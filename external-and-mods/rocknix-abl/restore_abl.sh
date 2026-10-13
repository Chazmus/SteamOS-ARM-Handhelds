#!/system/bin/sh
# Put the ABL saved by backup_abl.sh / flash_abl.sh back on both slots. Run it as root.
# abl_a.img and abl_b.img must be in the rocknix_abl folder (on the microSD card or in internal storage).
# Every line stands on its own (root script tools may run one line at a time).
for d in /sdcard/rocknix_abl /storage/*/rocknix_abl; do [ -s "$d/abl_a.img" ] && [ -s "$d/abl_b.img" ] || continue; dd if="$d/abl_a.img" of=/dev/block/by-name/abl_a bs=1M; dd if="$d/abl_b.img" of=/dev/block/by-name/abl_b bs=1M; sync; [ "$(sha256sum < "$d/abl_a.img")" = "$(head -c "$(wc -c < "$d/abl_a.img")" /dev/block/by-name/abl_a | sha256sum)" ] && [ "$(sha256sum < "$d/abl_b.img")" = "$(head -c "$(wc -c < "$d/abl_b.img")" /dev/block/by-name/abl_b | sha256sum)" ] && echo "Done: your previous ABL is back on both slots." && exit 0; done; echo "FAILED: abl_a.img and abl_b.img weren't found in a rocknix_abl folder, or didn't write back. Check that root was allowed."
