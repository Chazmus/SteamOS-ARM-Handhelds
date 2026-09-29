# Developer & Agent Guidelines for SteamOS-ARM-Handhelds

This repository ports Valve's official SteamOS for ARM64 (originally designed for the Steam Frame VR headset) to Snapdragon-powered handheld gaming devices.

---

## 1. Supported Devices & Hardware Architecture

| Device | SoC | GPU / Driver | Display | Target Script |
| :--- | :--- | :--- | :--- | :--- |
| **AYN Odin 3** | Snapdragon 8 Elite (SM8750) | Adreno 830 (Mesa Freedreno Turnip Vulkan 26.1+) | 1080×1920 AMOLED portrait, rotated 90° to 1920×1080 @ 120Hz | `./make-steamos-sm8750.sh` |
| **KONKR Pocket FIT** | Snapdragon 8 Gen 3 (SM8650) | Adreno 750 (Valve stock Frame driver) | 1080×1920 AMOLED, rotated to 1920×1080 @ 144Hz | `./make-steamos-sm8650.sh` |
| **AYANEO Pocket S2 / Pro** | Snapdragon 8 Gen 3 (SM8650) | Adreno 750 (Valve stock Frame driver) | 1080×1920 AMOLED | `./make-steamos-sm8650.sh` |

---

## 2. Critical Safety & Storage Invariants

> [!CAUTION]
> **NEVER TOUCH INTERNAL UFS STORAGE (`/dev/sda` through `/dev/sdh`) ON THE ODIN 3.**
> On the AYN Odin 3, internal UFS flash is enumerated as SCSI disks `sda` through `sdh`. This contains Android OS, radio/modem calibration, bootloaders, and user data.
> **SteamOS runs exclusively on `/dev/mmcblk0` (the external MicroSD card).**
> When working on device via SSH or diagnosing storage, always ensure any partition, format, or write commands target `/dev/mmcblk0`.

---

## 3. Build & Packaging Workflow

### Building the Odin 3 Image
```bash
./make-steamos-sm8750.sh
```
* **Output:** Sparse disk image generated at `sm8750-work/steamos-odin3.img` (~15.5 GB sparse, containing partitions 1, 2, and 3).
* **Partitions:**
  1. `p1` (512 MiB, VFAT, `LABEL=BOOT`): Kernel image (`KERNEL`), device trees, extlinux config.
  2. `p2` (10.7 GiB, ext4, `LABEL=root`): Valve SteamOS base rootfs + overlays.
  3. `p3` (Dynamically sized ext4, `LABEL=home`): User data (`/home`, `/var`, `/srv`). Resized to fill the entire MicroSD card on first boot via `x-systemd.growfs`.

### Flashing to MicroSD
```bash
sudo dd if=sm8750-work/steamos-odin3.img of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Replace `/dev/sdX` with the host's actual MicroSD card device).*

---

## 4. Key Subsystems & Proven Architecture Fixes

### A. Gamescope Session & Systemd Timeout
* **Issue:** Stock Valve `gamescope-session.service` is `Type=notify` with `TimeoutStartSec=45`. Since handheld gamescope starts via `start-gamescope-session` without an immediate `systemd-notify --ready`, systemd was killing the session every 45 seconds, causing a black-screen restart loop.
* **Solution:** Configured in `steamos-overlay/usr/lib/systemd/user/gamescope-session.service.d/99-odin.conf`:
  ```ini
  [Service]
  Type=simple
  NotifyAccess=none
  TimeoutStartSec=infinity
  ```

### B. Boot Partition Mounting (`/boot`)
* **Issue:** ROCKNIX ABL initramfs opens the boot partition superblock as read-only. Standard `defaults` (which defaults to `rw`) causes the Linux VFAT driver to fail with `EBUSY` ("Can't mount, would change RO state").
* **Solution:** `/etc/fstab` MUST specify `ro,defaults`:
  ```fstab
  LABEL=BOOT  /boot  vfat  ro,defaults,umask=0077,nofail  0 2
  ```

### C. MicroSD Card Performance Tuning
* **Issue:** Flash random write speed on MicroSD cards causes I/O latency stalls (processes entering `D-state`), leading to UI micro-stutters and long tarball extraction times.
* **Solutions:**
  1. **Writeback Caching:** `/etc/sysctl.d/99-sm8750-io.conf` sets:
     ```ini
     vm.dirty_writeback_centisecs = 1500
     vm.dirty_expire_centisecs = 3000
     ```
  2. **CEF HTML Cache in RAM:** `steamos-overlay/usr/share/deckard/RUNSTEAM.sh` automatically redirects `~/.local/share/Steam/config/htmlcache` to a `tmpfs` directory in `/tmp/steam-htmlcache-$USER`.

### D. Display & Rotation
* **Connector:** `DSI-1` (1080×1920 portrait native AMOLED).
* **Gamescope Command:**
  ```bash
  gamescope --backend drm --prefer-output DSI-1 --force-composition-rotation --force-orientation right --force-composition
  ```
  This presents a virtual 1920×1080 landscape buffer to Xwayland and composites it rotated onto the physical portrait panel at 120Hz.

### E. Controller Input
* **Hardware:** `ATTRS{name}=="AYN Odin3 Gamepad"` on `/dev/input/event6`.
* **udev Rule:** `sm8750-overlay/usr/lib/udev/rules.d/70-sm8750-gamepad.rules`:
  ```udev
  KERNEL=="event*", ATTRS{name}=="AYN Odin3 Gamepad", ENV{ID_INPUT}="1", ENV{ID_INPUT_JOYSTICK}="1", MODE="0660", GROUP="input", TAG+="uaccess"
  ```
* **SDL Mapping:** GUID `0300bb95202000000130000001000000` is exported in `RUNSTEAM.sh` and `steam.service.d/99-odin.conf`.

### F. Network & SSH Access
* **User:** `steamos` with passwordless sudo via `/etc/sudoers.d/99-steamos-nopasswd`.
* **sshd:** Enabled out-of-the-box via symlink in `/etc/systemd/system/multi-user.target.wants/sshd.service`.
* Wi-Fi configurations reside in `/etc/NetworkManager/system-connections/` (mode `0600`).
