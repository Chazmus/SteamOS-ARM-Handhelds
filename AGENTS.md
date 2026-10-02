# AGENTS.md — SteamOS ARM Handhelds (Odin 3 context)

This file provides context for AI coding agents working in this repository.
The primary target in active development is the **AYN Odin 3 (Snapdragon 8 Elite / SM8750)**.

---

## What this project is

An unofficial port of Valve's SteamOS ARM (originally built for the Steam Frame VR headset)
to Snapdragon handheld gaming devices. It produces a flashable `.img` containing:

- **p1 (BOOT, vfat)** — ABL + repacked Linux kernel (`KERNEL` boot image + DTB)
- **p2 (root, ext4)** — Modified SteamOS rootfs (Turnip Adreno GPU driver, Gamescope, overlays)
- **p3 (home, ext4)** — User data partition; pre-seeded with the Steam ARM client; auto-expands on first boot

Supported SoCs: SM8750 (Odin 3), SM8650 (KONKR/AYANEO), SM8550 (Odin 2 family), SM8350 (REDMAGIC 6).

---

## Repository layout

```
make-steamos-sm8750.sh          # Top-level build entry point for Odin 3 (SM8750)
make-steamos-sm8650.sh          # SM8650 / SM8550 image builder
make-steamos-sm8350.sh          # SM8350 fastboot kit builder

scripts/
  apply-overlays-sm8750.sh      # SM8750-specific overlay application (kernel, Mesa, sessions, services)
  apply-overlays-sm8650.sh      # SM8650/SM8550 equivalent
  apply-overlays.sh             # Shared overlay helpers
  install-complete-steam-client.sh  # Seeds the full Steam ARM client into the image
  build-mesa.sh                 # Builds Mesa 26.2.3 for aarch64 + FEX guests + Android
  build-gamescope-in-rootfs.sh
  build-*.sh                    # Other component builders

external-and-mods/
  kernel-sm8750/                # SM8750 kernel: extracts from ROCKNIX release
  kernel-sm8650/
  kernel-sm8550/
  kernel-sm8350/
  mesa/patches/                 # Mesa patches (incl. 0003-freedreno-a830-chip-ids.patch for Adreno 830)
  gamescope/
  BOX64/
  InputPlumber/
  Decky/

steamos-overlay/                # Overlays applied to every target (sessions, systemd units, scripts)
sm8750-overlay/                 # SM8750 / Odin 3 specific overlays (audio, display, InputPlumber)
sm8550-overlay/                 # SM8550 / Odin 2 family overlays (reused for some SM8750 paths)

sm8750-work/                    # Build working directory (gitignored)
  rootfs/                       #   Extracted official SteamOS rootfs (after overlays: modified in-place)
  kernel-sm8750-release/7.2.0/  #   Staged kernel + modules + firmware
  mesa-stack/                   #   Pre-built Mesa output tree (aarch64/, x86_64/, i386/, android/)
  steam-arm-seed/               #   Pre-bootstrapped complete Steam ARM client
  steamos-odin3.img             #   Final output image

docs/
  ODIN3-INSTALL.md              # Odin 3 flashing and first-boot guide
  building.md
  HOW-IT-WORKS.md
```

---

## Building for the Odin 3

The main build script is [`make-steamos-sm8750.sh`](make-steamos-sm8750.sh).
It runs three phases in order: `ensure_kernel` → `ensure_official_rootfs` → `apply_mods` → `build_image`.

### Full build (first time)

```bash
./make-steamos-sm8750.sh
```

Downloads the official Valve SteamOS rootfs, extracts it, applies all overlays, and packs the `.img`.
Requires `unsquashfs`, `sfdisk`, `mkfs.vfat`, `mkfs.ext4`, `uuidgen`, and Python 3.

### Incremental rebuilds

If the rootfs and overlays are already applied, use `--image-only` to just repack the image:

```bash
./make-steamos-sm8750.sh --image-only
```

Other flags:

| Flag | Effect |
|---|---|
| `--skip-download` | Reuse existing rootfs chunks (no re-download) |
| `--skip-apply` | Skip `apply-overlays-sm8750.sh` (rootfs already patched) |
| `--image-only` | Implies both above; only repacks the `.img` |
| `--img PATH` | Override output image path |

### Flashing

```bash
sudo dd if=sm8750-work/steamos-odin3.img of=/dev/sdX bs=4M status=progress
```

Boot: **Hold Volume Down → Boot Mode: Linux → START**

---

## Key environment variables

These are passed as env vars before the build script, e.g.:

```bash
STEAM_ARM_SEED=sm8750-work/steam-arm-seed ./make-steamos-sm8750.sh --image-only
```

### `STEAM_ARM_SEED` ⚡ (important for boot speed)

**What it does:** Points to a directory containing a fully bootstrapped Steam ARM client.
When set (and valid), [`scripts/install-complete-steam-client.sh`](scripts/install-complete-steam-client.sh)
`rsync`s the client directly into the image's `/home/steamos/.local/share/Steam/`, stripping all
account/login data so the device first-boots to a clean sign-in screen.

**Why it matters:** Without it, the script falls through to the `SteamARM` bootstrap path and
first boot has to download and unpack ~2.5 GB of Steam live on the device behind a black screen —
this takes roughly 10 minutes. Setting `STEAM_ARM_SEED` eliminates that entirely.

**The seed lives at:** `sm8750-work/steam-arm-seed/` (already present in the work directory,
gitignored alongside the rest of `sm8750-work/`).

**Completeness check** — the seed is valid when it has all three of:
- `steamrtarm64/steam` (executable)
- `steamrtarm64/steamui.so` (non-empty)
- `package/steam_client_*_linuxarm64.installed` OR `.odin-complete-client` (marker file)

**Always use `STEAM_ARM_SEED` for any rebuild** — the boot experience is significantly worse without it.

```bash
STEAM_ARM_SEED=sm8750-work/steam-arm-seed \
  ./make-steamos-sm8750.sh --image-only
```

### `MESA_STACK` ⚡ (required — OpenGL breaks without it)

Points to a pre-built Mesa 26.2.3 output tree (produced by `scripts/build-mesa.sh`) with four slices:
`aarch64/` (on-device), `x86_64/` + `i386/` (FEX x86 guest), `android/` (Lepton/Android container).

When set, `apply-overlays-sm8750.sh` replaces Valve's entire Mesa install with this custom build and
writes `60-sm8750-zink.conf` to force `MESA_LOADER_DRIVER_OVERRIDE=zink` (OpenGL through zink→Turnip,
matching how the retail Frame works).

**The stack lives at:** `sm8750-work/mesa-stack/` (gitignored).

**Why it's required:** Without `MESA_STACK`, the rootfs has no `msm` DRI driver and no zink fallback.
Xwayland fails to initialize GLAMOR (`msm: driver missing` → `couldn't create gbm device`), which
means OpenGL is unavailable. Steam's update UI requires GL and crashes immediately
(`UpdateUI GL not available`), causing an infinite crash-restart loop on boot (steam.service
`exit-code 1`, restarted by systemd every 2 seconds). **Always set `MESA_STACK` for any Odin 3 build.**

```bash
MESA_STACK=sm8750-work/mesa-stack \
STEAM_ARM_SEED=sm8750-work/steam-arm-seed \
  ./make-steamos-sm8750.sh --skip-download
```

### `GAMESCOPE_BUILD`

Path to a locally compiled Gamescope build directory. Required only when testing custom Gamescope
changes. The built binaries need `--force-composition-rotation` support (verified at apply time).

### Other env vars

| Variable | Default | Purpose |
|---|---|---|
| `STEAMOS_WORK` | `./sm8750-work` | Build working directory |
| `STEAMOS_ROOTFS` | `$STEAMOS_WORK/rootfs` | Path to the extracted SteamOS rootfs |
| `KERNEL_OUT` | `$STEAMOS_WORK/kernel-sm8750-release/7.2.0` | Staged kernel output |
| `STEAMOS_SM8750_IMG` | `$STEAMOS_WORK/steamos-odin3.img` | Output image path |
| `BOOT_MIB` | `512` | Boot partition size in MiB |
| `ROOT_MIB` | auto | Root partition size (auto-sized from rootfs usage + 1.5 GiB headroom) |
| `HOME_MIB` | auto | Home partition size (auto-sized from seeded home content + 4 GiB) |

---

## How the overlay system works

`apply-overlays-sm8750.sh` modifies the rootfs **in place** in `sm8750-work/rootfs/`. It:

1. Stages the SM8750 kernel, modules, and firmware
2. Optionally installs a custom Gamescope build
3. Applies the base SteamOS overlay (`steamos-overlay/`) — session scripts, systemd units, update stubs
4. Installs the Turnip/Mesa driver for Adreno 830 (from overlay `.so` or full `MESA_STACK`)
5. Applies the SM8750/Odin 3 overlay (`sm8750-overlay/`) — audio, display, InputPlumber, fan daemon
6. Sets up `/home/steamos` — Decky Loader, Steam client (via `install-complete-steam-client.sh`)

Overlays back up stock files into `rootfs/opt/stock-steamos/` before replacing them, so diffs
are traceable. A number of Valve VR headset services are masked (`/dev/null` symlinks) since they
crash or are irrelevant on the handheld.

---

## Common workflows

### Rebuild the image after changing an overlay file

```bash
# Re-apply overlays and repack (re-downloads nothing):
STEAM_ARM_SEED=sm8750-work/steam-arm-seed \
  ./make-steamos-sm8750.sh --skip-download

# Or if you only changed image-packing logic (not rootfs content):
STEAM_ARM_SEED=sm8750-work/steam-arm-seed \
  ./make-steamos-sm8750.sh --image-only
```

### Check what the last overlay run did

```bash
cat sm8750-work/odin3-apply.log
```

### Inspect the rootfs interactively

```bash
sudo chroot sm8750-work/rootfs /usr/bin/bash
```

### Check the Mesa version in the rootfs

```bash
sudo strings sm8750-work/rootfs/usr/lib/libvulkan_freedreno.so | grep "Mesa "
```

---

## What NOT to change without care

- **`steamos-overlay/usr/lib/steamos/gamescope-session`** — the main session launcher; wrong flags
  here cause a black screen on boot.
- **`sm8750-overlay/`** — device-specific audio UCM, display config, InputPlumber YAML. Changes here
  need testing on the physical device.
- **Systemd mask list in `apply-overlays-sm8750.sh`** — masking the wrong service can break Wi-Fi,
  audio, or input.
- **`scripts/extract_rootfs.py`** — downloads and assembles Valve's rootfs via casync; only touch
  if the Valve CDN format changes.
