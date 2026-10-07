"""Stinger - victory (successful extraction).  ~3 s one-shot, D major.

The leitmotif's opening gesture (A-D-F#) fired upward as a 16th-note flourish into a big
D major hit: strummed guitar, bass, glockenspiel triad, strings, timpani and a soft crash,
with a chiptune sparkle an octave above.  Not looped.
"""
from engine import P, Bass, Chip, Kit, Pad, Plucked, Reed, Song, Struck

from .common import std_buses


def build():
    s = Song("stinger_victory", bpm=120, key="D", seed=141, loop=False, length_s=3.0, target_lufs=-15.0)
    s.meta.update(title="Extraction!", key="D major", use="Stinger: successful extraction / expedition success")
    s.section("hit", 2, "Dadd9 | Dadd9")
    std_buses(s, echo_beats=0.5, echo_fb=0.3)

    lead = s.part("harmonica", Reed("harmonica"), level=0.0, pan=0.05, ref=True,
                  sends={"hall": -8, "echo": -14}, human_ms=0)
    lead.melody("A4:16 D5 F#5 A5 D6:2. | r:1 |", "hit", vel=0.9)
    chip = s.part("chip", Chip(duty=0.25, decay=0.4, sustain=0.5), level=-9.0, pan=0.3,
                  sends={"hall": -8, "echo": -6}, human_ms=0)
    chip.melody("A5:16 D6 F#6 A6 D7:4 A6:8 F#6 D7:4 | r:1 |", "hit", vel=0.7)
    glock = s.part("glock", Struck("glock"), level=-4.0, pan=-0.25, sends={"hall": -5}, human_ms=0)
    glock.melody("r:4 D6+F#6+A6:2. | r:1 |", "hit", vel=0.8)

    gtr = s.part("guitar", Plucked("guitar"), level=-5.0, pan=-0.35, sends={"hall": -10}, human_ms=0)
    P.strum(gtr, ("hit", 0, 1), "..D~~~~~", vel=0.9, spread_ms=30)
    gtr2 = s.part("guitar2", Plucked("guitar"), level=-6.0, pan=0.4, sends={"hall": -10}, human_ms=0)
    P.strum(gtr2, ("hit", 0, 1), "..D~~~~~", vel=0.85, spread_ms=38, lo=55, hi=79)

    bass = s.part("bass", Bass("round"), level=-9.0, human_ms=0)
    bass.add(s.at(("hit", 0, 1.0)), 1.5, 38, 0.85)
    strings = s.part("strings", Pad("strings", attack=0.25, release=1.4), level=-7.0, width=1.3,
                     sends={"hall": -5}, human_ms=0)
    strings.add(s.at(("hit", 0, 1.0)), 3.2, [57, 62, 66, 69, 74], 0.85)

    kit = s.part("drums", Kit(), level=-3.0, sends={"hall": -10, "room": -6}, human_ms=0)
    kit.grid("snare", "ooxX", ("hit", 0, 1), vel=0.7)
    kit.add(s.at(("hit", 0, 1.0)), 1.0, "kick", 1.0)
    kit.add(s.at(("hit", 0, 1.0)), 1.0, "timp", 0.7, f0=73.4)
    kit.add(s.at(("hit", 0, 1.0)), 1.0, "crash", 0.75)
    kit.add(s.at(("hit", 0, 1.0)), 1.0, "tamb_shake", 0.6)
    return s
