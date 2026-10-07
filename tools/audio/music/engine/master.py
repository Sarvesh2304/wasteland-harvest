"""Mastering: BS.1770-4 loudness, true peak, offline look-ahead limiter, loop-safe
processing, and OGG Vorbis encoding through ffmpeg.

Loops are mastered *circularly*: every stateful stage (IIR EQ, compressor, limiter,
oversampling filter) sees the end of the loop before its beginning, so the processed
loop is exactly as continuous at the seam as it is everywhere else.
"""
from __future__ import annotations

import math
import re
import subprocess

import numpy as np
from scipy import signal
from scipy.ndimage import maximum_filter1d, uniform_filter1d

from .effects import compress, eq
from .synth import SR


# --------------------------------------------------------------------------- loudness
def _k_weight_sos(sr: int):
    # pre-filter (high shelf) - same derivation as libebur128 / pyloudnorm
    G, Q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    K = math.tan(math.pi * fc / sr)
    Vh = 10 ** (G / 20.0)
    Vb = Vh ** 0.4996667741545416
    a0 = 1.0 + K / Q + K * K
    b = [(Vh + Vb * K / Q + K * K) / a0, 2.0 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a = [1.0, 2.0 * (K * K - 1.0) / a0, (1.0 - K / Q + K * K) / a0]
    # RLB high-pass
    Q2, fc2 = 0.5003270373238773, 38.13547087602444
    K2 = math.tan(math.pi * fc2 / sr)
    a02 = 1.0 + K2 / Q2 + K2 * K2
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2.0 * (K2 * K2 - 1.0) / a02, (1.0 - K2 / Q2 + K2 * K2) / a02]
    return np.array([b + a, b2 + a2])


def _hop_energy(x: np.ndarray, sr: int, hop: int) -> np.ndarray:
    """K-weighted energy summed over channels, per hop-sized chunk."""
    st = x if x.ndim == 2 else x[None, :]
    y = signal.sosfilt(_k_weight_sos(sr), st, axis=-1)
    nh = y.shape[-1] // hop
    e = np.einsum("chk,chk->h", y[:, :nh * hop].reshape(st.shape[0], nh, hop),
                  y[:, :nh * hop].reshape(st.shape[0], nh, hop))
    return e


def lufs(x: np.ndarray, sr: int = SR, return_blocks: bool = False):
    """Integrated loudness (BS.1770-4: 400 ms blocks, 75 % overlap, -70 / -10 LU gates)."""
    hop = int(0.1 * sr)
    e = _hop_energy(x, sr, hop)
    if len(e) < 4:
        st = x if x.ndim == 2 else x[None, :]
        y = signal.sosfilt(_k_weight_sos(sr), st, axis=-1)
        z = np.mean(y ** 2, axis=-1).sum()
        return -0.691 + 10 * math.log10(z + 1e-20)
    z = (e[:-3] + e[1:-2] + e[2:-1] + e[3:]) / (4 * hop)
    l = -0.691 + 10 * np.log10(z + 1e-20)
    g1 = l > -70.0
    if not np.any(g1):
        return -float("inf")
    rel = -0.691 + 10 * math.log10(np.mean(z[g1])) - 10.0
    g2 = g1 & (l > rel)
    out = -0.691 + 10 * math.log10(np.mean(z[g2]))
    if return_blocks:
        return out, l
    return out


def short_term(x: np.ndarray, sr: int = SR, win: float = 3.0, hop: float = 0.5):
    st = x if x.ndim == 2 else x[None, :]
    y = signal.sosfilt(_k_weight_sos(sr), st, axis=-1)
    n = y.shape[-1]
    blk, h = int(win * sr), int(hop * sr)
    cs = np.concatenate((np.zeros((y.shape[0], 1)), np.cumsum(y ** 2, axis=-1)), axis=-1)
    starts = np.arange(0, max(1, n - blk + 1), h)
    z = ((cs[:, np.minimum(starts + blk, n)] - cs[:, starts]) / blk).sum(axis=0)
    return starts / sr, -0.691 + 10 * np.log10(z + 1e-20)


def true_peak_db(x: np.ndarray, circular: bool = False) -> float:
    st = x if x.ndim == 2 else x[None, :]
    if circular:
        pad = 64
        st = np.concatenate((st[:, -pad:], st, st[:, :pad]), axis=-1)
    os = signal.resample_poly(st, 4, 1, axis=-1)
    if circular:
        os = os[:, 4 * 64: -4 * 64]
    return 20 * math.log10(np.max(np.abs(os)) + 1e-20)


# --------------------------------------------------------------------------- limiter
def limit(x: np.ndarray, ceiling_db: float = -1.5, sr: int = SR, attack_ms: float = 2.0,
          hold_ms: float = 25.0, release_ms: float = 80.0, circular: bool = True) -> np.ndarray:
    """Non-causal true-peak limiter: gain never exceeds what keeps 4x-oversampled peaks
    under the ceiling; reductions are smoothed symmetrically (built-in look-ahead)."""
    mode = "wrap" if circular else "nearest"
    pad = 64
    if circular:
        xp = np.concatenate((x[:, -pad:], x, x[:, :pad]), axis=-1)
    else:
        xp = np.concatenate((np.zeros((2, pad)), x, np.zeros((2, pad))), axis=-1)
    os = signal.resample_poly(xp, 4, 1, axis=-1)[:, 4 * pad: -4 * pad]
    n = x.shape[-1]
    pk = np.max(np.abs(os).reshape(2, n, 4), axis=(0, 2))
    ceil = 10 ** (ceiling_db / 20)
    r = np.maximum(0.0, 20 * np.log10(pk / ceil + 1e-20))
    if not np.any(r > 0):
        return x
    W = max(1, int(attack_ms * sr / 1000))
    r = maximum_filter1d(r, 2 * W + 1, mode=mode)
    r = uniform_filter1d(r, 2 * W + 1, mode=mode)
    H = max(3, int(hold_ms * sr / 1000))
    R = max(1, min(H, int(release_ms * sr / 1000)))
    r = maximum_filter1d(r, H, mode=mode)
    r = uniform_filter1d(r, R, mode=mode)
    return x * 10 ** (-r / 20)


def circular_eq(x: np.ndarray, spec, sr: int = SR, loop: bool = True, pre_s: float = 3.0):
    if not spec:
        return x
    if not loop:
        return eq(x, spec, sr)
    P = min(x.shape[-1], int(pre_s * sr))
    xp = np.concatenate((x[:, -P:], x), axis=-1)
    y = eq(xp, spec, sr)
    return y[:, P:]


def master(x: np.ndarray, target_lufs: float = -15.0, ceiling_dbtp: float = -1.5,
           eq_spec=None, glue: dict | None = None, loop: bool = True, sr: int = SR,
           log=None) -> tuple[np.ndarray, dict]:
    """EQ -> gentle glue compression -> loudness normalisation -> true-peak limiting."""
    y = circular_eq(x, [("hp", 28.0)] + list(eq_spec or []), sr, loop)
    L0 = lufs(y, sr)
    if glue is not None:
        g = dict(ratio=1.6, window_ms=60.0, smooth_ms=180.0, knee_db=8.0)
        g.update(glue)
        rel = g.pop("above", 5.0)
        y = compress(y, L0 + rel, sr=sr, circular=loop, **g)
    gain = 0.0
    for it in range(6):
        L = lufs(y, sr)
        d = target_lufs - L
        y = y * 10 ** (d / 20)
        gain += d
        y = limit(y, ceiling_dbtp - 0.25, sr, circular=loop)
        L2 = lufs(y, sr)
        tp = true_peak_db(y, circular=loop)
        if abs(L2 - target_lufs) < 0.08 and tp <= ceiling_dbtp:
            break
    info = {"lufs": lufs(y, sr), "true_peak": true_peak_db(y, circular=loop), "gain_db": gain,
            "pre_lufs": L0}
    return y, info


# --------------------------------------------------------------------------- encode / decode
def encode_ogg(x: np.ndarray, path: str, sr: int = SR, quality: int = 6, meta: dict | None = None):
    inter = np.ascontiguousarray(x.T.astype("<f4"))
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-f", "f32le", "-ar", str(sr),
           "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", str(quality),
           "-fflags", "+bitexact", "-flags:a", "+bitexact"]   # fixed Ogg serial -> reproducible bytes
    for k, v in (meta or {}).items():
        cmd += ["-metadata", f"{k}={v}"]
    cmd.append(path)
    subprocess.run(cmd, input=inter.tobytes(), check=True)


def decode(path: str, sr: int = SR) -> np.ndarray:
    out = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-f", "f32le",
                          "-ac", "2", "-ar", str(sr), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<f4").reshape(-1, 2).T.astype(np.float64)


def ffmpeg_loudness(path: str) -> dict:
    """Integrated loudness / true peak as measured by ffmpeg's ebur128 filter."""
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
                        "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True)
    txt = r.stderr
    tail = txt[txt.rfind("Summary:"):]
    I = re.search(r"I:\s+(-?[\d.]+|-inf)\s+LUFS", tail)
    tp = re.search(r"Peak:\s+(-?[\d.]+|-inf)\s+dBFS", tail)
    lra = re.search(r"LRA:\s+(-?[\d.]+)\s+LU", tail)
    return {"I": float(I.group(1)) if I else None, "TP": float(tp.group(1)) if tp else None,
            "LRA": float(lra.group(1)) if lra else None}
