#!/system/bin/sh
# Save the ABL that's on the device now (ROCKNIX ABL @VERSION@, @SOC@).
# Run as root from /sdcard/rocknix_abl (Settings > run script as root).
dd if=/dev/block/by-name/abl_a of=/sdcard/rocknix_abl/abl_a.img bs=1M
dd if=/dev/block/by-name/abl_b of=/sdcard/rocknix_abl/abl_b.img bs=1M
sync
echo "Saved abl_a.img and abl_b.img in /sdcard/rocknix_abl. Copy them to a PC and keep them."
