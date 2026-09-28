# SteamOS ARM for handhelds

Valve's official SteamOS for ARM (the one made for the Steam Frame), running on Snapdragon handhelds. The real Game Mode and the real KDE desktop, same as on a Steam Deck, tuned so it actually feels good on a handheld.

## Supported chips

| Chip | Devices | Status |
|---|---|---|
| Snapdragon 8 Gen 3 (SM8650) | KONKR Pocket FIT, AYANEO Pocket S2 / S2 Pro | stable ([v1.2](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/releases/tag/v1.2)) |
| Snapdragon 8 Gen 2 (SM8550) | AYN Odin 2 / Mini / Portal / Thor, AYANEO Pocket ACE / DMG / DS / EVO / S 1K / S 2K, Retroid Pocket 6 / Nova | beta |

One image per chip. Pick your device in the ABL menu and the system sets itself up for it. More chips are coming.

I don't own the 8 Gen 2 devices or the Pocket S2, so if you have one, [tell me what works](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/issues).

## Highlights

- Game Mode and Desktop Mode, x86 games through FEX and ARM64 Proton
- your controller shows up as a Steam Deck controller, back buttons included
- a real bottom screen on the AYN Thor and AYANEO Pocket DS: Steam buttons, profiles, brightness and your own apps down there while you play
- standby that saves battery (around 1W instead of 3W+) and a proper fan curve
- Lossless Scaling frame gen on ARM, Decky, the performance overlay
- Android apps with the Google Play Store
- updates install in place, no reflashing

## I want to...

| | |
|---|---|
| install it | [Installing](docs/install.md) |
| move it to internal storage | [Internal storage](docs/internal-storage.md) |
| update to a new version | [Updating](docs/updating.md) |
| use the second screen | [Bottom screen](docs/bottom-screen.md) |
| set up frame generation | [Frame generation](docs/frame-generation.md) |
| run Android apps | [Android apps](docs/android-apps.md) |
| change profiles, use SSH | [Profiles, commands and SSH](docs/tips.md) |
| check what's broken | [Known issues](docs/known-issues.md) |
| build it myself | [Building](docs/building.md) |
| report a bug | [Open an issue](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/issues) |

## What's different

The Steam Frame image is built for a VR headset, and other ARM builds pretty much ship it as is. Here the Frame services that crash-loop in the background are off, games and the Steam UI stay off the slow little cores, the GPU clocks up like on Android, speakers get louder without clipping, and a bunch of Proton and Quick Access bugs are fixed. The details are in [HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## Supporting the project

I work on this in my spare time and it's free. If it got your device running the way you wanted, a coffee really helps.

<p align="left">
  <a href="https://ko-fi.com/aimalb"><img src="https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-ff5e5b?style=for-the-badge&logo=kofi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://paypal.me/Basit2000"><img src="https://img.shields.io/badge/PayPal-Basit2000-00457c?style=for-the-badge&logo=paypal&logoColor=white" alt="PayPal"></a>
</p>

Can't donate? A star helps too.

## Credits

The kernel and device support come from [ROCKNIX](https://github.com/ROCKNIX/distribution), and some of the groundwork for putting SteamOS ARM on a handheld came from [MaSi's SM8550 project](https://github.com/MaSieS4Fun/SteamOS-ARM-SM8550). Huge thanks to both. Everything else is in [CREDITS.md](CREDITS.md).

## License

Scripts and overlays are GPL-2.0, everything in `external-and-mods/` keeps its own license. See [LICENSE](LICENSE).
