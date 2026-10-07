"""Spring - "Spring Rains".  Farm / town daytime in spring.

G major, 112 BPM, 4/4 with a light 8th-note lilt (swing 0.56), 56 bars (120 s), loop.

Fresh and bouncy: Travis-picked guitar, harmonica tune, upright bass, glockenspiel answers,
marimba "raindrops".  The breakdown (C) quotes the first four bars of the leitmotif on
glockenspiel, transposed to G, before the harmonica answers with new material.

Form
  intro  4  guitar alone                       G | C/G | G | D/F#
  A      8  tune A (harmonica), shaker joins   G | C | G/B | D | Em | C | Am7 D7 | G
  A2     8  tune A, second ending, marimba     (same chords)
  B      8  call (harmonica) & response (glock) Em | C | G | D | Em | C | Am7 | D7sus4 D7
  C      8  rain breakdown: leitmotif quote    G | C | Em | Dsus4 D | Am7 | Bm7 | C | D7sus4 D7
  A3     8  tune A, full band
  B2     8  call & response, both instruments
  tag    4  winds back down to the intro       C | G/B | Am7 | D7sus4
"""
from engine import P, Bass, Pad, Plucked, Reed, Song, Struck

from .common import ARP_UP, TRAVIS, folk_kit, lint, std_buses

TUNE_A = """
r:8 D5 G5 A5 B5:4 A5:8 G5 | E5:4 G5:4. E5:8 D5:4 | r:8 D5 G5 A5 B5 D6:4. | C6:8 B5 A5:4 F#5:4 D5:4 |
E5:8 G5 B5:4 B5:8 A5 G5:4 | A5:4.^ G5:8 E5:2 | C5:8* D5* E5 G5 F#5:4 A5:4 | G5:2. r:4 |
"""

TUNE_A2 = """
r:8 D5 G5 A5 B5:4 A5:8 G5 | E5:4 G5:4. E5:8 D5:4 | r:8 D5 G5 A5 B5 D6:4. | C6:8 B5 A5:4 F#5:4 D5:4 |
E5:8 G5 B5:4 B5:8 A5 G5:4 | A5:4.^ G5:8 E5:2 | C6:8 B5 A5 G5 F#5 E5 D5 F#5 | G5:4 D5:8 B4 G4:4 r:4 |
"""

CALL_B = """
B4:4 E5:8 F#5 G5:4. F#5:8 | E5:2 r:2 | r:1 | r:1 |
G5:4 B5:8 A5 G5:4. E5:8 | G5:2 r:2 | r:1 | G5:2 F#5:2 |
"""

RESP_B = """
r:1 | r:1 | B5:8 D6 G6:4 F#6:8 E6 D6:4 | F#6:4 E6:4 D6:2 |
r:1 | r:1 | E6:8 D6 C6:4 A5:4 E5:4 | r:1 |
"""

CALL_B2 = """
B4:4 E5:8 F#5 G5:4. F#5:8 | E5:2 r:2 | r:1 | r:2 A5:4 F#5:4 |
G5:4 B5:8 A5 G5:4. E5:8 | G5:2 r:2 | r:1 | A5:4 G5:4 F#5:2 |
"""

QUOTE_C = """
D5:8 G5 B5:4. A5:8 G5:4 | C6:4. B5:8 A5:2 | E5:8 G5 B5:4. C6:8 B5:4 | A5:4. G5:8 F#5:2 |
r:1 | r:1 | r:1 | r:1 |
"""

ANSWER_C = """
r:1 | r:1 | r:1 | r:1 |
r:4 E5:8 G5 A5:4. G5:8 | F#5:2 D5:4 B4:4 | E5:4. D5:8 C5:4 E5:4 | D5:2 r:2 |
"""

TAG = "E6:2 D6:2 | D6:2 B5:2 | C6:2 A5:2 | A5:1 |"


def build():
    s = Song("spring", bpm=112, key="G", seed=21, target_lufs=-15.0)
    s.meta["mood"] = "fresh, bouncy"
    s.meta.update(title="Spring Rains", key="G major", use="Farm / town daytime, spring")
    s.section("intro", 4, "G | C/G | G | D/F#")
    s.section("A", 8, "G | C | G/B | D | Em | C | Am7 D7 | G")
    s.section("A2", 8, "G | C | G/B | D | Em | C | Am7 D7 | G")
    s.section("B", 8, "Em | C | G | D | Em | C | Am7 | D7sus4 D7")
    s.section("C", 8, "G | C | Em | Dsus4 D | Am7 | Bm7 | C | D7sus4 D7")
    s.section("A3", 8, "G | C | G/B | D | Em | C | Am7 D7 | G")
    s.section("B2", 8, "Em | C | G | D | Em | C | Am7 | D7sus4 D7")
    s.section("tag", 4, "C | G/B | Am7 | D7sus4")
    std_buses(s, echo_beats=0.75)
    s.master["glue"] = {"ratio": 1.5}
    s.master["eq"] = [("peak", 300, -1.0, 0.9), ("highshelf", 7500, 1.5)]
    sw = (0.5, 0.56)

    harp = s.part("harmonica", Reed("harmonica"), level=0.0, pan=0.08, ref=True, swing=sw,
                  sends={"hall": -10, "echo": -16}, human_ms=8)
    harp.melody(TUNE_A, "A", vel=0.72)
    harp.melody(TUNE_A2, "A2", vel=0.76)
    harp.melody(CALL_B, "B", vel=0.74)
    harp.melody(ANSWER_C, "C", vel=0.68)
    harp.melody(TUNE_A2, "A3", vel=0.84)
    harp.melody(CALL_B2, "B2", vel=0.8)

    glock = s.part("glock", Struck("glock", decay=0.9), level=-5.0, pan=-0.25, swing=sw,
                   sends={"hall": -6, "echo": -12}, human_ms=5)
    glock.melody(RESP_B, "B", vel=0.6)
    glock.melody(QUOTE_C, "C", vel=0.62)
    glock.melody(RESP_B, "B2", vel=0.66)
    glock.melody(TAG, "tag", vel=0.5)
    lint(harp, glock)

    gtr = s.part("guitar", Plucked("guitar"), level=-6.0, pan=-0.28, swing=sw,
                 sends={"hall": -16, "room": -12}, human_ms=7)
    P.fingerpick(gtr, "intro", TRAVIS, vel=0.6)
    P.fingerpick(gtr, ["A", "A2", "B"], TRAVIS, vel=0.62)
    P.fingerpick(gtr, "C", ARP_UP, vel=0.52)
    P.fingerpick(gtr, ["A3", "B2"], TRAVIS, vel=0.66)
    P.fingerpick(gtr, "tag", ARP_UP, vel=0.55)
    gtr.gain("C", -2).gain("A3", 0)

    strum = s.part("strum", Plucked("guitar", t60_scale=0.7), level=-10.0, pan=0.4, swing=sw,
                   sends={"room": -10, "hall": -16}, human_ms=6)
    P.strum(strum, ["A3", "B2"], "D.xU.UxU", vel=0.6)

    mar = s.part("marimba", Struck("marimba"), level=-10.0, pan=0.3, swing=sw,
                 sends={"hall": -9}, human_ms=6)
    P.arp(mar, "A2", rate=0.5, order=[0, 2, 1, 3, 2, 1, 3, 2], n=4, lo=55, hi=74, vel=0.5, gate=0.9)
    P.arp(mar, "C", rate=0.5, order="random", n=5, lo=62, hi=86, vel=0.48, gate=0.9,
          skip_rate=0.3, seed_tag="rain")
    P.arp(mar, "A3", rate=0.5, order=[0, 2, 1, 3, 2, 1, 3, 2], n=4, lo=55, hi=74, vel=0.5, gate=0.9)
    mar.gain("C", 2)

    bass = s.part("bass", Plucked("upright"), level=-8.0, swing=sw, sends={"room": -16}, human_ms=5)
    P.bassline(bass, ["A", "A2"], "1 - 5 -", vel=0.75, lo=33, hi=50)
    P.bassline(bass, "B", "1 - - 5", vel=0.72, lo=33, hi=50)
    P.bassline(bass, "C", "1 - - -", vel=0.65, lo=33, hi=50)
    P.bassline(bass, ["A3", "B2"], "1 - 5 5 1 - 5 a", vel=0.8, lo=33, hi=50)
    P.bassline(bass, "tag", "1 - - -", vel=0.6, lo=33, hi=50)

    pad = s.part("pad", Pad("soft"), level=-15.0, sends={"hall": -8}, human_ms=0)
    P.pad(pad, ["B", "C", "B2"], n=4, lo=55, hi=71, vel=0.6)
    pad.gain("B", -3).gain("C", 0).gain("B2", -3)

    kit = s.part("drums", folk_kit(), level=-12.0, swing=sw, sends={"room": -8, "hall": -18}, human_ms=4)
    kit.grid("shaker", "xoxoxoxoxoxoxoxo", ["A", "A2", "B", "A3", "B2"], vel=0.55)
    kit.grid("kick_soft", "X.......x.x.....", ["A2", "B"], vel=0.7)
    kit.grid("rim", "....x.......x...", ["A2", "B"], vel=0.6)
    kit.grid("brush", "....x.......x...", "C", vel=0.4)
    kit.grid("shaker_long", "x.......x.......", "C", vel=0.4)
    kit.grid("kick_soft", "X.....x.X.x.....", ["A3", "B2"], vel=0.8)
    kit.grid("rim", "....X.......X...", ["A3", "B2"], vel=0.7)
    kit.grid("tamb", "..x...x...x...x.", ["A3", "B2"], vel=0.45)
    kit.grid("brush", "x.x.x.x.X.X.X.XX", ("C", 7, 1), vel=0.55)
    return s
