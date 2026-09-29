# SteamOS ARM for handhelds

This is Valve's official SteamOS for ARM, the build they made for the Steam Frame, running on Snapdragon handhelds. You get Game Mode and the KDE desktop just like on a Steam Deck. The Frame software is made for a VR headset though, so I've spent a lot of time on the stuff that makes it annoying on a handheld (battery, fan, lag, broken overlay etc.).

## Supported chips

| Chip | Devices | Status |
|---|---|---|
| Snapdragon 8 Gen 3 (SM8650) | KONKR Pocket FIT, AYANEO Pocket S2 / S2 Pro | stable ([v1.2](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/releases/tag/v1.2)) |
| Snapdragon 8 Gen 2 (SM8550) | AYN Odin 2 / Mini / Portal / Thor, AYANEO Pocket ACE / DMG / DS / EVO / S 1K / S 2K, Retroid Pocket 6 / Nova | pre-release beta [v1.3 beta 5](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/releases/tag/v1.3-beta5) |

There's one image per chip and you pick your device in the ABL menu, the system figures out the rest. More chips will come later.

I only own a Pocket FIT, so if you have one of the others please [let me know how it runs](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/issues).

## Features

- Game Mode and Desktop Mode, x86 games through FEX and ARM64 Proton
- the controller shows up as a Steam Deck controller, back buttons too
- on the AYN Thor and AYANEO Pocket DS the bottom screen gets its own dashboard in Game Mode (Steam buttons, profiles, brightness, and any apps you want down there)
- standby that actually saves battery (around 1W, the stock image sits at 3W+) and a proper fan curve
- Lossless Scaling frame gen on ARM, Decky, the performance overlay
- Android apps with the Play Store
- updates install over your current system, no reflashing

## Guides

| | |
|---|---|
| Installing | [docs/install.md](docs/install.md) |
| Moving it to internal storage | [docs/internal-storage.md](docs/internal-storage.md) |
| Updating | [docs/updating.md](docs/updating.md) |
| The bottom screen | [docs/bottom-screen.md](docs/bottom-screen.md) |
| Frame generation | [docs/frame-generation.md](docs/frame-generation.md) |
| Android apps | [docs/android-apps.md](docs/android-apps.md) |
| Profiles, commands, SSH | [docs/tips.md](docs/tips.md) |
| Known issues | [docs/known-issues.md](docs/known-issues.md) |
| Building it yourself | [docs/building.md](docs/building.md) |

Found a bug? [Open an issue](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/issues).

## What's different from other ARM builds

Most other builds ship the Frame software pretty much as it is, and it's made for a VR headset. Out of the box a bunch of Frame services keep crashing in the background (that's a big part of why standby drains so fast), games and the Steam UI end up on the slow little cores so menus lag, the GPU doesn't clock as high as on Android, and things like the overlay and some ARM64 Proton games just don't work. I turned off what's useless on a handheld and fixed the rest, the long version is in [HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## Supporting the project

I work on this in my free time and it's free for everyone. If it helped you out, a coffee means a lot.

<p align="left">
  <a href="https://ko-fi.com/aimalb"><img src="https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-ff5e5b?style=for-the-badge&logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://paypal.me/Basit2000"><img src="https://img.shields.io/badge/PayPal-Basit2000-00457c?style=for-the-badge&logo=paypal&logoColor=white" alt="PayPal"></a>
</p>

If you can't donate, starring the repo helps too!

## Credits

The kernel and all the device support come from [ROCKNIX](https://github.com/ROCKNIX/distribution), and some of the early groundwork came from [MaSi's SM8550 project](https://github.com/MaSieS4Fun/SteamOS-ARM-SM8550). Big thanks to both, the full list is in [CREDITS.md](CREDITS.md).

## License

My scripts and overlays are GPL-2.0, everything in `external-and-mods/` keeps its own license. See [LICENSE](LICENSE).
