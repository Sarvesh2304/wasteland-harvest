"""Self-review tooling: waveform & log-frequency spectrogram PNGs, per-section band energy
report, loop-seam continuity check, and a harmonic "lint" for melodies vs. chords.

Nobody can listen to these renders during development, so every track is checked
analytically: clipping, low-end control (<120 Hz), 200-400 Hz mud, where the melody
energy sits, whether sections actually differ in density, and click-free loop seams.
"""
from __future__ import annotations

import math

import numpy as np
from scipy import signal

from .synth import SR, butter, sosf
from .theory import name as note_name

BANDS = [(20, 60), (60, 120), (120, 250), (250, 500), (500, 1000), (1000, 2000), (2000, 4000),
         (4000, 8000), (8000, 16000)]


def _cmap(v: np.ndarray) -> np.ndarray:
    """0..1 -> RGB (dark purple -> red -> amber -> pale yellow), inferno-like."""
    stops = np.array([[0.0, 0, 0, 4], [0.15, 31, 12, 72], [0.35, 101, 21, 110], [0.55, 187, 55, 84],
                      [0.72, 237, 105, 37], [0.87, 251, 180, 26], [1.0, 252, 255, 164]])
    v = np.clip(v, 0, 1)
    out = np.zeros(v.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(v, stops[:, 0], stops[:, c + 1])
    return out.astype(np.uint8)


def _font():
    from PIL import ImageFont
    try:
        return ImageFont.load_default(size=12)
    except TypeError:
        return ImageFont.load_default()


def waveform_png(x: np.ndarray, path: str, title: str, sections=None, sr: int = SR,
                 width: int = 1600, height: int = 420):
    from PIL import Image, ImageDraw
    n = x.shape[-1]
    img = Image.new("RGB", (width, height), (18, 18, 22))
    d = ImageDraw.Draw(img)
    f = _font()
    half = (height - 40) // 2
    cols = np.array_split(np.arange(n), width)
    for ch in range(2):
        y0 = 30 + ch * half + half // 2
        d.line([(0, y0), (width, y0)], fill=(60, 60, 70))
        for lvl in (0.5, 0.891):   # -6 dBFS and -1 dBFS guides
            for s in (-1, 1):
                yy = y0 - s * lvl * (half // 2 - 2)
                d.line([(0, yy), (width, yy)], fill=(70, 40, 40) if lvl > 0.8 else (45, 45, 55))
        for i, idx in enumerate(cols):
            if len(idx) == 0:
                continue
            seg = x[ch, idx[0]:idx[-1] + 1]
            mx, mn = seg.max(), seg.min()
            rms = math.sqrt(float(np.mean(seg ** 2)))
            col = (230, 90, 70) if max(abs(mx), abs(mn)) >= 0.999 else (225, 152, 42)
            d.line([(i, y0 - mx * (half // 2 - 2)), (i, y0 - mn * (half // 2 - 2))], fill=col)
            d.line([(i, y0 - rms * (half // 2 - 2)), (i, y0 + rms * (half // 2 - 2))], fill=(255, 215, 110))
    if sections:
        for nm, t0 in sections:
            xp = int(t0 * sr / n * width)
            d.line([(xp, 22), (xp, height)], fill=(120, 170, 220))
            d.text((xp + 3, 22), nm, fill=(150, 200, 240), font=f)
    d.text((6, 4), title, fill=(240, 240, 240), font=f)
    img.save(path)


def spectrogram_png(x: np.ndarray, path: str, title: str, sections=None, sr: int = SR,
                    width: int = 1600, height: int = 520, fmin: float = 30.0, fmax: float = 16000.0):
    from PIL import Image, ImageDraw
    m = x.mean(axis=0)
    nfft = 8192 if len(m) > 20 * sr else 2048
    hop = max(64, min(2048, len(m) // (width * 2)))
    f, t, Z = signal.stft(m, sr, nperseg=nfft, noverlap=nfft - hop, boundary=None, padded=False)
    S = 20 * np.log10(np.abs(Z) + 1e-9)
    # time -> columns (average frames per column, or nearest frame when there are fewer)
    nf = S.shape[1]
    if nf >= width:
        cols = np.array_split(np.arange(nf), width)
        Sc = np.stack([S[:, c].mean(axis=1) for c in cols], axis=1)
    else:
        idx = np.minimum(nf - 1, (np.arange(width) * nf / width).astype(int))
        Sc = S[:, idx]
    rows = fmin * (fmax / fmin) ** (1 - (np.arange(height - 30) + 0.5) / (height - 30))
    img_db = np.stack([np.interp(rows, f, Sc[:, i]) for i in range(width)], axis=1)
    top = np.percentile(img_db, 99.7)
    v = (img_db - (top - 80)) / 80
    rgb = _cmap(v)
    canvas = np.zeros((height, width, 3), dtype=np.uint8) + 16
    canvas[30:] = rgb
    img = Image.fromarray(canvas)
    d = ImageDraw.Draw(img)
    fnt = _font()
    for fr, lab in ((60, "60"), (120, "120"), (200, "200"), (400, "400"), (500, "500"), (1000, "1k"),
                    (3000, "3k"), (8000, "8k")):
        y = 30 + (height - 30) * (1 - math.log(fr / fmin) / math.log(fmax / fmin))
        d.line([(0, y), (width, y)], fill=(90, 90, 110) if fr not in (120, 500, 3000) else (140, 140, 170))
        d.text((2, y - 12), lab, fill=(200, 200, 220), font=fnt)
    if sections:
        n = x.shape[-1]
        for nm, t0 in sections:
            xp = int(t0 * sr / n * width)
            d.line([(xp, 30), (xp, height)], fill=(120, 200, 255))
            d.text((xp + 3, 14), nm, fill=(150, 210, 250), font=fnt)
    d.text((6, 0), title, fill=(240, 240, 240), font=fnt)
    img.save(path)


def band_report(x: np.ndarray, sections, sr: int = SR) -> str:
    """Per-section energy (dB) per octave band, relative to the loudest band of the track."""
    m = x.mean(axis=0)
    filt = []
    for lo, hi in BANDS:
        sos = butter("bp", (lo, min(hi, sr * 0.45)), 4, sr)
        filt.append(sosf(m, sos) ** 2)
    n = len(m)
    bounds = [int(t * sr) for _, t in sections] + [n]
    rows = []
    for i, (nm, t0) in enumerate(sections):
        a, b = bounds[i], bounds[i + 1]
        if b <= a:
            continue
        e = [10 * math.log10(np.mean(fb[a:b]) + 1e-20) for fb in filt]
        rms = 10 * math.log10(np.mean(m[a:b] ** 2) + 1e-20)
        rows.append((nm, rms, e))
    ref = max(max(r[2]) for r in rows)
    hdr = "section        rms dB | " + " ".join(f"{lo:>5}" for lo, _ in BANDS)
    lines = [hdr]
    for nm, rms, e in rows:
        lines.append(f"{nm[:14]:<14} {rms:6.1f} | " + " ".join(f"{v - ref:5.1f}" for v in e))
    return "\n".join(lines)


def spectral_balance(x: np.ndarray, sr: int = SR) -> dict:
    m = x.mean(axis=0)
    f, P = signal.welch(m, sr, nperseg=16384)
    def band(lo, hi):
        sel = (f >= lo) & (f < hi)
        return float(np.sum(P[sel]))
    tot = band(20, 20000)
    return {
        "sub<60": 10 * math.log10(band(20, 60) / tot + 1e-20),
        "low<120": 10 * math.log10(band(20, 120) / tot + 1e-20),
        "mud200-400": 10 * math.log10(band(200, 400) / tot + 1e-20),
        "mid500-3k": 10 * math.log10(band(500, 3000) / tot + 1e-20),
        "air>6k": 10 * math.log10(band(6000, 20000) / tot + 1e-20),
    }


def _seam_metrics(y: np.ndarray, sr: int):
    w = 2048
    cat = np.concatenate((y[:, -w:], y[:, :w]), axis=-1)
    d = np.abs(np.diff(cat, axis=-1)).max(axis=0)
    seam = float(d[w - 1])
    local = float(np.median(d[w - 256:w + 256]))
    hp = sosf(cat.mean(axis=0), butter("hp", 7000, 4, sr))
    at = float(np.max(np.abs(hp[w - 24:w + 24])))
    before = float(np.max(np.abs(hp[w - 600:w - 24])))
    return seam, local, at, before


def seam_check(dec: np.ndarray, pre: np.ndarray | None = None, sr: int = SR) -> dict:
    """Loop-seam continuity.  step_ratio = |x[0]-x[-1]| / median local step (a click would be
    >> 1); hf_at_seam vs hf_before compares 7 kHz+ energy in the +-0.5 ms around the seam
    with the preceding 13 ms; codec_* repeats the measurement on the pre-encode master so
    any click introduced by the encoder would show up as a difference."""
    seam, local, at, before = _seam_metrics(dec, sr)
    out = {"seam_step": seam, "local_step": local, "step_ratio": seam / (local + 1e-12),
           "hf_at_seam": at, "hf_before": before}
    if pre is not None:
        s2, l2, a2, b2 = _seam_metrics(pre, sr)
        out.update({"pre_step_ratio": s2 / (l2 + 1e-12), "pre_hf_at_seam": a2})
    return out


def harmonic_lint(song, parts=None, min_beats: float = 0.75) -> list[str]:
    """Flag long strong-beat melody notes that clash with the chord underneath."""
    out = []
    names = parts or [n for n, p in song.parts.items() if getattr(p, "lint", False)]
    for pn in names:
        p = song.parts[pn]
        for e in p.events:
            if not isinstance(e.p, list) or not e.p:
                continue
            dur = e.kw.get("written_d", e.d)
            if dur < min_beats:
                continue
            on_beat = abs(e.t - round(e.t)) < 1e-6
            if not on_beat:
                continue
            c = song.chord_at(e.t + 0.01)
            if c is None:
                continue
            for midi in e.p:
                pc = int(round(midi)) % 12
                if pc in c.pcs:
                    continue
                iv = (pc - c.root) % 12
                maj = (c.root + 4) % 12 in c.pcs
                minor = (c.root + 3) % 12 in c.pcs and not maj
                dom = maj and (c.root + 10) % 12 in c.pcs
                sus = not maj and not minor
                ok = {2, 9}  # 9th, 13th/6th always fine as colour
                if maj and not dom:
                    ok |= {11, 6}
                if minor:
                    ok |= {5, 10}
                if dom:
                    ok |= {6, 1, 3, 8}
                if sus:
                    ok |= {5, 2, 10, 11}
                if iv not in ok:
                    bar = int(e.t // song.bpb) + 1
                    beat = e.t % song.bpb + 1
                    out.append(f"{pn}: bar {bar} beat {beat:g} {note_name(int(midi))} "
                               f"over {c.symbol} (interval {iv}) dur {dur:g}")
    return out
