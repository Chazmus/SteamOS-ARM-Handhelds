#!/usr/bin/env python3
"""Decky backend: Emulator Hub.

A thin front for steamos-arm-hub, which does the work as this user (no root:
AppImages go to ~/Applications, Flatpaks are user installs). Jobs run in the
hub's own processes, so closing the panel mid-install changes nothing.
"""
from __future__ import annotations

import asyncio
import json
import os
import subprocess

import decky

HUB = "/usr/lib/steamos-arm/hub/hub.py"


def hub(*args: str, timeout: int = 60) -> dict:
    env = dict(os.environ)
    # Decky's bundled Python sets these for itself; the hub uses the system one.
    for k in ("LD_LIBRARY_PATH", "PYTHONHOME", "PYTHONPATH"):
        env.pop(k, None)
    env["HOME"] = decky.DECKY_USER_HOME
    env.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    try:
        r = subprocess.run(["/usr/bin/python3", HUB, *args], capture_output=True, text=True,
                           timeout=timeout, env=env)
        return json.loads(r.stdout or "{}")
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        return {"error": str(exc)}


class Plugin:
    async def status(self):
        return await asyncio.to_thread(hub, "status")

    async def jobs(self):
        return await asyncio.to_thread(hub, "jobs")

    async def install(self, app):
        return await asyncio.to_thread(hub, "install", app)

    async def update(self, app):
        return await asyncio.to_thread(hub, "update", app)

    async def remove(self, app, wipe=False):
        return await asyncio.to_thread(hub, "remove", app, *(["--wipe"] if wipe else []))

    async def cancel(self, job):
        return await asyncio.to_thread(hub, "cancel", job)

    async def starter(self):
        return await asyncio.to_thread(hub, "starter")

    async def check_updates(self):
        return await asyncio.to_thread(hub, "check-updates", timeout=180)

    async def update_all(self):
        return await asyncio.to_thread(hub, "update-all")

    async def library(self, where=None):
        return await asyncio.to_thread(hub, "library", *([where] if where else []), timeout=600)

    async def reset(self, app):
        return await asyncio.to_thread(hub, "reset", app)

    async def add_file(self, path):
        return await asyncio.to_thread(hub, "add-file", path)

    async def desktop(self):
        return await asyncio.to_thread(hub, "desktop")

    async def steam_pending(self):
        return await asyncio.to_thread(hub, "steam-pending")

    async def steam_made(self, app, appid):
        return await asyncio.to_thread(hub, "steam-made", app, str(int(appid)))

    async def steam_gone(self, app):
        return await asyncio.to_thread(hub, "steam-gone", app)

    async def _main(self):
        # Icons for the list, fetched once in the background.
        await asyncio.to_thread(hub, "icons", timeout=300)

    async def _unload(self):
        pass
