"""Summer - "Scorched Summer".  Sunny, lazy, warm, hazy.

A major (with mixolydian G-naturals and a borrowed iv), 90 BPM, lazy shuffle (swing 0.63),
4/4, 44 bars (~117 s), loop.

Slide-guitar lead (glides between notes, wide bar vibrato), banjo forward rolls with the
high drone string, upright bass two-feel, brushes, and a high shimmering "heat haze" pad.

Form
  intro  4  banjo roll + haze                 A | D/A | A | E7sus4
  A      8  slide tune                        A | D/A | A | E7 | F#m | D | A/E E7 | A
  A2     8  tune, second ending, guitar strums
  B      8  the hazy turn: IV -> iv           D | Dm6 | A/C# | F#m7 | Bm7 | E7sus4 E7 | A | A7
  C      8  banjo break, slide answers        G | D/F# | G | A | G | D/F# | Bm7 | E7sus4 E7
  A3     8  tune returns, fuller
"""
from engine import P, Pad, Plucked, Slide, Song

from .common import folk_kit, lint, std_buses

TUNE = """
E5:2. C#5:8 E5:8/ | F#5:2/ E5:4 D5:4 | C#5:2. r:8 A4:8 | B4:4. C#5:8 D5:4 E5:4 |
F#5:2/ E5:8 C#5:8 A4:4 | B4:4. A4:8 F#4:2 | A4:4 C#5:4 B4:4 G#4:4/ | A4:1 |
"""

TUNE2 = """
E5:2. C#5:8 E5:8/ | F#5:2/ E5:4 D5:4 | C#5:2. r:8 A4:8 | B4:4. C#5:8 D5:4 E5:4 |
A5:2/ G#5:8 F#5:8 E5:4 | F#5:4. E5:8 D5:2 | C#5:4 E5:4 D5:4 B4:4 | A4:2. r:4 |
"""

BRIDGE = """
A5:2/ F#5:4 D5:4 | F5:2. D5:4 | E5:4. C#5:8 A4:2 | C#5:2 E5:2 |
D5:4. C#5:8/ B4:2 | A4:2 G#4:2 | E5:2/ C#5:2 | G5:2. r:4 |
"""

ANSWERS_C = """
r:1 | A5:2/ F#5:2 | r:1 | E5:1 |
r:1 | F#5:2/ A5:2 | r:1 | B4:2 G#4:2 |
"""


def build():
    s = Song("summer", bpm=90, key="A", seed=31, target_lufs=-15.0)
    s.meta.update(title="Scorched Summer", key="A major", use="Farm / town daytime, summer")
    s.section("intro", 4, "A | D/A | A | E7sus4")
    s.section("A", 8, "A | D/A | A | E7 | F#m | D | A/E E7 | A")
    s.section("A2", 8, "A | D/A | A | E7 | F#m | D | A/E E7 | A")
    s.section("B", 8, "D | Dm6 | A/C# | F#m7 | Bm7 | E7sus4 E7 | A | A7")
    s.section("C", 8, "G | D/F# | G | A | G | D/F# | Bm7 | E7sus4 E7")
    s.section("A3", 8, "A | D/A | A | E7 | F#m | D | A/E E7 | A")
    std_buses(s, echo_beats=1.0, echo_fb=0.28)
    s.master["glue"] = {"ratio": 1.5}
    s.master["eq"] = [("peak", 300, -1.0, 0.9), ("highshelf", 7500, 1.5)]
    sw = (0.5, 0.63)

    lead = s.part("slide", Slide(), level=0.0, pan=0.06, ref=True, swing=sw,
                  sends={"hall": -9, "echo": -12}, human_ms=12)
    lead.melody(TUNE, "A", vel=0.75)
    lead.melody(TUNE2, "A2", vel=0.78)
    lead.melody(BRIDGE, "B", vel=0.8)
    lead.melody(ANSWERS_C, "C", vel=0.72)
    lead.melody(TUNE2, "A3", vel=0.84)
    lint(lead)

    banjo = s.part("banjo", Plucked("banjo"), level=-8.0, pan=-0.35, swing=sw,
                   sends={"hall": -14, "room": -10}, human_ms=6)
    P.banjo_roll(banjo, ["intro", "A", "A2", "B", "C", "A3"], roll="0 1 3 0 1 3 0 2",
                 drone=69, vel=0.55, lo=50, hi=71)
    banjo.gain("intro", -1).gain("A", -3).gain("B", -4).gain("C", 3).gain("A3", -2)

    gtr = s.part("guitar", Plucked("guitar", t60_scale=0.9), level=-9.0, pan=0.32, swing=sw,
                 sends={"hall": -14, "room": -10}, human_ms=8)
    P.strum(gtr, ["A2", "A3"], "D..U.UD.", vel=0.55, spread_ms=28)
    P.strum(gtr, "B", "D...D...", vel=0.48, spread_ms=40)
    P.strum(gtr, "C", "D.......", vel=0.5, spread_ms=35)

    bass = s.part("bass", Plucked("upright"), level=-8.0, swing=sw, sends={"room": -16}, human_ms=6)
    P.bassline(bass, ["A", "A2", "B", "A3"], "1 - 5 -", vel=0.75, lo=33, hi=50)
    P.bassline(bass, "C", "1 - - . . . 5 .", vel=0.72, lo=31, hi=50)

    haze = s.part("haze", Pad("glass", attack=1.8, release=2.5), level=-15.0, width=1.4,
                  sends={"hall": -4}, human_ms=0, post_fx=[("chorus", {"rate": 0.25, "depth_ms": 3.5, "mix": 0.5})])
    P.pad(haze, ["intro", "A", "A2", "B", "C", "A3"], n=3, lo=69, hi=88, vel=0.5)

    warm = s.part("pad", Pad("warm"), level=-14.0, sends={"hall": -8}, human_ms=0)
    P.pad(warm, ["B", "A3"], n=4, lo=52, hi=69, vel=0.55)
    warm.gain("B", 0).gain("A3", -2)

    kit = s.part("drums", folk_kit(), level=-13.0, swing=sw, sends={"room": -8, "hall": -16}, human_ms=5)
    kit.grid("swish", "x.......x.......", ["A", "A2", "B", "A3"], vel=0.5)
    kit.grid("brush", "....x.......x...", ["A2", "A3"], vel=0.6)
    kit.grid("kick_soft", "x.......x.......", ["A2", "A3"], vel=0.6)
    kit.grid("kick_soft", "x...............", "B", vel=0.5)
    kit.grid("shaker", "..x...x...x...x.", ["B", "A3"], vel=0.45)
    kit.grid("rim", "....x.......x...", "C", vel=0.55)
    kit.grid("kick_soft", "x.........x.....", "C", vel=0.55)
    return s
