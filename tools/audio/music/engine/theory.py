"""Music theory helpers: pitch names, chord symbols, scales and voice-led voicings.

Pitches are MIDI note numbers (C4 = 60, A4 = 69 = 440 Hz).  Chord symbols use the usual
lead-sheet spelling ("Dmaj7", "F#m7b5", "A7sus4", "G/B", "Bbadd9").  Voicing functions pick
concrete pitches for a chord while minimising movement from the previous voicing, which is
what makes pads / keys / guitar parts voice-lead smoothly instead of jumping around.
"""
from __future__ import annotations

import itertools
import re
from dataclasses import dataclass

PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
NAMES_SHARP = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
NAMES_FLAT = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

_NOTE_RE = re.compile(r"^([A-G])(##|#|bb|b)?(-?\d)$")


def note(name: str) -> int:
    """'F#4' -> 66.  Accepts ints unchanged."""
    if isinstance(name, (int, float)):
        return name
    m = _NOTE_RE.match(name.strip())
    if not m:
        raise ValueError(f"bad note name {name!r}")
    letter, acc, octv = m.groups()
    acc_val = {"#": 1, "##": 2, "b": -1, "bb": -2}.get(acc or "", 0)
    return 12 * (int(octv) + 1) + PC[letter] + acc_val


def notes(text: str) -> list[int]:
    return [note(t) for t in text.split()]


def hz(midi: float, a4: float = 440.0) -> float:
    return a4 * 2.0 ** ((midi - 69.0) / 12.0)


def name(midi: int, flats: bool = False) -> str:
    names = NAMES_FLAT if flats else NAMES_SHARP
    return f"{names[int(midi) % 12]}{int(midi) // 12 - 1}"


def pc_of(name_: str) -> int:
    m = re.match(r"^([A-G])(##|#|bb|b)?$", name_)
    if not m:
        raise ValueError(f"bad pitch class {name_!r}")
    letter, acc = m.groups()
    return (PC[letter] + {"#": 1, "##": 2, "b": -1, "bb": -2}.get(acc or "", 0)) % 12


# --------------------------------------------------------------------------- scales
MODES = {
    "major": (0, 2, 4, 5, 7, 9, 11),
    "ionian": (0, 2, 4, 5, 7, 9, 11),
    "dorian": (0, 2, 3, 5, 7, 9, 10),
    "phrygian": (0, 1, 3, 5, 7, 8, 10),
    "lydian": (0, 2, 4, 6, 7, 9, 11),
    "mixolydian": (0, 2, 4, 5, 7, 9, 10),
    "minor": (0, 2, 3, 5, 7, 8, 10),
    "aeolian": (0, 2, 3, 5, 7, 8, 10),
    "harmonic_minor": (0, 2, 3, 5, 7, 8, 11),
    "locrian": (0, 1, 3, 5, 6, 8, 10),
    "major_pent": (0, 2, 4, 7, 9),
    "minor_pent": (0, 3, 5, 7, 10),
}


def scale_pcs(tonic: str, mode: str = "major") -> list[int]:
    t = pc_of(tonic)
    return [(t + i) % 12 for i in MODES[mode]]


# --------------------------------------------------------------------------- chords
# intervals above the root; roles are inferred from the interval (see Chord.roles)
QUALITIES: dict[str, tuple[int, ...]] = {
    "": (0, 4, 7), "maj": (0, 4, 7), "M": (0, 4, 7),
    "m": (0, 3, 7), "min": (0, 3, 7), "-": (0, 3, 7),
    "dim": (0, 3, 6), "o": (0, 3, 6),
    "aug": (0, 4, 8), "+": (0, 4, 8),
    "5": (0, 7),
    "sus2": (0, 2, 7), "sus4": (0, 5, 7), "sus": (0, 5, 7),
    "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9),
    "69": (0, 4, 7, 9, 14), "m69": (0, 3, 7, 9, 14),
    "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11), "M7": (0, 4, 7, 11),
    "m7": (0, 3, 7, 10), "mmaj7": (0, 3, 7, 11), "mM7": (0, 3, 7, 11),
    "dim7": (0, 3, 6, 9), "o7": (0, 3, 6, 9),
    "m7b5": (0, 3, 6, 10), "ø": (0, 3, 6, 10),
    "7sus4": (0, 5, 7, 10), "7sus": (0, 5, 7, 10), "7sus2": (0, 2, 7, 10),
    "9sus4": (0, 5, 7, 10, 14), "9sus": (0, 5, 7, 10, 14),
    "add9": (0, 4, 7, 14), "add2": (0, 2, 4, 7), "madd9": (0, 3, 7, 14),
    "add11": (0, 4, 7, 17), "add4": (0, 4, 5, 7), "sus2add4": (0, 2, 5, 7),
    "9": (0, 4, 7, 10, 14), "maj9": (0, 4, 7, 11, 14), "m9": (0, 3, 7, 10, 14),
    "7b9": (0, 4, 7, 10, 13), "7#9": (0, 4, 7, 10, 15), "7#11": (0, 4, 7, 10, 18),
    "7b13": (0, 4, 7, 10, 20), "7#5": (0, 4, 8, 10), "aug7": (0, 4, 8, 10), "+7": (0, 4, 8, 10),
    "11": (0, 7, 10, 14, 17), "m11": (0, 3, 7, 10, 14, 17), "m7add11": (0, 3, 7, 10, 17),
    "13": (0, 4, 7, 10, 14, 21), "m13": (0, 3, 7, 10, 14, 21), "maj13": (0, 4, 7, 11, 14, 21),
    "7b9b13": (0, 4, 7, 10, 13, 20),
    "maj7#11": (0, 4, 7, 11, 18), "maj9#11": (0, 4, 7, 11, 14, 18),
    "maj7sus2": (0, 2, 7, 11), "m6add9": (0, 3, 7, 9, 14), "madd11": (0, 3, 7, 17),
    "mb6": (0, 3, 7, 8), "b5": (0, 4, 6), "sus4b9": (0, 5, 7, 13), "dimmaj7": (0, 3, 6, 11),
}

_CHORD_RE = re.compile(r"^([A-G](?:#|b)?)([^/]*)(?:/([A-G](?:#|b)?))?$")


@dataclass(frozen=True)
class Chord:
    symbol: str
    root: int            # pitch class
    ivals: tuple         # intervals above root (may exceed 12 for extensions)
    bass: int            # pitch class of the bass note (slash bass or root)

    @property
    def pcs(self) -> list[int]:
        out = []
        for i in self.ivals:
            pc = (self.root + i) % 12
            if pc not in out:
                out.append(pc)
        return out

    def roles(self) -> list[tuple[int, str]]:
        """(pitch class, role) with role in root/third/sus/fifth/seventh/sixth/ext."""
        out = []
        for i in self.ivals:
            s = i % 12
            if i == 0:
                r = "root"
            elif s in (3, 4) and i < 12:
                r = "third"
            elif s in (2, 5) and i < 12:
                r = "sus"
            elif s in (6, 7, 8) and i < 12:
                r = "fifth"
            elif s in (10, 11) or (s == 9 and "dim7" in self.symbol):
                r = "seventh"
            elif s == 9 and i < 12:
                r = "sixth"
            else:
                r = "ext"
            out.append(((self.root + i) % 12, r))
        return out

    @property
    def has_third(self) -> bool:
        return any(r == "third" for _, r in self.roles())

    def fifth_pc(self) -> int:
        for pc, r in self.roles():
            if r == "fifth":
                return pc
        return (self.root + 7) % 12

    def third_pc(self):
        for pc, r in self.roles():
            if r in ("third", "sus"):
                return pc
        return None

    def contains(self, pc: int) -> bool:
        return pc % 12 in self.pcs

    def __str__(self):
        return self.symbol


def chord(symbol: str) -> Chord:
    sym = symbol.strip()
    m = _CHORD_RE.match(sym)
    if not m:
        raise ValueError(f"bad chord symbol {symbol!r}")
    root_s, qual, bass_s = m.groups()
    qual = qual or ""
    if qual not in QUALITIES:
        raise ValueError(f"unknown chord quality {qual!r} in {symbol!r}")
    root = pc_of(root_s)
    bass = pc_of(bass_s) if bass_s else root
    return Chord(sym, root, QUALITIES[qual], bass)


# --------------------------------------------------------------------------- voicings
def _candidates(pc: int, lo: int, hi: int) -> list[int]:
    first = lo + ((pc - lo) % 12)
    return list(range(first, hi + 1, 12))


def _pc_plan(ch: Chord, n: int, rootless: bool, keep_fifth: bool) -> list[list[int]]:
    """A few alternative pitch-class multisets of size n, best first."""
    roles = ch.roles()
    by = {}
    for pc, r in roles:
        by.setdefault(r, [])
        if pc not in by[r]:
            by[r].append(pc)
    third = by.get("third", []) + by.get("sus", [])
    seventh = by.get("seventh", []) + by.get("sixth", [])
    ext = by.get("ext", [])
    root = by.get("root", [])
    fifth = by.get("fifth", [])
    altered_fifth = [p for p in fifth if (p - ch.root) % 12 != 7]
    prio = third + seventh + altered_fifth + ext
    if not rootless:
        prio = prio[:2] + root + prio[2:] if len(prio) >= 2 else prio + root
    if keep_fifth:
        prio += [p for p in fifth if p not in prio]
    rest = [p for p in (root + fifth) if p not in prio]
    if rootless:
        rest = [p for p in fifth if p not in prio] + [p for p in root if p not in prio]
    order = []
    for p in prio + rest:
        if p not in order:
            order.append(p)
    plans = []
    if len(order) >= n:
        plans.append(order[:n])
        # alternative: swap the last chosen with the next candidate
        if len(order) > n:
            plans.append(order[: n - 1] + [order[n]])
    else:
        base = list(order)
        doubles = [p for p in (root + fifth + third) if p in base] or base
        i = 0
        while len(base) < n:
            base.append(doubles[i % len(doubles)])
            i += 1
        plans.append(base)
        if len(doubles) > 1:
            alt = list(order)
            i = 1
            while len(alt) < n:
                alt.append(doubles[i % len(doubles)])
                i += 1
            plans.append(alt)
    return plans


def voice(ch: Chord, n: int = 4, lo: int = 55, hi: int = 79, prev: list[int] | None = None,
          rootless: bool = False, keep_fifth: bool = True, top_max: int | None = None,
          top_min: int | None = None, center: float | None = None, max_gap: int = 9,
          bonus: dict | None = None, avoid: list[int] | None = None,
          spread_w: float = 0.08) -> list[int]:
    """Choose n concrete pitches for `ch` within [lo, hi], voice-led from `prev`.

    * `top_max` keeps the top voice below a melody note.
    * `bonus` maps midi pitch -> cost bonus (e.g. open guitar strings).
    * `avoid` lists midi pitches that must not be a semitone away from any voice
      (used to keep accompaniment from rubbing against a sustained melody note).
    """
    if center is None:
        center = (lo + hi) / 2.0
    best, best_cost = None, 1e18
    for plan_i, plan in enumerate(_pc_plan(ch, n, rootless, keep_fifth)):
        cands = [_candidates(pc, lo, hi) for pc in plan]
        if any(not c for c in cands):
            continue
        for combo in itertools.product(*cands):
            v = sorted(combo)
            if len(set(v)) < n:
                continue
            if top_max is not None and v[-1] > top_max:
                continue
            if top_min is not None and v[-1] < top_min:
                continue
            gaps = [b - a for a, b in zip(v, v[1:])]
            if gaps and max(gaps) > max_gap:
                continue
            cost = 0.6 * plan_i
            # low-register clusters sound muddy
            for a, b in zip(v, v[1:]):
                if b - a <= 2 and a < 60:
                    cost += 6.0
                elif b - a == 1:
                    cost += 1.5
            if prev:
                pv = sorted(prev)
                if len(pv) == n:
                    cost += sum(abs(a - b) for a, b in zip(v, pv))
                else:
                    cost += sum(min(abs(a - b) for b in pv) for a in v)
                    cost += sum(min(abs(a - b) for a in v) for b in pv) * 0.5
                cost += 0.35 * abs(v[-1] - pv[-1])
            cost += 0.25 * abs(sum(v) / n - center) + spread_w * (v[-1] - v[0])
            if bonus:
                cost -= sum(bonus.get(x, 0.0) for x in v)
            if avoid:
                for a in avoid:
                    for x in v:
                        if abs(((x - a) % 12)) in (1, 11) and abs(x - a) < 14:
                            cost += 8.0
            if cost < best_cost:
                best, best_cost = v, cost
    if best is None:
        # fall back: widen the range
        return voice(ch, n, lo - 5, hi + 5, prev, rootless, keep_fifth, None, None, center, 12, bonus,
                     None, spread_w)
    return best


def bass_note(ch: Chord, lo: int = 36, hi: int = 52, prev: int | None = None,
              center: float = 43.0) -> int:
    c = _candidates(ch.bass, lo, hi)
    if not c:
        c = _candidates(ch.bass, lo - 6, hi + 6)
    ref = prev if prev is not None else center
    return min(c, key=lambda x: (abs(x - ref) + 0.3 * abs(x - center), x))


def fifth_below_or_above(ch: Chord, bass: int, lo: int = 38, hi: int = 52) -> int:
    """Alternating-bass partner: the chord's fifth (or the root if the bass is a slash note)."""
    target_pc = ch.fifth_pc() if ch.bass == ch.root else ch.root
    c = [x for x in _candidates(target_pc, lo, hi) if x != bass]
    if not c:
        c = _candidates(target_pc, lo - 7, hi + 7)
    above = [x for x in c if bass < x <= bass + 9]
    if above:
        return above[0]
    return min(c, key=lambda x: abs(x - bass))


OPEN_STRINGS = {40: 1.2, 45: 1.2, 50: 1.0, 55: 1.0, 59: 0.8, 64: 0.8}


def guitar_voicing(ch: Chord, prev: list[int] | None = None, n_upper: int = 3,
                   lo: int = 52, hi: int = 74, bass_lo: int = 40, bass_hi: int = 52,
                   prev_bass: int | None = None, top_max: int | None = None) -> list[int]:
    """[bass, upper...] approximating an open-position guitar chord shape."""
    b = bass_note(ch, bass_lo, bass_hi, prev_bass, center=46)
    up_prev = prev[1:] if prev else None
    upper = voice(ch, n_upper, max(lo, b + 5), hi, up_prev, rootless=False, keep_fifth=True,
                  top_max=top_max, center=(lo + hi) / 2 - 2, max_gap=8, bonus=OPEN_STRINGS)
    return [b] + upper


def nearest(pc: int, ref: float, lo: int = 0, hi: int = 127) -> int:
    c = _candidates(pc, lo, hi)
    return min(c, key=lambda x: abs(x - ref))


def transpose_text(text: str, semis: int) -> str:
    """Transpose every note name inside a notation string (keeps durations/modifiers)."""
    def rep(m):
        n = note(m.group(0)) + semis
        return name(n, flats=("b" in m.group(0)))
    return re.sub(r"(?<![A-Za-z])[A-G](?:##|#|bb|b)?-?\d(?![\d])", rep, text)
