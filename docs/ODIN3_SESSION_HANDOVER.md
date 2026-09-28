# AYN Odin 3 (Snapdragon 8 Elite / SM8750) SteamOS Handover Document

**Date:** September 28, 2026  
**Target Hardware:** AYN Odin 3  
* **SoC:** Qualcomm Snapdragon 8 Elite (SM8750)
* **GPU:** Adreno 830 (Turnip Mesa Vulkan 26.1.6)
* **Display:** 1080×1920 AMOLED portrait panel (`DSI-1`)
* **Kernel:** Linux 7.2.0-odin3-sm8750+
* **OS:** Valve SteamOS 3.x (`holo-core-aarch64` rootfs)

---

## 1. Executive Summary & Session Achievements

In this session, we transitioned the AYN Odin 3 from boot-looping/black-screen state into a fully running SteamOS installation with:
1. **Physical AMOLED Display Active:** Compositor running via official Valve `gamescope 3.16.30` at 1080×1920 native rotated 90° right to 1920×1080 landscape at 120Hz.
2. **GPU Hardware Acceleration Verified:** Adreno 830 DPU and Vulkan driver recognized properly by Mesa Turnip and Valve Steam Client.
3. **Steam Runtime Fully Unpacked:** All ~2.1 GB of official Steam runtime binaries extracted into `/home/steamos/.local/share/Steam/`, and the `.install-complete` sentinel file successfully touched.
4. **Steam Client & Gamepad UI Rendered on Screen:** `steamwebhelper` (Chromium CEF) mapped window `0x1a00035 "Steam Big Picture Mode"` to full 1920×1080 landscape, and the official SteamOS boot animation and UI displayed live on the physical AMOLED display.
5. **Storage & Networking Resilient:** `/home` expanded to 46 GB; Wi-Fi operational on boot; SSH low-latency access active (`UseDNS no`).

---

## 2. Key Issues Diagnosed & Solutions Applied

### A. Gamescope Binary GLIBC Incompatibility
* **Problem:** `sm8750-overlay/usr/bin/` contained a broken `gamescope` binary requiring `GLIBC_2.40`, whereas the SteamOS system glibc is `2.39`.
* **Fix:** 
  * Restored official Valve SteamOS `gamescope 3.16.30` (compiled with GCC 15.1.1, glibc 2.39).
  * Removed foreign binaries from `sm8750-overlay/usr/bin/` to prevent overwriting.

### B. Display Rotation Flags Crash
* **Problem:** Startup scripts were passing `--force-internal` and `--use-rotation-shader` to `gamescope`, which are not supported by Valve's official binary and caused gamescope to abort immediately.
* **Fix:** Updated `/usr/lib/steamos/gamescope-session` and git repository with official Valve rotation flags:
  ```bash
  --force-composition-rotation --force-orientation right --force-composition
  ```
  This cleanly maps the 1080×1920 portrait panel into a 1920×1080 landscape framebuffer.

### C. DRM Master & Seatd Permission Denied
* **Problem:** Gamescope failed to acquire DRM master rights with `/run/seatd.sock: Permission denied`.
* **Fix:** Added user `steamos` to group `seat` (GID 974):
  ```bash
  sudo usermod -aG seat steamos
  ```

### D. Systemd Boot Target Dual-Layer Overlay Pitfall
* **Problem:** Device booted into `multi-user.target` despite `systemctl set-default graphical.target`.
* **Root Cause:** SteamOS mounts an overlayfs on `/etc` (`/var/lib/overlays/etc/upper`). Before `etc.mount` runs during early boot, systemd reads `/etc/systemd/system/default.target` from the underlying **lower** rootfs (`/dev/mmcblk0p2`).
* **Fix:** Updated the symlink on both the upper and lower filesystems:
  ```bash
  unshare -m /bin/bash -c "mount /dev/mmcblk0p2 /mnt && ln -sf /usr/lib/systemd/system/graphical.target /mnt/etc/systemd/system/default.target && umount /mnt"
  ```

### E. Tracefs Missing & `steamos-manager` EPERM Lockup
* **Problem:** Linux kernel 7.2.0 does not compile in `tracefs`. `steamos-manager` exited with `EPERM` on startup, blocking `graphical-session-pre.target` from ever finishing.
* **Fix:** Masked `steamos-manager.service` and `steamos-manager-session-cleanup.service` in both lower and upper `/etc/systemd/user/`.

### F. Deckard VR Spatial Audio Crash Loop & Core Dump Storm
* **Problem:** `wireplumber` was repeatedly crashing on missing Deckard VR spatializer libraries, triggering `systemd-coredump` to write hundreds of megabytes of core dumps to the MicroSD card, locking up I/O.
* **Fix:**
  * Disabled `/etc/wireplumber/wireplumber.conf.d/60-spatial-audio.conf` and `70-spatial-node-config.conf`.
  * Disabled kernel core dumping: `sysctl -w kernel.core_pattern='|/bin/false'`.
  * Masked crashing `wireplumber.service` until pure ALSA/PipeWire configs are finalized.

### G. SD Card Storage Expansion
* **Problem:** Steam unpacking failed with `tar: Cannot write: No space left on device` because partition 3 (`/dev/mmcblk0p3`) was only 313 MB.
* **Fix:** Resized partition 3 online to 46 GB and executed `resize2fs /dev/mmcblk0p3`.

### H. Steam Tarball Extraction Timeout Loop
* **Problem:** `/usr/share/deckard/steam-health-check` unpacks `/usr/lib/steam/steam.tar.zst` (673 MB compressed, 2.1 GB uncompressed) if `/home/steamos/.local/share/Steam/.install-complete` does not exist. `steam.service` had `TimeoutStartSec=180` (3 minutes). Unpacking 2.1 GB on MicroSD takes ~5 minutes, so systemd repeatedly killed and restarted the extraction in an infinite loop.
* **Fix:**
  * Raised `TimeoutStartSec=600` in `/usr/lib/systemd/user/steam.service.d/99-odin.conf` and updated the git repository.
  * Allowed `tar` to complete cleanly. Sentinel file `/home/steamos/.local/share/Steam/.install-complete` was touched.

### I. SSH Latency (Reverse DNS Lookup)
* **Problem:** Every SSH command took 20+ seconds to respond due to DNS lookup timeouts on local Wi-Fi.
* **Fix:** Added `UseDNS no` to `/etc/ssh/sshd_config` and reloaded `sshd`. Commands now execute sub-second.

---

## 3. Current Live Status at Handover

* **IP Address:** `192.168.86.20` (`odin3.local`)
* **SSH Access:** `ssh -o StrictHostKeyChecking=no steamos@192.168.86.20` (Passwordless SSH key authenticated)
* **Display / Compositor:** `gamescope` (PID 1900) running with DRM backend on `DSI-1` with Xwayland `:0` and `:1`.
* **Steam Client:** `steamrtarm64/steam` (PID 9125) and `steamwebhelper` (PID 9573) are running.
* **X11 Display Clients:** `DISPLAY=:0 xlsclients` reports:
  ```
  odin3  steamwebhelper
  odin3  steam
  ```
* **GPU Detection (Mesa Turnip):**
  ```
  gpu_topology {
    gpus {
      id: 1
      name: "Adreno (TM) 830"
      vram_size_bytes: 11751865344
      driver_id: k_EGpuDriverId_MesaTurnip
      driver_version_major: 26
      driver_version_minor: 1
      driver_version_patch: 6
    }
  }
  ```
* **Page-Cache Flush Status:**
  The 2.1 GB extracted archive had ~850 MB of buffered dirty pages in RAM. As of handover, it has drained to ~300 MB and is continuing to write to flash. **Do not power down or reboot until `grep Dirty /proc/meminfo` is below 30 MB.**

---

## 4. How to Resume Work (Next Steps)

When picking this up next:

1. **Verify Flush Completion:**
   ```bash
   ssh steamos@192.168.86.20 "grep -E 'Dirty|Writeback' /proc/meminfo"
   ```
   Ensure `Dirty` is low (< 50MB) and `sync` has completed.

2. **Verify Steam Gamepad UI Window:**
   ```bash
   ssh steamos@192.168.86.20 "DISPLAY=:0 xwininfo -root -tree"
   ```
   Confirm that the Steam Big Picture window is mapped to full 1920×1080 resolution.

3. **Audio Setup:**
   * Configure basic PipeWire/WirePlumber profiles for the SM8750 WCD939x / WSA8845 sound hardware without the Deckard VR spatializer plugin.
   * Test audio output:
     ```bash
     ssh steamos@192.168.86.20 "pw-play /usr/share/sounds/alsa/Front_Center.wav"
     ```

4. **Built-in Gamepad Controls:**
   * Test controller input inside Steam Gamepad UI using the physical Odin 3 buttons and joysticks (InputPlumber / evdev).
   * Check `/dev/input/by-id/` or `evtest`.
