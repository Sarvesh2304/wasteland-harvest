"""Night - "Lamplight".  Calm, sleepy evening.

D-flat major, 63 BPM, 4/4, 24 bars (91.4 s), loop.

Slow-attack warm pad, harp arpeggios (Karplus-Strong, soft triangle pluck), a few long
e-piano notes, and in the last section the leitmotif itself - down a semitone, slowed by
the tempo into a lullaby - on music box: the day remembered as the town goes to sleep.

Form
  A   8  Dbmaj9 | Gbmaj7#11 | Bbm9 | Absus4 Ab | Dbmaj9 | Gbmaj7 | Ebm9 | Ab7sus4
  B   8  Gbmaj7 | Fm7 | Ebm7 | Dbmaj7/F | Gbmaj7 | Gbm6 | Dbmaj7/Ab | Ab7sus4 Ab7
  A2  8  leitmotif harmony in Db: Dbmaj9 | Gbmaj7 | Bbm9 | Absus4 Ab | Db/F | Gb Gbm6 | Ebm9 Ab7 | Dbmaj9
"""
from engine import P, Bass, EPiano, Kit, Pad, Plucked, Song, Struck

from .common import ARP_UP, lint, std_buses
from .leitmotif import LEITMOTIF

MEL_A = "F5:2. Eb5:4 | Db5:1 | F5:2 Db5:2 | Eb5:1 | Ab5:2. F5:4 | F5:2 Db5:2 | Gb5:2 F5:2 | Eb5:1 |"
MEL_B = "Bb5:2. Ab5:4 | Ab5:2 F5:2 | Gb5:2. Eb5:4 | F5:1 | Bb5:2 Db6:2 | A5:2. Gb5:4 | F5:1 | Eb5:2 C5:2 |"


def build():
    s = Song("night", bpm=63, key="Db", seed=61, target_lufs=-16.0)
    s.meta["mood"] = "calm, sleepy lullaby"
    s.meta.update(title="Lamplight", key="D-flat major", use="Evening / night at the settlement")
    s.section("A", 8, "Dbmaj9 | Gbmaj7#11 | Bbm9 | Absus4 Ab | Dbmaj9 | Gbmaj7 | Ebm9 | Ab7sus4")
    s.section("B", 8, "Gbmaj7 | Fm7 | Ebm7 | Dbmaj7/F | Gbmaj7 | Gbm6 | Dbmaj7/Ab | Ab7sus4 Ab7")
    s.section("A2", 8, "Dbmaj9 | Gbmaj7 | Bbm9 | Absus4 Ab | Db/F | Gb Gbm6 | Ebm9 Ab7 | Dbmaj9")
    std_buses(s, hall="night", echo_beats=None)

    ep = s.part("epiano", EPiano(bark=0.35, tine=0.6), level=0.0, pan=0.1, ref=True,
                sends={"hall": -6}, post_fx=[("tremolo", {"rate": 2.8, "depth": 0.14})], human_ms=14)
    ep.melody(MEL_A, "A", vel=0.5)
    ep.melody(MEL_B, "B", vel=0.54)
    P.pad(ep, "A2", n=3, lo=53, hi=65, vel=0.36, rhythm="x...............", steps=4)

    mbox = s.part("musicbox", Struck("musicbox", decay=1.5), level=-1.0, pan=-0.12,
                  sends={"hall": -3}, human_ms=12)
    mbox.melody(LEITMOTIF, "A2", transpose=11, vel=0.55)
    lint(ep, mbox)

    harp = s.part("harp", Plucked("harp"), level=-5.0, pan=-0.25, sends={"hall": -6}, human_ms=12)
    P.fingerpick(harp, ["A", "B", "A2"], ARP_UP, vel=0.5, lo=56, hi=77, bass_lo=37, bass_hi=49,
                 n_upper=3, ring_over=0.5)
    harp.gain("A", -1).gain("B", 0).gain("A2", -3)

    pad = s.part("pad", Pad("warm", attack=2.4, release=3.0, lp_scale=0.8), level=-9.0, width=1.3,
                 sends={"hall": -4}, human_ms=0, post_fx=[("chorus", {"rate": 0.2, "depth_ms": 3.0, "mix": 0.4})])
    P.pad(pad, ["A", "B", "A2"], n=4, lo=53, hi=70, vel=0.6)

    bass = s.part("bass", Bass("round", drive=0.6), level=-12.0, sends={"hall": -16}, human_ms=6)
    P.bassline(bass, ["A", "B", "A2"], "1 - 1 -", vel=0.5, lo=32, hi=46)

    kit = s.part("perc", Kit(), level=-20.0, sends={"hall": -2}, human_ms=8)
    kit.add(s.at(("A", 3, 2.5)), 1.0, "chime", 0.4)
    kit.add(s.at(("B", 6, 1.5)), 1.0, "chime", 0.35)
    return s
