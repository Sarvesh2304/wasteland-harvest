"""Shop - "Marta's Counter".  Cozy and intimate.

E-flat major, swung 8ths (0.62), 96 BPM, 4/4, 24 bars (60 s), loop.

Music box melody over rootless e-piano comping, a soft walking upright bass and brushes;
ii-V-I movement throughout (Fm7-Bb7-Ebmaj7, Gm7-C7 secondary dominants) and a backdoor
Db7 in the bridge, where the e-piano takes the tune and the music box answers.

Form
  A   8  Ebmaj7 | Cm7 | Fm7 | Bb7 | Gm7 | C7 | Fm7 | Bb7
  B   8  Abmaj7 | Db7 | Ebmaj7/G | C7 | Fm7 | Bb7 | Ebmaj7 | Fm7 Bb7
  A2  8  Ebmaj7 | Cm7 | Fm7 | Bb7 | Gm7 C7 | Fm7 Bb7 | Eb6 | Fm7 Bb7
"""
from engine import P, EPiano, Kit, Plucked, Song, Struck

from .common import lint, std_buses

MEL_A = """
Bb5:4. G5:8 F5:4 Eb5:4 | G5:2 r:4 Eb5:8 F5 | Ab5:4. G5:8 F5:4 Eb5:4 | D5:2. r:4 |
Bb5:4. A5:8 G5:4 F5:4 | E5:2 G5:4 Bb5:4 | Ab5:4. G5:8 F5:4 C5:4 | D5:2 F5:4 Ab5:4 |
"""
MEL_B = """
C6:4. Bb5:8 Ab5:4 G5:4 | F5:2. Ab5:4 | G5:4. F5:8 Eb5:4 Bb4:4 | E5:2. G5:4 |
Ab5:4 C6:4 Bb5:4 Ab5:4 | G5:4. F5:8 D5:2 | Eb5:2. r:4 | F5:4 Ab5:4 D5:4 F5:4 |
"""
ANSWER_B = """
r:1 | r:2 Db6:8 Bb5 Ab5:4 | r:1 | r:2 Bb5:8 G5 E5:4 |
r:1 | r:2 F5:8 Ab5 D6:4 | r:2 G5:8 Bb5 Eb6:4 | r:1 |
"""
MEL_A2 = """
Bb5:4. G5:8 F5:4 Eb5:4 | G5:2 r:4 Eb5:8 F5 | Ab5:4. G5:8 F5:4 Eb5:4 | D5:2. r:4 |
Bb5:4 G5:4 E5:4 G5:4 | Ab5:4 F5:4 D5:4 Bb4:4 | Eb5:2. r:4 | r:2 F5:4 Ab5:4 |
"""


def build():
    s = Song("shop", bpm=96, key="Eb", seed=131, target_lufs=-16.0)
    s.meta["mood"] = "cozy, intimate, jazzy"
    s.meta.update(title="Marta's Counter", key="E-flat major", use="Shops / store interiors")
    s.section("A", 8, "Ebmaj7 | Cm7 | Fm7 | Bb7 | Gm7 | C7 | Fm7 | Bb7")
    s.section("B", 8, "Abmaj7 | Db7 | Ebmaj7/G | C7 | Fm7 | Bb7 | Ebmaj7 | Fm7 Bb7")
    s.section("A2", 8, "Ebmaj7 | Cm7 | Fm7 | Bb7 | Gm7 C7 | Fm7 Bb7 | Eb6 | Fm7 Bb7")
    std_buses(s, hall="studio", echo_beats=None, hall_ret=-1.0)
    sw = (0.5, 0.62)

    mb = s.part("musicbox", Struck("musicbox", decay=1.1), level=0.0, pan=-0.1, ref=True, swing=sw,
                sends={"hall": -7}, human_ms=7)
    mb.melody(MEL_A, "A", vel=0.7)
    mb.melody(ANSWER_B, "B", vel=0.6)
    mb.melody(MEL_A2, "A2", vel=0.72)

    ep = s.part("epiano", EPiano(bark=0.8), level=-8.0, pan=0.18, swing=sw, sends={"hall": -9},
                post_fx=[("tremolo", {"rate": 4.5, "depth": 0.16})], human_ms=9)
    P.comp(ep, "A", "x..x....", vel=0.55, n=4, lo=55, hi=70, rootless=True, steps=2)
    P.comp(ep, "B", "x.......x.......", vel=0.45, n=4, lo=50, hi=65, rootless=True, steps=4)
    eplead = s.part("epiano_lead", EPiano(bark=0.6), level=-1.0, pan=0.08, swing=sw, sends={"hall": -8},
                    post_fx=[("tremolo", {"rate": 4.5, "depth": 0.12})], human_ms=9)
    eplead.melody(MEL_B, "B", vel=0.66)
    P.comp(ep, "A2", "x...x.x.", vel=0.58, n=4, lo=55, hi=70, rootless=True, steps=2)
    lint(mb, eplead)

    bass = s.part("bass", Plucked("upright"), level=-9.0, swing=sw, sends={"hall": -16}, human_ms=5)
    P.walking_bass(bass, ["A", "B", "A2"], vel=0.7, lo=31, hi=50, key="Eb")

    kit = s.part("brushes", Kit(), level=-12.0, swing=sw, sends={"hall": -12}, human_ms=6)
    kit.grid("swish", "....x.......x...", ["A", "B", "A2"], vel=0.45)
    kit.grid("brush", "....x.....o.x...", ["A", "B", "A2"], vel=0.5)
    kit.grid("brush_lo", "x.......x.......", ["B", "A2"], vel=0.35)
    return s
