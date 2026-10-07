"""Combat - "Teeth in the Dark".  Driving and urgent, but not metal.

D minor (harmonic-minor A7, Neapolitan Eb), 140 BPM, 4/4, 40 bars (68.6 s), loop.

A synth-bass ostinato in 3+3+2 (tresillo) accents, taiko and toms locking to the same
grouping, brushed-to-full snare, tight hats, brassy synth stabs, and a chiptune lead (the
retro nod) doubled an octave down by a reed for body.

Form
  A   8  drums + bass ostinato                 Dm | Dm | Bb | C | Dm | Dm | Bb | A
  B   8  stabs enter                           Dm | Dm | Bb | C | Dm | Gm | Eb | A7
  C   8  lead melody                           Dm | Bb | Gm | A | Dm | Bb | Eb | A7
  D   4  breakdown: half-time taiko            Dm | Dm | Bb | A
  E   4  build: snare roll + riser             Gm | Eb | A | A7
  A2  8  everything                            Dm | Dm | Bb | C | Dm | Gm | Eb | A7
"""
from engine import P, Bass, Chip, Kit, Pad, Reed, Song, Swell

LEAD = """
A5:4. G5:8 F5:4 E5:4 | F5:4. D5:8 Bb4:2 | G5:4. A5:8 Bb5:4 D6:4 | C#6:2. A5:4 |
D6:4. C6:8 A5:4 F5:4 | G5:4. F5:8 D5:4 Bb4:4 | Eb5:4 G5:4 Bb5:4 Eb6:4 | C#6:4 A5:4 G5:4 E5:4 |
"""

STABS_A2 = """
D5:8*> r:8 r:8 D5:8*> r:8 r:8 F5:8*> r:8 | r:1 | D5:8*> r:8 r:8 D5:8*> r:8 r:8 Bb4:8*> r:8 | r:2 C5:8*> r:8 E5:4* |
D5:8*> r:8 r:8 F5:8*> r:8 r:8 A5:8*> r:8 | G5:4* r:4 Bb5:4* r:4 | Eb6:8*> r:8 r:8 Bb5:8*> r:8 r:8 G5:8*> r:8 | C#6:2 A5:4 E5:4 |
"""


def build():
    s = Song("combat", bpm=140, key="D", seed=101, target_lufs=-14.0)
    s.meta["mood"] = "driving, urgent"
    s.meta.update(title="Teeth in the Dark", key="D minor", use="Combat encounters in the ruins")
    s.section("A", 8, "Dm | Dm | Bb | C | Dm | Dm | Bb | A")
    s.section("B", 8, "Dm | Dm | Bb | C | Dm | Gm | Eb | A7")
    s.section("C", 8, "Dm | Bb | Gm | A | Dm | Bb | Eb | A7")
    s.section("D", 4, "Dm | Dm | Bb | A")
    s.section("E", 4, "Gm | Eb | A | A7")
    s.section("A2", 8, "Dm | Dm | Bb | C | Dm | Gm | Eb | A7")
    s.bus("hall", ir="hall", ret=-2.0, eq=[("hp", 250), ("lp", 10000)])
    s.bus("room", ir="room", ret=-1.0, eq=[("hp", 150), ("lp", 12000)])
    s.bus("echo", kind="echo", time=0.75 * s.spb, fb=0.3, lp=3500, hp=400, ret=-5.0)
    s.master["glue"] = {"ratio": 1.8, "above": 4.0}

    tres = [1.0, 0.62, 0.78, 1.0, 0.62, 0.78, 1.0, 0.7]
    bass = s.part("bass", Bass("synth", drive=1.6, sub=0.25), level=-5.5, sends={"room": -18}, human_ms=2,
                  fx=[("eq", [("hp", 38), ("peak", 250, -2.0, 1.0)])])
    P.bassline(bass, ["A", "B", "C", "A2"], "1 1 8 1 1 8 1 5", vel=0.85, lo=33, hi=50, gate=0.7, vels=tres)
    P.bassline(bass, "D", "1 - - - - - - -", vel=0.8, lo=33, hi=50, gate=0.95)
    P.bassline(bass, "E", "1 1 1 1 1 1 1 1", vel=0.8, lo=33, hi=50, gate=0.6,
               vels=[0.7, 0.6, 0.75, 0.6, 0.8, 0.65, 0.9, 0.7])
    bass.gain("E", -4).gain(("E", 3, 3), 0)

    lead = s.part("lead", Chip(duty=0.25, decay=0.6, sustain=0.6, vib=12.0, max_hz=6500), level=0.0,
                  pan=0.08, ref=True, sends={"hall": -10, "echo": -10}, human_ms=3)
    lead.melody(LEAD, "C", vel=0.85)
    lead.melody(STABS_A2, "A2", vel=0.9)
    body = s.part("lead_body", Reed("melodica"), level=-5.0, pan=-0.08, sends={"hall": -12}, human_ms=3)
    body.melody(LEAD, "C", transpose=-12, vel=0.75)
    body.melody(STABS_A2, "A2", transpose=-12, vel=0.75)
    lead.lint = True

    stab = s.part("stabs", Pad("strings", attack=0.006, release=0.16, lp_scale=1.6), level=-5.0,
                  width=1.3, sends={"hall": -9, "room": -10}, human_ms=2)
    P.comp(stab, "B", "x..x..x.", vel=0.85, n=4, lo=55, hi=72, rootless=False, steps=2, gate=0.45)
    P.comp(stab, "C", "x.......", vel=0.7, n=4, lo=52, hi=67, rootless=False, steps=2, gate=0.9)
    P.comp(stab, "A2", "x..x..x.", vel=0.85, n=4, lo=55, hi=72, rootless=False, steps=2, gate=0.45)

    arp = s.part("arp", Chip(duty=0.125, decay=0.15, sustain=0.3), level=-12.0, pan=-0.3,
                 sends={"echo": -6}, human_ms=0)
    P.arp(arp, ["C", "A2"], rate=0.25, order="up", n=4, lo=74, hi=91, vel=0.55, gate=0.5)
    arp.gain("C", -3).gain("A2", 0)

    drone = s.part("drone", Pad("dark"), level=-10.0, width=1.3, sends={"hall": -6}, human_ms=0)
    P.pad(drone, ["D", "E"], n=3, lo=45, hi=60, vel=0.7)

    rise = s.part("riser", Swell(lp=(300, 5000)), level=-6.0, width=1.4, sends={"hall": -6})
    rise.add(s.at("E"), 16.0, [50, 57, 62], 0.8)

    kit = s.part("drums", Kit(gains={"hat": 0.55, "shaker": 0.5},
                              tune={"taiko": {"f0": 74.0}, "taiko_hi": {"f0": 104.0}}), level=-5.0,
                 sends={"room": -6, "hall": -16}, human_ms=3,
                 fx=[("eq", [("hp", 40), ("lowshelf", 110, -6.0), ("peak", 3500, 2.0, 1.0)])])
    kit.grid("taiko", "X.....x.....x...", ["A", "B", "C", "A2"], vel=0.9)
    kit.grid("tom_lo", "..........x...x.", ("A", 3, 1), vel=0.7)
    kit.grid("tom_mid", "........x.x.x.xx", ("A", 7, 1), vel=0.75)
    kit.grid("shaker", "xoxoxoxoxoxoxoxo", "A", vel=0.6)
    kit.grid("snare", "....X.......X...", ["B", "C", "A2"], vel=0.8)
    kit.grid("snare", "..g......g.g....", ["B", "C", "A2"], vel=0.5)
    kit.grid("hat", "x.x.x.x.x.x.x.x.", ["B", "A2"], vel=0.7)
    kit.grid("hat", "xxxxxxxxxxxxxxxx", "C", vel=0.55)
    kit.grid("tom_hi", "............x.xx", [("B", 7, 1), ("C", 7, 1)], vel=0.75)
    kit.grid("taiko", "X...............", "D", vel=0.85)
    kit.grid("taiko_hi", "........X.......", "D", vel=0.6)
    kit.grid("snare", "x.x.x.x.x.x.x.x.", ("E", 0, 2), vel=0.5)
    kit.grid("snare", "xxxxxxxxxxxxxxxx", ("E", 2, 2), vel=0.65)
    kit.grid("taiko", "X.......X.......", "E", vel=0.8)
    kit.dyn("E", 0.6).dyn(("E", 3, 3.75), 1.15).dyn("A2", 1.0)
    kit.add(s.at("A2") - 1.6 / s.spb, 2.0, "revcym", 0.7)
    for sec in ("B", "C", "A2"):
        kit.add(s.at(sec), 1.0, "crash", 0.6)
    kit.add(s.at("D"), 1.0, "boom", 0.7)
    return s
