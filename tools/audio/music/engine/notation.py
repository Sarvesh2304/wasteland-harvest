"""Compact, readable text notation for the scores.

Melody notation (LilyPond-ish, absolute pitches, sticky durations)::

    "A4:8 D5 F#5:4. E5:8 D5:4 | G5:4. F#5:8 E5:2 |"

* pitch: ``C4``, ``F#5``, ``Bb3``; rest ``r``; double-stop ``D5+F#5``
* duration suffix ``:1 :2 :4 :8 :16 :32`` (+ ``.``/``..`` dots, + ``t`` triplet); the duration
  is sticky until changed.  Default is a quarter note.
* modifiers after the duration: ``>`` accent, ``!`` strong accent, ``?`` soft,
  ``*`` staccato, ``~`` tie to the next note, ``^`` scoop/bend into the note,
  ``/`` slide (glide) from the previous note, ``_`` slur (no re-articulation),
  ``=`` tenuto (full length).
* ``|`` is a bar line and is *checked*: a bar of the wrong length raises an error.
* ``;`` starts a comment (to the end of the line).

Drum grid notation::

    "X..x ..x. x..x .x.."   (one char per step; X=1.0 x=0.75 o=0.5 g=0.3 .=rest)

Chord charts::

    "D | G | Bm | Asus4 A | D/F# | G Gm | Em7 A7 | D"

Chords inside a bar share the bar equally; ``.`` extends the previous chord by one slot
(``"G . . D"`` = G for three beats then D), ``%`` repeats the previous bar.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

from .theory import chord as parse_chord, note as parse_note

DUR = {"1": 4.0, "2": 2.0, "4": 1.0, "8": 0.5, "16": 0.25, "32": 0.125}
_TOK = re.compile(
    r"^(?P<pitch>r|[A-G](?:##|#|bb|b)?-?\d(?:\+[A-G](?:##|#|bb|b)?-?\d)*)"
    r"(?::(?P<dur>1|2|4|8|16|32)(?P<dots>\.{0,2})(?P<tup>t)?)?"
    r"(?P<mods>[>!?*~^/_=]*)$")


@dataclass
class Note:
    t: float                 # start, beats (relative)
    d: float                 # duration, beats
    p: list                  # midi pitches (empty for rest)
    acc: float = 0.0         # velocity offset
    flags: set = field(default_factory=set)


def _strip_comments(text: str) -> str:
    """Comments run from ';' to the end of the line ('#' is a sharp sign)."""
    return "\n".join(line.split(";", 1)[0] for line in text.splitlines())


def parse_melody(text: str, beats_per_bar: float = 4.0, start_offset: float = 0.0,
                 check_bars: bool = True, where: str = "") -> list[Note]:
    """Parse melody notation into Note objects (rests are dropped, ties merged).

    ``start_offset`` lets a phrase begin mid-bar (pickup): bar checks are made relative
    to the bar grid, i.e. the first bar line must arrive at the end of the bar in which
    the phrase started.
    """
    toks = _strip_comments(text).split()
    out: list[Note] = []
    pos = start_offset
    dur = 1.0
    tie_open: Note | None = None
    bar_no = 0
    for ti, tok in enumerate(toks):
        if tok in ("|", "||", "|:", ":|"):
            bar_no += 1
            if check_bars:
                rem = pos % beats_per_bar
                if abs(rem) > 1e-6 and abs(rem - beats_per_bar) > 1e-6:
                    raise ValueError(
                        f"{where}: bar {bar_no} has wrong length (position {pos:.3f} beats is "
                        f"{rem:.3f} into a {beats_per_bar}-beat bar) near token #{ti}: "
                        f"{' '.join(toks[max(0, ti - 8):ti])}")
            continue
        m = _TOK.match(tok)
        if not m:
            raise ValueError(f"{where}: bad melody token {tok!r}")
        if m.group("dur"):
            dur = DUR[m.group("dur")]
            dots = len(m.group("dots") or "")
            if dots == 1:
                dur *= 1.5
            elif dots == 2:
                dur *= 1.75
            if m.group("tup"):
                dur *= 2.0 / 3.0
        mods = m.group("mods") or ""
        pitch = m.group("pitch")
        if pitch == "r":
            tie_open = None
            pos += dur
            continue
        ps = [parse_note(x) for x in pitch.split("+")]
        acc = 0.0
        if ">" in mods:
            acc += 0.12
        if "!" in mods:
            acc += 0.22
        if "?" in mods:
            acc -= 0.15
        flags = set()
        for ch, fl in (("*", "stacc"), ("^", "scoop"), ("/", "slide"), ("_", "slur"), ("=", "ten")):
            if ch in mods:
                flags.add(fl)
        if tie_open is not None and tie_open.p == ps:
            tie_open.d += dur
            if "~" not in mods:
                tie_open = None
        else:
            n = Note(pos, dur, ps, acc, flags)
            out.append(n)
            tie_open = n if "~" in mods else None
        pos += dur
    return out


def melody_length(text: str) -> float:
    toks = _strip_comments(text).split()
    pos, dur = 0.0, 1.0
    for tok in toks:
        if tok.startswith("|") or tok.endswith("|"):
            continue
        m = _TOK.match(tok)
        if not m:
            raise ValueError(f"bad melody token {tok!r}")
        if m.group("dur"):
            dur = DUR[m.group("dur")]
            dots = len(m.group("dots") or "")
            dur *= (1.0, 1.5, 1.75)[dots]
            if m.group("tup"):
                dur *= 2.0 / 3.0
        pos += dur
    return pos


GRID_VEL = {"X": 1.0, "x": 0.75, "o": 0.5, "g": 0.3, "G": 0.4}


def parse_grid(text: str, steps_per_beat: int = 4) -> list[tuple[float, float]]:
    """Drum grid -> [(beat_offset, velocity)]."""
    chars = [c for c in _strip_comments(text) if not c.isspace() and c != "|"]
    out = []
    for i, c in enumerate(chars):
        if c in GRID_VEL:
            out.append((i / steps_per_beat, GRID_VEL[c]))
        elif c not in ".-_":
            raise ValueError(f"bad grid char {c!r} in {text!r}")
    return out


def grid_len(text: str, steps_per_beat: int = 4) -> float:
    chars = [c for c in _strip_comments(text) if not c.isspace() and c != "|"]
    return len(chars) / steps_per_beat


def parse_chart(text: str, beats_per_bar: float = 4.0) -> list[list[tuple[float, float, object]]]:
    """Chord chart -> list of bars, each a list of (offset_in_bar, duration, Chord)."""
    bars_txt = [b.strip() for b in _strip_comments(text).replace("\n", " ").split("|")]
    bars_txt = [b for b in bars_txt if b]
    bars = []
    prev_bar = None
    last_chord = None
    for btxt in bars_txt:
        if btxt == "%":
            if prev_bar is None:
                raise ValueError("'%' with no previous bar")
            bars.append(list(prev_bar))
            continue
        toks = btxt.split()
        slot = beats_per_bar / len(toks)
        items = []
        for i, t in enumerate(toks):
            if t == ".":
                if items:
                    o, d, c = items[-1]
                    items[-1] = (o, d + slot, c)
                else:
                    if last_chord is None:
                        raise ValueError("'.' at start of chart")
                    items.append((0.0, slot, last_chord))
                continue
            c = parse_chord(t)
            items.append((i * slot, slot, c))
            last_chord = c
        bars.append(items)
        prev_bar = items
    return bars
