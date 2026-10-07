"""Stinger - death (lost in the ruins).  ~3 s one-shot, D minor.

A soft low thud and a felt-piano D octave, a dark D-minor chord that sinks to B-flat minor
over the D, and the leitmotif's opening - the same broken, flat music-box version heard in
the ruins - played once, slowing, into a cave reverb.  Sombre, not harsh.  Not looped.
"""
from engine import Kit, Pad, Piano, Song, Struck


def build():
    s = Song("stinger_death", bpm=60, key="D", seed=151, loop=False, length_s=3.2, target_lufs=-16.0)
    s.meta["mood"] = "sombre, falling"
    s.meta.update(title="Lost", key="D minor", use="Stinger: player death on an expedition")
    s.section("fall", 1, "Dm . Bbm/D .")
    s.bus("cave", ir="cave", ret=-2.0, eq=[("hp", 180), ("lp", 6000)])

    mb = s.part("broken", Struck("musicbox", decay=1.3), level=0.0, pan=0.1, ref=True,
                sends={"cave": -4}, human_ms=0)
    # each note a little later than the last: the music box winding down
    for t, p, v in ((0.0, 69, 0.72), (0.27, 74, 0.68), (0.58, 77, 0.66), (1.02, 75, 0.6), (1.6, 74, 0.55)):
        mb.add(t, 1.2, [p + 12 - 0.35], v)

    pno = s.part("piano", Piano(felt=1.4), level=-5.0, sends={"cave": -8}, human_ms=0)
    pno.add(0.0, 2.6, [38, 50], 0.6)
    pno.add(1.6, 1.4, [53, 58, 61], 0.32)

    pad = s.part("pad", Pad("dark", attack=0.08, release=1.2, lp_scale=1.3), level=-9.0, width=1.3,
                 sends={"cave": -6}, human_ms=0, fx=[("eq", [("hp", 120)])])
    pad.add(0.0, 1.5, [50, 53, 57], 0.7)
    pad.add(1.5, 1.2, [49, 53, 58], 0.6)

    kit = s.part("perc", Kit(), level=-10.0, sends={"cave": -6}, human_ms=0,
                 fx=[("eq", [("hp", 45), ("lowshelf", 120, -3.0)])])
    kit.add(0.0, 1.0, "kick", 0.7)
    return s
