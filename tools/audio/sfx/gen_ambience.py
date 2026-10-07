"""gen_ambience.py -- seamless stereo ambience loops (30-60 s).

Every layer is built *circularly* so the loop point is invisible by construction:
  * noise beds are FFT-shaped (exactly periodic over the loop),
  * control curves (gusts, drift, flicker) are periodic smooth noise,
  * time-varying filters are warm-started with the loop's own tail (synth.circ_apply),
  * discrete events (birds, crickets, drops, crackles, chimes...) wrap around the end
    (synth.circ_add / circular convolution of impulse trains),
  * reverb is circular convolution with a synthetic IR,
  * stationary sinusoids are snapped to an integer number of cycles per loop (lfreq).
Each generator returns a (2, n) float array; build_all.py normalises it to the registered LUFS.
"""
import numpy as np

import synth as S
from synth import SR, ns, note, Mix
import parts as P
from parts import norm
from registry import amb


# ============================================================================ loop helpers
def lfreq(f, L):
    """Snap a frequency so it completes an integer number of cycles in a loop of L samples."""
    secs = L / SR
    return max(1, round(f * secs)) / secs


def stereo_noise(L, rng, slope=-3.0, corr=0.3):
    c, a, b = (S.colored(L, rng, slope) for _ in range(3))
    k, j = np.sqrt(corr), np.sqrt(1.0 - corr)
    return np.vstack([k * c + j * a, k * c + j * b])


def band(lo=None, hi=None, order=2, peak=None):
    """Smooth magnitude response for fft_eq: Butterworth-like HP at lo, LP at hi, optional
    (freq, gain_db, octave_width) bump."""
    def g(f):
        f = np.maximum(f, 1e-3)
        r = np.ones_like(f)
        if lo:
            r /= np.sqrt(1.0 + (lo / f) ** (2 * order))
        if hi:
            r /= np.sqrt(1.0 + (f / hi) ** (2 * order))
        if peak:
            fc, gdb, w = peak
            r *= 10 ** (gdb / 20.0 * np.exp(-0.5 * (np.log2(f / fc) / w) ** 2))
        return r
    return g


def eq(x, **kw):
    return S.fft_eq(x, band(**kw))


def cdist(x, amount):
    """Circular (zero-phase) version of synth.distance for whole loop layers."""
    fc = 14000.0 * (1.2 / 14.0) ** amount
    return eq(x, hi=fc) * (1.0 - 0.5 * amount)


def tv(x, kind, fc, q=0.707, warm=1.0, block=64):
    """Circular time-varying biquad on a mono or stereo loop; fc / q may be per-sample arrays."""
    fc = S._arr(fc, x.shape[-1])
    q = S._arr(q, x.shape[-1])
    f = lambda a, c, qq: S.tvf(a, kind, c, qq, block=block)  # noqa: E731
    if x.ndim == 1:
        return S.circ_apply(f, x, warm, fc, q)
    return np.vstack([S.circ_apply(f, x[c], warm, fc, q) for c in range(x.shape[0])])


def impulses(L, rng, rate, amp_sigma=0.5, signed=True):
    """Bernoulli/Poisson impulse train; rate = events per second (scalar or per-sample)."""
    p = S._arr(rate, L) / SR
    hit = rng.random(L) < p
    imp = np.zeros(L)
    k = int(hit.sum())
    a = rng.lognormal(0.0, amp_sigma, k)
    if signed:
        a *= rng.choice([-1.0, 1.0], k)
    imp[hit] = a
    return imp


def place(buf, sig, t, gain=1.0, pan=0.0):
    """Circularly add a mono (panned) or stereo event to a stereo loop buffer."""
    if sig.ndim == 1:
        sig = S.panned(sig, pan)
    S.circ_add(buf, sig, int(round(t * SR)) % buf.shape[-1], gain)


def at_lufs(x, target):
    """Scale a loop layer to a given integrated loudness (relative balancing between layers)."""
    cur = S.loudness(x, circular=True)
    return x * S.undb(target - cur) if np.isfinite(cur) and cur > -90 else x


def gust_env(L, rng, rate=0.08, lo=0.3, hi=1.0, power=1.3):
    return S.periodic_env(L, rng, rate, lo, hi, power)


# ============================================================================ wind / air
def wind(L, rng, gust, f_lo=250.0, f_hi=900.0, q=0.8, slope=-3.0, corr=0.35, floor=0.25):
    """Wind bed: stereo coloured noise through a band-pass whose centre and level follow gust."""
    x = stereo_noise(L, rng, slope, corr)
    fc = f_lo * (f_hi / f_lo) ** gust
    y = tv(x, 'bp', fc, q)
    return y * (floor + (1.0 - floor) * gust)


def whistles(L, rng, gust, centers, q=22.0, drift=0.03, power=2.0):
    """Narrow resonant 'howl' tones riding on the wind (aeolian whistles through gaps)."""
    out = np.zeros((2, L))
    for f0, pan in centers:
        d = 1.0 + drift * S.smooth_noise(L, rng, 0.05)
        y = tv(S.colored(L, rng, -1.0), 'bp', f0 * d, q)
        a = S.periodic_env(L, rng, 0.06, 0.0, 1.0, 1.5) * gust ** power
        out += S.panned(norm(y) * a, pan)
    return out


def rustle(L, rng, density, rate=90.0, bands=((2200, 1.0), (3600, 1.2), (5200, 1.4))):
    """Leaf / grass rustle: impulse trains (rate * density) through short band-passed kernels."""
    out = np.zeros((2, L))
    for ch in range(2):
        for fc, q in bands:
            imp = impulses(L, rng, rate * density / len(bands), 0.6)
            k = S.biquad(S.white(ns(0.004), rng) * np.exp(-np.arange(ns(0.004)) / ns(0.001)), 'bp', fc, q)
            out[ch] += S.circ_conv(imp, k)
    return out


# ============================================================================ birds & insects
def bird_note(rng, f_pts, dur, fm_rate=0.0, fm_depth=0.0, harm=None, attack=0.004, release=0.012):
    n = ns(dur)
    f = S.env_pts(n, f_pts, 'exp')
    env = S.env_pts(n, [(0, 0), (attack, 1.0), (max(attack, dur - release), 0.85), (dur, 0)], 'cos')
    return S.chirp(n, f, env, fm_rate, fm_depth, harm)


def bird_phrase(rng, kind):
    m = Mix(3.0)
    if kind == 'feebee':          # clear two-note whistle ("fee-bee"), 3.3-4.1 kHz
        f1 = rng.uniform(3700, 4100)
        f2 = f1 * rng.uniform(0.82, 0.88)
        m.add(bird_note(rng, [(0, f1), (0.25, f1 * 0.98)], 0.26, 35, 0.006, {2: 0.05}), 0.0)
        m.add(bird_note(rng, [(0, f2), (0.3, f2 * 0.99)], 0.30, 35, 0.006, {2: 0.05}), 0.33)
    elif kind == 'trill':         # warbler: rapid run of down-sweeps 5.5 -> 3.5 kHz
        k = int(rng.integers(8, 15))
        rate = rng.uniform(13, 18)
        fa = rng.uniform(4800, 5600)
        fb = fa * rng.uniform(0.6, 0.72)
        for i in range(k):
            a = np.sin(np.pi * (i + 0.5) / k) ** 0.7
            m.add(bird_note(rng, [(0, fa * (1 - 0.01 * i)), (0.035, fb)], 0.035), i / rate, a)
    elif kind == 'chip':          # sparrow-like chips 4-6 kHz
        t = 0.0
        for _ in range(int(rng.integers(2, 6))):
            fa = rng.uniform(4200, 6000)
            m.add(bird_note(rng, [(0, fa), (0.025, fa * 0.75)], 0.025), t, rng.uniform(0.6, 1.0))
            t += rng.uniform(0.09, 0.25)
    elif kind == 'carol':         # robin-like warbled phrase 2-3.5 kHz
        t = 0.0
        base = rng.uniform(2300, 2900)
        for _ in range(int(rng.integers(3, 6))):
            d = rng.uniform(0.12, 0.2)
            f0 = base * rng.choice([1.0, 1.12, 1.26, 0.89, 1.33])
            m.add(bird_note(rng, [(0, f0 * 0.92), (d * 0.3, f0 * 1.05), (d, f0 * 0.95)], d,
                            rng.uniform(55, 85), rng.uniform(0.03, 0.07), {2: 0.15}), t)
            t += d + rng.uniform(0.04, 0.09)
    elif kind == 'coo':           # mourning-dove-ish "hoo-HOOO hoo hoo", soft and low
        f = rng.uniform(520, 600)
        for (t, d, fr, a) in ((0, 0.35, 1.0, 0.8), (0.45, 0.55, 1.08, 1.0), (1.1, 0.32, 1.0, 0.75),
                              (1.5, 0.32, 0.98, 0.65)):
            n = ns(d)
            ff = f * fr * S.env_pts(n, [(0, 0.96), (d * 0.3, 1.02), (d, 0.97)], 'cos')
            tone = S.sine(ff, n) + 0.12 * S.sine(2 * ff, n)
            tone += 0.15 * norm(S.butter(S.white(n, rng), 'lp', 900.0))
            tone *= S.env_pts(n, [(0, 0), (0.06, 1.0), (d - 0.1, 0.8), (d, 0)], 'cos')
            m.add(tone, t, a)
    return norm(m.out())


def bird_layer(L, rng, count, kinds, dist=(0.15, 0.45)):
    out = np.zeros((2, L))
    secs = L / SR
    for _ in range(count):
        kind = rng.choice(kinds)
        ph = bird_phrase(rng, kind)
        ph = S.distance(ph, rng.uniform(*dist))
        # some birds repeat their phrase a couple of times
        reps = int(rng.integers(1, 4)) if kind != 'coo' else 1
        t0 = rng.uniform(0, secs)
        pan = rng.uniform(-0.8, 0.8)
        g = rng.uniform(0.4, 1.0)
        for r in range(reps):
            place(out, ph, t0 + r * rng.uniform(1.2, 2.6), g * rng.uniform(0.8, 1.0), pan)
    return out


def flyby(rng, dur=2.6):
    """A buzzing insect passing by: wing-beat buzz with Doppler shift and a pan sweep."""
    n = ns(dur)
    t = S.tvec(n)
    tc = dur * rng.uniform(0.4, 0.6)
    f0 = rng.uniform(190, 240)
    f = f0 * (1.0 + 0.045 * np.tanh((tc - t) / 0.35)) * (1.0 + 0.01 * S.smooth_noise(n, rng, 20.0))
    src = S.saw(f, n)
    src = S.butter(src, 'bp', (250.0, 3500.0), 2)
    src = S.peq(src, 900.0, 6.0, 1.5)
    amp = 1.0 / (1.0 + ((t - tc) / 0.45) ** 2)
    amp *= S.env_pts(n, [(0, 0), (0.2, 1), (dur - 0.2, 1), (dur, 0)], 'cos')
    y = norm(src * amp)
    p0 = rng.choice([-1.0, 1.0]) * 0.8
    pan = p0 + (-2.0 * p0) * np.clip(t / dur, 0, 1)
    a = (pan + 1.0) * np.pi / 4.0
    return np.vstack([np.cos(a) * y, np.sin(a) * y])


def stridulation(rng, dur=None):
    """Grasshopper-like dry ticking burst."""
    dur = dur or rng.uniform(0.6, 1.4)
    n = ns(dur)
    rate = rng.uniform(25, 40)
    imp = np.zeros(n)
    k = np.arange(0, dur, 1.0 / rate)
    for tk in k:
        i = int((tk + rng.uniform(-0.003, 0.003)) * SR)
        if 0 <= i < n:
            imp[i] = rng.uniform(0.6, 1.0) * rng.choice([-1, 1])
    ker = S.biquad(S.white(ns(0.003), rng), 'bp', rng.uniform(4500, 6000), 2.0)
    y = np.convolve(imp, ker)[:n] * S.env_pts(n, [(0, 0.3), (0.1, 1), (dur - 0.1, 1), (dur, 0)], 'cos')
    return norm(y)


# ============================================================================ water
def drop_bed(L, rng, rate, bands=((1800, 2.0), (3000, 2.0), (4500, 2.5)), tau=0.0012):
    """Raindrop ticks: impulse trains through short resonant clicks (leaves, wood, ground)."""
    out = np.zeros((2, L))
    for ch in range(2):
        for fc, q in bands:
            imp = impulses(L, rng, rate / len(bands), 0.7)
            k = ns(0.008)
            ker = S.biquad(S.white(k, rng) * np.exp(-np.arange(k) / (tau * SR)), 'bp', fc, q)
            out[ch] += S.circ_conv(imp, ker)
    return out


def bubble_bed(L, rng, rate, f_lo, f_hi, bins=20, eps=0.25, amp_sigma=0.6, tilt=0.5):
    """Many Minnaert bubbles (stream gurgle, puddle plinks) via per-frequency-bin impulse trains
    convolved with bubble kernels.  rate: events/s (scalar or per-sample) summed over bins."""
    fs = np.geomspace(f_lo, f_hi, bins)
    w = fs ** -tilt
    w /= w.sum()
    out = np.zeros(L)
    for f, wi in zip(fs, w):
        imp = impulses(L, rng, S._arr(rate, L) * wi, amp_sigma)
        k = S.bubble(f * rng.uniform(0.97, 1.03), 1.0, eps)
        out += S.circ_conv(imp, k)
    return out


def rain_layers(L, rng, heavy=False):
    """Steady rain: broadband hiss, a body 'patter', close drop ticks and puddle plinks."""
    inten = S.periodic_env(L, rng, 0.15, 0.85, 1.15, 1.0)
    if heavy:
        hiss = eq(stereo_noise(L, rng, -1.5, 0.15), lo=180, hi=9000, peak=(1500, 3.0, 1.5))
    else:
        hiss = eq(stereo_noise(L, rng, -1.0, 0.15), lo=350, hi=10000, peak=(3200, 3.0, 1.2))
    hiss = hiss * inten
    body = eq(stereo_noise(L, rng, -4.0, 0.3), lo=80, hi=700 if heavy else 500)
    body *= inten * (1.0 + 0.25 * np.vstack([S.smooth_noise(L, rng, 6.0), S.smooth_noise(L, rng, 6.0)]))
    drops = drop_bed(L, rng, 260.0 if heavy else 120.0)
    plinks = np.vstack([bubble_bed(L, rng, 14.0 if heavy else 8.0, 1200, 4000, 12, 0.3),
                        bubble_bed(L, rng, 14.0 if heavy else 8.0, 1200, 4000, 12, 0.3)])
    return hiss, body, drops, plinks


# ============================================================================ loops
@amb('amb_farm_day', lufs=-24.0,
     desc='Farm by day: gentle gusting wind with leaf rustle, sparse distant FM birdsong, an '
          'occasional passing bee and grasshopper ticks')
def amb_farm_day(rng):
    L = ns(48.0)
    gust = gust_env(L, rng, 0.07, 0.3, 1.0)
    w = at_lufs(eq(wind(L, rng, gust, 300, 900, 0.7, -3.0, 0.3), hi=2500), -31.0)
    r = at_lufs(rustle(L, rng, gust ** 2.5, 70.0), -39.0)
    birds = bird_layer(L, rng, 16, ['feebee', 'trill', 'chip', 'carol', 'carol', 'chip'])
    birds = at_lufs(S.circ_reverb(birds, 'outdoor', wet=0.35), -27.0)
    ins = np.zeros((2, L))
    for t in rng.uniform(0, 48.0, 2):
        place(ins, flyby(rng), t, 1.0)
    for t in rng.uniform(0, 48.0, 5):
        place(ins, stridulation(rng), t, rng.uniform(0.3, 0.6), rng.uniform(-0.7, 0.7))
    ins = at_lufs(ins, -33.0)
    return w + r + birds + ins


def cricket(L, rng, fc, pulse_s, pulse_per, n_pulses, chirp_per, gating=True):
    """One cricket: n_pulses tone pulses (~fc Hz) per chirp; chirp period snapped to the loop."""
    secs = L / SR
    K = max(1, round(secs / chirp_per))
    per = secs / K
    pn = ns(pulse_s)
    t = S.tvec(pn)
    pulse = S.sine(fc * (1.0 - 0.02 * t / pulse_s), pn) * np.sin(np.pi * np.arange(pn) / pn) ** 1.5
    pulse += 0.05 * S.sine(2 * fc * (1.0 - 0.02 * t / pulse_s), pn) * np.sin(np.pi * np.arange(pn) / pn) ** 2
    chirp = Mix(n_pulses * pulse_per + pulse_s)
    for i in range(n_pulses):
        chirp.add(pulse, i * pulse_per, 0.7 if i == 0 else 1.0)
    ch = chirp.out()
    out = np.zeros(L)
    ph = rng.uniform(0, per)
    for k in range(K):
        tk = ph + k * per + rng.normal(0, 0.04 * per)
        S.circ_add(out, ch, int(tk * SR) % L, rng.uniform(0.85, 1.0))
    if gating:
        g = S.periodic_env(L, rng, 0.08, 0.0, 1.0, 1.0)
        g = np.clip((g - 0.25) / 0.2, 0.0, 1.0)
        out *= g
    return out


def owl_hoot(rng):
    """Distant great-horned-owl-like 'hoo, h'hoo-hoooo, hoo, hoo'."""
    f = rng.uniform(340, 390)
    m = Mix(2.6)
    for (t, d, fr, a) in ((0, 0.3, 1.0, 0.7), (0.5, 0.13, 1.03, 0.6), (0.68, 0.45, 1.06, 1.0),
                          (1.3, 0.28, 0.98, 0.8), (1.8, 0.28, 0.97, 0.7)):
        n = ns(d)
        ff = f * fr * S.env_pts(n, [(0, 1.0), (d, 0.95)], 'lin')
        tone = S.sine(ff, n) + 0.2 * S.sine(2 * ff, n)
        tone += 0.2 * norm(S.butter(S.white(n, rng), 'bp', (200.0, 900.0)))
        tone *= S.env_pts(n, [(0, 0), (min(0.06, d * 0.4), 1.0), (d * 0.7, 0.8), (d, 0)], 'cos')
        m.add(tone, t, a)
    return norm(m.out())


@amb('amb_farm_night', lufs=-25.0,
     desc='Farm at night: pulsed ~4-5 kHz cricket chirps from several crickets, soft wind and a '
          'rare distant owl hoot')
def amb_farm_night(rng):
    L = ns(48.0)
    gust = gust_env(L, rng, 0.05, 0.2, 0.8)
    w = at_lufs(eq(wind(L, rng, gust, 200, 600, 0.7, -4.0, 0.3), hi=1200), -34.0)
    cr = np.zeros((2, L))
    specs = [  # fc, pulse_s, pulse_per, n_pulses, chirp_per, gain, pan, distance
        (4700, 0.016, 0.034, 3, 0.62, 1.0, -0.45, 0.10),
        (4450, 0.018, 0.038, 4, 0.81, 0.8, 0.55, 0.15),
        (4900, 0.014, 0.030, 3, 0.55, 0.6, 0.1, 0.25),
        (4250, 0.017, 0.036, 4, 0.95, 0.5, -0.8, 0.35),
        (4600, 0.015, 0.032, 3, 0.70, 0.4, 0.85, 0.4),
        (4350, 0.016, 0.035, 3, 0.66, 0.3, -0.2, 0.5),
    ]
    for fc, ps, pp, npl, cp, g, pan, d in specs:
        c = cricket(L, rng, fc, ps, pp, npl, cp, gating=g < 0.95)
        c = cdist(c, d) if d > 0 else c
        cr += S.panned(c, pan) * g
    cr = S.circ_reverb(cr, 'outdoor', wet=0.3)
    cr = at_lufs(eq(cr, hi=7000.0), -27.0)
    owl = np.zeros((2, L))
    o = S.distance(owl_hoot(rng), 0.45)
    place(owl, o, rng.uniform(5, 40), 1.0, rng.uniform(-0.7, -0.3))
    owl = S.circ_reverb(owl, 'distant', wet=0.6)
    owl = at_lufs(owl, -33.0)
    return w + cr + owl


def wood_hammer(rng, f=420.0):
    m = Mix(0.3)
    tick = S.strike(ns(0.04), [3200, 4700], [1.0, 0.5], [0.006, 0.004], attack=0.0001, hardness=0.7)
    m.add(norm(tick), 0.0, 0.3)
    m.add(P.wood_knock(rng, f, 0.2, tau1=0.03, hardness=0.6, contact=0.3), 0.0, 1.0)
    return norm(m.out())


@amb('amb_town', lufs=-24.0,
     desc='Settlement by day: warm breeze, birds and a dove, distant hammering with a slap-back '
          'echo, and soft pentatonic wind chimes that stir with the gusts')
def amb_town(rng):
    L = ns(48.0)
    secs = 48.0
    gust = gust_env(L, rng, 0.08, 0.25, 1.0)
    w = at_lufs(eq(wind(L, rng, gust, 280, 800, 0.7, -3.0, 0.35), hi=2200), -32.0)
    r = at_lufs(rustle(L, rng, gust ** 2.5, 50.0), -41.0)
    birds = bird_layer(L, rng, 12, ['feebee', 'chip', 'carol', 'trill', 'coo'])
    birds = at_lufs(S.circ_reverb(birds, 'outdoor', wet=0.35), -28.5)
    ham = np.zeros((2, L))
    t = rng.uniform(0, 4)
    while t < secs - 1.0:
        nk = int(rng.integers(3, 7))
        f = rng.uniform(380, 470)
        pan = rng.uniform(-0.7, -0.3)
        for k in range(nk):
            kn = wood_hammer(rng, f * rng.uniform(0.97, 1.03))
            place(ham, kn, t + k * rng.uniform(0.33, 0.42), rng.uniform(0.7, 1.0), pan)
            place(ham, S.butter(kn, 'lp', 1500.0), t + k * 0.38 + 0.19, 0.25, -pan * 0.5)
        t += nk * 0.38 + rng.uniform(5.0, 11.0)
    ham = cdist(ham, 0.45)
    ham = at_lufs(S.circ_reverb(ham, 'outdoor', wet=0.45), -33.0)
    ch = np.zeros((2, L))
    notes = [note('C6'), note('D6'), note('E6'), note('G6'), note('A6')]
    rate = 0.04 + 1.6 * np.clip((gust - 0.55) / 0.45, 0, 1) ** 2
    hits = np.nonzero(rng.random(L) < rate / SR)[0]
    for h in hits:
        f = notes[int(rng.integers(0, len(notes)))] * rng.uniform(0.997, 1.003)
        c = S.chime(f, 3.2, 1.0, bright=0.35, decay=1.1, attack=0.002, release=1.2)
        place(ch, c, h / SR, rng.uniform(0.3, 1.0), 0.45 + rng.uniform(-0.15, 0.15))
    ch = at_lufs(S.circ_reverb(ch, 'outdoor', wet=0.3), -31.0)
    return w + r + birds + ham + ch


@amb('amb_rain', lufs=-23.0,
     desc='Steady rain: smooth filtered-noise hiss and patter, close drop ticks, puddle plinks and '
          'a slow gutter drip')
def amb_rain(rng):
    L = ns(40.0)
    hiss, body, drops, plinks = rain_layers(L, rng, heavy=False)
    y = at_lufs(hiss, -25.0) + at_lufs(body, -31.0) + at_lufs(drops, -31.0) + at_lufs(plinks, -35.0)
    drip = np.zeros((2, L))
    secs = L / SR
    K = round(secs / 1.6)
    per = secs / K
    for k in range(K):
        b = S.bubble(rng.uniform(1700, 2100), 1.0, 0.35)
        place(drip, b, 3.0 + k * per + rng.normal(0, 0.05), rng.uniform(0.7, 1.0), 0.6)
    drip = at_lufs(S.circ_reverb(drip, 'small', wet=0.3), -36.0)
    return y + drip


@amb('amb_storm', lufs=-22.5,
     desc='Storm: heavy, darker rain with dense drops and strongly gusting, howling wind '
          '(thunder is separate)')
def amb_storm(rng):
    L = ns(48.0)
    hiss, body, drops, plinks = rain_layers(L, rng, heavy=True)
    rain = at_lufs(hiss, -24.5) + at_lufs(body, -28.0) + at_lufs(drops, -30.0) + at_lufs(plinks, -35.0)
    gust = gust_env(L, rng, 0.13, 0.15, 1.0, 1.6)
    w = at_lufs(wind(L, rng, gust, 280, 1100, 0.6, -3.0, 0.25, floor=0.15), -25.0)
    wh = at_lufs(whistles(L, rng, gust, [(520, -0.5), (760, 0.4), (980, 0.0)], q=16.0, drift=0.05), -31.0)
    rum = at_lufs(eq(stereo_noise(L, rng, -6.0, 0.6), lo=25, hi=120) * gust, -31.0)
    return rain + w + wh + rum


@amb('amb_wind', lufs=-24.0,
     desc='Desolate wind (winter / open wasteland): deep rumble, gusting body, drifting whistles '
          'and blown grit')
def amb_wind(rng):
    L = ns(48.0)
    gust = gust_env(L, rng, 0.06, 0.15, 1.0, 1.5)
    rum = at_lufs(eq(stereo_noise(L, rng, -6.0, 0.5), lo=25, hi=140) * (0.4 + 0.6 * gust), -28.0)
    body = at_lufs(wind(L, rng, gust, 220, 750, 0.8, -3.0, 0.3, floor=0.2), -26.0)
    wh = at_lufs(whistles(L, rng, gust, [(640, -0.6), (910, 0.5), (1320, 0.1)], q=30.0, drift=0.04,
                          power=2.2), -31.0)
    grit = eq(stereo_noise(L, rng, 0.0, 0.1), lo=2500, hi=7000) * gust ** 3
    grit = at_lufs(grit, -38.0)
    y = rum + body + wh + grit
    return S.circ_reverb(y, 'distant', wet=0.2)


def metal_groan(rng, dur):
    rate_pts = [(0, rng.uniform(18, 26)), (dur * 0.4, rng.uniform(35, 50)), (dur, rng.uniform(20, 30))]
    y = P.creak(rng, dur, rate_pts, [150, 280, 520, 860, 1300], [0.12, 0.08, 0.05, 0.03, 0.02],
                amp_pts=[(0, 0), (dur * 0.25, 1.0), (dur * 0.7, 0.7), (dur, 0)], jitter=0.2,
                gains=[1.0, 0.9, 0.6, 0.4, 0.2])
    return norm(S.sat(y, 1.5))


@amb('amb_ruins', lufs=-24.5,
     desc='Ruined city: eerie wind through broken buildings with hollow aeolian tones, a low '
          'beating drone, distant groaning metal and the occasional far-off clatter')
def amb_ruins(rng):
    L = ns(56.0)
    secs = 56.0
    gust = gust_env(L, rng, 0.05, 0.2, 1.0, 1.4)
    w = at_lufs(eq(wind(L, rng, gust, 180, 520, 0.8, -3.0, 0.3, floor=0.2), hi=1800), -27.0)
    tones = at_lufs(whistles(L, rng, gust, [(233, -0.6), (311, 0.5), (370, -0.1), (466, 0.7)],
                             q=40.0, drift=0.015, power=1.6), -31.0)
    t = S.tvec(L)
    drone = np.zeros((2, L))
    for f, a, pan in ((55.0, 1.0, -0.2), (58.0, 0.8, 0.2), (110.0, 0.25, 0.0), (82.5, 0.3, 0.1)):
        fl = lfreq(f, L)
        drone += S.panned(a * np.sin(2 * np.pi * fl * t + rng.uniform(0, 6.28)), pan)
    drone *= S.periodic_env(L, rng, 0.03, 0.5, 1.0, 1.0)
    drone += 0.6 * eq(stereo_noise(L, rng, -6.0, 0.6), lo=30, hi=90)
    drone = at_lufs(drone, -33.0)
    ev = np.zeros((2, L))
    for k in range(4):
        d = rng.uniform(1.6, 3.0)
        g = S.distance(metal_groan(rng, d), rng.uniform(0.4, 0.6))
        place(ev, g, (k + rng.uniform(0.1, 0.8)) * secs / 4.0, rng.uniform(0.6, 1.0), rng.uniform(-0.8, 0.8))
    for k in range(3):
        c = P.debris(rng, 1.2, int(rng.integers(5, 12)), [(0, 1.0), (0.4, 0.6), (1.2, 0)], (0.2, 0.9),
                     metal=0.5, wood=0.1)
        c = S.distance(c, rng.uniform(0.5, 0.7))
        place(ev, c, rng.uniform(0, secs), rng.uniform(0.5, 0.9), rng.uniform(-0.8, 0.8))
    ev = at_lufs(S.circ_reverb(ev, 'ruins', wet=0.7, dry=0.5), -32.0)
    return w + tones + drone + ev


@amb('amb_radstorm', lufs=-23.0,
     desc='Radstorm: crackling static and discharges, a low beating electrical hum, harsh fast-'
          'gusting wind and a distant rumble')
def amb_radstorm(rng):
    L = ns(44.0)
    secs = 44.0
    burst = S.periodic_env(L, rng, 1.5, 0.0, 1.0, 3.0)
    cr = np.zeros((2, L))
    for ch in range(2):
        for fc, q in ((1500, 1.0), (3000, 1.2), (5200, 1.5)):
            imp = impulses(L, rng, (30.0 + 500.0 * burst) / 3.0, 0.9)
            k = ns(0.004)
            ker = S.biquad(S.white(k, rng) * np.exp(-np.arange(k) / (0.0006 * SR)), 'bp', fc, q)
            cr[ch] += S.circ_conv(imp, ker)
    for _ in range(9):   # discharge bursts
        d = rng.uniform(0.08, 0.3)
        n = ns(d)
        imp = np.zeros(n)
        hit = rng.random(n) < 2500.0 / SR
        imp[hit] = rng.lognormal(0, 0.6, hit.sum()) * rng.choice([-1, 1], hit.sum())
        zap = S.butter(np.convolve(imp, np.hanning(8))[:n], 'bp', (900.0, 6000.0), 2)
        zap += 0.4 * norm(S.square(lfreq(120.0, L), n, 0.3)) * np.max(np.abs(zap))
        zap *= S.env_pts(n, [(0, 0.3), (0.01, 1.0), (d, 0)], 'cos')
        place(cr, norm(zap), rng.uniform(0, secs), rng.uniform(0.5, 1.0), rng.uniform(-0.7, 0.7))
    cr = at_lufs(cr, -27.0)
    hissb = eq(stereo_noise(L, rng, 0.0, 0.2), lo=1800, hi=5500)
    hissb *= 0.5 + 0.5 * np.clip(0.5 + 0.6 * np.vstack([S.smooth_noise(L, rng, 35.0),
                                                        S.smooth_noise(L, rng, 35.0)]), 0, 1)
    hissb = at_lufs(hissb, -33.0)
    t = S.tvec(L)
    hum = np.zeros(L)
    for f, a in ((50.0, 1.0), (51.5, 0.6), (100.0, 0.45), (150.0, 0.3), (200.0, 0.12)):
        hum += a * np.sin(2 * np.pi * lfreq(f, L) * t + rng.uniform(0, 6.28))
    hum *= S.periodic_env(L, rng, 0.1, 0.5, 1.0, 1.0)
    hum = at_lufs(np.vstack([hum, hum]), -30.0)
    gust = gust_env(L, rng, 0.25, 0.2, 1.0, 1.3)
    w = at_lufs(wind(L, rng, gust, 500, 2200, 0.7, -2.0, 0.25, floor=0.2), -27.0)
    wh = at_lufs(whistles(L, rng, gust, [(880, -0.4), (1250, 0.5)], q=25.0, drift=0.06), -33.0)
    rum = at_lufs(eq(stereo_noise(L, rng, -6.0, 0.6), lo=25, hi=100) * S.periodic_env(L, rng, 0.1, 0.3, 1.0),
                  -31.0)
    return cr + hissb + hum + w + wh + rum


@amb('amb_fire', lufs=-24.0,
     desc='Campfire: soft low roar with flicker, small crackles in clusters, louder wood pops and '
          'an occasional sap hiss')
def amb_fire(rng):
    L = ns(32.0)
    secs = 32.0
    flick = S.periodic_env(L, rng, 3.0, 0.6, 1.0, 1.0) * S.periodic_env(L, rng, 0.4, 0.7, 1.0, 1.0)
    roar = eq(stereo_noise(L, rng, -6.0, 0.6), lo=40, hi=350) * flick
    roar = at_lufs(roar, -30.0)
    breath = at_lufs(eq(stereo_noise(L, rng, -3.0, 0.5), lo=500, hi=1400) * flick ** 2, -38.0)
    cr = np.zeros((2, L))
    kers = []
    for fc, q in ((1300, 1.2), (2600, 1.3), (4800, 1.6)):
        k = ns(0.005)
        kers.append(S.biquad(S.white(k, rng) * np.exp(-np.arange(k) / (0.0007 * SR)), 'bp', fc, q))
    centers = np.nonzero(rng.random(L) < 7.0 / SR)[0]
    for ch in range(2):
        imps = [np.zeros(L) for _ in kers]
        for c0 in centers:
            if rng.random() < 0.35:   # some clusters only on one side -> width
                continue
            for _ in range(int(rng.integers(1, 6))):
                i = (c0 + int(rng.uniform(0, 0.04) * SR)) % L
                imps[int(rng.integers(0, len(kers)))][i] += rng.lognormal(0, 0.9) * rng.choice([-1, 1])
        for imp, k in zip(imps, kers):
            cr[ch] += S.circ_conv(imp, k)
    cr = at_lufs(cr, -29.0)
    pops = np.zeros((2, L))
    for t0 in rng.uniform(0, secs, int(secs * 0.45)):
        f = rng.uniform(400, 1200)
        p = S.strike(ns(0.08), [f, f * 1.7, f * 2.6], [1.0, 0.5, 0.3], [0.012, 0.007, 0.004],
                     attack=0.0001, hardness=0.8, rng=rng)
        c = S.pad_to(norm(S.burst(0.03, rng, 0.0001, 0.003, filt=[('hp', 800)])), len(p))
        p += 0.6 * c * np.max(np.abs(p))
        place(pops, norm(p), t0, rng.lognormal(0, 0.4) * 0.6, rng.uniform(-0.4, 0.4))
    pops = at_lufs(pops, -31.0)
    hiss = np.zeros((2, L))
    for t0 in rng.uniform(0, secs, 3):
        d = rng.uniform(0.6, 1.5)
        n = ns(d)
        h = S.butter(S.white(n, rng), 'bp', (3000.0, 6500.0), 2)
        h *= S.env_pts(n, [(0, 0), (d * 0.3, 1.0), (d, 0)], 'cos') * (1 + 0.5 * S.smooth_noise(n, rng, 15.0))
        place(hiss, norm(h), t0, 1.0, rng.uniform(-0.3, 0.3))
    hiss = at_lufs(hiss, -38.0)
    y = roar + breath + cr + pops + hiss
    return S.circ_reverb(y, 'small', wet=0.1)


@amb('amb_river', lufs=-24.0,
     desc='Flowing stream: wide water rush with dense gurgles and bubbles, and a slow low babble')
def amb_river(rng):
    L = ns(40.0)
    rush = eq(stereo_noise(L, rng, -2.0, 0.1), lo=250, hi=5000, peak=(1100, 2.0, 1.0))
    rush *= np.vstack([S.periodic_env(L, rng, 0.4, 0.8, 1.0), S.periodic_env(L, rng, 0.4, 0.8, 1.0)])
    rush = at_lufs(rush, -27.0)
    gur = np.zeros((2, L))
    for ch in range(2):
        clus = S.periodic_env(L, rng, 4.0, 0.0, 1.0, 2.0)
        gur[ch] = bubble_bed(L, rng, 60.0 + 260.0 * clus, 250, 2600, 22, 0.2, 0.6, 0.6)
    gur = at_lufs(gur, -27.5)
    bab = eq(stereo_noise(L, rng, -5.0, 0.5), lo=60, hi=260)
    bab *= S.periodic_env(L, rng, 1.5, 0.4, 1.0, 1.0)
    bab = at_lufs(bab, -33.0)
    return S.circ_reverb(rush + gur + bab, 'outdoor', wet=0.12)


def clock_tick(rng, tock=False):
    f = 2250.0 if tock else 2600.0
    click = S.strike(ns(0.03), [f, f * 1.52, f * 2.3], [1.0, 0.5, 0.3], [0.004, 0.003, 0.002],
                     attack=0.0001, hardness=0.8, rng=rng)
    cs = 0.92 if tock else 1.0
    case = S.strike(ns(0.08), [430 * cs, 980 * cs, 1650 * cs], [1.0, 0.5, 0.25], [0.015, 0.01, 0.006],
                    attack=0.0002, hardness=0.5, rng=rng)
    y = 0.7 * norm(S.pad_to(click, len(case))) + 0.5 * norm(case)
    return norm(y)


@amb('amb_indoor', lufs=-26.0,
     desc='Quiet interior: very soft room tone, faint muffled wind outside and a gentle '
          'wall-clock tick-tock (exactly 1 s, 30 per loop)')
def amb_indoor(rng):
    L = ns(30.0)
    room = at_lufs(eq(stereo_noise(L, rng, -5.0, 0.6), lo=40, hi=300), -40.0)
    gust = gust_env(L, rng, 0.07, 0.2, 1.0, 1.5)
    w = at_lufs(eq(wind(L, rng, gust, 150, 380, 0.7, -4.0, 0.5), hi=500), -34.0)
    clk = np.zeros((2, L))
    for k in range(30):
        place(clk, clock_tick(rng, tock=bool(k % 2)), k * 1.0 + 0.25, 0.9 if k % 2 else 1.0, 0.35)
    clk = at_lufs(S.circ_reverb(clk, 'small', wet=0.25), -29.0)
    return room + w + clk


def geiger_click(rng):
    n = ns(0.012)
    imp = np.zeros(n)
    imp[1] = 1.0
    imp[2] = -0.6
    y = S.resonate(imp, [1850.0, 4200.0, 760.0], [0.0016, 0.0009, 0.0022], [1.0, 0.6, 0.45])
    return S.butter(S.end_fade(norm(y), frac=0.3), 'lp', 9000.0, 2)


@amb('amb_geiger_loop', lufs=-24.0,
     desc='Continuous moderate Geiger-counter crackle (random clicks, ~9 per second on average)')
def amb_geiger_loop(rng):
    L = ns(30.0)
    rate = 9.0 * S.periodic_env(L, rng, 0.3, 0.6, 1.4, 1.0)
    hits = np.nonzero(rng.random(L) < rate / SR)[0]
    y = np.zeros(L)
    kinds = [geiger_click(rng) for _ in range(4)]
    for h in hits:
        S.circ_add(y, kinds[int(rng.integers(0, 4))], h, rng.uniform(0.85, 1.0))
    return np.vstack([y, y])
