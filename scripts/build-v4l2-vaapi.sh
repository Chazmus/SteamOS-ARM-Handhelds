#!/bin/bash
# Hardware video decode for VA-API apps: see external-and-mods/v4l2-vaapi.
#   OUT=/work/v4l2-vaapi-build bash scripts/build-v4l2-vaapi.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-${STEAMOS_WORK:-/work}/v4l2-vaapi-build}" bash "$ROOT/external-and-mods/v4l2-vaapi/build.sh"
