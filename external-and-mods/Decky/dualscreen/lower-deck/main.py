"""Lower Deck: the bottom screen from Steam's Quick Access.

Everything here goes through the bottom screen's own backend (the
`dashboard` service), which writes its address and a token to
/run/user/<uid>/bottom-screen.api. So the panel and the screen always agree,
and nothing is stored twice.
"""
from __future__ import annotations

import glob
import json
import pwd
import urllib.request
from typing import Any

import decky


def _api() -> tuple[str, str] | None:
    try:
        uid = pwd.getpwnam("steamos").pw_uid
    except KeyError:
        uid = 1000
    for f in [f"/run/user/{uid}/bottom-screen.api"] + glob.glob("/run/user/*/bottom-screen.api"):
        try:
            with open(f) as fh:
                c = json.load(fh)
            return c["url"], c["token"]
        except (OSError, ValueError, KeyError):
            continue
    return None


def call(method: str, path: str, body: dict | None = None) -> Any:
    api = _api()
    if not api:
        return None
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(api[0] + path, data=data, method=method,
                                 headers={"X-Token": api[1], "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return json.loads(r.read() or b"null")
    except (OSError, ValueError) as exc:
        decky.logger.warning(f"{method} {path}: {exc}")
        return None


class Plugin:
    async def _main(self) -> None:
        decky.logger.info("Lower Deck up")

    async def _unload(self) -> None:
        pass

    async def get_all(self, **_: Any) -> dict:
        st = call("GET", "/state") or {}
        if not st:
            return {"up": False}
        sk = call("GET", "/skins") or {}
        return {
            "up": True,
            "skin": (st.get("config") or {}).get("skin", "aura"),
            "skins": [{"id": s["id"], "title": s["title"]} for s in sk.get("skins", [])],
            "launcher": (call("GET", "/launcher") or {}).get("items", []),
            "companions": call("GET", "/companions") or {},
            "game": st.get("game") or {},
        }

    async def set_theme(self, skin: str = "aura", **_: Any) -> bool:
        return bool((call("POST", "/settings", {"skin": skin}) or {}).get("ok"))

    async def set_launcher(self, order: list | None = None, hidden: list | None = None, **_: Any) -> bool:
        return bool((call("POST", "/launcher", {"order": order or [], "hidden": hidden or []}) or {}).get("ok"))

    async def set_companions(self, appid: int = 0, apps: list | None = None, **_: Any) -> bool:
        return bool((call("POST", "/companions", {"appid": int(appid), "apps": apps or []}) or {}).get("ok"))

    async def set_companions_close(self, on: bool = True, **_: Any) -> bool:
        return bool((call("POST", "/companions", {"close": bool(on)}) or {}).get("ok"))
