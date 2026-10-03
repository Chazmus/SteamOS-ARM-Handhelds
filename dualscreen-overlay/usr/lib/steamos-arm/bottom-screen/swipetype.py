"""Swipe typing: turn a finger trace over the letter keys into words.

Every dictionary word has a skeleton, the straight line from key to key
through its letters. A trace is matched against the skeletons of plausible
words with dynamic time warping, so a finger that slows down on one part of
the word and rushes another still lines up. Three things decide the order:

  distance     how far, in key widths, the warped trace stays from the skeleton
  bends        the trace's sharp turns against the word's own: a word whose
               skeleton runs straight through a key (t-r-e in "stream") has
               no bend there, a trace that turns there wants one
  familiarity  how common the word is (SCOWL level) and how often this user
               picked it before (learned words, ~/.local/share/steamos-arm)

Only words whose first and last letters lie near the trace's ends, and whose
letters the trace came close to, are scored at all, which keeps it to a few
hundred skeletons per trace.
"""
from __future__ import annotations

import json
import math
import os
import threading
from pathlib import Path

WORDS = Path("/usr/share/steamos-arm/bottom-screen/words.txt")
LEARNED = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "steamos-arm" / "swipe-words.json"
SAMPLES = 28            # points a trace and a skeleton are resampled to
BAND = 6                # DTW warping window, in samples

_lock = threading.Lock()
_by_ends: dict[tuple[str, str], list[tuple[str, int]]] | None = None
_learned: dict[str, int] | None = None


def _dictionary() -> dict[tuple[str, str], list[tuple[str, int]]]:
    global _by_ends
    if _by_ends is None:
        table: dict[tuple[str, str], list[tuple[str, int]]] = {}
        try:
            for line in WORDS.read_text().splitlines():
                word, _, level = line.partition(" ")
                if len(word) >= 2:
                    table.setdefault((word[0], word[-1]), []).append((word, int(level or 50)))
        except OSError:
            pass
        _by_ends = table
    return _by_ends


def _known() -> dict[str, int]:
    global _learned
    if _learned is None:
        try:
            _learned = {str(k): int(v) for k, v in json.loads(LEARNED.read_text()).items()}
        except (OSError, ValueError, AttributeError):
            _learned = {}
    return _learned


def learn(word: str) -> None:
    """The user kept this word (typed it, swiped it, picked a suggestion)."""
    word = word.strip().lower()
    if not (2 <= len(word) <= 20 and word.isalpha()):
        return
    with _lock:
        known = _known()
        known[word] = min(known.get(word, 0) + 1, 1000)
        # Keep the file small: the 3000 most used.
        if len(known) > 3000:
            for w, _ in sorted(known.items(), key=lambda kv: kv[1])[:len(known) - 3000]:
                del known[w]
        try:
            LEARNED.parent.mkdir(parents=True, exist_ok=True)
            tmp = LEARNED.with_suffix(".tmp")
            tmp.write_text(json.dumps(known))
            os.replace(tmp, LEARNED)
        except OSError:
            pass
        # A learned word that isn't in the dictionary still has to be found.
        table = _dictionary()
        bucket = table.setdefault((word[0], word[-1]), [])
        if all(w != word for w, _ in bucket):
            bucket.append((word, 35))


def _even(points: list[tuple[float, float]], n: int = SAMPLES) -> list[tuple[float, float]]:
    """n points spread evenly along the polyline."""
    if len(points) < 2:
        return list(points) * n if points else []
    lengths = [math.dist(a, b) for a, b in zip(points, points[1:])]
    total = sum(lengths)
    if total == 0:
        return [points[0]] * n
    out = []
    seg, into = 0, 0.0
    for i in range(n):
        want = total * i / (n - 1)
        while seg < len(lengths) - 1 and into + lengths[seg] < want:
            into += lengths[seg]
            seg += 1
        a, b = points[seg], points[seg + 1]
        t = (want - into) / lengths[seg] if lengths[seg] else 0.0
        t = max(0.0, min(1.0, t))
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def _warped(a: list[tuple[float, float]], b: list[tuple[float, float]]) -> float:
    """Mean point distance along the best alignment within the band (DTW)."""
    n, m = len(a), len(b)
    inf = float("inf")
    prev = [inf] * (m + 1)
    prev[0] = 0.0
    for i in range(1, n + 1):
        cur = [inf] * (m + 1)
        lo, hi = max(1, i - BAND), min(m, i + BAND)
        for j in range(lo, hi + 1):
            d = math.dist(a[i - 1], b[j - 1])
            cur[j] = d + min(prev[j], prev[j - 1], cur[j - 1])
        prev = cur
    return prev[m] / max(n, m)


def _bends(points: list[tuple[float, float]], threshold: float = 0.9) -> list[tuple[float, float]]:
    """Where the line turns sharply (radians between successive headings)."""
    out = []
    for p, q, r in zip(points, points[1:], points[2:]):
        h1 = math.atan2(q[1] - p[1], q[0] - p[0])
        h2 = math.atan2(r[1] - q[1], r[0] - q[0])
        turn = abs((h2 - h1 + math.pi) % (2 * math.pi) - math.pi)
        if turn > threshold:
            out.append(q)
    return out


def words(keys: dict[str, list[float]], key_width: float, trace: list[list[float]],
          count: int = 4) -> list[str]:
    """The likeliest words for a trace, best first."""
    keys = {c.lower(): (float(xy[0]), float(xy[1])) for c, xy in keys.items()
            if len(c) == 1 and c.isalpha() and len(xy) == 2}
    pts = [(float(p[0]), float(p[1])) for p in trace if len(p) == 2]
    if len(pts) < 2 or not keys or key_width <= 0:
        return []
    w = float(key_width)
    unit = lambda d: d / w  # noqa: E731

    def keys_near(p, reach):
        hits = [c for c, xy in keys.items() if unit(math.dist(p, xy)) <= reach]
        return hits or [min(keys, key=lambda c: math.dist(p, keys[c]))]

    starts, ends = keys_near(pts[0], 1.1), keys_near(pts[-1], 1.3)
    trace_even = _even(pts)
    fine = _even(pts, 90)
    closest = {c: min(unit(math.dist(p, xy)) for p in fine) for c, xy in keys.items()}
    # The trace's turns, smoothed over a few samples so jitter isn't a bend.
    smooth = _even(pts, 16)
    trace_bends = _bends(smooth)
    known = _known()
    table = _dictionary()

    ranked = []
    for s in starts:
        for e in ends:
            for word, level in table.get((s, e), ()):
                if any(closest.get(c, 9.0) > 0.9 for c in word):
                    continue
                skeleton = [keys[c] for i, c in enumerate(word)
                            if c in keys and (i == 0 or c != word[i - 1])]
                if len(skeleton) < 2:
                    continue
                distance = unit(_warped(trace_even, _even(skeleton)))
                word_bends = _bends(skeleton, 0.5)
                # Each bend of the trace should sit on one of the word's, and
                # the other way round; unmatched ones cost.
                miss = sum(1 for b in trace_bends
                           if not any(unit(math.dist(b, k)) < 0.8 for k in word_bends))
                miss += sum(1 for k in word_bends
                            if not any(unit(math.dist(b, k)) < 0.8 for b in trace_bends))
                familiarity = (level - 10) / 40 * 0.35 - min(0.5, 0.12 * math.log1p(known.get(word, 0)))
                ranked.append((distance + 0.18 * miss + familiarity, word))
    ranked.sort()
    out: list[str] = []
    for _, word in ranked:
        if word not in out:
            out.append(word)
        if len(out) >= count:
            break
    return out
