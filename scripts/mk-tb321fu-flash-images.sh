#!/bin/bash
# Lenovo Legion Y700 Gen 3 (TB321FU): fastboot images for an internal install.
#
#   mk-tb321fu-flash-images.sh IMAGE OUT_DIR [KERNEL_OUT]
#
# IMAGE is the Gen 3 image (BOOT, root and home partitions). The tablet's
# UEFI loader only looks for GRUB on internal storage, so instead of booting
# that image from USB the tablet gets three partitions written by fastboot:
#   boot.img       -> boot_a    GUF296's UEFI loader (from the image's tablet/)
#   super.img      -> super     256 MiB FAT: GRUB, our boot menu, Image, DTBs.
#                               The startup code mounts it as /boot
#                               (steamos.bootlabel=super), logs go there too.
#   userdata.simg  -> userdata  the system and /home in one ext4 filesystem,
#                               Android sparse, grown to the whole partition
#                               on first boot
# Android's system partitions are replaced, so Android is gone; Lenovo's
# rescue tool (LMSA) puts it back. KERNEL_OUT, when given, replaces the
# image's kernel and modules (a newer build of the same kernel).
set -euo pipefail
IMG="${1:?image}"; OUT="${2:?output dir}"; KO="${3:-}"
log() { echo "==> $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
[[ $(id -u) = 0 ]] || die "run as root"
command -v img2simg >/dev/null || die "img2simg missing (android-sdk-libsparse-utils)"

W=$(mktemp -d /work/tb321fu-flash.XXXXXX)
LOOP=""; FAT=""
cleanup() {
  set +e
  for m in "$W/super" "$W/ud" "$W/home" "$W/root" "$W/boot"; do mountpoint -q "$m" && umount "$m"; done
  [[ -n "$FAT" ]] && losetup -d "$FAT"
  [[ -n "$LOOP" ]] && losetup -d "$LOOP"
  rm -rf "$W"
}
trap cleanup EXIT
mkdir -p "$OUT" "$W"/{boot,root,home,super,ud}
rm -f "$OUT"/{boot.img,super.img,userdata.img,userdata.simg,SHA256SUMS}

LOOP=$(losetup -fP --show -r "$IMG")
mount -o ro "${LOOP}p1" "$W/boot"
mount -o ro "${LOOP}p2" "$W/root"
mount -o ro "${LOOP}p3" "$W/home"
B=$W/boot

log "boot.img (UEFI loader)"
cp "$B/tablet/lenovo-legion-tab-gen3-boot.img" "$OUT/boot.img"

log "super.img (256 MiB FAT)"
truncate -s 256M "$OUT/super.img"
mkfs.vfat -F 32 -n Y700BOOT "$OUT/super.img" >/dev/null
FAT=$(losetup -f --show "$OUT/super.img")
mount "$FAT" "$W/super"
S=$W/super
cp -r "$B/EFI" "$S/"
cp "$B"/steamos-arm-boot-* "$S/"
mkdir -p "$S/dtb"
if [[ -n "$KO" ]]; then
  cp "$KO/boot/Image" "$S/Image"
  cp "$KO"/dtbs/sm8650-lenovo-tb321fu-{boe,csot}.dtb "$S/dtb/"
else
  cp "$B/Image" "$S/Image"
  cp "$B"/dtb/sm8650-lenovo-tb321fu-{boe,csot}.dtb "$S/dtb/"
fi
# Root is the userdata partition now, not the internal install's STORAGE or
# the USB drive, and the boot files live on super.
for f in "$S/EFI/BOOT/grub.cfg" "$S/EFI/BOOT/qcomramp.cfg"; do
  sed -i -e 's/ steamos\.usbimage=1//' \
    -e 's/root=PARTLABEL=STORAGE/root=PARTLABEL=userdata steamos.bootlabel=super/' "$f"
done
grep -q 'root=PARTLABEL=userdata steamos.bootlabel=super' "$S/EFI/BOOT/qcomramp.cfg" || die "boot menu not rewritten"
! grep -q 'usbimage' "$S"/EFI/BOOT/*.cfg || die "USB image fallback still in the boot menu"
# A "boot text" copy of each panel entry: kernel and systemd messages on
# screen, so a photo shows where a boot stops (the logs on super can't be
# read from a PC). The UEFI framebuffer stays on and its memory reserved, so
# the text starts before the display driver loads; the normal entries keep
# the quiet bring-up setup.
awk '
  /^menuentry "SteamOS ARM Port \(.* panel\)"/ { inblk = 1; blk = "" }
  { print }
  inblk { blk = blk $0 "\n" }
  inblk && /^}/ {
    inblk = 0
    sub(/ panel\)"/, " panel, boot text)\"", blk)
    gsub(/ \/reserved-memory\/splash-region/, "", blk)
    gsub(/ video=efifb:off| drm_client_lib\.active=none| quiet| loglevel=0| systemd\.show_status=0| rd\.udev\.log_level=0| logo\.nologo| vt\.global_cursor_default=0/, "", blk)
    sub(/ rw rootwait/, " loglevel=7 console=tty0 systemd.show_status=1 rw rootwait", blk)
    extra = extra "\n" blk
  }
  END { printf "%s", extra }
' "$S/EFI/BOOT/qcomramp.cfg" > "$W/qcomramp.cfg"
cp "$W/qcomramp.cfg" "$S/EFI/BOOT/qcomramp.cfg"
[[ $(grep -c 'boot text)' "$S/EFI/BOOT/qcomramp.cfg") = 2 ]] || die "boot text entries missing"
! grep -A8 'boot text)' "$S/EFI/BOOT/qcomramp.cfg" | grep -q -E ' quiet|efifb:off' || die "boot text entries still quiet"
# Beta: logs on every boot (bootlog.txt, debug-logs/), readable in Desktop
# Mode under /boot or over SSH. Delete /boot/debug to stop them.
: > "$S/debug"
sync; umount "$S"; losetup -d "$FAT"; FAT=""
fsck.fat -n "$OUT/super.img" | tail -1

log "userdata.img (ext4: system and /home)"
used=$(( $(du -sxB1M "$W/root" | cut -f1) + $(du -sxB1M "$W/home" | cut -f1) ))
size=$(( used * 110 / 100 + 1024 ))
truncate -s "${size}M" "$OUT/userdata.img"
mkfs.ext4 -q -F -L userdata -m 1 "$OUT/userdata.img"
mount "$OUT/userdata.img" "$W/ud"
U=$W/ud
rsync -aAXH --numeric-ids --exclude='/home/*' --exclude='/boot/*' "$W/root/" "$U/"
rsync -aAXH --numeric-ids --exclude='/lost+found' "$W/home/" "$U/home/"
if [[ -n "$KO" ]]; then
  kr=$(basename "$(ls -d "$KO"/modules/lib/modules/* 2>/dev/null || ls -d "$KO"/modules/*)")
  src=$(ls -d "$KO"/modules/lib/modules/"$kr" 2>/dev/null || ls -d "$KO"/modules/"$kr")
  rm -rf "$U/usr/lib/modules/$kr"; cp -a "$src" "$U/usr/lib/modules/$kr"
  log "kernel and modules from $KO ($kr)"
fi
FSTAB='# Lenovo Legion Y700 Gen 3: system and /home on userdata, boot files on super
PARTLABEL=userdata  /      ext4  defaults,noatime,x-systemd.growfs  0 1
PARTLABEL=super     /boot  vfat  defaults,umask=0077,nofail          0 2
'
printf '%s' "$FSTAB" > "$U/etc/fstab"
[[ -d "$U/var/lib/overlays/etc/upper" ]] && printf '%s' "$FSTAB" > "$U/var/lib/overlays/etc/upper/fstab"
# /home is already the whole partition: the microSD image's first-boot grow
# of its home partition must not run.
mkdir -p "$U/var/lib/steamos-sm8550"; touch "$U/var/lib/steamos-sm8550/home-expanded"
[[ -x "$U/sbin/init" || -L "$U/sbin/init" ]] || die "no /sbin/init in the system"
[[ -d "$U/home/steamos" ]] || die "no /home/steamos"
sync; umount "$U"
e2fsck -fy "$OUT/userdata.img" >/dev/null 2>&1 || true
e2fsck -fn "$OUT/userdata.img" >/dev/null || die "userdata.img doesn't check clean"

log "userdata.simg (Android sparse)"
img2simg "$OUT/userdata.img" "$OUT/userdata.simg"
rm -f "$OUT/userdata.img"
(cd "$OUT" && sha256sum boot.img super.img userdata.simg > SHA256SUMS && cat SHA256SUMS)
ls -l "$OUT"
log "done"
