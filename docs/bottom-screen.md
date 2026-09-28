# The bottom screen (AYN Thor, AYANEO Pocket DS)

As far as I know this is the first time Valve's own SteamOS uses the second screen in Game Mode. The game stays on the top screen and the bottom screen gets its own dashboard:

- Steam, Quick Access, Keyboard and Screenshot buttons. Tap one and it opens on the top screen, no button combos needed
- performance profile (Silent, Balanced, Turbo) and fan boost
- brightness for each screen, volume and mute
- clock, battery, CPU/GPU temps, GPU clock and fan speed
- pin any app you like and it runs full screen down there while you play

Tap **Add apps** to pin apps. Tap a running app to switch to it, hold it to close it, and swipe up from the bottom edge to get back to the dashboard.

Touches on the bottom screen never reach the game, and Steam's brightness slider controls the top screen.

In Desktop Mode both screens are one desktop, each touchscreen working on its own screen.

## Turning it off

Set `"enabled": false` in `~/.config/steamos-arm/bottom-screen.json` and go back to Game Mode.

## How it works

Game Mode's gamescope keeps the top screen and lends the bottom panel to a second, small gamescope through a DRM lease. The dashboard runs in that one. The code is in `dualscreen-overlay/` and the lease bits are in our gamescope (`external-and-mods/gamescope/`).
