"""gen_ui.py -- UI, dialogue and notification sounds.

Register: soft, tonal, wooden / plucky / bell-like (marimba, kalimba, chime, music box), always
rounded at the top end.  These play thousands of times, so nothing piercing and no naked sine
beeps: every tone is a struck/plucked modal model with a little mallet or tine noise.
"""
import numpy as np

import synth as S
from synth import ns, note, Mix
from registry import sfx, UI


def _wood_tick(rng, f1, dur=0.09, tau=0.022, body=420.0, body_amp=0.35, click=0.15, attack=0.0006,
               drop=0.025, ratios=(1.0, 2.57, 4.4), amps=(1.0, 0.28, 0.07)):
    """Small woodblock / marimba-key 'tok' with a tiny downward pitch settle on the strike."""
    n = ns(dur)
    t = S.tvec(n)
    settle = 1.0 + drop * np.exp(-t / 0.006)
    fr = [f1 * r * settle for r in ratios]
    taus = [tau, tau * 0.36, tau * 0.14]
    y = S.modes(n, fr, amps, taus)
    if body:
        y += body_amp * S.modes(n, [body * settle], [1.0], [tau * 0.55])
    a = max(1, int(attack * S.SR))
    y[:a] *= S.ramp_in(a)
    if click:
        c = S.burst(0.004, rng, 0.0002, 0.0008, filt=[('lp', 6000), ('hp', 600)])
        y[:len(c)] += click * c[:n] / (np.max(np.abs(c)) + 1e-9)
    return y


# ---------------------------------------------------------------------------- clicks
@sfx('ui_click', peak=-12, category=UI,
     desc='Soft wooden "tok" (small woodblock/marimba key) for button presses')
def ui_click(rng):
    y = _wood_tick(rng, 1180.0, dur=0.1, tau=0.024)
    return S.warm(y, lp_hz=8500, drive=0.35)


@sfx('ui_hover', peak=-15, category=UI,
     desc='Very light, short wooden tick for focus/hover changes')
def ui_hover(rng):
    y = _wood_tick(rng, 1397.0, dur=0.06, tau=0.012, body=700.0, body_amp=0.25, click=0.06,
                   attack=0.001, drop=0.015, amps=(1.0, 0.14, 0.03))
    return S.warm(y, lp_hz=8000, drive=0.2)


@sfx('ui_tab', peak=-12, category=UI,
     desc='Paper page-flick swish followed by a small wooden tick (tab switch)')
def ui_tab(rng):
    m = Mix(0.14)
    n = ns(0.045)
    flick = S.tvf(S.white(n, rng), 'bp', S.env_pts(n, [(0, 1400), (0.045, 3600)], 'exp'), 1.1)
    flick *= S.env_bell(n, 0.35, 1.5, 2.0)
    m.add(flick / (np.max(np.abs(flick)) + 1e-9), 0.0, 0.45)
    m.add(_wood_tick(rng, 988.0, dur=0.09, tau=0.02, body=380.0), 0.022, 1.0)
    return S.warm(m.out(), lp_hz=8000, drive=0.3)


# ---------------------------------------------------------------------------- open / close
def _swish(rng, dur, f_a, f_b, amp_peak=0.45):
    n = ns(dur)
    x = S.tvf(S.colored(n, rng, -3.0), 'bp', S.env_pts(n, [(0, f_a), (dur, f_b)], 'exp'), 0.9)
    x *= S.env_bell(n, 0.4, 1.5, 2.0)
    return x / (np.max(np.abs(x)) + 1e-9) * amp_peak


@sfx('ui_open', peak=-12, category=UI,
     desc='Rising two-note marimba (C5 -> G5) over a soft cloth/paper swish (menu/bag open)')
def ui_open(rng):
    m = Mix(0.4)
    m.add(_swish(rng, 0.09, 900, 2200, 0.18), 0.0)
    m.add(S.marimba(note('C5'), None, 0.8, rng, hardness=0.4, decay=0.3), 0.0)
    m.add(S.marimba(note('G5'), None, 1.0, rng, hardness=0.45, decay=0.32), 0.055)
    return S.warm(m.out(), lp_hz=9000, drive=0.4)


@sfx('ui_close', peak=-12, category=UI,
     desc='Falling two-note marimba (G5 -> C5) with a soft swish (menu/bag close)')
def ui_close(rng):
    m = Mix(0.4)
    m.add(_swish(rng, 0.08, 2000, 900, 0.15), 0.0)
    m.add(S.marimba(note('G5'), None, 0.85, rng, hardness=0.4, decay=0.26), 0.0)
    m.add(S.marimba(note('C5'), None, 0.8, rng, hardness=0.35, decay=0.28), 0.055)
    return S.warm(m.out(), lp_hz=8500, drive=0.4)


@sfx('ui_confirm', peak=-12, category=UI,
     desc='Bright, happy rising fifth (E5 -> B5) on marimba with a kalimba glint')
def ui_confirm(rng):
    m = Mix(0.5)
    m.add(S.marimba(note('E5'), None, 0.85, rng, hardness=0.5, decay=0.35), 0.0)
    m.add(S.marimba(note('B5'), None, 1.0, rng, hardness=0.55, decay=0.4), 0.045)
    m.add(S.kalimba(note('B5'), None, 0.35, rng, decay=0.3), 0.045)
    return S.warm(m.out(), lp_hz=9500, drive=0.4)


@sfx('ui_error', peak=-12, category=UI,
     desc='Soft muted "bonk-bonk" falling a semitone (Bb3 -> A3): gentle "nope"')
def ui_error(rng):
    m = Mix(0.45)
    for t, f, v in ((0.0, note('Bb3'), 1.0), (0.12, note('A3'), 0.9)):
        n = ns(0.3)
        body = S.pad_to(S.marimba(f, 0.3, 1.0, rng, hardness=0.15, decay=0.3), n)
        buzz = S.lp(S.tri(f, n) + 0.3 * S.square(f, n, 0.3), 900.0) * S.env_ad(n, 0.004, 0.045)
        m.add(v * (body + 0.35 * S.end_fade(buzz)), t)
    return S.warm(S.lp(m.out(), 2400.0), lp_hz=5000, drive=0.5)


@sfx('ui_purchase', peak=-12, category=UI,
     desc='Two soft coin clinks then a rising marimba "ka-ching" (G5 -> C6)')
def ui_purchase(rng):
    m = Mix(0.7)
    for t, f1 in ((0.0, 2100.0), (0.05, 2370.0)):
        n = ns(0.6)
        c = S.strike(n, [f1, f1 * 1.52, f1 * 2.33, f1 * 3.1], [1.0, 0.6, 0.35, 0.2],
                     [0.12, 0.08, 0.05, 0.03], attack=0.0004, hardness=0.6, rng=rng)
        m.add(c, t, 0.32)
    m.add(S.marimba(note('G5'), None, 0.8, rng, hardness=0.5, decay=0.35), 0.09)
    m.add(S.marimba(note('C6'), None, 1.0, rng, hardness=0.55, decay=0.5), 0.16)
    m.add(S.kalimba(note('C6'), None, 0.3, rng, decay=0.35), 0.16)
    return S.warm(m.out(), lp_hz=9000, drive=0.4)


# ---------------------------------------------------------------------------- dialogue blips
def _blip(rng, f0, va, vb, dur, scale):
    n = ns(dur + 0.02)
    t = S.tvec(n)
    f = f0 * (1.03 - 0.06 * t / dur)
    y = S.voice(f, [(0.0, va), (dur, vb)], n, rng, scale=scale, jitter=0.004, shimmer=0.02,
                breath=0.03, oq=0.55, tilt_hz=2600.0)
    env = S.env_pts(n, [(0, 0), (0.0025, 1.0), (dur * 0.45, 0.85), (dur, 0.0)], 'cos')
    y = y * env
    return S.butter(y, 'lp', 4200.0, 2)


@sfx('dialogue_blip_low', peak=-13, category=UI,
     desc='40 ms low voice-ish blip ("bo", f0 ~140 Hz) per typed character')
def dialogue_blip_low(rng):
    return _blip(rng, 140.0, 'o', 'uh', 0.040, 1.0)


@sfx('dialogue_blip_mid', peak=-13, category=UI,
     desc='36 ms mid voice-ish blip ("ba", f0 ~210 Hz) per typed character')
def dialogue_blip_mid(rng):
    return _blip(rng, 210.0, 'uh', 'a', 0.036, 1.08)


@sfx('dialogue_blip_high', peak=-13, category=UI,
     desc='32 ms high voice-ish blip ("be", f0 ~320 Hz) per typed character')
def dialogue_blip_high(rng):
    return _blip(rng, 320.0, 'a', 'e', 0.032, 1.18)


# ---------------------------------------------------------------------------- chimes / jingles
@sfx('notify', peak=-12, category=UI,
     desc='Gentle two-tone chime (A5 -> E6) for toasts/notifications')
def notify(rng):
    m = Mix(1.0)
    m.add(S.chime(note('A5'), 1.3, 0.85, bright=0.3, decay=0.4, attack=0.003, release=0.6), 0.0)
    m.add(S.chime(note('E6'), 1.3, 1.0, bright=0.25, decay=0.4, attack=0.003, release=0.6), 0.09)
    y = S.reverb(m.out(), 'room', wet=0.16)
    return S.warm(y, lp_hz=8500, drive=0.25)


@sfx('quest_complete', peak=-12, category=UI,
     desc='Warm three-note marimba/kalimba flourish (C5 E5 G5) landing on a soft chord')
def quest_complete(rng):
    m = Mix(1.4)
    for i, (t, nm) in enumerate(((0.0, 'C5'), (0.1, 'E5'), (0.2, 'G5'))):
        last = i == 2
        m.add(S.marimba(note(nm), 1.2 if last else 0.6, 0.9 if last else 0.75, rng, hardness=0.45,
                        decay=1.2 if last else 0.6, release=0.5 if last else 0.3), t)
        m.add(S.kalimba(note(nm), 1.2 if last else 0.6, 0.35, rng, decay=0.8 if last else 0.4,
                        release=0.5 if last else 0.3), t)
    m.add(S.chime(note('C6'), 1.2, 0.3, bright=0.2, decay=0.5, attack=0.004, release=0.6), 0.2)
    m.add(S.pad([note('C4'), note('E4'), note('G4')], 1.15, rng, attack=0.08, release=0.6,
                cutoff=1100.0), 0.18, 0.12)
    y = S.reverb(m.out(), 'room', wet=0.2)
    return S.warm(y, lp_hz=9000, drive=0.35)


@sfx('level_up', peak=-12, category=UI,
     desc='Short celebratory fanfare (~1.2 s): soft chiptune arpeggio to a held C-major chord')
def level_up(rng):
    m = Mix(1.4)
    arp = ((0.0, 'C5'), (0.07, 'E5'), (0.14, 'G5'))
    for t, nm in arp:
        m.add(S.chip(note(nm), 0.3, duty=0.25, cutoff=2600.0, attack=0.003, tau=0.05,
                     release=0.1), t, 0.55)
        m.add(S.marimba(note(nm), None, 0.4, rng, hardness=0.5, decay=0.3), t)
    lead = S.chip(note('C6'), 1.05, duty=0.3, cutoff=2800.0, attack=0.006, tau=0.5,
                  vib_rate=6.0, vib_depth=0.006, vib_delay=0.2, release=0.45)
    m.add(lead, 0.21, 0.55)
    m.add(S.chip(note('G5'), 1.0, duty=0.5, cutoff=2000.0, attack=0.01, tau=0.45, release=0.45),
          0.21, 0.28)
    m.add(S.pad([note('C5'), note('E5'), note('G5')], 1.0, rng, attack=0.04, release=0.55,
                cutoff=1800.0), 0.21, 0.16)
    m.add(S.musicbox(note('G6'), 0.7, 0.18, rng, decay=0.5, release=0.3), 0.27)
    m.add(S.musicbox(note('C7'), 0.7, 0.15, rng, decay=0.5, release=0.3), 0.33)
    y = S.reverb(m.out(), 'room', wet=0.18)
    return S.warm(y, lp_hz=9000, drive=0.35)


@sfx('save', peak=-13, category=UI,
     desc='Soft single chime (G5 with a faint music-box octave) confirming a save')
def save(rng):
    m = Mix(1.0)
    m.add(S.chime(note('G5'), 1.3, 1.0, bright=0.22, decay=0.42, attack=0.006, release=0.6), 0.0)
    m.add(S.musicbox(note('G6'), 0.8, 0.12, rng, decay=0.5, release=0.35), 0.0)
    y = S.reverb(m.out(), 'room', wet=0.2)
    return S.warm(y, lp_hz=8000, drive=0.2)


@sfx('day_start', peak=-12, category=UI, cost=3.0,
     desc='Three strikes of a distant, slightly rusty settlement bell across the fields')
def day_start(rng):
    m = Mix(6.0)
    for t, v in ((0.0, 1.0), (1.3, 0.85), (2.6, 0.92)):
        b = S.church_bell(note('E4'), 4.2, rng, rust=0.55, decay=0.8, release=2.0)
        m.add(b, t, v)
    y = S.distance(m.out(), 0.42)
    y = S.lshelf(y, 180.0, -4.0)
    y = S.reverb(y, 'bell', wet=0.65, dry=0.75)
    return S.warm(y, lp_hz=7000, drive=0.15)


@sfx('sleep', peak=-12, category=UI,
     desc='Soft descending music-box lullaby (G5 E5 C5 G4) over a warm swelling pad (~1.6 s)')
def sleep(rng):
    m = Mix(1.9)
    for i, (t, nm) in enumerate(((0.0, 'G5'), (0.22, 'E5'), (0.44, 'C5'), (0.66, 'G4'))):
        m.add(S.musicbox(note(nm), 1.15, 1.0 - 0.08 * i, rng, decay=0.6, release=0.5), t)
        m.add(S.kalimba(note(nm), 1.0, 0.25, rng, decay=0.5, release=0.45), t)
    p = S.pad([note('C4'), note('E4'), note('G4'), note('C5')], 1.65, rng, attack=0.45,
              release=0.7, cutoff=1000.0, gate=0.9)
    m.add(p, 0.0, 0.22)
    y = S.reverb(m.out(), 'room', wet=0.3)
    return S.warm(y, lp_hz=7500, drive=0.25)


@sfx('achievement', peak=-12, category=UI,
     desc='Sparkling ascending bell arpeggio into a warm sustained major chord (~1.6 s)')
def achievement(rng):
    m = Mix(2.0)
    seq = ('C5', 'G5', 'C6', 'E6', 'G6')
    for i, nm in enumerate(seq):
        t = 0.05 * i
        m.add(S.chime(note(nm), 1.4, 0.55 + 0.08 * i, bright=0.3, decay=0.5, attack=0.002,
                      release=0.6), t)
        m.add(S.kalimba(note(nm), 0.8, 0.3, rng, decay=0.45, release=0.35), t)
    m.add(S.marimba(note('C5'), 1.3, 0.6, rng, hardness=0.4, decay=1.3, release=0.6), 0.25)
    m.add(S.marimba(note('E5'), 1.3, 0.5, rng, hardness=0.4, decay=1.3, release=0.6), 0.25)
    m.add(S.pad([note('C4'), note('G4'), note('C5'), note('E5')], 1.5, rng, attack=0.2,
                release=0.7, cutoff=1500.0), 0.2, 0.2)
    for t, nm in ((0.4, 'C7'), (0.55, 'G6'), (0.7, 'E7')):
        m.add(S.musicbox(note(nm), 0.7, 0.12, rng, decay=0.4, release=0.3), t)
    y = S.reverb(m.out(), 'hall', wet=0.22)
    return S.warm(y, lp_hz=9500, drive=0.3)
