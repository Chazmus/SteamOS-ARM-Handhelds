#!/usr/bin/env python3
"""Decky backend: Loadout.

A thin front for the Loadout engine (loadout.py on top of hub.py), which does
the work as this user (no root: AppImages and app folders go to
~/Applications, Flatpaks are user installs). Jobs run in the engine's own
processes, so closing the store mid-install changes nothing.
"""
from __future__ import annotations

import asyncio
import base64
import json
import os
import subprocess

import decky

ENGINE = "/usr/lib/steamos-arm/hub/loadout.py"


def engine(*args: str, timeout: int = 60) -> dict:
    env = dict(os.environ)
    # Decky's bundled Python sets these for itself; the engine uses the system one.
    for k in ("LD_LIBRARY_PATH", "PYTHONHOME", "PYTHONPATH"):
        env.pop(k, None)
    env["HOME"] = decky.DECKY_USER_HOME
    env.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    try:
        r = subprocess.run(["/usr/bin/python3", ENGINE, *args], capture_output=True, text=True,
                           timeout=timeout, env=env)
        return json.loads(r.stdout or "{}")
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        return {"error": str(exc)}


def icon_data(path: str) -> str:
    """The icon at path as a data: URL. Steam's pages can't load file://
    images, so the panel gets the bytes; only the engine's own icons."""
    icons = os.path.realpath(os.path.join(decky.DECKY_USER_HOME, ".local/share/icons/hicolor"))
    real = os.path.realpath(path or "")
    if not real.startswith(icons + os.sep) or not real.endswith(".png"):
        return ""
    try:
        with open(real, "rb") as fh:
            data = fh.read(512 * 1024)
    except OSError:
        return ""
    return "data:image/png;base64," + base64.b64encode(data).decode()


class Plugin:
    async def icon(self, path):
        return await asyncio.to_thread(icon_data, path)

    async def status(self):
        return await asyncio.to_thread(engine, "status")

    async def discover(self):
        return await asyncio.to_thread(engine, "discover", timeout=120)

    async def jobs(self):
        return await asyncio.to_thread(engine, "jobs")

    async def install(self, app):
        return await asyncio.to_thread(engine, "install", app)

    async def update(self, app):
        return await asyncio.to_thread(engine, "update", app)

    async def remove(self, app, wipe=False):
        return await asyncio.to_thread(engine, "remove", app, *(["--wipe"] if wipe else []))

    async def cancel(self, job):
        return await asyncio.to_thread(engine, "cancel", job)

    async def starter(self):
        return await asyncio.to_thread(engine, "starter")

    async def bundle(self, bundle_id):
        return await asyncio.to_thread(engine, "bundle", bundle_id)

    async def bios(self, app):
        return await asyncio.to_thread(engine, "bios", app)

    async def check_updates(self):
        return await asyncio.to_thread(engine, "check-updates", timeout=180)

    async def update_all(self):
        return await asyncio.to_thread(engine, "update-all")

    async def library(self, where=None):
        return await asyncio.to_thread(engine, "library", *([where] if where else []), timeout=600)

    async def reset(self, app):
        return await asyncio.to_thread(engine, "reset", app)

    async def sizes(self):
        return await asyncio.to_thread(engine, "sizes", timeout=60)

    async def inspect(self, path):
        return await asyncio.to_thread(engine, "inspect", path)

    async def add_game(self, path, as_="", name="", app="", proton=""):
        args = ["add-game", path]
        for flag, value in (("--as", as_), ("--name", name), ("--app", app), ("--proton", proton)):
            if value:
                args += [flag, value]
        return await asyncio.to_thread(engine, *args, timeout=300)

    async def add_file(self, path):
        return await asyncio.to_thread(engine, "add-file", path)

    async def art(self, title):
        return await asyncio.to_thread(engine, "art", title, timeout=90)

    async def store_games(self):
        return await asyncio.to_thread(engine, "store-games")

    async def add_store_game(self, store, gid, proton=""):
        return await asyncio.to_thread(engine, "add-store-game", store, gid,
                                       *(["--proton", proton] if proton else []))

    async def added(self):
        return await asyncio.to_thread(engine, "added")

    async def remove_added(self, key):
        return await asyncio.to_thread(engine, "remove-added", key)

    async def compat_done(self, key):
        return await asyncio.to_thread(engine, "compat-done", key)

    async def desktop(self):
        return await asyncio.to_thread(engine, "desktop")

    async def steam_pending(self):
        return await asyncio.to_thread(engine, "steam-pending")

    async def steam_made(self, app, appid):
        return await asyncio.to_thread(engine, "steam-made", app, str(int(appid)))

    async def steam_gone(self, app):
        return await asyncio.to_thread(engine, "steam-gone", app)

    async def _main(self):
        # Icons for the store, fetched once in the background.
        await asyncio.to_thread(engine, "icons", timeout=300)

    async def _unload(self):
        pass
