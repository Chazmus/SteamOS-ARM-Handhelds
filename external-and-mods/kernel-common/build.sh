#!/usr/bin/env bash
# Kernel for SteamOS ARM, one build per SoC:
#   bash external-and-mods/kernel-common/build.sh sm8650|sm8550
# (external-and-mods/kernel-<soc>/build.sh does the same).
#
# Sources (pinned in kernel-<soc>/soc.env):
#   linux-${KVER}             kernel.org
#   ROCKNIX distribution      per-SoC patches, DTS, kernel config
#   ROCKNIX extra-firmware    vendor-signed ADSP/CDSP/zap, WCN7850, audio tplg
#   linux-firmware            Adreno microcode where ROCKNIX takes it from upstream
#   ROCKNIX chipone_tddi      out-of-tree touchscreen driver
# Our own patches/DTS appends live in kernel-<soc>/{patches,dts}, the SteamOS
# config fragment (steamos.config) and initramfs are shared.
#
# Output: output/<release>/{boot/KERNEL, modules/<release>, firmware/}
#
# KERNEL is a ROCKNIX-ABL bootimg (header v0): gzip(Image) + appended DTBs
# + a busybox initramfs (initramfs/init), as the bootimg ramdisk or, with
# EMBED_INITRAMFS=1 in soc.env, built into the Image like ROCKNIX does. ABL v1.1.8+ reads `model` from each
# DTB and boots the one matching "Set device model".
# The image builder patches the real root=PARTUUID= into the cmdline.
#
# Must run on aarch64 Linux (native build). Tested host: Ubuntu 24.04 in Colima.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT_ROOT="$(cd "${HERE}/../.." && pwd)"

SOC_ARG="${1:-}"
[[ "$SOC_ARG" =~ ^sm[0-9]+$ ]] || { echo "usage: $0 <sm8650|sm8550> [--repack-boot]" >&2; exit 2; }
shift
SOC_DIR="${PORT_ROOT}/external-and-mods/kernel-${SOC_ARG}"
[[ -f "${SOC_DIR}/soc.env" ]] || { echo "no ${SOC_DIR}/soc.env" >&2; exit 2; }
# shellcheck source=../kernel-sm8650/soc.env
source "${SOC_DIR}/soc.env"

LOCALVERSION="${LOCALVERSION:--${SOC}-steamos}"
ROCKNIX_DIR="${ROCKNIX_DIR:-${PORT_ROOT}/../rocknix-${ROCKNIX_REF}}"
TDDI_REF="${TDDI_REF:-af27029fa2b27c4a77d16809298ed5d03c9da5a6}"
DTBS="${DTBS_OVERRIDE:-$DTBS}"

WORK="${WORK:-/work/kernel-${SOC}}"
CACHE="${WORK}/cache"
SRC="${WORK}/linux-${KVER}"
OUT_BASE="${OUT_BASE:-${WORK}/output}"
JOBS="${JOBS:-$(nproc)}"

log() { printf '[kernel-%s] %s\n' "$SOC" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

[[ "$(uname -m)" == aarch64 ]] || die "build on aarch64 Linux (Colima VM), not $(uname -m)"

check_deps() {
  local missing=() c
  for c in make gcc bc bison flex python3 curl tar xz gzip cpio kmod patch perl rsync; do
    command -v "$c" >/dev/null || missing+=("$c")
  done
  [[ -f /usr/include/openssl/ssl.h ]] || missing+=(libssl-dev)
  [[ -f /usr/include/gelf.h ]] || missing+=(libelf-dev)
  if ((${#missing[@]})); then
    die "missing: ${missing[*]}  (sudo apt-get install -y build-essential bc bison flex libssl-dev libelf-dev python3 curl xz-utils cpio kmod patch rsync dwarves)"
  fi
}

fetch() {
  local url="$1" dest="$2"
  [[ -s "$dest" ]] && return 0
  mkdir -p "$(dirname "$dest")"
  log "download ${url}"
  curl -fL --retry 3 -o "${dest}.part" "$url"
  mv -f "${dest}.part" "$dest"
}

rocknix_path() { echo "${ROCKNIX_DIR}/$1"; }

prepare_source() {
  if [[ -e "$ROCKNIX_DIR/.git" ]]; then  # a directory, or a file in a worktree
    [[ "$(git -C "$ROCKNIX_DIR" rev-parse HEAD)" == "$(git -C "$ROCKNIX_DIR" rev-parse "${ROCKNIX_REF}^{commit}")" ]] || die "ROCKNIX checkout does not match pinned ${ROCKNIX_REF}"
  else
    die "ROCKNIX source needs Git metadata to verify the pinned revision"
  fi
  local tarball="${CACHE}/linux-${KVER}.tar.xz"
  fetch "https://cdn.kernel.org/pub/linux/kernel/v${KVER%%.*}.x/linux-${KVER}.tar.xz" "$tarball"
  local patch_digest
  patch_digest="$( { echo "$PATCH_DIRS ${PATCH_SKIP:-}"; find "${SOC_DIR}" -path "${SOC_DIR}/patches/*" -type f -o -path "${SOC_DIR}/dts/*" -type f | sort | xargs -r sha256sum | cut -d" " -f1; } | sha256sum | cut -d" " -f1)"
  if [[ -f "${SRC}/.${SOC}-patched" && "$(cat "${SRC}/.${SOC}-patched")" == "$patch_digest" ]]; then
    log "source already patched: ${SRC}"
    return 0
  fi
  rm -rf "$SRC"
  mkdir -p "$WORK"
  log "extract linux-${KVER}"
  tar -C "$WORK" -xf "$tarball"

  # ROCKNIX patch dirs in soc.env order, then ours.
  local d p
  local -a dirs
  read -ra dirs <<<"$PATCH_DIRS"
  dirs+=("@port")
  for d in "${dirs[@]}"; do
    local pdir
    if [[ "$d" == "@port" ]]; then pdir="${SOC_DIR}/patches"; else pdir="$(rocknix_path "$d")"; fi
    [[ -d "$pdir" ]] || { log "skip missing patch dir $d"; continue; }
    for p in "$pdir"/*.patch; do
      [[ -e "$p" ]] || continue
      case "$(basename "$p")" in
        9900-i915-10bit-hack.patch) continue ;;  # x86 only
      esac
      if [[ " ${PATCH_SKIP:-} " == *" $(basename "$p") "* ]]; then
        log "skip $(basename "$p") (PATCH_SKIP)"; continue
      fi
      log "patch $(basename "$d")/$(basename "$p")"
      patch -d "$SRC" -p1 -N --no-backup-if-mismatch -s <"$p" \
        || die "patch failed: $p"
    done
  done

  log "install ROCKNIX ${ROCKNIX_DEVICE} DTS"
  cp -v "$(rocknix_path "projects/ROCKNIX/devices/${ROCKNIX_DEVICE}/linux/dts/qcom")"/*.dts* \
    "${SRC}/arch/arm64/boot/dts/qcom/" >&2
  local app
  for app in "${SOC_DIR}"/dts/*.append; do
    [[ -e "$app" ]] || continue
    log "append $(basename "$app")"
    # <name>.dts.append goes onto <name>.dts (this used to write <name>.dts.dts,
    # which nothing compiles: the Thor fixes never made it in).
    local target="${SRC}/arch/arm64/boot/dts/qcom/$(basename "$app" .append)"
    [[ -f "$target" ]] || die "append target missing: $target"
    cat "$app" >>"$target"
  done
  local mk="${SRC}/arch/arm64/boot/dts/qcom/Makefile" dtb
  for dtb in $DTBS; do
    grep -q "${dtb}.dtb" "$mk" || echo "dtb-\$(CONFIG_ARCH_QCOM) += ${dtb}.dtb" >>"$mk"
  done
  printf "%s\n" "$patch_digest" > "${SRC}/.${SOC}-patched"
}

stage_builtin_firmware() {
  # GPU microcode + zap and the regulatory db are needed before the rootfs
  # is mounted, so they go into the kernel image (like ROCKNIX does).
  local fwtar="${CACHE}/extra-firmware-${EXTRA_FW_REF}.tar.gz"
  fetch "https://github.com/ROCKNIX/extra-firmware/archive/${EXTRA_FW_REF}.tar.gz" "$fwtar"
  EXTRA_FW_SRC="${WORK}/extra-firmware"
  if [[ ! -d "${EXTRA_FW_SRC}/${ROCKNIX_DEVICE}" || "$(cat "${EXTRA_FW_SRC}/.ref" 2>/dev/null)" != "$EXTRA_FW_REF" ]]; then
    rm -rf "$EXTRA_FW_SRC"; mkdir -p "$EXTRA_FW_SRC"
    tar -C "$EXTRA_FW_SRC" --strip-components=1 -xzf "$fwtar"
    echo "$EXTRA_FW_REF" >"${EXTRA_FW_SRC}/.ref"
  fi
  local regdb="${CACHE}/wireless-regdb"
  if [[ ! -f "${regdb}/regulatory.db" ]]; then
    fetch "https://git.kernel.org/pub/scm/linux/kernel/git/wens/wireless-regdb.git/plain/regulatory.db" "${regdb}/regulatory.db"
    fetch "https://git.kernel.org/pub/scm/linux/kernel/git/wens/wireless-regdb.git/plain/regulatory.db.p7s" "${regdb}/regulatory.db.p7s"
  fi
  local ext="${SRC}/external-firmware"
  rm -rf "$ext"
  local ent src dst from
  for ent in $BUILTIN_FW; do
    src="${ent%%:*}"; dst="${ent#*:}"
    case "$src" in
      xfw/*) from="${EXTRA_FW_SRC}/${src#xfw/}" ;;
      lfw/*)
        from="${CACHE}/linux-firmware-${LINUX_FW_REF}/${src#lfw/}"
        fetch "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/${LINUX_FW_REF}/${src#lfw/}" "$from" ;;
      *) die "BUILTIN_FW: unknown source $src" ;;
    esac
    [[ -s "$from" ]] || die "missing firmware $from"
    mkdir -p "$(dirname "${ext}/${dst}")"
    cp -L "$from" "${ext}/${dst}"
  done
  cp -L "${regdb}/regulatory.db" "${regdb}/regulatory.db.p7s" "$ext/"
  (cd "$ext" && find . -type f | sed 's|^\./||' | sort | xargs) >"${WORK}/extra-firmware.list"
}

configure() {
  local cfg
  cfg="$(rocknix_path "projects/ROCKNIX/devices/${ROCKNIX_DEVICE}/linux/linux.aarch64.conf")"
  [[ -f "$cfg" ]] || die "missing ROCKNIX config $cfg"
  cp "$cfg" "${SRC}/.config"
  local sc="${SRC}/scripts/config --file ${SRC}/.config"
  # ROCKNIX embeds its own initramfs through this placeholder; ours goes
  # there too with EMBED_INITRAMFS (uncompressed: the whole Image is gzipped
  # for ABL anyway, and konkr-update can then find the recovery hook in it).
  if [[ "${EMBED_INITRAMFS:-0}" == 1 ]]; then
    $sc --set-str INITRAMFS_SOURCE "$INITRD_CPIO"
    $sc --enable INITRAMFS_COMPRESSION_NONE
  else
    $sc --set-str INITRAMFS_SOURCE ""
  fi
  $sc --set-str LOCALVERSION "$LOCALVERSION"
  $sc --disable LOCALVERSION_AUTO
  # FW_BUILTIN=0 (soc.env): like ROCKNIX, nothing built in; the same files
  # still go to the rootfs (install_output) and load from there.
  if [[ "${FW_BUILTIN:-1}" == 1 ]]; then
    $sc --set-str EXTRA_FIRMWARE "$(cat "${WORK}/extra-firmware.list")"
    $sc --set-str EXTRA_FIRMWARE_DIR "external-firmware"
  else
    $sc --set-str EXTRA_FIRMWARE ""
  fi
  # Merge the SteamOS fragment (see steamos.config for why each is needed),
  # then the SoC's own (kernel-<soc>/steamos.config), if any.
  local frag="${WORK}/steamos.config.merged"
  cat "${HERE}/steamos.config" >"$frag"
  [[ -f "${SOC_DIR}/steamos.config" ]] && cat "${SOC_DIR}/steamos.config" >>"$frag"
  local line opt val
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    opt="${line%%=*}"; val="${line#*=}"; opt="${opt#CONFIG_}"
    case "$val" in
      y) $sc --enable "$opt" ;;
      m) $sc --module "$opt" ;;
      n) $sc --disable "$opt" ;;
      \"*) $sc --set-str "$opt" "$(eval echo "$val")" ;;
      *) $sc --set-val "$opt" "$val" ;;
    esac
  done <"$frag"
  make -C "$SRC" olddefconfig >/dev/null
  # Report anything from the fragment that Kconfig refused.
  local bad=0
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    opt="${line%%=*}"; val="${line#*=}"
    if [[ "$val" == n ]]; then
      grep -q "^${opt}=" "${SRC}/.config" && { log "WARN ${opt} still set"; bad=1; }
    elif ! grep -qx "${opt}=${val}" "${SRC}/.config"; then
      log "WARN ${opt}=${val} not applied (got: $(grep -E "^(# )?${opt}[= ]" "${SRC}/.config" || echo unset))"; bad=1
    fi
  done <"$frag"
  ((bad)) && log "some fragment options did not stick (see WARN lines)"
  return 0
}

build_kernel() {
  log "make -j${JOBS} Image modules dtbs"
  make -C "$SRC" -j"$JOBS" Image modules dtbs
  KREL="$(make -s -C "$SRC" kernelrelease)"
  log "kernel release ${KREL}"
}

build_tddi() {
  local tar="${CACHE}/chipone_tddi-${TDDI_REF}.tar.gz" d="${WORK}/chipone_tddi"
  fetch "https://github.com/ROCKNIX/chipone_tddi/archive/${TDDI_REF}.tar.gz" "$tar"
  rm -rf "$d"; mkdir -p "$d"
  tar -C "$d" --strip-components=1 -xzf "$tar"
  make -C "$SRC" M="$d" -j"$JOBS" modules
}

build_initramfs() {
  # Tiny busybox initramfs (initramfs/init): mounts the SD root and writes
  # bootlog.txt to the FAT partition. The configuration verified to boot on
  # the Pocket FIT; also the only log available when the screen stays black.
  local bb=/bin/busybox d="${WORK}/initramfs"
  file "$bb" 2>/dev/null | grep -q "statically linked" \
    || die "need a static busybox (apt install busybox-static)"
  rm -rf "$d"; mkdir -p "$d/root/bin" "$d/root/dev" "$d/root/proc" "$d/root/sys"
  cp "$bb" "$d/root/bin/busybox"
  install -m0755 "${HERE}/initramfs/init" "$d/root/init"
  install -m0755 "${HERE}/initramfs/konkr-update-recover" "$d/root/konkr-update-recover"
  install -m0755 "${HERE}/initramfs/bootdebug" "$d/root/bootdebug"
  (cd "$d/root" && find . | cpio -o -H newc --owner=0:0 2>/dev/null) >"$d/initrd.cpio"
  gzip -9 -n -c "$d/initrd.cpio" >"$d/initrd.gz"
  INITRD="$d/initrd.gz"
  INITRD_CPIO="$d/initrd.cpio"
}

pack_kernel_img() {
  local out="$1" img="${SRC}/arch/arm64/boot/Image" payload dtb f
  payload="$(mktemp)"
  gzip -9 -n -c "$img" >"$payload"
  for dtb in $DTBS; do
    f="${SRC}/arch/arm64/boot/dts/qcom/${dtb}.dtb"
    [[ -f "$f" ]] || die "missing ${f}"
    cat "$f" >>"$payload"
  done
  # Placeholder root; the image builder patches the real PARTUUID in.
  local cmdline
  cmdline="$(bash -c "source '${SOC_DIR}/soc.env'; source '${HERE}/cmdline.sh'; build_cmdline 00000000-02")"
  local rd=(--ramdisk "$INITRD")
  [[ "${EMBED_INITRAMFS:-0}" == 1 ]] && rd=()  # dummy ramdisk, like ROCKNIX
  python3 "${HERE}/mkbootimg-v0.py" --kernel "$payload" "${rd[@]}" \
    --cmdline "$cmdline" --out "$out"
  rm -f "$payload"
  md5sum "$out" | awk '{print $1"  KERNEL"}' >"$(dirname "$out")/KERNEL.md5"
}

install_output() {
  local o="${OUT_BASE}/${KREL}"
  rm -rf "$o"
  mkdir -p "$o/boot" "$o/modules" "$o/firmware" "$o/dtbs"
  log "modules_install"
  make -C "$SRC" INSTALL_MOD_PATH="$o/staging" INSTALL_MOD_STRIP=1 modules_install >/dev/null
  make -C "$SRC" M="${WORK}/chipone_tddi" INSTALL_MOD_PATH="$o/staging" INSTALL_MOD_STRIP=1 \
    INSTALL_MOD_DIR=extra modules_install >/dev/null
  depmod -b "$o/staging" "$KREL"
  mv "$o/staging/lib/modules/${KREL}" "$o/modules/${KREL}"
  rm -rf "$o/staging"
  rm -f "$o/modules/${KREL}/build" "$o/modules/${KREL}/source"

  log "firmware (rootfs part: remoteprocs, audio topology, Wi-Fi/BT)"
  cp -a "${EXTRA_FW_SRC}/${ROCKNIX_DEVICE}/." "$o/firmware/"
  # Built-in copies are enough for the GPU; keep rootfs copies too for tooling.
  cp -a "${SRC}/external-firmware/." "$o/firmware/"

  local dtb
  for dtb in $DTBS; do cp "${SRC}/arch/arm64/boot/dts/qcom/${dtb}.dtb" "$o/dtbs/"; done
  cp "${SRC}/.config" "$o/config-${KREL}"
  cp "${SRC}/System.map" "$o/System.map-${KREL}"
  pack_kernel_img "$o/boot/KERNEL"
  ln -sfn "$KREL" "${OUT_BASE}/current"
  log "done: $o"
  ls -la "$o/boot" >&2
}

main() {
  if [[ "${1:-}" == --repack-boot ]]; then
    [[ -s "$SRC/arch/arm64/boot/Image" ]] || die "no previously built kernel Image"
    KREL="$(make -s -C "$SRC" kernelrelease)"
    [[ -d "$OUT_BASE/$KREL" ]] || die "no previously built kernel output"
    build_initramfs
    [[ "${EMBED_INITRAMFS:-0}" == 1 ]] && make -C "$SRC" -j"$JOBS" Image
    pack_kernel_img "$OUT_BASE/$KREL/boot/KERNEL"
    log "repacked initramfs: $OUT_BASE/$KREL/boot/KERNEL"
    return
  fi
  check_deps
  [[ -d "$ROCKNIX_DIR/projects/ROCKNIX/devices/${ROCKNIX_DEVICE}" ]] \
    || die "ROCKNIX tree not found at ${ROCKNIX_DIR} (sparse clone of ROCKNIX/distribution@${ROCKNIX_REF})"
  mkdir -p "$CACHE"
  prepare_source
  stage_builtin_firmware
  build_initramfs
  configure
  build_kernel
  build_tddi
  install_output
}

main "$@"
