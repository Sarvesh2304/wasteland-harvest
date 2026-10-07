"""Synthesised instruments.

Each instrument renders a list of resolved events (start/end in seconds) into a buffer.
Per-note instruments with a natural decay (strings, e-piano, mallets, piano) cache one
full-length render per (pitch, variant) and apply velocity/brightness and the note-off
release per use, which keeps whole-soundtrack renders fast.

Melodic leads (harmonica, accordion, whistle, slide guitar) are rendered *per phrase*:
consecutive notes are one continuous oscillator with glides, tonguing dips, delayed
vibrato and breath-pressure brightness, which is what makes a wind/slide line sound played
rather than sequenced.
"""
from __future__ import annotations

import math
from collections import OrderedDict

import numpy as np
from scipy import signal

from .synth import (SR, additive, biquad, butter, dc_block, onepole_lp, place, ramp_cos,
                    release_tail, saw_blep, sosf, lagrange_frac)
from .theory import hz


def _interp_key(midi: float, table) -> float:
    xs = [a for a, _ in table]
    ys = [b for _, b in table]
    return float(np.interp(midi, xs, ys))


def vel_amp(v: float, gamma: float = 1.5) -> float:
    return max(0.0, v) ** gamma


class Instrument:
    stereo = False
    default_fx: list = []
    name = "inst"

    def render(self, events, n: int, sr: int, rng: np.random.Generator) -> np.ndarray:
        raise NotImplementedError


class _LRU:
    def __init__(self, cap=400):
        self.cap = cap
        self.d = OrderedDict()

    def get(self, k):
        if k in self.d:
            self.d.move_to_end(k)
            return self.d[k]
        return None

    def put(self, k, v):
        self.d[k] = v
        if len(self.d) > self.cap:
            self.d.popitem(last=False)


class NoteInstrument(Instrument):
    """Renders each pitch of each event independently."""
    release = 0.1
    max_len = 12.0

    def note(self, midi, dur, vel, rng, flags, kw, sr) -> np.ndarray:
        raise NotImplementedError

    def render(self, events, n, sr, rng):
        buf = np.zeros((2, n)) if self.stereo else np.zeros(n)
        for ev in events:
            ps = ev.p if isinstance(ev.p, list) else [ev.p]
            for p in ps:
                sig = self.note(p, max(0.01, ev.e - ev.s), ev.v, rng, ev.flags, ev.kw, sr)
                if sig is None:
                    continue
                place(buf, sig, int(round(ev.s * sr)))
        return buf


class CachedDecay(NoteInstrument):
    """Natural-decay instruments: cache raw renders, shape per note."""
    variants = 3
    gamma = 1.5
    bright_track = True        # lower velocity -> darker (one-pole lowpass)
    bright_lo, bright_hi = 1800.0, 12000.0

    def __init__(self):
        self.cache = _LRU(500)

    def raw(self, midi: float, variant: int, sr: int) -> np.ndarray:
        raise NotImplementedError

    def note(self, midi, dur, vel, rng, flags, kw, sr):
        var = int(rng.integers(self.variants))
        key = (round(midi * 100), var)
        x = self.cache.get(key)
        if x is None:
            x = self.raw(midi, var, sr).astype(np.float32)
            self.cache.put(key, x)
        rel = self.release if "mute" not in flags else 0.03
        end = int(dur * sr)
        length = min(len(x), end + int(rel * sr * 1.6) + 1)
        y = x[:length].astype(np.float64) * vel_amp(vel, self.gamma)
        if self.bright_track and vel < 0.97:
            fc = self.bright_lo + (self.bright_hi - self.bright_lo) * vel ** 2
            y = onepole_lp(y, fc, sr) * (1.0 + 0.15 * (1.0 - vel))
        if end < length:
            y *= release_tail(length, end, rel, sr)
        y[:16] *= ramp_cos(16)
        return y


# =========================================================================== plucked strings
PLUCK = {
    # loop lowpass taps, T60 by midi, pluck position, excitation mix, transient
    "guitar": dict(lp=(0.5, 0.5), t60=((40, 7.0), (52, 5.5), (64, 3.8), (76, 2.4), (88, 1.3)),
                   beta=0.16, noise=0.40, tri=0.75, nlp=5200, click=0.05, release=0.11,
                   bright=(2600, 11000)),
    "nylon": dict(lp=(0.5, 0.5), t60=((40, 6.0), (52, 4.6), (64, 3.2), (76, 2.0), (88, 1.1)),
                  beta=0.19, noise=0.18, tri=0.9, nlp=3000, click=0.03, release=0.13,
                  bright=(1800, 7000)),
    "banjo": dict(lp=(0.66, 0.34), t60=((48, 1.9), (60, 1.35), (72, 0.95), (84, 0.6)),
                  beta=0.075, noise=0.65, tri=0.5, nlp=9000, click=0.12, release=0.07,
                  bright=(3500, 14000)),
    "harp": dict(lp=(0.5, 0.5), t60=((36, 9.0), (60, 5.5), (72, 3.8), (84, 2.4), (96, 1.3)),
                 beta=0.3, noise=0.07, tri=1.0, nlp=2500, click=0.0, release=0.5,
                 bright=(1500, 5000)),
    "upright": dict(lp=(0.25, 0.5, 0.25), t60=((28, 2.6), (40, 2.0), (52, 1.4), (64, 1.0)),
                    beta=0.24, noise=0.12, tri=1.0, nlp=900, click=0.0, release=0.08,
                    bright=(500, 1600), thump=0.35),
    "dulcimer": dict(lp=(0.6, 0.4), t60=((48, 4.0), (60, 3.0), (72, 2.2), (84, 1.4)),
                     beta=0.11, noise=0.35, tri=0.6, nlp=7000, click=0.06, release=0.2,
                     bright=(3000, 12000)),
}


def ks_loop(x: np.ndarray, M: int, c: np.ndarray, n: int) -> np.ndarray:
    """y[i] = x[i] + sum_k c[k] * y[i - M - k], block-vectorised (all lags >= M)."""
    K = len(c)
    off = M + K
    y = np.zeros(n + off)
    xx = np.zeros(n)
    m = min(len(x), n)
    xx[:m] = x[:m]
    for s in range(0, n, M):
        e = min(s + M, n)
        seg = xx[s:e].copy()
        for k in range(K):
            a = off + s - M - k
            seg += c[k] * y[a:a + (e - s)]
        y[off + s:off + e] = seg
    return y[off:]


def ks_design(f0: float, sr: int, lp, t60: float):
    D = sr / f0
    lp = np.asarray(lp, dtype=float)
    lp = lp / lp.sum()
    gd = float(np.sum(np.arange(len(lp)) * lp))
    M = max(2, int(math.floor(D - gd - 1.0)))
    d = D - gd - M
    w0 = 2 * math.pi * f0 / sr
    for _ in range(4):
        c = np.convolve(lagrange_frac(min(max(d, 0.5), 2.5)), lp)
        H = np.sum(c * np.exp(-1j * w0 * np.arange(len(c))))
        pd = -np.angle(H) / w0
        d += D - (M + pd)
    c = np.convolve(lagrange_frac(min(max(d, 0.5), 2.5)), lp)
    H = abs(np.sum(c * np.exp(-1j * w0 * np.arange(len(c)))))
    g = 10.0 ** (-3.0 / (f0 * t60))
    rho = min(0.99995, g / H)
    return M, c * rho, D


class Plucked(CachedDecay):
    """Extended Karplus-Strong string with pluck-shape excitation and decay control."""

    def __init__(self, kind: str = "guitar", t60_scale: float = 1.0, **over):
        super().__init__()
        self.kind = kind
        self.p = dict(PLUCK[kind])
        self.p.update(over)
        self.t60_scale = t60_scale
        self.release = self.p["release"]
        self.bright_lo, self.bright_hi = self.p["bright"]
        self.name = kind
        self.default_fx = {
            "guitar": [("body", {"kind": "guitar"}),
                       ("eq", [("hp", 90), ("peak", 300, -3.0, 0.9), ("highshelf", 9000, -1.0)])],
            "nylon": [("body", {"kind": "nylon"}),
                      ("eq", [("hp", 70), ("peak", 280, -2.5, 0.9), ("highshelf", 6000, -3.0)])],
            "banjo": [("body", {"kind": "banjo"}), ("eq", [("hp", 160), ("lp", 9500)])],
            "harp": [("body", {"kind": "harp"}), ("eq", [("hp", 80), ("peak", 280, -2.0, 1.0)])],
            "upright": [("eq", [("lp", 2600), ("peak", 220, -2.0, 1.0)])],
            "dulcimer": [("eq", [("hp", 120), ("peak", 2500, 2.0, 1.2), ("lp", 9000)])],
        }.get(kind, [])

    def raw(self, midi, variant, sr):
        p = self.p
        f0 = hz(midi)
        t60 = _interp_key(midi, p["t60"]) * self.t60_scale
        n = int(min(t60 * 1.15 + 0.2, self.max_len) * sr)
        M, c, D = ks_design(f0, sr, p["lp"], t60)
        rng = np.random.default_rng(1000 + variant * 7919 + int(midi * 10))
        L = max(4, int(round(D)))
        xs = (np.arange(L) + 0.5) / L
        tri = np.interp(xs, [0.0, p["beta"], 1.0], [0.0, 1.0, 0.0])
        tri -= tri.mean()
        nz = rng.standard_normal(L)
        nz = onepole_lp(onepole_lp(nz, p["nlp"], sr), p["nlp"] * 1.5, sr)
        nz -= nz.mean()
        exc = p["tri"] * tri / (np.std(tri) + 1e-9) + p["noise"] * nz / (np.std(nz) + 1e-9)
        pb = max(1, int(round(p["beta"] * L)))
        exc = exc - 0.5 * np.concatenate((np.zeros(pb), exc[:-pb]))
        y = ks_loop(exc, M, c, n)
        if p.get("click", 0) > 0:
            k = int(0.003 * sr)
            cl = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.0006 * sr))
            cl = sosf(cl, biquad("highpass", 1800, 0.7, sr=sr))
            y[:k] += cl * p["click"] * np.std(exc)
        if p.get("thump", 0) > 0:
            k = int(0.05 * sr)
            th = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.012 * sr))
            th = onepole_lp(onepole_lp(th, 220, sr), 300, sr)
            y[:k] += th * p["thump"] * np.std(exc) * 3.0
        y = dc_block(y, 25.0, sr)
        ref = np.sqrt(np.mean(y[: int(0.06 * sr)] ** 2)) + 1e-9
        return y * (0.3 / ref)


# =========================================================================== keys & mallets
class EPiano(CachedDecay):
    """Two-operator-pair FM electric piano (warm body + metallic tine attack)."""
    gamma = 1.35
    bright_lo, bright_hi = 2500.0, 12000.0

    def __init__(self, bark: float = 1.0, tine: float = 1.0, decay: float = 1.0):
        super().__init__()
        self.release = 0.16
        self.bark, self.tine, self.decay = bark, tine, decay
        self.name = "epiano"

    def raw(self, midi, variant, sr):
        f = hz(midi)
        t60 = _interp_key(midi, ((36, 11.0), (60, 7.0), (72, 5.0), (84, 3.2), (96, 2.0))) * self.decay
        n = int(min(t60 * 0.9, self.max_len) * sr)
        t = np.arange(n) / sr
        det = 1.0 + (variant - 1) * 0.0006
        ph = 2 * np.pi * f * det * t
        kt = np.clip(1.1 - (midi - 48) / 60.0, 0.35, 1.2)
        i1 = (0.25 + 1.25 * self.bark * kt) * np.exp(-t / 0.55) + 0.18 * kt
        body = np.sin(ph + i1 * np.sin(ph + 0.4))
        i2 = (1.1 * self.tine) * np.exp(-t / 0.010)
        tine = np.sin(ph * 1.0005 + i2 * np.sin(14.0 * ph)) * np.exp(-t / 0.28)
        bell = np.sin(2 * ph * 1.0002 + 0.6 * np.exp(-t / 0.05) * np.sin(ph)) * np.exp(-t / 0.4)
        amp = (1 - np.exp(-t / 0.0012)) * (0.62 * np.exp(-t * 6.9 / t60) + 0.38 * np.exp(-t / 0.5))
        y = (0.8 * body + 0.22 * tine * self.tine + 0.08 * bell) * amp
        y = dc_block(y, 20.0, sr)
        ref = np.sqrt(np.mean(y[: int(0.2 * sr)] ** 2)) + 1e-9
        return y * (0.3 / ref)


STRUCK = {
    "musicbox": dict(r=[1.0, 1.0013, 2.0, 6.27, 17.55], a=[1.0, 0.45, 0.06, 0.22, 0.05],
                     t=[3.2, 3.0, 1.2, 0.35, 0.07], click=0.35, key=((60, 1.3), (84, 1.0), (96, 0.6))),
    "celesta": dict(r=[1.0, 2.0, 3.0, 4.15], a=[1.0, 0.22, 0.06, 0.03],
                    t=[2.6, 1.0, 0.45, 0.25], click=0.12, key=((60, 1.4), (84, 1.0), (96, 0.7))),
    "glock": dict(r=[1.0, 2.756, 5.404, 8.933], a=[1.0, 0.32, 0.16, 0.08],
                  t=[3.4, 1.7, 0.8, 0.4], click=0.15, key=((72, 1.2), (96, 0.8))),
    "marimba": dict(r=[1.0, 3.93, 9.2], a=[1.0, 0.16, 0.045], t=[1.1, 0.22, 0.07],
                    click=0.0, mallet=0.5, key=((48, 1.6), (60, 1.2), (72, 0.85), (84, 0.6))),
    "vibes": dict(r=[1.0, 4.0, 10.0], a=[1.0, 0.1, 0.025], t=[4.5, 1.0, 0.25], click=0.05,
                  key=((60, 1.2), (84, 0.8)), trem=(5.5, 0.35)),
    "kalimba": dict(r=[1.0, 5.95, 15.3], a=[1.0, 0.18, 0.04], t=[1.6, 0.18, 0.05], click=0.1,
                    mallet=0.25, key=((60, 1.2), (84, 0.8))),
    "bell": dict(r=[0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166],
                 a=[0.35, 1.0, 0.55, 0.3, 0.5, 0.2, 0.12, 0.15, 0.06],
                 t=[9.0, 6.5, 4.0, 3.2, 2.6, 1.9, 1.6, 1.3, 0.9], click=0.08, key=((48, 1.4), (72, 1.0), (96, 0.6))),
    "glass": dict(r=[1.0, 2.32, 4.25, 6.63], a=[1.0, 0.25, 0.08, 0.03], t=[5.0, 2.5, 1.0, 0.5],
                  click=0.02, key=((60, 1.2), (96, 0.7))),
}


class Struck(CachedDecay):
    """Additive struck bars / tines / bells (inharmonic partial sets)."""
    gamma = 1.4

    def __init__(self, kind: str = "musicbox", decay: float = 1.0, release: float = 0.6):
        super().__init__()
        self.kind = kind
        self.p = STRUCK[kind]
        self.decay = decay
        self.release = release
        self.bright_track = True
        self.bright_lo, self.bright_hi = 3000.0, 14000.0
        self.name = kind

    def raw(self, midi, variant, sr):
        p = self.p
        f = hz(midi)
        ks = _interp_key(midi, p["key"]) * self.decay
        tmax = max(p["t"]) * ks
        n = int(min(tmax * 0.9 + 0.1, self.max_len) * sr)
        t = np.arange(n) / sr
        rng = np.random.default_rng(int(midi * 31) + variant * 101)
        y = np.zeros(n)
        for r, a, t60 in zip(p["r"], p["a"], p["t"]):
            fr = f * r
            if fr > sr * 0.45:
                continue
            ph = rng.uniform(0, 2 * np.pi) if r != 1.0 else 0.0
            y += a * np.sin(2 * np.pi * fr * t + ph) * np.exp(-t * 6.9 / (t60 * ks))
        att = int(0.0015 * sr if not p.get("mallet") else p["mallet"] * 0.004 * sr)
        y[:att] *= ramp_cos(att)
        if p.get("trem"):
            rate, depth = p["trem"]
            y *= 1.0 - depth * 0.5 * (1 - np.cos(2 * np.pi * rate * t))
        if p.get("click", 0) > 0:
            k = int(0.004 * sr)
            cl = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.0008 * sr))
            cl = sosf(cl, biquad("highpass", 2500, 0.7, sr=sr))
            y[:k] += cl * p["click"]
        if p.get("mallet"):
            k = int(0.02 * sr)
            th = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.003 * sr))
            th = onepole_lp(th, 1500, sr)
            y[:k] += th * p["mallet"] * 0.6
        ref = np.sqrt(np.mean(y[: int(0.1 * sr)] ** 2)) + 1e-9
        return y * (0.3 / ref)


class FMBell(CachedDecay):
    """Glassy FM bell (carrier:modulator 1:3.5) for winter / night colours."""
    gamma = 1.4

    def __init__(self, ratio: float = 3.5, index: float = 2.2, decay: float = 1.0):
        super().__init__()
        self.ratio, self.index, self.decay = ratio, index, decay
        self.release = 0.9
        self.name = "fmbell"

    def raw(self, midi, variant, sr):
        f = hz(midi)
        t60 = _interp_key(midi, ((48, 7.0), (72, 4.5), (96, 2.2))) * self.decay
        n = int(min(t60 * 0.85, self.max_len) * sr)
        t = np.arange(n) / sr
        I = self.index * np.exp(-t / (t60 * 0.18)) + 0.15
        y = np.sin(2 * np.pi * f * t + I * np.sin(2 * np.pi * f * self.ratio * t))
        y += 0.3 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / (t60 * 0.12))
        y *= np.exp(-t * 6.9 / t60) * (1 - np.exp(-t / 0.001))
        ref = np.sqrt(np.mean(y[: int(0.15 * sr)] ** 2)) + 1e-9
        return y * (0.3 / ref)


class Piano(CachedDecay):
    """Soft felt piano: inharmonic additive partials, detuned unison strings, felt hammer."""
    gamma = 1.6
    bright_lo, bright_hi = 1500.0, 9000.0

    def __init__(self, felt: float = 1.0, decay: float = 1.0):
        super().__init__()
        self.felt, self.decay = felt, decay
        self.release = 0.35
        self.variants = 2
        self.name = "piano"

    def raw(self, midi, variant, sr):
        f = hz(midi)
        t60 = _interp_key(midi, ((24, 16.0), (48, 12.0), (60, 9.5), (72, 6.5), (84, 4.0), (96, 2.5))) * self.decay
        n = int(min(t60 * 0.7, 7.5) * sr)
        rng = np.random.default_rng(int(midi * 17) + variant * 977)
        B = 0.00012 * 2.0 ** ((midi - 60) / 16.0)
        K = int(min(22, max(4, 6500 / f)))
        fc = 2200.0 / self.felt
        imp = np.zeros(n)
        imp[0] = 1.0
        y = np.zeros(n)
        nstr = 2 if midi < 76 else 3
        for s_ in range(nstr):
            det = 1.0 + (s_ - (nstr - 1) / 2) * 0.00045
            for k in range(1, K + 1):
                fk = k * f * math.sqrt(1 + B * k * k) * det
                if fk > sr * 0.42:
                    break
                a = abs(math.sin(k * math.pi / 8.3)) / k ** 0.9 / (1 + (fk / fc) ** 2)
                tk = t60 / (1 + (k - 1) * 0.22)
                w = 2 * math.pi * fk / sr
                phi = rng.uniform(0, 2 * math.pi)
                # damped sinusoid r^n sin(w n + phi) = impulse response of a 2-pole resonator
                for amp_, tau in ((0.55 * a, tk * 0.32 / 6.9), (0.45 * a, tk / 6.9)):
                    r = math.exp(-1.0 / (tau * sr))
                    b_ = [amp_ * math.sin(phi), amp_ * r * math.sin(w - phi)]
                    a_ = [1.0, -2 * r * math.cos(w), r * r]
                    y += signal.lfilter(b_, a_, imp)
        att = int(0.002 * sr)
        y[:att] *= ramp_cos(att)
        k = int(0.03 * sr)
        hn = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.004 * sr))
        hn = onepole_lp(hn, 1200, sr)
        y[:k] += hn * 0.08 * np.max(np.abs(y[:k]) + 1e-9)
        ref = np.sqrt(np.mean(y[: int(0.2 * sr)] ** 2)) + 1e-9
        return y * (0.3 / ref)


# =========================================================================== bass
class Bass(NoteInstrument):
    def __init__(self, kind: str = "round", drive: float = 1.4, release: float | None = None,
                 bright: float = 1.0, sub: float = 0.3):
        self.kind = kind
        self.sub = sub
        self.drive = drive
        self.bright = bright
        self.release = release if release is not None else {"round": 0.07, "upright": 0.08, "synth": 0.05,
                                                             "sub": 0.18, "fretless": 0.1}[kind]
        self.name = f"bass_{kind}"

    def note(self, midi, dur, vel, rng, flags, kw, sr):
        f = hz(midi)
        rel = self.release
        n = int((dur + rel * 1.5) * sr)
        t = np.arange(n) / sr
        end = int(dur * sr)
        if self.kind == "round":
            ph = 2 * np.pi * f * t
            y = (np.sin(ph) + 0.32 * self.bright * np.sin(2 * ph + 0.3) * np.exp(-t / 0.5)
                 + 0.12 * self.bright * np.sin(3 * ph) * np.exp(-t / 0.22))
            env = (0.78 + 0.22 * np.exp(-t / 0.25)) * np.exp(-t / 5.0)
            att = int(0.012 * sr)
        elif self.kind == "fretless":
            cents = 25 * np.exp(-t / 0.06)
            fr = f * 2 ** (cents / 1200)
            ph = 2 * np.pi * np.cumsum(fr) / sr
            y = np.sin(ph) + 0.35 * np.sin(2 * ph) * np.exp(-t / 0.8) + 0.15 * np.sin(3 * ph) * np.exp(-t / 0.4)
            env = (0.8 + 0.2 * np.exp(-t / 0.3)) * np.exp(-t / 4.0)
            att = int(0.02 * sr)
        elif self.kind == "upright":
            cents = 14 * np.exp(-t / 0.04)
            fr = f * 2 ** (cents / 1200)
            ph = 2 * np.pi * np.cumsum(fr) / sr
            y = np.zeros(n)
            for k in range(1, 11):
                if k * f > 5000:
                    break
                a = abs(math.sin(k * math.pi * 0.22)) / k ** 1.2 * (self.bright if k > 2 else 1.0)
                y += a * np.sin(k * ph) * np.exp(-t / (1.7 / k ** 0.85))
            k = int(0.04 * sr)
            th = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.008 * sr))
            th = onepole_lp(onepole_lp(th, 260, sr), 400, sr)
            y[:k] += th * 1.2 * (0.6 + 0.4 * vel)
            env = np.ones(n)
            att = int(0.004 * sr)
        elif self.kind == "synth":
            ph0 = rng.uniform()
            saw = saw_blep(f, n, sr, ph0)
            sub = np.sin(2 * np.pi * f * 0.5 * t)
            x = 0.65 * saw + self.sub * sub
            dark = sosf(x, butter("lp", 260, 2, sr))
            brt = sosf(x, butter("lp", 1500 + 1800 * vel, 2, sr))
            b = np.exp(-t / (0.07 + 0.05 * vel))
            y = dark * (1 - b) + brt * b
            env = 0.85 + 0.15 * np.exp(-t / 0.15)
            att = int(0.003 * sr)
        elif self.kind == "sub":
            y = np.sin(2 * np.pi * f * t) + 0.08 * np.sin(4 * np.pi * f * t)
            env = np.ones(n)
            att = int(0.03 * sr)
        else:
            raise ValueError(self.kind)
        env = env.copy()
        env[:att] *= ramp_cos(att)
        y = y * env
        if self.drive > 0:
            y = np.tanh(self.drive * y) / math.tanh(self.drive)
        y *= release_tail(n, end, rel, sr)
        y[-32:] *= ramp_cos(32)[::-1]
        return y * vel_amp(vel, 1.25) * 0.4


# =========================================================================== chip pulse
class Chip(NoteInstrument):
    """Soft band-limited pulse (NES/Game Boy nod) with a stepped volume envelope."""

    def __init__(self, duty: float = 0.25, max_hz: float = 7000.0, decay: float = 0.35,
                 sustain: float = 0.45, release: float = 0.04, steps: int = 15, vib: float = 0.0):
        self.duty, self.max_hz = duty, max_hz
        self.decay, self.sustain, self.release, self.steps, self.vib = decay, sustain, release, steps, vib
        self.name = "chip"

    def note(self, midi, dur, vel, rng, flags, kw, sr):
        f = hz(midi)
        n = int((dur + self.release * 2) * sr)
        t = np.arange(n) / sr
        K = max(1, int(self.max_hz / f))
        amps = [abs(math.sin(math.pi * k * self.duty)) / k for k in range(1, K + 1)]
        freq = f if not self.vib else f * 2 ** (self.vib / 1200 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1))
        y = additive(freq, n, amps, sr)
        env = self.sustain + (1 - self.sustain) * np.exp(-t / self.decay)
        env *= release_tail(n, int(dur * sr), self.release, sr)
        env = np.round(env * self.steps) / self.steps
        env = onepole_lp(env, 400, sr)
        y *= env
        y[:24] *= ramp_cos(24)
        y[-48:] *= ramp_cos(48)[::-1]
        return y * vel_amp(vel, 1.2) * 0.25


# =========================================================================== pads
PADS = {
    "warm": dict(voices=4, det=9.0, lp=(900, 2400), hp=140, attack=0.9, release=1.6, vib=0.0, tri=0.25),
    "strings": dict(voices=5, det=7.0, lp=(1400, 3600), hp=220, attack=0.55, release=1.0, vib=0.16, tri=0.0),
    "dark": dict(voices=3, det=13.0, lp=(380, 900), hp=50, attack=2.2, release=2.8, vib=0.0, tri=0.4),
    "drone": dict(voices=4, det=16.0, lp=(300, 700), hp=35, attack=3.0, release=3.5, vib=0.05, tri=0.3),
    "soft": dict(voices=3, det=6.0, lp=(700, 1600), hp=160, attack=1.2, release=2.0, vib=0.0, tri=0.6),
    "glass": dict(voices=3, det=5.0, lp=(2500, 6000), hp=400, attack=0.35, release=2.2, vib=0.0, tri=0.8),
}


class Pad(Instrument):
    """Detuned saw/triangle stack, per-note filter swell, stereo-spread voices."""
    stereo = True

    def __init__(self, kind: str = "warm", attack: float | None = None, release: float | None = None,
                 lp_scale: float = 1.0, **over):
        self.p = dict(PADS[kind])
        self.p.update(over)
        if attack is not None:
            self.p["attack"] = attack
        if release is not None:
            self.p["release"] = release
        self.lp_scale = lp_scale
        self.kind = kind
        self.name = f"pad_{kind}"

    def render(self, events, n, sr, rng):
        p = self.p
        buf = np.zeros((2, n))
        lo_sos = butter("lp", p["lp"][0] * self.lp_scale, 2, sr)
        hi_sos = butter("lp", p["lp"][1] * self.lp_scale, 2, sr)
        for ev in events:
            ps = ev.p if isinstance(ev.p, list) else [ev.p]
            dur = max(0.05, ev.e - ev.s)
            att = min(p["attack"], dur * 0.8 + 0.05)
            m = int((dur + p["release"] * 1.2) * sr)
            t = np.arange(m) / sr
            env = np.ones(m)
            a = max(1, int(att * sr))
            env[:a] = ramp_cos(a)
            env *= release_tail(m, int(dur * sr), p["release"], sr)
            sw = np.clip(t / max(att * 1.5, 0.05), 0, 1)
            swell = sw * (0.55 + 0.45 * np.exp(-t / 4.0))
            acc = np.zeros((2, m))
            for midi in ps:
                f = hz(midi)
                st = np.zeros((2, m))
                for vi in range(p["voices"]):
                    spread = (vi - (p["voices"] - 1) / 2) / max(1, (p["voices"] - 1) / 2)
                    cents = spread * p["det"] + rng.normal(0, 1.0)
                    fr = f * 2 ** (cents / 1200)
                    if p["vib"]:
                        fr = fr * (1 + p["vib"] / 100 * np.sin(2 * np.pi * rng.uniform(4.5, 5.8) * t + rng.uniform(0, 6.28)))
                    ph0 = rng.uniform()
                    x = (1 - p["tri"]) * saw_blep(fr, m, sr, ph0)
                    if p["tri"]:
                        ph = (ph0 + (np.cumsum(np.full(m, fr) if np.isscalar(fr) else fr) / sr)) % 1.0
                        x = x + p["tri"] * (4 * np.abs(ph - 0.5) - 1)
                    pan = spread * 0.8
                    st[0] += x * math.cos((pan + 1) * math.pi / 4)
                    st[1] += x * math.sin((pan + 1) * math.pi / 4)
                acc += st / math.sqrt(p["voices"])
            dark = sosf(acc, lo_sos)
            brt = sosf(acc, hi_sos)
            y = dark * (1 - swell) + brt * swell
            y *= env * vel_amp(ev.v, 1.2) * 0.2
            place(buf, y, int(round(ev.s * sr)))
        if p["hp"]:
            buf = sosf(buf, butter("hp", p["hp"], 2, sr))
        return buf


# =========================================================================== phrase leads
REEDS = {
    "harmonica": dict(max_hz=6500.0, duty=0.42, nh=42, alpha=0.24, breath=0.045, vib_rate=5.3, vib_cents=11.0,
                      trem=0.16, vib_delay=0.26, attack=0.045, release=0.11, glide=0.03,
                      layers=((0.0, 1.0),), dip=0.5, scoop=-0.55),
    "accordion": dict(max_hz=7000.0, duty=0.30, nh=40, alpha=0.16, breath=0.012, vib_rate=5.0, vib_cents=0.0,
                      trem=0.0, vib_delay=0.3, attack=0.028, release=0.075, glide=0.012,
                      layers=((0.0, 1.0), (11.0, 0.75), (-9.0, 0.6)), dip=0.62, scoop=0.0),
    "melodica": dict(max_hz=6500.0, duty=0.38, nh=36, alpha=0.2, breath=0.03, vib_rate=5.0, vib_cents=4.0,
                     trem=0.04, vib_delay=0.35, attack=0.03, release=0.09, glide=0.02,
                     layers=((0.0, 1.0), (4.0, 0.4)), dip=0.55, scoop=0.0),
    "whistle": dict(duty=0.5, nh=4, alpha=0.1, breath=0.035, vib_rate=5.6, vib_cents=9.0,
                    trem=0.06, vib_delay=0.22, attack=0.05, release=0.12, glide=0.035,
                    layers=((0.0, 1.0),), dip=0.45, scoop=-0.35, amps=(1.0, 0.06, 0.025, 0.01)),
}


def _smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def _phrases(events, gap: float):
    evs = sorted(events, key=lambda e: e.s)
    out = []
    for e in evs:
        if out and e.s - out[-1][-1].e < gap and e.s >= out[-1][-1].s + 0.01:
            out[-1].append(e)
        else:
            out.append([e])
    return out


class _PhraseLead(Instrument):
    legato_gap = 0.045

    def split_voices(self, events):
        """Double-stops: split multi-pitch events into separate monophonic voice streams."""
        streams = {}
        for e in events:
            ps = e.p if isinstance(e.p, list) else [e.p]
            for i, p in enumerate(sorted(ps, reverse=True)):
                ee = type(e)(e.s, e.e, [p], e.v, e.flags, e.kw)
                streams.setdefault(i, []).append(ee)
        return streams

    def render(self, events, n, sr, rng):
        buf = np.zeros(n)
        for vi, evs in self.split_voices(events).items():
            for ph in _phrases(evs, self.legato_gap):
                y, s0 = self.render_phrase(ph, sr, rng)
                place(buf, y * (1.0 if vi == 0 else 0.7), s0)
        return buf

    def pitch_curve(self, ph, s0, N, sr, glide, slide_time, scoop_st, t):
        pc = np.zeros(N)
        prev_p = None
        for i, e in enumerate(ph):
            a = int(round(e.s * sr)) - s0
            b = int(round(ph[i + 1].s * sr)) - s0 if i + 1 < len(ph) else N
            p = float(e.p[0])
            pc[a:b] = p
            if prev_p is not None:
                g = slide_time if "slide" in e.flags else glide
                gs = max(1, int(g * sr))
                st = a - (0 if "slide" in e.flags else gs // 2)
                st = max(st, 0)
                seg = min(gs, N - st)
                pc[st:st + seg] = prev_p + (p - prev_p) * _smoothstep(np.arange(seg) / gs)
            if "scoop" in e.flags and scoop_st:
                k = min(int(0.11 * sr), b - a)
                pc[a:a + k] += scoop_st * (1 - _smoothstep(np.arange(k) / max(1, k)))
            if i == 0:
                pc[:a] = p
            prev_p = p
        return pc

    def vib_depth(self, ph, s0, N, sr, delay, t):
        d = np.zeros(N)
        for e in ph:
            a = int(round(e.s * sr)) - s0
            b = int(round(e.e * sr)) - s0
            L = (e.e - e.s)
            if L < 0.32:
                continue
            seg = np.arange(b - a) / sr
            depth = np.clip((seg - delay) / 0.35, 0, 1) * min(1.0, (L - 0.2) / 0.6)
            d[a:b] = np.maximum(d[a:b], depth)
        return np.convolve(d, np.ones(int(0.05 * sr)) / int(0.05 * sr), mode="same")


class Reed(_PhraseLead):
    """Harmonica / accordion / melodica / whistle lead."""

    def __init__(self, kind: str = "harmonica", **over):
        self.p = dict(REEDS[kind])
        self.p.update(over)
        self.kind = kind
        self.name = kind
        self.default_fx = {
            "harmonica": [("eq", [("hp", 200), ("peak", 1150, 2.5, 1.0), ("peak", 2700, 1.5, 1.4),
                                  ("lp", 6800)])],
            "accordion": [("eq", [("hp", 160), ("peak", 1700, 1.5, 1.0), ("lp", 7000)])],
            "melodica": [("eq", [("hp", 180), ("peak", 1500, 2.0, 1.0), ("lp", 5000)])],
            "whistle": [("eq", [("hp", 300), ("lp", 8000)])],
        }.get(kind, [])
        d = self.p["duty"]
        if "amps" in self.p:
            self.base = np.array(self.p["amps"], dtype=float)
        else:
            self.base = np.array([abs(math.sin(math.pi * k * d)) / k + 0.12 / k ** 1.3
                                  for k in range(1, self.p["nh"] + 1)])
        self.base /= np.sqrt(np.sum(self.base ** 2))

    def render_phrase(self, ph, sr, rng):
        p = self.p
        s0 = int(round(ph[0].s * sr))
        end_s = ph[-1].e + p["release"] * 1.5
        N = int(round(end_s * sr)) - s0
        t = np.arange(N) / sr
        pc = self.pitch_curve(ph, s0, N, sr, p["glide"], 0.14, p["scoop"], t)
        vd = self.vib_depth(ph, s0, N, sr, p["vib_delay"], t)
        rate = p["vib_rate"] * (1 + 0.04 * np.sin(2 * np.pi * 0.31 * t + rng.uniform(0, 6)))
        lfo = np.sin(2 * np.pi * np.cumsum(rate) / sr + rng.uniform(0, 6.28))
        # amplitude: per-note level, tonguing dips, attack / release
        lev = np.zeros(N)
        for i, e in enumerate(ph):
            a = int(round(e.s * sr)) - s0
            b = int(round(ph[i + 1].s * sr)) - s0 if i + 1 < len(ph) else int(round(e.e * sr)) - s0
            L = vel_amp(e.v, 1.25)
            seg = np.full(max(0, b - a), L)
            dl = (e.e - e.s)
            if dl > 0.8 and b > a:
                x = np.arange(b - a) / (b - a)
                seg *= 1.0 + 0.12 * np.sin(np.pi * x) - 0.06 * x
            lev[a:b] = seg
        last_end = int(round(ph[-1].e * sr)) - s0
        lev = np.convolve(lev, np.ones(int(0.012 * sr)) / int(0.012 * sr), mode="same")
        env = np.ones(N)
        att = int(p["attack"] * sr)
        env[:att] = ramp_cos(att) ** 1.3
        env *= release_tail(N, last_end, p["release"], sr)
        for i, e in enumerate(ph[1:], start=1):
            if "slur" in e.flags or "slide" in e.flags:
                continue
            c = int(round(e.s * sr)) - s0
            w = int(0.032 * sr)
            a0 = max(0, c - w // 2)
            k = np.arange(min(w, N - a0))
            env[a0:a0 + len(k)] *= 1.0 - p["dip"] * np.sin(np.pi * k / w)
        amp = lev * env
        amp *= 1.0 + p["trem"] * vd * lfo
        pres = np.clip(amp / (np.max(amp) + 1e-9), 0, 1)
        q = np.exp(-p["alpha"] * (1.0 - pres) * 2.2)
        y = np.zeros(N)
        for cents, w in p["layers"]:
            fr = hz(pc + cents / 100.0) * 2 ** (p["vib_cents"] * vd * lfo / 1200.0)
            phase0 = rng.uniform(0, 2 * np.pi, len(self.base))
            qk = np.ones(N)
            ph_acc = 2 * np.pi * np.concatenate(([0.0], np.cumsum(fr[:-1]) / sr))
            lim = min(0.45 * sr, p.get("max_hz", 7500.0))
            for k, a in enumerate(self.base, start=1):
                fk = fr * k
                if fk.min() >= lim:
                    break
                g = np.clip((lim - fk) / (0.25 * lim), 0, 1)
                y += w * a * g * qk * np.sin(k * ph_acc + phase0[k - 1])
                qk = qk * q
        y *= amp
        if p["breath"]:
            nz = rng.standard_normal(N)
            nz = sosf(nz, butter("bp", (1100, 5200), 2, sr))
            ch = np.zeros(N)
            for e in ph:
                if "slur" in e.flags:
                    continue
                a = int(round(e.s * sr)) - s0
                k = min(int(0.05 * sr), N - a)
                ch[a:a + k] += np.exp(-np.arange(k) / (0.012 * sr))
            y += nz * (amp ** 1.4 * p["breath"] + ch * p["breath"] * 0.8 * amp.max())
        fo = min(N, 64)
        y[-fo:] *= ramp_cos(fo)[::-1]
        return y * 0.5, s0


class Slide(_PhraseLead):
    """Lap-steel / slide guitar: plucked-string amplitude, glides between notes, bar vibrato."""
    legato_gap = 0.06

    def __init__(self, beta: float = 0.19, nh: int = 30, t60: float = 4.5, bright_tau: float = 0.7,
                 vib_rate: float = 4.8, vib_cents: float = 15.0, vib_delay: float = 0.22,
                 glide: float = 0.035, slide_time: float = 0.17, release: float = 0.3):
        self.beta, self.nh, self.t60, self.bright_tau = beta, nh, t60, bright_tau
        self.vib_rate, self.vib_cents, self.vib_delay = vib_rate, vib_cents, vib_delay
        self.glide, self.slide_time, self.release = glide, slide_time, release
        self.base = np.array([abs(math.sin(math.pi * k * beta)) / k ** 1.05 for k in range(1, nh + 1)])
        self.base /= np.sqrt(np.sum(self.base ** 2))
        self.name = "slide"
        self.default_fx = [("body", {"kind": "guitar"}),
                           ("eq", [("hp", 150), ("peak", 320, -2.5, 1.0), ("lp", 6500)])]

    def render_phrase(self, ph, sr, rng):
        s0 = int(round(ph[0].s * sr))
        N = int(round((ph[-1].e + self.release * 1.5) * sr)) - s0
        t = np.arange(N) / sr
        pc = self.pitch_curve(ph, s0, N, sr, self.glide, self.slide_time, -0.4, t)
        vd = self.vib_depth(ph, s0, N, sr, self.vib_delay, t)
        lfo = np.sin(2 * np.pi * self.vib_rate * t + rng.uniform(0, 6.28))
        fr = hz(pc) * 2 ** (self.vib_cents * vd * lfo / 1200.0)
        # pluck-driven amplitude & brightness
        amp = np.zeros(N)
        age = np.zeros(N)
        cur_level, last = 0.0, 0
        plucks = [i for i, e in enumerate(ph) if i == 0 or "slide" not in e.flags]
        for j, i in enumerate(plucks):
            e = ph[i]
            a = int(round(e.s * sr)) - s0
            b = int(round(ph[plucks[j + 1]].s * sr)) - s0 if j + 1 < len(plucks) else N
            L = vel_amp(e.v, 1.3)
            tt = np.arange(b - a) / sr
            amp[a:b] = L * (0.55 * np.exp(-tt * 6.9 / self.t60) + 0.45 * np.exp(-tt / 0.9))
            age[a:b] = tt
        att = np.ones(N)
        for i in plucks:
            a = int(round(ph[i].s * sr)) - s0
            k = min(int(0.004 * sr), N - a)
            if i > 0 and a > 8:
                # re-pluck: brief damp before the new attack
                d = min(int(0.012 * sr), a)
                att[a - d:a] *= np.linspace(1, 0.3, d)
            att[a:a + k] *= ramp_cos(k)
        amp = amp * att
        amp *= release_tail(N, int(round(ph[-1].e * sr)) - s0, self.release, sr)
        y = np.zeros(N)
        ph_acc = 2 * np.pi * np.concatenate(([0.0], np.cumsum(fr[:-1]) / sr))
        q = np.exp(-age / self.bright_tau * 0.35)
        qk = np.ones(N)
        lim = min(0.45 * sr, 8000.0)
        for k, a in enumerate(self.base, start=1):
            fk = fr * k
            if fk.min() >= lim:
                break
            g = np.clip((lim - fk) / (0.25 * lim), 0, 1)
            y += a * g * qk * np.sin(k * ph_acc + rng.uniform(0, 6.28))
            qk = qk * q
        y *= amp
        nz = sosf(rng.standard_normal(N), butter("bp", (1500, 6000), 2, sr))
        ch = np.zeros(N)
        for i in plucks:
            a = int(round(ph[i].s * sr)) - s0
            k = min(int(0.02 * sr), N - a)
            ch[a:a + k] += np.exp(-np.arange(k) / (0.003 * sr))
        y += nz * ch * 0.08
        y[-64:] *= ramp_cos(64)[::-1]
        return y * 0.5, s0


# =========================================================================== drones / textures
class ResoNoise(Instrument):
    """Noise blown through a tuned string loop: breathy pitched wind / pipe resonance."""

    def __init__(self, t60: float = 3.0, lp: float = 1200.0, attack: float = 1.5,
                 release: float = 2.0, loop_lp=(0.5, 0.5)):
        self.t60, self.lp, self.attack, self.release, self.loop_lp = t60, lp, attack, release, loop_lp
        self.name = "reso"

    def render(self, events, n, sr, rng):
        buf = np.zeros(n)
        for ev in events:
            ps = ev.p if isinstance(ev.p, list) else [ev.p]
            dur = max(0.1, ev.e - ev.s)
            m = int((dur + self.release * 1.3) * sr)
            env = np.ones(m)
            a = int(min(self.attack, dur * 0.7) * sr)
            env[:a] = ramp_cos(a)
            env *= release_tail(m, int(dur * sr), self.release, sr)
            for midi in ps:
                nz = rng.standard_normal(m)
                nz = sosf(nz, butter("lp", self.lp, 2, sr)) * env
                M, c, D = ks_design(hz(midi), sr, self.loop_lp, self.t60)
                y = ks_loop(nz, M, c, m)
                y = dc_block(y, 30.0, sr)
                y /= (np.sqrt(np.mean(y ** 2)) + 1e-9)
                place(buf, y * 0.1 * vel_amp(ev.v, 1.2), int(round(ev.s * sr)))
        return buf


class Swell(Instrument):
    """Reversed-envelope tone swells (ruins/combat risers): saw stack, rising filter."""
    stereo = True

    def __init__(self, lp=(300, 3000), det: float = 12.0):
        self.lp, self.det = lp, det
        self.name = "swell"

    def render(self, events, n, sr, rng):
        buf = np.zeros((2, n))
        for ev in events:
            ps = ev.p if isinstance(ev.p, list) else [ev.p]
            dur = max(0.1, ev.e - ev.s)
            m = int((dur + 0.08) * sr)
            t = np.arange(m) / sr
            env = np.clip(t / dur, 0, 1) ** 2.2
            env[int(dur * sr):] *= np.linspace(1, 0, m - int(dur * sr))
            st = np.zeros((2, m))
            for midi in ps:
                for vi, c in enumerate((-self.det, 0.0, self.det)):
                    x = saw_blep(hz(midi) * 2 ** (c / 1200), m, sr, rng.uniform())
                    st[vi % 2] += x
                    st[(vi + 1) % 2] += 0.5 * x
            lo = sosf(st, butter("lp", self.lp[0], 2, sr))
            hi = sosf(st, butter("lp", self.lp[1], 2, sr))
            y = lo * (1 - env) + hi * env
            y *= env * 0.12 * vel_amp(ev.v, 1.2)
            place(buf, y, int(round(ev.s * sr)))
        return buf
