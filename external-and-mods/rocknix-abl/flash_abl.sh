
# ---- flash_abl.sh: put ROCKNIX ABL @VERSION@ on both slots ----
need_root
check_chip
check_elf
say "Device: $(getprop ro.product.model) ($SOC)"
backup
say "Writing ROCKNIX ABL @VERSION@ to abl_a and abl_b..."
if write_both "$ELF"; then
  say
  say "Done. ROCKNIX ABL @VERSION@ is on both slots."
  say "Restart holding Volume Down for the ABL menu: set your device model,"
  say "pick Linux as the boot mode, then Start."
else
  say
  say "The new ABL did not write cleanly. Do NOT restart yet:"
  say "run restore_abl.sh from this folder first to put your old ABL back."
  exit 1
fi
