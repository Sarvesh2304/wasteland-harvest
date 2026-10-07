"""Effects: generated-impulse convolution reverb, chorus, echo, EQ, tremolo, saturation,
stereo width, offline (non-causal) compressor, varispeed.

Reverbs are convolution with *synthesised* impulse responses: decorrelated L/R noise
split into bands, each band decaying at its own RT60 (highs die faster, like real air
and walls), plus sparse early reflections and a pre-delay.  That gives a smooth, dense,
non-metallic tail - much nicer than a bare Schroeder network - and stays deterministic.
"""
from __future__ import annotations

import math

import numpy as np
from scipy import signal
from scipy.ndimage import uniform_filter1d

from .synth import SR, biquad, butter, onepole_lp, ramp_cos, sosf, db

IR_PRESETS = {
    #          rt60  pre    er    hf    lf    len  diffusion build (s)
    "room":   dict(rt=0.65, pre=0.007, er=0.55, hf=0.45, lf=0.9, length=1.6, build=0.010),
    "studio": dict(rt=1.1, pre=0.012, er=0.4, hf=0.5, lf=0.95, length=2.4, build=0.015),
    "hall":   dict(rt=2.3, pre=0.024, er=0.3, hf=0.45, lf=1.05, length=4.6, build=0.03),
    "plate":  dict(rt=1.8, pre=0.006, er=0.0, hf=0.75, lf=0.85, length=3.6, build=0.004),
    "night":  dict(rt=3.4, pre=0.030, er=0.2, hf=0.4, lf=1.0, length=6.0, build=0.04),
    "cave":   dict(rt=5.5, pre=0.045, er=0.35, hf=0.3, lf=1.1, length=9.0, build=0.06),
    "abyss":  dict(rt=8.0, pre=0.070, er=0.25, hf=0.25, lf=1.15, length=12.0, build=0.09),
}

_BANDS = [(20, 200), (200, 600), (600, 1800), (1800, 4500), (4500, 9000), (9000, 20000)]


def make_ir(kind: str = "hall", sr: int = SR, seed: int = 7, **over) -> np.ndarray:
    p = dict(IR_PRESETS[kind])
    p.update(over)
    rng = np.random.default_rng(seed)
    n = int(p["length"] * sr)
    t = np.arange(n) / sr
    ir = np.zeros((2, n))
    centers = [math.sqrt(a * b) for a, b in _BANDS]
    lc, hc = math.log(centers[0]), math.log(centers[-1])
    for ch in range(2):
        w = rng.standard_normal(n)
        y = np.zeros(n)
        for (a, b), fc in zip(_BANDS, centers):
            x = (math.log(fc) - lc) / (hc - lc)
            rt = max(0.05, p["rt"] * float(np.interp(x, [0.0, 0.4, 1.0], [p["lf"], 1.0, p["hf"]])))
            sos = butter("bp", (a, min(b, sr * 0.45)), 2, sr) if a > 20 else butter("lp", b, 2, sr)
            y += sosf(w, sos) * np.exp(-t * 6.9 / rt)
        build = 1.0 - np.exp(-t / max(p["build"], 1e-3))
        y *= build
        # early reflections
        if p["er"] > 0:
            for k in range(14):
                tk = rng.uniform(0.002, 0.075) + 0.0
                g = p["er"] * rng.uniform(0.3, 1.0) * math.exp(-tk / 0.05) * rng.choice([-1, 1])
                i = int(tk * sr)
                if i < n:
                    y[i] += g * 6.0
        pre = int(p["pre"] * sr)
        y = np.concatenate((np.zeros(pre), y))[:n]
        # gentle lowpass on the whole response (air absorption)
        y = sosf(y, butter("lp", 11000, 2, sr))
        ir[ch] = y
    # fade the very end to avoid truncation clicks
    f = int(0.05 * sr)
    ir[:, -f:] *= ramp_cos(f)[::-1]
    ir /= math.sqrt(np.sum(ir ** 2) / 2.0)
    return ir


def convolve_reverb(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """Mono-in (sum of the input), stereo-out convolution; output length = len(x)."""
    m = x.mean(axis=0) if x.ndim == 2 else x
    n = m.shape[-1]
    out = np.zeros((2, n))
    for ch in range(2):
        y = signal.oaconvolve(m, ir[ch])[:n]
        out[ch] = y
    return out


def chorus(x: np.ndarray, rate: float = 0.7, depth_ms: float = 2.2, base_ms: float = 11.0,
           mix: float = 0.35, sr: int = SR) -> np.ndarray:
    """Stereo chorus (quadrature LFOs on L/R)."""
    st = x if x.ndim == 2 else np.vstack((x, x))
    n = st.shape[-1]
    idx = np.arange(n, dtype=float)
    out = np.empty_like(st)
    for ch in range(2):
        lfo = np.sin(2 * np.pi * rate * idx / sr + ch * math.pi / 2)
        d = (base_ms + depth_ms * lfo) * sr / 1000.0
        pos = idx - d
        i0 = np.floor(pos).astype(np.int64)
        fr = pos - i0
        i0c = np.clip(i0, 0, n - 1)
        i1c = np.clip(i0 + 1, 0, n - 1)
        src = st[ch]
        wet = src[i0c] * (1 - fr) + src[i1c] * fr
        wet[i0 < 0] = 0.0
        out[ch] = (1 - mix) * src + mix * wet
    return out


def echo(x: np.ndarray, time_s: float, fb: float = 0.35, taps: int = 6, lp: float = 3500.0,
         hp: float = 250.0, pingpong: bool = True, sr: int = SR) -> np.ndarray:
    """Tape-ish echo as a sum of progressively darker taps (returns the wet signal only)."""
    st = x if x.ndim == 2 else np.vstack((x, x))
    n = st.shape[-1]
    m = st.mean(axis=0)
    m = sosf(m, butter("hp", hp, 2, sr))
    out = np.zeros((2, n))
    cur = m
    D = int(round(time_s * sr))
    for k in range(1, taps + 1):
        cur = onepole_lp(cur, lp, sr)
        g = fb ** (k - 1)
        sh = k * D
        if sh >= n:
            break
        if pingpong:
            ch = (k - 1) % 2
            out[ch, sh:] += g * cur[: n - sh]
            out[1 - ch, sh:] += 0.25 * g * cur[: n - sh]
        else:
            out[:, sh:] += g * cur[: n - sh]
    return out


def eq(x: np.ndarray, spec: list, sr: int = SR) -> np.ndarray:
    """spec: [("hp", f), ("lp", f), ("hp4", f), ("peak", f, gain_db, q), ("lowshelf", f, g),
    ("highshelf", f, g), ("bp", lo, hi), ("notch", f, q)]"""
    for s in spec:
        k = s[0]
        if k == "hp":
            x = sosf(x, butter("hp", s[1], 2, sr))
        elif k == "hp4":
            x = sosf(x, butter("hp", s[1], 4, sr))
        elif k == "lp":
            x = sosf(x, butter("lp", s[1], 2, sr))
        elif k == "lp4":
            x = sosf(x, butter("lp", s[1], 4, sr))
        elif k == "bp":
            x = sosf(x, butter("bp", (s[1], s[2]), 2, sr))
        elif k == "peak":
            x = sosf(x, biquad("peak", s[1], s[3] if len(s) > 3 else 1.0, s[2], sr))
        elif k in ("lowshelf", "highshelf"):
            x = sosf(x, biquad(k, s[1], 0.7071, s[2], sr))
        elif k == "notch":
            x = sosf(x, biquad("notch", s[1], s[2] if len(s) > 2 else 4.0, 0.0, sr))
        else:
            raise ValueError(k)
    return x


def tremolo(x: np.ndarray, rate: float, depth: float, pan: bool = True, sr: int = SR,
            phase: float = 0.0) -> np.ndarray:
    st = x if x.ndim == 2 else np.vstack((x, x))
    n = st.shape[-1]
    lfo = np.sin(2 * np.pi * rate * np.arange(n) / sr + phase)
    if pan:
        return np.vstack((st[0] * (1 + depth * lfo), st[1] * (1 - depth * lfo)))
    return st * (1 - depth * 0.5 * (1 - lfo))


def saturate(x: np.ndarray, drive: float = 1.5) -> np.ndarray:
    pk = np.max(np.abs(x)) + 1e-12
    y = np.tanh(drive * x / pk) / math.tanh(drive)
    return y * pk


def width(x: np.ndarray, w: float) -> np.ndarray:
    if x.ndim == 1:
        return x
    m = 0.5 * (x[0] + x[1])
    s = 0.5 * (x[0] - x[1]) * w
    return np.vstack((m + s, m - s))


def haas(x: np.ndarray, ms: float = 12.0, sr: int = SR) -> np.ndarray:
    """Widen a mono source: right channel delayed a few ms."""
    m = x if x.ndim == 1 else x.mean(axis=0)
    d = int(ms * sr / 1000)
    r = np.concatenate((np.zeros(d), m[:-d])) if d > 0 else m
    return np.vstack((m, r))


def slow_filter(x: np.ndarray, lo: float, hi: float, rate: float, sr: int = SR,
                phase: float = 0.0) -> np.ndarray:
    """Slowly sweeping lowpass (LFO crossfade between a dark and a bright copy)."""
    a = sosf(x, butter("lp", lo, 2, sr))
    b = sosf(x, butter("lp", hi, 2, sr))
    n = x.shape[-1]
    w = 0.5 - 0.5 * np.cos(2 * np.pi * rate * np.arange(n) / sr + phase)
    return a * (1 - w) + b * w


def compress(x: np.ndarray, thresh_db: float, ratio: float = 2.0, window_ms: float = 30.0,
             smooth_ms: float = 120.0, knee_db: float = 6.0, sr: int = SR,
             circular: bool = False) -> np.ndarray:
    """Offline RMS compressor with symmetric (look-ahead) gain smoothing."""
    st = x if x.ndim == 2 else x[None, :]
    mode = "wrap" if circular else "nearest"
    pw = np.max(st ** 2, axis=0)
    w = max(1, int(window_ms * sr / 1000))
    rms = np.sqrt(np.maximum(uniform_filter1d(pw, w, mode=mode), 0.0) + 1e-20)
    lvl = 20 * np.log10(rms)
    over = lvl - thresh_db
    gr = np.where(over <= -knee_db / 2, 0.0,
                  np.where(over >= knee_db / 2, over * (1 - 1 / ratio),
                           (1 - 1 / ratio) * (over + knee_db / 2) ** 2 / (2 * knee_db)))
    s = max(1, int(smooth_ms * sr / 1000))
    gr = uniform_filter1d(gr, s, mode=mode)
    g = 10 ** (-gr / 20)
    out = st * g
    return out if x.ndim == 2 else out[0]


def varispeed(x: np.ndarray, speed: np.ndarray) -> np.ndarray:
    """Read x at a variable rate (tape-stop / wow); speed is per output sample."""
    pos = np.concatenate(([0.0], np.cumsum(speed[:-1])))
    st = x if x.ndim == 2 else x[None, :]
    n = st.shape[-1]
    pos = np.clip(pos, 0, n - 1.001)
    i0 = np.floor(pos).astype(np.int64)
    fr = pos - i0
    out = st[:, i0] * (1 - fr) + st[:, i0 + 1] * fr
    return out if x.ndim == 2 else out[0]


def body(x: np.ndarray, kind: str = "guitar", sr: int = SR) -> np.ndarray:
    """Instrument body colouration as parallel resonances added to the dry signal."""
    modes = {
        "guitar": [(105, 9.0, 0.35), (205, 7.0, 0.22), (410, 5.0, 0.12), (2600, 1.6, 0.18)],
        "nylon": [(98, 9.0, 0.3), (190, 7.0, 0.2), (380, 5.0, 0.1), (2000, 1.6, 0.1)],
        "banjo": [(330, 4.0, 0.15), (950, 2.5, 0.45), (2400, 2.0, 0.4), (4200, 2.0, 0.2)],
        "harp": [(140, 5.0, 0.2), (420, 4.0, 0.12)],
    }[kind]
    y = x.copy()
    for f, q, g in modes:
        y = y + g * sosf(x, biquad("bandpass", f, q, sr=sr)) * 2.0
    return y


FX = {
    "eq": lambda x, sr, spec: eq(x, spec, sr),
    "chorus": lambda x, sr, **k: chorus(x, sr=sr, **k),
    "tremolo": lambda x, sr, **k: tremolo(x, sr=sr, **k),
    "saturate": lambda x, sr, drive=1.5: saturate(x, drive),
    "width": lambda x, sr, w=1.0: width(x, w),
    "haas": lambda x, sr, ms=12.0: haas(x, ms, sr),
    "slow_filter": lambda x, sr, **k: slow_filter(x, sr=sr, **k),
    "compress": lambda x, sr, **k: compress(x, sr=sr, **k),
    "body": lambda x, sr, kind="guitar": body(x, kind, sr),
}


def apply_fx(x: np.ndarray, fx, sr: int = SR) -> np.ndarray:
    """fx: ("eq", [...]) | ("chorus", {kw}) | ("name", {kw}) | callable(x, sr)."""
    if callable(fx):
        return fx(x, sr)
    name = fx[0]
    if name == "eq":
        return eq(x, fx[1], sr)
    kw = fx[1] if len(fx) > 1 else {}
    return FX[name](x, sr, **kw)
