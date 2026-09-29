#!/usr/bin/env bash
# Apply the AYN Odin 3 (SM8750) handheld overlay onto the extracted SteamOS Frame rootfs.
# Mesa: ships Freedreno / Turnip Adreno 830 Vulkan driver.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKDIR="${STEAMOS_WORK:-${ROOT}/sm8750-work}"
R="${STEAMOS_ROOTFS:-${WORKDIR}/rootfs}"
MOD="${ROOT}/external-and-mods"
OVL="${ROOT}/steamos-overlay"
SM8750_OVL="${ROOT}/sm8750-overlay"
KOUT="$(readlink -f "${KERNEL_OUT:-${WORKDIR}/kernel-sm8750-release/7.2.0}")"
KREL="7.2.0"
STOCK="${R}/opt/stock-steamos"
MESA_SO="${SM8750_MESA_SO:-${SM8750_OVL}/usr/lib/libvulkan_freedreno.so}"
LOG="${WORKDIR}/odin3-apply.log"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "$*" | tee -a "$LOG"; }

[[ -d "$R/usr/bin" ]] || die "missing rootfs at $R"
[[ -f "$KOUT/boot/KERNEL" ]] || die "missing kernel at $KOUT/boot/KERNEL"
[[ -d "$KOUT/modules/$KREL" ]] || die "missing modules at $KOUT/modules/$KREL"
[[ -d "$KOUT/firmware" ]] || die "missing firmware at $KOUT/firmware"

: >"$LOG"
log "== $(date -Iseconds) apply Odin 3 mods into $R"

backup() {
  local src="$1" dest="$2"
  [[ -e "$src" ]] || return 0
  mkdir -p "$(dirname "$dest")"
  if [[ ! -e "$dest" ]]; then
    cp -a "$src" "$dest"
  fi
}

install_file() {
  local src="$1" dest="$2" mode="${3:-}"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  [[ -n "$mode" ]] && chmod "$mode" "$dest"
}

# ---------------------------------------------------------------------------
# 1. Kernel, Modules & Firmware
# ---------------------------------------------------------------------------
log "== staging kernel ${KREL}"
mkdir -p "$R/boot" "$R/usr/lib/modules" "$R/usr/lib/firmware" "$R/opt/steamos-sm8750"
if [[ -e "$R/boot/KERNEL" && ! -e "$STOCK/boot/KERNEL" ]]; then
  mkdir -p "$STOCK/boot"
  cp -a "$R/boot/KERNEL" "$STOCK/boot/KERNEL" 2>/dev/null || true
fi
cp -a "$KOUT/boot/KERNEL" "$R/boot/KERNEL"
cp -a "$KOUT/boot/KERNEL.md5" "$R/boot/KERNEL.md5"
chmod 0644 "$R/boot/KERNEL" "$R/boot/KERNEL.md5"

# Clean out old Frame modules and install SM8750 modules
find "$R/usr/lib/modules" -mindepth 1 -maxdepth 1 ! -name "$KREL" -exec rm -rf {} + 2>/dev/null || true
cp -a "$KOUT/modules/$KREL" "$R/usr/lib/modules/$KREL"

# Merge SM8750 firmware
cp -a "$KOUT/firmware/." "$R/usr/lib/firmware/"

# ---------------------------------------------------------------------------
# 2. Gamescope (SM8750 aarch64 build)
# ---------------------------------------------------------------------------
log "== gamescope binaries"
for b in gamescope gamescopectl gamescopereaper gamescopestream; do
  if [[ -f "$SM8750_OVL/usr/bin/$b" ]]; then
    backup "$R/usr/bin/$b" "$STOCK/usr/bin/$b"
    install_file "$SM8750_OVL/usr/bin/$b" "$R/usr/bin/$b" 0755
    install_file "$SM8750_OVL/usr/bin/$b" "$R/usr/local/bin/$b" 0755
  fi
done

if [[ -d "${MOD}/gamescope/scripts" ]]; then
  mkdir -p "$R/usr/share/gamescope" "$R/usr/local/share/gamescope"
  cp -a "${MOD}/gamescope/scripts" "$R/usr/share/gamescope/"
  cp -a "${MOD}/gamescope/scripts" "$R/usr/local/share/gamescope/"
fi

# ---------------------------------------------------------------------------
# 3. Base SteamOS Overlay (Session, Desktop, Services)
# ---------------------------------------------------------------------------
log "== base steamos overlay"
backup "$R/usr/lib/steamos/gamescope-session" "$STOCK/usr/lib/steamos/gamescope-session"
install_file "$OVL/usr/lib/steamos/gamescope-session" \
  "$R/usr/lib/steamos/gamescope-session" 0755
install_file "$OVL/usr/lib/steamos/panel-modes" \
  "$R/usr/lib/steamos/panel-modes" 0755
install_file "$OVL/usr/lib/steamos/desktop-outputs" \
  "$R/usr/lib/steamos/desktop-outputs" 0755
backup "$R/usr/lib/steamos/gamescope-onready" "$STOCK/usr/lib/steamos/gamescope-onready"
install_file "$OVL/usr/lib/steamos/gamescope-onready" \
  "$R/usr/lib/steamos/gamescope-onready" 0755
install_file "$OVL/usr/lib/steamos/sm8550-steam-focus" \
  "$R/usr/lib/steamos/sm8550-steam-focus" 0755
install_file "$OVL/usr/lib/steamos/sm8550-volume-keys" \
  "$R/usr/lib/steamos/sm8550-volume-keys" 0755
install_file "$OVL/usr/lib/steamos/odin-bin/steamvr" \
  "$R/usr/lib/steamos/odin-bin/steamvr" 0755
backup "$R/usr/bin/steamos-select-branch" "$STOCK/usr/bin/steamos-select-branch"
install_file "$OVL/usr/bin/steamos-select-branch" \
  "$R/usr/bin/steamos-select-branch" 0755

# Desktop Plasma
install_file "$OVL/usr/lib/steamos/sm8550-prepare-plasma" \
  "$R/usr/lib/steamos/sm8550-prepare-plasma" 0755
install_file "$OVL/usr/lib/steamos/sm8550-startplasma" \
  "$R/usr/lib/steamos/sm8550-startplasma" 0755
backup "$R/usr/bin/steamos-session-select" "$STOCK/usr/bin/steamos-session-select"
install_file "$OVL/usr/bin/steamos-session-select" \
  "$R/usr/bin/steamos-session-select" 0755
backup "$R/usr/share/wayland-sessions/plasma.desktop" \
  "$STOCK/usr/share/wayland-sessions/plasma.desktop"
install_file "$OVL/usr/share/wayland-sessions/plasma.desktop" \
  "$R/usr/share/wayland-sessions/plasma.desktop" 0644
install_file "$OVL/usr/lib/systemd/user/sm8550-plasma-env.service" \
  "$R/usr/lib/systemd/user/sm8550-plasma-env.service" 0644

# Clean handheld RUNSTEAM.sh (handheld flags only, no VR headset flags)
backup "$R/usr/share/deckard/RUNSTEAM.sh" "$STOCK/usr/share/deckard/RUNSTEAM.sh"
install_file "$OVL/usr/share/deckard/RUNSTEAM.sh" \
  "$R/usr/share/deckard/RUNSTEAM.sh" 0755

# Systemd user drop-ins (includes 99-odin.conf with TimeoutStartSec=600, BindsTo gamescope, etc.)
if [[ -d "$OVL/usr/lib/systemd/user" ]]; then
  mkdir -p "$R/usr/lib/systemd/user"
  cp -a "$OVL/usr/lib/systemd/user/." "$R/usr/lib/systemd/user/"
fi

# Expand home partition service on first boot
install_file "$OVL/usr/lib/steamos/steamos-sm8550-expand-home" \
  "$R/usr/lib/steamos/steamos-sm8550-expand-home" 0755
install_file "$OVL/usr/lib/systemd/system/steamos-sm8550-expand-home.service" \
  "$R/usr/lib/systemd/system/steamos-sm8550-expand-home.service" 0644
mkdir -p "$R/etc/systemd/system/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/steamos-sm8550-expand-home.service \
  "$R/etc/systemd/system/multi-user.target.wants/steamos-sm8550-expand-home.service"

# VR crash services cleanup (disable Valve Headset daemons)
for svc in \
  vrcompositor.service vrserver.service steamos-headset-adb.service \
  steamos-headset-adb.path steamos-headset-usb-gadget.service \
  steamos-headset-usb-gadget.path deckard-factory-recovery.service \
  steamos-headset-fpga-config.service steamos-power-monitor.service \
  deckard-boot-images.service deckard-fan-control.service \
  deckard-fpga.service deckard-led-control.service \
  deckard-typec-logger.service dsp_service.service \
  iris-driver-rebind.service steamvr-program-ble.service \
  steamvr-set-kernel-thread-priorities.service \
  steamvr-v4l2loopback.service deckard-charger.service \
  deckard-power-monitor.service adbd.service adbd-pre.service \
  adbd-post.service usb-gadget.target usb-gadget.service \
  usb-gadget-init.service 'usb-ncm-gadget@.service' \
  'usb-ncm-dnsmasq@.service' 'usb-ncm-gadget@usb0.service' \
  'usb-ncm-dnsmasq@usb0.service'
do
  rm -f "$R/etc/systemd/system/multi-user.target.wants/${svc}" \
        "$R/etc/systemd/system/default.target.wants/${svc}" \
        "$R/etc/systemd/user/default.target.wants/${svc}" 2>/dev/null || true
  mkdir -p "$R/etc/systemd/system"
  ln -sfn /dev/null "$R/etc/systemd/system/${svc}"
done

# Set boot target to graphical.target (SDDM autologin into Gamescope)
mkdir -p "$R/etc/systemd/system"
ln -sfn /usr/lib/systemd/system/graphical.target "$R/etc/systemd/system/default.target"

# User-level service masking (steamos-manager requires tracefs not in 7.2.0; steamvr services)
mkdir -p "$R/etc/systemd/user"
for usvc in steamvr.service steamvr-proxmicmute.service steamvr-v4l2cam.service \
            steamos-manager.service steamos-manager-session-cleanup.service \
            sm8550-audio-pipewire.service; do
  ln -sfn /dev/null "$R/etc/systemd/user/${usvc}"
done
rm -f "$R/etc/systemd/user/wireplumber.service" "$R/etc/systemd/user/sm8550-volume-keys.service" 2>/dev/null || true

# Volume keys daemon for Odin 3 (handles gpio-keys VOLUP and pmic_resin VOLDOWN)
mkdir -p "$R/usr/lib/systemd/user/default.target.wants" "$R/etc/systemd/user/default.target.wants"
ln -sfn /usr/lib/systemd/user/sm8550-volume-keys.service \
  "$R/usr/lib/systemd/user/default.target.wants/sm8550-volume-keys.service"
ln -sfn /usr/lib/systemd/user/sm8550-volume-keys.service \
  "$R/etc/systemd/user/default.target.wants/sm8550-volume-keys.service"

# Disable steamos-log-submitter to prevent coredump storm on errors
mkdir -p "$R/etc/systemd/system"
ln -sfn /dev/null "$R/etc/systemd/system/steamos-log-submitter.service"

# User 'steamos' in seat group (GID 974) for seatd / DRM master
if grep -q '^seat:' "$R/etc/group" 2>/dev/null; then
  sed -i '/^seat:/ s/$/,steamos/; s/:,/:/' "$R/etc/group"
else
  echo "seat:x:974:steamos" >> "$R/etc/group"
fi

# Passwordless sudo for steamos user
mkdir -p "$R/etc/sudoers.d"
echo 'steamos ALL=(ALL) NOPASSWD: ALL' > "$R/etc/sudoers.d/99-steamos-nopasswd"
chmod 0440 "$R/etc/sudoers.d/99-steamos-nopasswd"

# Low-latency SSH (disable reverse DNS lookup timeout) and enable sshd
mkdir -p "$R/etc/ssh/sshd_config.d"
echo "UseDNS no" > "$R/etc/ssh/sshd_config.d/99-odin-dns.conf"
mkdir -p "$R/etc/systemd/system/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/sshd.service "$R/etc/systemd/system/multi-user.target.wants/sshd.service"

# Disable core dump loops from crashing VR audio plugins
mkdir -p "$R/etc/sysctl.d"
echo "kernel.core_pattern = |/bin/false" > "$R/etc/sysctl.d/99-disable-coredump.conf"
cat <<'SYSCTL' >"$R/etc/sysctl.d/99-sm8750-io.conf"
# SD card writeback tuning: batch dirty page flushes to eliminate random I/O stalls
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000
SYSCTL

# Clean up Deckard VR headset WirePlumber configs and SteamVR dependency
# Stock Deckard VR configs (40-mic-processing, 60-spatial-audio, etc.) crash WirePlumber with SIGSEGV
# because the VR multi-mic beamforming array and spatializer hardware do not exist on Odin 3.
# Removing them lets WirePlumber use standard ALSA UCM device discovery in /usr/share/wireplumber/.
rm -f "$R/usr/lib/systemd/user/wireplumber.service.d/wireplumber-steamvr.conf" 2>/dev/null || true
if [[ -d "$R/etc/wireplumber/wireplumber.conf.d" ]]; then
  rm -rf "$R/etc/wireplumber/wireplumber.conf.d"
  mkdir -p "$R/etc/wireplumber/wireplumber.conf.d"
fi

# Enable persistent journal logging and boot debug
mkdir -p "$R/var/log/journal" "$R/etc/systemd/journald.conf.d"
chmod 2755 "$R/var/log/journal" 2>/dev/null || true
cat <<'JRNL' >"$R/etc/systemd/journald.conf.d/99-persist.conf"
[Journal]
Storage=persistent
SyncIntervalSec=5s
JRNL

# ---------------------------------------------------------------------------
# 4. Turnip / Mesa Driver (Adreno 830)
# ---------------------------------------------------------------------------
if [[ -f "$MESA_SO" ]]; then
  log "== Turnip Adreno 830 Vulkan driver ($MESA_SO)"
  backup "$R/usr/lib/libvulkan_freedreno.so" "$STOCK/usr/lib/libvulkan_freedreno.so"
  install_file "$MESA_SO" "$R/usr/lib/libvulkan_freedreno.so" 0755
fi
if [[ -f "$SM8750_OVL/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json" ]]; then
  install_file "$SM8750_OVL/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json" \
    "$R/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json" 0644
fi

# ---------------------------------------------------------------------------
# 5. Odin 3 Overlay (InputPlumber, Display, Audio, Device Manager)
# ---------------------------------------------------------------------------
log "== SM8750 Odin 3 overlay"
cp -r --no-preserve=mode,ownership "$SM8750_OVL/." "$R/"
chmod 0755 "$R/usr/lib/steamos/sm8750-audio-setup" 2>/dev/null || true

# Audio setup service
mkdir -p "$R/etc/systemd/system/multi-user.target.wants"
cat <<'UNIT' >"$R/etc/systemd/system/sm8750-audio-setup.service"
[Unit]
Description=AYN Odin 3 Audio Setup
After=sound.target

[Service]
Type=oneshot
ExecStart=/usr/lib/steamos/sm8750-audio-setup
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
ln -sfn /etc/systemd/system/sm8750-audio-setup.service \
  "$R/etc/systemd/system/multi-user.target.wants/sm8750-audio-setup.service"

# Permissions
find "$R/usr/share/alsa/ucm2/AYN/Odin3" "$R/usr/share/alsa/ucm2/conf.d/sm8750" \
  -type d -exec chmod 0755 {} + 2>/dev/null || true
find "$R/usr/share/alsa/ucm2/AYN/Odin3" "$R/usr/share/alsa/ucm2/conf.d/sm8750" \
  -type f -exec chmod 0644 {} + 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. User Home / Decky Loader
# ---------------------------------------------------------------------------
log "== home/steamos setup"
HOME_DST="${STEAMOS_HOME:-$R/home/steamos}"
mkdir -p "$HOME_DST/.cache" "$HOME_DST/.config" "$HOME_DST/homebrew/services"

DECKY_VERSION=v3.2.9
DECKY_LOADER="${MOD}/Decky/loader/PluginLoader-${DECKY_VERSION}"
if [[ ! -s "$DECKY_LOADER" ]]; then
  mkdir -p "${DECKY_LOADER%/*}"
  curl -fL -o "$DECKY_LOADER.part" \
    "https://github.com/SteamDeckHomebrew/decky-loader/releases/download/${DECKY_VERSION}/PluginLoader" &&
    mv "$DECKY_LOADER.part" "$DECKY_LOADER"
fi
if [[ -s "$DECKY_LOADER" ]]; then
  install -m0755 "$DECKY_LOADER" "$HOME_DST/homebrew/services/PluginLoader"
  printf '%s' "$DECKY_VERSION" >"$HOME_DST/homebrew/services/.loader.version"
  mkdir -p "$R/usr/lib/systemd/system/multi-user.target.wants"
  ln -sfn ../plugin_loader.service "$R/usr/lib/systemd/system/multi-user.target.wants/plugin_loader.service" 2>/dev/null || true
fi

# Steam client seed and desktop theme
if [[ -f "$R/etc/xdg/kdeglobals" ]]; then
  sed -i 's/^LookAndFeelPackage=.*/LookAndFeelPackage=com.valve.vapor.deck.desktop/' "$R/etc/xdg/kdeglobals"
fi

# Ensure correct root and user permissions across /usr and /etc
find "$R/usr" "$R/etc" -xdev \( -uid +999 -o -gid +999 \) -exec chown -h root:root {} + 2>/dev/null || true

log "== SM8750 overlays successfully applied"
