# Release and Versioning Strategy — SteamOS ARM Handhelds

This document outlines the version management architecture, component upgrade lifecycles, and automated release pipeline for the SteamOS ARM handheld ports (AYN Odin 3 / SM8750).

---

## 1. Architectural Philosophy: Two-Tier Build Cadence

Building an unofficial SteamOS distribution involves both lightweight platform customizations and heavyweight binary toolchains. To keep CI fast, reproducible, and affordable, this project separates builds into two speeds:

```
┌─────────────────────────────────────────────────────────────────┐
│                    FAST TIER (Image Assembly)                   │
│  • Handheld overlays (gamescope-session, odin3d fan daemon)     │
│  • Controller profiles (InputPlumber deck-uhid mappings)        │
│  • Audio UCM profiles & session scripts                         │
│  • Cadence: Frequent (PRs, bugfixes, feature iterations)        │
│  • Build Duration: ~10 minutes                                  │
└───────────────────────────────┬─────────────────────────────────┘
                                │ Consumes pinned, pre-built assets
┌───────────────────────────────┴─────────────────────────────────┐
│                    SLOW TIER (Core Binary Stacks)               │
│  • Kernel: Linux 7.2.0 from source with tracefs enabled         │
│  • Graphics: Mesa 26.2.3 (Turnip + Zink, 4 cross-slices)        │
│  • Base OS: Valve Deckard SteamOS rootfs (casync chunk store)   │
│  • Steam Client: Pre-bootstrapped sanitized ARM user seed       │
│  • Cadence: Infrequent (upstream major version bumps)           │
│  • Build Duration: 20 to 90 minutes                             │
└─────────────────────────────────────────────────────────────────┘
```

By decoupling image assembly from recompiling the core stacks, everyday commits and PRs can build and test fresh `.img` files in ~10 minutes on GitHub Actions.

---

## 2. Global Version Manifest (`versions.env`)

All upstream dependency versions, image hashes, and release tags are centralized in a single file at the root of the repository: [`versions.env`](../versions.env).

```bash
# --- Valve SteamOS Base (Steam Frame / Deckard) ---
STEAMOS_BUILD="20260925.6175226"
STEAMOS_BUNDLE="deckard-20260925.6175226-0.5.0"
STEAMOS_URL="https://steamdeck-images.steamos.cloud/vr/${STEAMOS_BUILD}"

# --- Mesa Graphics Stack (Turnip Adreno 830 Vulkan + Zink OpenGL) ---
MESA_VERSION="26.2.3"
MESA_SHA256="1628058a8d2c0615975de5a15ab7bbb9638c50000b5bed9456ff423ea034a81f"
NDK_VERSION="r27c"
NDK_SHA1="090e8083a715fdb1a3e402d0763c388abb03fb4e"

# --- Pre-Bootstrapped Steam Client Seed ---
STEAM_SEED_TAG="steam-seed-v1"

# --- Kernel & Distribution Upstream Pins ---
ROCKNIX_REF="20260901"
KVER="7.2"
```

### How It Is Consumed
- **Bash Scripts (`make-steamos-*.sh`, `scripts/build-mesa.sh`):** Automatically source `versions.env` if present, while allowing local environment variables to override them.
- **GitHub Actions Workflows:** Exported directly to `$GITHUB_ENV` in initial workflow steps, ensuring every job operates on identical pins.

---

## 3. Component Upgrade Runbooks

### A. Upgrading the Valve SteamOS Base (`STEAMOS_BUILD`)
Valve periodically updates the SteamOS ARM rootfs for the Steam Frame on `steamdeck-images.steamos.cloud`.
1. Update `STEAMOS_BUILD` and `STEAMOS_BUNDLE` in `versions.env`.
2. Trigger `build-image.yml` (or run `./make-steamos-sm8750.sh` locally).
3. The script automatically fetches the new `.raucb` bundle and reassembles the updated `rootfs.img` via casync.

### B. Upgrading the Mesa Graphics Stack (`MESA_VERSION`)
The Mesa stack requires four slices (`aarch64` native via rootfs bubblewrap, `x86_64` and `i386` cross-compiled for FEX, and `android` for Lepton):
1. Update `MESA_VERSION` and `MESA_SHA256` in `versions.env`.
2. Review/rebase patches in `external-and-mods/mesa/patches/` (such as Adreno 830 chip IDs).
3. Trigger the `.github/workflows/build-mesa.yml` workflow via GitHub Actions `workflow_dispatch`.
4. Once verified, publish the resulting `mesa-sm8750.tar.zst` artifact to a release asset tag and update the pointer.

### C. Upgrading the Kernel & ROCKNIX Tree
The Odin 3 kernel is compiled from source with `CONFIG_FTRACE=y` (enabling tracefs for `mangoapp` and `steamos-manager`):
1. Update `ROCKNIX_REF` or `KVER` in `versions.env` and `external-and-mods/kernel-sm8750/soc.env`.
2. Any commit modifying `external-and-mods/kernel-sm8750/**` automatically triggers `.github/workflows/build-kernel.yml` on native `ubuntu-24.04-arm` runners.
3. The new kernel artifact is built in ~13 minutes.

### D. Upgrading / Refreshing the Steam ARM Seed
The Steam client runs in user space under `/home/steamos/.local/share/Steam/`.
- **Why it is stable:** The seed includes `steam.cfg` with `BootStrapperInhibitAll=enable`, preventing the client from breaking itself with incompatible x86 CDN self-updates on handheld boot.
- **When to update:** Only when you explicitly desire newer Steam client UI features or protocol changes.
- **How to update:**
  1. Boot Steam on an ARM handheld or test environment with network access and allow it to update.
  2. Run `scripts/install-complete-steam-client.sh` sanitize logic to strip personal account data, credentials, and cache files.
  3. Compress the folder (`tar -cf - steam-arm-seed | zstd -3 -T0 > steam-arm-seed.tar.zst`).
  4. Create a new release tag (e.g. `steam-seed-v2`), upload the asset, and update `STEAM_SEED_TAG` in `versions.env`.

---

## 4. Git Tag-Driven Releases

Official image releases should be triggered automatically by pushing Git tags (e.g. `v1.3-beta11` or `v1.3-odin3-beta1`):

```bash
git tag v1.3-odin3-beta1
git push origin v1.3-odin3-beta1
```

### Automated Release Actions:
1. **Runner:** Spins up `ubuntu-24.04-arm`.
2. **Asset Retrieval:** Pulls the pinned Kernel, Mesa stack, and Steam Client seed.
3. **Assembly:** Downloads base rootfs, applies overlays, and packages the 3-partition image.
4. **Compression:** Compresses to `steamos-odin3-<tag>.img.zst`.
5. **Publishing:** Generates SHA256 checksums and attaches both files to the GitHub Release.

---

## 5. Upstream Integration Strategy

When opening a Pull Request to merge this CI pipeline into upstream `hashtagbasit/SteamOS-ARM-Handhelds`:

1. **Zero External Infrastructure Required:** Builds run entirely on GitHub's standard public `ubuntu-24.04-arm` runners.
2. **No Proprietary Hardcoded Paths:** Replaces local developer paths (`/home/steam/Desktop/...`) with reproducible manifests and public release assets.
3. **Graceful Fallbacks:** If pre-built assets are unavailable, scripts log warnings and fall back cleanly rather than halting the build.
4. **Clean Diff:** Overlays, kernel configurations, and build scripts retain upstream compatibility.
