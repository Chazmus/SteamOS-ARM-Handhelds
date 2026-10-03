#!/usr/bin/env bash
# Emulator Hub on every image: the engine, its command, and the Decky panel
# that is its front end on devices with one screen (the Thor's bottom screen
# has its own page too). Called by each apply-overlays script.
#   install-hub.sh <rootfs> [<home of the default user in the image>]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="${1:?rootfs}"
HOME_DST="${2:-}"
OVL="${ROOT}/steamos-overlay"
SRC="${ROOT}/external-and-mods/Decky/common/emulator-hub"

install -d -m0755 "$R/usr/lib/steamos-arm/hub"
install -m0755 "$OVL/usr/lib/steamos-arm/hub/hub.py" "$R/usr/lib/steamos-arm/hub/hub.py"
install -m0644 "$OVL/usr/lib/steamos-arm/hub/catalog.json" "$R/usr/lib/steamos-arm/hub/catalog.json"
install -m0755 "$OVL/usr/bin/steamos-arm-hub" "$R/usr/bin/steamos-arm-hub"

# The panel goes where Decky's bundled plugins are synced from, and straight
# into the user's plugins when the image has a home to seed.
BUNDLE="$R/usr/share/steamos-odin/decky-plugins/emulator-hub"
rm -rf "$BUNDLE"; install -d "$BUNDLE/dist"
install -m0644 "$SRC/plugin.json" "$SRC/main.py" "$SRC/package.json" "$BUNDLE/"
install -m0644 "$SRC/dist/index.js" "$BUNDLE/dist/"
if [[ -n "$HOME_DST" && -d "$HOME_DST" ]]; then
  DST="$HOME_DST/homebrew/plugins/emulator-hub"
  rm -rf "$DST"; mkdir -p "$DST"
  cp -a "$BUNDLE/." "$DST/"
  chown -R 1000:1000 "$HOME_DST/homebrew"
fi
echo "Emulator Hub installed"
