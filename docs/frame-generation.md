# Frame generation

Lossless Scaling frame gen comes in two Decky plugins. Some games look better with one and some with the other, so both are installed. Use one per game, not both.

| Plugin | lsfg-vk | Launch option |
|---|---|---|
| **Decky LSFG-VK** | 2.0 | `~/.lsfg %command%` |
| **Frame Gen Classic** | 1.x | `~/lsfg-classic %command%` |

On Adreno, 2.0 draws garbage blocks in some games. If a game does that, switch it to Frame Gen Classic.

## Decky LSFG-VK (2.0)

1. In Steam, go to Lossless Scaling > Properties > Game Versions & Betas and pick the `lsfg-vk` branch.
2. Open the Decky LSFG-VK plugin and hit Install.
3. Pick a game in the plugin and set it up, then add `~/.lsfg %command%` to that game's launch options.

## Frame Gen Classic (1.x)

1. Install Lossless Scaling in Steam.
2. Open Frame Gen Classic and hit Install.
3. Set it up, then add `~/lsfg-classic %command%` to the game's launch options.

A game started through `~/lsfg-classic` gets only the 1.x layer: it also switches 2.0 off for that game, so the two never run together. Frame Gen Classic keeps its own settings in `~/.config/lsfg-vk-classic`.

Both start in performance mode with flow scale 0.5. On these GPUs the full-quality model costs about as much GPU time as the frames it adds.

## Layers

The plugins only come with x86 layers (those still cover x86 games under FEX), so the image adds ARM64 builds for ARM64 games:

- [lsfg-vk](https://lsfg-vk.dev) 2.0 by PancakeTAS, unmodified (CC BY-NC-ND 4.0, see [LICENSE](../LICENSE)).
- lsfg-vk 1.x from [lsfg-vk-arm64](https://github.com/hashtagbasit/lsfg-vk-arm64), with two fixes so Proton ARM64 games start (MIT).
