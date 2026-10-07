"""Synthesised percussion: folk kit (felt kick, brushes, shaker, rim, wood block,
tambourine, claps, stomp), combat kit (toms, taiko, snare, hats) and ruins metals
(distant pipes, sheet-metal hits, scrapes, booms, heartbeat).

Every voice has round-robin variants (different noise seeds) so repeated hits never sound
machine-identical; velocity changes both level and brightness.
"""
from __future__ import annotations

import math

import numpy as np

from .instruments import Instrument, _LRU
from .synth import (SR, biquad, butter, onepole_lp, place, ramp_cos, sosf, pan_gains)


def _t(n, sr):
    return np.arange(n) / sr


def _env(n, sr, attack, tau):
    t = _t(n, sr)
    e = np.exp(-t / tau)
    a = max(1, int(attack * sr))
    e[:a] *= ramp_cos(a)
    return e


def _sweep_sine(f_fn, n, sr):
    t = _t(n, sr)
    f = f_fn(t)
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def kick(rng, sr, tune=1.0, decay=0.16, click=0.12):
    n = int(0.55 * sr)
    t = _t(n, sr)
    body = _sweep_sine(lambda t: tune * (47 + 80 * np.exp(-t / 0.028)), n, sr)
    y = body * _env(n, sr, 0.0015, decay) * 1.0
    y += 0.25 * _sweep_sine(lambda t: tune * (95 + 60 * np.exp(-t / 0.02)), n, sr) * _env(n, sr, 0.001, 0.05)
    k = int(0.006 * sr)
    cl = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.0012 * sr))
    y[:k] += onepole_lp(cl, 3500, sr) * click
    return np.tanh(1.4 * y) / math.tanh(1.4)


def stomp(rng, sr, tune=1.0):
    n = int(0.35 * sr)
    y = _sweep_sine(lambda t: tune * (58 + 50 * np.exp(-t / 0.02)), n, sr) * _env(n, sr, 0.002, 0.07)
    nz = sosf(rng.standard_normal(n), butter("bp", (180 * tune, 900 * tune), 2, sr)) * _env(n, sr, 0.001, 0.025)
    return y + 0.9 * nz


def brush(rng, sr, tone=1.0):
    n = int(0.35 * sr)
    nz = sosf(rng.standard_normal(n), butter("bp", (1800 * tone, 9000), 2, sr))
    y = nz * _env(n, sr, 0.003, 0.065)
    y += 0.12 * np.sin(2 * np.pi * 190 * _t(n, sr)) * _env(n, sr, 0.001, 0.03)
    return y


def swish(rng, sr, length=0.42):
    n = int(length * sr)
    t = _t(n, sr)
    nz = sosf(rng.standard_normal(n), butter("bp", (1500, 7000), 2, sr))
    e = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.5
    return nz * e * 0.6


def snare(rng, sr, tune=1.0, snappy=1.0):
    n = int(0.4 * sr)
    t = _t(n, sr)
    nz = sosf(rng.standard_normal(n), butter("bp", (1200, 9000), 2, sr)) * _env(n, sr, 0.001, 0.11) * snappy
    tone = (np.sin(2 * np.pi * 185 * tune * t) * _env(n, sr, 0.001, 0.05)
            + 0.5 * np.sin(2 * np.pi * 330 * tune * t) * _env(n, sr, 0.001, 0.03))
    return 0.8 * nz + 0.7 * tone


def rim(rng, sr, tune=1.0):
    n = int(0.12 * sr)
    t = _t(n, sr)
    y = (np.sin(2 * np.pi * 520 * tune * t) * _env(n, sr, 0.0005, 0.016)
         + 0.6 * np.sin(2 * np.pi * 1650 * tune * t) * _env(n, sr, 0.0005, 0.008))
    nz = sosf(rng.standard_normal(n), butter("bp", (2000, 6000), 2, sr)) * _env(n, sr, 0.0003, 0.004)
    return y + 0.8 * nz


def wood(rng, sr, tune=1.0):
    n = int(0.15 * sr)
    t = _t(n, sr)
    f = 980 * tune
    y = (np.sin(2 * np.pi * f * t) * _env(n, sr, 0.0005, 0.035)
         + 0.35 * np.sin(2 * np.pi * f * 2.71 * t) * _env(n, sr, 0.0005, 0.012))
    nz = sosf(rng.standard_normal(n), butter("bp", (1500, 5000), 2, sr)) * _env(n, sr, 0.0003, 0.003)
    return y + 0.5 * nz


def shaker(rng, sr, length=1.0):
    n = int(0.16 * sr * length)
    nz = sosf(rng.standard_normal(n), butter("bp", (4500, 12000), 2, sr))
    t = _t(n, sr)
    a = 0.012 * length
    e = np.clip(t / a, 0, 1) ** 1.5 * np.exp(-np.maximum(t - a, 0) / (0.045 * length))
    return nz * e


def tamb(rng, sr, shake=False):
    n = int(0.35 * sr)
    t = _t(n, sr)
    y = np.zeros(n)
    for _ in range(14):
        f = rng.uniform(4800, 11500)
        y += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.3)) * np.exp(-t / rng.uniform(0.05, 0.13))
    y /= 6.0
    nz = sosf(rng.standard_normal(n), butter("hp", 7000, 2, sr)) * _env(n, sr, 0.001, 0.05)
    out = y + 0.6 * nz
    if shake:
        out *= np.clip(t / 0.02, 0, 1)
    else:
        out[: int(0.0008 * sr)] *= ramp_cos(int(0.0008 * sr))
    return out


def clap(rng, sr):
    n = int(0.3 * sr)
    y = np.zeros(n)
    for i, off in enumerate((0.0, 0.009, 0.019, 0.03)):
        k0 = int(off * sr)
        m = n - k0
        tau = 0.006 if i < 3 else 0.075
        b = sosf(rng.standard_normal(m), butter("bp", (900, 3000), 2, sr)) * _env(m, sr, 0.0005, tau)
        y[k0:] += b * (0.8 if i < 3 else 1.0)
    return y


def hat(rng, sr, open_=False):
    n = int((0.5 if open_ else 0.12) * sr)
    t = _t(n, sr)
    y = np.zeros(n)
    for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0):
        y += np.sign(np.sin(2 * np.pi * f * 1.7 * t + rng.uniform(0, 6.3)))
    y = sosf(y, butter("bp", (7000, 13000), 2, sr))
    nz = sosf(rng.standard_normal(n), butter("hp", 8000, 2, sr))
    out = (0.5 * y + 0.5 * nz) * _env(n, sr, 0.0005, 0.25 if open_ else 0.03)
    return out


def tom(rng, sr, f0=110.0, decay=0.28):
    n = int(0.8 * sr)
    y = _sweep_sine(lambda t: f0 * (1 + 0.55 * np.exp(-t / 0.045)), n, sr) * _env(n, sr, 0.001, decay)
    nz = onepole_lp(rng.standard_normal(n), 2000, sr) * _env(n, sr, 0.0005, 0.018)
    return np.tanh(1.3 * (y + 0.35 * nz))


def taiko(rng, sr, f0=60.0):
    n = int(1.4 * sr)
    y = _sweep_sine(lambda t: f0 * (1 + 0.6 * np.exp(-t / 0.05)), n, sr) * _env(n, sr, 0.002, 0.42)
    y += 0.4 * _sweep_sine(lambda t: f0 * 1.52 * (1 + 0.4 * np.exp(-t / 0.04)), n, sr) * _env(n, sr, 0.001, 0.18)
    nz = onepole_lp(onepole_lp(rng.standard_normal(n), 1300, sr), 1800, sr) * _env(n, sr, 0.0008, 0.04)
    return np.tanh(1.2 * (y + 0.6 * nz))


def boom(rng, sr, f0=42.0, decay=1.1):
    n = int(3.2 * sr)
    y = _sweep_sine(lambda t: f0 * (1 + 0.8 * np.exp(-t / 0.09)), n, sr) * _env(n, sr, 0.004, decay)
    rum = onepole_lp(onepole_lp(rng.standard_normal(n), 160, sr), 220, sr) * _env(n, sr, 0.01, decay * 0.8)
    return y + 2.5 * rum


def heart(rng, sr):
    n = int(0.75 * sr)
    y = np.zeros(n)
    for off, a in ((0.0, 1.0), (0.26, 0.7)):
        k0 = int(off * sr)
        m = n - k0
        y[k0:] += a * _sweep_sine(lambda t: 52 * (1 + 0.5 * np.exp(-t / 0.025)), m, sr) * _env(m, sr, 0.004, 0.08)
    return y


def metal(rng, sr, f0=None, decay=1.6, bright=1.0):
    """Struck sheet metal / girder: dense inharmonic partials."""
    n = int(decay * 2.4 * sr)
    t = _t(n, sr)
    y = np.zeros(n)
    base = f0 or rng.uniform(180, 420)
    for _ in range(18):
        f = base * rng.uniform(1.0, 9.0) ** 1.15
        if f > 9000 * bright:
            continue
        a = 1.0 / math.sqrt(f / base)
        y += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.3)) * np.exp(-t / (decay * rng.uniform(0.25, 1.0) * (base / f) ** 0.3))
    nz = sosf(rng.standard_normal(n), butter("bp", (600, 5000), 2, sr)) * _env(n, sr, 0.0005, 0.02)
    y = y / 4.0 + 0.4 * nz
    y[: int(0.001 * sr)] *= ramp_cos(int(0.001 * sr))
    return y


def pipe(rng, sr, f0=None, decay=2.0):
    n = int(decay * 1.6 * sr)
    t = _t(n, sr)
    f = f0 or rng.uniform(380, 900)
    y = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 1.0), (2.756, 0.5, 0.6), (5.404, 0.3, 0.35), (8.933, 0.15, 0.2)):
        if f * r < 15000:
            y += a * np.sin(2 * np.pi * f * r * t * (1 + rng.normal(0, 0.002))) * np.exp(-t / (decay * d * 0.5))
    y[: int(0.0008 * sr)] *= ramp_cos(int(0.0008 * sr))
    return y


def anvil(rng, sr, f0=1700.0):
    n = int(1.2 * sr)
    t = _t(n, sr)
    y = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 0.5), (2.13, 0.6, 0.3), (3.71, 0.35, 0.18), (5.2, 0.2, 0.1)):
        y += a * np.sin(2 * np.pi * f0 * r * t) * np.exp(-t / d)
    y[: int(0.0005 * sr)] *= ramp_cos(int(0.0005 * sr))
    return y


def scrape(rng, sr, length=2.2, f0=None):
    """Bowed / scraped metal: slow resonant noise with a few drifting partials."""
    n = int(length * sr)
    t = _t(n, sr)
    e = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 2
    nz = rng.standard_normal(n)
    y = np.zeros(n)
    base = f0 or rng.uniform(300, 700)
    for r in (1.0, 1.41, 2.23, 3.1):
        f = base * r * (1 + 0.02 * np.sin(2 * np.pi * rng.uniform(0.2, 0.6) * t))
        y += np.sin(2 * np.pi * np.cumsum(f) / sr) * rng.uniform(0.3, 1.0)
    rough = 0.5 + 0.5 * onepole_lp(np.abs(nz), 30, sr) / 0.8
    bp = sosf(nz, biquad("bandpass", base * 2.0, 6.0, sr=sr)) * 2.0
    return (0.3 * y * rough + bp) * e * 0.5


def crash(rng, sr, decay=1.6):
    n = int(decay * 2.2 * sr)
    t = _t(n, sr)
    nz = sosf(rng.standard_normal(n), butter("hp", 3500, 2, sr))
    y = np.zeros(n)
    for _ in range(20):
        f = rng.uniform(3000, 12000)
        y += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.3)) * np.exp(-t / rng.uniform(0.3, decay))
    out = (0.7 * nz + 0.08 * y) * _env(n, sr, 0.001, decay * 0.5)
    return out


def rev_cymbal(rng, sr, length=1.6):
    c = crash(rng, sr, decay=length)
    n = int(length * sr)
    c = c[:n][::-1].copy()
    c[-int(0.004 * sr):] *= ramp_cos(int(0.004 * sr))[::-1]
    return c


def timp(rng, sr, f0=73.4):
    n = int(2.8 * sr)
    t = _t(n, sr)
    y = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 1.4), (1.504, 0.55, 0.9), (1.742, 0.3, 0.7), (2.0, 0.35, 0.6), (2.44, 0.15, 0.45)):
        y += a * np.sin(2 * np.pi * f0 * r * t + rng.uniform(0, 6.3)) * np.exp(-t / d)
    nz = onepole_lp(rng.standard_normal(n), 900, sr) * _env(n, sr, 0.0005, 0.02)
    y = y * _env(n, sr, 0.003, 9.0) + 0.5 * nz
    return y


def chime(rng, sr, f0=None):
    n = int(3.0 * sr)
    t = _t(n, sr)
    f = f0 or rng.choice([1567.98, 1760.0, 1975.5, 2349.3, 2637.0])
    y = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 1.5), (2.76, 0.3, 0.6), (5.4, 0.12, 0.25)):
        y += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6.3)) * np.exp(-t / d)
    y[: int(0.001 * sr)] *= ramp_cos(int(0.001 * sr))
    return y


VOICES = {
    # name: (fn, default pan, kwargs)
    "kick": (kick, 0.0, {}),
    "kick_soft": (kick, 0.0, {"decay": 0.12, "click": 0.05}),
    "stomp": (stomp, 0.0, {}),
    "brush": (brush, 0.1, {}),
    "brush_lo": (brush, 0.1, {"tone": 0.7}),
    "swish": (swish, 0.15, {}),
    "snare": (snare, 0.05, {}),
    "rim": (rim, -0.15, {}),
    "wood": (wood, -0.35, {}),
    "wood_hi": (wood, -0.35, {"tune": 1.35}),
    "wood_lo": (wood, -0.3, {"tune": 0.72}),
    "shaker": (shaker, 0.4, {}),
    "shaker_long": (shaker, 0.4, {"length": 1.8}),
    "tamb": (tamb, 0.35, {}),
    "tamb_shake": (tamb, 0.35, {"shake": True}),
    "clap": (clap, -0.1, {}),
    "hat": (hat, 0.3, {}),
    "ohat": (hat, 0.3, {"open_": True}),
    "tom_lo": (tom, -0.3, {"f0": 82.0, "decay": 0.35}),
    "tom_mid": (tom, 0.0, {"f0": 112.0, "decay": 0.3}),
    "tom_hi": (tom, 0.3, {"f0": 150.0, "decay": 0.25}),
    "taiko": (taiko, 0.0, {}),
    "taiko_hi": (taiko, 0.2, {"f0": 88.0}),
    "boom": (boom, 0.0, {}),
    "heart": (heart, 0.0, {}),
    "metal": (metal, 0.0, {}),
    "metal_lo": (metal, 0.0, {"decay": 2.4}),
    "pipe": (pipe, 0.0, {}),
    "anvil": (anvil, 0.2, {}),
    "scrape": (scrape, 0.0, {}),
    "crash": (crash, -0.2, {}),
    "revcym": (rev_cymbal, 0.0, {}),
    "timp": (timp, 0.0, {}),
    "chime": (chime, 0.3, {}),
}


class Kit(Instrument):
    """Drum kit instrument: event p = voice name; kw may carry pan/tune overrides."""
    stereo = True

    def __init__(self, variants: int = 4, pans: dict | None = None, gains: dict | None = None,
                 tune: dict | None = None):
        self.variants = variants
        self.pans = pans or {}
        self.gains = gains or {}
        self.tune = tune or {}
        self.cache = _LRU(300)
        self.name = "kit"

    def hit(self, name, var, kw, sr):
        fn, _pan, dkw = VOICES[name]
        args = dict(dkw)
        args.update(self.tune.get(name, {}))
        for k in ("f0", "tune", "decay", "length", "tone"):
            if k in kw:
                args[k] = kw[k]
        key = (name, var, tuple(sorted(args.items())))
        y = self.cache.get(key)
        if y is None:
            rng = np.random.default_rng(sum(ord(c) * (i + 1) for i, c in enumerate(name)) * 131 + var * 7717 + 13)
            y = fn(rng, sr, **args).astype(np.float32)
            y /= (np.max(np.abs(y)) + 1e-9)
            self.cache.put(key, y)
        return y

    def render(self, events, n, sr, rng):
        buf = np.zeros((2, n))
        for ev in events:
            name = ev.p if isinstance(ev.p, str) else ev.p[0]
            var = int(rng.integers(self.variants))
            y = self.hit(name, var, ev.kw, sr).astype(np.float64)
            v = max(0.0, min(1.2, ev.v))
            if v < 0.95:
                y = v * y + (1 - v) * onepole_lp(y, 1500 + 6000 * v, sr)
            y = y * v ** 1.6 * self.gains.get(name, 1.0)
            pan = ev.kw.get("pan", self.pans.get(name, VOICES[name][1])) + rng.normal(0, 0.04)
            gl, gr = pan_gains(max(-1, min(1, pan)))
            place(buf, np.vstack((y * gl, y * gr)), int(round(ev.s * sr)))
        return buf
