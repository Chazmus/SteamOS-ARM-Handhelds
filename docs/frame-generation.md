# Frame generation

Lossless Scaling frame gen works through the decky-lsfg-vk plugin.

1. In Steam, go to Lossless Scaling > Properties > Game Versions & Betas and pick the `lsfg-vk` branch.
2. Open the decky-lsfg-vk plugin and hit Install.
3. Pick a game in the plugin and set it up, then add `~/.lsfg %command%` to that game's launch options.

The plugin only comes with x86 layers (those still cover x86 games under FEX), so the image adds an unmodified ARM64 build of [lsfg-vk](https://lsfg-vk.dev) 2.0 by PancakeTAS for ARM64 games (CC BY-NC-ND 4.0, see [LICENSE](../LICENSE)).
