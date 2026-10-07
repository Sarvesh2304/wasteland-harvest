"""Render a Song to a stereo mix.

* Events are resolved to seconds with swing (time warp), shared per-onset timing jitter
  (so a strummed chord stays a strum), velocity jitter and velocity automation.
* Every part is rendered, processed by its insert effects, panned, and **auto gain-staged**:
  its gated loudness is measured and set to `ref_lufs + part.level`, so `level` in the
  score is a musical balance ("the guitar sits 6 LU under the lead") instead of a guess.
* Sends feed shared reverb / echo buses.
* Loops: the timeline is rendered with a short pre-roll and a long tail; anything before
  bar 1 (humanised early notes) wraps to the end and the tail (reverb, ringing notes)
  wraps onto the start, so the file loops seamlessly with no cut-off reverbs.
"""
from __future__ import annotations

import math

import numpy as np

from .effects import apply_fx, compress, convolve_reverb, echo, eq, make_ir
from .master import lufs
from .synth import db, pan_gains, ramp_cos

PRE_S = 0.25


class RE:
    __slots__ = ("s", "e", "p", "v", "flags", "kw")

    def __init__(self, s, e, p, v, flags, kw):
        self.s, self.e, self.p, self.v, self.flags, self.kw = s, e, p, v, flags, kw


def swing_warp(t: float, unit: float, ratio: float) -> float:
    pair = 2.0 * unit
    k = math.floor(t / pair + 1e-9)
    f = (t - k * pair) / pair
    if f < 0.5:
        f2 = f / 0.5 * ratio
    else:
        f2 = ratio + (f - 0.5) / 0.5 * (1 - ratio)
    return (k + f2) * pair


def _pw_lin(points, t, default):
    if not points:
        return default
    pts = sorted(points)
    if t < pts[0][0]:
        return default
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t0 <= t <= t1:
            if t1 - t0 < 1e-9:
                return v1
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return pts[-1][1]


def resolve(part, song, pre_s: float = PRE_S) -> list[RE]:
    rng = song.rng("human", part.name)
    spb = song.spb
    jit = {}
    out = []
    sw = part.swing
    sigma = part.human_ms / 1000.0
    for e in sorted(part.events, key=lambda e: e.t):
        t0, t1 = e.t, e.t + e.d
        if sw:
            t0, t1 = swing_warp(t0, *sw), swing_warp(t1, *sw)
        key = round(e.t, 3)
        if key not in jit:
            jit[key] = float(np.clip(rng.normal(0, sigma), -2.5 * sigma, 2.5 * sigma)) if sigma > 0 else 0.0
        j = jit[key] + part.offset_ms / 1000.0 + e.kw.get("offset_ms", 0.0) / 1000.0
        v = e.v * _pw_lin(part.vel_pts, e.t, 1.0)
        if part.human_vel > 0:
            v *= 1.0 + float(np.clip(rng.normal(0, part.human_vel), -0.2, 0.2))
        s = t0 * spb + j + pre_s
        end = t1 * spb + j + pre_s
        out.append(RE(max(0.0, s), max(s + 0.01, end), e.p, float(np.clip(v, 0.02, 1.25)), e.flags, e.kw))
    return out


def gain_curve(part, song, s0: int, m: int, pre_s: float = PRE_S) -> np.ndarray | None:
    if not part.gain_pts:
        return None
    pts = sorted(part.gain_pts)
    sr = song.sr
    xs = np.array([pre_s * sr + t * song.spb * sr for t, _ in pts]) - s0
    ys = np.array([d for _, d in pts])
    g_db = np.interp(np.arange(m), xs, ys)
    return db(g_db)


PART_TAIL_S = 14.0


def render_part(part, song, n: int):
    """Render a part over its active span only.  Returns (stereo array, start sample)."""
    sr = song.sr
    evs = resolve(part, song)
    if not evs:
        return None, 0
    s0 = max(0, int((min(e.s for e in evs) - 0.02) * sr))
    s1 = min(n, int((max(e.e for e in evs) + PART_TAIL_S) * sr))
    if s1 <= s0:
        return None, 0
    off = s0 / sr
    local = [RE(e.s - off, e.e - off, e.p, e.v, e.flags, e.kw) for e in evs]
    rng = song.rng("inst", part.name)
    x = part.inst.render(local, s1 - s0, sr, rng)
    for fx in list(getattr(part.inst, "default_fx", [])) + part.fx:
        x = apply_fx(x, fx, sr)
    if x.ndim == 1:
        gl, gr = pan_gains(part.pan)
        x = np.vstack((x * gl, x * gr))
    else:
        if part.pan:
            gl, gr = pan_gains(part.pan)
            x = np.vstack((x[0] * gl * math.sqrt(2), x[1] * gr * math.sqrt(2)))
    if part.width != 1.0:
        m = 0.5 * (x[0] + x[1])
        sd = 0.5 * (x[0] - x[1]) * part.width
        x = np.vstack((m + sd, m - sd))
    for fx in part.post_fx:
        x = apply_fx(x, fx, sr)
    return x, s0


def wrap_loop(buf: np.ndarray, pre: int, L: int) -> np.ndarray:
    out = buf[:, pre:pre + L].copy()
    head = buf[:, :pre]
    out[:, L - pre:] += head
    tail = buf[:, pre + L:]
    i = 0
    while i < tail.shape[-1]:
        chunk = tail[:, i:i + L]
        out[:, :chunk.shape[-1]] += chunk
        i += L
    return out


def render_song(song, log=print, want_stems: bool = False):
    sr = song.sr
    L = song.loop_samples
    pre = int(PRE_S * sr)
    ir_len = 0.0
    irs = {}
    for name, spec in song.buses.items():
        if spec.get("kind", "reverb") == "reverb":
            kw = {k: v for k, v in spec.items() if k not in ("kind", "ir", "ret", "eq", "seed")}
            ir = make_ir(spec.get("ir", "hall"), sr, spec.get("seed", 11), **kw)
            irs[name] = ir
            ir_len = max(ir_len, ir.shape[-1] / sr)
    tail_s = (ir_len + 6.0) if song.loop else 0.0
    n = pre + L + int(tail_s * sr) + (0 if song.loop else 0)
    if not song.loop:
        n = pre + L
    mix = np.zeros((2, n))
    bus_in = {k: np.zeros((2, n)) for k in song.buses}
    stats = {}
    stems = {}
    ref_lufs = song.ref_lufs
    for name, part in song.parts.items():
        x, s0 = render_part(part, song, n)
        if x is None:
            continue
        m = x.shape[-1]
        lv = lufs(x, sr)
        if not np.isfinite(lv):
            continue
        g = db(ref_lufs + part.level - lv)
        x *= g
        gc = gain_curve(part, song, s0, m)
        if gc is not None:
            x *= gc
        stats[name] = {"lufs_raw": round(lv, 2), "gain_db": round(float(20 * np.log10(g)), 2),
                       "level": part.level, "peak": round(float(np.max(np.abs(x))), 3)}
        mix[:, s0:s0 + m] += x
        for bname, sdb in part.sends.items():
            if bname not in bus_in:
                raise KeyError(f"{song.name}/{name}: unknown bus {bname}")
            bus_in[bname][:, s0:s0 + m] += x * db(sdb)
        if want_stems:
            full = np.zeros((2, n), dtype=np.float32)
            full[:, s0:s0 + m] = x
            stems[name] = full
        del x
    for bname, spec in song.buses.items():
        xin = bus_in[bname]
        if not np.any(xin):
            continue
        kind = spec.get("kind", "reverb")
        if kind == "reverb":
            y = convolve_reverb(xin, irs[bname])
        elif kind == "echo":
            y = echo(xin, spec["time"], spec.get("fb", 0.35), spec.get("taps", 6), spec.get("lp", 3500),
                     spec.get("hp", 250), spec.get("pingpong", True), sr)
        else:
            raise ValueError(kind)
        if spec.get("eq"):
            y = eq(y, spec["eq"], sr)
        if kind == "reverb" and spec.get("tame", True):
            # sustained notes can build up resonances where the (random) IR spectrum peaks;
            # a gentle compressor on the return keeps those swells from poking out
            act = np.max(np.abs(y), axis=0) > 1e-6
            if np.any(act):
                rms_db = 10 * np.log10(np.mean(y[:, act] ** 2) + 1e-20)
                y = compress(y, rms_db + 6.0, ratio=3.0, window_ms=25.0, smooth_ms=150.0, knee_db=6.0, sr=sr)
        y *= db(spec.get("ret", 0.0))
        mix += y
        if want_stems:
            stems["bus:" + bname] = y.astype(np.float32)
    if song.loop:
        out = wrap_loop(mix, pre, L)
        if want_stems:
            stems = {k: wrap_loop(v.astype(np.float64), pre, L).astype(np.float32) for k, v in stems.items()}
    else:
        out = mix[:, pre:pre + L].copy()
        f = int(0.25 * sr)
        out[:, -f:] *= ramp_cos(f)[::-1]
        if want_stems:
            stems = {k: v[:, pre:pre + L] for k, v in stems.items()}
    return out, stats, stems
