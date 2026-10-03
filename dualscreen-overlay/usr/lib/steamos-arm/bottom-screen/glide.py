"""Glide typing for the bottom screen's keyboards.

A glide is the finger's path over the letter keys. Each candidate word has an
ideal path, key centre to key centre through its letters; a word scores by
how far the glide runs from that path (where the finger went), how unlike
the two are once both are normalised (what the stroke looked like), and how
common the word is (its SCOWL level, 10 = most common).

Candidates: words whose first letter is near where the finger went down,
whose last letter is near where it lifted, and every one of whose letters the
glide passed close to. That leaves a few hundred words to score.

Coordinates are the keyboard's own; key_size is a key's width in them.
"""
from __future__ import annotations

import math
from pathlib import Path

WORDS = Path("/usr/share/steamos-arm/bottom-screen/words.txt")
N = 32                      # points both paths are resampled to

_index: dict[tuple[str, str], list[tuple[str, int]]] | None = None


def _load() -> dict[tuple[str, str], list[tuple[str, int]]]:
    global _index
    if _index is None:
        _index = {}
        try:
            for line in WORDS.read_text().splitlines():
                w, _, lvl = line.partition(" ")
                if len(w) >= 2:
                    _index.setdefault((w[0], w[-1]), []).append((w, int(lvl or 50)))
        except OSError:
            pass
    return _index


def _resample(pts: list[tuple[float, float]], n: int = N) -> list[tuple[float, float]]:
    if len(pts) == 1:
        return pts * n
    seg = [math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    total = sum(seg)
    if total == 0:
        return [pts[0]] * n
    out, step, acc, i = [pts[0]], total / (n - 1), 0.0, 0
    target = step
    while len(out) < n - 1 and i < len(seg):
        if acc + seg[i] >= target:
            t = (target - acc) / seg[i] if seg[i] else 0
            a, b = pts[i], pts[i + 1]
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            target += step
        else:
            acc += seg[i]
            i += 1
    while len(out) < n:
        out.append(pts[-1])
    return out


def _normalise(pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    span = max(max(abs(p[0] - cx) for p in pts), max(abs(p[1] - cy) for p in pts)) or 1.0
    return [((p[0] - cx) / span, (p[1] - cy) / span) for p in pts]


def _mean_dist(a, b) -> float:
    return sum(math.dist(p, q) for p, q in zip(a, b)) / len(a)


def decode(keys: dict[str, list[float]], key_size: float, path: list[list[float]],
           limit: int = 4) -> list[str]:
    index = _load()
    keys = {k.lower(): (float(v[0]), float(v[1])) for k, v in keys.items()
            if len(k) == 1 and k.isalpha() and len(v) == 2}
    pts = [(float(p[0]), float(p[1])) for p in path if len(p) == 2]
    if len(pts) < 2 or not keys or key_size <= 0:
        return []
    k = float(key_size)

    def near(p, radius):
        return [c for c, xy in keys.items() if math.dist(p, xy) <= radius * k]

    firsts = near(pts[0], 1.1) or [min(keys, key=lambda c: math.dist(pts[0], keys[c]))]
    lasts = near(pts[-1], 1.3) or [min(keys, key=lambda c: math.dist(pts[-1], keys[c]))]
    glide = _resample(pts)
    shape = _normalise(glide)
    # Closest the glide came to each key: a word needs all of its letters.
    dense = _resample(pts, 96)
    reach = {c: min(math.dist(p, xy) for p in dense) / k for c, xy in keys.items()}

    scored = []
    for f in firsts:
        for l in lasts:
            for word, lvl in index.get((f, l), ()):
                if any(reach.get(c, 9) > 0.9 for c in word):
                    continue
                ideal = [keys[c] for i, c in enumerate(word) if c in keys and (i == 0 or c != word[i - 1])]
                if len(ideal) != len(set(word)) and len(ideal) < 2 and len(word) > 2:
                    continue
                ip = _resample(ideal)
                where = _mean_dist(glide, ip) / k
                looks = _mean_dist(shape, _normalise(ip))
                rarity = (lvl - 10) / 40 * 0.35
                scored.append((where + 0.8 * looks + rarity, word))
    scored.sort()
    out: list[str] = []
    for _, w in scored:
        if w not in out:
            out.append(w)
        if len(out) >= limit:
            break
    return out
