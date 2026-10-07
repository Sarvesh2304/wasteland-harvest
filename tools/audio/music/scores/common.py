"""Shared helpers for the scores: standard buses and common accompaniment figures."""
from engine import Kit

# Fingerpicking patterns (one token per 8th note in 4/4; see engine.patterns.fingerpick)
TRAVIS = "B3 2 A 1 B 3 A 2"          # thumb alternates bass, fingers on the off-beats
ARP_UP = "B 1 2 3 2 1 2 3"           # gentle rolling arpeggio
ARP_RING = "B 2 3 1 3 2 1 2"
WALTZ_ARP = "B 1 2 3 2 1"            # 3/4, 8ths

# Strum patterns (one char per 8th note)
FOLK_STRUM = "D.DU.UDU"
SOFT_STRUM = "D..U.UD."
BOOM_CHICK = "B.C.A.C."


def std_buses(song, hall: str = "hall", echo_beats: float | None = 0.75, echo_fb: float = 0.3,
              hall_ret: float = 0.0, room_ret: float = -2.0, echo_ret: float = -4.0):
    song.bus("hall", ir=hall, ret=hall_ret, eq=[("hp", 200), ("lp", 11000)])
    song.bus("room", ir="room", ret=room_ret, eq=[("hp", 160), ("lp", 12000)])
    if echo_beats:
        song.bus("echo", kind="echo", time=echo_beats * song.spb, fb=echo_fb, lp=3000, hp=350,
                 ret=echo_ret)


def folk_kit():
    return Kit(gains={"shaker": 0.5, "tamb": 0.45, "rim": 0.7, "wood": 0.6})


def lint(*parts):
    for p in parts:
        p.lint = True
