#!/bin/bash
# build-heroic-arm64.sh OUT_DIR
# Heroic Games Launcher for SteamOS ARM (aarch64), as one folder Loadout
# unpacks into ~/Applications/Heroic. Heroic only publishes x86 Linux builds,
# so this builds it from the release source on the VM (native arm64):
#
#   helpers   legendary (Epic), gogdl (GOG), nile (Amazon): Python, installed
#             with their dependencies into a private folder for the image's
#             Python 3.12 and run by small wrappers; nothing goes system-wide
#   heroic    the Electron app, electron-builder --dir for arm64
#
# Games Heroic installs are played from Steam with Steam's own Proton (Loadout
# adds them), so no extra Wine is needed; Heroic's own downloads of x86 Wine
# and DXVK are switched off in its first-run defaults.
set -euo pipefail
OUT=${1:-/work/heroic-arm64}
HEROIC=2.22.3
LEGENDARY=0.21.1
GOGDL=v1.3.0
NILE=v1.2.0
W=${WORK:-/work}/heroic-build
mkdir -p "$W" "$OUT"
rm -rf "$W/src" "$W/helpers"

# ---- Heroic's source -------------------------------------------------
curl -fsSL "https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/archive/refs/tags/v$HEROIC.tar.gz" \
  | tar -xz -C "$W" && mv "$W/HeroicGamesLauncher-$HEROIC" "$W/src"

# ---- store helpers for Python 3.12 (the image's) ----------------------
docker run --rm -v "$W:/w" python:3.12-bookworm bash -euc "
  apt-get -qq update >/dev/null && apt-get -qq install -y git >/dev/null
  pip -q install --upgrade pip setuptools wheel
  mkdir -p /w/helpers/py
  pip -q install --no-compile --target /w/helpers/py \
    'git+https://github.com/legendary-gl/legendary@$LEGENDARY' \
    'git+https://github.com/Heroic-Games-Launcher/heroic-gogdl@$GOGDL'
  # nile has no package list setuptools accepts (an assets/ folder sits next
  # to it): its dependencies from pip, the package itself copied in.
  git clone -q --depth 1 --branch $NILE https://github.com/imLinguin/nile /tmp/nile
  pip -q install --no-compile --target /w/helpers/py -r /tmp/nile/requirements.txt
  cp -a /tmp/nile/nile /w/helpers/py/nile
  rm -rf /w/helpers/py/bin
  find /w/helpers/py -name __pycache__ -prune -exec rm -rf {} +
"

D="$W/src/public/bin/arm64/linux"
mkdir -p "$D"
cp -a "$W/helpers/py" "$D/py"
for tool in legendary gogdl nile; do
  cat > "$D/$tool" <<EOF
#!/bin/sh
# $tool for Heroic on SteamOS ARM: the bundled Python package, run with the
# system Python 3.12.
here=\$(dirname "\$(readlink -f "\$0")")
PYTHONPATH="\$here/py\${PYTHONPATH:+:\$PYTHONPATH}" exec /usr/bin/python3 -c 'import sys
from $tool.cli import main
sys.argv[0] = "$tool"
sys.exit(main())' "\$@"
EOF
  chmod 0755 "$D/$tool"
done

# ---- the Electron app -------------------------------------------------
docker run --rm -v "$W/src:/src" -w /src node:22-bookworm bash -euc "
  corepack enable >/dev/null 2>&1 || npm i -g pnpm@10 >/dev/null
  pnpm install --frozen-lockfile --ignore-scripts
  pnpm run build
  pnpm exec electron-builder --linux dir --arm64 --publish never
"
APP="$W/src/dist/linux-arm64-unpacked"
[[ -x "$APP/heroic" ]] || { echo "build-heroic-arm64: no heroic binary" >&2; exit 1; }
[[ -x "$APP/resources/app.asar.unpacked/build/bin/arm64/linux/legendary" ]] \
  || { echo "build-heroic-arm64: helpers missing from the package" >&2; exit 1; }

# ---- check the helpers start on Python 3.12 ---------------------------
docker run --rm -v "$APP:/app:ro" python:3.12-slim-bookworm sh -euc '
  b=/app/resources/app.asar.unpacked/build/bin/arm64/linux
  $b/legendary --version; $b/gogdl --version; $b/nile --version'

# ---- bundle ------------------------------------------------------------
name="Heroic-$HEROIC-steamos-arm-aarch64"
rm -rf "$W/$name"; cp -a "$APP" "$W/$name"
tar -C "$W" -cJf "$OUT/$name.tar.xz" "$name"
(cd "$OUT" && sha256sum "$name.tar.xz" > "$name.tar.xz.sha256")
ls -la "$OUT"
echo "HEROIC DONE"
