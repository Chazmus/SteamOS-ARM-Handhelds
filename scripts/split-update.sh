#!/bin/bash
# Split an update package for a GitHub release (2 GiB per asset).
#
#   split-update.sh steamos-arm-<soc>-<version>.sau
#
# Packages up to 1.9 GiB are left alone. Bigger ones become .sau.001,
# .sau.002, ... next to it, and the package itself is removed; its .sha256
# (from build-update-v2.py) stays the checksum of the whole package, which
# update-agent checks after joining the parts.
set -euo pipefail
PKG="${1:?package}"
[[ -s "$PKG" && -s "$PKG.sha256" ]] || { echo "need $PKG and $PKG.sha256" >&2; exit 1; }
LIMIT=$((1900 * 1024 * 1024))
size=$(stat -c %s "$PKG")
if (( size <= LIMIT )); then
  echo "$PKG: $((size >> 20)) MiB, one asset"
  exit 0
fi
rm -f "$PKG".[0-9][0-9][0-9]
split -b "$LIMIT" -d -a 3 --numeric-suffixes=1 "$PKG" "$PKG."
# The parts must join back to exactly the package before it goes.
want=$(cut -d' ' -f1 "$PKG.sha256")
got=$(cat "$PKG".[0-9][0-9][0-9] | sha256sum | cut -d' ' -f1)
[[ "$got" == "$want" ]] || { echo "parts don't join back to $PKG" >&2; exit 1; }
rm -f "$PKG"
ls -l "$PKG".[0-9][0-9][0-9] "$PKG.sha256"
