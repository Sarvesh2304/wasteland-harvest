"""Autumn - "Amber Autumn".  Golden, nostalgic: the richest harmony of the four seasons.

B-flat major, 3/4 waltz, 100 BPM, 64 bars (115.2 s), loop.

Musette accordion over a nylon-guitar waltz, upright bass, e-piano, strings and celesta.
Harmony leans on maj7 / m7 colour, IV -> iv (Ebmaj7 -> Ebm6), secondary dominants
(G7 -> Cm7), a G-minor bridge over a descending bass, a passing diminished chord and a
chromatic-mediant Gbmaj7 that holds the melody's B-flat as a common tone.

Form
  intro  8  celesta motif over the waltz
  A     16  accordion theme (two 8-bar phrases, IV-iv sighs, ii-V-I)
  B     16  G-minor bridge, lament bass G F Eb D, Edim7, Gbmaj7 -> F7
  A2    16  theme returns, higher second phrase, strings + celesta shimmer
  coda   8  Ebmaj7 Ebm6 ... settles on F7sus4 to loop
"""
from engine import P, EPiano, Pad, Plucked, Reed, Song, Struck

from .common import WALTZ_ARP, folk_kit, lint, std_buses

A_CH = ("Bbmaj7 | Dm7 | Ebmaj7 | Ebm6 | Dm7 | G7 | Cm7 | F7 | "
        "Bbmaj7 | Dm7 | Ebmaj7 | Ebm6 | Dm7 . G7 | Cm7 . F7 | Bb6 | F7sus4 . F7")

THEME_A = """
D5:4 F5:4 A5:4 | A5:2 G5:4 | G5:4. F5:8 Eb5:4 | Gb5:2.^ | F5:4 D5:4 A4:4 | B4:2 D5:4 | Eb5:4. D5:8 C5:4 | A4:2. |
D5:4 F5:4 A5:4 | C6:2 A5:4 | Bb5:4. G5:8 Eb5:4 | Gb5:4 F5:4 Eb5:4 | D5:2 B4:4 | Eb5:4 D5:4 C5:4 | Bb4:2. | F5:2 Eb5:4 |
"""

THEME_A2 = """
D5:4 F5:4 A5:4 | A5:2 G5:4 | G5:4. F5:8 Eb5:4 | Gb5:2.^ | F5:4 D5:4 A4:4 | B4:2 D5:4 | Eb5:4. D5:8 C5:4 | A4:2. |
D5:4 F5:4 A5:4 | D6:2^ C6:4 | Bb5:4. G5:8 Eb5:4 | Gb5:2 Eb5:4 | F5:2 D5:4 | Eb5:2 C5:4 | D5:2. | C5:2 A4:4 |
"""

THEME_B = """
D5:4 G5:4 A5:4 | Bb5:2 A5:4 | G5:4. F5:8 Eb5:4 | F#5:2. | G5:4 Bb5:4 D6:4 | C6:2 Bb5:4 | Eb5:4. D5:8 C5:4 | D5:2. |
Bb4:4 Eb5:4 G5:4 | Bb5:2 G5:4 | F5:4. D5:8 Bb4:4 | B4:2 D5:4 | Eb5:4 G5:4 Bb5:4 | Bb5:2.^ | C6:4 Bb5:4 F5:4 | Eb5:4 C5:4 A4:4 |
"""

CODA = "G5:2. | Gb5:2. | F5:2. | D5:2 Bb4:4 | Eb5:2. | F5:2 Eb5:4 | D5:2. | C5:2. |"

INTRO_CEL = "D6:2. | C6:2 A5:4 | Bb5:2. | C6:2. | D6:2. | C6:2 A5:4 | Bb5:4 A5:4 G5:4 | F5:2. |"


def build():
    s = Song("autumn", bpm=100, bpb=3, key="Bb", seed=41, target_lufs=-15.0)
    s.meta["mood"] = "golden, nostalgic waltz"
    s.meta.update(title="Amber Autumn", key="B-flat major", use="Farm / town daytime, autumn")
    s.section("intro", 8, "Bbmaj7 | Gm7 | Ebmaj7 | F7sus4 | Bbmaj7 | Gm7 | Cm7 | F7sus4 . F7")
    s.section("A", 16, A_CH)
    s.section("B", 16, "Gm | Gm/F | Ebmaj7 | D7 | Gm | Gm/F | Cm7 | F7 | "
                       "Ebmaj7 | Edim7 | Bb/F | G7 | Cm7 | Gbmaj7 | F7sus4 | F7")
    s.section("A2", 16, A_CH)
    s.section("coda", 8, "Ebmaj7 | Ebm6 | Bbmaj7/D | Gm7 | Cm9 | F7sus4 | Bbmaj7 | F7sus4")
    std_buses(s, echo_beats=None)
    s.master["glue"] = {"ratio": 1.5}

    acc = s.part("accordion", Reed("accordion"), level=0.0, pan=-0.05, ref=True,
                 sends={"hall": -9}, human_ms=10)
    acc.melody(THEME_A, "A", vel=0.7)
    acc.melody(THEME_B, "B", vel=0.74)
    acc.melody(THEME_A2, "A2", vel=0.8)
    acc.melody(CODA, "coda", vel=0.62)
    acc.dyn(("B", 8), 0.95).dyn(("B", 13), 1.05)

    cel = s.part("celesta", Struck("celesta", decay=1.2), level=-5.0, pan=0.3,
                 sends={"hall": -5}, human_ms=6)
    cel.melody(INTRO_CEL, "intro", vel=0.62)
    P.arp(cel, ("A2", 8, 8), rate=0.5, order="updown", n=4, lo=74, hi=91, vel=0.32, gate=0.9)
    lint(acc, cel)

    gtr = s.part("guitar", Plucked("nylon"), level=-6.0, pan=-0.3, sends={"hall": -14, "room": -11},
                 human_ms=9)
    P.fingerpick(gtr, ["intro", "A"], WALTZ_ARP, vel=0.6)
    P.waltz(gtr, "B", vel=0.62, pattern="B C C")
    P.fingerpick(gtr, ["A2", "coda"], WALTZ_ARP, vel=0.62)
    gtr.gain("coda", -1.5)

    bass = s.part("bass", Plucked("upright"), level=-8.0, sends={"room": -16}, human_ms=6)
    P.bassline(bass, ["A"], "1 - -", vel=0.72, lo=31, hi=50)
    P.bassline(bass, ["B"], "1 - 5", vel=0.74, lo=31, hi=50)
    P.bassline(bass, ["A2"], "1 - 5", vel=0.76, lo=31, hi=50)
    P.bassline(bass, "coda", "1 - -", vel=0.66, lo=31, hi=50)

    ep = s.part("epiano", EPiano(bark=0.6), level=-11.0, pan=0.28, sends={"hall": -9},
                post_fx=[("tremolo", {"rate": 3.6, "depth": 0.15})], human_ms=8)
    P.comp(ep, ["B", "A2"], ". . x . x .", vel=0.5, n=4, lo=55, hi=72, rootless=True, steps=2)

    strings = s.part("strings", Pad("strings"), level=-11.0, sends={"hall": -5}, human_ms=0)
    P.pad(strings, ["B", "A2", "coda"], n=4, lo=50, hi=70, vel=0.65)
    strings.gain("B", -4).gain(("B", 8), -1).gain("A2", -2).gain("coda", 0)

    kit = s.part("drums", folk_kit(), level=-14.0, sends={"room": -8, "hall": -16}, human_ms=5)
    kit.grid("swish", "x...........", ["B", "A2"], vel=0.5)
    kit.grid("brush", "....o...o...", ["A", "B", "A2"], vel=0.6)
    kit.grid("kick_soft", "x...........", ["B", "A2"], vel=0.55)
    return s
