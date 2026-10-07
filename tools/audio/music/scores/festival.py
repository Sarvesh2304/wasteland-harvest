"""Festival - "Harvest Day Reel".  Celebratory community dance (reel / hoedown).

D major, 120 BPM, 4/4, 44 bars (88 s), loop.

A two-strain reel in running eighths (AABB form) on harmonica and accordion over banjo
rolls, boom-chick guitar, root-fifth upright bass, foot stomps, hand claps and tambourine;
then the whole town plays the leitmotif (C) - harmonica with the accordion an octave below,
chiptune "festival lights" arpeggios over the top.

Form
  intro  4  stomp-clap + banjo                    D | D | G | A
  A      8  reel strain A (harmonica)             D | G | D | A | D | G | A7 | D
  A2     8  strain A again (accordion leads)
  B      8  strain B, higher                      Bm | G | D | A | Bm | G | Em7 A7 | D
  B2     8  strain B, both instruments
  C      8  leitmotif, everybody                  D | G | Bm | Asus4 A | D/F# | G Gm | Em7 A7 | D
"""
from engine import P, Chip, Kit, Plucked, Reed, Song

from .common import BOOM_CHICK, lint, std_buses
from .leitmotif import LEITMOTIF, LEITMOTIF_CHORDS

REEL_A = """
A4:8 D5 F#5 D5 A5 D5 F#5 D5 | G5:8 B5 D6 B5 G5 D5 B4 D5 | A4:8 D5 F#5 A5 D6 A5 F#5 D5 | E5:8 A5 C#6 A5 E5 C#5 A4 C#5 |
A4:8 D5 F#5 D5 A5 D5 F#5 D5 | B5:8 A5 G5 F#5 E5 D5 C#5 B4 | A4:8 B4 C#5 D5 E5 F#5 G5 E5 | F#5:8 E5 D5 C#5 D5:4 A4:4 |
"""

REEL_A2 = """
A4:8 D5 F#5 D5 A5 D5 F#5 D5 | G5:8 B5 D6 B5 G5 D5 B4 D5 | A4:8 D5 F#5 A5 D6 A5 F#5 D5 | E5:8 A5 C#6 A5 E5 C#5 A4 C#5 |
A4:8 D5 F#5 D5 A5 D5 F#5 D5 | B5:8 A5 G5 F#5 E5 D5 C#5 B4 | A4:8 B4 C#5 D5 E5 F#5 G5 E5 | D5:4 F#5:4 D5:2 |
"""

REEL_B = """
B4:8 D5 F#5 B5 A5 F#5 D5 F#5 | G5:8 F#5 G5 A5 B5 A5 G5 F#5 | F#5:8 A5 D6 A5 F#5 A5 D6 A5 | E5:8 F#5 G5 F#5 E5 D5 C#5 A4 |
B4:8 D5 F#5 B5 A5 F#5 D5 F#5 | G5:8 A5 B5 D6 E6 D6 B5 G5 | E5:8 G5 B5 G5 C#5 E5 A5 G5 | F#5:4 D5:4 D5:2 |
"""


def build():
    s = Song("festival", bpm=120, key="D", seed=111, target_lufs=-14.0)
    s.meta.update(title="Harvest Day Reel", key="D major", use="Festivals (Harvest Day, Winter Gathering) / celebrations")
    s.section("intro", 4, "D | D | G | A")
    s.section("A", 8, "D | G | D | A | D | G | A7 | D")
    s.section("A2", 8, "D | G | D | A | D | G | A7 | D")
    s.section("B", 8, "Bm | G | D | A | Bm | G | Em7 A7 | D")
    s.section("B2", 8, "Bm | G | D | A | Bm | G | Em7 A7 | D")
    s.section("C", 8, LEITMOTIF_CHORDS)
    std_buses(s, echo_beats=None, hall_ret=-2.0)
    s.master["glue"] = {"ratio": 1.6}
    s.master["eq"] = [("peak", 300, -1.0, 0.9), ("highshelf", 7500, 1.5)]
    sw = (0.5, 0.54)

    harp = s.part("harmonica", Reed("harmonica", vib_cents=8.0), level=0.0, pan=0.12, ref=True, swing=sw,
                  sends={"hall": -12, "room": -10}, human_ms=5)
    harp.melody(REEL_A, "A", vel=0.8)
    harp.melody(REEL_B, "B", vel=0.82)
    harp.melody(REEL_B, "B2", vel=0.86)
    harp.melody(LEITMOTIF, "C", vel=0.9)

    acc = s.part("accordion", Reed("accordion"), level=-1.0, pan=-0.15, swing=sw,
                 sends={"hall": -12, "room": -10}, human_ms=5)
    acc.melody(REEL_A2, "A2", vel=0.8)
    acc.melody(REEL_B, "B2", transpose=-12, vel=0.7)
    acc.melody(LEITMOTIF, "C", transpose=-12, vel=0.75)
    lint(harp, acc)

    banjo = s.part("banjo", Plucked("banjo"), level=-7.0, pan=-0.38, swing=sw,
                   sends={"room": -8, "hall": -16}, human_ms=4)
    P.banjo_roll(banjo, ["intro", "A", "A2", "B", "B2", "C"], roll="0 1 3 0 1 3 0 2", drone=69,
                 vel=0.6, lo=50, hi=71)
    banjo.gain("intro", 0).gain("A", -2).gain("A2", -1).gain("C", -2)

    gtr = s.part("guitar", Plucked("guitar", t60_scale=0.5), level=-7.0, pan=0.36, swing=sw,
                 sends={"room": -8, "hall": -16}, human_ms=4)
    P.strum(gtr, ["A", "A2", ("B", 4, 4), "B2", "C"], BOOM_CHICK, vel=0.66, spread_ms=12, gate=0.6)
    P.strum(gtr, ("B", 0, 4), "D.......", vel=0.75, spread_ms=16, gate=0.35)

    bass = s.part("bass", Plucked("upright"), level=-6.0, swing=sw, sends={"room": -14}, human_ms=3)
    P.bassline(bass, ["A", "A2", ("B", 4, 4), "B2", "C"], "1 . 5 . 1 . 5 .", vel=0.82, lo=33, hi=50, gate=0.9)
    P.bassline(bass, ("B", 0, 4), "1 . . . . . . .", vel=0.85, lo=33, hi=50, gate=0.6)

    chip = s.part("chip", Chip(duty=0.25, decay=0.12, sustain=0.35), level=-13.0, pan=0.3, swing=sw,
                  sends={"hall": -10}, human_ms=0)
    P.arp(chip, "C", rate=0.25, order="updown", n=4, lo=76, hi=93, vel=0.5, gate=0.5)
    P.arp(chip, ("B2", 4, 4), rate=0.5, order="up", n=4, lo=74, hi=91, vel=0.45, gate=0.5)

    kit = s.part("drums", Kit(gains={"tamb": 0.5, "clap": 0.8, "wood": 0.6}), level=-6.0, swing=sw,
                 sends={"room": -5, "hall": -16}, human_ms=4)
    kit.grid("stomp", "X.......X.......", ["intro", "A", "A2", ("B", 4, 4), "B2", "C"], vel=0.9)
    kit.grid("stomp", "X...............", ("B", 0, 4), vel=0.95)
    kit.grid("clap", "....X.......X...", ["intro", "A2", "B", "B2", "C"], vel=0.75)
    kit.grid("kick_soft", "X.......X.......", ["A2", "B2", "C"], vel=0.6)
    kit.grid("tamb", "x.x.x.x.x.x.x.x.", ["A", "A2", "B2", "C"], vel=0.55)
    kit.grid("tamb_shake", "....x.......x...", [("B", 4, 4)], vel=0.5)
    kit.grid("wood", "..x...x...x...x.", [("B", 4, 4), "B2"], vel=0.5)
    kit.grid("clap", "x.x.x.x.xxxxXXXX", ("B2", 7, 1), vel=0.7)
    kit.add(s.at("C"), 1.0, "crash", 0.55)
    return s
