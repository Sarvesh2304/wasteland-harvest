"""Stinger - new day (waking up).  ~2.5 s one-shot, D major.

A morning flourish: music box runs up the D-major pentatonic, a harp rolls up underneath,
a soft Dmaj9 guitar strum and warm pad bloom, and a wind chime catches the light.  Not looped.
"""
from engine import P, Kit, Pad, Plucked, Song, Struck

from .common import std_buses


def build():
    s = Song("stinger_new_day", bpm=120, key="D", seed=161, loop=False, length_s=2.5, target_lufs=-16.0)
    s.meta["mood"] = "bright morning flourish"
    s.meta.update(title="Morning", key="D major", use="Stinger: waking up / new day")
    s.section("morning", 2, "Dmaj9 | Dmaj9")
    std_buses(s, echo_beats=0.5, echo_fb=0.25)

    mb = s.part("musicbox", Struck("musicbox"), level=0.0, pan=-0.15, ref=True,
                sends={"hall": -5, "echo": -12}, human_ms=4)
    mb.melody("D5:16 E5 F#5 A5 B5 D6 E6 F#6 A6:2 | r:1 |", "morning", vel=0.7)
    harp = s.part("harp", Plucked("harp"), level=-4.0, pan=0.25, sends={"hall": -6}, human_ms=3)
    harp.melody("r:4 D3:16 A3 D4 E4 F#4:2 | r:1 |", "morning", vel=0.6)
    gtr = s.part("guitar", Plucked("guitar"), level=-6.0, pan=0.35, sends={"hall": -9}, human_ms=0)
    P.strum(gtr, ("morning", 0, 1), "....d~~~", vel=0.6, spread_ms=45)
    pad = s.part("pad", Pad("warm", attack=0.6, release=1.2), level=-8.0, width=1.3,
                 sends={"hall": -5}, human_ms=0)
    pad.add(0.0, 3.0, [50, 57, 61, 64, 66], 0.7)
    kit = s.part("perc", Kit(), level=-12.0, sends={"hall": -3}, human_ms=0)
    kit.add(2.5, 1.0, "chime", 0.6, f0=2349.3)
    kit.add(0.0, 1.0, "shaker_long", 0.35)
    return s
