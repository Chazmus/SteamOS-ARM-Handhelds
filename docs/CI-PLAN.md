# CI Build Plan — SteamOS ARM (Odin 3 / SM8750)

> **Status:** Draft / MVP
> **Target:** GitHub Actions workflows to build and publish the Odin 3 image as an artifact.

---

## Overview

Three separate workflows, each producing a cached artifact that the final image
build consumes. The split keeps CI fast (only rebuild what changed) and works
around the fact that different components need different runner architectures
and have wildly different build times.

```
┌──────────────────────┐    ┌──────────────────────┐
│  build-kernel.yml    │    │   build-mesa.yml     │
│  ubuntu-24.04-arm    │    │  ubuntu-24.04-arm    │
│  ~20 min             │    │  ~1–2 hours          │
│  Trigger: manual /   │    │  Trigger: manual     │
│    kernel path push  │    │                      │
└────────┬─────────────┘    └─────────┬────────────┘
         │ kernel-sm8750              │ mesa-sm8750
         │ artifact (~30 MB)         │ artifact (~220 MB)
         ▼                           ▼
┌──────────────────────────────────────────────────┐
│              build-image.yml                     │
│              ubuntu-24.04-arm                    │
│              ~30–45 min                          │
│              Trigger: manual / main push         │
│                                                  │
│  1. Free disk space (~40 GB)                     │
│  2. Download kernel + Mesa artifacts             │
│  3. Download SteamOS rootfs (Valve CDN, casync)  │
│  4. Apply overlays                               │
│  5. Pack .img                                    │
│  6. Compress + upload                            │
│                                                  │
│  NOTE: No Steam ARM seed (MVP).                  │
│  First boot will have ~10 min black screen       │
│  while Steam bootstraps itself.                  │
└──────────────────────────────────────────────────┘
```

---

## Workflow 1: `build-kernel.yml`

**Purpose:** Build the SM8750 kernel from source with tracefs enabled.

- **Runner:** `ubuntu-24.04-arm` (native aarch64 — `build.sh` enforces `uname -m == aarch64`)
- **Triggers:** `workflow_dispatch`, push on `external-and-mods/kernel-sm8750/**` or `kernel-common/**`
- **Key dependency:** ROCKNIX/distribution git checkout (sparse clone at tag `20260901`)
- **Build time:** ~15–25 min
- **Artifact:** `kernel-sm8750` (~30 MB compressed)

### Why from-source?

ROCKNIX's prebuilt kernel ships without `CONFIG_FTRACE`. Without ftrace/tracefs:
- mangoapp (Performance Overlay) crashes immediately
- steamos-manager stalls Game Mode boot by ~3 minutes
- "Switch to Desktop" and update checks don't work

Building from source with our `steamos.config` fragment enables tracefs with
zero runtime overhead (`CONFIG_ENABLE_DEFAULT_TRACERS=y`).

---

## Workflow 2: `build-mesa.yml`

**Purpose:** Build the Mesa 26.2.3 graphics stack (Turnip Vulkan + Zink OpenGL)
for Adreno 830, in four architecture slices.

- **Runner:** `ubuntu-24.04-arm` (aarch64 build runs inside rootfs via bwrap)
- **Triggers:** `workflow_dispatch` only (Mesa rarely changes)
- **Key dependency:** SteamOS rootfs (needed as build environment for the aarch64 slice)
- **Build time:** ~1–2 hours
- **Artifact:** `mesa-sm8750` (~220 MB compressed)

### Output slices

| Slice | Target | Purpose |
|-------|--------|---------|
| `aarch64/` | ARM64 native | On-device Turnip + Zink |
| `x86_64/` | x86_64 guest | FEX emulated x86_64 games |
| `i386/` | i686 guest | FEX emulated 32-bit games |
| `android/` | Android/Bionic | Lepton (Valve's Android container) |

---

## Workflow 3: `build-image.yml`

**Purpose:** Assemble the final flashable `.img` from pre-built kernel, Mesa,
and the downloaded SteamOS rootfs.

- **Runner:** `ubuntu-24.04-arm`
- **Triggers:** `workflow_dispatch`, push to `main`
- **Requires:** Successful `build-kernel.yml` and `build-mesa.yml` runs
- **Build time:** ~30–45 min (dominated by rootfs download)
- **Artifact:** `steamos-odin3.img.zst` (~6–8 GB compressed)

### MVP limitations

- **No Steam ARM seed.** First boot will spend ~10 minutes downloading the
  Steam client behind a black screen. Functional but poor UX. A future
  iteration could pull a pre-built seed from external storage.
- **Image published as a workflow artifact** (90-day retention, not a release).
- **Licensing caveat:** The image contains Valve's proprietary SteamOS rootfs.
  Artifacts should remain private / not attached to public releases without
  reviewing Valve's redistribution terms.

---

## Disk space strategy

GitHub ARM runners have ~14 GB free out of the box. The image build needs
~50 GB. All workflows that need significant disk run this cleanup first:

```bash
sudo rm -rf /usr/local/lib/android /usr/share/dotnet \
  /opt/hostedtoolcache /usr/local/.ghcup /usr/share/swift \
  /usr/local/share/boost
sudo docker image prune -af 2>/dev/null || true
```

This typically frees 30–40 GB.

---

## Cross-workflow artifact sharing

Kernel and Mesa workflows upload artifacts via `actions/upload-artifact@v4`.
The image workflow downloads them via `gh run download` (GitHub CLI), finding
the latest successful run of each upstream workflow:

```bash
RUN_ID=$(gh run list --workflow=build-kernel.yml \
  --status=success --limit=1 --json databaseId -q '.[0].databaseId')
gh run download "$RUN_ID" -n kernel-sm8750 -D ./kernel-out/
```

---

## Future improvements

1. **Steam ARM seed:** Upload pre-bootstrapped seed to cloud storage; download in image build
2. **GitHub Releases:** Publish compressed images as release assets (after licensing review)
3. **Caching:** Cache rootfs chunks, ROCKNIX checkout, kernel source tarball across runs
4. **Matrix builds:** Support SM8650/SM8550 targets alongside SM8750
5. **Automated testing:** At minimum, mount the image and verify key files exist
