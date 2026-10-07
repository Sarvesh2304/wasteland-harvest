"""Low-level DSP primitives shared by instruments and effects (numpy / scipy only)."""
from __future__ import annotations

import math

import numpy as np
from scipy import signal

SR = 44100


def db(x):
    return 10.0 ** (np.asarray(x, dtype=float) / 20.0)


def to_db(x, floor=1e-12):
    return 20.0 * np.log10(np.maximum(np.abs(x), floor))


# --------------------------------------------------------------------------- envelopes
def ramp_cos(n: int) -> np.ndarray:
    """0 -> 1 raised-cosine ramp of n samples."""
    if n <= 0:
        return np.ones(0)
    return 0.5 - 0.5 * np.cos(np.pi * (np.arange(n) + 0.5) / n)


def env_ar(n: int, attack: float, release_at: float, release: float, sr: int = SR,
           curve: float = 1.0) -> np.ndarray:
    """Attack (raised cosine) then hold, then exponential-ish release starting at release_at s."""
    e = np.ones(n)
    a = min(n, max(1, int(attack * sr)))
    e[:a] = ramp_cos(a) ** curve
    r0 = int(release_at * sr)
    if r0 < n:
        tt = np.arange(n - r0) / sr
        e[r0:] *= np.exp(-tt / max(release, 1e-4) * 4.0)
    return e


def release_tail(n: int, start: int, release: float, sr: int = SR) -> np.ndarray:
    """Gain curve: 1 until `start`, then a smooth exponential release to silence."""
    g = np.ones(n)
    if start < n:
        tt = np.arange(n - start) / sr
        r = np.exp(-tt * (6.9 / max(release, 1e-4)))
        # cosine-smoothed knee over the first 4 ms to avoid a slope discontinuity click
        k = min(len(r), int(0.004 * sr))
        if k > 1:
            r[:k] = 1.0 - (1.0 - r[:k]) * ramp_cos(k)
        g[start:] = r
    return g


def fade_edges(x: np.ndarray, fin: int = 32, fout: int = 64) -> np.ndarray:
    """Short fades so a rendered note never starts/ends on a step."""
    n = x.shape[-1]
    if fin > 0 and n > fin:
        x[..., :fin] *= ramp_cos(fin)
    if fout > 0 and n > fout:
        x[..., -fout:] *= ramp_cos(fout)[::-1]
    return x


# --------------------------------------------------------------------------- oscillators
def phase_from_freq(freq, n: int, sr: int = SR, phase0: float = 0.0) -> np.ndarray:
    """Cycle phase (0..1 wrapping) for constant or per-sample frequency."""
    if np.isscalar(freq):
        ph = phase0 + np.arange(n) * (freq / sr)
    else:
        ph = phase0 + np.concatenate(([0.0], np.cumsum(freq[:-1] / sr)))
    return ph


def saw_blep(freq, n: int, sr: int = SR, phase0: float = 0.0) -> np.ndarray:
    """Band-limited sawtooth via PolyBLEP (vectorised)."""
    ph = phase_from_freq(freq, n, sr, phase0) % 1.0
    dt = (np.full(n, freq / sr) if np.isscalar(freq) else np.asarray(freq) / sr)
    y = 2.0 * ph - 1.0
    m = ph < dt
    t = ph[m] / dt[m]
    y[m] -= t + t - t * t - 1.0
    m = ph > 1.0 - dt
    t = (ph[m] - 1.0) / dt[m]
    y[m] -= t * t + t + t + 1.0
    return y


def pulse_blep(freq, n: int, duty: float = 0.5, sr: int = SR, phase0: float = 0.0) -> np.ndarray:
    """Band-limited pulse = difference of two PolyBLEP saws."""
    a = saw_blep(freq, n, sr, phase0)
    b = saw_blep(freq, n, sr, phase0 + duty)
    return 0.5 * (a - b)


def tri_from_phase(ph: np.ndarray) -> np.ndarray:
    p = ph % 1.0
    return 4.0 * np.abs(p - 0.5) - 1.0


def additive(freq, n: int, amps, sr: int = SR, phase0=None, nyq_frac: float = 0.45,
             amp_env=None) -> np.ndarray:
    """Sum of harmonics k=1..len(amps) of a (possibly time-varying) fundamental.

    Harmonics above nyq_frac*sr fade out smoothly, so pitch glides never alias.
    amp_env(k) may return a per-sample gain array for harmonic k (brightness tracking).
    """
    ph = 2.0 * np.pi * phase_from_freq(freq, n, sr)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    out = np.zeros(n)
    lim = nyq_frac * sr
    for k, a in enumerate(amps, start=1):
        if a == 0:
            continue
        fk = f * k
        if np.min(fk) >= lim:
            break
        g = np.clip((lim - fk) / (0.08 * sr), 0.0, 1.0)
        p0 = 0.0 if phase0 is None else phase0[k - 1]
        comp = a * g * np.sin(k * ph + p0)
        if amp_env is not None:
            comp *= amp_env(k)
        out += comp
    return out


# --------------------------------------------------------------------------- filters
def _norm_sos(b, a):
    b = np.asarray(b, dtype=float) / a[0]
    a = np.asarray(a, dtype=float) / a[0]
    return np.array([[b[0], b[1], b[2], 1.0, a[1], a[2]]])


def biquad(kind: str, f0: float, q: float = 0.7071, gain_db: float = 0.0, sr: int = SR):
    """RBJ cookbook biquad as an sos array."""
    f0 = min(max(f0, 5.0), sr * 0.49)
    A = 10.0 ** (gain_db / 40.0)
    w0 = 2.0 * math.pi * f0 / sr
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * q)
    if kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bandpass":   # 0 dB peak gain
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "notch":
        b = [1, -2 * cw, 1]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind in ("lowshelf", "highshelf"):
        sq = 2.0 * math.sqrt(A) * alpha
        if kind == "lowshelf":
            b = [A * ((A + 1) - (A - 1) * cw + sq), 2 * A * ((A - 1) - (A + 1) * cw),
                 A * ((A + 1) - (A - 1) * cw - sq)]
            a = [(A + 1) + (A - 1) * cw + sq, -2 * ((A - 1) + (A + 1) * cw),
                 (A + 1) + (A - 1) * cw - sq]
        else:
            b = [A * ((A + 1) + (A - 1) * cw + sq), -2 * A * ((A - 1) + (A + 1) * cw),
                 A * ((A + 1) + (A - 1) * cw - sq)]
            a = [(A + 1) - (A - 1) * cw + sq, 2 * ((A - 1) - (A + 1) * cw),
                 (A + 1) - (A - 1) * cw - sq]
    else:
        raise ValueError(kind)
    return _norm_sos(b, a)


def butter(kind: str, f, order: int = 2, sr: int = SR):
    if np.isscalar(f):
        f = min(max(float(f), 5.0), sr * 0.49)
    else:
        f = [min(max(float(x), 5.0), sr * 0.49) for x in f]
    btype = {"lowpass": "lowpass", "highpass": "highpass", "bandpass": "bandpass",
             "lp": "lowpass", "hp": "highpass", "bp": "bandpass"}[kind]
    return signal.butter(order, f, btype=btype, fs=sr, output="sos")


def sosf(x: np.ndarray, sos) -> np.ndarray:
    """Apply sos filter along the last axis (mono or stereo)."""
    return signal.sosfilt(sos, x, axis=-1)


def chain(x: np.ndarray, *soses) -> np.ndarray:
    for s in soses:
        x = signal.sosfilt(s, x, axis=-1)
    return x


def onepole_lp(x: np.ndarray, fc: float, sr: int = SR) -> np.ndarray:
    a = math.exp(-2.0 * math.pi * fc / sr)
    return signal.lfilter([1.0 - a], [1.0, -a], x, axis=-1)


def dc_block(x: np.ndarray, fc: float = 18.0, sr: int = SR) -> np.ndarray:
    return signal.sosfilt(biquad("highpass", fc, 0.6, sr=sr), x, axis=-1)


def noise(rng: np.random.Generator, n: int) -> np.ndarray:
    return rng.standard_normal(n)


def pink(rng: np.random.Generator, n: int) -> np.ndarray:
    """Pink-ish noise (Paul Kellet's economy filter via lfilter)."""
    w = rng.standard_normal(n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, w) * 4.0


# --------------------------------------------------------------------------- utilities
def pan_gains(pan: float) -> tuple[float, float]:
    """Constant-power pan, pan in [-1, 1]."""
    th = (pan + 1.0) * math.pi / 4.0
    return math.cos(th) * math.sqrt(2.0) * 0.7071, math.sin(th) * math.sqrt(2.0) * 0.7071


def to_stereo(x: np.ndarray, pan: float = 0.0) -> np.ndarray:
    if x.ndim == 2:
        return x
    gl, gr = pan_gains(pan)
    return np.vstack((x * gl, x * gr))


def place(buf: np.ndarray, sig: np.ndarray, start: int) -> None:
    """Add `sig` into `buf` at sample `start` (mono or stereo, clipped to bounds)."""
    n = buf.shape[-1]
    if start >= n:
        return
    s0 = 0
    if start < 0:
        s0 = -start
        start = 0
    m = min(sig.shape[-1] - s0, n - start)
    if m <= 0:
        return
    if buf.ndim == 1 and sig.ndim == 1:
        buf[start:start + m] += sig[s0:s0 + m]
    elif buf.ndim == 2 and sig.ndim == 1:
        buf[:, start:start + m] += sig[s0:s0 + m]
    else:
        buf[..., start:start + m] += sig[..., s0:s0 + m]


def lagrange_frac(d: float, order: int = 3) -> np.ndarray:
    """FIR taps of a Lagrange fractional delay of `d` samples (0 <= d <= order)."""
    h = np.ones(order + 1)
    for k in range(order + 1):
        for m in range(order + 1):
            if m != k:
                h[k] *= (d - m) / (k - m)
    return h
