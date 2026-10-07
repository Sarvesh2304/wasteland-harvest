"""Song / Part model: form (sections), chord chart, parts with events, mix settings.

Time inside scores is always in quarter-note beats from the start of the song (bar 0,
beat 0).  Bars are 0-indexed internally; score files use section names + bar offsets so
they rarely touch raw numbers.
"""
from __future__ import annotations

import zlib
from dataclasses import dataclass, field

import numpy as np

from .notation import parse_chart, parse_grid, parse_melody, grid_len
from .synth import SR


def stable_seed(*parts) -> int:
    return zlib.crc32("|".join(str(p) for p in parts).encode()) & 0x7FFFFFFF


@dataclass
class Ev:
    t: float                     # start (beats)
    d: float                     # duration (beats)
    p: object                    # list of midi pitches, or a drum name
    v: float = 0.8               # velocity 0..1
    flags: set = field(default_factory=set)
    kw: dict = field(default_factory=dict)


@dataclass
class Section:
    name: str
    start_bar: int
    bars: int


class Part:
    def __init__(self, song: "Song", name: str, inst, level: float = 0.0, pan: float = 0.0,
                 width: float = 1.0, sends: dict | None = None, fx: list | None = None,
                 human_ms: float = 7.0, human_vel: float = 0.05, swing=None,
                 ref: bool = False, offset_ms: float = 0.0, post_fx: list | None = None):
        self.song = song
        self.name = name
        self.inst = inst
        self.level = level            # target loudness relative to the reference part (LU)
        self.pan = pan
        self.width = width
        self.sends = dict(sends or {})  # bus name -> send level in dB
        self.fx = list(fx or [])      # insert effects (applied before panning)
        self.post_fx = list(post_fx or [])  # applied on the stereo signal after panning
        self.human_ms = human_ms
        self.human_vel = human_vel
        self.swing = swing            # None or (unit_beats, ratio) e.g. (0.5, 0.6)
        self.ref = ref
        self.offset_ms = offset_ms    # systematic push (-) / lay-back (+)
        self.events: list[Ev] = []
        self.gain_pts: list[tuple[float, float]] = []
        self.vel_pts: list[tuple[float, float]] = []

    # ---------------------------------------------------------------- raw events
    def add(self, t: float, d: float, p, v: float = 0.8, flags=None, **kw) -> Ev:
        if not isinstance(p, (list, str)):
            p = [p]
        e = Ev(t, d, p, v, set(flags or ()), kw)
        self.events.append(e)
        return e

    # ---------------------------------------------------------------- notation helpers
    def melody(self, text: str, at, transpose: int = 0, vel: float = 0.8, gate: float = 1.0,
               flags=(), check: bool = True, vel_jitter: bool = True) -> list[Ev]:
        """Place a melody.  `at` = bar index, (bar, beat) tuple, or 'section' / ('section', bar)."""
        t0 = self.song.at(at)
        bpb = self.song.bpb
        off = t0 % bpb
        notes = parse_melody(text, bpb, start_offset=off, check_bars=check,
                             where=f"{self.song.name}/{self.name}@{at}")
        out = []
        for n in notes:
            g = gate
            fl = set(flags) | n.flags
            if "stacc" in fl:
                g = min(g, 0.45)
            if "ten" in fl:
                g = 1.0
            e = self.add(t0 + n.t - off, n.d * g, [p + transpose for p in n.p],
                         max(0.05, min(1.0, vel + n.acc)), fl)
            e.kw["written_d"] = n.d
            out.append(e)
        return out

    def grid(self, drum: str, pattern: str, bars, vel: float = 0.8, steps: int = 4,
             flags=(), **kw) -> None:
        """Repeat a drum grid pattern over the given bars (pattern may span several bars)."""
        hits = parse_grid(pattern, steps)
        plen = grid_len(pattern, steps)
        bars = list(self.song.bar_list(bars))
        if not bars:
            return
        b0 = self.song.bar_beat(bars[0])
        spans = []
        # group contiguous bars into one block so multi-bar patterns cycle naturally
        block = [bars[0]]
        for b in bars[1:]:
            if b == block[-1] + 1:
                block.append(b)
            else:
                spans.append(block)
                block = [b]
        spans.append(block)
        for block in spans:
            start = self.song.bar_beat(block[0])
            end = self.song.bar_beat(block[-1] + 1)
            t = start
            while t < end - 1e-9:
                for off, v in hits:
                    if t + off < end - 1e-9:
                        self.add(t + off, 0.25, drum, v * vel, flags, **kw)
                t += plen
        _ = b0

    # ---------------------------------------------------------------- automation
    def gain(self, at, db_: float) -> "Part":
        self.gain_pts.append((self.song.at(at), db_))
        return self

    def dyn(self, at, mult: float) -> "Part":
        self.vel_pts.append((self.song.at(at), mult))
        return self


class Song:
    def __init__(self, name: str, bpm: float, bpb: float = 4, key: str = "C", seed: int = 1,
                 loop: bool = True, sr: int = SR, length_s: float | None = None,
                 target_lufs: float = -15.0, ref_lufs: float = -20.0):
        self.name = name
        self.bpm = float(bpm)
        self.bpb = float(bpb)
        self.key = key
        self.seed = seed
        self.loop = loop
        self.sr = sr
        self.length_s = length_s          # for non-looped stingers (total file length)
        self.sections: list[Section] = []
        self.chart: list[tuple[float, float, object]] = []
        self.parts: dict[str, Part] = {}
        self.buses: dict[str, dict] = {}
        self.master: dict = {"target_lufs": target_lufs, "ceiling_dbtp": -1.5, "eq": []}
        self.ref_lufs = ref_lufs
        self.n_bars = 0
        self.meta: dict = {}

    # ---------------------------------------------------------------- form
    def section(self, name: str, bars: int, chords: str | None = None) -> Section:
        s = Section(name, self.n_bars, bars)
        if any(x.name == name for x in self.sections):
            raise ValueError(f"duplicate section {name}")
        self.sections.append(s)
        if chords:
            chart = parse_chart(chords, self.bpb)
            if len(chart) != bars:
                if bars % len(chart) == 0:
                    chart = chart * (bars // len(chart))
                else:
                    raise ValueError(f"{self.name}/{name}: chart has {len(chart)} bars, "
                                     f"section has {bars}")
            for i, items in enumerate(chart):
                b0 = (s.start_bar + i) * self.bpb
                for off, d, c in items:
                    self.chart.append((b0 + off, d, c))
        self.n_bars += bars
        return s

    def sec(self, name: str) -> Section:
        for s in self.sections:
            if s.name == name:
                return s
        raise KeyError(f"{self.name}: no section {name!r}")

    def bar_beat(self, bar: int) -> float:
        return bar * self.bpb

    def at(self, at) -> float:
        """Resolve a position: int bar, (bar, beat), 'section', ('section', bar[, beat])."""
        if isinstance(at, (int, np.integer)):
            return float(at) * self.bpb
        if isinstance(at, float):
            return at
        if isinstance(at, str):
            return self.sec(at).start_bar * self.bpb
        if isinstance(at, tuple):
            if isinstance(at[0], str):
                s = self.sec(at[0])
                bar = at[1] if len(at) > 1 else 0
                beat = at[2] if len(at) > 2 else 0.0
                return (s.start_bar + bar) * self.bpb + beat
            return at[0] * self.bpb + at[1]
        raise ValueError(at)

    def bar_list(self, spec):
        """Bars from: 'section', ['secA', 'secB'], range, ('section', first, count)."""
        if isinstance(spec, str):
            s = self.sec(spec)
            return range(s.start_bar, s.start_bar + s.bars)
        if isinstance(spec, tuple) and isinstance(spec[0], str):
            s = self.sec(spec[0])
            first = spec[1] if len(spec) > 1 else 0
            cnt = spec[2] if len(spec) > 2 else s.bars - first
            return range(s.start_bar + first, s.start_bar + first + cnt)
        if isinstance(spec, (list, tuple)):
            out = []
            for x in spec:
                if isinstance(x, (int, np.integer)):
                    out.append(int(x))
                else:
                    out.extend(self.bar_list(x))
            return out
        return spec

    @property
    def total_beats(self) -> float:
        return self.n_bars * self.bpb

    @property
    def spb(self) -> float:
        """Seconds per beat."""
        return 60.0 / self.bpm

    @property
    def loop_samples(self) -> int:
        if not self.loop and self.length_s:
            return int(round(self.length_s * self.sr))
        return int(round(self.total_beats * self.spb * self.sr))

    def chord_at(self, beat: float):
        best = None
        for t, d, c in self.chart:
            if t <= beat + 1e-9 < t + d:
                return c
            if t <= beat + 1e-9:
                best = c
        if best is None and self.chart:
            return self.chart[0][2]
        return best

    def chords_in(self, b0: float, b1: float):
        out = []
        for t, d, c in self.chart:
            s, e = max(t, b0), min(t + d, b1)
            if e > s + 1e-9:
                out.append((s, e - s, c))
        return out

    def next_chord_after(self, beat: float):
        for t, d, c in self.chart:
            if t > beat + 1e-9:
                return c
        return self.chart[0][2] if (self.loop and self.chart) else None

    # ---------------------------------------------------------------- parts & buses
    def part(self, name: str, inst, **kw) -> Part:
        if name in self.parts:
            raise ValueError(f"duplicate part {name}")
        p = Part(self, name, inst, **kw)
        self.parts[name] = p
        return p

    def bus(self, name: str, **spec) -> None:
        self.buses[name] = spec

    def rng(self, *tag) -> np.random.Generator:
        return np.random.default_rng(stable_seed(self.name, self.seed, *tag))
