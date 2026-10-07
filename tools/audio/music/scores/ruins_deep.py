"""Ruins (deep) - "Below".  Deeper, darker, more oppressive levels.

C-sharp (locrian / phrygian colours over a C# pedal), 54 BPM, 4/4, 27 bars (120 s), loop.

A lower, wider drone (C#2 + G#2 with a faint C#1 sub), cluster pads (C# against D and
G - minor second and tritone), a slow heartbeat, metal groans and booms in an enormous
reverb, whistling high resonances, and in the last section the leitmotif's head bent into
an augmented, whole-tone shape on a flat music box.

Form
  A  9  drone, groans, distant heartbeat     C#5 | C#5 | D/C# | C#5 | C#5 | G/C# | D/C# | C#5 | C#5
  B  9  clusters swell, booms, pulse         D/C# | C#5 | G/C# | C#5 | D/C# | C#dim | G/C# | D/C# | C#5
  C  9  the corrupted lullaby, thinning out  C#5 | C#5 | D/C# | C#5 | C#5 | C#5 | G/C# | D/C# | C#5
"""
from engine import P, Bass, Kit, Pad, ResoNoise, Song, Struck, Swell

CORRUPT = "r:1 | G#4:8 C#5 F5:4. D#5:8 C#5:4 | r:1 | r:1 | r:2 G#4:8 C#5 F5:4 | A5:2. r:4 | r:1 | r:1 | r:1 |"


def build():
    s = Song("ruins_deep", bpm=54, key="C#", seed=91, target_lufs=-16.0)
    s.meta.update(title="Below", key="C-sharp locrian / phrygian", use="Deep ruins / bunkers / late zones")
    s.section("A", 9, "C#5 | C#5 | D/C# | C#5 | C#5 | G/C# | D/C# | C#5 | C#5")
    s.section("B", 9, "D/C# | C#5 | G/C# | C#5 | D/C# | C#dim | G/C# | D/C# | C#5")
    s.section("C", 9, "C#5 | C#5 | D/C# | C#5 | C#5 | C#5 | G/C# | D/C# | C#5")
    s.bus("abyss", ir="abyss", ret=0.0, eq=[("hp", 170), ("lp", 6000)])
    s.bus("echo", kind="echo", time=0.833, fb=0.5, lp=1800, hp=250, ret=-4.0)
    s.master["eq"] = [("peak", 230, -1.5, 0.8)]

    drone = s.part("drone", Pad("drone", det=20.0), level=-5.0, width=1.4,
                   sends={"abyss": -9}, human_ms=0, fx=[("eq", [("lowshelf", 140, -6.0)])],
                   post_fx=[("slow_filter", {"lo": 200, "hi": 800, "rate": 1 / 40})])
    for sec in ("A", "B", "C"):
        drone.add(s.at(sec), s.sec(sec).bars * 4 + 2.0, [37, 44], 0.8)

    sub = s.part("sub", Bass("sub", drive=0.0, release=3.0), level=-20.0, human_ms=0,
                 fx=[("eq", [("lp", 90)])])
    for sec in ("A", "B", "C"):
        sub.add(s.at(sec), s.sec(sec).bars * 4 - 0.5, [25], 0.6)

    pad = s.part("cluster", Pad("dark", attack=3.0, release=4.0), level=-2.0, width=1.3, ref=True,
                 sends={"abyss": -3}, human_ms=0, fx=[("eq", [("peak", 250, -2.0, 0.9)])])
    P.pad(pad, ["A", "B", "C"], n=3, lo=49, hi=63, vel=0.6, keep_fifth=True)
    pad.gain("A", -4).gain("B", 0).gain("C", -3)

    sw = s.part("swell", Swell(lp=(200, 1600), det=18.0), level=-3.0, width=1.5, sends={"abyss": -2})
    sw.add(s.at(("B", 1)), 7.5, [49, 50, 55], 0.7)
    sw.add(s.at(("B", 5)), 7.5, [49, 50, 56], 0.75)
    sw.add(s.at(("C", 6)), 7.0, [61, 62], 0.55)

    whistle = s.part("whistle", ResoNoise(t60=5.0, lp=2600, attack=4.0, release=5.0), level=-10.0,
                     pan=-0.3, sends={"abyss": 0}, human_ms=0)
    for at, beats, p in ((("A", 2), 14, [85]), (("B", 3), 12, [86]), (("C", 1), 16, [85, 91])):
        whistle.add(s.at(at), beats, p, 0.6)
    groan = s.part("groan", ResoNoise(t60=2.5, lp=700, attack=2.0, release=3.0), level=-6.0, pan=0.25,
                   sends={"abyss": -3}, human_ms=0)
    for at, beats, p in ((("A", 4), 10, [49, 55]), (("B", 2), 12, [43]), (("C", 3), 10, [50])):
        groan.add(s.at(at), beats, p, 0.7)

    mbox = s.part("broken", Struck("musicbox", decay=1.6), level=-1.0, pan=-0.1,
                  sends={"abyss": 0, "echo": -3}, human_ms=60)
    mbox.melody(CORRUPT, "C", transpose=12 - 0.42, vel=0.45)

    kit = s.part("perc", Kit(variants=6), level=-5.0, sends={"abyss": -2}, human_ms=15,
                 fx=[("eq", [("hp", 40), ("lowshelf", 110, -4.0), ("lp", 3500)])])
    kit.grid("heart", "x...............", ("A", 4, 5), vel=0.45)
    kit.grid("heart", "x.......x.......", "B", vel=0.55)
    kit.grid("heart", "x...............", ("C", 0, 6), vel=0.4)
    hits = [(("A", 0, 0.0), "boom", 0.5), (("A", 1, 2.0), "scrape", 0.55), (("A", 3, 1.5), "metal_lo", 0.45),
            (("A", 6, 3.0), "scrape", 0.5), (("A", 8, 1.0), "pipe", 0.3), (("B", 0, 0.0), "boom", 0.6),
            (("B", 2, 2.5), "metal_lo", 0.55), (("B", 4, 0.0), "boom", 0.55), (("B", 4, 2.0), "scrape", 0.6),
            (("B", 6, 1.0), "metal", 0.5), (("B", 8, 0.0), "taiko", 0.45), (("B", 8, 2.0), "taiko", 0.5),
            (("C", 0, 0.0), "boom", 0.45), (("C", 4, 1.0), "scrape", 0.45), (("C", 7, 2.0), "pipe", 0.3)]
    for at, name, v in hits:
        kit.add(s.at(at), 1.0, name, v)
    return s
