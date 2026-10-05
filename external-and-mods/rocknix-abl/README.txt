ROCKNIX ABL @VERSION@ for @SOC@ (@DEVICES@)

The bootloader menu that lets this device start SteamOS from the microSD
card or internal storage, and still start Android. From the ROCKNIX project
(https://github.com/ROCKNIX/abl), GPL-2.0, (c) ROCKNIX contributors. Only
needed once; skip this if the ABL menu already shows ROCKNIX ABL @VERSION@
or newer.

You need Android's "run script as root" option (in the device's settings).

1. In Android, copy this whole rocknix_abl folder from the microSD card's
   BOOT drive to Android's internal storage.
2. Open the folder for your chip: @SOC@. Don't use another chip's folder;
   the scripts check and refuse, but don't rely on that.
3. Run flash_abl.sh as root. It first saves your current ABL as abl_a.img
   and abl_b.img in the same folder, then writes the new one to both slots
   and checks it. Copy the two .img files to a PC and keep them.
4. Restart holding Volume Down. In the menu (Volume to move, Power to
   select): set your device model, choose Linux as the boot mode, Start.

To go back to the ABL you had: run restore_abl.sh as root from the same
folder. backup_abl.sh only takes the backup, without flashing anything.

Android keeps working with ROCKNIX ABL: choose Android in the ABL menu.
