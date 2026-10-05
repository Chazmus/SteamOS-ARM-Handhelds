#!/system/bin/sh
# Shared by flash_abl.sh, backup_abl.sh and restore_abl.sh. Runs on Android
# as root (toybox sh). The chip values below are filled in at build time for
# the chip this folder is for.

SOC=@SOC@
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -n "$HERE" ] || HERE=/sdcard/rocknix_abl/$SOC
ELF=$HERE/abl_signed-$SOC.elf
A=/dev/block/by-name/abl_a
B=/dev/block/by-name/abl_b

say() { echo "$*"; }
fail() { echo; echo "STOPPED: $*"; echo "Nothing was written."; exit 1; }

need_root() {
  [ "$(id -u)" = 0 ] || fail "run this as root (Settings > run script as root)"
  [ -b "$A" ] && [ -b "$B" ] || fail "abl_a / abl_b not found on this device"
}

# The wrong chip's ABL can leave the device unable to start, so this only
# goes on when Android itself says it's the chip this folder is for.
check_chip() {
  model=$(getprop ro.soc.model 2>/dev/null)
  platform=$(getprop ro.board.platform 2>/dev/null)
  for m in @MODELS@; do [ "$model" = "$m" ] && return 0; done
  [ -n "$platform" ] && [ "$platform" = "@PLATFORM@" ] && return 0
  fail "this folder is for $SOC, but this device reports soc '${model:-?}', platform '${platform:-?}'. Use the folder for your chip."
}

sha_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

# sha256 of the first N bytes of a partition
part_sha() { head -c "$2" "$1" | sha256sum | cut -d' ' -f1; }

check_elf() {
  [ -f "$ELF" ] || fail "abl_signed-$SOC.elf is missing from $HERE"
  want=$(cut -d' ' -f1 "$ELF.sha256" 2>/dev/null)
  [ -n "$want" ] && [ "$(sha_of "$ELF")" = "$want" ] || fail "abl_signed-$SOC.elf doesn't match its .sha256 (bad copy?). Copy the folder again."
}

# Keep the first backup ever taken: that's the one with Android's own ABL.
backup() {
  if [ -s "$HERE/abl_a.img" ] && [ -s "$HERE/abl_b.img" ]; then
    say "Backup already here, keeping it: abl_a.img, abl_b.img"
    return 0
  fi
  dd if="$A" of="$HERE/abl_a.img" bs=4096 2>/dev/null || fail "couldn't read abl_a"
  dd if="$B" of="$HERE/abl_b.img" bs=4096 2>/dev/null || fail "couldn't read abl_b"
  sync
  [ "$(sha_of "$HERE/abl_a.img")" = "$(sha_of "$A")" ] || fail "abl_a backup doesn't read back the same"
  [ "$(sha_of "$HERE/abl_b.img")" = "$(sha_of "$B")" ] || fail "abl_b backup doesn't read back the same"
  say "Backed up the current ABL: $HERE/abl_a.img and abl_b.img"
  say "Copy those two files to a PC and keep them."
}

# write FILE to both slots and confirm each reads back the same
write_both() {
  size=$(wc -c < "$1" | tr -d ' ')
  want=$(sha_of "$1")
  for p in "$A" "$B"; do
    dd if="$1" of="$p" bs=4096 conv=fsync 2>/dev/null || { echo "WRITE FAILED on $p"; return 1; }
  done
  sync
  for p in "$A" "$B"; do
    [ "$(part_sha "$p" "$size")" = "$want" ] || { echo "VERIFY FAILED on $p"; return 1; }
  done
  return 0
}
