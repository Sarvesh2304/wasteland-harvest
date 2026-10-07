"""Town - "The Plaza".  The settlement square: friendly, gently busy.

F major (B section in D minor), 105 BPM, 4/4, 44 bars (100.6 s), loop.

Accordion tune over boom-chick guitar, upright bass, wood block and shaker; the harmonica
takes the D-minor B strain; a marimba "market" interlude bustles in C; the finale puts
accordion and harmonica together in thirds.

Form
  intro  4  boom-chick + wood block             F | Bb/F | F | C7
  A      8  accordion tune                      F | Am | Bb | C7 | F | Dm7 | Gm7 C7 | F
  B      8  harmonica, D minor, walking bass    Dm | Dm/C | Bb | A7 | Dm | Gm7 | C7sus4 | C7
  A2     8  accordion tune, glock sparkles
  C      8  marimba interlude, offbeat accordion Bb | F/A | Gm7 | F | Bb | F/A | G7 | C7sus4 C7
  A3     8  accordion + harmonica in thirds, full band
"""
from engine import P, Chip, Plucked, Reed, Song, Struck

from .common import BOOM_CHICK, folk_kit, lint, std_buses

A_CH = "F | Am | Bb | C7 | F | Dm7 | Gm7 C7 | F"

TUNE = """
C5:4 F5:4 F5:8 G5 A5:4 | E5:4. C5:8 A4:2 | D5:4 F5:4 Bb5:4. A5:8 | G5:2 E5:4 r:4 |
C5:4 F5:4 F5:8 G5 A5:4 | D6:4.^ C6:8 A5:2 | Bb5:4 G5:4 E5:4 G5:4 | F5:2. r:4 |
"""

HARMONY = """
A4:4 C5:4 C5:8 E5 F5:4 | C5:4. A4:8 E4:2 | Bb4:4 D5:4 F5:4. F5:8 | E5:2 C5:4 r:4 |
A4:4 C5:4 C5:8 E5 F5:4 | A5:4. A5:8 F5:2 | G5:4 D5:4 C5:4 E5:4 | A4:2. r:4 |
"""

TUNE_B = """
A5:4 F5:8 E5 D5:4 A4:4 | C5:2 D5:4 E5:4 | F5:4. E5:8 D5:4 Bb4:4 | C#5:2. A4:4 |
D5:4 F5:4 A5:4 D6:4 | C6:4. Bb5:8 G5:2 | F5:4 G5:4 Bb5:4 C6:4 | Bb5:4 A5:4 G5:4 E5:4 |
"""

MARIMBA_C = """
D5:8 F5 Bb5 F5 D5 F5 Bb5 D6 | C6:4 A5:4 F5:4 C5:4 | Bb4:8 D5 G5 Bb5 A5:4 G5:4 | A5:2 r:2 |
D5:8 F5 Bb5 F5 D5 F5 Bb5 D6 | C6:4 A5:4 F5:4 A5:4 | B5:4. A5:8 G5:4 F5:4 | F5:4 G5:4 E5:4 C5:4 |
"""

SPARKLE = "r:1 | r:2 E6:8 F6 A6:4 | r:1 | r:2 G6:8 E6 C6:4 | r:1 | r:2 F6:8 A6 C7:4 | r:1 | r:1 |"


def build():
    s = Song("town", bpm=105, key="F", seed=71, target_lufs=-15.0)
    s.meta["mood"] = "friendly, gently busy"
    s.meta.update(title="The Plaza", key="F major", use="Settlement plaza / town map")
    s.section("intro", 4, "F | Bb/F | F | C7")
    s.section("A", 8, A_CH)
    s.section("B", 8, "Dm | Dm/C | Bb | A7 | Dm | Gm7 | C7sus4 | C7")
    s.section("A2", 8, A_CH)
    s.section("C", 8, "Bb | F/A | Gm7 | F | Bb | F/A | G7 | C7sus4 C7")
    s.section("A3", 8, A_CH)
    std_buses(s, echo_beats=0.5, echo_fb=0.25)
    s.master["glue"] = {"ratio": 1.5}
    s.master["eq"] = [("peak", 300, -1.0, 0.9), ("highshelf", 7500, 1.5)]
    sw = (0.5, 0.55)

    acc = s.part("accordion", Reed("accordion"), level=0.0, pan=-0.12, ref=True, swing=sw,
                 sends={"hall": -11, "room": -12}, human_ms=8)
    acc.melody(TUNE, "A", vel=0.72)
    acc.melody(TUNE, "A2", vel=0.76)
    acc.melody(TUNE, "A3", vel=0.84)
    P.comp(acc, "C", ".x.x.x.x", vel=0.42, n=3, lo=60, hi=72, rootless=False, steps=2, gate=0.5)

    harp = s.part("harmonica", Reed("harmonica"), level=-1.0, pan=0.18, swing=sw,
                  sends={"hall": -10, "echo": -16}, human_ms=9)
    harp.melody(TUNE_B, "B", vel=0.76)
    harp.melody(HARMONY, "A3", vel=0.66)

    mar = s.part("marimba", Struck("marimba"), level=-2.0, pan=0.25, swing=sw,
                 sends={"hall": -10}, human_ms=6)
    mar.melody(MARIMBA_C, "C", vel=0.75)

    glock = s.part("glock", Struck("glock"), level=-9.0, pan=0.4, swing=sw, sends={"hall": -6},
                   human_ms=5)
    glock.melody(SPARKLE, "A2", vel=0.45)
    lint(acc, harp, mar)

    gtr = s.part("guitar", Plucked("guitar", t60_scale=0.6), level=-7.0, pan=-0.35, swing=sw,
                 sends={"room": -9, "hall": -16}, human_ms=6)
    P.strum(gtr, ["intro", "A", "A2", "C", "A3"], BOOM_CHICK, vel=0.62, spread_ms=14, gate=0.7)
    P.strum(gtr, "B", "D.xU.Ux.", vel=0.55, spread_ms=18)

    bass = s.part("bass", Plucked("upright"), level=-8.0, swing=sw, sends={"room": -14}, human_ms=5)
    P.bassline(bass, ["intro", "A", "A2", "C"], "1 - 5 -", vel=0.75, lo=33, hi=50)
    P.walking_bass(bass, "B", vel=0.72, lo=33, hi=50, key="D", mode="harmonic_minor")
    P.bassline(bass, "A3", "1 - 5 - 1 - 5 a", vel=0.8, lo=33, hi=50)

    chip = s.part("chip", Chip(duty=0.125), level=-18.0, pan=0.3, swing=sw, sends={"echo": -8, "hall": -10},
                  human_ms=0)
    P.arp(chip, ("C", 4, 4), rate=0.25, order="updown", n=3, lo=72, hi=88, vel=0.5, gate=0.5)

    kit = s.part("drums", folk_kit(), level=-12.0, swing=sw, sends={"room": -7, "hall": -18}, human_ms=4)
    kit.grid("wood", "....x.......x...", ["intro", "A", "A2", "A3"], vel=0.55)
    kit.grid("shaker", "x.o.x.o.x.o.x.o.", ["A", "B", "A2", "C", "A3"], vel=0.5)
    kit.grid("kick_soft", "x.......x.......", ["A2", "C", "A3"], vel=0.6)
    kit.grid("rim", "....x.......x...", ["B", "C"], vel=0.55)
    kit.grid("wood_hi", "..........x..x..", "C", vel=0.4)
    kit.grid("tamb", "....x.......x...", "A3", vel=0.45)
    return s
