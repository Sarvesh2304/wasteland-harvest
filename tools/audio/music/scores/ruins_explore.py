"""Ruins (explore) - "Dead City".  Tense ambient exploration.

D minor / D phrygian over a D pedal, 60 BPM, 4/4, 30 bars (120 s), loop.

A low detuned drone (D + A) with a slowly breathing filter, dark pad chords that drift to
phrygian bII (Eb/D), a tritone-shadowed Ab/D and Bbm/D; breathy pitched wind in the pipes;
distant metal hits in a long cave reverb; sparse plucks doubled by a slightly flat second
string so every note sours; and, in the quiet C section, the leitmotif's opening gesture in
phrygian minor on a detuned music box - home, remembered wrong.

Form
  A  8  drone, wind, sparse plucks, distant metal      Dm | Dm | Eb/D | Dm | Dm | Bb/D | Eb/D | Dm
  B  8  tension: dissonant pad, scrapes, sub pulse      Gm/D | Eb/D | Dm | C#dim7/D | Dm | Bbmaj7/D | Eb/D | A7sus4/D
  C  6  near-silence: drone + broken lullaby            Dm | Dm | Dm | Eb/D | Dm | Dm
  D  8  rising dread: swells, distant drums, then ebb   Dm | Eb/D | Gm/D | Ab/D | Dm | Eb/D | Bbm/D | A7sus4/D
"""
from engine import P, Bass, Kit, Pad, Plucked, ResoNoise, Song, Struck, Swell

from .common import std_buses

PLUCK_A = "r:1 | r:2 D4:4 r:4 | r:1 | A3:2 r:2 | r:1 | r:4 Eb4:4 r:2 | r:1 | D4:4 r:4 Ab3:2 |"
PLUCK_B = "r:1 | Bb3:4 r:2. | r:1 | r:2 C#4:4 r:4 | D4:2 r:2 | r:1 | Eb4:4 D4:4 r:2 | r:1 |"
PLUCK_D = "D4:4 r:2. | r:1 | G3:4 r:4 Ab3:4 r:4 | r:1 | D4:4 r:2. | Eb4:4 r:2. | r:1 | A3:2 r:2 |"
BROKEN = "r:1 | A4:8 D5 F5:4. Eb5:8 D5:4 | r:1 | r:2 A4:8 D5 F5:4 | Eb5:2. r:4 | r:1 |"


def build():
    s = Song("ruins_explore", bpm=60, key="D", seed=81, target_lufs=-16.0)
    s.meta["mood"] = "tense, desolate"
    s.meta.update(title="Dead City", key="D phrygian", use="Ruined city exploration")
    s.section("A", 8, "Dm | Dm | Eb/D | Dm | Dm | Bb/D | Eb/D | Dm")
    s.section("B", 8, "Gm/D | Eb/D | Dm | C#dim7/D | Dm | Bbmaj7/D | Eb/D | A7sus4/D")
    s.section("C", 6, "Dm | Dm | Dm | Eb/D | Dm | Dm")
    s.section("D", 8, "Dm | Eb/D | Gm/D | Ab/D | Dm | Eb/D | Bbm/D | A7sus4/D")
    s.bus("cave", ir="cave", ret=0.0, eq=[("hp", 120), ("lp", 7000)])
    s.bus("echo", kind="echo", time=0.75, fb=0.45, lp=2200, hp=300, ret=-3.0)
    s.master["eq"] = [("peak", 250, -1.0, 0.8)]

    pl = s.part("pluck", Plucked("guitar", t60_scale=1.4), level=0.0, pan=-0.25, ref=True,
                sends={"cave": -3, "echo": -8}, human_ms=25)
    pl.melody(PLUCK_A, "A", transpose=12, vel=0.6)
    pl.melody(PLUCK_B, "B", transpose=12, vel=0.62)
    pl.melody(PLUCK_D, "D", transpose=12, vel=0.62)
    ghost = s.part("pluck_flat", Plucked("guitar", t60_scale=1.4), level=-4.0, pan=0.3,
                   sends={"cave": -1, "echo": -6}, human_ms=25, offset_ms=35)
    for sec, txt in (("A", PLUCK_A), ("B", PLUCK_B), ("D", PLUCK_D)):
        ghost.melody(txt, sec, transpose=12 - 0.16, vel=0.55)

    drone = s.part("drone", Pad("drone"), level=-9.0, width=1.3, sends={"cave": -8}, human_ms=0,
                   fx=[("eq", [("lowshelf", 120, -2.0), ("peak", 260, -3.0, 0.9)])],
                   post_fx=[("slow_filter", {"lo": 260, "hi": 1100, "rate": 1 / 24})])
    for sec in ("A", "B", "C", "D"):
        sc = s.sec(sec)
        drone.add(s.at(sec), sc.bars * 4 + 2.0, [38, 45], 0.8)

    pad = s.part("pad", Pad("dark"), level=-9.0, width=1.2, sends={"cave": -4}, human_ms=0,
                 fx=[("eq", [("peak", 280, -3.0, 0.9)])])
    P.pad(pad, ["A", "B", "D"], n=3, lo=50, hi=65, vel=0.6)
    pad.gain("A", -3).gain("B", 0).gain("D", 1)

    wind = s.part("wind", ResoNoise(t60=3.5, lp=1400, attack=3.0, release=4.0), level=-9.0, width=1.0,
                  pan=0.2, sends={"cave": -2}, human_ms=0)
    for at, beats, p in ((("A", 1), 12, [50]), (("A", 5), 10, [57]), (("B", 2), 14, [51]),
                         (("C", 1), 12, [62]), (("D", 1), 10, [51]), (("D", 4), 14, [56, 50])):
        wind.add(s.at(at), beats, p, 0.7)

    mbox = s.part("broken", Struck("musicbox", decay=1.4), level=-2.0, pan=0.15,
                  sends={"cave": 0, "echo": -4}, human_ms=40)
    mbox.melody(BROKEN, "C", transpose=12 - 0.3, vel=0.5)

    sub = s.part("sub", Bass("sub", drive=0.0), level=-13.0, human_ms=0)
    P.bassline(sub, ("B", 4, 4), "1 - . .", vel=0.6, lo=26, hi=40)
    P.bassline(sub, ("D", 2, 6), "1 - . .", vel=0.65, lo=26, hi=40)

    sw = s.part("swell", Swell(lp=(250, 2200)), level=-8.0, width=1.4, sends={"cave": -3}, human_ms=0)
    sw.add(s.at(("B", 6)), 8.0, [50, 51, 57], 0.7)
    sw.add(s.at(("D", 5)), 11.5, [50, 51, 56, 62], 0.75)

    kit = s.part("metal", Kit(variants=6), level=-5.0, sends={"cave": 0}, human_ms=30,
                 fx=[("eq", [("hp", 90), ("lowshelf", 120, -3.0), ("lp", 4500)])])
    hits = [(("A", 0, 2.5), "metal", 0.5), (("A", 3, 1.0), "pipe", 0.45), (("A", 6, 3.5), "metal_lo", 0.5),
            (("B", 0, 1.5), "scrape", 0.6), (("B", 2, 3.0), "anvil", 0.35), (("B", 4, 0.0), "metal", 0.6),
            (("B", 5, 2.5), "pipe", 0.5), (("B", 7, 1.0), "scrape", 0.55), (("C", 2, 2.0), "pipe", 0.35),
            (("D", 0, 0.0), "boom", 0.55), (("D", 2, 2.5), "metal", 0.6), (("D", 3, 3.0), "scrape", 0.6),
            (("D", 5, 1.0), "metal_lo", 0.65), (("D", 6, 0.0), "taiko", 0.45), (("D", 6, 2.0), "taiko", 0.4),
            (("D", 6, 3.0), "taiko", 0.5), (("D", 7, 0.0), "boom", 0.5)]
    for at, name, v in hits:
        kit.add(s.at(at), 1.0, name, v)
    return s
