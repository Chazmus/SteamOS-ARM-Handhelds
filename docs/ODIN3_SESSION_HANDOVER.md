# AYN Odin 3 (Snapdragon 8 Elite / SM8750) SteamOS Handover Document

**Date:** September 28, 2026 (Updated End-of-Day)  
**Target Hardware:** AYN Odin 3  
* **SoC:** Qualcomm Snapdragon 8 Elite (SM8750)
* **GPU:** Adreno 830 (Turnip Mesa Vulkan 26.1.6)
* **Display:** 1080×1920 AMOLED portrait panel (`DSI-1`)
* **Kernel:** Linux 7.2.0-odin3-sm8750+
* **OS:** Valve SteamOS 3.x (`holo-core-aarch64` rootfs)
* **Storage:** External MicroSD (`/dev/mmcblk0`) — *Internal UFS storage (`sda`-`sdh`) contains Android and is untouched*

---

## 1. Executive Summary & Major Milestones Achieved

In today's marathon session, the AYN Odin 3 transitioned from an unbootable, black-screen state into a **fully functioning, official Valve SteamOS handheld experience**:

1. **Hardware-Accelerated Gamescope Compositor:**
   * Running official Valve `gamescope 3.16.30` (compiled with GCC 15.1.1, glibc 2.39).
   * DRM backend on `DSI-1` at 1080×1920 native rotated 90° right to **1920×1080 landscape at 120Hz**.
   * Adreno 830 GPU fully recognized via Mesa Turnip Vulkan driver (`vram_size_bytes: 11751865344`).

2. **Handheld Steam UI (No More Truncation):**
   * Replaced Deckard VR flags with handheld flags (`-gamepadui -steamos3 -steampal -steamdeck -noverifyfiles -noshaders -inhibitbootstrap -nobootstrapperupdate`).
   * Main login and Gamepad UI fit the 1080p landscape display cleanly without vertical truncation.

3. **Steam Account Login & Library Loaded:**
   * User successfully authenticated using the on-screen Steam QR code.
   * Steam cloud, user account data, and game library populated into `https://steamloopback.host/routes/library/home`.

4. **Physical Controller Fully Operational:**
   * Fixed `70-sm8750-gamepad.rules` by removing restrictive root-only permissions and enabling joystick subsystem tagging (`uaccess`, `MODE="0660"`, `GROUP="input"`).
   * Exported SDL controller mappings for GUID `0300bb95202000000130000001000000` (`AYN Odin3 Gamepad`).
   * Steam opened `/dev/input/event6`, reserved XInput slot 0, and **physical D-pad input successfully navigated the Steam Big Picture UI**.

5. **Storage Benchmark & Lag Spike Diagnosis:**
   * Identified root cause of random UI freezes: the currently installed MicroSD card (`SanDisk Ultra 64GB` / `SU64G`) has extremely slow write performance (< 1 MB/s write, 8.3 MB/s read in SDR50 mode).
   * Storage I/O queues stall whenever Linux flushes dirty page caches to flash, placing processes into `D-state` (Uninterruptible Sleep).
   * Recommended upgrade to an **Application Performance Class A2** MicroSD card (e.g., Samsung EVO/PRO Plus or SanDisk Extreme) to eliminate I/O stutter.

---

## 2. Key Issues Diagnosed & Solutions Applied

### A. Physical Gamepad Buttons Not Working in Steam
* **Problem:** Physical buttons, D-pad, and analog sticks on the Odin 3 were ignored by Steam.
* **Root Cause:**
  1. `sm8750-overlay/usr/lib/udev/rules.d/70-sm8750-gamepad.rules` had stripped `ENV{ID_INPUT_JOYSTICK}=""` and set `MODE="0600", GROUP="root"` on the assumption that an external daemon (`inputplumber`) would run as root. However, InputPlumber is not installed on the system.
  2. Steam (running as unprivileged user `steamos`) was blocked by Linux DAC permissions from reading `/dev/input/event6`.
  3. SDL lacked an explicit controller mapping for the hardware GUID.
* **Fix:**
  1. Updated udev rule to:
     ```udev
     KERNEL=="event*", ATTRS{name}=="AYN Odin3 Gamepad", ENV{ID_INPUT}="1", ENV{ID_INPUT_JOYSTICK}="1", MODE="0660", GROUP="input", TAG+="uaccess"
     ```
  2. Exported SDL mapping in `/usr/lib/systemd/user/steam.service.d/99-odin.conf` and `/usr/share/deckard/RUNSTEAM.sh`:
     ```bash
     SDL_GAMECONTROLLERCONFIG="0300bb95202000000130000001000000,AYN Odin3 Gamepad,a:b0,b:b1,x:b2,y:b3,back:b6,guide:b8,start:b7,leftstick:b9,rightstick:b10,leftshoulder:b4,rightshoulder:b5,dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,platform:Linux,"
     ```
  3. Steam log confirms: `!! Steam controller device opened for index 0`, `reserving XInput slot 0`, `Opted-in Controller Mask: 100f`.

### B. Login QR Code Truncated Vertically
* **Problem:** Login screen had an inner viewport where the top and bottom of the QR code were cut off.
* **Root Cause:** Stock Deckard script passed `-deckard` and `-vrgamepadui`, which treats the display as an oversized curved VR slate.
* **Fix:** Replaced flags in `RUNSTEAM.sh` with pure handheld flags:
  `-gamepadui -steamos3 -steampal -steamdeck -noverifyfiles -noshaders -inhibitbootstrap -nobootstrapperupdate`.

### C. Boot Black Screen / Coredump Storm & I/O Freeze
* **Problem:** System appeared to hang with a black screen during boot and experienced long UI freezes.
* **Root Cause:**
  1. `wireplumber` was crashing with SIGSEGV in a restart loop due to missing Deckard VR spatial audio modules and unconfigured SM8750 soundwire routing.
  2. `systemd-coredump` and `steamos_log_submitter` were writing multi-hundred MB core dumps to the MicroSD card repeatedly, completely saturating disk write bandwidth.
  3. Missing SM8550 services (`sm8550-audio-pipewire`, `sm8550-volume-keys`) were restarting every 2 seconds.
* **Fix:**
  1. Masked `wireplumber.service`, `sm8550-audio-pipewire.service`, and `sm8550-volume-keys.service` in systemd user services.
  2. Set `sysctl -w kernel.core_pattern='|/bin/false'` and masked `steamos-log-submitter.service`.
  3. Once the storm was stopped, disk I/O cleared and Steam rendered immediately.

### D. Gamescope Binary GLIBC Incompatibility
* **Problem:** Stock overlay contained a foreign `gamescope` binary requiring `GLIBC_2.40` (system is glibc 2.39).
* **Fix:** Restored official Valve SteamOS `gamescope 3.16.30` and purged broken binaries from the overlay repo.

### E. Display Rotation Flags Crash
* **Problem:** Gamescope failed on unsupported `--force-internal` and `--use-rotation-shader` flags.
* **Fix:** Switched to official Valve flags: `--force-composition-rotation --force-orientation right --force-composition`.

### F. Multi-User vs Graphical Boot Target Overlay
* **Problem:** `graphical.target` failed to stick across reboots due to SteamOS overlayfs reading `/etc/systemd/system/default.target` from the underlying lower rootfs (`mmcblk0p2`).
* **Fix:** Updated symlinks on both upper and lower partitions.

### G. SD Card Storage Expansion
* **Problem:** Partition 3 (`/home`) was only 313 MB, causing tar extraction to fail with `No space left on device`.
* **Fix:** Resized partition 3 online to 46 GB and executed `resize2fs /dev/mmcblk0p3`.

### H. Steam Tarball Extraction Timeout Loop
* **Problem:** `steam-health-check` was killed at 180s before 2.1 GB tar finished.
* **Fix:** Increased `TimeoutStartSec=600` in `99-odin.conf`. Once tar completed and `.install-complete` was touched, Steam now starts in ~3 seconds.

### I. SSH Latency (Reverse DNS Lookup)
* **Problem:** 20-second connection delay over local Wi-Fi.
* **Fix:** Added `UseDNS no` to `/etc/ssh/sshd_config.d/99-odin-dns.conf`.

---

## 3. Storage Performance Diagnosis

During the session, live benchmarks were executed on the active storage:
* **Hardware ID:** `mmc0:e624 SU64G 59.5 GiB` (SanDisk Ultra 64GB)
* **Hardware Bus:** `SDR50` @ 100MHz (50 MB/s theoretical max)
* **Direct Read Throughput:** **8.3 MB/s**
* **Direct Write Throughput:** **< 1.0 MB/s** (took > 4 minutes to sync 4 MB of data)

### Explanation of Lag Spikes:
When navigating Steam Big Picture Mode, Chromium (`steamwebhelper`) writes session state, telemetry, and web caches to `/home/steamos/.local/share/Steam/config/htmlcache`. Because the SanDisk Ultra's random 4K write speed is abysmal, the kernel's block flush workers (`flush-179:0`) lock the I/O channel. While locked, gamescope and steamwebhelper enter `D-state` (Uninterruptible Sleep waiting on disk), causing visible UI freezes until the write completes.

### Hardware Recommendation:
To get desktop/Steam Deck level smoothness:
* Upgrade to an **Application Performance Class A2** MicroSD card (e.g. **Samsung EVO Plus / PRO Plus**, **SanDisk Extreme / Extreme Pro**, **Lexar PLAY**).
* A2 cards have dedicated command queuing (Command Queueing / CQ) and guaranteed random write performance (>2000 IOPS write vs <100 IOPS on Ultra), providing **90-130 MB/s read** and **60-90 MB/s write**.

---

## 4. Current Device State

* **IP Address:** `192.168.86.20` (`odin3.local`)
* **SSH Access:** `ssh -o StrictHostKeyChecking=no steamos@192.168.86.20` (Passwordless sudo enabled)
* **Compositor:** `gamescope` running DRM backend on `DSI-1` @ 1920×1080 120Hz.
* **Steam Client:** `steamrtarm64/steam` and `steamwebhelper` running in Gamepad UI mode.
* **Controller:** `/dev/input/event6` mapped and active in Steam Big Picture.
* **Git Repository:** Remote `git@personal:Chazmus/SteamOS-ARM-Handhelds.git`, branch `odin3-sm8750`.
  * All fixes codified in:
    * `scripts/apply-overlays-sm8750.sh`
    * `sm8750-overlay/usr/lib/udev/rules.d/70-sm8750-gamepad.rules`
    * `steamos-overlay/usr/lib/systemd/user/steam.service.d/99-odin.conf`
    * `steamos-overlay/usr/share/deckard/RUNSTEAM.sh`

---

## 5. Next Steps for Tomorrow's Session

When starting the fresh session tomorrow:

1. **Software RAM Cache Optimizations (Until New SD Card Arrives):**
   * Mount Chromium's `htmlcache` to `tmpfs` (RAM disk) so web cache writes never hit the slow SD card:
     ```bash
     mkdir -p /home/steamos/.local/share/Steam/config/htmlcache
     # Add tmpfs mount to /etc/fstab:
     tmpfs /home/steamos/.local/share/Steam/config/htmlcache tmpfs defaults,noatime,mode=0755,uid=1000,gid=1000 0 0
     ```
   * Increase Linux dirty writeback ratio to prevent frequent synchronous stalls:
     ```bash
     sudo sysctl -w vm.dirty_writeback_centisecs=1500
     sudo sysctl -w vm.dirty_expire_centisecs=3000
     ```

2. **Audio Setup (WCD939x / WSA8845):**
   * Unmask audio services once spatial audio references are cleaned up.
   * Configure PipeWire ALSA sink for SM8750 stereo speakers.
   * Verify audio playback via `pw-play /usr/share/sounds/alsa/Front_Center.wav`.

3. **Game Launch Testing:**
   * Test installing and running a native Linux ARM64 game or benchmark.
   * Test x86_64 emulation through FEX-Emu (`/home/steamos/.local/share/Steam/steamapps/common/FEX-Emu/`).

4. **Power Management & Suspend:**
   * Test power button short press for suspend/resume under Gamescope.
