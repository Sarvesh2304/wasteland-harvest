"""parts.py -- reusable higher-level sound 'parts' built from synth.py primitives.

Each part returns a mono float array normalised to a peak of about 1.0 (so callers mix with
explicit gains): whooshes, wood knocks, metal clanks, stone clicks, coin clinks, soil/gravel
crunch, debris clatter, water droplets, latch clicks, hinge creaks, body thuds and creature
voices.
"""
import numpy as np

import synth as S
from synth import ns, Mix


def norm(x, peak=1.0):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


# ---------------------------------------------------------------------------- air
def whoosh(rng, dur, f_pts, q=1.0, amp_pts=None, color=-3.0, body=0.0, body_lp=500.0,
           whistle=0.0, whistle_q=12.0):
    """Air movement: coloured noise through a band-pass whose centre follows f_pts [(t, Hz)],
    amplitude amp_pts [(t, a)] (default: smooth hump peaking at 45 %).  body adds a low-passed
    'weight' layer; whistle adds a narrow resonant edge tone (blades)."""
    n = ns(dur)
    src = S.colored(n, rng, color)
    fc = S.env_pts(n, f_pts, 'exp')
    y = S.tvf(src, 'bp', fc, q)
    if whistle:
        w = S.tvf(src, 'bp', fc * 1.15, whistle_q)
        y = y + whistle * norm(w) * np.std(y) * 4.0
    if body:
        y = y + body * S.butter(src, 'lp', body_lp, 2) * np.std(y) / (np.std(S.butter(src, 'lp', body_lp, 2)) + 1e-9)
    env = S.env_pts(n, amp_pts, 'cos') if amp_pts else S.env_bell(n, 0.45, 1.6, 2.2)
    return norm(S.end_fade(y * env, frac=0.1))


# ---------------------------------------------------------------------------- wood
PLANK = (1.0, 2.31, 3.92, 5.63, 7.8)
FREE_BAR = (1.0, 2.756, 5.404, 8.933)


def wood_knock(rng, f1, dur=0.3, ratios=PLANK, tau1=0.05, hardness=0.4, cavity=None,
               cavity_amp=0.5, contact=0.15, contact_lp=3000.0, amps=None, detune=0.03):
    """Struck wood (plank, door, crate, log).  Modes decay faster with frequency; cavity adds a
    hollow low resonance (Hz) for boxes / floors; contact = noise transient level."""
    n = ns(dur)
    r = np.asarray(ratios) * (1.0 + detune * rng.uniform(-1, 1, len(ratios)))
    r[0] = 1.0
    fr = f1 * r
    am = np.asarray(amps) if amps is not None else r ** -0.6 * rng.uniform(0.6, 1.0, len(r))
    ta = tau1 / r ** 0.9 * rng.uniform(0.8, 1.2, len(r))
    y = S.strike(n, fr, am, ta, attack=0.0006, hardness=hardness, rng=rng, release=dur * 0.3)
    if cavity:
        y += cavity_amp * S.strike(n, [cavity], [1.0], [tau1 * 0.8], attack=0.001)
    if contact:
        c = S.burst(0.01, rng, 0.0002, 0.0015, filt=[('lp', contact_lp), ('hp', 300)])
        m = min(n, len(c))
        y[:m] += contact * norm(c)[:m] * np.max(np.abs(y))
    return norm(y)


def creak(rng, dur, rate_pts, freqs, taus, amp_pts=None, jitter=0.12, gains=None):
    """Stick-slip creak (hinge, tree, rope, metal groan).  rate_pts [(t, Hz)] sets pitch."""
    n = ns(dur)
    rate = S.env_pts(n, rate_pts, 'exp')
    amp = S.env_pts(n, amp_pts, 'cos') if amp_pts else S.env_bell(n, 0.3, 1.2, 1.5)
    y = S.creak(n, rng, rate, freqs, taus, gains=gains, jitter=jitter, amp=amp)
    return norm(S.end_fade(y, frac=0.08))


# ---------------------------------------------------------------------------- metal
def metal_clank(rng, f1, dur=0.8, count=8, tau1=0.4, rust=0.5, hardness=0.7, contact=0.3,
                rattle=0, spread=(0.35, 1.2), doublet=0.004, thud=0.3):
    """Struck metal (sheet, pipe, can, latch).  rust 0..1 shortens & roughens the ring;
    rattle = number of loose secondary impacts."""
    n = ns(dur)
    f, a, t = S.metal_modes(rng, f1, count, spread, tau1 * (1.0 - 0.6 * rust), 0.7, doublet)
    y = S.strike(n, f, a, t, attack=0.0003, hardness=hardness, rng=rng, release=dur * 0.3)
    if rust:
        rough = 1.0 + rust * 0.35 * S.smooth_noise(n, rng, 140.0)
        y *= rough
    pk = np.max(np.abs(y))
    if contact:
        c = S.burst(0.012, rng, 0.0001, 0.0012, filt=[('hp', 900), ('lp', 9000)])
        m = min(n, len(c))
        y[:m] += contact * norm(c)[:m] * pk
    if thud:
        th = S.thump(min(dur, 0.12), 2.2 * f1 if f1 < 300 else 260.0, 90.0, 0.008, 0.02)
        m = min(n, len(th))
        y[:m] += thud * norm(th)[:m] * pk
    for _ in range(rattle):
        t0 = rng.uniform(0.012, 0.09)
        i = int(t0 * S.SR)
        ff, aa, tt = S.metal_modes(rng, f1 * rng.uniform(1.6, 3.2), 5, (0.4, 1.0), 0.05, 0.7, 0)
        r = S.strike(ns(0.15), ff, aa, tt, attack=0.0002, hardness=0.8, rng=rng)
        m = min(n - i, len(r))
        if m > 0:
            y[i:i + m] += rng.uniform(0.12, 0.3) * pk * norm(r)[:m]
    return norm(y)


def latch(rng, f=2200.0, dur=0.08, body=0.4, vel=1.0):
    """Small metal latch / mechanism click."""
    n = ns(dur)
    y = S.strike(n, [f, f * 1.63, f * 2.41, f * 3.2], [1.0, 0.6, 0.35, 0.2],
                 [0.012, 0.008, 0.005, 0.003], attack=0.0001, hardness=0.85, rng=rng)
    c = S.burst(0.006, rng, 0.0001, 0.0008, filt=[('hp', 1500), ('lp', 9000)])
    y[:len(c)] += 0.6 * norm(c) * np.max(np.abs(y))
    if body:
        b = S.thump(min(dur, 0.05), 420.0, 220.0, 0.004, 0.008)
        y[:len(b)] += body * norm(b) * np.max(np.abs(y))
    return vel * norm(y)


# ---------------------------------------------------------------------------- stone / soil
def grit(rng, dur, count, f_lo, f_hi, tau, attack=0.002, q=1.2, dlo=0.0006, dhi=0.004,
         amp_sigma=0.6, kind='bp'):
    """Crunchy grain cloud with an attack/decay density envelope (soil, gravel, crumbs)."""
    n = ns(dur)
    dens = S.env_ad(n, attack, tau)
    y = S.grains(n, rng, count, dens, f_lo, f_hi, q, dlo, dhi, amp_sigma, kind)
    return norm(S.end_fade(y, frac=0.1))


def stone_click(rng, f=None, dur=0.05, vel=1.0):
    """Very damped stone-on-stone tick (2-5 kHz), zero-mean."""
    f = f or rng.uniform(1800, 4200)
    n = ns(dur)
    y = S.strike(n, [f, f * rng.uniform(1.4, 1.8), f * rng.uniform(2.2, 2.9)],
                 [1.0, 0.6, 0.3], [0.004, 0.0025, 0.0015], attack=0.0001, hardness=0.8, rng=rng)
    c = S.burst(0.004, rng, 0.0001, 0.0006, filt=[('bp', f, 0.8)])
    y[:len(c)] += 0.5 * norm(c) * np.max(np.abs(y))
    return vel * norm(y)


def debris(rng, dur, count, t_pts, size=(0.3, 1.0), stone=True, metal=0.0, wood=0.0):
    """Falling-debris clatter: count small impacts distributed by density t_pts [(t, d)]."""
    n = ns(dur)
    m = Mix(dur + 0.3)
    dens = S.env_pts(n, t_pts, 'lin')
    times = np.sort(S.sample_times(dens, count, rng)) / S.SR
    for t in times:
        sz = rng.uniform(*size)
        u = rng.random()
        if u < metal:
            f1 = rng.uniform(900, 2600) / (0.5 + sz)
            x = metal_clank(rng, f1, 0.25, 5, 0.08, 0.7, 0.8, 0.4, 0, thud=0.0)
        elif u < metal + wood:
            x = wood_knock(rng, rng.uniform(300, 900) / (0.5 + sz), 0.12, tau1=0.02, hardness=0.6)
        else:
            x = stone_click(rng, rng.uniform(1200, 4500) / (0.4 + 0.8 * sz), 0.06)
            if sz > 0.7:
                x = x + 0.6 * norm(S.burst(0.06, rng, 0.0005, 0.01, filt=[('lp', 900)]))
        m.add(x, t, sz * rng.uniform(0.5, 1.0))
    y = m.out()[:n]
    return norm(S.end_fade(y, frac=0.1))


def body_thud(rng, f0=120.0, f1=55.0, tau=0.08, lp=700.0, noise=0.6, dur=0.3, sweep=0.02):
    """Heavy low thud (body/object hitting ground): pitch-dropping sine + low-passed noise."""
    th = S.thump(dur, f0, f1, sweep, tau)
    nb = S.burst(dur, rng, 0.0008, tau * 0.35, filt=[('lp', lp, 0.7)])
    return norm(norm(th) + noise * norm(nb))


# ---------------------------------------------------------------------------- coins / water
def coin_clink(rng, f1=None, dur=0.7, hardness=0.7, decay=1.0):
    """Single coin ring (thin disc partials, shimmering doublets)."""
    f1 = f1 or rng.uniform(1900, 2600)
    n = ns(dur)
    r = np.array([1.0, 1.47, 2.31, 3.07, 3.62]) + np.r_[0, rng.uniform(-0.04, 0.04, 4)]
    f = f1 * r
    a = np.array([1.0, 0.7, 0.45, 0.28, 0.18])
    t = np.array([0.32, 0.22, 0.14, 0.09, 0.06]) * rng.uniform(0.75, 1.2) * decay
    f = np.concatenate([f, f * 1.0035])
    a = np.concatenate([a, a * 0.5])
    t = np.concatenate([t, t * 0.9])
    y = S.strike(n, f, a, t, attack=0.0003, hardness=hardness, rng=rng, release=dur * 0.35)
    c = S.burst(0.004, rng, 0.0001, 0.0006, filt=[('hp', 2500), ('lp', 9000)])
    y[:len(c)] += 0.25 * norm(c) * np.max(np.abs(y))
    return norm(y)


def drops(rng, dur, count, dens_pts, f_lo=800.0, f_hi=3200.0, eps=(0.15, 0.6), amp_sigma=0.5):
    """Cloud of water droplets / bubbles (Minnaert model) with a density envelope."""
    n = ns(dur)
    y = np.zeros(n + ns(0.3))
    dens = S.env_pts(n, dens_pts, 'lin')
    for s in np.sort(S.sample_times(dens, count, rng)):
        f0 = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        b = S.bubble(f0, rng.lognormal(0, amp_sigma), rng.uniform(*eps))
        y[s:s + len(b)] += b
    return norm(S.end_fade(y[:n], frac=0.1))


# ---------------------------------------------------------------------------- voices
def creature(rng, dur, f0_pts, vowel_path, scale=1.0, bw_scale=1.0, amp_pts=None, jitter=0.01,
             shimmer=0.05, breath=0.05, oq=0.6, tilt=3000.0, vib=(0.0, 0.0), trem=(0.0, 0.0),
             fry=0.0, fry_jitter=0.25, rasp=0.0, rasp_bp=(1800.0, 0.7), f0_mode='cos'):
    """Formant-synthesised voice/animal call.
    vib = (rate Hz, depth fraction) pitch vibrato; trem = (rate, depth) amplitude tremolo;
    fry mixes in an irregular glottal pulse train (growl / creak); rasp adds turbulent noise
    modulated by the voice envelope (hoarse breath)."""
    n = ns(dur)
    t = S.tvec(n)
    f0 = S.env_pts(n, f0_pts, f0_mode)
    if vib[1]:
        f0 = f0 * (1.0 + vib[1] * np.sin(2 * np.pi * vib[0] * t + rng.uniform(0, 6.28)))
    F, B = S.vowel_tracks(n, vowel_path, scale, bw_scale)
    src = S.glottal(f0 * (1.0 + jitter * S.smooth_noise(n, rng, 45.0)), n, oq=oq)
    if shimmer:
        src *= 1.0 + shimmer * S.smooth_noise(n, rng, 30.0)
    src = norm(src)
    if fry:
        cs = norm(S.creaky_source(f0 * 0.5, n, rng, jitter=fry_jitter, alt=0.5))
        src = (1.0 - fry) * src + fry * cs
    if breath:
        ph = S.phase(f0, n) % 1.0
        asp = S.butter(S.white(n, rng), 'hp', 900.0) * (0.35 + 0.65 * (ph < oq))
        src = src + breath * norm(asp)
    src = S.onepole(src, tilt)
    y = S.formant_cascade(src, F, B)
    y = norm(y)
    if rasp:
        nz = S.tvf(S.colored(n, rng, -1.0), 'bp', F[1] * 1.1, rasp_bp[1])
        nz = nz + 0.6 * S.biquad(S.colored(n, rng, -1.0), 'bp', rasp_bp[0], 0.8)
        y = y + rasp * norm(nz) * (0.6 + 0.4 * np.abs(norm(S.onepole(np.abs(y), 30.0))))
    if trem[1]:
        y *= 1.0 - trem[1] * (0.5 + 0.5 * np.sin(2 * np.pi * trem[0] * t))
    if amp_pts:
        y *= S.env_pts(n, amp_pts, 'cos')
    return norm(S.end_fade(y, frac=0.05))
