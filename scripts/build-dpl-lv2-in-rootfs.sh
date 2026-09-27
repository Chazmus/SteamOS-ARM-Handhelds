#!/usr/bin/env bash
# Build x42's Digital Peak Limiter (dpl.lv2, GPL-2.0) inside the Frame rootfs
# for the Pocket FIT speaker chain (sm8650-overlay/usr/share/pipewire/
# konkr-speaker.conf). Plugin only: no GUI, no JACK app.
#
# Usage: build-dpl-lv2-in-rootfs.sh <rootfs>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$(cd "${1:?rootfs}" && pwd)"
WORKDIR="${STEAMOS_WORK:-/work}"
SRC="${WORKDIR}/dpl.lv2"
REF="8bcd25d"            # v0.7.3
ROBTK_REF="c6c3ade30b1cffb12e4cd6eda5a46bf1c96cb318"

log() { printf '==> [dpl.lv2] %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v bwrap >/dev/null || die "bwrap required (apt install bubblewrap)"
[[ -x "$R/usr/bin/gcc" && -x "$R/usr/bin/make" ]] \
  || die "rootfs needs gcc+make (scripts/install-build-deps-in-rootfs.sh)"

if [[ ! -f "$SRC/Makefile" ]]; then
  log "cloning x42/dpl.lv2"
  git clone -q https://github.com/x42/dpl.lv2.git "$SRC"
fi
git -C "$SRC" fetch -q origin 2>/dev/null || true
git -C "$SRC" checkout -q "$REF"
git -C "$SRC" submodule update -q --init
[[ "$(git -C "$SRC" rev-parse HEAD:robtk)" == "$ROBTK_REF" ]] || die "unexpected robtk ref"

run() {
  bwrap --bind "$R" / \
    --bind /tmp /tmp \
    --bind "$SRC" /src/dpl \
    --dev /dev --proc /proc --tmpfs /run \
    --unshare-pid --die-with-parent --chdir /src/dpl \
    "$@"
}

log "build (aarch64, against the rootfs)"
run /usr/bin/make clean >/dev/null
run /usr/bin/make -j"$(nproc)" BUILDOPENGL=no BUILDJACKAPP=no \
  OPTIMIZATIONS="-O2 -ffast-math -fomit-frame-pointer" LV2DIR=/usr/lib/lv2
log "install into $R/usr/lib/lv2/dpl.lv2"
rm -rf "$R/usr/lib/lv2/dpl.lv2"
run /usr/bin/make install BUILDOPENGL=no BUILDJACKAPP=no LV2DIR=/usr/lib/lv2 PREFIX=/usr
install -Dm0644 "$SRC/COPYING" "$R/usr/share/licenses/dpl.lv2/COPYING"
ls "$R/usr/lib/lv2/dpl.lv2"
