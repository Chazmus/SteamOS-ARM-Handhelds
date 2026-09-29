#!/usr/bin/env bash
# Import MaSi's prebuilt SM8550 kernel (KERNEL + modules + firmware) from
# their released image into a kernel output dir that make-steamos-sm8650.sh /
# apply-overlays.sh take like one of ours:
#   <out>/<krel>/boot/KERNEL(.md5)  modules/<krel>  firmware/  config-<krel>
# Usage (as root, in the build VM):
#   scripts/import-sm8550-kernel.sh <SteamOS-ARM-sm8550.img[.gz]> [out-parent]
# Source: github.com/MaSieS4Fun/SteamOS-ARM-SM8550 v1.1.0 (MediaFire link in
# the release notes).
set -euo pipefail

src="${1:?image (.img or .img.gz)}"
parent="${2:-/work/kernel-masi}"
work="$(mktemp -d /work/.masi-import.XXXX)"
loop=""
cleanup() {
  umount "$work/boot" "$work/root" 2>/dev/null || true
  [[ -n "$loop" ]] && losetup -d "$loop" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

img="$src"
if [[ "$src" == *.gz ]]; then
  img="${src%.gz}"
  [[ -f "$img" ]] || { echo "decompressing to $img"; gzip -dc "$src" >"$img.part" && mv "$img.part" "$img"; }
fi

loop="$(losetup -fP --show -r "$img")"
mkdir -p "$work/boot" "$work/root"
bootp="" rootp=""
for p in "${loop}"p*; do
  t="$(blkid -o value -s TYPE "$p" 2>/dev/null || true)"
  if [[ "$t" == vfat && -z "$bootp" ]]; then
    mount -o ro "$p" "$work/boot"
    if [[ -f "$work/boot/KERNEL" ]]; then bootp="$p"; else umount "$work/boot"; fi
  elif [[ "$t" == ext4 && -z "$rootp" ]]; then
    mount -o ro,noload "$p" "$work/root"
    if [[ -d "$work/root/usr/lib/modules" ]]; then rootp="$p"; else umount "$work/root"; fi
  fi
done
[[ -n "$bootp" && -n "$rootp" ]] || { echo "BOOT ($bootp) or root ($rootp) not found" >&2; exit 1; }

# Their image carries an old 6.18 module dir too; take the KERNEL's release.
krel="$(python3 - "$work/boot/KERNEL" <<'PY'
import re, struct, sys, zlib
d = open(sys.argv[1], "rb").read()
ks, = struct.unpack_from("<I", d, 8)
ps, = struct.unpack_from("<I", d, 36)
img = zlib.decompressobj(31).decompress(d[ps:ps + ks])
print(re.search(rb"Linux version (\S+)", img).group(1).decode())
PY
)"
[[ -d "$work/root/usr/lib/modules/$krel" ]] || { echo "no modules for $krel" >&2; exit 1; }
out="$parent/$krel"
echo "BOOT=$bootp root=$rootp kernel=$krel -> $out"

rm -rf "$out"
mkdir -p "$out/boot" "$out/modules" "$out/firmware"
install -m0644 "$work/boot/KERNEL" "$out/boot/KERNEL"
(cd "$out/boot" && md5sum KERNEL >KERNEL.md5)
cp -a "$work/root/usr/lib/modules/$krel" "$out/modules/$krel"
for c in "$work/root/boot/config-$krel" "$work/root/usr/lib/modules/$krel/config"; do
  [[ -f "$c" ]] && { cp "$c" "$out/config-$krel"; break; }
done

# Firmware: only what this kernel's SM8550 devices load (GPU, DSPs, audio
# topology/amp tuning, panels). Everything else stays the Frame's.
fw="$work/root/usr/lib/firmware"
for f in qcom/sm8550 qcom/a740_sqe.fw qcom/gmu_gen70200.bin qcom/vpu; do
  for g in "$fw/$f" "$fw/$f".zst "$fw/$f".xz; do
    [[ -e "$g" ]] || continue
    mkdir -p "$out/firmware/$(dirname "$f")"
    cp -a "$g" "$out/firmware/$(dirname "$f")/"
  done
done

# MaSi links whole device dirs to the Odin 2's files (ayaneo -> ayn/odin2,
# ayn/odin2mini|odin2portal -> odin2). The rootfs already has ROCKNIX's real
# per-device dirs there (own amp tuning, AYANEO's own DSP split as .mdt), and
# rsync can't put a link over a dir. So: keep the real dirs, and give AYANEO
# the names MaSi's DTBs ask for, resolving to what MaSi's image loads.
s="$out/firmware/qcom/sm8550"
if [[ -L "$s/ayaneo" ]]; then
  rm "$s/ayaneo"
  mkdir -p "$s/ayaneo"
  for f in adsp.mbn adsp_dtb.mbn; do ln -s "../ayn/odin2/$f" "$s/ayaneo/$f"; done
  ln -s ../ayn/a740_zap.mbn "$s/ayaneo/a740_zap.mbn"
fi
for d in odin2mini odin2portal; do [[ -L "$s/ayn/$d" ]] && rm "$s/ayn/$d"; done

# Boot file: MaSi's kernel section (Image.gz + their appended DTBs) untouched,
# with OUR busybox initramfs (bootlog.txt, debug file, update recovery) as the
# ramdisk at the beta 2 addresses. A tester's hybrid with exactly this layout
# reached switch_root on an Odin 2; MaSi's own Debian initramfs is kept aside.
repo="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
kc="$repo/external-and-mods/kernel-common"
mv "$out/boot/KERNEL" "$out/boot/KERNEL.masi-orig"
python3 - "$out/boot/KERNEL.masi-orig" "$work/kernel.bin" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
assert d[:8] == b"ANDROID!"
ks, = struct.unpack_from("<I", d, 8)
ps, = struct.unpack_from("<I", d, 36)
k = d[ps:ps + ks]
# The appended DTBs follow the gzipped Image. Its AYANEO Pocket trees give
# the GPU "qcom,adreno-43050a00", which Mesa takes for an Adreno A32 (G3x
# Gen 2), so Turnip drove the 740 wrong and the screen stayed black (EVO,
# beta 5). The AYN/Retroid trees and upstream sm8550.dtsi use 43050a01.
# Same length, so a byte swap keeps every DTB intact.
import zlib
z = zlib.decompressobj(31); z.decompress(k)
img_len = len(k) - len(z.unused_data)
bad, good = b"qcom,adreno-43050a00", b"qcom,adreno-43050a01"
n = k[img_len:].count(bad)
k = k[:img_len] + k[img_len:].replace(bad, good)
print(f"dtb fixup: {n} x {bad.decode()} -> {good.decode()}")
open(sys.argv[2], "wb").write(k)
PY
rd="$work/initramfs"
mkdir -p "$rd/root/bin" "$rd/root/dev" "$rd/root/proc" "$rd/root/sys"
cp /bin/busybox "$rd/root/bin/busybox"
file -L /bin/busybox | grep -q "statically linked" || { echo "need static busybox" >&2; exit 1; }
install -m0755 "$kc/initramfs/init" "$rd/root/init"
install -m0755 "$kc/initramfs/konkr-update-recover" "$rd/root/konkr-update-recover"
install -m0755 "$kc/initramfs/bootdebug" "$rd/root/bootdebug"
(cd "$rd/root" && find . | cpio -o -H newc --owner=0:0 2>/dev/null) | gzip -9 -n >"$rd/initrd.gz"
python3 "$kc/mkbootimg-v0.py" --kernel "$work/kernel.bin" --ramdisk "$rd/initrd.gz" \
  --kernel-addr 0x10008000 --ramdisk-addr 0x16000000 --tags-addr 0x10000100 \
  --cmdline "root=PARTUUID=00000000-02" --out "$out/boot/KERNEL"
(cd "$out/boot" && md5sum KERNEL >KERNEL.md5)
# Extra modules this kernel lacks, built against a vanilla tree of the same
# release with its own config (no MODVERSIONS/signing, so vermagic is all it
# checks): sgm3804 powers the Pocket DMG / ACE panel (ROCKNIX's driver).
kver="${krel%%-*}"
ksrc="/work/sgm/linux-$kver"
if [[ ! -d "$ksrc" ]]; then
  mkdir -p /work/sgm
  curl -sfL "https://cdn.kernel.org/pub/linux/kernel/v${kver%%.*}.x/linux-$kver.tar.xz" | tar -xJ -C /work/sgm
fi
cp "$out/config-$krel" "$ksrc/.config" 2>/dev/null || python3 - "$work/boot/KERNEL" "$ksrc/.config" <<'PY'
import struct, sys, zlib
d = open(sys.argv[1], "rb").read()
ks, = struct.unpack_from("<I", d, 8); ps, = struct.unpack_from("<I", d, 36)
img = zlib.decompressobj(31).decompress(d[ps:ps + ks])
i = img.find(b"IKCFG_ST")
open(sys.argv[2], "wb").write(zlib.decompressobj(31).decompress(img[i + 8:]))
PY
make -s -C "$ksrc" olddefconfig >/dev/null
make -s -C "$ksrc" -j"$(nproc)" modules_prepare
[[ "$(cat "$ksrc/include/config/kernel.release")" == "$krel" ]] || { echo "extra modules: release mismatch" >&2; exit 1; }
for m in "$repo"/external-and-mods/kernel-sm8550/extra-modules/*/; do
  b="$work/extra-$(basename "$m")"; cp -r "$m" "$b"
  make -s -C "$ksrc" M="$b" KBUILD_MODPOST_WARN=1 modules 2>/dev/null
  for ko in "$b"/*.ko; do
    strip --strip-debug "$ko"
    install -D -m0644 "$ko" "$out/modules/$krel/extra/$(basename "$ko")"
    echo "extra module: $(basename "$ko")"
  done
done
mkdir -p "$work/dm/lib" && ln -sfn "$out/modules" "$work/dm/lib/modules"
depmod -b "$work/dm" "$krel"
chown -R -h root:root "$out"
du -sh "$out"/* "$out"/boot/* | sed "s|$out/||"
