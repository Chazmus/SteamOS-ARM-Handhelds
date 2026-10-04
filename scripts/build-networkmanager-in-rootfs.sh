#!/usr/bin/env bash
# Build the Frame's own NetworkManager (1.52.1, Valve's Holo package) with
# Valve's resume patch from their newer Deck build (1.58.0-1.9): after sleep
# NetworkManager scans only the channel it was on instead of every band.
# Pocket FIT: Wi-Fi back 0.95 s after wake instead of 9.3 s (DFS channel).
#
# Only the daemon and the Wi-Fi device plugin are replaced; both come from
# the same source, version string and feature options as the stock package,
# so every stock plugin keeps loading (the daemon exports the same symbols).
#
# Usage: build-networkmanager-in-rootfs.sh <rootfs> [out-dir]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
R="$(cd "${1:?rootfs}" && pwd)"
WORKDIR="${STEAMOS_WORK:-/work}"
OUT="${2:-${WORKDIR}/networkmanager-build}"
VER=1.52.1 REL=1.1 PPP=2.5.0
SRC_URL="https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/holo-main/networkmanager-${VER}-${REL}.src.tar.gz"
log() { printf '==> [networkmanager] %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
command -v bwrap >/dev/null || die "bwrap required"
[[ -x "$R/usr/bin/gcc" && -x "$R/usr/bin/meson" ]] || die "rootfs needs gcc + meson"
[[ -d "$R/usr/lib/NetworkManager/${VER}-${REL}" ]] || die "rootfs NetworkManager is not ${VER}-${REL}, update VER/REL"

T="$R/t/nm"
rm -rf "$T"; mkdir -p "$T"
log "Valve's source package ${VER}-${REL}"
curl -fsSL "$SRC_URL" | tar -xz -C "$T"
git clone -q "$T/networkmanager/NetworkManager" "$T/src"
git -C "$T/src" checkout -q "$VER"
for p in "$ROOT/external-and-mods/NetworkManager/patches/"*.patch; do
  log "patch $(basename "$p")"
  patch -d "$T/src" -Np1 --quiet < "$p"
done
# pppd headers (the rootfs has the plugin dir but no headers) for the same
# PPP support as the stock build.
log "ppp ${PPP} headers"
curl -fsSL "https://github.com/ppp-project/ppp/archive/refs/tags/v${PPP}.tar.gz" | tar -xz -C "$T"
bwrap --bind "$R" / --dev /dev --proc /proc --tmpfs /tmp bash -c "set -e
  cd /t/nm/ppp-${PPP}; (autoreconf -fi || ./autogen.sh) >/dev/null 2>&1
  ./configure --prefix=/usr >/dev/null; make -C pppd pppdconf.h >/dev/null 2>&1 || true
  test -f pppd/pppdconf.h"
mkdir -p "$T/inc/pppd" "$T/pc"
cp "$T/ppp-${PPP}/pppd/"*.h "$T/inc/pppd/"
printf 'prefix=/usr\nincludedir=/t/nm/inc\nName: pppd\nDescription: ppp headers\nVersion: %s\nCflags: -I${includedir}\n' "$PPP" >"$T/pc/pppd.pc"

log "build (stock package options, without docs/introspection/LTO)"
bwrap --bind "$R" / --dev /dev --proc /proc --tmpfs /tmp bash -c "set -e
  export PKG_CONFIG_PATH=/t/nm/pc; cd /t/nm/src
  meson setup /t/nm/build --prefix=/usr --libexecdir=lib --sbindir=bin --buildtype=plain \
    -Dc_args='-O2 -pipe' -Ddist_version=${VER}-${REL} -Dsession_tracking_consolekit=false \
    -Dsuspend_resume=systemd -Dmodify_system=true -Dselinux=false -Diwd=true -Dteamdctl=true \
    -Dconfig_plugins_default=keyfile -Difupdown=false -Dnetconfig=no \
    -Dconfig_dns_rc_manager_default=symlink -Dvapi=false -Ddocs=false -Dintrospection=false \
    -Dmore_asserts=no -Dmore_logging=false -Dqt=false -Dtests=no \
    -Dpppd=/usr/bin/pppd -Dpppd_plugin_dir=/usr/lib/pppd/${PPP} >/dev/null
  ninja -C /t/nm/build src/core/NetworkManager src/core/devices/wifi/libnm-device-plugin-wifi.so >/dev/null"

# Every symbol the stock daemon exports must still be there for its plugins.
missing="$(comm -23 <(nm -D --defined-only "$R/usr/bin/NetworkManager" | awk '{print $3}' | sort) \
                    <(nm -D --defined-only "$T/build/src/core/NetworkManager" | awk '{print $3}' | sort) | wc -l)"
[[ "$missing" == 0 ]] || die "daemon lacks ${missing} symbols the stock plugins use"
mkdir -p "$OUT"
install -m0755 "$T/build/src/core/NetworkManager" "$OUT/NetworkManager"
install -m0755 "$T/build/src/core/devices/wifi/libnm-device-plugin-wifi.so" "$OUT/libnm-device-plugin-wifi.so"
strip --strip-unneeded "$OUT/NetworkManager" "$OUT/libnm-device-plugin-wifi.so"
echo "${VER}-${REL}" >"$OUT/VERSION"
rm -rf "$T"
log "OK: $OUT"
