#!/bin/bash
# libgbm.so.1 shim: NV12 allocation for GBM clients on Adreno (see gbm_nv12.c).
# Ships next to a symlink libgbm-mesa.so.1 -> the real Mesa libgbm.so.1.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"
gcc -O2 -g -fPIC -shared -fvisibility=hidden -Wall -Wextra -Wl,-soname,libgbm.so.1 \
	-o "$OUT/libgbm.so.1" "$HERE/gbm_nv12.c" -ldl -lpthread
patchelf --add-needed libgbm-mesa.so.1 "$OUT/libgbm.so.1"
echo "built $OUT/libgbm.so.1"
