#!/usr/bin/env bash
# Build mangoapp (Steam's performance overlay) inside the SteamOS rootfs, so
# it links against SteamOS's glibc: MangoHud v0.8.4 + the patches in
# external-and-mods/MangoHud-qualcomm (GPU load, clock and VRAM on Adreno).
#
# Usage: build-mangohud-in-rootfs.sh <rootfs> [build-dir]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
R="$(cd "${1:?rootfs}" && pwd)"
WORKDIR="${STEAMOS_WORK:-/work}"
BUILD="${2:-${WORKDIR}/mangohud-build}"
TAG=v0.8.4
log() { printf '==> [mangohud] %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
command -v bwrap >/dev/null || die "bwrap required"
[[ -x "$R/usr/bin/gcc" && -x "$R/usr/bin/python3" ]] || die "rootfs needs gcc + python3"

T="$R/t/mangohud"                       # inside the rootfs: /t/mangohud
rm -rf "$T/src"; mkdir -p "$T"
log "MangoHud $TAG"
curl -fsSL "https://github.com/flightlessmango/MangoHud/archive/refs/tags/${TAG}.tar.gz" | tar -xz -C "$T"
mv "$T/MangoHud-${TAG#v}" "$T/src"
for p in "$ROOT/external-and-mods/MangoHud-qualcomm/patches/"*.patch; do
  log "patch $(basename "$p")"
  patch -d "$T/src" -p1 --quiet < "$p"
done
# v0.8.4 wants a newer meson than the rootfs has: a private copy for the build.
[[ -d "$T/pymeson/mesonbuild" ]] || python3 -m pip install -q --target "$T/pymeson" "meson==1.8.2"
bwrap --bind "$R" / --dev /dev --proc /proc --tmpfs /tmp --ro-bind /etc/resolv.conf /etc/resolv.conf \
  bash -c 'set -e; export PYTHONPATH=/t/mangohud/pymeson
    cd /t/mangohud/src
    rm -rf /t/mangohud/build
    python3 -m mesonbuild.mesonmain setup /t/mangohud/build --buildtype=release --prefix=/usr \
      -Dmangoapp=true -Dmangohudctl=false -Dwith_xnvctrl=disabled -Dwith_nvml=disabled \
      -Dtests=disabled -Dinclude_doc=false -Dmangoplot=disabled >/dev/null
    ninja -C /t/mangohud/build src/mangoapp'
mkdir -p "$BUILD"
install -m0755 "$T/build/src/mangoapp" "$BUILD/mangoapp"
rm -rf "$T"
log "OK: $BUILD/mangoapp"
