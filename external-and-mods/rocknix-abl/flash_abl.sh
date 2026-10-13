#!/system/bin/sh
# Put ROCKNIX ABL @VERSION@ (@SOC@) on both ABL slots. Run it as root.
# Every line stands on its own: the root script tools in Android settings may
# run a file one line at a time, so nothing carries over from line to line.
# The rocknix_abl folder can stay on the microSD card's BOOT drive or be copied
# to internal storage (/sdcard/rocknix_abl).
# 1. Back up the ABL on the device now as abl_a.img / abl_b.img in the folder (kept if already there: that one has Android's ABL).
for d in /sdcard/rocknix_abl /storage/*/rocknix_abl; do [ -s "$d/abl_signed-@SOC@.elf" ] || continue; for s in a b; do [ -s "$d/abl_$s.img" ] || { dd if=/dev/block/by-name/abl_$s of="$d/abl_$s.img" bs=1M && sync && [ "$(sha256sum < "$d/abl_$s.img")" = "$(sha256sum < /dev/block/by-name/abl_$s)" ] || rm -f "$d/abl_$s.img"; }; done; break; done
# 2. Flash both slots, only with a backup in place and an intact ABL file.
for d in /sdcard/rocknix_abl /storage/*/rocknix_abl; do [ -s "$d/abl_a.img" ] && [ -s "$d/abl_b.img" ] && [ "$(sha256sum "$d/abl_signed-@SOC@.elf" 2>/dev/null | cut -d' ' -f1)" = @ABL_SHA@ ] || continue; dd if="$d/abl_signed-@SOC@.elf" of=/dev/block/by-name/abl_a bs=1M; dd if="$d/abl_signed-@SOC@.elf" of=/dev/block/by-name/abl_b bs=1M; sync; break; done
# 3. Read both slots back.
[ "$(head -c @ABL_BYTES@ /dev/block/by-name/abl_a | sha256sum | cut -d' ' -f1)" = @ABL_SHA@ ] && [ "$(head -c @ABL_BYTES@ /dev/block/by-name/abl_b | sha256sum | cut -d' ' -f1)" = @ABL_SHA@ ] && echo "Done: ROCKNIX ABL @VERSION@ is on both slots. Copy abl_a.img and abl_b.img from the rocknix_abl folder to a PC, then restart holding Volume Down: set your device model, choose Linux, Start." || echo "FAILED: ROCKNIX ABL is not on the device. Check that root was allowed and that the whole rocknix_abl folder is on the SD card or in internal storage, then run flash_abl.sh again."
