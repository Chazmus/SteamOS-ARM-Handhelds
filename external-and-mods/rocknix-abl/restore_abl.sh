
# ---- restore_abl.sh: put the backed-up ABL back on each slot ----
need_root
[ -s "$HERE/abl_a.img" ] && [ -s "$HERE/abl_b.img" ] || fail "no backup here (abl_a.img, abl_b.img)"
ok=1
for s in a b; do
  img=$HERE/abl_$s.img
  part=/dev/block/by-name/abl_$s
  size=$(wc -c < "$img" | tr -d ' ')
  dd if="$img" of="$part" bs=4096 conv=fsync 2>/dev/null && sync
  if [ "$(part_sha "$part" "$size")" = "$(sha_of "$img")" ]; then
    say "abl_$s restored"
  else
    say "abl_$s did NOT read back the same, run this script again"; ok=0
  fi
done
[ "$ok" = 1 ] && say "Done. Your previous ABL is back on both slots." || exit 1
