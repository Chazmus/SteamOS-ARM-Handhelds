#!/bin/bash
# Lenovo Legion Y700 Gen 3 (TB321FU) support in the 8 Gen 3 rootfs.
#
#   install-tb321fu.sh ROOTFS
#
# Firmware and the audio profile, kept out of what the Pocket FIT and Pocket
# S2 use from the same rootfs:
#  - the tablet's own files go to its own paths (qcom/sm8650/lenovo/tb321fu,
#    qca/hmtnv20_Kirby_*, the Qualcomm/sm8650/TB321FU UCM)
#  - its Wi-Fi firmware and board data replace the shared WCN7850 files, so
#    they go to /usr/lib/firmware/steamos-arm/tb321fu, which only the
#    tablet's cmdline puts first in the search (firmware_class.path)
#  - settings no other device should get are installed by units gated on
#    its device tree
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

# GUF296's packages: Bluetooth NVM, CSOT touch firmware.
fetch "$TB321FU_DEBS_URL" tb321fu-debs.tar.gz "$TB321FU_DEBS_SHA256"
mkdir -p "$W/debs" "$W/ov"
tar -C "$W/debs" -xzf "$CACHE/tb321fu-debs.tar.gz"
deb="$(echo "$W"/debs/y700-daily-rootfs-overlay_*_arm64.deb)"
[[ -f "$deb" ]] || die "no rootfs overlay package in the device packages"
(cd "$W/debs" && ar x "$deb" data.tar.xz)
tar -C "$W/ov" -xJf "$W/debs/data.tar.xz" ./usr/lib/firmware
O="$W/ov/usr/lib/firmware"
cp -a "$O/qca/hmtnv20_Kirby_prc.bin" "$O/qca/hmtnv20_Kirby_row.bin" "$F/qca/"
# The Kirby NVM only loads after the patch it was released with
# (BTFW.HAMILTON.2.0.1-00355); with the newer shared hmtbtfw20.tlv the
# controller rejects it (-52) and Bluetooth never comes up. The pair goes
# to the tablet's own firmware path, searched first only on the tablet.
mkdir -p "$F/steamos-arm/tb321fu/qca"
cp -a "$O/qca/hmtbtfw20.tlv" "$O/qca/hmtnv20_Kirby_prc.bin" "$O/qca/hmtnv20_Kirby_row.bin" \
  "$F/steamos-arm/tb321fu/qca/"
cp -a "$O/qcom/sm8650/lenovo/tb321fu/novatek_ts_csot_fw.bin" \
  "$O/qcom/sm8650/lenovo/tb321fu/novatek_ts_csot_mp.bin" "$F/qcom/sm8650/lenovo/tb321fu/"

# Audio profile: from the tree the kernel is built from (same commit), whose
# controls it uses (aw882xx_rx_switch, aw_dev_N_switch, ...). GUF296's
# profile was written for his kernel's controls and routes nothing on this one.
fetch "$TB321FU_PORT_URL" tb321fu-port.tar.gz
mkdir -p "$W/port"
tar -C "$W/port" -xzf "$CACHE/tb321fu-port.tar.gz" --strip-components=1 --wildcards '*/system_files/usr/share/alsa/ucm2/*'
A="$W/port/system_files/usr/share/alsa/ucm2"
[[ -f "$A/Qualcomm/sm8650/TB321FU/HiFi.conf" ]] || die "no TB321FU audio profile in the kernel's source tree"
U="$R/usr/share/alsa/ucm2"
rm -rf "$U/LenovoY700TB321" "$U/Qualcomm/sm8650/TB321FU"
rm -f "$U/conf.d/snd_soc_sc8280xp/Lenovo-Y700-TB321FU.conf" "$U/conf.d/snd_soc_sc8280xp/Lenovo-QRD-2.0.conf"
mkdir -p "$U/Qualcomm/sm8650" "$U/conf.d/sm8650"
cp -a "$A/Qualcomm/sm8650/TB321FU" "$U/Qualcomm/sm8650/"
# Some Lenovo firmware names the card Lenovo-QRD-2.0.
for n in Lenovo-Y700-TB321FU Lenovo-QRD-2.0; do
  install -m0644 "$A/conf.d/sm8650/$n.conf" "$U/conf.d/sm8650/$n.conf"
done
for f in /codecs/wcd939x/init.conf /codecs/wcd939x/HeadphoneEnableSeq.conf \
         /codecs/qcom-lpass/rx-macro/HeadphoneEnableSeq.conf /codecs/qcom-lpass/tx-macro/SoundwireMic0EnableSeq.conf \
         /lib/card-init.conf /lib/ctl-remap.conf; do
  [[ -f "$U$f" ]] || die "the rootfs's alsa-ucm-conf has no $f, which the profile includes"
done

# The ADSP takes at most 65280-byte buffers in 2-8 periods for this card;
# PipeWire's default request fails (EINVAL) and nothing plays. The Pocket
# FIT's rules in /etc (53-konkr-audio, 54-konkr-quantum) match every
# platform-sound card and sort after a 5x name: they set 960-frame periods
# and ask for a "HiFi (Headphones, Speaker)" profile this card doesn't have
# (its mics are part of every HiFi profile), so WirePlumber fell back to
# pro-audio, which plays raw PCMs without the UCM speaker and mic sequences:
# one "Built-in Audio" output, no sound and no microphone. This file sorts
# after them and is matched by the card name, so no other device sees it.
rm -f "$R/usr/share/wireplumber/wireplumber.conf.d/51-lenovo-tb321fu-alsa.conf"
install -Dm0644 /dev/stdin "$R/usr/share/wireplumber/wireplumber.conf.d/90-lenovo-tb321fu-alsa.conf" <<'CONF'
# Lenovo Legion Y700 Gen 3: its own profile order and the buffer sizes the
# ADSP accepts for its card (after the Pocket FIT's 53/54 rules).
monitor.alsa.rules = [
  {
    matches = [
      { alsa.card_name = "Lenovo-Y700-TB321FU" } { alsa.card_name = "Lenovo-QRD-2.0" }
      { api.alsa.card.name = "Lenovo-Y700-TB321FU" } { api.alsa.card.name = "Lenovo-QRD-2.0" }
    ]
    actions = {
      update-props = {
        api.acp.auto-profile = true
        api.acp.auto-port = true
        device.profile = "HiFi (Headphones, Mic1, Speaker)"
        api.alsa.period-size = 1024
        api.alsa.period-num = 4
        api.alsa.headroom = 0
        api.alsa.disable-tsched = false
        node.force-quantum = 1024
      }
    }
  }
]
device.profile.priority.rules = [
  {
    matches = [
      { alsa.card_name = "Lenovo-Y700-TB321FU" } { alsa.card_name = "Lenovo-QRD-2.0" }
      { api.alsa.card.name = "Lenovo-Y700-TB321FU" } { api.alsa.card.name = "Lenovo-QRD-2.0" }
    ]
    actions = {
      update-props = {
        priorities = [
          "HiFi (Headphones, Mic1, Speaker)"
          "HiFi (Headphones, Headset, Speaker)"
          "HiFi"
          "pro-audio"
        ]
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

# Touch and pen report the panel's native portrait coordinates. gamescope only
# rotates touch for I2C (internal) or USB (external) devices and these are on
# SPI, so it maps them unrotated: taps land in the wrong place in Game Mode.
# Rotate them in libinput (the matrix for DT rotation 90, "right-up").
install -Dm0644 /dev/stdin "$R/usr/lib/udev/rules.d/90-steamos-arm-tb321fu-touch.rules" <<'RULES'
# Lenovo Legion Y700 Gen 3: the touch panel reports portrait coordinates, the session runs landscape.
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="NVTCapacitiveTouchScreen", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1"
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="NVTCapacitivePen", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1"
RULES
# KWin already maps touch to the rotated output, so Desktop Mode undoes the
# udev matrix. Appended: other devices' groups in the file stay as they are.
mkdir -p "$R/etc/xdg"
grep -qs 'NVTCapacitiveTouchScreen' "$R/etc/xdg/kcminputrc" || cat >> "$R/etc/xdg/kcminputrc" <<'KCM'
# Lenovo Legion Y700 Gen 3 touch: udev rotates it for gamescope, KWin rotates it itself.
[Libinput][0][0][NVTCapacitiveTouchScreen]
CalibrationMatrix=1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1

[Libinput][0][0][NVTCapacitivePen]
CalibrationMatrix=1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1
KCM

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

# "Safely remove" on a USB drive: udisks unmounts it, then powers the port
# off, and that never returns on this tablet's USB controller: the drive
# stays at "Removing..." and the desktop shell hangs waiting for it.
# Unmounting is all a safe removal needs; skip the power-off here.
install -Dm0644 /dev/stdin "$R/usr/lib/udev/rules.d/90-steamos-arm-tb321fu-usb-storage.rules" <<'RULES'
# Lenovo Legion Y700 Gen 3: no USB power-off on safe removal (it hangs).
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", ENV{DEVTYPE}=="disk", PROGRAM="/usr/bin/grep -aq lenovo,tb321fu /sys/firmware/devicetree/base/compatible", ENV{UDISKS_CAN_POWER_OFF}="0"
# The internal UFS partitions (Android's and the system's own) out of the
# desktop's Disks & Devices list, where one tap mounts them.
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_PATH}=="*ufs*", PROGRAM="/usr/bin/grep -aq lenovo,tb321fu /sys/firmware/devicetree/base/compatible", ENV{UDISKS_IGNORE}="1"
RULES

# The cameras have no working driver on this kernel (/dev/video* fail with
# ENOMEM) and WirePlumber's v4l2 hook never completes on them, which stalls
# its event queue: no stream gets linked, no sound and no microphone. A
# profile can't be scoped to a device, so a unit gated on the tablet puts the
# override into /etc (the other devices sharing this rootfs never get it).
install -Dm0644 /dev/stdin "$R/usr/share/steamos-arm/tb321fu/52-tb321fu.conf" <<'CONF'
# Lenovo Legion Y700 Gen 3 (steamos-arm-tb321fu-setup.service): the cameras
# stall WirePlumber, and Game Mode has no xdg-desktop-portal.
wireplumber.profiles = {
  main = {
    monitor.v4l2 = disabled
    monitor.libcamera = disabled
    support.portal-permissionstore = disabled
  }
}
CONF
install -Dm0644 /dev/stdin "$R/usr/lib/systemd/system/steamos-arm-tb321fu-setup.service" <<'UNIT'
[Unit]
Description=Lenovo Legion Y700 Gen 3: audio server settings for this tablet
ConditionFirmware=device-tree-compatible(lenovo,tb321fu)
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target display-manager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/install -Dm0644 /usr/share/steamos-arm/tb321fu/52-tb321fu.conf /etc/wireplumber/wireplumber.conf.d/52-tb321fu.conf

[Install]
WantedBy=sysinit.target
UNIT
mkdir -p "$R/usr/lib/systemd/system/sysinit.target.wants"
ln -sfn ../steamos-arm-tb321fu-setup.service "$R/usr/lib/systemd/system/sysinit.target.wants/steamos-arm-tb321fu-setup.service"

# USB-C: the UCSI driver probes while the ADSP is still booting, times out
# ("PPM init failed, stop trying") and leaves no Type-C ports, roles or VBUS.
# Bind it again once the ADSP runs.
install -Dm0755 /dev/stdin "$R/usr/lib/steamos-arm/tb321fu-ucsi-rebind" <<'SH'
#!/bin/bash
for i in $(seq 1 60); do
  [ "$(cat /sys/class/remoteproc/remoteproc0/state 2>/dev/null)" = running ] && break
  sleep 1
done
sleep 8
[ -e /sys/class/typec/port0 ] && exit 0
D=/sys/bus/auxiliary/drivers/ucsi_glink.pmic_glink_ucsi
echo pmic_glink.ucsi.0 > $D/unbind 2>/dev/null || true
sleep 1
echo pmic_glink.ucsi.0 > $D/bind
SH
install -Dm0644 /dev/stdin "$R/usr/lib/systemd/system/steamos-arm-tb321fu-usb.service" <<'UNIT'
[Unit]
Description=Lenovo Legion Y700 Gen 3: bind USB-C (UCSI) again once the ADSP is up
ConditionFirmware=device-tree-compatible(lenovo,tb321fu)
After=systemd-modules-load.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/lib/steamos-arm/tb321fu-ucsi-rebind

[Install]
WantedBy=multi-user.target
UNIT
ln -sfn ../steamos-arm-tb321fu-usb.service "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-tb321fu-usb.service"

# The tablet has one USB controller for its two USB-C ports, muxed by TLMM
# GPIO 58 (pmic-glink's c2-select): left alone the data lines stay on the
# long-side charging port, so a controller or hub on the short-side port
# (the data port) was never seen. Hold the line high to route data there.
# gpioset (libgpiod 2) keeps the line for as long as it runs.
install -Dm0755 /dev/stdin "$R/usr/lib/steamos-arm/tb321fu-usb-data-port" <<'SH'
#!/bin/bash
# Lenovo Legion Y700 Gen 3: route USB data to the short-side USB-C port.
chip=$(gpiodetect | awk '/\[f100000\.pinctrl\]/ { print $1; exit }')
[ -n "$chip" ] || { echo "no TLMM gpiochip" >&2; exit 1; }
# A kernel whose UCSI driver takes c2-select-gpios (the 7.2.8 tablet kernel)
# routes the port itself.
if gpioinfo -c "$chip" 58 | grep -q 'consumer='; then
  echo "GPIO 58 is driven by the kernel" >&2
  exit 0
fi
exec gpioset -c "$chip" 58=1
SH
install -Dm0644 /dev/stdin "$R/usr/lib/systemd/system/steamos-arm-tb321fu-usb-data-port.service" <<'UNIT'
[Unit]
Description=Lenovo Legion Y700 Gen 3: USB data on the short-side USB-C port
ConditionFirmware=device-tree-compatible(lenovo,tb321fu)
StartLimitBurst=3
StartLimitIntervalSec=120

[Service]
ExecStart=/usr/lib/steamos-arm/tb321fu-usb-data-port
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
ln -sfn ../steamos-arm-tb321fu-usb-data-port.service "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-tb321fu-usb-data-port.service"

# UCSI sets the controller's role from the long-side connector: a charger or
# a PC there turns it into a device and drops whatever is on the data port.
# Put it back to host whenever something is attached to the short side.
install -Dm0755 /dev/stdin "$R/usr/lib/steamos-arm/tb321fu-usb-host" <<'SH'
#!/bin/bash
# Lenovo Legion Y700 Gen 3: host mode while the short-side port has a partner.
role=/sys/class/usb_role/a600000.usb-role-switch/role
[ -e /sys/class/typec/port1-partner ] || exit 0
sleep 2
[ "$(cat "$role")" = host ] || echo host > "$role"
SH
install -Dm0644 /dev/stdin "$R/usr/lib/systemd/system/steamos-arm-tb321fu-usb-host.service" <<'UNIT'
[Unit]
Description=Lenovo Legion Y700 Gen 3: USB host mode for the short-side USB-C port
ConditionFirmware=device-tree-compatible(lenovo,tb321fu)
After=steamos-arm-tb321fu-usb.service

[Service]
Type=oneshot
ExecStart=/usr/lib/steamos-arm/tb321fu-usb-host

[Install]
WantedBy=multi-user.target
UNIT
ln -sfn ../steamos-arm-tb321fu-usb-host.service "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-tb321fu-usb-host.service"
install -Dm0644 /dev/stdin "$R/usr/lib/udev/rules.d/91-steamos-arm-tb321fu-usb-host.rules" <<'RULES'
# Lenovo Legion Y700 Gen 3: put host mode back when a USB-C partner or the role changes.
SUBSYSTEM=="typec", KERNEL=="port[01]-partner", ACTION=="add|remove", PROGRAM="/usr/bin/grep -aq lenovo,tb321fu /sys/firmware/devicetree/base/compatible", TAG+="systemd", ENV{SYSTEMD_WANTS}+="steamos-arm-tb321fu-usb-host.service"
SUBSYSTEM=="usb_role", ACTION=="change", PROGRAM="/usr/bin/grep -aq lenovo,tb321fu /sys/firmware/devicetree/base/compatible", TAG+="systemd", ENV{SYSTEMD_WANTS}+="steamos-arm-tb321fu-usb-host.service"
RULES

# Tell the ABL each boot worked, or it gives up on the slot after 7.
O="${HERE}/../steamos-overlay"
install -Dm0755 "$O/usr/lib/steamos-arm/tablet-boot-ok" "$R/usr/lib/steamos-arm/tablet-boot-ok"
install -Dm0644 "$O/usr/lib/systemd/system/steamos-arm-tablet-boot-ok.service" "$R/usr/lib/systemd/system/steamos-arm-tablet-boot-ok.service"
ln -sfn ../steamos-arm-tablet-boot-ok.service "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-tablet-boot-ok.service"
log "firmware and audio profile installed"
