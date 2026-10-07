"""Title theme - "Wasteland Harvest (Main Theme)".

D major, 84 BPM, 4/4, 40 bars (~114 s), seamless loop.

Form
  intro  4  pedal D (D | Gmaj7/D | D | A7sus4/D), pad + fingerpicking, music-box teaser
  A1     8  leitmotif on music box, Travis-picked guitar, half-note bass - quiet, hopeful
  A2     8  leitmotif on harmonica, the band joins (brushes, two-feel bass, e-piano answers)
  B      8  bridge in B minor over a lament bass (B A G F# E F# G A), melody in contrary
            motion, strings swell, chip arpeggio rises into a brush roll + reverse cymbal
  A3     8  climax: richer harmony (add9 / maj7 / Em9), strummed + picked guitars, music box
            doubles the lead an octave up
  outro  4  the "iv sigh" tag (Gmaj7 | Gm6 | D/F# | A7sus4) leading back to the intro
"""
from engine import P, Bass, Chip, EPiano, Pad, Plucked, Reed, Song, Struck

from .common import ARP_RING, ARP_UP, FOLK_STRUM, TRAVIS, folk_kit, lint, std_buses
from .leitmotif import LEITMOTIF, LEITMOTIF_CHORDS

BRIDGE = """
B4:4. C#5:8 D5:2 | E5:4. D5:8 C#5:2 | D5:4. E5:8 F#5:2 | A5:2. F#5:4 |
G5:4. F#5:8 E5:2 | F#5:4. E5:8 D5:2 | B4:4. C#5:8 D5:4 G5:4 | A5:2 G5:4 E5:4 |
"""

LEITMOTIF_ORN = """
A4:8 D5 F#5:4.^ E5:8 D5:4 | G5:4.^ F#5:8 E5:2 | B4:8 D5 F#5:4. G5:8 F#5:4 | E5:4. D5:8 C#5:2 |
A4:8 D5 F#5:4. E5:8 D5:4 | B5:4.^ A5:8 G5:2 | F#5:4. G5:8 E5:4 C#5:4 | D5:2. r:4 |
"""

COUNTER_A2 = """
r:1 | r:2 B4:8 A4 G4:4 | r:1 | r:2 E4:8 F#4 G4:4 |
F#4:1 | r:2 D5:4 Bb4:4 | r:1 | r:2 A4:8 B4 C#5 D5 |
"""

COUNTER_A3 = """
r:1 | r:2 D5:8 B4 G4:4 | r:1 | r:2 E4:8 F#4 G4:4 |
r:1 | r:2 D5:4 Bb4:4 | r:1 | r:1 |
"""

TEASER = "A5:8 D6 F#6:4. E6:8 D6:4 | E6:4. D6:8 A5:2 |"
OUTRO_TAG = "B5:2 A5:4 F#5:4 | G5:2. E5:4 | F#5:1 | E5:2 r:2 |"


def build():
    s = Song("title", bpm=84, key="D", seed=11, target_lufs=-15.0)
    s.meta.update(title="Wasteland Harvest (Main Theme)", key="D major",
                  use="Title screen / main menu")
    s.section("intro", 4, "D | Gmaj7/D | D | A7sus4/D")
    s.section("A1", 8, LEITMOTIF_CHORDS)
    s.section("A2", 8, LEITMOTIF_CHORDS)
    s.section("B", 8, "Bm | Bm/A | G | D/F# | Em7 | D/F# | G | A7sus4 A7")
    s.section("A3", 8, "Dadd9 | Gmaj7 | Bm7 | Asus4 A | D/F# | G Gm6 | Em9 A7 | D")
    s.section("outro", 4, "Gmaj7 | Gm6 | D/F# | A7sus4")
    std_buses(s, echo_beats=0.75)
    s.master["glue"] = {"ratio": 1.5}
    s.master["eq"] = [("peak", 300, -1.0, 0.9), ("highshelf", 7500, 1.5)]

    # ---------------------------------------------------------------- melody
    harp = s.part("harmonica", Reed("harmonica"), level=0.0, pan=0.05, ref=True,
                  sends={"hall": -9, "echo": -15}, human_ms=9)
    harp.melody(LEITMOTIF, "A2", vel=0.72)
    harp.melody(BRIDGE, "B", vel=0.74)
    harp.melody(LEITMOTIF_ORN, "A3", vel=0.85)
    harp.dyn("B", 0.92).dyn(("B", 4), 1.0).dyn(("B", 7), 1.06)

    mbox = s.part("musicbox", Struck("musicbox", decay=1.3), level=-2.0, pan=-0.12,
                  sends={"hall": -5, "echo": -12}, human_ms=6)
    mbox.melody(TEASER, ("intro", 2), vel=0.55)
    mbox.melody(LEITMOTIF, "A1", transpose=12, vel=0.68)
    mbox.melody(LEITMOTIF, "A3", transpose=12, vel=0.42)
    mbox.melody(OUTRO_TAG, "outro", vel=0.6)

    ep = s.part("epiano", EPiano(bark=0.7), level=-9.0, pan=0.25, sends={"hall": -9},
                post_fx=[("tremolo", {"rate": 4.2, "depth": 0.18})], human_ms=8)
    ep.melody(COUNTER_A2, "A2", vel=0.55)
    P.comp(ep, "B", "x...x...", vel=0.42, n=4, lo=52, hi=69, rootless=False, steps=2)
    ep.melody(COUNTER_A3, "A3", vel=0.6)
    lint(harp, mbox)

    # ---------------------------------------------------------------- guitars
    gtr = s.part("guitar", Plucked("guitar"), level=-6.5, pan=-0.3,
                 sends={"hall": -15, "room": -12}, human_ms=8)
    P.fingerpick(gtr, "intro", ARP_UP, vel=0.5)
    P.fingerpick(gtr, "A1", TRAVIS, vel=0.55)
    P.fingerpick(gtr, "A2", TRAVIS, vel=0.62)
    P.fingerpick(gtr, "B", ARP_RING, vel=0.6)
    P.fingerpick(gtr, "A3", TRAVIS, vel=0.58)
    P.fingerpick(gtr, "outro", ARP_UP, vel=0.52)
    gtr.gain("intro", -2).gain("A1", -1).gain("A2", 0).gain("A3", -1.5).gain("outro", -2)

    strum = s.part("strum", Plucked("guitar", t60_scale=0.8), level=-9.5, pan=0.42,
                   sends={"hall": -13, "room": -9}, human_ms=6)
    P.strum(strum, ("B", 6, 2), "D...D.DU", vel=0.55)
    P.strum(strum, "A3", FOLK_STRUM, vel=0.66)
    strum.gain(("B", 6), -4).gain(("B", 7, 3), 0)

    # ---------------------------------------------------------------- bass & pads
    bass = s.part("bass", Bass("round"), level=-8.0, pan=0.0, sends={"room": -20}, human_ms=5)
    P.bassline(bass, "intro", "1 - - -", vel=0.6)
    P.bassline(bass, "A1", "1 - 1 -", vel=0.62)
    P.bassline(bass, "A2", "1 - 5 -", vel=0.7)
    P.bassline(bass, "B", "1 - - 5", vel=0.7)
    P.bassline(bass, "A3", "1 - - 5 1 - 5 a", vel=0.78)
    P.bassline(bass, "outro", "1 - 1 -", vel=0.62)

    pad = s.part("pad", Pad("warm"), level=-13.0, sends={"hall": -8}, human_ms=0)
    P.pad(pad, ["intro", "A1", "A2"], n=4, lo=55, hi=72, vel=0.6)
    P.pad(pad, "outro", n=4, lo=55, hi=72, vel=0.6)
    pad.gain("intro", 0).gain("A1", -1).gain("A2", -3)

    strings = s.part("strings", Pad("strings"), level=-11.0, sends={"hall": -5}, human_ms=0)
    P.pad(strings, ["B", "A3"], n=4, lo=50, hi=71, vel=0.7)
    strings.gain("B", -8).gain(("B", 4), -3).gain(("B", 7), 0).gain(("A3", 7), 0).gain(("A3", 7, 3), -3)

    chip = s.part("chip", Chip(duty=0.25), level=-17.0, pan=0.3, sends={"hall": -8, "echo": -9},
                  human_ms=0)
    P.arp(chip, ("B", 4, 4), rate=0.25, order="up", n=4, lo=69, hi=88, vel=0.6, gate=0.6)
    P.arp(chip, "A3", rate=0.5, order="updown", n=4, lo=74, hi=91, vel=0.45, gate=0.5)
    chip.gain(("B", 4), -8).gain(("B", 7, 3), 0).gain(("A3", 0, 0), -4)

    # ---------------------------------------------------------------- percussion
    kit = s.part("drums", folk_kit(), level=-10.0, sends={"room": -8, "hall": -18}, human_ms=4)
    kit.grid("kick_soft", "X.......X.......", "A2", vel=0.75)
    kit.grid("brush", "....X.......X...", "A2", vel=0.7)
    kit.grid("shaker", "x.o.x.o.x.o.x.o.", "A2", vel=0.6)
    kit.grid("kick_soft", "X...............", ("B", 0, 7), vel=0.7)
    kit.grid("swish", "........X.......", ("B", 0, 7), vel=0.55)
    kit.grid("shaker", "x.o.x.o.x.o.x.o.", ("B", 0, 7), vel=0.5)
    kit.grid("brush", "o.o.o.o.x.x.X.XX", ("B", 7, 1), vel=0.7)
    kit.add(s.at(("A3", 0)) - 1.6 / s.spb, 2.0, "revcym", 0.55)
    kit.grid("kick_soft", "X.....x.X.......", "A3", vel=0.85)
    kit.grid("rim", "....X.......X...", "A3", vel=0.75)
    kit.grid("shaker", "xoxoxoxoxoxoxoxo", "A3", vel=0.5)
    kit.grid("tamb", "....x.......x...", ("A3", 4, 4), vel=0.55)
    kit.add(s.at("A3"), 1.0, "crash", 0.45)
    kit.add(s.at("outro"), 1.0, "swish", 0.4)
    return s
