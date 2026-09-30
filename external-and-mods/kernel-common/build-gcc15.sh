#!/usr/bin/env bash
# Run build.sh inside a Fedora 43 container, which has GCC 15. Same
# arguments as build.sh, e.g. for the 8 Gen 2 test kernel on 7.2:
#   SM8550_RECIPE=7.2 bash external-and-mods/kernel-common/build-gcc15.sh sm8550
# The port tree, WORK and the ROCKNIX checkout all have to be under MOUNT
# (default /work), which is mounted at the same path in the container.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-fedora:43}"
MOUNT="${MOUNT:-/work}"
BUSYBOX="${BUSYBOX:-/bin/busybox}"
[[ "$HERE" == "$MOUNT"/* ]] || { echo "$HERE is not under $MOUNT" >&2; exit 1; }
[[ -x "$BUSYBOX" ]] || { echo "no static busybox at $BUSYBOX" >&2; exit 1; }

PKGS="file gcc make bc bison flex python3 curl tar xz gzip cpio kmod patch perl rsync
      openssl-devel elfutils-libelf-devel dwarves diffutils findutils hostname which git"
env_args=()
for v in SM8550_RECIPE WORK ROCKNIX_DIR JOBS OUT_BASE LOCALVERSION DTBS_OVERRIDE; do
  [[ -n "${!v:-}" ]] && env_args+=(-e "$v=${!v}")
done
exec docker run --rm -v "$MOUNT:$MOUNT" -v "$BUSYBOX:/bin/busybox:ro" "${env_args[@]}" \
  "$IMAGE" bash -c "
    set -e
    dnf -q -y install $(echo $PKGS) >/dev/null
    git config --global --add safe.directory '*'
    gcc --version | head -1
    exec bash '$HERE/build.sh' $*"
