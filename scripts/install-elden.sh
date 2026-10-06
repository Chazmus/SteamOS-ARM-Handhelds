#!/bin/bash
# Lenovo Legion Y700 Gen 4 (elden) support in the 8 Elite rootfs.
#
#   install-elden.sh ROOTFS
#
# The firmware manifest (copied out of the tablet's Android by
# tablet-firmware, at install and on boot while anything is missing), the
# compiled audio topology and the UCM profile, all under the tablet's own
# names so the Odin 3 and Pocket FIT Elite are untouched. The firmware dir
# goes first in the tablet's firmware search (firmware_class.path in its
# cmdline), since its device tree asks for qcom/sm8750/... like the others.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/../external-and-mods/elden/release.env"
R="${1:?rootfs}"
CACHE="${CACHE:-/work/cache/elden}"
die() { echo "[elden] ERROR: $*" >&2; exit 1; }
mkdir -p "$CACHE"
[[ -s "$CACHE/elden-src.tar.gz" ]] || { curl -fsSL --retry 3 -o "$CACHE/elden-src.tar.gz.part" "$ELDEN_SRC_URL"; mv -f "$CACHE/elden-src.tar.gz.part" "$CACHE/elden-src.tar.gz"; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
tar -C "$W" -xzf "$CACHE/elden-src.tar.gz"
S="$(echo "$W"/tb322fc-linux-*)"
[[ -f "$S/firmware.json" ]] || die "no firmware.json in the pinned source"

install -Dm0644 "$S/firmware.json" "$R/usr/share/steamos-arm/tablets/elden-firmware.json"

# Topology, compiled with the rootfs's own alsatplg, checked against the
# tablet-validated build.
tplg="$R/usr/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin"
mkdir -p "$(dirname "$tplg")"
cp "$S/inputs/audio/Lenovo-Y700-Gen4.conf" "$R/tmp/elden-tplg.conf"
chroot "$R" alsatplg -c /tmp/elden-tplg.conf -o /tmp/elden-tplg.bin >/dev/null || die "alsatplg failed"
mv "$R/tmp/elden-tplg.bin" "$tplg"; rm -f "$R/tmp/elden-tplg.conf"
echo "$ELDEN_TPLG_SHA256  $tplg" | sha256sum -c --quiet || die "topology differs from the validated one"

U="$R/usr/share/alsa/ucm2"
rm -rf "$U/Qualcomm/sm8750/Lenovo-Y700-Gen4"
mkdir -p "$U/Qualcomm/sm8750" "$U/conf.d/sm8750"
cp -a "$S/rootfs/audio/ucm2/Qualcomm/sm8750/Lenovo-Y700-Gen4" "$U/Qualcomm/sm8750/"
cp -a "$S/rootfs/audio/ucm2/conf.d/sm8750/Lenovo-Y700-Gen4.conf" "$U/conf.d/sm8750/"
# Tell the ABL each boot worked, or it gives up on the slot after 7.
O="${HERE}/../steamos-overlay"
install -Dm0755 "$O/usr/lib/steamos-arm/tablet-boot-ok" "$R/usr/lib/steamos-arm/tablet-boot-ok"
install -Dm0644 "$O/usr/lib/systemd/system/steamos-arm-tablet-boot-ok.service" "$R/usr/lib/systemd/system/steamos-arm-tablet-boot-ok.service"
mkdir -p "$R/usr/lib/systemd/system/multi-user.target.wants"
ln -sfn ../steamos-arm-tablet-boot-ok.service "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-tablet-boot-ok.service"
echo "[elden] firmware manifest, topology and audio profile installed"
