<p align="center">
  <a href="https://steamos-arm-port.github.io/">
    <img src=".github/assets/logo.svg" alt="SteamOS ARM Port" width="112">
  </a>
</p>

<h1 align="center">SteamOS ARM Port</h1>

<p align="center"><strong>Unofficial SteamOS for Snapdragon handhelds</strong></p>

<p align="center">
  Valve's SteamOS for ARM, the one made for the Steam Frame, set up for handhelds:
  Game Mode, the KDE desktop, PC games through FEX and Proton, and Android apps.
</p>

<p align="center">
  <a href="https://github.com/hashtagbasit/SteamOS-ARM-Port/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/hashtagbasit/SteamOS-ARM-Port?include_prereleases&style=flat&color=7c5cf0&label=release"></a>
  <a href="https://steamos-arm-port.github.io/"><img alt="Documentation" src="https://img.shields.io/badge/docs-steamos--arm--port.github.io-18181a?style=flat"></a>
  <a href="LICENSE"><img alt="GPL-2.0 license" src="https://img.shields.io/badge/license-GPL--2.0-18181a?style=flat"></a>
  <a href="https://discord.gg/EP53nZYvg"><img alt="Discord" src="https://img.shields.io/badge/chat-Discord-5865F2?style=flat&amp;logo=discord&amp;logoColor=white"></a>
</p>

<p align="center">
  <a href="https://steamos-arm-port.github.io/getting-started/install/"><strong>Install it</strong></a>
  ·
  <a href="https://steamos-arm-port.github.io/devices/">Supported devices</a>
  ·
  <a href="https://steamos-arm-port.github.io/downloads/">Downloads</a>
  ·
  <a href="https://steamos-arm-port.github.io/help/known-issues/">Known issues</a>
</p>

> [!WARNING]
> This is a community project, not affiliated with or endorsed by Valve.
> Installing it means flashing the ROCKNIX ABL bootloader, and getting that
> wrong can leave your device unable to boot or lose your data. Back up first
> and follow the [install guide](https://steamos-arm-port.github.io/getting-started/install/)
> step by step.

## About

Valve's ARM build of SteamOS is made for a VR headset, so out of the box a lot
of it gets in the way on a handheld: services that keep crashing, the UI stuck
on the slow cores, the GPU not clocking up, standby that drains the battery. I
turned off what a handheld doesn't need and fixed the rest, the long version
is in [HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

What you get:

- Game Mode and Desktop Mode, with the controller showing up as a Steam Deck pad
- x86 PC games through FEX and ARM64 Proton, plus Epic, GOG and Amazon through Heroic
- Loadout, which installs emulators and apps picked for your chip
- Sleep that lasts and quiet fan curves
- Updates through Steam, no reflashing
- Lossless Scaling frame gen, Decky and the performance overlay
- Android apps with the Play Store
- A dashboard on the bottom screen of the AYN Thor and AYANEO Pocket DS

## Devices

| Chip | Devices | Status |
|---|---|---|
| Snapdragon 8 Elite | AYN Odin 3, KONKR Pocket FIT Elite | Stable |
| Snapdragon 8 Gen 3 | KONKR Pocket FIT, AYANEO Pocket S2 / S2 Pro | Stable |
| Snapdragon 8 Gen 2 | AYN Odin 2 / Mini / Portal / Thor, AYANEO Pocket ACE / DMG / DS / EVO / S 1K / S 2K, Retroid Pocket 6 / Nova | Stable |
| Snapdragon 888 | REDMAGIC 6 | Build it yourself ([guide](docs/redmagic6.md)) |

There's one image per chip, you pick your device in the ABL menu and it sets
itself up. I only own a Pocket FIT, so if you have one of the others please
[let me know how it runs](https://github.com/hashtagbasit/SteamOS-ARM-Port/issues).

### Lenovo tablets (testing)

| Tablet | Chip | Status |
|---|---|---|
| Lenovo Legion Y700 Gen 3 (TB321FU) | Snapdragon 8 Gen 3 | Testing |
| Lenovo Legion Y700 Gen 4 (TB322FC) | Snapdragon 8 Elite | Testing |

These boot from a USB drive and install to internal storage, nobody has run
them on a real tablet yet. If you have one and want to help, ask on
[Discord](https://discord.gg/EP53nZYvg) and see the
[Lenovo page](https://steamos-arm-port.github.io/devices/lenovo/).

## Documentation

Everything lives on the [website](https://steamos-arm-port.github.io/).

| I want to… | Guide |
|---|---|
| Install it | [Flash to a microSD card](https://steamos-arm-port.github.io/getting-started/install/) |
| Check my device | [Supported devices](https://steamos-arm-port.github.io/devices/) |
| Move it to internal storage | [Internal storage](https://steamos-arm-port.github.io/getting-started/internal-storage/) |
| Update | [Updates](https://steamos-arm-port.github.io/using/updates/) |
| Get help | [FAQ](https://steamos-arm-port.github.io/help/faq/) · [Troubleshooting](https://steamos-arm-port.github.io/help/troubleshooting/) |
| Report a bug | [GitHub issues](https://github.com/hashtagbasit/SteamOS-ARM-Port/issues) |

## Building

The images are built from this repo on an ARM64 Linux machine, see
[docs/building.md](docs/building.md). Issues and pull requests are welcome,
and for help with installing come say hi on [Discord](https://discord.gg/EP53nZYvg).

## Supporting the project

I work on this in my free time and it's free for everyone. If it helped you
out, a coffee means a lot.

<p align="left">
  <a href="https://ko-fi.com/aimalb"><img src="https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-ff5e5b?style=for-the-badge&logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://paypal.me/Basit2000"><img src="https://img.shields.io/badge/PayPal-Basit2000-00457c?style=for-the-badge&logo=paypal&logoColor=white" alt="PayPal"></a>
</p>

If you can't donate, starring the repo helps too!

## Credits

The kernels and device support come from [ROCKNIX](https://github.com/ROCKNIX/distribution).
The full list of projects and people is in [CREDITS.md](CREDITS.md).

## License

My scripts and overlays are GPL-2.0, everything in `external-and-mods/` keeps
its own license. See [LICENSE](LICENSE).

Steam and SteamOS are trademarks of Valve Corporation, used here only to say
what this is based on. Please don't ask Valve for help with it.
