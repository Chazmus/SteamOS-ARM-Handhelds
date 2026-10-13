ROCKNIX ABL @VERSION@ for @SOC@ (@DEVICES@)

The bootloader menu that lets this device start SteamOS from the microSD
card or internal storage, and still start Android. From the ROCKNIX project
(https://github.com/ROCKNIX/abl), GPL-2.0, (c) ROCKNIX contributors. Only
needed once; skip this if the ABL menu already shows ROCKNIX ABL @VERSION@
or newer.

You need Android's "run script as root" option (in the device's settings).

1. In Android, open the root script tool and run flash_abl.sh from this
   rocknix_abl folder. It can stay on the microSD card's BOOT drive; copying
   it to the top of internal storage (/sdcard/rocknix_abl) works too.
2. The script first saves your current ABL as abl_a.img and abl_b.img in the
   same folder, then writes ROCKNIX ABL to both slots and reads them back.
   It ends with "Done" or "FAILED". Copy the two .img files to a PC and keep
   them.
3. Restart holding Volume Down. In the menu (Volume to move, Power to
   select): set your device model, choose Linux as the boot mode, Start.

To go back to the ABL you had: run restore_abl.sh as root from the same
folder. backup_abl.sh only takes the backup, without flashing anything.

Android keeps working with ROCKNIX ABL: choose Android in the ABL menu.
