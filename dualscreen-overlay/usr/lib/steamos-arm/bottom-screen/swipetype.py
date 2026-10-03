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


def learn(word: str, sure: bool = False) -> None:
    """The user kept this word (typed it, swiped it, picked a suggestion).
    sure: they put it back after autocorrect, so it counts as known at once."""
    word = word.strip().lower()
    if not (2 <= len(word) <= 20 and word.isalpha()):
        return
    with _lock:
        known = _known()
        known[word] = min(known.get(word, 0) + (2 if sure else 1), 1000)
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


# ------------------------------------------------------------ tap typing --
#
# The same dictionary also backs the tapped keys: fixing a word as it is
# finished and offering endings while it is typed.
#
# A typo costs less the closer the wrong key sits to the right one on the
# layout in use: hitting "r" for "e" is cheap, "p" for "e" is not. Swapped
# neighbours ("teh") and a doubled or missing letter are cheap too. The
# cheapest word wins once its commonness is weighed in, and only when the
# typed word is unknown and the fix is clearly a typo.

ROWS = {
    "qwerty": ("qwertyuiop", "asdfghjkl", "zxcvbnm"),
    "qwertz": ("qwertzuiop", "asdfghjkl", "yxcvbnm"),
    "azerty": ("azertyuiop", "qsdfghjklm", "wxcvbn"),
}
_ROW_SHIFT = (0.0, 0.5, 1.0)

_flat: list[tuple[str, int]] | None = None

# Apostrophes nobody types on a touch keyboard, and a lone i.
SHORTHAND = {
    "i": "I", "im": "I'm", "ive": "I've", "ill": None, "id": None,
    "dont": "don't", "cant": "can't", "wont": "won't", "didnt": "didn't",
    "doesnt": "doesn't", "isnt": "isn't", "wasnt": "wasn't", "arent": "aren't",
    "couldnt": "couldn't", "shouldnt": "shouldn't", "wouldnt": "wouldn't",
    "youre": "you're", "theyre": "they're", "thats": "that's", "whats": "what's",
    "hes": None, "shes": "she's", "theres": "there's", "lets": None,
}


def _all_words() -> list[tuple[str, int]]:
    """Every word, the most common first."""
    global _flat
    if _flat is None:
        _flat = sorted((wl for bucket in _dictionary().values() for wl in bucket), key=lambda wl: wl[1])
    return _flat


def _spots(layout: str) -> dict[str, tuple[float, float]]:
    rows = ROWS.get(layout, ROWS["qwerty"])
    return {c: (x + _ROW_SHIFT[y], float(y)) for y, row in enumerate(rows) for x, c in enumerate(row)}


def _slip(a: str, b: str, spots) -> float:
    """What typing a where b was meant costs."""
    if a == b:
        return 0.0
    pa, pb = spots.get(a), spots.get(b)
    if pa and pb and math.dist(pa, pb) <= 1.2:
        return 0.45
    return 1.0


def _typo_cost(typed: str, word: str, spots, cap: float) -> float:
    """Keyboard-aware edit distance; gives up past cap."""
    n, m = len(typed), len(word)
    far = cap + 1
    rows = [[0.0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        rows[i][0] = i * 0.8
    for j in range(m + 1):
        rows[0][j] = j * 0.8
    for i in range(1, n + 1):
        best = far
        for j in range(1, m + 1):
            c = min(rows[i - 1][j] + (0.5 if i > 1 and typed[i - 1] == typed[i - 2] else 0.8),  # extra letter
                    rows[i][j - 1] + (0.4 if j > 1 and word[j - 1] == word[j - 2] else 0.8),  # missing letter
                    rows[i - 1][j - 1] + _slip(typed[i - 1], word[j - 1], spots))
            if i > 1 and j > 1 and typed[i - 1] == word[j - 2] and typed[i - 2] == word[j - 1]:
                c = min(c, rows[i - 2][j - 2] + 0.35)                                         # swapped pair
            rows[i][j] = c
            best = min(best, c)
        # A swap only pays off a row later, so allow for one in flight.
        if best > cap + 0.8:
            return far
    return rows[n][m]


def _rank(level: int, word: str) -> float:
    """Lower for common words and ones this user types."""
    return (level - 10) / 40 * 0.4 - min(0.45, 0.1 * math.log1p(_known().get(word, 0)))


def known(word: str) -> bool:
    w = word.lower()
    # A word of the user's own counts once it was kept twice (or put back).
    return _known().get(w, 0) >= 2 or any(x == w for x, _ in _dictionary().get((w[:1], w[-1:]), ()))


def fix(word: str, layout: str = "qwerty", sentence_start: bool = False) -> str | None:
    """The word meant, when `word` is a clear typo; None to leave it.
    A capital mid-sentence is taken for a name and left alone."""
    if not (1 <= len(word) <= 20) or not word.isalpha() or (word.isupper() and len(word) > 1):
        return None
    if word[0].isupper() and not sentence_start:
        return None
    low = word.lower()
    if low in SHORTHAND:
        mended = SHORTHAND[low]
        if mended and word[0].isupper() and mended[0].islower():
            mended = mended[0].upper() + mended[1:]
        return mended
    if len(low) < 3 or known(low):
        return None
    letters = set(low)
    spots = _spots(layout)
    # Short words only get swapped letters fixed: "lol" and "gg" stay.
    cap = 0.35 if len(low) <= 3 else (0.5 if len(low) == 4 else (1.0 if len(low) <= 6 else 1.6))
    # The first letter is usually right, or a neighbour, or swapped with the second.
    reach = {c for c, p in spots.items() if low[0] in spots and math.dist(p, spots[low[0]]) <= 1.2} | {low[0], low[1]}
    best, best_score = None, float("inf")
    for cand, level in _all_words():
        if cand[0] not in reach or abs(len(cand) - len(low)) > (1 if len(low) <= 6 else 2):
            continue
        if len(letters.symmetric_difference(cand)) > 3:
            continue
        cost = _typo_cost(low, cand, spots, cap)
        if cost > cap:
            continue
        score = cost + _rank(level, cand)
        if score < best_score:
            best, best_score = cand, score
    if best is None:
        return None
    if word[0].isupper():
        best = best[0].upper() + best[1:]
    return best


def complete(prefix: str, count: int = 3) -> list[str]:
    """Words that start with prefix, the likeliest first (the user's own lead)."""
    low = prefix.lower()
    if len(low) < 2 or not low.isalpha():
        return []
    # Shorter endings first among equals: fewer letters left to guess.
    hits = [(_rank(level, w) + 0.04 * len(w), w) for w, level in _all_words() if len(w) > len(low) and w.startswith(low)]
    hits += [(_rank(35, w) + 0.04 * len(w), w) for w in _known() if len(w) > len(low) and w.startswith(low)]
    out: list[str] = []
    for _, w in sorted(hits):
        if w not in out:
            out.append(w)
        if len(out) >= count:
            break
    if prefix[0].isupper():
        out = [w[0].upper() + w[1:] for w in out]
    return out
