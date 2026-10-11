#!/system/bin/sh
# Switch to SteamOS: write the staged SteamOS boot image into boot_a and
# restart. boot_b keeps Android's own boot image (the way back); nothing is
# written unless boot_b still is that image and the staged image is the one
# the installer recorded.
D=/data/adb/steamos-gen5
M=${0%/*}
say() { echo "$*"; }
fail() { echo "! $*"; exit 1; }
part() {  # the one block device with GPT name $1
  n=0; dev=""
  for u in /sys/class/block/*/uevent; do
    grep -qx "PARTNAME=$1" "$u" || continue
    n=$((n + 1)); dev=/dev/block/$(sed -n 's/^DEVNAME=//p' "$u")
  done
  [ "$n" = 1 ] && [ -b "$dev" ] && echo "$dev"
}
a=$(part boot_a) || fail "boot_a not found"
b=$(part boot_b) || fail "boot_b not found"
want_android=$(cut -d' ' -f1 "$M/android.sha256" 2>/dev/null)
want_linux=$(cut -d' ' -f1 "$D/linux.img.sha256" 2>/dev/null)
[ ${#want_android} = 64 ] && [ ${#want_linux} = 64 ] || fail "not set up: run the installer again"
[ "$(sha256sum "$b" | cut -d' ' -f1)" = "$want_android" ] || fail "boot_b is not your Android boot image: nothing written"
[ "$(sha256sum "$D/linux.img" | cut -d' ' -f1)" = "$want_linux" ] || fail "the staged SteamOS image is damaged: nothing written"
size=$(stat -c %s "$D/linux.img")
say "- writing SteamOS to boot_a"
dd if="$D/linux.img" of="$a" bs=4096 conv=fsync 2>/dev/null || fail "write failed"
sync; echo 3 > /proc/sys/vm/drop_caches
got=$(head -c "$size" "$a" | sha256sum | cut -d' ' -f1)
if [ "$got" != "$want_linux" ]; then
  say "! boot_a didn't verify: putting Android back"
  dd if="$b" of="$a" bs=4096 conv=fsync 2>/dev/null; sync
  fail "nothing changed; try again"
fi
say "- done, restarting into SteamOS"
sleep 2
reboot
