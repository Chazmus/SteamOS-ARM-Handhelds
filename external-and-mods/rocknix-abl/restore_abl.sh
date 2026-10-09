#!/system/bin/sh
# Put the ABL saved by backup_abl.sh / flash_abl.sh back on both slots.
# Run as root from /sdcard/rocknix_abl (Settings > run script as root).
dd if=/sdcard/rocknix_abl/abl_a.img of=/dev/block/by-name/abl_a bs=1M
dd if=/sdcard/rocknix_abl/abl_b.img of=/dev/block/by-name/abl_b bs=1M
sync
echo "Done. Your previous ABL is back on both slots."
