#!/bin/bash
# Lenovo Legion Y700 Gen 3 (TB321FU) support in the 8 Gen 3 rootfs.
#
#   install-tb321fu.sh ROOTFS
#
# Firmware and the audio profile, kept out of what the Pocket FIT and Pocket
# S2 use from the same rootfs:
#  - the tablet's own files go to its own paths (qcom/sm8650/lenovo/tb321fu,
#    qca/hmtnv20_Kirby_*, the LenovoY700TB321 UCM)
#  - its Wi-Fi firmware and board data replace the shared WCN7850 files, so
#    they go to /usr/lib/firmware/steamos-arm/tb321fu, which only the
#    tablet's cmdline puts first in the search (firmware_class.path)
#  - its WCD939x UCM sequences go with its profile, not over the shared ones
# Downloads are cached in ${CACHE:-/work/cache/tb321fu-boot}.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/../external-and-mods/tb321fu-boot/release.env"
R="${1:?rootfs}"
CACHE="${CACHE:-/work/cache/tb321fu-boot}"
log() { echo "[tb321fu] $*"; }
die() { echo "[tb321fu] ERROR: $*" >&2; exit 1; }
mkdir -p "$CACHE"

fetch() {  # fetch URL FILE [SHA256]
  [[ -s "$CACHE/$2" ]] || { curl -fsSL --retry 3 -o "$CACHE/$2.part" "$1"; mv -f "$CACHE/$2.part" "$CACHE/$2"; }
  [[ -z "${3:-}" ]] || echo "$3  $CACHE/$2" | sha256sum -c --quiet || die "hash mismatch: $2"
}

# Firmware: unpack, check the pinned SHA256SUMS, then every file against it.
fetch "$TB321FU_FW_URL" tb321fu-firmware.tar.gz
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
tar -C "$W" -xzf "$CACHE/tb321fu-firmware.tar.gz"
FW="$(echo "$W"/firmware-lenovo-tb321fu-*)"
echo "$TB321FU_FW_SUMS_SHA256  $FW/SHA256SUMS" | sha256sum -c --quiet || die "firmware SHA256SUMS changed"
(cd "$FW" && sha256sum -c --quiet SHA256SUMS) || die "firmware files don't match SHA256SUMS"

F="$R/usr/lib/firmware"
mkdir -p "$F/qcom/sm8650/lenovo" "$F/steamos-arm/tb321fu/ath12k/WCN7850"
rm -rf "$F/qcom/sm8650/lenovo/tb321fu"
cp -a "$FW/usr/lib/firmware/qcom/sm8650/lenovo/tb321fu" "$F/qcom/sm8650/lenovo/"
cp -a "$FW/usr/lib/firmware/qcom/sm8650/Lenovo-Y700-TB321FU-tplg.bin" "$F/qcom/sm8650/"
cp -a "$FW/usr/lib/firmware/aw882xx_acf.bin" "$FW/usr/lib/firmware/haptic_click.bin" \
  "$FW/usr/lib/firmware/haptic_ram.bin" "$F/"
rm -rf "$F/steamos-arm/tb321fu/ath12k/WCN7850/hw2.0"
cp -a "$FW/usr/lib/firmware/updates/ath12k/WCN7850/hw2.0" "$F/steamos-arm/tb321fu/ath12k/WCN7850/"

# GUF296's packages: Bluetooth NVM, CSOT touch firmware, the audio profile.
fetch "$TB321FU_DEBS_URL" tb321fu-debs.tar.gz "$TB321FU_DEBS_SHA256"
mkdir -p "$W/debs" "$W/ov"
tar -C "$W/debs" -xzf "$CACHE/tb321fu-debs.tar.gz"
deb="$(echo "$W"/debs/y700-daily-rootfs-overlay_*_arm64.deb)"
[[ -f "$deb" ]] || die "no rootfs overlay package in the device packages"
(cd "$W/debs" && ar x "$deb" data.tar.xz)
tar -C "$W/ov" -xJf "$W/debs/data.tar.xz" ./usr/lib/firmware ./usr/share/alsa
O="$W/ov/usr/lib/firmware"
cp -a "$O/qca/hmtnv20_Kirby_prc.bin" "$O/qca/hmtnv20_Kirby_row.bin" "$F/qca/"
cp -a "$O/qcom/sm8650/lenovo/tb321fu/novatek_ts_csot_fw.bin" \
  "$O/qcom/sm8650/lenovo/tb321fu/novatek_ts_csot_mp.bin" "$F/qcom/sm8650/lenovo/tb321fu/"

U="$R/usr/share/alsa/ucm2"
A="$W/ov/usr/share/alsa/ucm2"
rm -rf "$U/LenovoY700TB321"
mkdir -p "$U/LenovoY700TB321/wcd939x"
cp -a "$A/LenovoY700TB321/LenovoY700TB321.conf" "$U/LenovoY700TB321/"
# Our verb: speakers on their own PCM (see the file), not GUF296's shared one.
cp "${HERE}/../external-and-mods/tb321fu-boot/ucm/HiFi.conf" "$U/LenovoY700TB321/HiFi.conf"
cp -a "$A/codecs/wcd939x/." "$U/LenovoY700TB321/wcd939x/"
# Its own WCD939x sequences, not the shared ones the other 8 Gen 3 devices use.
sed -i 's|"/codecs/wcd939x/|"/LenovoY700TB321/wcd939x/|g' "$U/LenovoY700TB321/"*.conf "$U/LenovoY700TB321/wcd939x/"*.conf
for d in sm8650 snd_soc_sc8280xp; do
  mkdir -p "$U/conf.d/$d"
  # Some Lenovo firmware names the card Lenovo-QRD-2.0.
  for n in Lenovo-Y700-TB321FU Lenovo-QRD-2.0; do
    ln -sfn ../../LenovoY700TB321/LenovoY700TB321.conf "$U/conf.d/$d/$n.conf"
  done
done
grep -rq '/codecs/wcd939x/' "$U/LenovoY700TB321" && die "profile still points at the shared WCD939x sequences"

# The ADSP takes at most 65280-byte buffers in 2-8 periods for this card;
# PipeWire's default request fails (EINVAL) and nothing plays. Matched by the
# card name, so no other device sees it.
install -Dm0644 /dev/stdin "$R/usr/share/wireplumber/wireplumber.conf.d/51-lenovo-tb321fu-alsa.conf" <<'CONF'
# Lenovo Legion Y700 Gen 3: buffer sizes the ADSP accepts for its card.
monitor.alsa.rules = [
  {
    matches = [ { alsa.card_name = "Lenovo-Y700-TB321FU" }, { alsa.card_name = "Lenovo-QRD-2.0" } ]
    actions = {
      update-props = {
        api.alsa.period-size = 1024
        api.alsa.period-num = 4
        api.alsa.headroom = 0
      }
    }
  }
]
CONF

# Desktop Mode: the panel's two halves are 800 px wide, so the DPU's inline
# rotator takes the rotation and leaves a line at the seam; KWin rotates in
# the compositor instead (Game Mode already uses gamescope's shader).
install -Dm0755 /dev/stdin "$R/etc/xdg/plasma-workspace/env/steamos-arm-tablet-kwin.sh" <<'ENV'
#!/bin/sh
# Lenovo Legion Y700 Gen 3: rotate in the compositor (see install-tb321fu.sh).
if tr '\0' '\n' </sys/firmware/devicetree/base/compatible 2>/dev/null | grep -qx 'lenovo,tb321fu'; then
  export KWIN_ENABLE_HW_ROTATION=0
fi
ENV

# The Adreno 750's GMU fails to come back from runtime suspend on this tablet
# (Armada TB321FU notes): keep it powered until that is understood.
install -Dm0644 /dev/stdin "$R/usr/lib/systemd/system/steamos-arm-tb321fu-gpu-on.service" <<'UNIT'
[Unit]
Description=Lenovo Legion Y700 Gen 3: keep the GPU powered (its GMU doesn't resume)
ConditionFirmware=device-tree-compatible(lenovo,tb321fu)
Before=display-manager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'for d in 3d00000.gpu 3d6a000.gmu; do [ -e /sys/bus/platform/devices/$d/power/control ] && echo on > /sys/bus/platform/devices/$d/power/control; done; exit 0'

[Install]
WantedBy=multi-user.target
UNIT
mkdir -p "$R/usr/lib/systemd/system/multi-user.target.wants"
ln -sfn ../steamos-arm-tb321fu-gpu-on.service "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-tb321fu-gpu-on.service"

# Tell the ABL each boot worked, or it gives up on the slot after 7.
O="${HERE}/../steamos-overlay"
install -Dm0755 "$O/usr/lib/steamos-arm/tablet-boot-ok" "$R/usr/lib/steamos-arm/tablet-boot-ok"
install -Dm0644 "$O/usr/lib/systemd/system/steamos-arm-tablet-boot-ok.service" "$R/usr/lib/systemd/system/steamos-arm-tablet-boot-ok.service"
ln -sfn ../steamos-arm-tablet-boot-ok.service "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-tablet-boot-ok.service"
log "firmware and audio profile installed"
