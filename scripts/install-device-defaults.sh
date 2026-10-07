#!/usr/bin/env bash
# Per-device defaults worked out on the device itself, for every image:
# the hostname from the model, and Desktop Mode's scale and touch mode from
# the panel (run by sm8550-startplasma on the first Desktop start).
#   install-device-defaults.sh <rootfs>
set -euo pipefail
R="${1:?usage: install-device-defaults.sh <rootfs>}"
OVL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/steamos-overlay"
install -D -m0755 "$OVL/usr/lib/steamos-arm/device-hostname" "$R/usr/lib/steamos-arm/device-hostname"
install -D -m0755 "$OVL/usr/lib/steamos-arm/desktop-fit" "$R/usr/lib/steamos-arm/desktop-fit"
install -D -m0644 "$OVL/usr/lib/systemd/system/steamos-arm-hostname.service" \
  "$R/usr/lib/systemd/system/steamos-arm-hostname.service"
mkdir -p "$R/usr/lib/systemd/system/multi-user.target.wants"
ln -sfn ../steamos-arm-hostname.service \
  "$R/usr/lib/systemd/system/multi-user.target.wants/steamos-arm-hostname.service"
echo "device defaults: hostname from the model, Desktop scale from the panel"
