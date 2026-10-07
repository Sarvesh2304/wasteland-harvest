"""Sad - "What They Left Us".  Emotional story moments (remembering the player's parents).

B minor (relative minor of the leitmotif's D major), 60 BPM, 4/4, 20 bars (80 s), loop.

A soft felt piano carries a new, plain theme over a low string line; then a distant
harmonica plays the leitmotif note-for-note while the harmony underneath turns it minor
(Bm, Em7, Gmaj7, F#7, the Neapolitan-coloured Cmaj7) so the town's theme ends on the third
of B minor instead of home - bittersweet, not tragic: they had the ending few got.

Form
  intro  2  piano alone                Bmadd9 | Gmaj7
  A      8  piano theme                Bm | G | D/F# | Em7 | Bm/D | Cmaj7 | Em7 | F#sus4 F#
  B      8  leitmotif in minor         Bm | Em7 | Gmaj7 | F#7sus4 F#7 | Bm/A | Em9 Cmaj7 | Gmaj7 F#7 | Bm
  coda   2                             Gmaj7 | F#sus4
"""
from engine import P, Pad, Piano, Reed, Song

from .common import lint, std_buses
from .leitmotif import LEITMOTIF

THEME = """
F#5:2. E5:8 D5:8 | D5:4 B4:4 G4:2 | A4:4. B4:8 C#5:4 D5:4 | E5:2. r:4 |
F#5:4. G5:8 F#5:4 E5:4 | E5:2 B4:2 | G4:4 B4:4 E5:4 D5:4 | C#5:2 A#4:2 |
"""
INTRO = "D5:2 C#5:2 | B4:1 |"
CODA = "B4:2 A4:2 | C#5:1 |"
ECHO_B = "r:1 | r:2 B4:4 A4:4 | r:1 | r:2 A#4:2 | r:1 | r:2 E5:4 D5:4 | r:1 | F#4:1 |"


def build():
    s = Song("sad", bpm=60, key="B", seed=121, target_lufs=-16.0)
    s.meta["mood"] = "tender, bittersweet"
    s.meta.update(title="What They Left Us", key="B minor", use="Emotional story scenes (the parents, memories)")
    s.section("intro", 2, "Bmadd9 | Gmaj7")
    s.section("A", 8, "Bm | G | D/F# | Em7 | Bm/D | Cmaj7 | Em7 | F#sus4 F#")
    s.section("B", 8, "Bm | Em7 | Gmaj7 | F#7sus4 F#7 | Bm/A | Em9 Cmaj7 | Gmaj7 F#7 | Bm")
    s.section("coda", 2, "Gmaj7 | F#sus4")
    std_buses(s, hall="night", echo_beats=None)

    pr = s.part("piano", Piano(felt=1.1), level=0.0, pan=0.05, ref=True, sends={"hall": -7}, human_ms=14)
    pr.melody(INTRO, "intro", vel=0.55)
    pr.melody(THEME, "A", vel=0.6)
    pr.melody(ECHO_B, "B", vel=0.45)
    pr.melody(CODA, "coda", vel=0.5)
    pr.dyn(("A", 4), 1.0).dyn(("A", 5), 1.08).dyn(("A", 7), 0.95)

    lh = s.part("piano_lh", Piano(felt=1.2), level=-5.0, pan=-0.05, sends={"hall": -7}, human_ms=12)
    P.fingerpick(lh, ["intro", "A", "B", "coda"], "B 1 2 3 2 1 2 1", vel=0.42, n_upper=3,
                 lo=50, hi=66, bass_lo=35, bass_hi=47, ring_over=0.6)
    lh.gain("B", -1.5)

    harp = s.part("harmonica", Reed("harmonica", vib_cents=9.0, breath=0.05), level=-1.0, pan=-0.15,
                  sends={"hall": -3}, human_ms=16, fx=[("eq", [("lp", 5000)])])
    harp.melody(LEITMOTIF, "B", vel=0.62)
    lint(pr, harp)

    strings = s.part("strings", Pad("strings", attack=1.4, release=2.2), level=-9.0, width=1.3,
                     sends={"hall": -4}, human_ms=0)
    P.pad(strings, ["A", "B", "coda"], n=3, lo=59, hi=74, vel=0.55)
    strings.gain("A", -4).gain(("A", 4), -1).gain("B", -2).gain(("B", 5), 0).gain("coda", -3)

    cello = s.part("cello", Pad("strings", attack=0.9, release=1.6, lp_scale=0.6, voices=3),
                   level=-8.0, sends={"hall": -8}, human_ms=0)
    P.bassline(cello, ["A", "B", "coda"], "1 - 1 -", vel=0.6, lo=35, hi=52, gate=0.98)
    return s
