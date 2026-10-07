"""Winter - "Grey Winter".  Sparse, quiet, cold but warm-hearted.

A minor (with Lydian #11 shimmer on the F chords) -> F major warmth, 72 BPM, 4/4,
36 bars (120 s), loop.

Cold: glassy FM bells in a high register, open fifths and ninths, an airy glass pad, wind
chimes.  Warm-hearted: the e-piano's soft chords and, in B, the e-piano itself sings the
first four bars of the leitmotif (transposed to F) - lamplight in the window.

Form
  intro  4  bells alone                       Am9 | Fmaj7#11 | Am9 | Fmaj7#11
  A      8  bell melody, e-piano chords       Am9 | Fmaj7 | C/G | G | Am9 | Fmaj7 | Dm7 | Esus4 E
  B      8  warmth: leitmotif on e-piano      F | Bb | Dm | Csus4 C | Dm7 | Gm7 | Bbmaj7 | Csus4 C
  A2     8  bells + glockenspiel, soft brushes
  coda   8  slowly rising bell line           Fmaj7#11 | Em7 | Dm9 | Esus4 E | Am9 | Fmaj7#11 | Am9 | Esus4
"""
from engine import P, Bass, EPiano, FMBell, Kit, Pad, Song, Struck

from .common import lint, std_buses

INTRO = "E6:2 B5:2 | A5:1 | E6:2 B5:2 | C6:1 |"
BELLS_A = "E5:2 B5:2 | A5:2. G5:4 | E5:1 | D5:2 r:2 | E5:2 C6:2 | B5:2. A5:4 | F5:2 D5:2 | E5:2 G#5:2 |"
BELLS_A2 = "E5:2 B5:2 | C6:2. B5:4 | G5:1 | D5:2 B4:2 | A5:2 E6:2 | D6:2. C6:4 | A5:2 F5:2 | E5:2 G#5:2 |"
CODA = "A5:1 | G5:1 | F5:1 | E5:2 G#5:2 | A5:1 | B5:1 | C6:1 | B5:1 |"
QUOTE_B = """
C5:8 F5 A5:4. G5:8 F5:4 | Bb5:4. A5:8 G5:2 | D5:8 F5 A5:4. Bb5:8 A5:4 | G5:4. F5:8 E5:2 |
F5:2 E5:4 D5:4 | D5:2. Bb4:4 | D5:4 C5:4 A4:2 | G4:2 E4:2 |
"""


def build():
    s = Song("winter", bpm=72, key="A", seed=51, target_lufs=-16.0)
    s.meta["mood"] = "sparse, cold but warm-hearted"
    s.meta.update(title="Grey Winter", key="A minor / F major", use="Farm / town daytime, winter")
    s.section("intro", 4, "Am9 | Fmaj7#11 | Am9 | Fmaj7#11")
    s.section("A", 8, "Am9 | Fmaj7 | C/G | G | Am9 | Fmaj7 | Dm7 | Esus4 E")
    s.section("B", 8, "F | Bb | Dm | Csus4 C | Dm7 | Gm7 | Bbmaj7 | Csus4 C")
    s.section("A2", 8, "Am9 | Fmaj7 | C/G | G | Am9 | Fmaj7 | Dm7 | Esus4 E")
    s.section("coda", 8, "Fmaj7#11 | Em7 | Dm9 | Esus4 E | Am9 | Fmaj7#11 | Am9 | Esus4")
    std_buses(s, hall="night", echo_beats=1.5, echo_fb=0.35, echo_ret=-2.0)

    bells = s.part("bells", FMBell(ratio=3.5, index=1.6, decay=1.2), level=0.0, pan=-0.1, ref=True,
                   sends={"hall": -4, "echo": -10}, human_ms=10)
    bells.melody(INTRO, "intro", vel=0.6)
    bells.melody(BELLS_A, "A", vel=0.66)
    bells.melody(BELLS_A2, "A2", vel=0.7)
    bells.melody(CODA, "coda", vel=0.6)

    glock = s.part("glock", Struck("glock", decay=1.2), level=-7.0, pan=0.35,
                   sends={"hall": -3, "echo": -8}, human_ms=8)
    glock.melody(BELLS_A2, "A2", transpose=12, vel=0.4)

    ep = s.part("epiano", EPiano(bark=0.45, tine=0.8), level=-3.0, pan=0.12, sends={"hall": -7},
                post_fx=[("tremolo", {"rate": 3.2, "depth": 0.12})], human_ms=10)
    P.pad(ep, "A", n=4, lo=52, hi=69, vel=0.42, rhythm="x...............", steps=4)
    P.pad(ep, "A2", n=4, lo=52, hi=69, vel=0.42, rhythm="x...........x...", steps=4)
    P.pad(ep, "coda", n=4, lo=52, hi=69, vel=0.4, rhythm="x.......x.......", steps=4)
    P.pad(ep, "B", n=3, lo=50, hi=64, vel=0.38, rhythm="x.......x.......", steps=4)
    ep.melody(QUOTE_B, "B", vel=0.62)
    lint(bells, ep)

    glass = s.part("glass", Pad("glass", attack=2.5, release=3.0), level=-14.0, width=1.5,
                   sends={"hall": -2}, human_ms=0, post_fx=[("chorus", {"rate": 0.18, "depth_ms": 4.0, "mix": 0.5})])
    P.pad(glass, ["intro", "A", "A2", "coda"], n=3, lo=67, hi=86, vel=0.5)

    warm = s.part("warm", Pad("warm", attack=1.6), level=-13.0, sends={"hall": -6}, human_ms=0)
    P.pad(warm, "B", n=4, lo=53, hi=69, vel=0.6)

    bass = s.part("bass", Bass("round", drive=0.8), level=-13.0, sends={"hall": -18}, human_ms=4)
    P.bassline(bass, "B", "1 - - -", vel=0.6, lo=33, hi=48)
    P.bassline(bass, "A2", "1 - - -", vel=0.55, lo=33, hi=48)

    kit = s.part("perc", Kit(), level=-17.0, sends={"hall": -4}, human_ms=10)
    for bar, beat in ((1, 2.5), (3, 1.0), (6, 3.5)):
        kit.add(s.at(("A", bar, beat)), 1.0, "chime", 0.5)
    kit.add(s.at(("intro", 1, 2.0)), 1.0, "chime", 0.45)
    kit.add(s.at(("coda", 2, 1.0)), 1.0, "chime", 0.45)
    kit.add(s.at(("coda", 5, 3.0)), 1.0, "chime", 0.45)
    kit.grid("swish", "....x.......x...", "A2", vel=0.4)
    kit.grid("shaker_long", "....x.......x...", ("B", 4, 4), vel=0.35)
    return s
