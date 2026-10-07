#!/usr/bin/env python3
"""build_all.py -- regenerate every Wasteland Harvest SFX and ambience file, deterministically.

    python3 tools/audio/sfx/build_all.py                       # everything (4 worker processes)
    python3 tools/audio/sfx/build_all.py --only 'ui_*' amb_rain
    python3 tools/audio/sfx/build_all.py --jobs 2 --no-readme

Outputs
  audio/sfx/<name>.wav        16-bit PCM mono 44.1 kHz one-shots (variants <name>_N.wav)
  audio/ambience/<name>.ogg   Vorbis q5 stereo 44.1 kHz seamless loops (30-60 s)
  audio/README.md             only the "SFX & ambience" section is (re)written

Every sound has a fixed seed derived from its name, so builds are bit-for-bit repeatable (the OGG
writer uses ffmpeg's bitexact flags).  Requirements: Python 3, numpy, scipy, ffmpeg with libvorbis.

Mastering applied to every one-shot (finalize_sfx): DC-blocking high-pass, leading silence
trimmed (onset < 1 ms), trailing silence trimmed below -62 dB re peak, raised-cosine fade-in
(0.6 ms) and fade-out so the first and last samples are exactly zero, then sample-peak
normalisation to the per-sound target and a per-category ceiling on max momentary loudness (so
sustained sounds don't outshout short ones sharing a peak target).  Ambience loops are generated circularly (every layer wraps
around the loop point), DC-removed, loudness-normalised to their LUFS target, encoded, decoded
again and checked for a seam discontinuity.
"""
from __future__ import annotations

import argparse
import fnmatch
import multiprocessing as mp
import os
import re
import sys
import time
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import synth as S  # noqa: E402
import analyze as A  # noqa: E402
from registry import REGISTRY, UI, FARM, COMBAT, AMBIENCE  # noqa: E402
import gen_ui  # noqa: E402,F401
import gen_farm  # noqa: E402,F401
import gen_combat  # noqa: E402,F401
import gen_ambience  # noqa: E402,F401

REPO = A.REPO
SFX_DIR = A.SFX_DIR
AMB_DIR = A.AMB_DIR
README = os.path.join(REPO, 'audio', 'README.md')
SEED_BASE = 'wasteland-harvest/sfx/v1/'


def seed_for(name):
    return zlib.crc32((SEED_BASE + name).encode('utf-8'))


# ============================================================================ mastering
def finalize_sfx(x, peak_db, mcap=None):
    x = np.nan_to_num(np.asarray(x, dtype=float))
    if x.ndim != 1:
        x = x.mean(axis=0)
    x = S.dc_block(np.concatenate([x, np.zeros(S.ns(0.03))]), 18.0)
    pk = np.max(np.abs(x))
    if pk <= 0:
        raise ValueError('silent sound')
    loud = np.nonzero(np.abs(x) >= pk * S.undb(-45.0))[0]
    start = max(0, loud[0] - S.ns(0.0004))
    keep = np.nonzero(np.abs(x) >= pk * S.undb(-62.0))[0]
    end = min(len(x), keep[-1] + S.ns(0.003))
    x = x[start:end].copy()
    n = len(x)
    fin = min(n // 4, S.ns(0.0006))
    fout = int(np.clip(0.12 * n, S.ns(0.003), S.ns(0.03)))
    fout = min(fout, n - fin)
    x[:fin] *= S.ramp_in(fin)
    x[-fout:] *= S.ramp_out(fout)
    x -= np.mean(x) * np.hanning(n) / np.mean(np.hanning(n))   # residual DC, zero at the ends
    x = S.normalize_peak(x, peak_db)
    if mcap is not None:
        m = S.momentary_max(x)
        if m > mcap:
            x = x * S.undb(mcap - m)
    return x


def finalize_amb(x, lufs):
    x = np.nan_to_num(np.asarray(x, dtype=float))
    if x.ndim == 1:
        x = np.vstack([x, x])
    x = x - x.mean(axis=-1, keepdims=True)
    x = S.fft_eq(x, lambda f: 1.0 / np.sqrt(1.0 + (20.0 / np.maximum(f, 1e-3)) ** 4))  # circular HP
    cur = S.loudness(x, circular=True)
    x = x * S.undb(lufs - cur)
    pk = np.max(np.abs(x))
    if pk > S.undb(-1.5):   # soft safety limiter (should not trigger for ambience)
        x = np.tanh(x / S.undb(-1.5)) * S.undb(-1.5)
    return x


# ============================================================================ worker
def render(name):
    try:
        return _render(name)
    except Exception:  # report and keep building the rest
        import traceback
        return name, {'secs': 0.0, 'error': traceback.format_exc()}, ['ERROR']


def _render(name):
    e = REGISTRY[name]
    t0 = time.time()
    rng = np.random.default_rng(seed_for(name))
    x = e.fn(rng, **e.kwargs)
    if e.kind == 'sfx':
        y = finalize_sfx(x, e.level, e.mcap)
        path = os.path.join(SFX_DIR, name + '.wav')
        S.write_wav(path, y)
        q, _ = S.read_wav(path)
        m = A.sfx_metrics(q)
        flags = A.sfx_flags(m)
    else:
        y = finalize_amb(x, e.level)
        path = os.path.join(AMB_DIR, name + '.ogg')
        S.write_ogg(path, y)
        q = S.read_audio(path)
        # Vorbis can shift the loudness of very transient material slightly: measure the decoded
        # file and re-encode once with a correction if it missed the target by more than 0.3 dB.
        miss = e.level - S.loudness(q, circular=True)
        if abs(miss) > 0.3:
            y = y * S.undb(miss)
            S.write_ogg(path, y)
            q = S.read_audio(path)
        m = A.amb_metrics(q)
        m['src_len'] = y.shape[-1]
        m['dec_len'] = q.shape[-1]
        flags = A.amb_flags(m)
        if m['src_len'] != m['dec_len']:
            flags.append('LEN')
    m['secs'] = time.time() - t0
    return name, m, flags


# ============================================================================ README section
BEGIN = '<!-- BEGIN SFX & ambience (generated by tools/audio/sfx/build_all.py; do not hand-edit) -->'
END = '<!-- END SFX & ambience -->'


def _section(stats):
    reg = REGISTRY
    L = []
    L.append('## SFX & ambience')
    L.append('')
    L.append(BEGIN)
    L.append('')
    L.append('Every sound effect and ambience loop is synthesised from code in `tools/audio/sfx/` '
             '(no samples or recordings). Regenerate everything (deterministic, fixed per-sound '
             'seeds; ~2 minutes on 4 cores):')
    L.append('')
    L.append('```')
    L.append('python3 tools/audio/sfx/build_all.py            # needs numpy, scipy, ffmpeg+libvorbis')
    L.append('python3 tools/audio/sfx/analyze.py --sheets DIR # QA report + spectrogram contact sheets')
    L.append('```')
    L.append('')
    L.append('- **Code:** `synth.py` (DSP library: oscillators, coloured noise, envelopes, RBJ biquads, '
             'time-varying filters, FM, Karplus-Strong, modal/resonator banks, Klatt formant voice, '
             'bubbles, grains, stick-slip creaks, synthetic-IR reverb, saturation, BS.1770 loudness, '
             'WAV/OGG IO), `gen_ui.py` / `gen_farm.py` / `gen_combat.py` / `gen_ambience.py` (one '
             'generator per sound), `registry.py` (names = engine API contract), `build_all.py`, '
             '`analyze.py`.')
    L.append('- **SFX:** `audio/sfx/<name>.wav`, 16-bit PCM mono 44.1 kHz. Onset < 1 ms (no leading '
             'silence), first and last samples exactly 0 (raised-cosine fades), DC-blocked, '
             'sample-peak normalised: UI about -12 dBFS (hover/blips a touch lower), footsteps '
             'about -16 dBFS, farm/world actions -10 to -4 dBFS, impacts/guns/explosions up to '
             '-1 dBFS; sustained sounds are additionally capped in max momentary loudness (UI -20, '
             'farm -17.5, combat -16 LUFS) so perceived loudness stays consistent.')
    L.append('- **Variants:** files named `<group>_N.wav` are interchangeable takes; pick one at random '
             '(the engine also adds +/-5% pitch). Takes differ in transient, envelope and timbre, not '
             'just pitch.')
    L.append('- **Ambience:** `audio/ambience/<name>.ogg`, Vorbis q5 stereo 44.1 kHz, 30-60 s, '
             'seamless loops (every layer is generated circularly so the last sample flows into the '
             'first; verified after encode/decode), integrated loudness -26 to -22 LUFS. Enable '
             '`loop` on the imported AudioStreamOggVorbis.')
    L.append('')
    groups = {}
    for e in reg.values():
        if e.group:
            groups.setdefault(e.group, []).append(e.name)
    L.append('### Variant groups')
    L.append('')
    L.append('| Group | Files |')
    L.append('|---|---|')
    for g, names in groups.items():
        L.append(f'| `{g}` | {len(names)} (`{names[0]}` .. `{names[-1]}`) |')
    L.append('')
    for cat in (UI, FARM, COMBAT):
        ents = [e for e in reg.values() if e.category == cat]
        L.append(f'### {cat} ({len(ents)} files)')
        L.append('')
        L.append('| File | Description | Duration | Peak |')
        L.append('|---|---|---|---|')
        for e in ents:
            m = stats.get(e.name)
            dur = f"{m['dur']:.2f} s" if m else '?'
            pk = f"{m['peak_db']:.1f} dBFS" if m else '?'
            L.append(f'| `{e.name}.wav` | {e.desc} | {dur} | {pk} |')
        L.append('')
    ents = [e for e in reg.values() if e.category == AMBIENCE]
    L.append(f'### Ambience loops ({len(ents)} files)')
    L.append('')
    L.append('| File | Description | Duration | Loudness |')
    L.append('|---|---|---|---|')
    for e in ents:
        m = stats.get(e.name)
        dur = f"{m['dur']:.1f} s" if m else '?'
        lu = f"{m['lufs']:.1f} LUFS" if m else '?'
        L.append(f'| `{e.name}.ogg` | {e.desc} | {dur} | {lu} |')
    L.append('')
    L.append(END)
    return '\n'.join(L) + '\n'


def update_readme(stats):
    sec = _section(stats)
    if os.path.exists(README):
        text = open(README, encoding='utf-8').read()
        if BEGIN in text and END in text:
            a = text.index(BEGIN)
            # include our own '## SFX & ambience' heading just above the marker
            h = text.rfind('## SFX & ambience', 0, a)
            a = h if h != -1 and text[h:a].count('\n') <= 3 else a
            b = text.index(END) + len(END)
            text = text[:a] + sec.rstrip('\n') + text[b:]
        else:
            m = re.search(r'^## SFX & ambience.*?(?=^## |\Z)', text, flags=re.S | re.M)
            if m:
                text = text[:m.start()] + sec + '\n' + text[m.end():].lstrip('\n')
            else:
                text = text.rstrip('\n') + '\n\n' + sec
    else:
        text = '# Audio\n\n' + sec
    with open(README, 'w', encoding='utf-8') as f:
        f.write(text)


def _load_existing_stats():
    """Measure files already on disk (used to fill README rows not rebuilt this run)."""
    stats = {}
    for e in REGISTRY.values():
        p = os.path.join(SFX_DIR if e.kind == 'sfx' else AMB_DIR,
                         e.name + ('.wav' if e.kind == 'sfx' else '.ogg'))
        if os.path.exists(p):
            if e.kind == 'sfx':
                stats[e.name] = A.sfx_metrics(S.read_wav(p)[0])
            else:
                stats[e.name] = A.amb_metrics(S.read_audio(p))
    return stats


# ============================================================================ main
def main():
    ap = argparse.ArgumentParser(description='Regenerate Wasteland Harvest SFX + ambience.')
    ap.add_argument('--only', nargs='*', help='glob patterns of sound names to rebuild')
    ap.add_argument('--jobs', type=int, default=min(4, os.cpu_count() or 1))
    ap.add_argument('--no-readme', action='store_true', help='do not touch audio/README.md')
    ap.add_argument('--list', action='store_true', help='list registered sounds and exit')
    a = ap.parse_args()
    if a.list:
        for e in REGISTRY.values():
            print(f'{e.kind:3s} {e.category:16s} {e.name:24s} {e.level:6.1f}  {e.desc}')
        print(len(REGISTRY), 'sounds')
        return 0
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(AMB_DIR, exist_ok=True)
    names = [n for n in REGISTRY if not a.only or any(fnmatch.fnmatch(n, p) for p in a.only)]
    names.sort(key=lambda n: -REGISTRY[n].cost)          # long jobs first
    t0 = time.time()
    results = {}
    problems = []
    if a.jobs > 1 and len(names) > 1:
        with mp.get_context('fork').Pool(a.jobs) as pool:
            it = pool.imap_unordered(render, names)
            for name, m, flags in it:
                results[name] = m
                if flags:
                    problems.append((name, flags))
                print(f'  {name:24s} {m["secs"]:5.1f}s' + ('  ! ' + ','.join(flags) if flags else ''),
                      flush=True)
                if 'error' in m:
                    print(m['error'], flush=True)
    else:
        for n in names:
            name, m, flags = render(n)
            results[name] = m
            if flags:
                problems.append((name, flags))
            print(f'  {name:24s} {m["secs"]:5.1f}s' + ('  ! ' + ','.join(flags) if flags else ''),
                  flush=True)
            if 'error' in m:
                print(m['error'], flush=True)
    n_sfx = sum(1 for n in names if REGISTRY[n].kind == 'sfx')
    print(f'\nbuilt {n_sfx} SFX + {len(names) - n_sfx} ambience loops in {time.time() - t0:.1f}s')
    if not a.no_readme:
        stats = _load_existing_stats() if a.only else {}
        stats.update({k: v for k, v in results.items() if 'error' not in v})
        update_readme(stats)
        print('updated', os.path.relpath(README, REPO), '(SFX & ambience section)')
    if problems:
        print(f'{len(problems)} file(s) with QA flags:')
        for n, fl in problems:
            print('  !', n, ','.join(fl))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
