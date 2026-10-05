# Themes

The stats at the top of the bottom screen's dashboard are drawn by a skin.
The controls under them (profiles, fan, brightness, lights...) are not part
of a skin, so a skin can never take them away.

Built in: `pulse`, `aura`, `gauges`, `black`. Your own go in
`~/.local/share/steamos-arm/skins/<name>/` and show up in Settings → Theme,
with a live preview, next to the built-in ones.

A skin folder holds:

- `Skin.qml`, the root item. Give it an `implicitHeight`; it gets the full
  width of the dashboard.
- `skin.json`: `{ "title": "...", "about": "...", "colors": {...} }`.
  `colors` is optional and recolours the whole interface, not only the
  dashboard: any of `bg`, `bgTop`, `card`, `cardTop`, `cardEdge`, `cardHi`,
  `button`, `line`, `accent`, `accentSoft`, `text`, `dim`, `faint`, as
  `#rrggbb` or `#aarrggbb`. See `aura/skin.json`.
- anything else it uses, by relative path.

`Skin.qml` declares `property var dash`, which the dashboard sets. Give it
`readonly property bool stretch: true` and it gets whatever height the
controls leave (up to `maxHeight`, if it sets one) instead of its
`implicitHeight`. To use the
dashboard's look and its building blocks (`Ui`, `Txt`, `Card`, `Meter`...),
import them with
`import "file:///usr/lib/steamos-arm/bottom-screen/qml"`.

| `dash.` | |
|---|---|
| `st` | the latest stats, once a second: `fps`, `battery {percent, status, hours_left}`, `temps {cpu, gpu, hot}`, `cpu {ghz, load}`, `gpu {mhz, max_mhz}`, `power_w`, `memory {used_gb, total_gb}`, `fan`, `fan_mode`, `net {down, up}`, `refresh {rates, choice}`, `game {appid, name, art {hero, logo, cover, blur}}`, `fg {multiplier}` |
| `fpsHist` | the frame rate once a second over the last minute (empty with no game) |
| `fpsAvg`, `fpsMin` | over that minute |
| `graphPoints(w, h)` | `fpsHist` as points for a `PathPolyline` |
| `batteryLine()` | "2 h 36 min left", "charging"... |
| `cpuHist`, `gpuHist`, `powHist`, `heatHist` | the last minute of each, for `Spark` |
| `sessionLine()`, `energyWh` | how long this game has run, and the energy it took |
| `drawLine()` | how long the battery lasts at the last minute's draw |
| `cap(text)` | Capitalised |

Fields may be added later, so guard against missing ones. A skin that fails
to load falls back to Pulse; Settings shows why.
