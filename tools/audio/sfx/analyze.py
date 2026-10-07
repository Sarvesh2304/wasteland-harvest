#!/usr/bin/env python3
"""analyze.py -- QA report and spectrogram contact sheets for the generated SFX and ambience.

    python3 tools/audio/sfx/analyze.py                         # report + sheets for everything
    python3 tools/audio/sfx/analyze.py --sheets /some/dir      # where the PNG sheets go
    python3 tools/audio/sfx/analyze.py --only 'footstep_*' 'ui_*' --no-sheets
    python3 tools/audio/sfx/analyze.py --ffmpeg-lufs           # cross-check loop loudness

Per file it reports peak / RMS dBFS, max momentary loudness, DC offset, leading silence (time to
the first sample within 40 dB of the peak), the tail (last-sample value, level of the last 2 ms),
clipped samples and the share of energy above 6 kHz (a harshness indicator for the cozy sounds).
For ambience loops it also reports integrated LUFS (BS.1770, measured around the loop) and the
loop-seam discontinuity: the step x[0] - x[-1] and the second difference across the seam, each
ranked against the same statistic at every other sample, plus the >8 kHz energy of the window
straddling the seam ranked against every other window (a click is an outlier in all three).
Problems are flagged with '!'.

Contact sheets (PNG): per sound a log-frequency spectrogram (40 Hz - 20 kHz, 80 dB range relative
to the sound's own maximum), a full-scale min/max waveform strip with an RMS-dB envelope line and,
for loops, a 20 ms zoom across the seam.
"""
from __future__ import annotations

import argparse
import fnmatch
import os
import re
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import synth as S  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SFX_DIR = os.path.join(REPO, 'audio', 'sfx')
AMB_DIR = os.path.join(REPO, 'audio', 'ambience')

# QA thresholds
LEAD_MAX_MS = 5.0
DC_MAX = 0.001          # -60 dBFS
TAIL_MAX_DB = -50.0     # RMS level of the final 2 ms (the fade-out region) must be tiny
SEAM_RANK_MAX = 99.9    # seam step / 2nd difference must not be outliers among all samples
SEAM_HF_RANK_MAX = 99.5  # >8 kHz energy of the seam window must not be an outlier among windows


# ============================================================================ metrics
def sfx_metrics(x):
    """x: mono float array as stored (16-bit decoded)."""
    n = len(x)
    pk = float(np.max(np.abs(x))) if n else 0.0
    thr = pk * 10 ** (-40 / 20)
    above = np.nonzero(np.abs(x) >= thr)[0]
    lead_ms = 1000.0 * above[0] / S.SR if len(above) else float('nan')
    tail = x[-max(1, S.ns(0.002)):]
    X = np.abs(np.fft.rfft(x * np.hanning(n))) ** 2 if n > 8 else np.zeros(2)
    f = np.fft.rfftfreq(n, 1.0 / S.SR) if n > 8 else np.zeros(2)
    hf = float(X[f > 6000].sum() / (X.sum() + 1e-20)) * 100.0
    cen = float((f * X).sum() / (X.sum() + 1e-20))
    return {
        'dur': n / S.SR,
        'peak_db': float(S.todb(pk)),
        'rms_db': S.rms_db(x),
        'mom_lufs': S.momentary_max(x),
        'dc': float(np.mean(x)),
        'lead_ms': lead_ms,
        'first': float(x[0]) if n else 0.0,
        'last': float(x[-1]) if n else 0.0,
        'tail_db': S.rms_db(tail),
        'clipped': int(np.sum(np.abs(x) >= 32767 / 32768.0)),
        'hf_pct': hf,
        'centroid': cen,
    }


def seam_metrics(x):
    """x: (ch, L) loop as decoded.  A seam click would show up as (a) an outlier sample step
    x[0] - x[-1], (b) an outlier second difference across the seam, (c) an outlier burst of
    >8 kHz energy in the window straddling the seam.  Each is ranked (percentile) against the same
    statistic everywhere else in the loop, so natural transients near the seam (a bird chirp, a
    crackle) are not mistaken for a discontinuity."""
    x = np.atleast_2d(x)
    d = np.abs(np.diff(x, axis=-1))
    seam = np.abs(x[:, 0] - x[:, -1])
    rank = max(float(np.mean(d[c] < seam[c]) * 100.0) for c in range(x.shape[0]))
    d2 = np.abs(np.diff(x, 2, axis=-1))
    s2 = np.maximum(np.abs(x[:, 1] - 2 * x[:, 0] + x[:, -1]), np.abs(x[:, 0] - 2 * x[:, -1] + x[:, -2]))
    rank2 = max(float(np.mean(d2[c] < s2[c]) * 100.0) for c in range(x.shape[0]))
    # HF-burst rank: 1024-sample windows (hop 512) over the loop rotated so that window 0 is
    # centred on the seam; the high-pass is warmed up circularly as well.
    W, H = 1024, 512
    xr = np.roll(x, W // 2, axis=-1)
    hpx = S.butter(np.concatenate([xr[:, -4096:], xr], axis=-1), 'hp', 8000.0, 4)[:, 4096:]
    e = (hpx ** 2).sum(axis=0)
    cs = np.concatenate([[0.0], np.cumsum(e)])
    starts = np.arange(0, x.shape[-1] - W, H)
    win = cs[starts + W] - cs[starts]
    hf_rank = float(np.mean(win < win[0]) * 100.0)
    # level continuity: 50 ms RMS either side (informational; natural events can differ)
    m = S.ns(0.05)
    lvl = abs(S.rms_db(x[:, -m:]) - S.rms_db(x[:, :m]))
    return {
        'seam_step': float(np.max(seam)),
        'seam_rank': rank,
        'seam_d2_rank': rank2,
        'seam_hf_rank': hf_rank,
        'step_p50': float(np.median(d)),
        'step_p999': float(np.percentile(d, 99.9)),
        'seam_lvl_db': lvl,
    }


def amb_metrics(x):
    x = np.atleast_2d(x)
    m = {
        'dur': x.shape[-1] / S.SR,
        'peak_db': float(S.todb(np.max(np.abs(x)))),
        'rms_db': S.rms_db(x),
        'lufs': S.loudness(x, circular=True),
        'dc': float(np.max(np.abs(np.mean(x, axis=-1)))),
        'corr': float(np.corrcoef(x[0], x[1])[0, 1]) if x.shape[0] == 2 else 1.0,
        'clipped': int(np.sum(np.abs(x) >= 0.9999)),
    }
    m.update(seam_metrics(x))
    return m


def ffmpeg_lufs(path):
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', path, '-filter_complex',
                        'ebur128', '-f', 'null', '-'], capture_output=True, text=True)
    hits = re.findall(r'I:\s+(-?[\d.]+) LUFS', r.stderr)
    return float(hits[-1]) if hits else float('nan')


def sfx_flags(m):
    fl = []
    if not (m['lead_ms'] <= LEAD_MAX_MS):
        fl.append('LEAD')
    if abs(m['dc']) > DC_MAX:
        fl.append('DC')
    if m['tail_db'] > TAIL_MAX_DB or abs(m['last']) > 1.0 / 32768:
        fl.append('TAIL')
    if abs(m['first']) > 2.0 / 32768:
        fl.append('HEAD')
    if m['clipped']:
        fl.append('CLIP')
    return fl


def amb_flags(m, target=None):
    fl = []
    if m['seam_rank'] > SEAM_RANK_MAX or m['seam_d2_rank'] > SEAM_RANK_MAX:
        fl.append('SEAM')
    if m['seam_hf_rank'] > SEAM_HF_RANK_MAX:
        fl.append('SEAM-HF')
    if not (-26.5 <= m['lufs'] <= -21.5):
        fl.append('LUFS')
    if m['dc'] > DC_MAX:
        fl.append('DC')
    if m['clipped'] or m['peak_db'] > -1.0:
        fl.append('PEAK')
    if not (30.0 <= m['dur'] <= 60.0):
        fl.append('DUR')
    return fl


# ============================================================================ rendering
_CMAP = np.array([[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66],
                  [245, 125, 21], [250, 193, 39], [252, 255, 164]], dtype=float)


def _cmap(v):
    v = np.clip(v, 0, 1) * (len(_CMAP) - 1)
    i = np.minimum(v.astype(int), len(_CMAP) - 2)
    fr = (v - i)[..., None]
    return (_CMAP[i] * (1 - fr) + _CMAP[i + 1] * fr).astype(np.uint8)


FMIN, FMAX = 40.0, 20000.0


def spectro_rgb(x, w, h, dyn=80.0):
    x = np.asarray(x, dtype=float)
    n = len(x)
    nfft = 256 if n < S.ns(0.15) else (512 if n < S.ns(1.0) else 2048)
    hop = max(8, n // (w * 2) or 1)
    xp = np.concatenate([np.zeros(nfft // 2), x, np.zeros(nfft // 2)])
    starts = np.arange(0, max(1, len(xp) - nfft), hop)
    idx = starts[:, None] + np.arange(nfft)[None, :]
    fr = xp[idx] * np.hanning(nfft)[None, :]
    P = np.abs(np.fft.rfft(fr, axis=1)) ** 2
    Pdb = 10 * np.log10(P + 1e-20)
    rows = FMIN * (FMAX / FMIN) ** (1.0 - (np.arange(h) + 0.5) / h)
    bins = rows / (S.SR / nfft)
    b0 = np.clip(np.floor(bins).astype(int), 0, P.shape[1] - 2)
    fb = bins - b0
    img = Pdb[:, b0] * (1 - fb) + Pdb[:, b0 + 1] * fb       # (frames, h)
    ref = np.max(img)
    v = (img - (ref - dyn)) / dyn
    rgb = _cmap(v.T)                                          # (h, frames, 3)
    from PIL import Image
    im = Image.fromarray(rgb, 'RGB').resize((w, h), Image.BILINEAR)
    return im


def draw_tile(x, title, sub, w=360, sh=150, wh=44, loop=False, flags=()):
    from PIL import Image, ImageDraw
    x = np.atleast_2d(x)
    mono = x.mean(axis=0)
    lab = 26
    seam_h = 40 if loop else 0
    tile = Image.new('RGB', (w, lab + sh + wh + seam_h + 6), (18, 18, 22))
    d = ImageDraw.Draw(tile)
    col = (255, 110, 110) if flags else (230, 230, 230)
    d.text((4, 1), title + ('  [' + ','.join(flags) + ']' if flags else ''), fill=col)
    d.text((4, 13), sub, fill=(160, 160, 170))
    tile.paste(spectro_rgb(mono, w, sh), (0, lab))
    # frequency grid
    for f, txt in ((100, '100'), (1000, '1k'), (5000, '5k'), (10000, '10k')):
        yy = lab + int(sh * (1.0 - np.log(f / FMIN) / np.log(FMAX / FMIN)))
        d.line([(0, yy), (w, yy)], fill=(70, 70, 80))
        d.text((w - 22, yy - 11), txt, fill=(140, 140, 150))
    # time ticks
    dur = mono.shape[-1] / S.SR
    step = 0.1 if dur <= 1.5 else (1.0 if dur <= 12 else 5.0)
    tk = step
    while tk < dur:
        xx = int(w * tk / dur)
        d.line([(xx, lab + sh - 5), (xx, lab + sh)], fill=(200, 200, 200))
        tk += step
    # waveform (full-scale) + RMS dB envelope
    y0 = lab + sh + 2
    mid = y0 + wh // 2
    cols = np.array_split(mono, w) if len(mono) >= w else [mono[int(i * len(mono) / w):int(i * len(mono) / w) + 1] for i in range(w)]
    for i, c in enumerate(cols):
        if len(c) == 0:
            continue
        lo, hi = float(np.min(c)), float(np.max(c))
        d.line([(i, mid - int(hi * wh / 2)), (i, mid - int(lo * wh / 2))], fill=(90, 170, 230))
    prev = None
    for i, c in enumerate(cols):
        if len(c) == 0:
            continue
        r = np.sqrt(np.mean(c * c)) + 1e-9
        yy = y0 + wh - int(np.clip((20 * np.log10(r) + 70) / 70, 0, 1) * wh)
        if prev is not None:
            d.line([prev, (i, yy)], fill=(250, 200, 60))
        prev = (i, yy)
    d.line([(0, mid), (w, mid)], fill=(50, 50, 60))
    if loop:
        z0 = y0 + wh + 4
        m = S.ns(0.01)
        seg = np.concatenate([x[0, -m:], x[0, :m]])
        sc = 0.45 * seam_h / (np.max(np.abs(seg)) + 1e-9)
        pts = [(int(i * w / len(seg)), z0 + seam_h // 2 - int(v * sc)) for i, v in enumerate(seg)]
        d.line(pts, fill=(120, 230, 120))
        d.line([(w // 2, z0), (w // 2, z0 + seam_h)], fill=(255, 80, 80))
        d.text((4, z0), 'seam zoom 10 ms | 10 ms (L ch)', fill=(140, 140, 150))
    return tile


def contact_sheet(tiles, path, cols=4, pad=6, title=''):
    from PIL import Image, ImageDraw
    if not tiles:
        return
    tw = max(t.width for t in tiles)
    th = max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * (tw + pad) + pad, rows * (th + pad) + pad + 18), (8, 8, 10))
    ImageDraw.Draw(sheet).text((pad, 3), title, fill=(255, 255, 255))
    for i, t in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet.paste(t, (pad + c * (tw + pad), 18 + pad + r * (th + pad)))
    sheet.save(path)


# ============================================================================ driver
def _registry():
    import registry  # noqa
    import gen_ui, gen_farm, gen_combat, gen_ambience  # noqa: F401  (register sounds)
    return registry.REGISTRY


def analyze(names=None, sheets_dir=None, ffm=False, quiet=False):
    reg = _registry()
    sel = [e for e in reg.values() if names is None or any(fnmatch.fnmatch(e.name, p) for p in names)]
    rows, problems = [], []
    groups = {}
    for e in sel:
        path = os.path.join(SFX_DIR if e.kind == 'sfx' else AMB_DIR,
                            e.name + ('.wav' if e.kind == 'sfx' else '.ogg'))
        if not os.path.exists(path):
            problems.append(f'{e.name}: MISSING {path}')
            continue
        if e.kind == 'sfx':
            x, sr = S.read_wav(path)
            if sr != S.SR or np.ndim(x) != 1:
                problems.append(f'{e.name}: wrong format (sr={sr}, ndim={np.ndim(x)})')
            m = sfx_metrics(x)
            fl = sfx_flags(m)
            line = (f"{e.name:24s} {m['dur'] * 1000:7.0f} ms  pk {m['peak_db']:6.1f}  rms {m['rms_db']:6.1f}"
                    f"  M {m['mom_lufs']:6.1f}  dc {m['dc']:+.5f}  lead {m['lead_ms']:4.1f} ms"
                    f"  tail {m['tail_db']:6.1f}  hf {m['hf_pct']:4.1f}%  cen {m['centroid']:5.0f}"
                    + ('  ! ' + ','.join(fl) if fl else ''))
            sub = f"{m['dur'] * 1000:.0f} ms  pk {m['peak_db']:.1f} dBFS  M {m['mom_lufs']:.1f}  hf {m['hf_pct']:.1f}%"
        else:
            x = S.read_audio(path)
            m = amb_metrics(x)
            if ffm:
                m['ffmpeg_lufs'] = ffmpeg_lufs(path)
            fl = amb_flags(m)
            line = (f"{e.name:24s} {m['dur']:6.2f} s  LUFS {m['lufs']:6.2f}"
                    + (f" (ffmpeg {m['ffmpeg_lufs']:6.2f})" if ffm else '')
                    + f"  pk {m['peak_db']:6.1f}  corr {m['corr']:+.2f}  seam step {m['seam_step']:.5f}"
                    f" (rank {m['seam_rank']:5.1f}%, p50 {m['step_p50']:.5f}, p99.9 {m['step_p999']:.5f})"
                    f"  d2 rank {m['seam_d2_rank']:5.1f}%  HF rank {m['seam_hf_rank']:5.1f}%"
                    + ('  ! ' + ','.join(fl) if fl else ''))
            sub = (f"{m['dur']:.1f} s  {m['lufs']:.1f} LUFS  pk {m['peak_db']:.1f}  seam ranks "
                   f"{m['seam_rank']:.0f}/{m['seam_d2_rank']:.0f}/{m['seam_hf_rank']:.0f}%")
        rows.append((e, m))
        if fl:
            problems.append(f'{e.name}: ' + ','.join(fl))
        if not quiet:
            print(line)
        if sheets_dir:
            key = e.category
            if e.name.startswith('footstep_'):
                key = 'Footsteps'
            groups.setdefault(key, []).append(draw_tile(x, e.name, sub, loop=(e.kind == 'amb'),
                                                        flags=fl))
    if sheets_dir:
        os.makedirs(sheets_dir, exist_ok=True)
        for key, tiles in groups.items():
            slug = re.sub(r'[^a-z0-9]+', '_', key.lower()).strip('_')
            per = 12 if key == 'Ambience' else 20
            cols = 3 if key == 'Ambience' else 4
            for k in range(0, len(tiles), per):
                p = os.path.join(sheets_dir, f'{slug}_{k // per + 1}.png')
                contact_sheet(tiles[k:k + per], p, cols=cols, title=f'{key} ({k // per + 1})')
                if not quiet:
                    print('sheet:', p)
    return rows, problems


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--only', nargs='*', help='glob patterns of sound names')
    ap.add_argument('--sheets', default=os.path.join(tempfile.gettempdir(), 'wasteland_sfx_sheets'),
                    help='directory for PNG contact sheets')
    ap.add_argument('--no-sheets', action='store_true')
    ap.add_argument('--ffmpeg-lufs', action='store_true', help='cross-check loop LUFS with ffmpeg')
    a = ap.parse_args()
    rows, problems = analyze(a.only, None if a.no_sheets else a.sheets, a.ffmpeg_lufs)
    print(f'\n{len(rows)} files analysed, {len(problems)} problem(s)')
    for p in problems:
        print('  !', p)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
