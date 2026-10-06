#!/bin/bash
# Boot files for the Lenovo tablets on an image's BOOT partition, so the
# image on a USB drive can be started on the tablet (fastboot boot) and
# installed to its internal storage from there.
#
#   stage-tablet-boot.sh BOOT_DIR tb321fu|elden KERNEL_OUT
#
# tb321fu  Legion Y700 Gen 3: EFI/BOOT (GRUB), Image and both panels' DTBs at
#          the top of BOOT, which UEFI finds on the drive; the UEFI boot
#          image to start it with goes to tablet/.
# elden    Legion Y700 Gen 4: our kernel (DTB and cmdline built in) as a
#          header v4 boot image with an AVB footer, in tablet/.
#
# Both kernels boot root=PARTLABEL=STORAGE, the internal install, and fall
# back to the image on the USB drive while that doesn't exist yet.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD="${HERE}/../external-and-mods"
BOOT="$1" DEV="$2" KOUT="$(readlink -f "$3")"
CACHE="${CACHE:-${STEAMOS_WORK:-/work}/cache}"
die() { echo "stage-tablet-boot: $*" >&2; exit 1; }
[[ -d "$BOOT" ]] || die "no $BOOT"
mkdir -p "$BOOT/tablet"

case "$DEV" in
  tb321fu)
    cmdline="$(bash -c "source '${MOD}/kernel-tb321fu/soc.env'; source '${MOD}/kernel-common/cmdline.sh'; build_cmdline PARTLABEL=STORAGE")"
    CACHE="$CACHE/tb321fu-boot" bash "${HERE}/stage-tb321fu-boot.sh" "$BOOT" "$KOUT" both "$cmdline" \
      "$BOOT/tablet/lenovo-legion-tab-gen3-boot.img"
    ;;
  elden)
    source "${MOD}/elden/release.env"
    c="$CACHE/elden"; mkdir -p "$c"
    get() {  # get URL FILE SHA256 (googlesource ?format=TEXT is base64)
      if [[ ! -s "$c/$2" ]] || ! echo "$3  $c/$2" | sha256sum -c --quiet 2>/dev/null; then
        curl -fsSL --retry 3 "$1" | base64 -d >"$c/$2.part"
        mv -f "$c/$2.part" "$c/$2"
      fi
      echo "$3  $c/$2" | sha256sum -c --quiet || die "hash mismatch: $2"
    }
    get "$AVBTOOL_URL" avbtool.py "$AVBTOOL_SHA256"
    get "$AVB_TESTKEY_URL" testkey_rsa4096.pem "$AVB_TESTKEY_SHA256"
    [[ -s "$KOUT/boot/Image" ]] || die "no $KOUT/boot/Image (kernel-elden builds it)"
    out="$BOOT/tablet/lenovo-legion-y700-gen4-boot.img"
    tmp="$(mktemp)"
    python3 "${MOD}/kernel-common/mkbootimg-v4.py" --kernel "$KOUT/boot/Image" --out "$tmp"
    python3 "$c/avbtool.py" add_hash_footer --image "$tmp" \
      --partition_size "$ELDEN_BOOT_PARTITION_SIZE" --partition_name boot \
      --algorithm SHA256_RSA4096 --key "$c/testkey_rsa4096.pem"
    cp "$tmp" "$out"; rm -f "$tmp"
    ;;
  *) die "unknown tablet $DEV" ;;
esac
(cd "$BOOT/tablet" && sha256sum ./*.img > SHA256SUMS)
echo "stage-tablet-boot: $DEV staged on $BOOT"
