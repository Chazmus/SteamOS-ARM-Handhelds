#!/usr/bin/env python3
"""Boot images for Nubia's stock ABL (REDMAGIC 6): header v3 boot + vendor_boot.

Verified on an NX669J-UN: the stock ABL boots only the layout Nubia ships,
kernel in boot (v3) and DTB + ramdisk + cmdline in vendor_boot (v3). A v2
boot image with its own dtb section is acknowledged by fastboot and then
silently not started, even with Nubia's own kernel and DTB in it.

It also needs dtbo erased: with a valid dtbo, ABL overlays Nubia's board
dtbo and the Haven hypervisor's overlays onto the DTB (libufdt), which fails
on a mainline tree. Without it ABL takes the DTB as is, matched by msm-id and
board-id; see --board-ids.

  mkbootimg-v3.py --kernel Image.gz --ramdisk initrd.gz --dtb board.dtb \
                  --cmdline "..." --boot boot.img --vendor-boot vendor_boot.img

vendor_boot load addresses: base 0, kernel 0x8000, tags 0x100, 4 KiB pages
like the stock image; the DTB and ramdisk go after the kernel's in-memory
size (arm64 Image header, BSS included) instead of the stock 31/16 MiB, which
sit inside a ~48 MiB mainline kernel.
"""
import argparse
import struct
import zlib
from pathlib import Path

PAGE = 4096
BASE = 0x00000000
KERNEL_OFFSET = 0x00008000
TAGS_OFFSET = 0x00000100
MIN_DTB_OFFSET = 0x01F00000     # stock layout, for small kernels
REGION_ALIGN = 0x00800000       # 8 MiB between kernel end, dtb and ramdisk
BOOT_HEADER_V3_SIZE = 1580
VENDOR_HEADER_V3_SIZE = 2112
BOOT_ARGS_V3_SIZE = 1536
VENDOR_ARGS_SIZE = 2048


def os_version(release, patch):
    a, b, c = (int(x) for x in (release.split(".") + ["0", "0"])[:3])
    y, m = (int(x) for x in patch.split("-")[:2])
    return ((a << 14) | (b << 7) | c) << 11 | ((y - 2000) << 4) | m


def kernel_image_size(kernel):
    """In-memory size of an arm64 Image (gzip or raw), BSS included."""
    if kernel[:2] == b"\x1f\x8b":
        head = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(kernel, 64)
    else:
        head = kernel[:64]
    if head[56:60] != b"ARM\x64":
        raise SystemExit("kernel is not an arm64 Image")
    return struct.unpack_from("<Q", head, 16)[0]


def align_up(x, a):
    return (x + a - 1) // a * a


def pad(data):
    return data + b"\0" * (-len(data) % PAGE)


def with_board_id(dtb, board_id):
    """Copy of an FDT with its root qcom,board-id (two cells) replaced."""
    magic, _total, off_struct, off_strings = struct.unpack_from(">IIII", dtb, 0)
    if magic != 0xD00DFEED:
        raise SystemExit("dtb: bad magic")
    out = bytearray(dtb)
    pos, depth = off_struct, 0
    while True:
        (tok,) = struct.unpack_from(">I", dtb, pos)
        pos += 4
        if tok == 1:                            # FDT_BEGIN_NODE
            end = dtb.index(b"\0", pos)
            pos = (end + 4) & ~3
            depth += 1
        elif tok == 2:                          # FDT_END_NODE
            depth -= 1
        elif tok == 3:                          # FDT_PROP
            length, nameoff = struct.unpack_from(">II", dtb, pos)
            pos += 8
            name = dtb[off_strings + nameoff:dtb.index(b"\0", off_strings + nameoff)]
            if depth == 1 and name == b"qcom,board-id":
                if length != 8:
                    raise SystemExit("dtb: qcom,board-id must be two cells")
                struct.pack_into(">II", out, pos, *board_id)
                return bytes(out)
            pos = (pos + length + 3) & ~3
        elif tok == 4:                          # FDT_NOP
            continue
        else:                                   # FDT_END
            raise SystemExit("dtb: no root qcom,board-id")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--ramdisk", required=True)
    ap.add_argument("--dtb", required=True)
    ap.add_argument("--cmdline", default="")
    ap.add_argument("--os-version", default="11.0.0")
    ap.add_argument("--os-patch-level", default="2023-06")
    ap.add_argument("--boot", required=True)
    ap.add_argument("--vendor-boot", required=True)
    ap.add_argument("--board-ids", default="",
                    help="comma-separated hex pairs a:b; one DTB copy per id")
    a = ap.parse_args()

    kernel = Path(a.kernel).read_bytes()
    ramdisk = Path(a.ramdisk).read_bytes()
    dtb = Path(a.dtb).read_bytes()
    if a.board_ids:
        # With dtbo erased, ABL picks the vendor_boot DTB by msm-id AND the
        # board's real board-id, which is not published: ship one copy per
        # candidate (the ids of Nubia's dtbo entries) and let ABL choose.
        ids = [tuple(int(x, 16) for x in p.split(":")) for p in a.board_ids.split(",")]
        dtb = b"".join(with_board_id(dtb, i) for i in ids)
    cmd = a.cmdline.encode()
    if len(cmd) >= VENDOR_ARGS_SIZE:
        raise SystemExit(f"cmdline too long ({len(cmd)})")

    kernel_end = KERNEL_OFFSET + kernel_image_size(kernel)
    dtb_offset = max(MIN_DTB_OFFSET, align_up(kernel_end, REGION_ALIGN))
    ramdisk_offset = align_up(dtb_offset + len(dtb), REGION_ALIGN)

    # boot: kernel only (no generic ramdisk); the cmdline lives in vendor_boot.
    boot_hdr = struct.pack(
        "<8s4I4II1536s",
        b"ANDROID!",
        len(kernel),
        0,                                      # ramdisk size
        os_version(a.os_version, a.os_patch_level),
        BOOT_HEADER_V3_SIZE,
        0, 0, 0, 0,                             # reserved
        3,                                      # header version
        b"".ljust(BOOT_ARGS_V3_SIZE, b"\0"),
    )
    assert len(boot_hdr) == BOOT_HEADER_V3_SIZE, len(boot_hdr)
    Path(a.boot).write_bytes(pad(boot_hdr) + pad(kernel))

    vendor_hdr = struct.pack(
        "<8sIIIII2048sI16sIIQ",
        b"VNDRBOOT",
        3,                                      # header version
        PAGE,
        BASE + KERNEL_OFFSET,
        BASE + ramdisk_offset,
        len(ramdisk),
        cmd.ljust(VENDOR_ARGS_SIZE, b"\0"),
        BASE + TAGS_OFFSET,
        b"",                                    # product name
        VENDOR_HEADER_V3_SIZE,
        len(dtb),
        BASE + dtb_offset,
    )
    assert len(vendor_hdr) == VENDOR_HEADER_V3_SIZE, len(vendor_hdr)
    Path(a.vendor_boot).write_bytes(pad(vendor_hdr) + pad(ramdisk) + pad(dtb))


if __name__ == "__main__":
    main()
