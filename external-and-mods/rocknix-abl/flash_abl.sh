#!/system/bin/sh
# Put ROCKNIX ABL @VERSION@ (@SOC@) on both ABL slots.
# Run as root from /sdcard/rocknix_abl (Settings > run script as root).
# The ABL that's on the device now is saved first as abl_a.img / abl_b.img,
# unless an earlier backup is already there (that one has Android's ABL).
D=/sdcard/rocknix_abl
if [ ! -s $D/abl_a.img ] || [ ! -s $D/abl_b.img ]; then
  dd if=/dev/block/by-name/abl_a of=$D/abl_a.img bs=1M
  dd if=/dev/block/by-name/abl_b of=$D/abl_b.img bs=1M
fi
dd if=$D/abl_signed-@SOC@.elf of=/dev/block/by-name/abl_a bs=1M
dd if=$D/abl_signed-@SOC@.elf of=/dev/block/by-name/abl_b bs=1M
sync
echo "Done. Restart holding Volume Down: set your device model, choose Linux, Start."
