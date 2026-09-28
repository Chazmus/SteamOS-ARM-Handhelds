# Known issues

## All devices

- Real kernel sleep isn't there yet, standby is used instead (panel off, apps paused, around 1W). `konkrctl sleep s2idle` tries the real thing.

## 8 Gen 3 (KONKR Pocket FIT, AYANEO Pocket S2)

- **Games flicker below 1080p** (picture jumps between full screen and the top-left corner). Fixed by the [v1.2.1 hotfix](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/releases/tag/v1.2.1), and built into v1.3.

## 8 Gen 2 (beta)

- Nobody has booted this on real hardware yet, that's what the beta is for.
- No internal storage installer yet, SD card only.

If something else breaks for you, [open an issue](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/issues) and say which device you have.
