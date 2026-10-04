/*
 * H.264: read just enough of each slice header to know which PPS it uses
 * and whether it overrides the PPS reference counts, and write SPS/PPS NAL
 * units equivalent to the ones the client parsed.
 */
#include <string.h>

#include "common.h"

/* ---- bit reader over an escaped NAL (skips emulation prevention) ---- */

struct br {
	const uint8_t *p;
	size_t len, pos;     /* pos in bits over the unescaped payload */
	size_t byte;         /* next escaped byte index */
	int zeros;
	uint32_t cur;
	int bits_left;
	int err;
};

static void br_init(struct br *b, const uint8_t *p, size_t len)
{
	memset(b, 0, sizeof(*b));
	b->p = p;
	b->len = len;
}

static int br_bit(struct br *b)
{
	if (!b->bits_left) {
		if (b->byte >= b->len) {
			b->err = 1;
			return 0;
		}
		uint8_t v = b->p[b->byte++];
		if (b->zeros >= 2 && v == 3) {
			b->zeros = 0;
			if (b->byte >= b->len) {
				b->err = 1;
				return 0;
			}
			v = b->p[b->byte++];
		}
		b->zeros = v ? 0 : b->zeros + 1;
		b->cur = v;
		b->bits_left = 8;
	}
	b->bits_left--;
	return (b->cur >> b->bits_left) & 1;
}

static uint32_t br_u(struct br *b, int n)
{
	uint32_t v = 0;
	while (n--)
		v = (v << 1) | br_bit(b);
	return v;
}

static uint32_t br_ue(struct br *b)
{
	int lz = 0;
	while (!br_bit(b) && !b->err && lz < 32)
		lz++;
	if (lz >= 32)
		b->err = 1;
	return ((1u << lz) - 1) + br_u(b, lz);
}

static int32_t br_se(struct br *b)
{
	uint32_t k = br_ue(b);
	return (k & 1) ? (int32_t)((k + 1) / 2) : -(int32_t)(k / 2);
}

int h264_parse_slice(struct context *c, const VASliceParameterBufferH264 *sp,
		     const uint8_t *nal, size_t len, int *pps_id, int *nal_type)
{
	const VAPictureParameterBufferH264 *pp = &c->pic;
	struct br b;

	if (len < 2 || (nal[0] & 0x80))
		return -1;
	*nal_type = nal[0] & 0x1f;
	if (*nal_type != 1 && *nal_type != 5)
		return -1;

	br_init(&b, nal + 1, len - 1);
	br_ue(&b);                                     /* first_mb_in_slice */
	uint32_t slice_type = br_ue(&b) % 5;
	uint32_t id = br_ue(&b);
	if (b.err || id > 255)
		return -1;
	*pps_id = (int)id;

	if (pp->seq_fields.bits.chroma_format_idc == 3 &&
	    pp->seq_fields.bits.residual_colour_transform_flag)
		br_u(&b, 2);                           /* colour_plane_id */
	br_u(&b, pp->seq_fields.bits.log2_max_frame_num_minus4 + 4);
	int field = 0;
	if (!pp->seq_fields.bits.frame_mbs_only_flag) {
		field = br_bit(&b);
		if (field)
			br_bit(&b);
	}
	if (*nal_type == 5)
		br_ue(&b);                             /* idr_pic_id */
	if (pp->seq_fields.bits.pic_order_cnt_type == 0) {
		br_u(&b, pp->seq_fields.bits.log2_max_pic_order_cnt_lsb_minus4 + 4);
		if (pp->pic_fields.bits.pic_order_present_flag && !field)
			br_se(&b);
	}
	if (pp->seq_fields.bits.pic_order_cnt_type == 1 &&
	    !pp->seq_fields.bits.delta_pic_order_always_zero_flag) {
		br_se(&b);
		if (pp->pic_fields.bits.pic_order_present_flag && !field)
			br_se(&b);
	}
	if (pp->pic_fields.bits.redundant_pic_cnt_present_flag)
		br_ue(&b);
	if (slice_type == 1)
		br_bit(&b);                            /* direct_spatial_mv_pred_flag */

	if (slice_type == 0 || slice_type == 1 || slice_type == 3) {
		int override = br_bit(&b);
		if (b.err)
			return -1;
		if (!override) {
			/* The slice uses the PPS defaults, so VA's effective counts are them. */
			struct pps_learned *l = &c->learned[id];
			l->l0 = sp->num_ref_idx_l0_active_minus1;
			if (slice_type == 1)
				l->l1 = sp->num_ref_idx_l1_active_minus1;
			l->known = 1;
		}
	}
	return b.err ? -1 : 0;
}

/* ---- bit writer producing an escaped NAL ---- */

struct bw {
	uint8_t raw[1024];
	size_t bits;
};

static void bw_bit(struct bw *w, int v)
{
	if (w->bits / 8 >= sizeof(w->raw))
		return;
	if (v)
		w->raw[w->bits / 8] |= 0x80 >> (w->bits % 8);
	w->bits++;
}

static void bw_u(struct bw *w, int n, uint32_t v)
{
	while (n--)
		bw_bit(w, (v >> n) & 1);
}

static void bw_ue(struct bw *w, uint32_t v)
{
	uint32_t x = v + 1;
	int n = 0;
	while ((x >> n) > 1)
		n++;
	bw_u(w, n, 0);
	bw_u(w, n + 1, x);
}

static void bw_se(struct bw *w, int32_t v)
{
	bw_ue(w, v > 0 ? (uint32_t)(2 * v - 1) : (uint32_t)(-2 * v));
}

static size_t bw_finish(struct bw *w, uint8_t nal_header, uint8_t *out, size_t cap)
{
	bw_bit(w, 1);                                  /* rbsp_stop_one_bit */
	while (w->bits % 8)
		bw_bit(w, 0);
	size_t n = w->bits / 8, o = 0;
	if (cap < 5 + n * 3 / 2)
		return 0;
	out[o++] = 0; out[o++] = 0; out[o++] = 0; out[o++] = 1;
	out[o++] = nal_header;
	int zeros = 0;
	for (size_t i = 0; i < n; i++) {
		uint8_t v = w->raw[i];
		if (zeros >= 2 && v <= 3) {
			out[o++] = 3;
			zeros = 0;
		}
		out[o++] = v;
		zeros = v ? 0 : zeros + 1;
	}
	return o;
}

static int profile_idc(const struct context *c)
{
	const VAPictureParameterBufferH264 *pp = &c->pic;
	if (pp->pic_fields.bits.transform_8x8_mode_flag || c->have_iq ||
	    pp->seq_fields.bits.chroma_format_idc != 1 ||
	    pp->bit_depth_luma_minus8 || pp->bit_depth_chroma_minus8)
		return 100;
	switch (c->cfg.profile) {
	case VAProfileH264ConstrainedBaseline:
		return 66;
	case VAProfileH264Main:
		return 77;
	default:
		return 100;
	}
}

size_t h264_write_sps(const struct context *c, uint8_t *out, size_t cap)
{
	const VAPictureParameterBufferH264 *pp = &c->pic;
	struct bw w = {0};
	int prof = profile_idc(c);
	uint32_t mbs = (pp->picture_width_in_mbs_minus1 + 1u) *
		       (pp->picture_height_in_mbs_minus1 + 1u);

	bw_u(&w, 8, prof);
	bw_u(&w, 8, prof == 66 ? 0x40 : 0);          /* constraint_set1 for CB */
	bw_u(&w, 8, mbs > 36864 ? 61 : 52);          /* level_idc */
	bw_ue(&w, 0);                                  /* seq_parameter_set_id */
	if (prof >= 100) {
		bw_ue(&w, pp->seq_fields.bits.chroma_format_idc);
		if (pp->seq_fields.bits.chroma_format_idc == 3)
			bw_bit(&w, pp->seq_fields.bits.residual_colour_transform_flag);
		bw_ue(&w, pp->bit_depth_luma_minus8);
		bw_ue(&w, pp->bit_depth_chroma_minus8);
		bw_bit(&w, 0);                         /* qpprime_y_zero_transform_bypass */
		bw_bit(&w, 0);                         /* scaling lists go in the PPS */
	}
	bw_ue(&w, pp->seq_fields.bits.log2_max_frame_num_minus4);
	bw_ue(&w, pp->seq_fields.bits.pic_order_cnt_type);
	if (pp->seq_fields.bits.pic_order_cnt_type == 0) {
		bw_ue(&w, pp->seq_fields.bits.log2_max_pic_order_cnt_lsb_minus4);
	} else if (pp->seq_fields.bits.pic_order_cnt_type == 1) {
		/* VA drops the type 1 offsets; zero cycles is the common encoding. */
		bw_bit(&w, pp->seq_fields.bits.delta_pic_order_always_zero_flag);
		bw_se(&w, 0);
		bw_se(&w, 0);
		bw_ue(&w, 0);
	}
	bw_ue(&w, pp->num_ref_frames);
	bw_bit(&w, pp->seq_fields.bits.gaps_in_frame_num_value_allowed_flag);
	bw_ue(&w, pp->picture_width_in_mbs_minus1);
	if (pp->seq_fields.bits.frame_mbs_only_flag) {
		bw_ue(&w, pp->picture_height_in_mbs_minus1);
	} else {
		bw_ue(&w, (pp->picture_height_in_mbs_minus1 + 1) / 2 - 1);
	}
	bw_bit(&w, pp->seq_fields.bits.frame_mbs_only_flag);
	if (!pp->seq_fields.bits.frame_mbs_only_flag)
		bw_bit(&w, pp->seq_fields.bits.mb_adaptive_frame_field_flag);
	bw_bit(&w, pp->seq_fields.bits.direct_8x8_inference_flag);
	bw_bit(&w, 0);                                 /* frame_cropping_flag */

	/*
	 * VUI with only a bitstream restriction: no reordering and a DPB the
	 * size of the reference count. The firmware then hands each picture
	 * back right after decoding it, in decode order, as VA-API expects.
	 */
	bw_bit(&w, 1);                                 /* vui_parameters_present */
	bw_bit(&w, 0);                                 /* aspect_ratio_info */
	bw_bit(&w, 0);                                 /* overscan_info */
	bw_bit(&w, 0);                                 /* video_signal_type */
	bw_bit(&w, 0);                                 /* chroma_loc_info */
	bw_bit(&w, 0);                                 /* timing_info */
	bw_bit(&w, 0);                                 /* nal_hrd */
	bw_bit(&w, 0);                                 /* vcl_hrd */
	bw_bit(&w, 0);                                 /* pic_struct_present */
	bw_bit(&w, 1);                                 /* bitstream_restriction */
	bw_bit(&w, 1);                                 /* mv over pic boundaries */
	bw_ue(&w, 0);                                  /* max_bytes_per_pic_denom */
	bw_ue(&w, 0);                                  /* max_bits_per_mb_denom */
	bw_ue(&w, 16);
	bw_ue(&w, 16);
	bw_ue(&w, 0);                                  /* max_num_reorder_frames */
	bw_ue(&w, pp->num_ref_frames ? pp->num_ref_frames : 1);

	return bw_finish(&w, 0x67, out, cap);
}

static int list_is_flat(const uint8_t *l, int n)
{
	for (int i = 0; i < n; i++)
		if (l[i] != 16)
			return 0;
	return 1;
}

/* Frame zig-zag scans: bitstream position -> raster index. */
static const uint8_t zz4[16] = {0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15};
static const uint8_t zz8[64] = {
	0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5,
	12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
	35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
	58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63,
};

static void write_list(struct bw *w, const uint8_t *l, int n)
{
	/* VA keeps the lists in raster order; the bitstream codes them in
	 * zig-zag order. Every entry is coded, no early end. */
	const uint8_t *zz = n == 16 ? zz4 : zz8;
	int last = 8;
	for (int i = 0; i < n; i++) {
		int v = l[zz[i]];
		int d = v - last;
		if (d > 127)
			d -= 256;
		if (d < -128)
			d += 256;
		bw_se(w, d);
		last = v;
	}
}

size_t h264_write_pps(const struct context *c, int pps_id, uint8_t *out, size_t cap)
{
	const VAPictureParameterBufferH264 *pp = &c->pic;
	const struct pps_learned *l = &c->learned[pps_id];
	struct bw w = {0};

	int lists = 0;
	if (c->have_iq) {
		for (int i = 0; i < 6; i++)
			if (!list_is_flat(c->iq.ScalingList4x4[i], 16))
				lists = 1;
		if (pp->pic_fields.bits.transform_8x8_mode_flag)
			for (int i = 0; i < 2; i++)
				if (!list_is_flat(c->iq.ScalingList8x8[i], 64))
					lists = 1;
	}

	bw_ue(&w, pps_id);
	bw_ue(&w, 0);                                  /* seq_parameter_set_id */
	bw_bit(&w, pp->pic_fields.bits.entropy_coding_mode_flag);
	bw_bit(&w, pp->pic_fields.bits.pic_order_present_flag);
	bw_ue(&w, 0);                                  /* num_slice_groups_minus1 */
	bw_ue(&w, l->l0);
	bw_ue(&w, l->l1);
	bw_bit(&w, pp->pic_fields.bits.weighted_pred_flag);
	bw_u(&w, 2, pp->pic_fields.bits.weighted_bipred_idc);
	bw_se(&w, pp->pic_init_qp_minus26);
	bw_se(&w, pp->pic_init_qs_minus26);
	bw_se(&w, pp->chroma_qp_index_offset);
	bw_bit(&w, pp->pic_fields.bits.deblocking_filter_control_present_flag);
	bw_bit(&w, pp->pic_fields.bits.constrained_intra_pred_flag);
	bw_bit(&w, pp->pic_fields.bits.redundant_pic_cnt_present_flag);

	if (pp->pic_fields.bits.transform_8x8_mode_flag || lists ||
	    pp->second_chroma_qp_index_offset != pp->chroma_qp_index_offset) {
		bw_bit(&w, pp->pic_fields.bits.transform_8x8_mode_flag);
		bw_bit(&w, lists);
		if (lists) {
			int n = 6 + (pp->pic_fields.bits.transform_8x8_mode_flag ? 2 : 0);
			for (int i = 0; i < n; i++) {
				bw_bit(&w, 1);         /* pic_scaling_list_present_flag */
				if (i < 6)
					write_list(&w, c->iq.ScalingList4x4[i], 16);
				else
					write_list(&w, c->iq.ScalingList8x8[i - 6], 64);
			}
		}
		bw_se(&w, pp->second_chroma_qp_index_offset);
	}
	return bw_finish(&w, 0x68, out, cap);
}
