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

## 2. Upstream Lineage & The Steam Frame ("Deckard") Hardware Gap

> [!IMPORTANT]
> **Valve's ARM64 SteamOS was built for an unreleased VR Headset (The "Steam Frame" / Codename "Deckard"), NOT a handheld and NOT the Snapdragon 8 Elite (SM8750).**

The upstream rootfs (`holo-core-aarch64`, distributed by Valve under bundles named `deckard-${STEAMOS_BUILD}-0.5.0` at `https://steamdeck-images.steamos.cloud/vr/`) was built specifically for Valve's unreleased standalone VR headset:
* **Frame VR Reference Hardware:**
  * **SoC:** Snapdragon 8 Gen 3 (SM8650) paired with an Adreno 750 GPU and Valve's proprietary graphics stack.
  * **Displays:** Dual high-resolution micro-OLED panels for VR binocular rendering.
  * **Audio & Sensors:** Complex multi-microphone beamforming arrays, hardware DSP, spatial HRTF filter chains, inside-out 6DOF tracking cameras, FPGA sub-controllers, eye tracking, and facial/proximity wear sensors.
* **Handheld Target Hardware (AYN Odin 3):**
  * **SoC:** Snapdragon 8 Elite (SM8750 / Oryon CPU architecture) paired with the **Adreno 830 GPU**.
  * **Display:** Single 1080×1920 AMOLED portrait panel rotated 90° to landscape.
  * **Audio & Controls:** Standard stereo speaker amplifiers + 3.5mm headphone jack driven by Qualcomm ASoC/ALSA UCM, and physical gamepad/volume rocker buttons (`gpio-keys` and `pmic_resin`).

### Why this gap causes breakage if left unhandled:
1. **Audio Engine Crashes (WirePlumber):** Valve configured WirePlumber with VR spatialization and microphone tracking plugins (`/etc/wireplumber/wireplumber.conf.d/40-mic-processing.conf` calling `microphone-tracker.lua`, `60-spatial-audio.conf`, `70-spatial-node-config.conf`). On Odin 3, the missing headset mic topology caused `microphone-tracker.lua` to pass NULL strings into `wp_spa_json_new_from_string`, triggering an instant segmentation fault (`SIGSEGV` in `__strlen_asimd`) and an infinite restart loop.
2. **SteamVR Interlocking:** The stock drop-in `/usr/lib/systemd/user/wireplumber.service.d/wireplumber-steamvr.conf` configured `After=steamvr.service` with the comment *"Wait until steamvr is running before we start up, so that we don't fail to VR_init() a bunch"*. On a handheld with SteamVR masked, this introduces unnecessary service dependencies and boot stalls.
3. **GPU Driver Incompatibility:** The proprietary Adreno 750 drivers in Valve's image fail to bind to the Adreno 830. Odin 3 requires custom Mesa Freedreno Turnip (v26.1+).
4. **Phantom Hardware Daemons & Standby Drain:** Over 20 systemd services in the stock rootfs specifically service VR headset hardware (`vrcompositor`, `vrserver`, `steamos-headset-adb`, `deckard-factory-recovery`, `deckard-fan-control`, `deckard-fpga`, `dsp_service`, `steamvr-proxmicmute`). Leaving these unmasked causes background crash loops, high CPU utilization, and rapid battery drain during standby.

---

## 3. Critical Safety & Storage Invariants

> [!CAUTION]
> **NEVER TOUCH INTERNAL UFS STORAGE (`/dev/sda` through `/dev/sdh`) ON THE ODIN 3.**
> On the AYN Odin 3, internal UFS flash is enumerated as SCSI disks `sda` through `sdh`. This contains Android OS, radio/modem calibration, bootloaders, and user data.
> **SteamOS runs exclusively on `/dev/mmcblk0` (the external MicroSD card).**
> When working on device via SSH or diagnosing storage, always ensure any partition, format, or write commands target `/dev/mmcblk0`.

---

## 4. Build & Packaging Workflow

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

## 5. Key Subsystems & Proven Architecture Fixes

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

### G. Startup Latency & Screen Blanking Gotchas
* **Cold Boot Startup Time:** Cold boots take ~2 to 2.5 minutes before the Gamepad UI paints. Gamescope starts first and holds a black screen while `steam` initializes the Adreno 830 GPU topology via Turnip, starts IPC daemons, and launches `steamwebhelper`. This is normal behavior on ARM64 handhelds and not a freeze.
* **Idle Screensaver Blackout:** When sitting on the login screen or menus without user input, Steam's built-in screensaver activates (`Screensaver_uid2`), turning the screen completely black to prevent OLED burn-in. Gamepad buttons or touchscreen input wake it up immediately.

### H. Audio Subsystem & Deckard VR Conflict Resolution
* **Hardware:** Qualcomm ASoC soundcard `SM8750AYN` on `/dev/snd/`, exposing stereo speakers (`SECONDARY_MI2S_RX` / `WSA8845` amps) and 3.5mm headphone jack (`RX_CODEC_DMA_RX_0`).
* **ALSA Setup Service:** `sm8750-overlay/usr/lib/steamos/sm8750-audio-setup` is executed as a oneshot system service (`sm8750-audio-setup.service`) after `sound.target`. It applies ALSA UCM profile `AYN-Odin3` / `SM8750-AYN` and sets speaker mixer gain controls (`SPK_L PCM`, `SPK_R PCM`, `RX_RX0 Digital Volume`, `HPHL/HPHR`).
* **WirePlumber Fix:** All Frame VR headset configurations in `/etc/wireplumber/wireplumber.conf.d/` (`40-mic-processing.conf`, `50-alsa-config.conf`, `51-alsa-disable.conf`, `60-spatial-audio.conf`, `70-spatial-node-config.conf`) are purged during image staging. WirePlumber then runs cleanly without crashing, utilizes distribution defaults from `/usr/share/wireplumber/`, and cleanly provisions PipeWire audio sinks (`Built-in Audio Speaker playback` and `Headphones playback`).
* **SteamVR Drop-in Removed:** `/usr/lib/systemd/user/wireplumber.service.d/wireplumber-steamvr.conf` is deleted so WirePlumber starts independently of SteamVR.

### I. Physical Volume Controls
* **Hardware:**
  * **Volume Up (`KEY_VOLUMEUP` / 115):** Wired via `gpio-keys` on `/dev/input/event3`.
  * **Volume Down (`KEY_VOLUMEDOWN` / 114):** Wired via `pmic_resin` (PMIC reset line input) on `/dev/input/event1`.
* **Daemon:** `sm8550-volume-keys` (`/usr/lib/steamos/sm8550-volume-keys`) is enabled as a systemd user service (`sm8550-volume-keys.service`) under `default.target`.
* **Mechanism:** The daemon listens to non-blocking raw evdev keypresses on `/dev/input/event*` devices matching `gpio-keys` and `pmic_resin`. It invokes `pactl set-sink-volume @DEFAULT_SINK@` in 5% increments using PulseAudio/cubic volume scaling, which triggers the native SteamOS on-screen volume bar overlay in Game Mode.
