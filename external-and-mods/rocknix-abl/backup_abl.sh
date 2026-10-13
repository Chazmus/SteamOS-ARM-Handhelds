#!/system/bin/sh
# Save the ABL on the device now as abl_a.img / abl_b.img in the rocknix_abl
# folder (on the microSD card or in internal storage). Run it as root.
# Every line stands on its own (root script tools may run one line at a time).
for d in /sdcard/rocknix_abl /storage/*/rocknix_abl; do [ -s "$d/abl_signed-@SOC@.elf" ] || continue; dd if=/dev/block/by-name/abl_a of="$d/abl_a.img" bs=1M; dd if=/dev/block/by-name/abl_b of="$d/abl_b.img" bs=1M; sync; [ "$(sha256sum < "$d/abl_a.img")" = "$(sha256sum < /dev/block/by-name/abl_a)" ] && [ "$(sha256sum < "$d/abl_b.img")" = "$(sha256sum < /dev/block/by-name/abl_b)" ] && echo "Saved abl_a.img and abl_b.img in $d. Copy them to a PC and keep them." && exit 0; done; echo "FAILED: no backup was saved. Check that root was allowed and that the whole rocknix_abl folder is on the SD card or in internal storage."
