"""synth.py -- a small offline DSP / synthesis library for Wasteland Harvest's SFX and ambience.

Everything works on float64 numpy arrays at ``SR`` = 44100 Hz.  Mono signals are 1-D arrays,
stereo signals are ``(2, n)`` arrays.  Every random decision takes an explicit
``numpy.random.Generator`` so whole builds are deterministic.

Sections:
  basics / notes . . . . . . sample helpers, dB, note names
  envelopes  . . . . . . . . AD, ADSR, breakpoint envelopes, fades
  oscillators  . . . . . . . sine / triangle / band-limited saw & square (polyBLEP), FM, glottal
  noise  . . . . . . . . . . white / coloured (FFT) / smooth control noise
  filters  . . . . . . . . . RBJ biquads (static + time-varying), Butterworth, resonator banks,
                             Klatt formant cascade, FFT EQ
  physical-ish models  . . . modal synthesis, Karplus-Strong, bubbles, chirps, grains, creaks
  instruments  . . . . . . . marimba, kalimba, chime, bell, music box, pad, chip lead
  effects  . . . . . . . . . reverb (synthetic IR convolution), saturation, crush, distance
  mixing / levels  . . . . . Mix buffer, panning, normalisation, BS.1770 loudness
  loops  . . . . . . . . . . circular placement / filtering / convolution for seamless ambience
  io . . . . . . . . . . . . 16-bit WAV writer, OGG Vorbis writer (ffmpeg), readers
"""
from __future__ import annotations

import subprocess
import wave

import numpy as np
from scipy import signal as sps

SR = 44100
TWO_PI = 2.0 * np.pi


# ============================================================================ basics / notes
def ns(dur):
    """Seconds -> sample count (>= 1)."""
    return max(1, int(round(float(dur) * SR)))


def tvec(n):
    return np.arange(n) / SR


def undb(d):
    return 10.0 ** (np.asarray(d, dtype=float) / 20.0)


def todb(a):
    return 20.0 * np.log10(np.maximum(np.abs(a), 1e-12))


def _arr(v, n):
    """Broadcast a scalar / array control value to exactly n samples."""
    a = np.asarray(v, dtype=float)
    if a.ndim == 0:
        return np.full(n, float(a))
    if len(a) == n:
        return a
    if len(a) > n:
        return a[:n]
    return np.concatenate([a, np.full(n - len(a), a[-1])])


_NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def note(name):
    """'C5' / 'F#4' / 'Bb3' -> Hz (A4 = 440)."""
    s = name.strip()
    pc = _NOTE[s[0].upper()]
    i = 1
    while i < len(s) and s[i] in '#b':
        pc += 1 if s[i] == '#' else -1
        i += 1
    octave = int(s[i:])
    return 440.0 * 2.0 ** ((pc + 12 * (octave + 1) - 69) / 12.0)


def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


def cents(f, c):
    return f * 2.0 ** (c / 1200.0)


def pad_to(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


# ============================================================================ envelopes
def ramp_in(m):
    """Raised-cosine 0 -> 1 over m samples (first sample exactly 0)."""
    m = max(1, int(m))
    return 0.5 - 0.5 * np.cos(np.pi * np.arange(m) / m)


def ramp_out(m):
    """Raised-cosine 1 -> 0 over m samples (last sample exactly 0)."""
    m = max(1, int(m))
    return 0.5 + 0.5 * np.cos(np.pi * (np.arange(m) + 1) / m)


def env_ad(n, attack=0.002, tau=0.1, hold=0.0):
    """Raised-cosine attack, optional hold, exponential decay with time constant tau."""
    t = tvec(n)
    a = min(n, max(1, int(attack * SR)))
    start = attack + hold
    e = np.exp(-np.maximum(t - start, 0.0) / max(tau, 1e-6))
    e[:a] *= ramp_in(a)
    return e


def env_adsr(n, attack, decay, sustain, release, gate):
    """Classic ADSR; gate = seconds the key is held.  Linear-in-dB-ish segments."""
    t = tvec(n)
    e = np.zeros(n)
    a = t < attack
    e[a] = 0.5 - 0.5 * np.cos(np.pi * t[a] / max(attack, 1e-6))
    d = (t >= attack) & (t < gate)
    e[d] = sustain + (1.0 - sustain) * np.exp(-(t[d] - attack) / max(decay, 1e-6))
    lvl = sustain + (1.0 - sustain) * np.exp(-max(gate - attack, 0.0) / max(decay, 1e-6))
    if gate < attack:
        lvl = 0.5 - 0.5 * np.cos(np.pi * gate / max(attack, 1e-6))
    r = t >= gate
    u = np.clip((t[r] - gate) / max(release, 1e-6), 0.0, 1.0)
    e[r] = lvl * (0.5 + 0.5 * np.cos(np.pi * u))
    return e


def env_pts(n, pts, mode='lin'):
    """Breakpoint envelope.  pts = [(time_s, value), ...].
    mode: 'lin' linear, 'cos' raised-cosine smooth segments, 'exp' geometric (values > 0)."""
    ts = np.array([p[0] for p in pts], dtype=float) * SR
    vs = np.array([p[1] for p in pts], dtype=float)
    idx = np.arange(n, dtype=float)
    if mode == 'lin':
        return np.interp(idx, ts, vs)
    if mode == 'exp':
        return np.exp(np.interp(idx, ts, np.log(np.maximum(vs, 1e-9))))
    # cosine-smoothed segments
    seg = np.clip(np.searchsorted(ts, idx, side='right') - 1, 0, len(ts) - 2)
    t0, t1 = ts[seg], ts[seg + 1]
    v0, v1 = vs[seg], vs[seg + 1]
    u = np.clip((idx - t0) / np.maximum(t1 - t0, 1e-9), 0.0, 1.0)
    u = 0.5 - 0.5 * np.cos(np.pi * u)
    out = v0 + (v1 - v0) * u
    out[idx < ts[0]] = vs[0]
    out[idx >= ts[-1]] = vs[-1]
    return out


def env_bell(n, peak_pos=0.5, rise=2.0, fall=2.0):
    """Asymmetric smooth hump 0 -> 1 -> 0 over n samples (peak at peak_pos * n)."""
    x = np.linspace(0.0, 1.0, n)
    p = min(max(peak_pos, 1e-3), 1 - 1e-3)
    up = np.clip(x / p, 0, 1)
    dn = np.clip((1 - x) / (1 - p), 0, 1)
    e = np.where(x <= p, np.sin(0.5 * np.pi * up) ** rise, np.sin(0.5 * np.pi * dn) ** fall)
    return e


def fade(x, fin=0.0005, fout=0.005):
    """Apply raised-cosine fade in / out (seconds).  Copies."""
    y = np.array(x, dtype=float, copy=True)
    L = y.shape[-1]
    a = min(L, int(fin * SR))
    if a > 0:
        y[..., :a] *= ramp_in(a)
    if fout > 0:
        b = min(L, max(1, int(fout * SR)))
        y[..., -b:] *= ramp_out(b)
    return y


def end_fade(y, release=None, frac=0.25, max_s=0.4):
    """Smooth raised-cosine release over the end of a buffer (in place, returns y).  release in
    seconds; default = min(frac * duration, max_s).  Guarantees no truncation click."""
    L = y.shape[-1]
    m = ns(release) if release is not None else min(int(frac * L), ns(max_s))
    m = min(m, L)
    if m > 1:
        y[..., -m:] *= ramp_out(m)
    return y


# ============================================================================ oscillators
def phase(freq, n, phase0=0.0):
    """Running phase in cycles for a (possibly time-varying) frequency; starts at phase0."""
    f = _arr(freq, n)
    ph = np.cumsum(f) / SR
    return ph - ph[0] + phase0


def sine(freq, n, phase0=0.0):
    return np.sin(TWO_PI * phase(freq, n, phase0))


def tri(freq, n, phase0=0.0):
    p = phase(freq, n, phase0 + 0.25) % 1.0
    return 1.0 - 4.0 * np.abs(p - 0.5)


def _blep(ph, dt):
    y = np.zeros_like(ph)
    m = ph < dt
    if m.any():
        x = ph[m] / dt[m]
        y[m] = x + x - x * x - 1.0
    m = ph > 1.0 - dt
    if m.any():
        x = (ph[m] - 1.0) / dt[m]
        y[m] = x * x + x + x + 1.0
    return y


def saw(freq, n, phase0=0.0):
    """Band-limited (polyBLEP) rising sawtooth in [-1, 1]."""
    f = _arr(freq, n)
    dt = np.clip(f / SR, 1e-9, 0.45)
    ph = (np.cumsum(dt) - dt[0] + phase0) % 1.0
    return 2.0 * ph - 1.0 - _blep(ph, dt)


def square(freq, n, duty=0.5, phase0=0.0):
    """Band-limited (polyBLEP) pulse wave, DC removed."""
    f = _arr(freq, n)
    dt = np.clip(f / SR, 1e-9, 0.45)
    ph = (np.cumsum(dt) - dt[0] + phase0) % 1.0
    duty = _arr(duty, n)
    y = np.where(ph < duty, 1.0, -1.0)
    y += _blep(ph, dt)
    y -= _blep((ph + 1.0 - duty) % 1.0, dt)
    return y - (2.0 * duty - 1.0)


def fm(fc, fmod, index, n, phase0=0.0):
    """Two-operator phase-modulation FM.  fc, fmod, index: scalars or per-sample arrays."""
    pm = TWO_PI * phase(fmod, n)
    return np.sin(TWO_PI * phase(fc, n, phase0) + _arr(index, n) * np.sin(pm))


def glottal(f0, n, oq=0.6, phase0=0.0):
    """KLGLOTT88-style glottal flow derivative (radiated voice source), roughly f0-independent
    amplitude.  oq = open quotient."""
    f = _arr(f0, n)
    p = phase(f, n, phase0) % 1.0
    u = np.clip(p / oq, 0.0, 1.0)
    flow = np.where(p < oq, (27.0 / 4.0) * u * u * (1.0 - u), 0.0)
    d = np.diff(flow, prepend=0.0)
    return d * (SR / np.maximum(f, 20.0)) * oq / 3.0


# ============================================================================ noise
def white(n, rng):
    return rng.standard_normal(n)


def colored(n, rng, slope_db_oct=-3.0, fmin=20.0):
    """Gaussian noise with spectral slope (dB/octave): pink -3, brown -6, blue +3, violet +6.
    FFT-shaped, therefore exactly periodic over n samples; unit RMS."""
    n = int(n)
    x = rng.standard_normal(n)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = (np.maximum(f, fmin) / 1000.0) ** (slope_db_oct / 6.0206)
    g[0] = 0.0
    y = np.fft.irfft(X * g, n)
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


def smooth_noise(n, rng, rate_hz=5.0):
    """Band-limited random control signal (unit RMS, periodic over n) with ~rate_hz bandwidth."""
    n = int(n)
    x = rng.standard_normal(n)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    X *= np.exp(-0.5 * (f / max(rate_hz, 1e-3)) ** 2)
    X[0] = 0.0
    y = np.fft.irfft(X, n)
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


def spectral_noise(n, rng, gain_fn):
    """Noise with an arbitrary magnitude response gain_fn(f_hz) -> gain.  Periodic, unit RMS."""
    n = int(n)
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = np.asarray(gain_fn(f), dtype=float)
    X *= g
    X[0] = 0.0
    y = np.fft.irfft(X, n)
    return y / (np.sqrt(np.mean(y * y)) + 1e-12)


# ============================================================================ filters
def _rbj(kind, f0, Q, gain_db=0.0):
    """Vectorised RBJ-cookbook biquad coefficients.  Returns b (3, m), a (3, m) normalised."""
    f0 = np.clip(np.atleast_1d(np.asarray(f0, dtype=float)), 5.0, SR * 0.49)
    Q = np.broadcast_to(np.atleast_1d(np.asarray(Q, dtype=float)), f0.shape)
    g = np.broadcast_to(np.atleast_1d(np.asarray(gain_db, dtype=float)), f0.shape)
    w0 = TWO_PI * f0 / SR
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2.0 * np.maximum(Q, 1e-3))
    A = 10.0 ** (g / 40.0)
    one = np.ones_like(f0)
    if kind == 'lp':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'hp':
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'bp':  # constant 0 dB peak gain
        b = [alpha, 0 * one, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'notch':
        b = [one, -2 * cw, one]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'peak':
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind in ('lowshelf', 'highshelf'):
        s = 2 * np.sqrt(A) * alpha
        if kind == 'lowshelf':
            b = [A * ((A + 1) - (A - 1) * cw + s), 2 * A * ((A - 1) - (A + 1) * cw),
                 A * ((A + 1) - (A - 1) * cw - s)]
            a = [(A + 1) + (A - 1) * cw + s, -2 * ((A - 1) + (A + 1) * cw),
                 (A + 1) + (A - 1) * cw - s]
        else:
            b = [A * ((A + 1) + (A - 1) * cw + s), -2 * A * ((A - 1) + (A + 1) * cw),
                 A * ((A + 1) + (A - 1) * cw - s)]
            a = [(A + 1) - (A - 1) * cw + s, 2 * ((A - 1) - (A + 1) * cw),
                 (A + 1) - (A - 1) * cw - s]
    else:
        raise ValueError(kind)
    b = np.array(b, dtype=float)
    a = np.array(a, dtype=float)
    return b / a[0], a / a[0]


def biquad(x, kind, f0, Q=0.7071, gain_db=0.0):
    """Static RBJ biquad (kind: lp hp bp notch peak lowshelf highshelf)."""
    b, a = _rbj(kind, f0, Q, gain_db)
    return sps.lfilter(b[:, 0], a[:, 0], x, axis=-1)


def lp(x, f0, Q=0.7071):
    return biquad(x, 'lp', f0, Q)


def hp(x, f0, Q=0.7071):
    return biquad(x, 'hp', f0, Q)


def bp(x, f0, Q=1.0):
    return biquad(x, 'bp', f0, Q)


def peq(x, f0, gain_db, Q=1.0):
    return biquad(x, 'peak', f0, Q, gain_db)


def lshelf(x, f0, gain_db, Q=0.7071):
    return biquad(x, 'lowshelf', f0, Q, gain_db)


def hshelf(x, f0, gain_db, Q=0.7071):
    return biquad(x, 'highshelf', f0, Q, gain_db)


def butter(x, kind, f, order=2):
    """Butterworth via SOS.  kind 'lowpass'|'highpass'|'bandpass'|'bandstop'; f scalar or pair."""
    k = {'lp': 'lowpass', 'hp': 'highpass', 'bp': 'bandpass', 'bs': 'bandstop'}.get(kind, kind)
    if np.ndim(f):
        f = [min(max(v, 5.0), SR * 0.49) for v in f]
    else:
        f = min(max(f, 5.0), SR * 0.49)
    sos = sps.butter(order, f, btype=k, fs=SR, output='sos')
    return sps.sosfilt(sos, x, axis=-1)


def onepole(x, fc, kind='lp'):
    a = np.exp(-TWO_PI * fc / SR)
    y = sps.lfilter([1 - a], [1, -a], x, axis=-1)
    return y if kind == 'lp' else x - y


def tvf(x, kind, f0, Q=0.7071, gain_db=0.0, block=32):
    """Time-varying biquad: f0 / Q / gain may be per-sample arrays; coefficients are updated every
    `block` samples with the DF2T state carried across (smooth for slowly varying controls)."""
    n = len(x)
    idx = np.arange(0, n, block)
    B, A = _rbj(kind, _arr(f0, n)[idx], _arr(Q, n)[idx], _arr(gain_db, n)[idx])
    y = np.empty(n)
    zi = np.zeros(2)
    for k, i in enumerate(idx):
        j = min(n, i + block)
        y[i:j], zi = sps.lfilter(B[:, k], A[:, k], x[i:j], zi=zi)
    return y


def resonate(x, freqs, taus, gains=None):
    """Parallel bank of two-pole resonators (modal filter bank).  A unit impulse into mode k
    rings as gains[k] * exp(-t / taus[k]) * sin(2 pi f t)."""
    freqs = np.atleast_1d(freqs)
    taus = np.broadcast_to(np.atleast_1d(taus), freqs.shape)
    gains = np.ones_like(freqs, dtype=float) if gains is None else np.broadcast_to(gains, freqs.shape)
    y = np.zeros(len(x))
    for f, tau, g in zip(freqs, taus, gains):
        if f >= SR * 0.47 or g == 0:
            continue
        r = np.exp(-1.0 / (tau * SR))
        th = TWO_PI * f / SR
        y += sps.lfilter([g * np.sin(th)], [1.0, -2.0 * r * np.cos(th), r * r], x)
    return y


def _klatt_tv(x, F, BW, block=32):
    n = len(x)
    idx = np.arange(0, n, block)
    Fb = _arr(F, n)[idx]
    Bb = _arr(BW, n)[idx]
    T = 1.0 / SR
    C = -np.exp(-TWO_PI * Bb * T)
    Bc = 2.0 * np.exp(-np.pi * Bb * T) * np.cos(TWO_PI * Fb * T)
    A = 1.0 - Bc - C
    y = np.empty(n)
    zi = np.zeros(2)
    for k, i in enumerate(idx):
        j = min(n, i + block)
        y[i:j], zi = sps.lfilter([A[k]], [1.0, -Bc[k], -C[k]], x[i:j], zi=zi)
    return y


def formant_cascade(x, F_list, BW_list, block=32):
    """Klatt-style cascade of unity-DC-gain resonators; F/BW entries scalars or arrays."""
    y = x
    for F, BW in zip(F_list, BW_list):
        y = _klatt_tv(y, F, BW, block)
    return y


def fft_eq(x, gain_fn):
    """Zero-phase (circular) EQ: multiply the spectrum by gain_fn(f_hz)."""
    n = x.shape[-1]
    X = np.fft.rfft(x, axis=-1)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(X * gain_fn(f), n, axis=-1)


def dc_block(x, fc=18.0):
    return butter(x, 'hp', fc, order=2)


# ============================================================================ vowels / voice
# Formants F1..F4 (Hz) and bandwidths (Hz); adult-male-ish reference values (Peterson & Barney /
# Klatt).  Scaled per voice with `scale`.
VOWELS = {
    'a':  ((730, 1090, 2440, 3400), (80, 90, 120, 180)),
    'ae': ((660, 1720, 2410, 3400), (80, 100, 120, 180)),
    'e':  ((530, 1840, 2480, 3400), (60, 100, 120, 180)),
    'ih': ((390, 1990, 2550, 3400), (60, 100, 120, 180)),
    'i':  ((270, 2290, 3010, 3600), (50, 90, 150, 200)),
    'o':  ((570, 840, 2410, 3400), (70, 80, 120, 180)),
    'oh': ((450, 880, 2400, 3300), (60, 80, 120, 180)),
    'u':  ((300, 870, 2240, 3300), (50, 80, 120, 180)),
    'uh': ((640, 1190, 2390, 3400), (80, 90, 120, 180)),
    'er': ((490, 1350, 1690, 3300), (70, 100, 120, 180)),
    'm':  ((260, 1000, 2200, 3300), (90, 250, 300, 300)),
    'n':  ((260, 1500, 2550, 3400), (90, 250, 300, 300)),
}


def vowel_tracks(n, path, scale=1.0, bw_scale=1.0):
    """path = [(time_s, vowel_name), ...] -> (F_list, BW_list) of per-sample arrays."""
    ts = np.array([p[0] for p in path]) * SR
    idx = np.arange(n, dtype=float)
    F, B = [], []
    for k in range(4):
        fv = [VOWELS[p[1]][0][k] * scale for p in path]
        bv = [VOWELS[p[1]][1][k] * bw_scale for p in path]
        F.append(np.exp(np.interp(idx, ts, np.log(fv))))
        B.append(np.interp(idx, ts, bv))
    return F, B


def voice(f0, path, n, rng, scale=1.0, bw_scale=1.0, jitter=0.006, shimmer=0.04, breath=0.04,
          oq=0.6, tilt_hz=3000.0, n_formants=4):
    """Formant-synthesised voiced sound.  f0 per-sample (or scalar); path = vowel breakpoints."""
    f = _arr(f0, n) * (1.0 + jitter * smooth_noise(n, rng, 45.0))
    src = glottal(f, n, oq=oq)
    if shimmer:
        src *= 1.0 + shimmer * smooth_noise(n, rng, 30.0)
    if breath:
        ph = phase(f, n) % 1.0
        asp = butter(white(n, rng), 'hp', 900.0) * (0.35 + 0.65 * (ph < oq))
        src = src + breath * asp * np.std(src) * 3.0
    src = onepole(src, tilt_hz)
    F, B = vowel_tracks(n, path, scale, bw_scale)
    return formant_cascade(src, F[:n_formants], B[:n_formants])


def creaky_source(f0, n, rng, jitter=0.2, alt=0.4, width_ms=0.7):
    """Irregular glottal pulse train (vocal fry / growl / rasp).  f0 per-sample; jitter is the
    random period perturbation (fraction), alt the period-to-period amplitude alternation."""
    f = _arr(f0, n)
    imp = np.zeros(n)
    t = 0.0
    k = 0
    while True:
        i = int(t * SR)
        if i >= n:
            break
        a = (1.0 + alt * (1 if k % 2 else -1)) * rng.lognormal(0.0, 0.25)
        imp[i] += a
        per = 1.0 / max(f[i], 5.0)
        t += per * (1.0 + jitter * rng.standard_normal())
        t = max(t, i / SR + 0.25 / max(f[i], 5.0))
        k += 1
    w = max(3, int(width_ms * 1e-3 * SR))
    tk = np.linspace(-3, 3, 2 * w + 1)
    ker = -tk * np.exp(-0.5 * tk * tk)  # derivative-of-Gaussian pulse
    return np.convolve(imp, ker, mode='same')


# ============================================================================ modal / physical
def modes(n, freqs, amps, taus, phases=None, release=None):
    """Additive modal synthesis: sum_k amps[k] * exp(-t / taus[k]) * sin(2 pi f_k t + phi_k).
    freqs may contain per-sample arrays (pitch glides).  Ends with a smooth release (end_fade)."""
    t = tvec(n)
    y = np.zeros(n)
    for k, (f, a, tau) in enumerate(zip(freqs, amps, taus)):
        fmax = np.max(f) if np.ndim(f) else f
        if fmax >= SR * 0.47 or a == 0:
            continue
        ph0 = 0.0 if phases is None else phases[k]
        if np.ndim(f):
            s = np.sin(TWO_PI * phase(f, n) + ph0)
        else:
            s = np.sin(TWO_PI * f * t + ph0)
        y += a * np.exp(-t / tau) * s
    return end_fade(y, release)


def strike(n, freqs, amps, taus, attack=0.0008, hardness=1.0, rng=None, phases=None, release=None):
    """Modal strike: soft-mallet hardness rolls off high modes (fc = 1.2k..14k Hz)."""
    freqs = np.asarray(freqs, dtype=float)
    fc = 1200.0 * (12.0 ** hardness)
    g = np.asarray(amps, dtype=float) / np.sqrt(1.0 + (freqs / fc) ** 4)
    if phases is None and rng is not None:
        phases = rng.uniform(0, 0.15, len(freqs))
    y = modes(n, freqs, g, taus, phases, release)
    a = min(n, max(1, int(attack * SR)))
    y[:a] *= ramp_in(a)
    return y


def pluck(freq, dur, rng, t60=1.0, bright=0.5, pick=0.13, exc=None):
    """Karplus-Strong string with fractional-delay allpass tuning and loop low-pass.
    bright 0..1 (excitation & loop brightness), pick = pluck position (comb on excitation)."""
    n = ns(dur)
    P = SR / float(freq)
    s = 0.5 + 0.45 * bright                       # loop filter y = s*x[n] + (1-s)*x[n-1]
    lp_delay = 1.0 - s
    N = int(np.floor(P - lp_delay - 0.15))
    frac = P - lp_delay - N                        # in [0.15, 1.15)
    ap = (1.0 - frac) / (1.0 + frac)
    g = 10.0 ** (-3.0 / (t60 * freq))              # per-period loss for the requested T60
    if exc is None:
        e = rng.uniform(-1, 1, N)
        e = onepole(e, 1500 + 9000 * bright)
        d = max(1, int(pick * N))
        e = e - np.concatenate([np.zeros(d), e[:-d]])  # pluck-position comb
    else:
        e = pad_to(exc, N)
    x = np.zeros(n + N)
    x[:N] = e
    y = np.zeros(n + N)
    y[:N] = e
    # loop: y[k] = x[k] + g * AP(LP(y[k - N]))   (block of N samples at a time is exact)
    b_lp = [s, 1.0 - s]
    zi_lp = np.zeros(1)
    zi_ap = np.zeros(1)
    for start in range(N, n + N, N):
        end = min(n + N, start + N)
        d = y[start - N:end - N]
        v, zi_lp = sps.lfilter(b_lp, [1.0], d, zi=zi_lp)
        v, zi_ap = sps.lfilter([ap, 1.0], [1.0, ap], v, zi=zi_ap)
        y[start:end] = x[start:end] + g * v
    return end_fade(y[:n].copy())


def bubble(f0, amp=1.0, eps=0.25, dur=None):
    """Van den Doel / Minnaert bubble: a decaying sinusoid whose pitch rises as it shrinks."""
    beta = 0.043 * f0 + 0.0014 * f0 ** 1.5
    tau = 1.0 / beta
    n = ns(min(dur if dur else 7 * tau, 0.25))
    t = tvec(n)
    f = f0 * np.minimum(1.0 + eps * beta * t, 2.5)
    y = amp * np.sin(TWO_PI * np.cumsum(f) / SR) * np.exp(-t / tau)
    a = min(n, 6)
    y[:a] *= ramp_in(a)
    b = max(1, n // 6)
    y[-b:] *= ramp_out(b)
    return y


def chirp(n, f_path, amp_env=None, fm_rate=0.0, fm_depth=0.0, harm=None):
    """Tonal glide (bird notes etc.).  f_path: per-sample Hz.  Optional vibrato/FM trill and
    harmonics dict {multiple: amplitude}."""
    f = _arr(f_path, n)
    if fm_depth:
        f = f * (1.0 + fm_depth * np.sin(TWO_PI * fm_rate * tvec(n)))
    ph = TWO_PI * phase(f, n)
    y = np.sin(ph)
    if harm:
        for m, a in harm.items():
            y += a * np.sin(m * ph)
    if amp_env is not None:
        y *= amp_env
    return y


def sample_times(density, count, rng):
    """Draw `count` sample indices distributed according to a non-negative density array."""
    c = np.cumsum(np.maximum(density, 0))
    if c[-1] <= 0:
        return np.zeros(count, dtype=int)
    u = rng.uniform(0, c[-1], count)
    return np.searchsorted(c, u).clip(0, len(density) - 1)


def grains(n, rng, count, density, f_lo, f_hi, q=1.5, dur_lo=0.0008, dur_hi=0.004,
           amp_sigma=0.6, kind='bp', shape='exp'):
    """Cloud of tiny filtered noise bursts (crunch, grit, crackle, rustle).
    density: per-sample array (envelope of grain rate).  Frequencies log-uniform in [f_lo, f_hi]."""
    y = np.zeros(n)
    if count <= 0:
        return y
    starts = np.sort(sample_times(density, count, rng))
    fs = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi), count))
    durs = np.exp(rng.uniform(np.log(dur_lo), np.log(dur_hi), count))
    amps = rng.lognormal(0.0, amp_sigma, count)
    for s, f, d, a in zip(starts, fs, durs, amps):
        L = max(4, int(d * SR))
        tail = int(min(0.02, 4.0 * q / max(f, 50.0)) * SR)
        e = rng.standard_normal(L)
        if shape == 'exp':
            e *= np.exp(-np.arange(L) / (L / 3.0))
        else:
            e *= np.hanning(L + 2)[1:-1]
        e = np.concatenate([e, np.zeros(tail)])
        g = biquad(e, kind, f, q) if kind else e
        m = min(len(g), n - s)
        if m > 0:
            y[s:s + m] += a * g[:m]
    return y


def creak(n, rng, rate, freqs, taus, gains=None, jitter=0.12, amp=None, click_ms=0.25):
    """Stick-slip friction (door hinge, tree, rope, metal groan): an irregular impulse train whose
    rate (Hz, per-sample array) sets the perceived pitch, exciting a resonator bank."""
    r = _arr(rate, n) * (1.0 + jitter * smooth_noise(n, rng, 25.0))
    ph = np.cumsum(np.maximum(r, 0.5)) / SR
    k = np.floor(ph)
    hits = np.nonzero(np.diff(k, prepend=k[0]) > 0)[0]
    imp = np.zeros(n)
    imp[hits] = rng.lognormal(0.0, 0.35, len(hits))
    if amp is not None:
        imp *= _arr(amp, n)
    L = max(2, int(click_ms * 1e-3 * SR))
    imp = np.convolve(imp, np.hanning(L + 2)[1:-1], mode='same')
    return resonate(imp, freqs, taus, gains)


def thump(dur, f_start, f_end, sweep_tau=0.03, tau=0.08, attack=0.001):
    """Sine with exponential pitch drop: kicks, thuds, body impacts."""
    n = ns(dur)
    t = tvec(n)
    f = f_end + (f_start - f_end) * np.exp(-t / sweep_tau)
    return end_fade(sine(f, n) * env_ad(n, attack, tau))


def burst(dur, rng, attack=0.0005, tau=0.02, color=0.0, filt=()):
    """Noise burst with AD envelope; filt = [('lp', 800), ('bp', 1200, 1.0), ...]."""
    n = ns(dur)
    x = colored(n, rng, color) if color else white(n, rng)
    for f in filt:
        x = biquad(x, f[0], f[1], f[2] if len(f) > 2 else 0.7071)
    return end_fade(x * env_ad(n, attack, tau))


def metal_modes(rng, f1, count=8, spread=(0.35, 1.2), tau1=0.4, tau_exp=0.7, doublet=0.004):
    """Random inharmonic plate/sheet-metal mode set -> (freqs, amps, taus)."""
    r = [1.0]
    for _ in range(count - 1):
        r.append(r[-1] + rng.uniform(*spread))
    r = np.array(r)
    f = f1 * r
    a = r ** -0.4 * rng.uniform(0.45, 1.0, count)
    t = tau1 / r ** tau_exp * rng.uniform(0.7, 1.3, count)
    if doublet:
        f2 = f * (1.0 + doublet * rng.uniform(0.5, 1.5, count))
        f = np.concatenate([f, f2])
        a = np.concatenate([a, a * rng.uniform(0.3, 0.8, count)])
        t = np.concatenate([t, t * rng.uniform(0.8, 1.1, count)])
    return f, a, t


# ============================================================================ instruments
def _auto(dur, tau, k=6.0, lo=0.05, hi=8.0):
    return float(dur) if dur is not None else float(np.clip(k * tau, lo, hi))


def marimba(freq, dur=None, vel=1.0, rng=None, hardness=0.45, decay=1.0, release=None):
    """Marimba bar (tuned 1 : 3.93 : 9.87) with a soft mallet thump.  dur=None -> rings out."""
    base = float(np.clip(0.75 * (262.0 / freq) ** 0.7, 0.06, 1.2)) * decay
    n = ns(_auto(dur, base))
    fr = [freq, freq * 3.93, freq * 9.87]
    y = strike(n, fr, [1.0, 0.30 * hardness + 0.04, 0.10 * hardness], [base, base * 0.22, base * 0.06],
               attack=0.0015, hardness=0.5 + 0.4 * hardness, release=release)
    if rng is not None:
        th = burst(0.012, rng, 0.0003, 0.0025, filt=[('lp', 900 + 2500 * hardness)])
        m = min(n, len(th))
        y[:m] += 0.10 * th[:m]
    return vel * y


def kalimba(freq, dur=None, vel=1.0, rng=None, decay=1.0, release=None):
    """Thumb-piano tine: fundamental + inharmonic ~5.9x overtone + faint octave, tiny tine click."""
    base = float(np.clip(1.1 * (262.0 / freq) ** 0.5, 0.15, 1.6)) * decay
    n = ns(_auto(dur, base))
    y = strike(n, [freq, freq * 5.93, freq * 2.0], [1.0, 0.22, 0.05], [base, 0.05, base * 0.4],
               attack=0.0012, hardness=0.8, release=release)
    if rng is not None:
        c = burst(0.006, rng, 0.0002, 0.001, filt=[('hp', 2500), ('lp', 7000)])
        m = min(n, len(c))
        y[:m] += 0.05 * c[:m]
    return vel * y


def musicbox(freq, dur=None, vel=1.0, rng=None, decay=1.0, release=None):
    """Music-box comb tooth (cantilever 1 : 6.27), short pluck."""
    base = float(np.clip(1.4 * (523.0 / freq) ** 0.6, 0.2, 2.0)) * decay
    n = ns(_auto(dur, base))
    y = strike(n, [freq, freq * 6.27, freq * 3.0], [1.0, 0.12, 0.03], [base, 0.04, 0.2 * decay],
               attack=0.0008, hardness=0.9, release=release)
    if rng is not None:
        c = burst(0.004, rng, 0.0001, 0.0008, filt=[('hp', 3000), ('lp', 8000)])
        m = min(n, len(c))
        y[:m] += 0.04 * c[:m]
    return vel * y


def chime(freq, dur=None, vel=1.0, bright=0.5, decay=1.0, attack=0.002, release=None):
    """Soft tubular/bar chime (free-free bar partials 1 : 2.756 : 5.404 : 8.933)."""
    base = float(np.clip(1.6 * (523.0 / freq) ** 0.5, 0.3, 3.0)) * decay
    n = ns(_auto(dur, base))
    fr = [freq, freq * 2.756, freq * 5.404, freq * 8.933, freq * 1.003]
    am = [1.0, 0.45 * bright + 0.1, 0.18 * bright, 0.06 * bright, 0.35]
    ta = [base, base * 0.45, base * 0.2, base * 0.08, base * 0.9]
    return vel * strike(n, fr, am, ta, attack=attack, hardness=0.9, release=release)


def fmbell(freq, dur=None, vel=1.0, ratio=3.5, index=2.5, tau=0.8, itau=0.25, attack=0.001,
           release=None):
    """Classic Chowning FM bell: inharmonic modulator ratio, decaying index."""
    n = ns(_auto(dur, tau))
    t = tvec(n)
    idx = index * np.exp(-t / itau)
    y = fm(freq, freq * ratio, idx, n) * np.exp(-t / tau)
    a = min(n, max(1, int(attack * SR)))
    y[:a] *= ramp_in(a)
    return vel * end_fade(y, release)


def church_bell(prime, dur, rng, rust=0.5, decay=1.0, release=None):
    """Swinging-bell partial series (hum, prime, tierce, quint, nominal, ...) with doublets.
    rust 0..1: detunes partials, shortens decays and adds a dull clank."""
    n = ns(dur)
    ratios = np.array([0.5, 1.0, 1.19, 1.5, 2.0, 2.51, 2.66, 3.01, 4.03, 5.05])
    amps = np.array([0.55, 0.75, 0.6, 0.25, 1.0, 0.35, 0.3, 0.18, 0.12, 0.06])
    taus = np.array([6.0, 3.8, 2.6, 2.0, 2.2, 1.1, 0.9, 0.7, 0.45, 0.3]) * decay * (1.0 - 0.45 * rust)
    ratios = ratios * (1.0 + rust * 0.012 * rng.standard_normal(len(ratios)))
    f = prime * ratios
    f2 = f * (1.0 + 0.0025 + 0.002 * rng.random(len(f)))      # doublets -> slow beating
    y = strike(n, np.concatenate([f, f2]), np.concatenate([amps, amps * 0.5]),
               np.concatenate([taus, taus * 0.9]), attack=0.0015, hardness=0.75, rng=rng,
               release=release if release is not None else 0.4 * dur)
    if rust > 0:
        c = burst(0.08, rng, 0.0004, 0.012, filt=[('bp', 1800, 1.2)])
        m = min(n, len(c))
        y[:m] += rust * 0.35 * c[:m]
    return y


def pad(freqs, dur, rng, attack=0.3, release=0.5, cutoff=1500.0, detune_cents=7.0, voices=3,
        gate=None):
    """Warm detuned-saw pad chord through a low-pass; ADSR swell whose release reaches exactly
    zero at the end of the buffer (gate defaults to dur - release)."""
    n = ns(dur)
    y = np.zeros(n)
    for f in np.atleast_1d(freqs):
        for v in range(voices):
            c = detune_cents * (v - (voices - 1) / 2.0) + rng.uniform(-1.5, 1.5)
            y += saw(cents(f, c), n, phase0=rng.random())
    y = lp(lp(y, cutoff, 0.6), cutoff * 1.3, 0.6)
    g = dur - release if gate is None else gate
    return y * env_adsr(n, attack, 0.4, 0.8, max(release, dur - g), g)


def chip(freq, dur, duty=0.5, vib_rate=5.5, vib_depth=0.0, cutoff=3000.0, attack=0.004,
         tau=0.4, vib_delay=0.15, release=None):
    """Softened chiptune pulse lead (low-passed so it never buzzes harshly)."""
    n = ns(dur)
    t = tvec(n)
    vib = vib_depth * np.clip((t - vib_delay) / 0.1, 0, 1) * np.sin(TWO_PI * vib_rate * t)
    y = square(freq * (1.0 + vib), n, duty)
    y = lp(lp(y, cutoff, 0.7), cutoff * 1.5, 0.7)
    return end_fade(y * env_ad(n, attack, tau), release)


# ============================================================================ effects
_IR_CACHE = {}

IR_PRESETS = {
    # name: (rt60, predelay, hf_ratio, lf_ratio, early reflections [(t, gain)], stereo spread)
    'small':   (0.35, 0.004, 0.45, 1.0, [(0.007, 0.5), (0.013, 0.35), (0.021, 0.25)]),
    'room':    (0.6, 0.008, 0.5, 1.0, [(0.011, 0.45), (0.019, 0.35), (0.031, 0.25), (0.043, 0.15)]),
    'wood':    (0.5, 0.006, 0.4, 1.1, [(0.009, 0.45), (0.017, 0.3), (0.027, 0.2)]),
    'outdoor': (0.9, 0.015, 0.35, 0.9, [(0.045, 0.35), (0.11, 0.22), (0.19, 0.12)]),
    'street':  (1.4, 0.02, 0.4, 1.0, [(0.06, 0.4), (0.13, 0.3), (0.24, 0.2), (0.37, 0.12)]),
    'hall':    (1.6, 0.02, 0.5, 1.1, [(0.019, 0.4), (0.033, 0.3), (0.051, 0.25)]),
    'ruins':   (2.2, 0.025, 0.35, 1.2, [(0.05, 0.35), (0.09, 0.3), (0.17, 0.25), (0.31, 0.15)]),
    'distant': (3.2, 0.04, 0.25, 1.2, [(0.12, 0.3), (0.31, 0.2), (0.55, 0.12)]),
    'bell':    (2.6, 0.03, 0.35, 1.1, [(0.08, 0.3), (0.21, 0.2), (0.43, 0.12)]),
}


def make_ir(preset='room', stereo=False, seed=1234):
    """Synthetic impulse response: 3-band exponentially decaying noise (frequency-dependent
    RT60) plus sparse early reflections.  Unit energy per channel.  Cached & deterministic."""
    key = (preset, stereo, seed)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    rt60, pre, hf, lf, early = IR_PRESETS[preset]
    rng = np.random.default_rng(seed + sum(map(ord, preset)))
    n = ns(rt60 * 1.3 + pre)
    t = tvec(n)
    chans = []
    for _c in range(2 if stereo else 1):
        w = rng.standard_normal(n)
        lo = butter(w, 'lp', 400.0, 2)
        hi = butter(w, 'hp', 3500.0, 2)
        mid = w - lo - hi
        e_lo = np.exp(-6.9078 * t / (rt60 * lf))
        e_mid = np.exp(-6.9078 * t / rt60)
        e_hi = np.exp(-6.9078 * t / (rt60 * hf))
        ir = lo * e_lo + mid * e_mid + hi * e_hi
        # diffuse build-up: tail density ramps in over the first ~30 ms
        ir *= 1.0 - np.exp(-t / 0.012)
        for (et, eg) in early:
            i = int((et * rng.uniform(0.9, 1.1)) * SR)
            if i < n - 64:
                k = burst(0.002, rng, 0.0001, 0.0006, filt=[('lp', 6000)])
                ir[i:i + len(k)] += eg * 8.0 * k * np.exp(-6.9078 * et / rt60)
        end_fade(ir, frac=0.2)
        ir = np.concatenate([np.zeros(ns(pre)), ir])
        ir /= np.sqrt(np.sum(ir * ir)) + 1e-12
        chans.append(ir)
    out = np.array(chans) if stereo else chans[0]
    _IR_CACHE[key] = out
    return out


def reverb(x, preset='room', wet=0.25, dry=1.0, tail=True):
    """Convolution reverb with a synthetic IR.  Output is longer than x (tail) unless tail=False."""
    ir = make_ir(preset)
    w = sps.fftconvolve(x, ir)
    y = dry * np.concatenate([x, np.zeros(len(w) - len(x))]) + wet * w
    return y if tail else y[:len(x)]


def sat(x, drive=1.0, asym=0.0):
    """tanh saturation; asym adds even harmonics (DC is removed later by the pipeline)."""
    if drive <= 0:
        return x
    y = np.tanh(drive * (x + asym)) - np.tanh(drive * asym)
    return y / np.tanh(drive)


def crush(x, bits=8, hold=1):
    """Lo-fi bit reduction (and optional sample-hold decimation)."""
    q = 2.0 ** (bits - 1)
    y = np.round(x * q) / q
    if hold > 1:
        idx = (np.arange(len(y)) // hold) * hold
        y = y[idx]
    return y


def distance(x, amount=0.5):
    """Crude air absorption: amount 0 (close) .. 1 (far) -> low-pass sweep 14 kHz .. 1.2 kHz."""
    fc = 14000.0 * (1.2 / 14.0) ** amount
    return butter(x, 'lp', fc, 2) * (1.0 - 0.5 * amount)


def warm(x, lp_hz=9000.0, drive=0.6, shelf_db=-3.0):
    """Cozy 'lo-fi warmth' chain for farm/UI sounds: soft saturation, gentle top roll-off."""
    y = sat(x / (np.max(np.abs(x)) + 1e-12), drive) if drive else x
    y = hshelf(y, 5000.0, shelf_db)
    return butter(y, 'lp', lp_hz, 2)


# ============================================================================ mixing / levels
class Mix:
    """Growable mono or stereo mix buffer: add(sig, t_seconds, gain, pan)."""

    def __init__(self, dur=0.0, stereo=False):
        self.stereo = stereo
        self.buf = np.zeros((2, ns(dur)) if stereo else ns(dur))

    def _ensure(self, n):
        cur = self.buf.shape[-1]
        if n > cur:
            extra = n - cur
            pad = np.zeros((2, extra)) if self.stereo else np.zeros(extra)
            self.buf = np.concatenate([self.buf, pad], axis=-1)

    def add(self, sig, t=0.0, gain=1.0, pan=None):
        i = int(round(t * SR))
        if self.stereo and np.ndim(sig) == 1:
            sig = panned(sig, 0.0 if pan is None else pan)
        n = sig.shape[-1]
        self._ensure(i + n)
        self.buf[..., i:i + n] += gain * sig
        return self

    def out(self):
        return self.buf


def panned(x, p):
    """Constant-power pan, p in [-1, 1] -> (2, n)."""
    a = (p + 1.0) * np.pi / 4.0
    return np.vstack([np.cos(a) * x, np.sin(a) * x])


def normalize_peak(x, peak_db):
    m = np.max(np.abs(x))
    return x if m <= 0 else x * (undb(peak_db) / m)


def rms_db(x):
    return float(todb(np.sqrt(np.mean(np.square(x))) + 1e-12))


def _kweight_coefs():
    # ITU-R BS.1770-4 K-weighting re-derived for 44.1 kHz (pre-filter shelf + RLB high-pass).
    fs = SR
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = np.tan(np.pi * f0 / fs)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / fs)
    a2 = [1.0, 2 * (K * K - 1) / (1 + K / Q + K * K), (1 - K / Q + K * K) / (1 + K / Q + K * K)]
    b2 = [1.0, -2.0, 1.0]
    return (b1, a1), (b2, a2)


def kweight(x):
    (b1, a1), (b2, a2) = _kweight_coefs()
    return sps.lfilter(b2, a2, sps.lfilter(b1, a1, x, axis=-1), axis=-1)


def loudness(x, circular=False):
    """Integrated loudness (LUFS, BS.1770-4 gating) of mono (n,) or stereo (2, n) audio.
    circular=True treats x as a loop (filters warmed up with the loop's own tail)."""
    x = np.atleast_2d(x)
    if circular:
        w = min(x.shape[-1], ns(2.0))
        y = kweight(np.concatenate([x[:, -w:], x, x[:, :ns(0.4)]], axis=-1))[:, w:]
    else:
        y = kweight(x)
    n = y.shape[-1]
    blk, hop = ns(0.4), ns(0.1)
    if n < blk:
        z = np.mean(y * y, axis=-1).sum()
        return float(-0.691 + 10 * np.log10(z + 1e-20))
    cs = np.concatenate([np.zeros((y.shape[0], 1)), np.cumsum(y * y, axis=-1)], axis=-1)
    starts = np.arange(0, n - blk + 1, hop)
    z = ((cs[:, starts + blk] - cs[:, starts]) / blk).sum(axis=0)
    lk = -0.691 + 10 * np.log10(z + 1e-20)
    g = z[lk > -70.0]
    if len(g) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(g)) - 10.0
    g2 = z[(lk > -70.0) & (lk > rel)]
    return float(-0.691 + 10 * np.log10(np.mean(g2)))


def momentary_max(x):
    """Max momentary loudness (400 ms window, 10 ms hop), LUFS; short sounds zero-padded."""
    x = np.atleast_2d(x)
    y = kweight(np.concatenate([x, np.zeros((x.shape[0], ns(0.4)))], axis=-1))
    blk, hop = ns(0.4), ns(0.01)
    cs = np.concatenate([np.zeros((y.shape[0], 1)), np.cumsum(y * y, axis=-1)], axis=-1)
    starts = np.arange(0, max(1, y.shape[-1] - blk + 1), hop)
    z = ((cs[:, starts + blk] - cs[:, starts]) / blk).sum(axis=0)
    return float(-0.691 + 10 * np.log10(np.max(z) + 1e-20))


# ============================================================================ loops (ambience)
def circ_add(buf, sig, start, gain=1.0):
    """Add sig into a loop buffer at sample `start`, wrapping around the end.  buf (n,) or (2, n);
    sig mono or stereo matching buf."""
    L = buf.shape[-1]
    start = int(start) % L
    s = sig * gain
    m = s.shape[-1]
    pos = 0
    while pos < m:
        i = (start + pos) % L
        k = min(m - pos, L - i)
        buf[..., i:i + k] += s[..., pos:pos + k]
        pos += k
    return buf


def circ_conv(x, h):
    """Circular convolution of loop x with impulse response h (h folded modulo len(x))."""
    L = x.shape[-1]
    h = np.atleast_1d(h)
    if h.shape[-1] > L:
        reps = int(np.ceil(h.shape[-1] / L))
        hp_ = np.zeros(h.shape[:-1] + (reps * L,))
        hp_[..., :h.shape[-1]] = h
        h = hp_.reshape(h.shape[:-1] + (reps, L)).sum(axis=-2)
    H = np.fft.rfft(h, L, axis=-1)
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * H, L, axis=-1)


def circ_reverb(x, preset='outdoor', wet=0.3, dry=1.0):
    """Seamless (circular) reverb for loop buffers; x mono or stereo; output same shape."""
    if np.ndim(x) == 1:
        return dry * x + wet * circ_conv(x, make_ir(preset))
    ir = make_ir(preset, stereo=True)
    return dry * x + wet * np.vstack([circ_conv(x[0], ir[0]), circ_conv(x[1], ir[1])])


def circ_apply(fn, x, warm_s=1.0, *ctrl):
    """Run a causal processor on a loop as if it had been running forever: prepend the loop's own
    tail (warm-up), process, crop.  Extra per-sample control arrays are extended the same way and
    passed to fn as extra positional args."""
    L = x.shape[-1]
    W = min(L, ns(warm_s))
    xe = np.concatenate([x[..., -W:], x], axis=-1)
    ce = [np.concatenate([c[-W:], c]) for c in ctrl]
    return fn(xe, *ce)[..., W:]


def loop_crossfade(x, L, fade_s=1.0):
    """Generic tail-into-head crossfade: x has >= L + C samples; returns exactly L samples where
    the first C samples are an equal-power blend of x[:C] (fading in) and x[L:L+C] (fading out),
    so sample L-1 flows continuously into sample 0."""
    C = min(ns(fade_s), x.shape[-1] - L)
    y = np.array(x[..., :L], copy=True)
    if C > 0:
        u = np.arange(C) / C
        fi, fo = np.sin(0.5 * np.pi * u), np.cos(0.5 * np.pi * u)
        y[..., :C] = x[..., :C] * fi + x[..., L:L + C] * fo
    return y


def periodic_env(L, rng, rate_hz, lo=0.0, hi=1.0, power=1.0):
    """Smooth random control curve, exactly periodic over L samples, mapped into [lo, hi]."""
    s = smooth_noise(L, rng, rate_hz)
    u = 0.5 + 0.5 * np.tanh(0.9 * s)
    return lo + (hi - lo) * u ** power


# ============================================================================ io
def to_int16(x):
    return np.round(np.clip(x, -1.0, 32767.0 / 32768.0) * 32767.0).astype('<i2')


def write_wav(path, x):
    """16-bit PCM mono (1-D) or stereo ((2, n)) WAV at SR."""
    x = np.asarray(x)
    ch = 1 if x.ndim == 1 else x.shape[0]
    pcm = to_int16(x if x.ndim == 1 else x.T.reshape(-1))
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def read_wav(path):
    """-> float array (n,) or (ch, n) in [-1, 1), sample rate."""
    with wave.open(str(path), 'rb') as w:
        ch, sw, sr, nf = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(nf)
    if sw != 2:
        raise ValueError('only 16-bit WAV supported')
    a = np.frombuffer(raw, dtype='<i2').astype(float) / 32768.0
    if ch > 1:
        a = a.reshape(-1, ch).T
    return a, sr


def write_ogg(path, x, quality=5):
    """Stereo (2, n) float -> OGG Vorbis via ffmpeg/libvorbis (bit-exact flags for determinism)."""
    x = np.atleast_2d(x)
    data = np.ascontiguousarray(x.T.astype('<f4')).tobytes()
    cmd = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-f', 'f32le', '-ar', str(SR),
           '-ac', str(x.shape[0]), '-i', 'pipe:0', '-map_metadata', '-1', '-fflags', '+bitexact',
           '-flags:a', '+bitexact', '-c:a', 'libvorbis', '-q:a', str(quality), str(path)]
    subprocess.run(cmd, input=data, check=True)


def read_audio(path, channels=None):
    """Decode any file via ffmpeg -> float32 (ch, n) at SR."""
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(path), '-f', 'f32le',
           '-ar', str(SR)]
    if channels:
        cmd += ['-ac', str(channels)]
    cmd += ['pipe:1']
    probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries',
                            'stream=channels', '-of', 'csv=p=0', str(path)],
                           capture_output=True, text=True, check=True)
    ch = channels or int(probe.stdout.strip().split(',')[0])
    out = subprocess.run(cmd, capture_output=True, check=True).stdout
    a = np.frombuffer(out, dtype='<f4').astype(float)
    return a.reshape(-1, ch).T
