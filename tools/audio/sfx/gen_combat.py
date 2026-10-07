"""gen_combat.py -- combat, creatures, weapons and ruins sounds.

Register: gritty, tense and punchy (beyond the fence).  Gore is implied through meaty, saturated
thuds -- never squelchy.  Creatures are Klatt-style formant voices driven by irregular (creaky)
glottal pulses plus turbulent rasp.  Guns follow the classic transient + body + tail recipe with
urban slap-back reverb.
"""
import numpy as np

import synth as S
from synth import ns, note, Mix
import parts as P
from parts import norm
from registry import sfx, COMBAT


def grit_out(y, lp_hz=9000.0, hp_hz=40.0, drive=1.5, asym=0.0):
    """Final polish for ruins-side sounds: saturation for density, band-limit."""
    y = S.sat(norm(y), drive, asym) if drive else norm(y)
    return S.butter(S.butter(y, 'hp', hp_hz, 2), 'lp', lp_hz, 2)


# ============================================================================ melee
_SWING = [
    dict(dur=0.28, f=(420, 2000, 700), q=2.6, body=0.15, whistle=0.35),
    dict(dur=0.2, f=(560, 2700, 950), q=2.8, body=0.08, whistle=0.0),
    dict(dur=0.38, f=(260, 1250, 400), q=2.0, body=0.35, whistle=0.0),
]


@sfx('swing', peak=-6, variants=3, category=COMBAT,
     desc=['Melee swing: blade whoosh with a thin edge whistle', 'Melee swing: quick, light, airy',
           'Melee swing: heavy blunt weapon, low and slow'])
def swing(rng, v):
    p = _SWING[v - 1]
    d = p['dur']
    pts = [(0, p['f'][0]), (0.45 * d, p['f'][1]), (d, p['f'][2])]
    amp = [(0, 0.12), (0.45 * d, 1.0), (0.72 * d, 0.35), (d, 0.0)]
    y = P.whoosh(rng, d, pts, q=p['q'], amp_pts=amp, body=p['body'], whistle=p['whistle'])
    lo = P.whoosh(rng, d, [(t, f * 0.5) for t, f in pts], q=p['q'] * 0.8, amp_pts=amp)
    return grit_out(y + 0.45 * lo, lp_hz=9000.0, hp_hz=90.0, drive=1.2)


_HIT = [
    dict(f0=170, f1=60, tau=0.07, slap_f=900, slap=0.8, flesh=230, crunch=0.0, drive=2.0),
    dict(f0=140, f1=48, tau=0.1, slap_f=600, slap=0.65, flesh=180, crunch=0.0, drive=2.5),
    dict(f0=200, f1=70, tau=0.055, slap_f=1300, slap=1.0, flesh=260, crunch=0.35, drive=1.8),
]


def meaty_hit(rng, f0, f1, tau, slap_f, slap, flesh, crunch=0.0, drive=2.0, dur=0.35):
    """Body impact: short low punch + mid 'smack' (band-passed noise ringing a damped flesh
    resonance) + a dull thwack layer + transient click, saturated together."""
    m = Mix(dur)
    m.add(norm(S.thump(dur, f0, max(f1, 85.0), 0.01, tau * 0.5)), 0.0, 0.55)
    sb = S.burst(0.09, rng, 0.0004, 0.012, filt=[('bp', slap_f, 0.9)])
    m.add(norm(sb), 0.0, slap)
    fl = S.resonate(S.pad_to(sb, ns(0.25)), [flesh, flesh * 1.9, flesh * 3.1], [0.03, 0.018, 0.01],
                    [1.0, 0.5, 0.25])
    m.add(norm(S.end_fade(fl, frac=0.3)), 0.0, 0.85)
    m.add(norm(S.burst(0.12, rng, 0.0005, 0.022, filt=[('lp', 1600), ('hp', 150)])), 0.0, 0.8)
    m.add(norm(S.burst(0.005, rng, 0.0001, 0.0008, filt=[('hp', 2000), ('lp', 7000)])), 0.0, 0.25)
    if crunch:
        m.add(P.grit(rng, 0.07, 60, 600, 2500, 0.015, attack=0.001, q=1.4), 0.002, crunch)
    return S.sat(norm(m.out()), drive)


@sfx('hit', peak=-2, variants=3, category=COMBAT,
     desc=['Meaty body hit: punchy thud with a slap', 'Meaty hit: heavier and darker',
           'Meaty hit: snappier with a bony crunch'])
def hit(rng, v):
    p = _HIT[v - 1]
    y = meaty_hit(rng, p['f0'], p['f1'], p['tau'], p['slap_f'], p['slap'], p['flesh'], p['crunch'], p['drive'])
    return grit_out(y, lp_hz=8000.0, drive=0)


@sfx('hit_metal', peak=-2, category=COMBAT,
     desc='Weapon striking metal (armour, car body): clang with ringing partials and a thud')
def hit_metal(rng):
    m = Mix(1.0)
    m.add(P.metal_clank(rng, 520.0, 0.9, 9, 0.45, 0.3, 0.85, 0.5, 2, thud=0.2), 0.0, 1.0)
    m.add(P.body_thud(rng, 170.0, 70.0, 0.05, 800.0, 0.6, 0.3), 0.0, 0.6)
    return grit_out(m.out(), lp_hz=10000.0, drive=1.3)


@sfx('crit', peak=-1, category=COMBAT,
     desc='Critical hit: heavier saturated impact plus a bright metallic "shing" sting')
def crit(rng):
    m = Mix(1.0)
    m.add(meaty_hit(rng, 135.0, 42.0, 0.12, 750.0, 0.9, 200.0, 0.4, 3.0, 0.45), 0.0, 1.0)
    n = ns(0.6)
    exc = S.burst(0.02, rng, 0.0002, 0.004, filt=[('hp', 2000)])
    shing = S.resonate(S.pad_to(exc, n), [2450, 3610, 5230, 6900, 2462], [0.25, 0.2, 0.12, 0.08, 0.22],
                       [1.0, 0.7, 0.4, 0.2, 0.6])
    t = S.tvec(n)
    zing = S.sine(S.env_pts(n, [(0, 1800), (0.2, 2600)], 'exp'), n) * S.env_ad(n, 0.003, 0.08)
    m.add(norm(S.end_fade(shing)) + 0.25 * norm(S.end_fade(zing)), 0.01, 0.45)
    y = S.reverb(m.out(), 'small', wet=0.15)
    return grit_out(y, lp_hz=11000.0, drive=1.2)


@sfx('player_hurt', peak=-4, variants=2, category=COMBAT,
     desc=['Player hurt: impact plus a short filtered "hm!" grunt',
           'Player hurt: sharper impact plus a higher "nh!" grunt'])
def player_hurt(rng, v):
    m = Mix(0.5)
    if v == 1:
        m.add(meaty_hit(rng, 150.0, 70.0, 0.05, 800.0, 0.7, 220.0, 0.0, 1.8, 0.25), 0.0, 1.0)
        g = P.creature(rng, 0.17, [(0, 190), (0.17, 150)], [(0, 'uh'), (0.1, 'uh'), (0.17, 'm')],
                       scale=1.05, bw_scale=1.3, breath=0.15, jitter=0.02,
                       amp_pts=[(0, 0), (0.012, 1), (0.1, 0.8), (0.17, 0)])
        m.add(S.butter(g, 'lp', 2500.0, 2), 0.02, 0.55)
    else:
        m.add(meaty_hit(rng, 190.0, 80.0, 0.04, 1200.0, 0.9, 260.0, 0.15, 2.0, 0.22), 0.0, 1.0)
        g = P.creature(rng, 0.14, [(0, 225), (0.14, 175)], [(0, 'e'), (0.08, 'e'), (0.14, 'n')],
                       scale=1.12, bw_scale=1.3, breath=0.18, jitter=0.02,
                       amp_pts=[(0, 0), (0.01, 1), (0.08, 0.8), (0.14, 0)])
        m.add(S.butter(g, 'lp', 2800.0, 2), 0.015, 0.55)
    return grit_out(m.out(), lp_hz=7000.0, drive=1.2)


@sfx('player_death', peak=-3, category=COMBAT, cost=2.0,
     desc='Player death: heavy low hit, then a slow descending, fading tone (~2 s)')
def player_death(rng):
    m = Mix(2.6)
    m.add(meaty_hit(rng, 120.0, 38.0, 0.16, 500.0, 0.7, 170.0, 0.0, 2.5, 0.6), 0.0, 1.0)
    dur = 1.7
    n = ns(dur)
    t = S.tvec(n)
    f = 98.0 + (440.0 - 98.0) * (1.0 - np.clip(t / 1.5, 0, 1)) ** 1.6
    f = f * (1.0 + 0.01 * np.sin(2 * np.pi * 5.0 * t))
    tone = 0.6 * S.tri(f, n) + 0.4 * S.sine(f, n) + 0.25 * S.sine(f * 0.5, n)
    tone = S.lp(tone, 1500.0) * S.env_pts(n, [(0, 0), (0.03, 1.0), (1.0, 0.7), (dur, 0)], 'cos')
    m.add(norm(tone), 0.05, 0.45)
    m.add(S.pad([note('A2'), note('C3'), note('E3')], 1.9, rng, attack=0.4, release=0.9, cutoff=700.0),
          0.0, 0.15)
    y = S.reverb(m.out(), 'hall', wet=0.3)
    return grit_out(y, lp_hz=6000.0, drive=1.1)


# ============================================================================ creatures
_GROAN = [
    dict(dur=1.4, f0=[(0, 78), (0.5, 92), (1.4, 64)],
         path=[(0, 'uh'), (0.4, 'a'), (0.9, 'o'), (1.4, 'u')],
         amp=[(0, 0.35), (0.15, 1.0), (0.7, 0.75), (1.0, 1.0), (1.4, 0)]),
    dict(dur=1.75, f0=[(0, 70), (0.6, 84), (1.2, 74), (1.75, 58)],
         path=[(0, 'o'), (0.5, 'a'), (1.1, 'uh'), (1.75, 'er')],
         amp=[(0, 0.35), (0.25, 1.0), (0.8, 0.6), (1.2, 0.9), (1.75, 0)]),
    dict(dur=1.95, f0=[(0, 88), (0.4, 76), (1.0, 95), (1.95, 60)],
         path=[(0, 'u'), (0.6, 'a'), (1.2, 'ae'), (1.95, 'uh')],
         amp=[(0, 0.35), (0.2, 0.8), (0.55, 0.5), (1.05, 1.0), (1.95, 0)]),
]


def zombie_voice(rng, dur, f0, path, amp, fry=0.6, rasp=0.5, scale=0.88):
    y = P.creature(rng, dur, f0, path, scale=scale, bw_scale=1.8, jitter=0.08, shimmer=0.25,
                   breath=0.25, oq=0.5, tilt=1800.0, fry=fry, fry_jitter=0.3, rasp=rasp, amp_pts=amp)
    return S.sat(y, 2.0, 0.15)


@sfx('zombie_groan', peak=-4, variants=3, category=COMBAT, cost=1.5,
     desc=['Zombie groan: low rasping "uhh-aah-ooh" (~1.4 s)', 'Zombie groan: longer, darker "oh-aah-urr"',
           'Zombie groan: wavering, swelling moan (~1.9 s)'])
def zombie_groan(rng, v):
    p = _GROAN[v - 1]
    y = zombie_voice(rng, p['dur'], p['f0'], p['path'], p['amp'])
    y = S.reverb(y, 'small', wet=0.12)
    return grit_out(y, lp_hz=4000.0, hp_hz=60.0, drive=1.2)


@sfx('zombie_alert', peak=-2, category=COMBAT,
     desc='Zombie spots you: rising, rasping shriek (~0.9 s)')
def zombie_alert(rng):
    dur = 0.95
    y = P.creature(rng, dur, [(0, 170), (0.65, 480), (0.95, 360)], [(0, 'uh'), (0.25, 'a'), (0.6, 'ae'), (0.95, 'e')],
                   scale=1.0, bw_scale=1.6, jitter=0.06, shimmer=0.25, breath=0.3, oq=0.5, tilt=2500.0,
                   fry=0.3, rasp=0.8, amp_pts=[(0, 0.3), (0.1, 0.7), (0.6, 1.0), (0.95, 0)], f0_mode='exp')
    n = ns(dur)
    scream = S.biquad(S.colored(n, rng, -1.0), 'bp', 2200.0, 1.5) * S.env_pts(
        n, [(0, 0), (0.3, 0.4), (0.65, 1.0), (0.95, 0)], 'cos')
    y = S.sat(y + 0.3 * norm(scream), 3.0, 0.1)
    y = S.reverb(y, 'room', wet=0.15)
    return grit_out(y, lp_hz=6000.0, hp_hz=80.0, drive=1.0)


@sfx('zombie_hurt', peak=-3, category=COMBAT,
     desc='Zombie hurt: meaty thud and a short pained rasping grunt')
def zombie_hurt(rng):
    m = Mix(0.6)
    m.add(meaty_hit(rng, 150.0, 55.0, 0.06, 700.0, 0.8, 200.0, 0.2, 2.0, 0.3), 0.0, 0.8)
    g = zombie_voice(rng, 0.38, [(0, 150), (0.38, 92)], [(0, 'a'), (0.38, 'uh')],
                     [(0, 0.4), (0.03, 1.0), (0.2, 0.7), (0.38, 0)], fry=0.5, rasp=0.6)
    m.add(norm(g), 0.02, 0.9)
    return grit_out(m.out(), lp_hz=5000.0, drive=1.3)


@sfx('zombie_die', peak=-3, category=COMBAT, cost=1.5,
     desc='Zombie dies: descending gurgling rattle, then the body collapsing (~1.6 s)')
def zombie_die(rng):
    m = Mix(1.9)
    dur = 1.0
    g = zombie_voice(rng, dur, [(0, 110), (1.0, 55)], [(0, 'o'), (0.5, 'u'), (1.0, 'uh')],
                     [(0, 0.6), (0.05, 1.0), (0.6, 0.6), (1.0, 0)], fry=0.7, rasp=0.6)
    n = len(g)
    gate = 1.0 - 0.7 * np.clip(0.5 + 0.8 * S.smooth_noise(n, rng, 14.0), 0, 1)
    m.add(norm(g * gate), 0.0, 0.9)
    b = np.zeros(n + ns(0.3))
    for s in np.sort(rng.integers(ns(0.2), ns(0.9), 9)):
        bb = S.bubble(rng.uniform(150, 400), 1.0, rng.uniform(0.1, 0.25))
        b[s:s + len(bb)] += bb
    m.add(norm(b), 0.0, 0.2)
    m.add(P.body_thud(rng, 100.0, 40.0, 0.12, 600.0, 0.8, 0.45), 0.95, 1.0)
    m.add(P.body_thud(rng, 120.0, 50.0, 0.07, 700.0, 0.8, 0.3), 1.15, 0.5)
    k = ns(0.12)
    cloth = S.biquad(S.white(k, rng), 'bp', 1500.0, 1.0) * S.env_ad(k, 0.005, 0.03)
    m.add(norm(S.end_fade(cloth)), 0.96, 0.25)
    m.add(P.debris(rng, 0.4, 5, [(0, 1), (0.4, 0)], (0.1, 0.4)), 0.98, 0.25)
    y = S.reverb(m.out(), 'room', wet=0.12)
    return grit_out(y, lp_hz=5000.0, hp_hz=40.0, drive=1.4)


@sfx('hound_growl', peak=-4, category=COMBAT,
     desc='Mutant hound growl: low, rough, fluttering snarl (~1.3 s)')
def hound_growl(rng):
    dur = 1.3
    y = P.creature(rng, dur, [(0, 80), (0.6, 92), (1.3, 74)], [(0, 'uh'), (0.6, 'a'), (1.3, 'uh')],
                   scale=0.75, bw_scale=1.6, jitter=0.06, shimmer=0.3, breath=0.3, oq=0.5, tilt=2000.0,
                   fry=0.8, fry_jitter=0.2, rasp=0.6, trem=(28.0, 0.4),
                   amp_pts=[(0, 0.3), (0.2, 1.0), (1.0, 0.85), (1.3, 0)])
    y = S.sat(y, 2.0, 0.1)
    y = S.reverb(y, 'small', wet=0.1)
    return grit_out(y, lp_hz=4500.0, hp_hz=50.0, drive=1.2)


@sfx('hound_bark', peak=-2, category=COMBAT,
     desc='Mutant hound bark: one harsh, sudden "ruff" with a ruin echo')
def hound_bark(rng):
    dur = 0.32
    y = P.creature(rng, dur, [(0, 420), (0.03, 560), (0.12, 380), (0.32, 280)],
                   [(0, 'uh'), (0.04, 'a'), (0.15, 'a'), (0.32, 'o')], scale=0.95, bw_scale=1.6,
                   jitter=0.04, shimmer=0.2, breath=0.3, oq=0.5, tilt=3000.0, fry=0.2, rasp=0.9,
                   amp_pts=[(0, 0), (0.008, 1.0), (0.08, 0.8), (0.32, 0)])
    y = S.sat(y, 3.0)
    y = S.reverb(y, 'room', wet=0.15)
    return grit_out(y, lp_hz=6000.0, hp_hz=120.0, drive=1.0)


@sfx('raider_shout', peak=-3, category=COMBAT,
     desc='Raider shout: gruff, short "hey!" (formant voice with rasp, street echo)')
def raider_shout(rng):
    m = Mix(0.7)
    n = ns(0.07)
    F, B = S.vowel_tracks(n, [(0, 'e'), (0.07, 'e')], 1.0, 1.4)
    asp = S.formant_cascade(S.butter(S.white(n, rng), 'hp', 500.0), F, B)
    m.add(norm(asp) * S.env_pts(n, [(0, 0.3), (0.05, 1.0), (0.07, 0.6)], 'cos'), 0.0, 0.35)
    v = P.creature(rng, 0.44, [(0, 150), (0.12, 178), (0.3, 160), (0.44, 120)],
                   [(0, 'e'), (0.18, 'e'), (0.32, 'ih'), (0.44, 'i')], scale=1.0, bw_scale=1.2,
                   jitter=0.02, shimmer=0.08, breath=0.15, oq=0.55, tilt=3500.0, fry=0.15, rasp=0.35,
                   amp_pts=[(0, 0), (0.015, 1.0), (0.25, 0.9), (0.44, 0)])
    m.add(S.sat(v, 2.5), 0.05, 1.0)
    y = S.reverb(m.out(), 'room', wet=0.15)
    return grit_out(y, lp_hz=5500.0, hp_hz=120.0, drive=1.0)


# ============================================================================ guns
def gunshot(rng, crack_hp, crack_tau, blast_tau, thump_f, thump_tau, body_f, body_amp, tail_tau,
            tail_lp, verb_wet, mech_t=None, echo=None, total=1.5, drive=3.0):
    m = Mix(total)
    m.add(norm(S.burst(0.008, rng, 0.00004, crack_tau, filt=[('hp', crack_hp), ('lp', 12000)])), 0.0, 1.0)
    n = ns(0.2)
    blast = S.tvf(S.white(n, rng), 'lp', S.env_pts(n, [(0, 9000), (0.05, 900), (0.2, 500)], 'exp'), 0.7)
    blast *= S.env_ad(n, 0.0002, blast_tau)
    m.add(norm(S.end_fade(blast)), 0.0, 0.9)
    m.add(norm(S.thump(0.35, thump_f[0], thump_f[1], 0.012, thump_tau)), 0.0, 0.95)
    m.add(norm(S.burst(0.15, rng, 0.0003, blast_tau * 1.6, filt=[('bp', body_f, 0.8)])), 0.0, body_amp)
    y = S.sat(norm(m.out()), drive)
    out = Mix(total)
    out.add(y, 0.0, 1.0)
    nt = ns(total)
    tail = S.butter(S.colored(nt, rng, -3.0), 'lp', tail_lp) * S.env_ad(nt, 0.004, tail_tau)
    out.add(norm(S.end_fade(tail, frac=0.3)), 0.004, 0.3)
    if mech_t is not None:
        out.add(P.latch(rng, 3200.0, 0.06, 0.3), mech_t, 0.12)
    if echo:
        e = S.butter(y, 'lp', 1500.0, 2)
        for (et, eg) in echo:
            out.add(norm(e), et, eg)
    z = S.reverb(out.out(), 'street', wet=verb_wet)
    return S.end_fade(z[:ns(total)], release=min(0.4, total * 0.3))


@sfx('gun_pistol', peak=-1, category=COMBAT,
     desc='Pistol shot: sharp crack, punchy body, short urban tail and slide click')
def gun_pistol(rng):
    y = gunshot(rng, 800.0, 0.0008, 0.012, (140.0, 50.0), 0.05, 420.0, 0.5, 0.16, 1800.0, 0.35,
                mech_t=0.03, echo=[(0.21, 0.12)], total=1.2, drive=3.0)
    return grit_out(y, lp_hz=12000.0, hp_hz=35.0, drive=0)


@sfx('gun_rifle', peak=-1, category=COMBAT, cost=1.5,
     desc='Rifle shot: supersonic crack, deep punch and a long rolling echo (~1.6 s)')
def gun_rifle(rng):
    y = gunshot(rng, 1500.0, 0.0005, 0.016, (110.0, 40.0), 0.07, 350.0, 0.55, 0.3, 1500.0, 0.45,
                mech_t=None, echo=[(0.33, 0.18), (0.62, 0.08)], total=1.7, drive=3.5)
    return grit_out(y, lp_hz=12000.0, hp_hz=30.0, drive=0)


@sfx('gun_shotgun', peak=-1, category=COMBAT, cost=1.5,
     desc='Shotgun blast: wide, heavy boom with a big low body and long tail (~1.6 s)')
def gun_shotgun(rng):
    y = gunshot(rng, 600.0, 0.0012, 0.03, (90.0, 35.0), 0.1, 250.0, 0.8, 0.35, 1300.0, 0.45,
                mech_t=None, echo=[(0.28, 0.15), (0.55, 0.07)], total=1.7, drive=3.5)
    return grit_out(y, lp_hz=11000.0, hp_hz=30.0, drive=0)


@sfx('gun_empty', peak=-9, category=COMBAT,
     desc='Dry fire: trigger and hammer clicks on an empty chamber')
def gun_empty(rng):
    m = Mix(0.12)
    m.add(P.latch(rng, 3000.0, 0.04, 0.2), 0.0, 0.6)
    m.add(P.latch(rng, 2400.0, 0.05, 0.5), 0.022, 1.0)
    return grit_out(m.out(), lp_hz=9000.0, hp_hz=200.0, drive=0)


@sfx('reload', peak=-5, category=COMBAT,
     desc='Reload: magazine release, slide out, magazine clack in, slide rack (~1 s)')
def reload(rng):
    m = Mix(1.2)
    m.add(P.latch(rng, 2600.0, 0.05, 0.3), 0.0, 0.5)
    n = ns(0.07)
    sl = S.biquad(S.white(n, rng), 'bp', 2100.0, 1.5) * S.env_bell(n, 0.4)
    m.add(norm(sl), 0.07, 0.25)
    m.add(P.metal_clank(rng, 900.0, 0.2, 5, 0.04, 0.5, 0.9, 0.6, 0, thud=0.5), 0.36, 1.0)
    m.add(P.latch(rng, 1800.0, 0.06, 0.8), 0.37, 0.6)
    n = ns(0.09)
    pull = S.tvf(S.white(n, rng), 'bp', S.env_pts(n, [(0, 1600), (0.09, 2600)], 'exp'), 2.0) * S.env_bell(n, 0.5)
    m.add(norm(pull), 0.62, 0.3)
    m.add(P.latch(rng, 2200.0, 0.05, 0.4), 0.7, 0.55)
    m.add(P.metal_clank(rng, 1100.0, 0.18, 5, 0.035, 0.5, 0.95, 0.7, 0, thud=0.4), 0.78, 0.95)
    y = S.reverb(m.out(), 'small', wet=0.1)
    return grit_out(y, lp_hz=11000.0, hp_hz=120.0, drive=1.2)


@sfx('crossbow', peak=-3, category=COMBAT,
     desc='Crossbow: string twang and limb thump, then the bolt whooshing away')
def crossbow(rng):
    m = Mix(0.8)
    m.add(P.latch(rng, 2200.0, 0.04, 0.3), 0.0, 0.3)
    tw = S.pluck(118.0, 0.6, rng, t60=0.45, bright=0.8, pick=0.08)
    tw2 = S.pad_to(S.pluck(236.5, 0.4, rng, t60=0.25, bright=0.7, pick=0.1), len(tw))
    m.add(norm(tw + 0.4 * tw2), 0.004, 0.9)
    m.add(norm(S.thump(0.15, 190.0, 80.0, 0.01, 0.03)), 0.004, 0.6)
    wh = P.whoosh(rng, 0.38, [(0, 2600), (0.38, 900)], q=2.0, amp_pts=[(0, 0.2), (0.04, 1.0), (0.38, 0)])
    m.add(wh, 0.01, 0.45)
    return grit_out(m.out(), lp_hz=9000.0, hp_hz=60.0, drive=1.5)


@sfx('slingshot', peak=-4, category=COMBAT,
     desc='Slingshot: rubber-band snap ("thwap") and a small whoosh')
def slingshot(rng):
    m = Mix(0.45)
    m.add(norm(S.burst(0.005, rng, 0.0001, 0.0008, filt=[('bp', 1500.0, 0.9)])), 0.0, 0.6)
    n = ns(0.12)
    t = S.tvec(n)
    f = 90.0 + 150.0 * np.exp(-t / 0.012)
    tw = S.sine(f * (1.0 + 0.05 * np.sin(2 * np.pi * 32.0 * t)), n) * S.env_ad(n, 0.001, 0.035)
    m.add(norm(S.end_fade(tw)), 0.0, 1.0)
    m.add(norm(S.strike(ns(0.12), [180.0, 410.0], [1.0, 0.4], [0.03, 0.015], attack=0.0005)), 0.0, 0.4)
    m.add(P.whoosh(rng, 0.18, [(0, 1800), (0.18, 1100)], q=1.8, amp_pts=[(0, 0.3), (0.03, 1), (0.18, 0)]),
          0.01, 0.35)
    return grit_out(m.out(), lp_hz=8000.0, hp_hz=60.0, drive=1.6)


@sfx('bullet_impact', peak=-4, category=COMBAT,
     desc='Bullet impact: sharp "thwip" hit with concrete chips and a ricochet whine')
def bullet_impact(rng):
    m = Mix(0.7)
    m.add(norm(S.burst(0.01, rng, 0.0001, 0.0018, filt=[('bp', 2500.0, 0.8)])), 0.0, 1.0)
    m.add(P.body_thud(rng, 220.0, 120.0, 0.02, 1500.0, 1.0, 0.08), 0.0, 0.5)
    for _ in range(5):
        m.add(P.stone_click(rng, None, 0.04), rng.uniform(0.005, 0.12), rng.uniform(0.15, 0.35))
    dur = 0.5
    n = ns(dur)
    t = S.tvec(n)
    f = 1500.0 + (3400.0 - 1500.0) * (1.0 - np.clip(t / 0.45, 0, 1)) ** 1.5
    f = f * (1.0 + 0.02 * S.smooth_noise(n, rng, 30.0))
    whine = S.sine(f, n)
    whine += 0.6 * norm(S.tvf(S.white(n, rng), 'bp', f, 8.0))
    whine *= S.env_pts(n, [(0, 0), (0.006, 0.6), (0.03, 1.0), (0.2, 0.5), (dur, 0)], 'cos')
    m.add(norm(whine), 0.012, 0.45)
    y = S.reverb(m.out(), 'street', wet=0.15)
    return grit_out(y, lp_hz=10000.0, hp_hz=100.0, drive=1.3)


@sfx('explosion', peak=-1, category=COMBAT, cost=3.0,
     desc='Explosion: big saturated boom with sub drop, then a falling-debris tail (~2.4 s)')
def explosion(rng):
    total = 2.6
    m = Mix(total)
    n = ns(0.6)
    blast = S.tvf(S.white(n, rng), 'lp', S.env_pts(n, [(0, 6000), (0.3, 300), (0.6, 150)], 'exp'), 0.7)
    blast *= S.env_ad(n, 0.0003, 0.09)
    m.add(norm(S.end_fade(blast)), 0.0, 1.0)
    m.add(norm(S.thump(1.2, 75.0, 28.0, 0.08, 0.35)), 0.0, 1.0)
    nr = ns(2.2)
    rum = S.butter(S.colored(nr, rng, -6.0), 'lp', 120.0) * S.env_ad(nr, 0.01, 0.7)
    rum *= np.clip(1.0 + 0.3 * S.smooth_noise(nr, rng, 5.0), 0.2, 2.0)
    m.add(norm(S.end_fade(rum)), 0.0, 0.7)
    m.add(norm(S.burst(0.02, rng, 0.00005, 0.002, filt=[('hp', 300.0)])), 0.0, 0.8)
    y = S.sat(norm(m.out()), 3.0)
    out = Mix(total)
    out.add(y, 0.0, 1.0)
    out.add(P.debris(rng, 2.0, 70, [(0, 0.2), (0.25, 1.0), (1.0, 0.4), (2.0, 0)], (0.1, 0.9),
                     metal=0.25, wood=0.15), 0.15, 0.35)
    ng = ns(1.8)
    gravel = S.grains(ng, rng, 500, S.env_pts(ng, [(0, 0.3), (0.3, 1.0), (1.8, 0)]), 800, 4500, 1.2,
                      0.0004, 0.002)
    out.add(norm(gravel), 0.2, 0.15)
    z = S.reverb(out.out(), 'street', wet=0.4)
    z = S.end_fade(z[:ns(total + 0.6)], release=0.6)
    return grit_out(z, lp_hz=9000.0, hp_hz=25.0, drive=1.2)


@sfx('bloater_pop', peak=-2, category=COMBAT,
     desc='Bloater bursting: balloon-like wet pop, low thump, then a hissing gas leak (~1.2 s)')
def bloater_pop(rng):
    m = Mix(1.4)
    m.add(norm(S.burst(0.01, rng, 0.00005, 0.0015, filt=[('hp', 400.0), ('lp', 9000.0)])), 0.0, 1.0)
    m.add(norm(S.thump(0.35, 90.0, 45.0, 0.02, 0.08)), 0.0, 0.9)
    m.add(norm(S.burst(0.12, rng, 0.0003, 0.02, filt=[('bp', 500.0, 0.7)])), 0.0, 0.6)
    b = np.zeros(ns(0.6))
    for s in np.sort(rng.integers(0, ns(0.25), 10)):
        bb = S.bubble(rng.uniform(200, 600), rng.lognormal(0, 0.4), rng.uniform(0.1, 0.3))
        b[s:s + len(bb)] += bb[:len(b) - s]
    m.add(norm(b), 0.005, 0.3)
    n = ns(1.1)
    hiss = S.tvf(S.colored(n, rng, -1.0), 'bp', S.env_pts(n, [(0, 3400), (1.1, 1900)], 'exp'), 0.9)
    hiss *= S.env_pts(n, [(0, 0), (0.03, 1.0), (0.4, 0.5), (1.1, 0)], 'cos')
    hiss *= 1.0 + 0.4 * S.smooth_noise(n, rng, 20.0)
    m.add(norm(hiss), 0.02, 0.45)
    return grit_out(m.out(), lp_hz=8000.0, hp_hz=40.0, drive=1.5)


# ============================================================================ radiation / items
@sfx('geiger_tick', peak=-8, category=COMBAT,
     desc='One Geiger-counter click (the engine schedules them at the dose rate)')
def geiger_tick(rng):
    n = ns(0.016)
    imp = np.zeros(n)
    imp[1] = 1.0
    imp[2] = -0.6
    y = S.resonate(imp, [1850.0, 4200.0, 760.0], [0.0016, 0.0009, 0.0022], [1.0, 0.6, 0.45])
    y += 0.15 * norm(S.pad_to(S.burst(0.0006, rng, 0.00002, 0.0002, filt=[('hp', 1500)]), n))
    return S.butter(S.end_fade(norm(y), frac=0.3), 'lp', 9000.0, 2)


@sfx('rad_warning', peak=-6, category=COMBAT,
     desc='Radiation warning: gritty two-tone dosimeter alarm (hi-lo-hi-lo)')
def rad_warning(rng):
    m = Mix(1.0)
    for i, f in enumerate((740.0, 554.0, 740.0, 554.0)):
        n = ns(0.17)
        tone = S.square(f, n) + 0.5 * S.square(f * 1.006, n, 0.4)
        tone = S.biquad(tone, 'bp', 1100.0, 0.9)
        tone = S.crush(norm(tone), 6)
        tone *= S.env_pts(n, [(0, 0), (0.003, 1.0), (0.15, 1.0), (0.17, 0)], 'lin')
        m.add(tone, 0.2 * i, 1.0)
    n = ns(0.85)
    st = S.grains(n, rng, 60, np.ones(n), 2000, 6000, 1.0, 0.0002, 0.0008)
    m.add(norm(st), 0.0, 0.08)
    return grit_out(m.out(), lp_hz=6000.0, hp_hz=250.0, drive=1.5)


@sfx('heal', peak=-8, category=COMBAT,
     desc='Heal: soft rising chime arpeggio (E major) with a gentle sparkle and warm swell')
def heal(rng):
    m = Mix(1.4)
    for i, nm in enumerate(('E5', 'G#5', 'B5', 'E6')):
        m.add(S.chime(note(nm), 1.0, 0.7 + 0.1 * i, bright=0.3, decay=0.35, attack=0.004, release=0.5),
              0.07 * i)
    for t in np.sort(rng.uniform(0.15, 0.6, 6)):
        nm = rng.choice(['B6', 'E7', 'G#6', 'C#7', 'F#7'])
        m.add(S.musicbox(note(nm), 0.5, rng.uniform(0.06, 0.14), rng, decay=0.3, release=0.25), t)
    m.add(S.pad([note('E4'), note('B4'), note('E5')], 1.1, rng, attack=0.15, release=0.6, cutoff=1500.0),
          0.0, 0.18)
    y = S.reverb(m.out(), 'room', wet=0.25)
    return S.warm(y, lp_hz=9000, drive=0.3)


@sfx('container_open', peak=-5, category=COMBAT, cost=1.5,
     desc='Rummaging a metal locker/crate: latch clank, squeaky wobbling door, items shifting')
def container_open(rng):
    m = Mix(1.5)
    m.add(P.metal_clank(rng, 900.0, 0.3, 6, 0.08, 0.7, 0.75, 0.5, 1, thud=0.2), 0.0, 0.7)
    m.add(P.metal_clank(rng, 160.0, 0.8, 9, 0.35, 0.5, 0.5, 0.2, 0, spread=(0.2, 0.6), thud=0.3), 0.05, 0.5)
    m.add(P.creak(rng, 0.3, [(0, 260), (0.3, 380)], [1300, 2200, 3100], [0.012, 0.008, 0.005],
                  amp_pts=[(0, 0.5), (0.05, 1.0), (0.3, 0)], jitter=0.1), 0.08, 0.3)
    for t in np.sort(rng.uniform(0.35, 1.1, 8)):
        kind = rng.random()
        if kind < 0.45:
            x = P.metal_clank(rng, rng.uniform(900, 2200), 0.2, 5, 0.05, 0.6, 0.7, 0.4, 0, thud=0.0)
        elif kind < 0.75:
            x = P.wood_knock(rng, rng.uniform(400, 900), 0.1, tau1=0.015, hardness=0.5)
        else:
            x = P.stone_click(rng, None, 0.05)
        m.add(x, t, rng.uniform(0.2, 0.45))
    n = ns(0.8)
    rus = S.grains(n, rng, 120, S.env_pts(n, [(0, 0.2), (0.3, 1.0), (0.8, 0)]), 1500, 5000, 1.0, 0.0008,
                   0.004)
    m.add(norm(rus), 0.3, 0.15)
    y = S.reverb(m.out(), 'small', wet=0.15)
    return grit_out(y, lp_hz=9000.0, hp_hz=60.0, drive=1.2)


@sfx('loot_rare', peak=-6, category=COMBAT,
     desc='Rare loot: glittering high bell arpeggio, sparkles and a warm shimmer (~1.4 s)')
def loot_rare(rng):
    m = Mix(2.0)
    m.add(norm(S.thump(0.4, 110.0, 82.0, 0.05, 0.12)), 0.0, 0.25)
    for i, nm in enumerate(('E6', 'G#6', 'B6', 'E7')):
        m.add(S.chime(note(nm), 1.2, 0.6 + 0.1 * i, bright=0.5, decay=0.4, attack=0.002, release=0.5),
              0.045 * i)
    m.add(S.fmbell(note('E6'), 1.3, 0.35, ratio=3.5, index=1.8, tau=0.5, itau=0.15, release=0.5), 0.14)
    for t in np.sort(rng.uniform(0.1, 1.0, 18)):
        nm = rng.choice(['B6', 'E7', 'G#7', 'C#7', 'F#7', 'B7'])
        amp = 0.14 * (1.1 - t)
        m.add(S.musicbox(note(nm), 0.4, amp, rng, decay=0.2, release=0.2), t)
    m.add(S.pad([note('E5'), note('B5'), note('E6')], 1.4, rng, attack=0.1, release=0.8, cutoff=3000.0),
          0.05, 0.12)
    y = S.reverb(m.out(), 'hall', wet=0.3)
    return S.warm(y, lp_hz=11000, drive=0.3, shelf_db=-2.0)


@sfx('door_metal', peak=-2, category=COMBAT, cost=2.0,
     desc='Heavy metal door: big latch clunk, slow groaning hinge, booming clang (~2.6 s)')
def door_metal(rng):
    m = Mix(3.2)
    m.add(P.metal_clank(rng, 450.0, 0.4, 7, 0.1, 0.6, 0.7, 0.5, 1, thud=0.4), 0.0, 0.6)
    g = P.creak(rng, 1.0, [(0, 28), (0.4, 45), (1.0, 30)], [180, 330, 620, 980], [0.08, 0.05, 0.03, 0.02],
                amp_pts=[(0, 0.3), (0.15, 1.0), (0.8, 0.8), (1.0, 0)], jitter=0.15, gains=[1.0, 0.8, 0.5, 0.3])
    m.add(S.sat(g, 1.5), 0.15, 0.55)
    m.add(P.metal_clank(rng, 85.0, 1.6, 12, 0.9, 0.4, 0.6, 0.6, 2, spread=(0.25, 0.7), thud=0.6), 1.15, 1.0)
    m.add(P.body_thud(rng, 90.0, 40.0, 0.15, 500.0, 0.8, 0.5), 1.15, 0.8)
    y = S.reverb(m.out(), 'ruins', wet=0.35)
    return grit_out(y, lp_hz=8000.0, hp_hz=30.0, drive=1.3)


@sfx('stairs', peak=-6, category=COMBAT,
     desc='Level transition: footsteps descending concrete/metal stairs into a low whoosh (~1.4 s)')
def stairs(rng):
    m = Mix(1.8)
    for i in range(4):
        t = 0.27 * i
        L = 0.12
        click = P.stone_click(rng, rng.uniform(1800, 2600), 0.05)
        body = S.burst(L, rng, 0.0005, 0.012, filt=[('lp', 900.0), ('hp', 150.0)])
        ring = S.strike(ns(0.2), [620.0 * (1 - 0.03 * i), 1450.0, 2380.0], [1.0, 0.5, 0.3], [0.06, 0.04, 0.02],
                        attack=0.0003, hardness=0.6)
        step = 0.6 * S.pad_to(click, ns(0.2)) + 0.7 * S.pad_to(norm(body), ns(0.2)) + 0.25 * norm(ring)
        step = S.butter(step, 'lp', 7000.0 * (0.75 ** i), 2)
        m.add(norm(step), t, 1.0 - 0.18 * i)
    n = ns(1.3)
    wh = S.tvf(S.colored(n, rng, -3.0), 'bp', S.env_pts(n, [(0, 300), (1.3, 150)], 'exp'), 0.7)
    wh *= S.env_pts(n, [(0, 0.05), (0.8, 1.0), (1.3, 0)], 'cos')
    m.add(norm(wh), 0.15, 0.45)
    y = S.reverb(m.out(), 'hall', wet=0.25)
    return grit_out(y, lp_hz=8000.0, hp_hz=40.0, drive=1.1)


def radio_click(rng, static_len=0.08):
    m = Mix(static_len + 0.06)
    m.add(P.latch(rng, 1900.0, 0.04, 0.6), 0.0, 0.8)
    n = ns(static_len)
    st = S.butter(S.white(n, rng), 'bp', (1200.0, 4200.0)) * S.env_pts(n, [(0, 1.0), (static_len, 0)], 'lin')
    st *= 1.0 + 0.8 * S.smooth_noise(n, rng, 200.0)
    m.add(norm(S.end_fade(st)), 0.008, 0.45)
    return norm(m.out())


@sfx('extract', peak=-5, category=COMBAT, cost=1.5,
     desc='Extraction/relief: radio click and static, a warm swelling major chord, closing click')
def extract(rng):
    m = Mix(2.6)
    m.add(radio_click(rng, 0.09), 0.0, 0.7)
    p = S.pad([note('A3'), note('C#4'), note('E4'), note('A4')], 2.0, rng, attack=0.7, release=0.8,
              cutoff=1300.0)
    m.add(p, 0.06, 0.6)
    m.add(S.chime(note('A5'), 1.2, 0.25, bright=0.2, decay=0.5, attack=0.01, release=0.6), 0.8)
    m.add(S.chime(note('E6'), 1.0, 0.15, bright=0.2, decay=0.4, attack=0.01, release=0.5), 1.0)
    m.add(radio_click(rng, 0.05), 1.95, 0.45)
    y = S.reverb(m.out(), 'room', wet=0.2)
    return S.warm(y, lp_hz=9000, drive=0.4)


@sfx('alarm', peak=-6, category=COMBAT, cost=2.0,
     desc='Distant, eerie air-raid siren: one slow rise-hold-fall cycle with a long echo (~4.5 s)')
def alarm(rng):
    dur = 4.6
    n = ns(dur)
    t = S.tvec(n)
    f0 = S.env_pts(n, [(0, 330), (1.6, 640), (2.6, 640), (4.4, 300), (dur, 290)], 'cos')
    y = np.zeros(n)
    for det in (0.0, 2.7):
        f = f0 + det
        for k, a in ((1, 1.0), (2, 0.25), (3, 0.33), (5, 0.12)):
            y += a * S.sine(f * k, n, phase0=rng.random())
    y *= 1.0 - 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 34.0 * t))
    y = S.butter(y, 'lp', 1800.0, 2)
    y *= S.env_pts(n, [(0, 0.45), (1.6, 1.0), (2.6, 1.0), (dur, 0)], 'cos')
    y = S.distance(norm(y), 0.55)
    y = S.reverb(y, 'distant', wet=0.6, dry=0.8)
    return grit_out(y, lp_hz=3500.0, hp_hz=120.0, drive=1.0)
