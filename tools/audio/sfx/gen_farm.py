"""gen_farm.py -- farming, world, settlement and animal sounds.

Register: warm, soft, rounded, slightly lo-fi and organic (the cozy Stardew side of the fence).
The high-repeat sounds (footsteps, hoe, water, harvest, pickup) get the most variation and the
gentlest top end.  Every generator returns a mono float array; build_all.py trims, fades and
peak-normalises it to the registered level.
"""
import numpy as np

import synth as S
from synth import ns, note, Mix
import parts as P
from parts import norm
from registry import sfx, FARM


def cozy(y, lp_hz=7500.0, shelf=-3.0, drive=0.5):
    """Final polish for settlement-side sounds: gentle saturation and a rounded top."""
    return S.warm(y, lp_hz=lp_hz, drive=drive, shelf_db=shelf)


# ============================================================================ footsteps
# Each surface: four takes with different transients/envelopes (heel-only vs heel+toe, scuffs,
# grain density, resonances), all very short and quiet (-16 dBFS peak).
_GRASS = [
    dict(len=0.12, sf=2600, satt=0.007, stau=0.026, gn=45, glo=1500, ghi=5500, gtau=0.022, thump=0.12, toe=None),
    dict(len=0.14, sf=3000, satt=0.005, stau=0.022, gn=55, glo=1800, ghi=6000, gtau=0.018, thump=0.09, toe=(0.055, 0.5)),
    dict(len=0.12, sf=2200, satt=0.009, stau=0.03, gn=32, glo=1300, ghi=4800, gtau=0.026, thump=0.15, toe=None),
    dict(len=0.15, sf=2800, satt=0.006, stau=0.024, gn=65, glo=1600, ghi=6200, gtau=0.016, thump=0.1, toe=(0.068, 0.42)),
]


def _grass_contact(rng, p, scale=1.0):
    n = ns(p['len'])
    sw = S.biquad(S.colored(n, rng, -1.0), 'bp', p['sf'], 0.7) * S.env_ad(n, p['satt'], p['stau'])
    g = P.grit(rng, p['len'], int(p['gn'] * scale), p['glo'], p['ghi'], p['gtau'], attack=0.003,
               q=2.0, dlo=0.0005, dhi=0.0025)
    th = S.thump(p['len'], 170.0, 100.0, 0.01, 0.016)
    return 0.55 * norm(S.end_fade(sw)) + 0.75 * g + p['thump'] * norm(th)


@sfx('footstep_grass', peak=-16.5, variants=4, category=FARM,
     desc=['Grass step: soft blade rustle + light foot thump', 'Grass step: heel + toe brush, crisper',
           'Grass step: duller, slower rustle, more foot', 'Grass step: long brush with toe-off'])
def footstep_grass(rng, v):
    p = _GRASS[v - 1]
    m = Mix(0.25)
    m.add(_grass_contact(rng, p), 0.0)
    if p['toe']:
        m.add(_grass_contact(rng, dict(p, len=0.09, thump=0.03), 0.6), p['toe'][0], p['toe'][1])
    return cozy(S.hp(m.out(), 110.0), lp_hz=7500, shelf=-3.0, drive=0.3)


_DIRT = [
    dict(len=0.11, f0=160, gn=20, glo=700, ghi=2600, gtau=0.018, scuff=0.0, toe=None),
    dict(len=0.13, f0=150, gn=28, glo=600, ghi=2300, gtau=0.022, scuff=0.25, toe=None),
    dict(len=0.12, f0=175, gn=16, glo=800, ghi=3000, gtau=0.015, scuff=0.0, toe=(0.05, 0.45)),
    dict(len=0.14, f0=145, gn=34, glo=550, ghi=2100, gtau=0.026, scuff=0.35, toe=(0.06, 0.35)),
]


def _dirt_contact(rng, p, scale=1.0):
    L = p['len']
    th = S.thump(L, p['f0'] * 1.25, 105.0, 0.008, 0.016)
    body = S.burst(L, rng, 0.0012, 0.012, filt=[('lp', 1100, 0.7), ('hp', 160)])
    g = P.grit(rng, L, int(p['gn'] * scale), p['glo'], p['ghi'], p['gtau'], q=1.3)
    y = 0.35 * norm(th) + 0.8 * norm(body) + 0.8 * g
    if p['scuff']:
        n = ns(L)
        sc = S.biquad(S.white(n, rng), 'bp', 1250.0, 1.0) * S.env_ad(n, 0.008, 0.022)
        y = y + p['scuff'] * norm(S.end_fade(sc))
    return y


@sfx('footstep_dirt', peak=-15, variants=4, category=FARM,
     desc=['Dirt step: dull thud + gritty crunch', 'Dirt step: heavier with a short scuff',
           'Dirt step: tight heel + toe', 'Dirt step: soft, crumbly, scuffing'])
def footstep_dirt(rng, v):
    p = _DIRT[v - 1]
    m = Mix(0.25)
    m.add(_dirt_contact(rng, p), 0.0)
    if p['toe']:
        m.add(_dirt_contact(rng, dict(p, len=0.08, f0=p['f0'] * 1.1, scuff=0.0), 0.5), p['toe'][0], p['toe'][1])
    return cozy(S.hp(m.out(), 100.0), lp_hz=5000, shelf=-2.0, drive=0.4)


_WOOD = [
    dict(f1=300, cav=160, tau=0.04, hard=0.4, toe=(0.055, 0.45, 325), creak=0),
    dict(f1=340, cav=175, tau=0.035, hard=0.48, toe=None, creak=0),
    dict(f1=270, cav=150, tau=0.045, hard=0.36, toe=(0.06, 0.4, 290), creak=0),
    dict(f1=360, cav=168, tau=0.033, hard=0.44, toe=None, creak=0.18),
]


@sfx('footstep_wood', peak=-16, variants=4, category=FARM,
     desc=['Wood step: hollow plank knock, heel + toe', 'Wood step: firmer single knock',
           'Wood step: deeper board, heel + toe', 'Wood step: knock with a faint board creak'])
def footstep_wood(rng, v):
    p = _WOOD[v - 1]
    m = Mix(0.3)
    k = P.wood_knock(rng, p['f1'], 0.15, tau1=p['tau'], hardness=p['hard'], cavity=p['cav'],
                     cavity_amp=0.35, contact=0.15, contact_lp=3000.0)
    m.add(k, 0.0)
    m.add(norm(S.thump(0.08, 190.0, 120.0, 0.008, 0.014)), 0.0, 0.15)
    if p['toe']:
        k2 = P.wood_knock(rng, p['toe'][2], 0.12, tau1=p['tau'] * 0.8, hardness=p['hard'] + 0.1,
                          cavity=p['cav'] * 1.05, cavity_amp=0.25, contact=0.18)
        m.add(k2, p['toe'][0], p['toe'][1])
    if p['creak']:
        c = P.creak(rng, 0.09, [(0, 160), (0.09, 230)], [700, 1300, 2100], [0.012, 0.008, 0.005],
                    amp_pts=[(0, 0), (0.02, 1), (0.09, 0)])
        m.add(c, 0.03, p['creak'])
    return cozy(S.hp(m.out(), 110.0), lp_hz=5500, shelf=-2.0, drive=0.4)


_STONE = [
    dict(f=2600, gn=12, scuff=0.0, toe=None),
    dict(f=2100, gn=18, scuff=0.3, toe=None),
    dict(f=3100, gn=10, scuff=0.0, toe=(0.045, 0.5)),
    dict(f=2400, gn=22, scuff=0.4, toe=(0.055, 0.35)),
]


def _stone_contact(rng, f, gn, L=0.08):
    click = P.stone_click(rng, f, 0.04)
    body = S.burst(L, rng, 0.0005, 0.007, filt=[('lp', 900), ('hp', 180)])
    th = S.thump(L, 240.0, 150.0, 0.005, 0.01)
    g = P.grit(rng, L, gn, 2000, 6000, 0.012, attack=0.001, q=1.0, dlo=0.0003, dhi=0.0015)
    return 0.8 * S.pad_to(click, ns(L)) + 0.45 * norm(body) + 0.2 * norm(th) + 0.5 * g


@sfx('footstep_stone', peak=-14, variants=4, category=FARM,
     desc=['Stone step: hard short tap', 'Stone step: tap with a gritty scuff',
           'Stone step: crisp heel + toe', 'Stone step: heavier, sandy drag'])
def footstep_stone(rng, v):
    p = _STONE[v - 1]
    m = Mix(0.2)
    m.add(_stone_contact(rng, p['f'], p['gn']), 0.0)
    if p['toe']:
        m.add(_stone_contact(rng, p['f'] * 1.15, p['gn'] // 2, 0.06), p['toe'][0], p['toe'][1])
    if p['scuff']:
        n = ns(0.06)
        sc = S.biquad(S.white(n, rng), 'bp', 3200.0, 0.9) * S.env_ad(n, 0.006, 0.016)
        m.add(norm(S.end_fade(sc)), 0.012, p['scuff'])
    return cozy(S.hp(m.out(), 140.0), lp_hz=7000, shelf=-3.0, drive=0.4)


# ============================================================================ farming tools
_HOE = [
    dict(f0=210, f1=95, crunch=100, clo=500, chi=3200, tau=0.05, tick=0.16, scatter=14, scrape=0.0),
    dict(f0=180, f1=80, crunch=120, clo=380, chi=2500, tau=0.065, tick=0.10, scatter=18, scrape=0.0),
    dict(f0=240, f1=110, crunch=85, clo=650, chi=4000, tau=0.04, tick=0.2, scatter=10, scrape=0.3),
]


@sfx('hoe', peak=-6, variants=3, category=FARM,
     desc=['Hoe into dirt: thud + soil crunch + scattered crumbs', 'Hoe: deeper, darker, heavier chunk',
           'Hoe: drier, crisper bite with a short drag'])
def hoe(rng, v):
    p = _HOE[v - 1]
    m = Mix(0.5)
    m.add(norm(S.thump(0.16, p['f0'], p['f1'], 0.012, 0.035)), 0.0, 0.5)
    m.add(norm(S.burst(0.12, rng, 0.0012, 0.016, filt=[('lp', 1000, 0.8), ('hp', 120)])), 0.0, 0.7)
    m.add(P.grit(rng, 0.35, p['crunch'], p['clo'], p['chi'], p['tau'], attack=0.002, q=1.2), 0.002, 1.0)
    tick = S.strike(ns(0.06), [2350, 3720, 5100], [1.0, 0.5, 0.25], [0.012, 0.008, 0.005],
                    attack=0.0002, hardness=0.6, rng=rng)
    m.add(norm(tick), 0.0, p['tick'])
    n2 = ns(0.3)
    dens = S.env_pts(n2, [(0, 0), (0.03, 1.0), (0.25, 0.1), (0.3, 0)])
    m.add(norm(S.grains(n2, rng, p['scatter'], dens, 900, 3500, 1.5, 0.0004, 0.0015)), 0.05, 0.22)
    if p['scrape']:
        n = ns(0.12)
        sc = S.tvf(S.white(n, rng), 'bp', S.env_pts(n, [(0, 1400), (0.12, 900)], 'exp'), 1.4)
        sc *= S.env_pts(n, [(0, 0), (0.02, 1), (0.12, 0)], 'cos')
        m.add(norm(sc), 0.06, p['scrape'])
    return cozy(S.hp(m.out(), 70.0), lp_hz=6500, shelf=-2.0, drive=0.8)


@sfx('water', peak=-10, variants=2, category=FARM, cost=2.0,
     desc=['Watering-can pour: soft stream, droplet plinks and soil patter (~0.9 s)',
           'Watering-can splash: shorter, splashier start, lower droplets (~0.7 s)'])
def water(rng, v):
    dur = (0.85, 0.65)[v - 1]
    n = ns(dur + 0.25)
    env = S.env_pts(n, [(0, 0), (0.05 if v == 1 else 0.02, 1.0), (dur - 0.15, 0.85), (dur, 0.0)], 'cos')
    fl = 1.0 + 0.25 * S.smooth_noise(n, rng, 14.0)
    stream = S.tvf(S.colored(n, rng, -1.5), 'bp', 1700.0 * (1 + 0.15 * S.smooth_noise(n, rng, 6.0)), 0.8)
    stream = norm(stream * env * fl)
    lo, hi = ((900.0, 3200.0), (700.0, 2600.0))[v - 1]
    drops = P.drops(rng, dur + 0.25, int(140 * dur), [(0, 0), (0.04, 1.0), (dur - 0.1, 0.9), (dur - 0.02, 0.0)],
                    lo, hi, (0.08, 0.3))
    patter = S.grains(n, rng, int(160 * dur), env, 300, 1500, 1.4, 0.0005, 0.002)
    soak = S.butter(S.colored(n, rng, -6.0), 'lp', 300.0) * env
    y = 0.45 * stream + 0.55 * drops + 0.35 * norm(patter) + 0.18 * norm(soak)
    if v == 2:
        sp = S.burst(0.12, rng, 0.001, 0.03, filt=[('bp', 900, 0.7)])
        y[:len(sp)] += 0.45 * norm(sp)
        y += 0.25 * P.drops(rng, dur + 0.25, 25, [(0, 1), (0.15, 0.2), (0.3, 0)], 350, 900, (0.1, 0.3))
    return cozy(y, lp_hz=8000, shelf=-3.0, drive=0.4)


@sfx('plant', peak=[-8, -6], variants=2, category=FARM,
     desc=['Seed rustle and two soft hand pats on soil', 'One firm pat then soil crumbling over the seed'])
def plant(rng, v):
    m = Mix(0.6)
    pats = ((0.025, 1.0), (0.15, 0.75)) if v == 1 else ((0.0, 1.0),)
    if v == 1:
        n = ns(0.06)
        r = S.grains(n, rng, 14, S.env_bell(n, 0.4), 2500, 6000, 2.0, 0.0004, 0.0012)
        m.add(norm(r), 0.0, 0.2)
    for t, g in pats:
        m.add(P.body_thud(rng, 170.0, 100.0, 0.028, 1000.0, 1.2, 0.15, 0.008), t, 0.8 * g)
        k = ns(0.1)
        pff = S.butter(S.white(k, rng), 'bp', (350.0, 1100.0)) * S.env_ad(k, 0.002, 0.02)
        m.add(norm(S.end_fade(pff)), t, 0.6 * g)
        m.add(P.grit(rng, 0.12, 16, 700, 2400, 0.03, q=1.3), t, 0.45 * g)
    if v == 2:
        n = ns(0.3)
        dens = S.env_pts(n, [(0, 0), (0.05, 1), (0.3, 0)])
        m.add(norm(S.grains(n, rng, 45, dens, 600, 2400, 1.2, 0.0006, 0.003)), 0.07, 0.32)
    return cozy(S.hp(m.out(), 90.0), lp_hz=4800, shelf=-2.0, drive=0.4)


_HARV = [
    dict(pop=(260.0, 700.0), T=0.03, tear=0.045, rustle=0.25),
    dict(pop=(320.0, 820.0), T=0.025, tear=0.03, rustle=0.15),
    dict(pop=(220.0, 560.0), T=0.035, tear=0.06, rustle=0.3),
]


def pop_tone(rng, fa, fb, T, tau=0.04, dur=0.18):
    """Satisfying 'bloop' pop: fast exponential upward sweep with a mouth-pop resonance."""
    n = ns(dur)
    t = S.tvec(n)
    f = fa * (fb / fa) ** np.clip(t / T, 0.0, 1.0)
    y = S.sine(f, n) + 0.18 * S.sine(2.0 * f, n) + 0.06 * S.sine(3.0 * f, n)
    y *= S.env_ad(n, 0.0012, tau)
    c = S.burst(0.005, rng, 0.0001, 0.001, filt=[('bp', fa * 2.5, 1.0)])
    y[:len(c)] += 0.3 * norm(c)
    return norm(S.end_fade(y))


@sfx('harvest', peak=-5, variants=3, category=FARM,
     desc=['Harvest pluck: leafy rustle, root tear and a round "pop"', 'Harvest: quick, higher, cleaner pop',
           'Harvest: bigger root tear and a deeper pop'])
def harvest(rng, v):
    p = _HARV[v - 1]
    m = Mix(0.5)
    n = ns(0.08)
    rus = S.grains(n, rng, 20, S.env_bell(n, 0.5), 2000, 5000, 1.8, 0.0005, 0.002)
    m.add(norm(rus), 0.0, p['rustle'])
    n = ns(p['tear'] + 0.02)
    dens = S.env_pts(n, [(0, 0.2), (p['tear'], 1.0), (p['tear'] + 0.02, 0)])
    tear = S.grains(n, rng, int(900 * p['tear']), dens, 900, 3000, 1.4, 0.0005, 0.003)
    m.add(norm(tear), 0.01, 0.45)
    t_pop = 0.01 + p['tear']
    m.add(pop_tone(rng, p['pop'][0], p['pop'][1], p['T'], tau=0.032), t_pop, 1.0)
    m.add(norm(S.burst(0.08, rng, 0.001, 0.012, filt=[('lp', 500)])), t_pop, 0.35)
    m.add(P.grit(rng, 0.2, 12, 800, 2500, 0.05, q=1.4), t_pop + 0.02, 0.15)
    return cozy(m.out(), lp_hz=7000, shelf=-2.5, drive=0.5)


@sfx('scythe', peak=-6, variants=2, category=FARM,
     desc=['Scythe: airy swish with a crisp grass-cut in the middle',
           'Scythe: faster swish, two cutting bursts'])
def scythe(rng, v):
    dur = (0.32, 0.26)[v - 1]
    m = Mix(dur + 0.1)
    sw = P.whoosh(rng, dur, [(0, 500), (0.55 * dur, 2600), (dur, 1000)], q=1.7, body=0.12)
    m.add(sw, 0.0, 0.7)
    cuts = (0.5 * dur,) if v == 1 else (0.42 * dur, 0.6 * dur)
    for c in cuts:
        m.add(P.grit(rng, 0.07, 130, 1800, 6500, 0.012, attack=0.002, q=2.0, dlo=0.0003, dhi=0.0015), c,
              1.1 / len(cuts) ** 0.5)
    return cozy(S.hp(m.out(), 150.0), lp_hz=8000, shelf=-2.0, drive=0.4)


@sfx('tool_whiff', peak=-10, category=FARM,
     desc='Light tool swing through air (soft whoosh, no impact)')
def tool_whiff(rng):
    y = P.whoosh(rng, 0.2, [(0, 550), (0.09, 1600), (0.2, 750)], q=1.5, body=0.1)
    return cozy(y, lp_hz=6000, shelf=-2.0, drive=0.2)


@sfx('tool_charge', peak=-10, category=FARM,
     desc='Rising, pulsing charge-up tone (~0.6 s) for held tool swings')
def tool_charge(rng):
    dur = 0.62
    n = ns(dur)
    t = S.tvec(n)
    f = 260.0 * 2.0 ** (1.6 * (t / dur) ** 1.2)
    tone = 0.6 * S.tri(f, n) + 0.25 * S.square(f, n, 0.3)
    tone = S.tvf(tone, 'lp', S.env_pts(n, [(0, 900), (dur, 3500)], 'exp'), 0.9)
    rate = S.env_pts(n, [(0, 7.0), (dur, 20.0)], 'exp')
    trem = 1.0 - 0.35 * (0.5 + 0.5 * np.sin(2 * np.pi * S.phase(rate, n)))
    env = S.env_pts(n, [(0, 0), (0.02, 0.6), (dur - 0.05, 1.0), (dur, 0.0)], 'cos')
    y = norm(tone * trem * env)
    k = S.kalimba(260.0, 0.3, 0.5, rng, decay=0.3)
    y[:len(k)] += 0.4 * norm(k)[:n]
    return cozy(y, lp_hz=7000, shelf=-2.0, drive=0.3)


@sfx('refill', peak=-9, category=FARM, cost=1.5,
     desc='Watering can refilling: bubbly gurgle whose resonance rises as it fills (~1.1 s)')
def refill(rng):
    dur = 1.1
    n = ns(dur + 0.2)
    fc = S.env_pts(n, [(0, 380), (dur, 1400)], 'exp')
    env = S.env_pts(n, [(0, 0.4), (0.04, 1.0), (dur - 0.15, 0.9), (dur, 0.0)], 'cos')
    gurgle = S.tvf(S.colored(n, rng, -2.0), 'bp', fc, 7.0) * env * (1 + 0.4 * S.smooth_noise(n, rng, 9.0))
    y = 0.9 * norm(gurgle)
    b = np.zeros(n + ns(0.3))
    for s in np.sort(S.sample_times(env, 110, rng)):
        f0 = fc[s] * rng.uniform(0.95, 1.4)
        bb = S.bubble(f0, rng.lognormal(0, 0.5), rng.uniform(0.1, 0.4))
        b[s:s + len(bb)] += bb
    y += 0.55 * norm(b[:n])
    y += 0.12 * norm(S.tvf(S.white(n, rng), 'bp', 2500.0, 0.8) * env)
    return cozy(y, lp_hz=7000, shelf=-3.0, drive=0.4)


# ============================================================================ trees / rocks / scrap
_CHOP = [
    dict(f1=330.0, tau=0.055, hard=0.58, splinter=0.0),
    dict(f1=290.0, tau=0.065, hard=0.52, splinter=0.0),
    dict(f1=380.0, tau=0.045, hard=0.65, splinter=0.35),
]


@sfx('chop', peak=-4, variants=3, category=FARM,
     desc=['Axe into wood: solid thunk with fibre crunch', 'Axe: deeper log, rounder thunk',
           'Axe: brighter bite with splinter crackle'])
def chop(rng, v):
    p = _CHOP[v - 1]
    m = Mix(0.5)
    m.add(P.wood_knock(rng, p['f1'], 0.4, ratios=(1.0, 1.58, 2.37, 3.3, 4.6), tau1=p['tau'],
                       hardness=p['hard'], contact=0.3, contact_lp=5000.0), 0.0, 1.0)
    m.add(P.body_thud(rng, 150.0, 75.0, 0.04, 700.0, 0.5, 0.25), 0.0, 0.45)
    m.add(P.grit(rng, 0.1, 50, 1200, 4500, 0.015, q=1.5), 0.001, 0.5)
    blade = S.strike(ns(0.12), [2900, 4100, 5600], [1.0, 0.5, 0.2], [0.03, 0.02, 0.01],
                     attack=0.0002, hardness=0.7, rng=rng)
    m.add(norm(blade), 0.0, 0.1)
    if p['splinter']:
        n = ns(0.25)
        dens = S.env_pts(n, [(0, 0), (0.02, 1), (0.25, 0)])
        m.add(norm(S.grains(n, rng, 35, dens, 1500, 5000, 2.5, 0.0004, 0.002)), 0.02, p['splinter'])
    return cozy(S.hp(m.out(), 70.0), lp_hz=7000, shelf=-2.0, drive=0.9)


@sfx('tree_creak', peak=-8, category=FARM,
     desc='Slow wooden trunk creak/groan as a tree starts to give (~1.5 s)')
def tree_creak(rng):
    y = P.creak(rng, 1.5, [(0, 22), (0.5, 48), (0.9, 35), (1.5, 18)], [310, 560, 940, 1500],
                [0.03, 0.02, 0.012, 0.008], amp_pts=[(0, 0), (0.12, 0.6), (0.5, 1.0), (1.05, 0.8), (1.5, 0)],
                jitter=0.18, gains=[1.0, 0.8, 0.5, 0.25])
    low = P.creak(rng, 1.5, [(0, 22), (0.5, 48), (0.9, 35), (1.5, 18)], [140], [0.04],
                  amp_pts=[(0, 0), (0.2, 0.5), (0.6, 1.0), (1.5, 0)], jitter=0.2)
    return cozy(y + 0.4 * low, lp_hz=5000, shelf=-2.0, drive=0.6)


@sfx('tree_fall', peak=-2, category=FARM, cost=3.0,
     desc='Tree falling: crack, rushing leafy whoosh, heavy crash with branch crackle (~3 s)')
def tree_fall(rng):
    m = Mix(3.4)
    crack = P.wood_knock(rng, 300.0, 0.3, tau1=0.03, hardness=0.9, contact=0.6, contact_lp=8000.0)
    m.add(crack, 0.0, 0.7)
    m.add(P.creak(rng, 0.5, [(0, 30), (0.5, 60)], [380, 700, 1200], [0.025, 0.015, 0.01],
                  amp_pts=[(0, 1), (0.5, 0)]), 0.02, 0.4)
    n = ns(1.25)
    rush = P.whoosh(rng, 1.25, [(0, 1600), (0.9, 700), (1.25, 400)], q=0.6,
                    amp_pts=[(0, 0), (0.6, 0.6), (1.1, 1.0), (1.25, 0.6)], body=0.4)
    leaves = S.grains(n, rng, 380, S.env_pts(n, [(0, 0.1), (1.1, 1.0), (1.25, 0.8)]), 1500, 6000, 2.0,
                      0.0005, 0.003)
    m.add(rush + 0.5 * norm(leaves), 0.1, 0.6)
    t = 1.3
    m.add(P.body_thud(rng, 75.0, 34.0, 0.3, 300.0, 0.8, 1.2, 0.05), t, 1.0)
    n = ns(0.8)
    br = S.grains(n, rng, 160, S.env_pts(n, [(0, 1), (0.1, 0.8), (0.8, 0)]), 900, 5000, 2.2, 0.0005, 0.004)
    m.add(norm(br), t, 0.55)
    m.add(P.debris(rng, 1.0, 14, [(0, 1), (0.6, 0.3), (1.0, 0)], (0.2, 0.7), wood=0.8), t + 0.02, 0.35)
    m.add(P.body_thud(rng, 90.0, 45.0, 0.12, 400.0, 0.7, 0.5), t + 0.24, 0.45)
    n = ns(1.4)
    settle = S.grains(n, rng, 160, S.env_pts(n, [(0, 1), (1.4, 0)]), 2000, 6000, 2.0, 0.0005, 0.002)
    m.add(norm(settle), t + 0.1, 0.18)
    y = S.reverb(m.out(), 'outdoor', wet=0.25)
    return cozy(y, lp_hz=8000, shelf=-2.0, drive=0.8)


@sfx('stump_break', peak=-3, category=FARM,
     desc='Stump breaking out: sharp wood crack, splintering, root tear and a final thump')
def stump_break(rng):
    m = Mix(1.2)
    m.add(P.wood_knock(rng, 260.0, 0.3, tau1=0.035, hardness=0.85, contact=0.7, contact_lp=7000.0), 0.0, 0.9)
    n = ns(0.5)
    sp = S.grains(n, rng, 160, S.env_pts(n, [(0, 1), (0.08, 0.9), (0.5, 0)]), 700, 3500, 3.0, 0.0006, 0.004)
    sp = sp + 0.6 * S.resonate(sp, [420, 780, 1350], [0.02, 0.012, 0.008])
    m.add(norm(sp), 0.01, 0.6)
    n = ns(0.45)
    root = S.tvf(S.colored(n, rng, -2.0), 'bp', S.env_pts(n, [(0, 500), (0.45, 1100)], 'exp'), 1.5)
    root *= S.env_pts(n, [(0, 0), (0.1, 1), (0.45, 0)], 'cos')
    root += 0.6 * norm(S.grains(n, rng, 60, S.env_bell(n, 0.5), 400, 1500, 1.2, 0.001, 0.005))
    m.add(norm(root), 0.12, 0.45)
    m.add(P.body_thud(rng, 100.0, 50.0, 0.1, 500.0, 0.8, 0.4), 0.5, 0.9)
    m.add(P.debris(rng, 0.5, 10, [(0, 1), (0.5, 0)], (0.2, 0.6), wood=0.5), 0.52, 0.3)
    y = S.reverb(m.out(), 'outdoor', wet=0.15)
    return cozy(y, lp_hz=8000, shelf=-2.0, drive=0.9)


_MINE = [
    dict(clink=(2100, 3350, 5050, 7100), ctau=0.06, clink_amp=0.55, crack=0.7, chips=8),
    dict(clink=(1850, 2950, 4600, 6400), ctau=0.075, clink_amp=0.6, crack=0.55, chips=6),
    dict(clink=(2500, 3900, 5500, 7600), ctau=0.04, clink_amp=0.3, crack=1.0, chips=12),
]


@sfx('mine', peak=-5, variants=3, category=FARM,
     desc=['Pick on stone: metallic clink + crack + bouncing chips', 'Pick: rounder, longer ring',
           'Pick: dull crack, mostly stone, more chips'])
def mine(rng, v):
    p = _MINE[v - 1]
    m = Mix(0.5)
    fr = np.array(p['clink']) * rng.uniform(0.97, 1.03, 4)
    cl = S.strike(ns(0.4), fr, [1.0, 0.6, 0.35, 0.18], [p['ctau'], p['ctau'] * 0.7, p['ctau'] * 0.45,
                                                     p['ctau'] * 0.3], attack=0.0002, hardness=0.6, rng=rng)
    m.add(norm(cl), 0.0, p['clink_amp'])
    m.add(norm(S.burst(0.04, rng, 0.0002, 0.006, filt=[('bp', 1600, 0.8)])), 0.0, p['crack'] * 0.8)
    m.add(norm(S.thump(0.12, 160.0, 80.0, 0.008, 0.03)), 0.0, 0.6)
    for _ in range(p['chips']):
        m.add(P.stone_click(rng, None, 0.04), rng.uniform(0.03, 0.26), rng.uniform(0.06, 0.2))
    return cozy(m.out(), lp_hz=8000, shelf=-3.0, drive=0.7)


@sfx('rock_break', peak=-3, category=FARM,
     desc='Rock breaking: crack, crumbling stone fragments and a low rumble (~1 s)')
def rock_break(rng):
    m = Mix(1.3)
    m.add(norm(S.burst(0.06, rng, 0.0002, 0.01, filt=[('bp', 1300, 0.7)])), 0.0, 1.0)
    m.add(P.body_thud(rng, 130.0, 55.0, 0.09, 500.0, 0.8, 0.35), 0.0, 0.9)
    m.add(P.debris(rng, 1.0, 55, [(0, 1.0), (0.15, 0.8), (0.6, 0.2), (1.0, 0)], (0.15, 1.0)), 0.01, 0.75)
    n = ns(0.8)
    g = S.grains(n, rng, 240, S.env_pts(n, [(0, 1), (0.8, 0)]), 1500, 5500, 1.2, 0.0003, 0.0015)
    m.add(norm(g), 0.02, 0.25)
    n = ns(0.7)
    rum = S.butter(S.colored(n, rng, -6.0), 'lp', 160.0) * S.env_ad(n, 0.01, 0.2)
    m.add(norm(S.end_fade(rum)), 0.0, 0.4)
    y = S.reverb(m.out(), 'outdoor', wet=0.12)
    return cozy(y, lp_hz=8000, shelf=-2.0, drive=0.8)


_SCRAP = [
    dict(f1=380.0, tau=0.3, rust=0.65, rattle=3, count=10, hard=0.65, desc='sheet'),
    dict(f1=560.0, tau=0.5, rust=0.45, rattle=1, count=7, hard=0.75, desc='pipe'),
    dict(f1=780.0, tau=0.16, rust=0.8, rattle=2, count=8, hard=0.55, desc='can'),
]


@sfx('scrap', peak=-5, variants=3, category=FARM,
     desc=['Tool on rusty sheet metal: clank, damped ring and rattle', 'Tool on a rusty pipe: longer ring',
           'Tool on a dented can/panel: dull clunk'])
def scrap(rng, v):
    p = _SCRAP[v - 1]
    y = P.metal_clank(rng, p['f1'], 1.0, p['count'], p['tau'], p['rust'], p['hard'], 0.35, p['rattle'],
                      spread=(0.3, 1.0) if v != 2 else (0.9, 1.6))
    th = P.body_thud(rng, 150.0, 80.0, 0.03, 600.0, 0.6, 0.2)
    y[:len(th)] += 0.35 * th
    return cozy(y, lp_hz=8500, shelf=-3.0, drive=0.6)


@sfx('scrap_break', peak=-2, category=FARM, cost=2.0,
     desc='Scrap pile collapsing: tumbling clanks, rattles and a scrape settling (~1.6 s)')
def scrap_break(rng):
    m = Mix(2.0)
    t = 0.0
    k = 0
    while t < 1.1:
        size = 1.0 - 0.6 * t
        f1 = rng.uniform(250, 900) / (0.6 + 0.4 * size)
        c = P.metal_clank(rng, f1, 0.7, 7, rng.uniform(0.15, 0.4), 0.65, 0.6, 0.35, rng.integers(0, 3))
        m.add(c, t, size * rng.uniform(0.6, 1.0))
        t += rng.uniform(0.04, 0.16) * (1.0 + 1.5 * t)
        k += 1
    m.add(P.body_thud(rng, 120.0, 55.0, 0.12, 500.0, 0.7, 0.4), 0.0, 0.8)
    n = ns(0.6)
    scr = S.tvf(S.white(n, rng), 'bp', S.env_pts(n, [(0, 2500), (0.6, 1300)], 'exp'), 2.0)
    scr *= S.env_pts(n, [(0, 0), (0.1, 1), (0.6, 0)], 'cos') * (1 + 0.5 * S.smooth_noise(n, rng, 30))
    m.add(norm(scr), 0.35, 0.25)
    m.add(P.debris(rng, 0.8, 10, [(0, 0.5), (0.8, 0)], (0.1, 0.4), metal=0.8), 0.9, 0.35)
    y = S.reverb(m.out(), 'outdoor', wet=0.15)
    return cozy(y, lp_hz=9000, shelf=-2.0, drive=0.8)


# ============================================================================ items / coins / food
@sfx('pickup', peak=-8, variants=2, category=FARM,
     desc=['Item collected: bright upward "bloop" pop with an octave sparkle',
           'Item collected: quick two-note marimba blip (G5 -> D6)'])
def pickup(rng, v):
    if v == 1:
        n = ns(0.2)
        t = S.tvec(n)
        f = 520.0 * 2.0 ** np.clip(t / 0.05, 0, 1)
        y = 0.75 * S.sine(f, n) + 0.25 * S.tri(f, n) + 0.12 * S.sine(3.0 * f, n)
        y *= S.env_ad(n, 0.001, 0.055)
        y = norm(S.end_fade(y))
        k = S.kalimba(2093.0, 0.2, 1.0, rng, decay=0.12)
        m = Mix(0.25)
        m.add(y, 0.0)
        m.add(norm(k), 0.035, 0.18)
        m.add(norm(S.burst(0.01, rng, 0.0003, 0.002, filt=[('bp', 3000, 1.0)])), 0.0, 0.08)
        return cozy(m.out(), lp_hz=9000, shelf=-2.0, drive=0.3)
    m = Mix(0.4)
    m.add(S.marimba(note('G5'), None, 0.8, rng, hardness=0.7, decay=0.15), 0.0)
    m.add(S.marimba(note('D6'), None, 1.0, rng, hardness=0.75, decay=0.18), 0.045)
    m.add(S.kalimba(note('D6'), None, 0.25, rng, decay=0.14), 0.045)
    return cozy(m.out(), lp_hz=9500, shelf=-2.0, drive=0.4)


@sfx('item_drop', peak=-7, category=FARM,
     desc='Item dropped on the ground: soft thud with a small bounce')
def item_drop(rng):
    m = Mix(0.4)
    m.add(P.body_thud(rng, 230.0, 120.0, 0.028, 1300.0, 1.0, 0.15, 0.008), 0.0, 1.0)
    m.add(P.wood_knock(rng, 520.0, 0.08, tau1=0.012, hardness=0.4, contact=0.2), 0.0, 0.35)
    m.add(P.grit(rng, 0.08, 10, 700, 2500, 0.02, q=1.2), 0.0, 0.25)
    m.add(P.body_thud(rng, 250.0, 135.0, 0.018, 1300.0, 1.0, 0.1, 0.006), 0.095, 0.4)
    return cozy(S.hp(m.out(), 90.0), lp_hz=5000, shelf=-2.0, drive=0.4)


@sfx('coin', peak=-9, category=FARM,
     desc='Single coin: warm "ching" with a tiny settle')
def coin(rng):
    m = Mix(0.8)
    m.add(P.coin_clink(rng, 2240.0, 0.75), 0.0, 1.0)
    m.add(P.coin_clink(rng, 2390.0, 0.4, decay=0.4), 0.07, 0.25)
    return cozy(m.out(), lp_hz=9000, shelf=-3.0, drive=0.3)


@sfx('coins', peak=-6, category=FARM,
     desc='Handful of coins jingling into a pouch (~0.7 s)')
def coins(rng):
    m = Mix(1.0)
    n = ns(0.6)
    dens = S.env_pts(n, [(0, 0.5), (0.05, 1.0), (0.3, 0.6), (0.6, 0.0)])
    for s in np.sort(S.sample_times(dens, 24, rng)):
        m.add(P.coin_clink(rng, rng.uniform(1900, 3100), 0.45, decay=rng.uniform(0.3, 0.9)), s / S.SR,
              rng.uniform(0.25, 1.0))
    m.add(P.body_thud(rng, 140.0, 80.0, 0.03, 700.0, 1.0, 0.15), 0.02, 0.6)
    return cozy(m.out(), lp_hz=9000, shelf=-3.0, drive=0.4)


@sfx('ship', peak=-5, category=FARM,
     desc='Shipping crate: wooden lid thunk and rattle, then a hint of coins')
def ship(rng):
    m = Mix(1.0)
    m.add(P.wood_knock(rng, 140.0, 0.4, ratios=(1.0, 2.36, 4.36, 7.0), tau1=0.06, hardness=0.45,
                       cavity=95.0, cavity_amp=0.7, contact=0.2), 0.0, 1.0)
    m.add(P.body_thud(rng, 110.0, 60.0, 0.05, 500.0, 0.6, 0.25), 0.0, 0.6)
    m.add(P.wood_knock(rng, 420.0, 0.1, tau1=0.015, hardness=0.6), 0.045, 0.2)
    m.add(P.coin_clink(rng, 2300.0, 0.5, decay=0.6), 0.2, 0.22)
    m.add(P.coin_clink(rng, 2650.0, 0.5, decay=0.5), 0.26, 0.16)
    return cozy(m.out(), lp_hz=8000, shelf=-2.0, drive=0.5)


@sfx('eat', peak=-7, variants=2, category=FARM,
     desc=['Crisp bite and crunch (apple/carrot)', 'Soft munching chews (bread/stew)'])
def eat(rng, v):
    m = Mix(0.7)
    if v == 1:
        for t, g in ((0.0, 1.0), (0.22, 0.7)):
            m.add(P.grit(rng, 0.14, 110, 900, 4000, 0.035, attack=0.002, q=1.0), t, g)
            m.add(norm(S.burst(0.05, rng, 0.001, 0.01, filt=[('lp', 300)])), t, 0.4 * g)
            m.add(P.grit(rng, 0.1, 12, 1500, 4000, 0.03, q=1.5), t + 0.05, 0.2 * g)
        y = S.peq(m.out(), 1500.0, 3.0, 1.0)
        return cozy(y, lp_hz=4500, shelf=-3.0, drive=0.5)
    for i, t in enumerate((0.0, 0.17, 0.34)):
        g = (1.0, 0.8, 0.65)[i]
        m.add(P.grit(rng, 0.12, 35, 500, 2000, 0.04, attack=0.006, q=1.0), t, g)
        n = ns(0.12)
        mm = S.butter(S.colored(n, rng, -3.0), 'bp', (200.0, 500.0)) * S.env_bell(n, 0.35)
        m.add(norm(mm), t, 0.45 * g)
    return cozy(m.out(), lp_hz=3000, shelf=-3.0, drive=0.4)


@sfx('drink', peak=-8, category=FARM,
     desc='Drinking: liquid swirl and two soft gulps')
def drink(rng):
    m = Mix(0.9)
    m.add(P.drops(rng, 0.2, 10, [(0, 1), (0.2, 0)], 600, 1400, (0.2, 0.6)), 0.0, 0.25)
    for t, f in ((0.12, 260.0), (0.45, 230.0)):
        b = S.bubble(f, 1.0, 0.6, dur=0.12)
        m.add(norm(b), t, 0.9)
        m.add(norm(S.bubble(f * 1.6, 1.0, 0.4, dur=0.06)), t + 0.025, 0.35)
        m.add(norm(S.burst(0.06, rng, 0.002, 0.012, filt=[('lp', 350)])), t, 0.6)
        n = ns(0.08)
        sw = S.biquad(S.white(n, rng), 'bp', 900.0, 1.0) * S.env_bell(n, 0.5)
        m.add(norm(sw), t - 0.05, 0.12)
    return cozy(m.out(), lp_hz=4000, shelf=-3.0, drive=0.4)


# ============================================================================ doors / chests / gates
@sfx('door_open', peak=-6, category=FARM,
     desc='Wooden door opening: latch click, short hinge creak, air movement')
def door_open(rng):
    m = Mix(0.9)
    m.add(P.latch(rng, 1900.0, 0.08, 0.5), 0.0, 0.7)
    m.add(P.creak(rng, 0.5, [(0, 45), (0.2, 95), (0.5, 60)], [520, 1150, 1900, 2800],
                  [0.02, 0.012, 0.008, 0.005], amp_pts=[(0, 0), (0.08, 0.8), (0.25, 1.0), (0.5, 0)],
                  gains=[1.0, 0.7, 0.4, 0.2]), 0.07, 0.6)
    n = ns(0.5)
    air = S.butter(S.colored(n, rng, -3.0), 'lp', 600.0) * S.env_bell(n, 0.5)
    m.add(norm(air), 0.1, 0.25)
    return cozy(m.out(), lp_hz=6500, shelf=-2.0, drive=0.4)


@sfx('door_close', peak=-5, category=FARM,
     desc='Wooden door closing: swing, solid thud into the frame, latch click')
def door_close(rng):
    m = Mix(0.7)
    n = ns(0.15)
    air = S.butter(S.colored(n, rng, -3.0), 'lp', 700.0) * S.env_pts(n, [(0, 0), (0.12, 1), (0.15, 0)], 'cos')
    m.add(norm(air), 0.0, 0.2)
    t = 0.12
    m.add(P.wood_knock(rng, 125.0, 0.4, ratios=(1.0, 2.2, 4.0, 6.7), tau1=0.08, hardness=0.5, contact=0.3),
          t, 1.0)
    m.add(P.body_thud(rng, 100.0, 55.0, 0.06, 450.0, 0.6, 0.3), t, 0.6)
    m.add(P.latch(rng, 2100.0, 0.07, 0.3), t + 0.03, 0.35)
    y = S.reverb(m.out(), 'small', wet=0.15)
    return cozy(y, lp_hz=6500, shelf=-2.0, drive=0.6)


@sfx('chest_open', peak=-6, category=FARM,
     desc='Wooden chest opening: latch clack, short lid creak, hollow box resonance')
def chest_open(rng):
    m = Mix(0.7)
    m.add(P.latch(rng, 1700.0, 0.08, 0.6), 0.0, 0.7)
    m.add(P.wood_knock(rng, 180.0, 0.25, tau1=0.04, hardness=0.4, cavity=410.0, cavity_amp=0.3,
                       contact=0.1), 0.01, 0.4)
    m.add(P.creak(rng, 0.3, [(0, 70), (0.3, 140)], [900, 1700, 2600], [0.015, 0.009, 0.006],
                  amp_pts=[(0, 0), (0.06, 1.0), (0.3, 0)], gains=[1.0, 0.6, 0.3]), 0.06, 0.45)
    return cozy(m.out(), lp_hz=6500, shelf=-2.0, drive=0.4)


@sfx('chest_close', peak=-5, category=FARM,
     desc='Wooden chest closing: hollow lid thump and latch click')
def chest_close(rng):
    m = Mix(0.5)
    m.add(P.wood_knock(rng, 190.0, 0.35, ratios=(1.0, 2.2, 3.73, 6.0), tau1=0.06, hardness=0.45,
                       cavity=330.0, cavity_amp=0.5, contact=0.25), 0.0, 1.0)
    m.add(P.body_thud(rng, 120.0, 70.0, 0.04, 500.0, 0.6, 0.2), 0.0, 0.5)
    m.add(P.latch(rng, 1900.0, 0.07, 0.4), 0.025, 0.4)
    return cozy(m.out(), lp_hz=6500, shelf=-2.0, drive=0.5)


@sfx('gate_open', peak=-5, category=FARM,
     desc='Farm gate opening: latch clank, rusty hinge squeal, wooden rattle (~1.1 s)')
def gate_open(rng):
    m = Mix(1.3)
    m.add(P.metal_clank(rng, 700.0, 0.35, 6, 0.12, 0.7, 0.6, 0.4, 1, thud=0.1), 0.0, 0.6)
    m.add(P.creak(rng, 0.85, [(0, 190), (0.3, 320), (0.6, 260), (0.85, 210)], [1100, 1900, 2700],
                  [0.015, 0.01, 0.006], amp_pts=[(0, 0), (0.1, 0.7), (0.4, 1.0), (0.85, 0)],
                  jitter=0.08, gains=[1.0, 0.6, 0.3]), 0.12, 0.38)
    for t in (0.2, 0.55, 0.9):
        m.add(P.wood_knock(rng, rng.uniform(260, 340), 0.12, tau1=0.02, hardness=0.5), t, 0.18)
    return cozy(m.out(), lp_hz=5500, shelf=-3.0, drive=0.5)


@sfx('gate_close', peak=-4, category=FARM,
     desc='Farm gate closing: short squeak, wooden clack on the post, latch clank and rattle')
def gate_close(rng):
    m = Mix(0.9)
    m.add(P.creak(rng, 0.2, [(0, 250), (0.2, 200)], [1100, 1900, 2700], [0.015, 0.01, 0.006],
                  amp_pts=[(0, 0.6), (0.05, 1.0), (0.2, 0)], jitter=0.08), 0.0, 0.25)
    t = 0.17
    m.add(P.wood_knock(rng, 165.0, 0.35, tau1=0.05, hardness=0.6, contact=0.35), t, 1.0)
    m.add(P.body_thud(rng, 110.0, 60.0, 0.05, 500.0, 0.6, 0.25), t, 0.5)
    m.add(P.metal_clank(rng, 820.0, 0.4, 6, 0.12, 0.7, 0.65, 0.4, 2, thud=0.1), t + 0.03, 0.5)
    return cozy(m.out(), lp_hz=6500, shelf=-2.0, drive=0.6)


# ============================================================================ building / crafting
def hammer_knock(rng, vel=1.0, f_wood=380.0):
    """Hammer on nail + plank: steel tick, wood knock, low body."""
    m = Mix(0.25)
    tick = S.strike(ns(0.05), [3200, 4700, 6900], [1.0, 0.6, 0.3], [0.006, 0.004, 0.0025],
                    attack=0.0001, hardness=0.8, rng=rng)
    m.add(norm(tick), 0.0, 0.35)
    m.add(P.wood_knock(rng, f_wood, 0.2, ratios=(1.0, 2.45, 4.1), tau1=0.035, hardness=0.6,
                       contact=0.3, contact_lp=6000.0), 0.0, 1.0)
    m.add(norm(S.thump(0.1, 160.0, 90.0, 0.008, 0.03)), 0.0, 0.6)
    return vel * norm(m.out())


@sfx('build', peak=-5, category=FARM,
     desc='Three hammer knocks on nails and planks')
def build(rng):
    m = Mix(1.0)
    for i, (t, v) in enumerate(((0.0, 0.85), (0.24, 0.9), (0.48, 1.0))):
        m.add(hammer_knock(rng, v, 380.0 * (1.0 + 0.04 * (i - 1))), t)
    y = S.reverb(m.out(), 'outdoor', wet=0.12)
    return cozy(y, lp_hz=8000, shelf=-2.0, drive=0.6)


@sfx('build_complete', peak=-5, category=FARM,
     desc='Two hammer knocks then a small bright marimba fanfare (C5 E5 G5 C6)')
def build_complete(rng):
    m = Mix(1.8)
    m.add(hammer_knock(rng, 0.9, 370.0), 0.0)
    m.add(hammer_knock(rng, 1.0, 395.0), 0.2)
    for i, nm in enumerate(('C5', 'E5', 'G5', 'C6')):
        last = i == 3
        m.add(S.marimba(note(nm), None, 0.6 if not last else 0.75, rng, hardness=0.55,
                        decay=0.35 if not last else 0.8), 0.45 + 0.065 * i)
        m.add(S.kalimba(note(nm), None, 0.25, rng, decay=0.3 if not last else 0.6), 0.45 + 0.065 * i)
    m.add(S.pad([note('C4'), note('G4'), note('C5'), note('E5')], 0.9, rng, attack=0.05, release=0.5,
                cutoff=1600.0), 0.64, 0.1)
    y = S.reverb(m.out(), 'outdoor', wet=0.12)
    return cozy(y, lp_hz=9000, shelf=-2.0, drive=0.5)


@sfx('place_object', peak=-6, category=FARM,
     desc='Object set down: soft wooden thunk with a tiny rattle')
def place_object(rng):
    m = Mix(0.4)
    m.add(P.wood_knock(rng, 300.0, 0.22, tau1=0.035, hardness=0.4, cavity=180.0, cavity_amp=0.4,
                       contact=0.15), 0.0, 1.0)
    m.add(P.body_thud(rng, 190.0, 100.0, 0.025, 900.0, 0.7, 0.15), 0.0, 0.4)
    m.add(P.wood_knock(rng, 520.0, 0.08, tau1=0.012, hardness=0.5), 0.035, 0.12)
    m.add(P.wood_knock(rng, 610.0, 0.08, tau1=0.01, hardness=0.5), 0.06, 0.08)
    return cozy(S.hp(m.out(), 90.0), lp_hz=5500, shelf=-2.0, drive=0.5)


def _tiny_click(rng, kind='metal'):
    if kind == 'metal':
        f = rng.uniform(1600, 4200)
        y = S.strike(ns(0.05), [f, f * 1.7, f * 2.6], [1.0, 0.5, 0.25],
                     [rng.uniform(0.004, 0.014), 0.004, 0.002], attack=0.0001, hardness=0.75, rng=rng)
    else:
        y = P.wood_knock(rng, rng.uniform(600, 1300), 0.05, tau1=0.008, hardness=0.6)
    return norm(y)


@sfx('craft', peak=-6, category=FARM,
     desc='Crafting: tinkering clicks, a little ratchet, then a satisfied thump')
def craft(rng):
    m = Mix(1.0)
    for t in np.sort(rng.uniform(0.0, 0.4, 6)):
        m.add(_tiny_click(rng, 'metal' if rng.random() < 0.6 else 'wood'), t, rng.uniform(0.4, 0.9))
    for k in range(4):
        m.add(_tiny_click(rng, 'metal'), 0.42 + 0.028 * k, 0.45)
    m.add(P.body_thud(rng, 130.0, 70.0, 0.05, 600.0, 0.7, 0.25), 0.62, 1.0)
    m.add(P.wood_knock(rng, 260.0, 0.2, tau1=0.03, hardness=0.45), 0.62, 0.5)
    y = S.reverb(m.out(), 'small', wet=0.12)
    return cozy(y, lp_hz=8000, shelf=-2.0, drive=0.5)


@sfx('machine_done', peak=-6, category=FARM,
     desc='Crafting machine finished: small mechanical clunk then a warm bell "ding"')
def machine_done(rng):
    m = Mix(1.6)
    m.add(P.latch(rng, 1300.0, 0.08, 0.7), 0.0, 0.5)
    f = note('E6')
    ding = S.strike(ns(1.4), [f, f * 1.004, f * 2.32, f * 2.74, f * 4.1, f * 5.4],
                    [1.0, 0.6, 0.35, 0.3, 0.12, 0.06], [0.7, 0.6, 0.3, 0.25, 0.12, 0.06],
                    attack=0.0008, hardness=0.6, rng=rng, release=0.5)
    m.add(norm(ding), 0.04, 1.0)
    y = S.reverb(m.out(), 'room', wet=0.15)
    return cozy(y, lp_hz=8500, shelf=-3.0, drive=0.3)


@sfx('smelter', peak=-5, category=FARM,
     desc='Smelter/furnace: fiery whoosh with roar and crackle (~1.2 s)')
def smelter(rng):
    dur = 1.25
    n = ns(dur)
    env = S.env_pts(n, [(0, 0.05), (0.12, 1.0), (0.4, 0.8), (dur, 0.0)], 'cos')
    turb = 1.0 + 0.35 * S.smooth_noise(n, rng, 18.0)
    roar = S.butter(S.colored(n, rng, -6.0), 'lp', 250.0)
    body = S.tvf(S.colored(n, rng, -3.0), 'bp', S.env_pts(n, [(0, 300), (0.25, 1400), (dur, 600)], 'exp'), 0.7)
    crack = S.grains(n, rng, 45, env, 1500, 5000, 2.0, 0.0003, 0.0015)
    y = (0.8 * norm(roar) + 0.7 * norm(body)) * env * turb + 0.25 * norm(crack)
    return cozy(S.end_fade(y), lp_hz=7000, shelf=-2.0, drive=0.7)


@sfx('sprinkler', peak=-9, category=FARM,
     desc='Sprinkler: soft rhythmic hiss-spray pulses over a light mist (~0.8 s)')
def sprinkler(rng):
    m = Mix(1.0)
    n = ns(0.85)
    mist = S.biquad(S.colored(n, rng, -1.0), 'bp', 3800.0, 0.8) * S.env_pts(
        n, [(0, 0), (0.06, 1.0), (0.7, 0.8), (0.85, 0)], 'cos')
    m.add(norm(mist), 0.0, 0.3)
    for i in range(6):
        t = 0.02 + i * 0.125 + rng.uniform(-0.01, 0.01)
        k = ns(0.1)
        sp = S.biquad(S.white(k, rng), 'bp', rng.uniform(3000, 3800), 0.8) * S.env_ad(k, 0.003, 0.035)
        m.add(norm(S.end_fade(sp)), t, 0.8 * (1.0 - 0.06 * i))
        tick = S.strike(ns(0.02), [2900.0, 4300.0], [1.0, 0.5], [0.003, 0.002], attack=0.0001, hardness=0.7)
        m.add(norm(tick), t, 0.12)
    m.add(P.drops(rng, 0.85, 30, [(0, 0), (0.1, 1), (0.85, 0.3)], 1500, 3500), 0.0, 0.18)
    return cozy(m.out(), lp_hz=7000, shelf=-4.0, drive=0.3)


# ============================================================================ animals
@sfx('cow', peak=-5, category=FARM,
     desc='Stylised warm, cartoonish "mmmooo" (formant voice, ~1.4 s)')
def cow(rng):
    dur = 1.45
    y = P.creature(rng, dur + 0.05, [(0, 98), (0.25, 112), (0.6, 128), (1.05, 118), (1.45, 92)],
                   [(0, 'm'), (0.16, 'm'), (0.32, 'u'), (0.6, 'o'), (0.9, 'a'), (1.2, 'o'), (1.45, 'u')],
                   scale=0.82, bw_scale=1.3, jitter=0.01, shimmer=0.05, breath=0.06, oq=0.65, tilt=1400.0,
                   vib=(4.5, 0.012),
                   amp_pts=[(0, 0), (0.03, 0.35), (0.18, 0.4), (0.4, 0.9), (0.8, 1.0), (1.2, 0.7), (1.45, 0)])
    y = S.lshelf(y, 200.0, 2.0)
    y = S.reverb(y, 'outdoor', wet=0.12)
    return cozy(y, lp_hz=4000, shelf=-2.0, drive=0.3)


@sfx('chicken', peak=-6, category=FARM,
     desc='Stylised chicken: three quick "bok" clucks and a rising "b\'gawk"')
def chicken(rng):
    m = Mix(1.0)
    for i, t in enumerate((0.0, 0.16, 0.3)):
        c = P.creature(rng, 0.09, [(0, 430 + 20 * i), (0.09, 360)], [(0, 'o'), (0.09, 'uh')], scale=1.6,
                       bw_scale=1.5, breath=0.2, tilt=3500.0, jitter=0.02,
                       amp_pts=[(0, 0), (0.004, 1.0), (0.03, 0.7), (0.09, 0)])
        m.add(c, t, 0.75)
        m.add(norm(S.burst(0.006, rng, 0.0002, 0.0012, filt=[('bp', 2500, 1.0)])), t, 0.25)
    g = P.creature(rng, 0.3, [(0, 520), (0.08, 700), (0.3, 560)], [(0, 'a'), (0.12, 'ae'), (0.3, 'e')],
                   scale=1.6, bw_scale=1.4, breath=0.18, tilt=3500.0, jitter=0.03, trem=(35.0, 0.3),
                   amp_pts=[(0, 0), (0.01, 0.8), (0.1, 1.0), (0.3, 0)])
    m.add(g, 0.46, 1.0)
    m.add(norm(S.burst(0.006, rng, 0.0002, 0.0012, filt=[('bp', 2500, 1.0)])), 0.46, 0.25)
    y = S.reverb(m.out(), 'outdoor', wet=0.1)
    return cozy(y, lp_hz=6500, shelf=-2.0, drive=0.3)


@sfx('goat', peak=-6, category=FARM,
     desc='Stylised goat bleat "meh-eh-eh" with its characteristic quaver (~0.9 s)')
def goat(rng):
    dur = 0.95
    y = P.creature(rng, dur, [(0, 400), (0.15, 440), (0.6, 425), (0.95, 380)],
                   [(0, 'm'), (0.07, 'e'), (0.5, 'ae'), (0.95, 'e')], scale=1.25, bw_scale=1.2,
                   jitter=0.02, breath=0.12, tilt=3000.0, vib=(8.5, 0.06), trem=(8.5, 0.45),
                   amp_pts=[(0, 0), (0.03, 0.8), (0.15, 1.0), (0.8, 0.8), (0.95, 0)])
    y = S.reverb(y, 'outdoor', wet=0.1)
    return cozy(y, lp_hz=5500, shelf=-2.0, drive=0.3)


# ============================================================================ weather / water
@sfx('thunder', peak=[-3, -2], variants=2, category=FARM, cost=4.0,
     desc=['Distant rolling thunder (~4.5 s): low rumbles, no crack',
           'Nearer thunder (~4 s): ripping crack then a rolling rumble'])
def thunder(rng, v):
    dur = (4.8, 4.3)[v - 1]
    n = ns(dur)
    t = S.tvec(n)
    if v == 1:
        rolls = [(0.0, 0.55, 0.03, 0.5), (0.45, 1.0, 0.15, 0.8), (1.4, 0.7, 0.25, 0.9), (2.5, 0.45, 0.3, 1.0)]
    else:
        rolls = [(0.0, 0.8, 0.01, 0.35), (0.3, 1.0, 0.08, 0.7), (1.1, 0.75, 0.2, 0.9), (2.2, 0.5, 0.3, 1.0)]
    env = np.zeros(n)
    for t0, a, att, tau in rolls:
        e = np.where(t >= t0, 1.0, 0.0) * np.exp(-np.maximum(t - t0 - att, 0) / tau)
        rise = np.clip((t - t0) / att, 0, 1)
        env += a * e * (0.5 - 0.5 * np.cos(np.pi * rise))
    env *= np.clip(1.0 + 0.3 * S.smooth_noise(n, rng, 4.0), 0.2, 2.0)
    rumble = S.butter(S.colored(n, rng, -6.0), 'lp', 170.0 if v == 1 else 260.0, 2)
    mid = S.butter(S.colored(n, rng, -3.0), 'bp', (150.0, 700.0 if v == 1 else 1400.0), 2)
    y = norm(rumble) * env + 0.35 * norm(mid) * env ** 1.6
    # irregular N-wave-ish pulses inside the roll give it texture
    imp = np.zeros(n)
    k = S.sample_times(env ** 2, 260 if v == 1 else 380, rng)
    imp[k] = rng.standard_normal(len(k))
    tex = S.butter(np.convolve(imp, np.hanning(ns(0.012)), 'same'), 'lp', 400.0 if v == 1 else 900.0)
    y = norm(y) + 0.5 * norm(tex)
    if v == 2:
        m = ns(0.35)
        rip_env = S.env_pts(m, [(0, 1.0), (0.05, 0.8), (0.35, 0)], 'cos')
        rip_imp = np.zeros(m)
        kk = S.sample_times(rip_env, 70, rng)
        rip_imp[kk] = rng.standard_normal(len(kk))
        rip = np.convolve(rip_imp, np.hanning(ns(0.002)), 'same')
        rip = S.tvf(rip, 'lp', S.env_pts(m, [(0, 4500), (0.35, 900)], 'exp'), 0.7)
        y[:m] += 0.9 * norm(rip)
        y[:ns(0.1)] += 0.6 * norm(S.burst(0.1, rng, 0.0005, 0.02, filt=[('lp', 2500), ('hp', 150)]))
    y = S.end_fade(y, release=0.8)
    y = S.reverb(y, 'distant', wet=0.45, dry=0.9)
    return S.butter(S.sat(norm(y), 1.2), 'lp', 3000.0 if v == 1 else 5000.0, 2)


@sfx('splash', peak=-4, category=FARM,
     desc='Something hitting water: plunge, bubble burst, spray and falling droplets (~1 s)')
def splash(rng):
    m = Mix(1.3)
    m.add(P.body_thud(rng, 120.0, 60.0, 0.05, 700.0, 0.9, 0.25), 0.0, 0.7)
    m.add(norm(S.burst(0.15, rng, 0.001, 0.03, filt=[('bp', 800, 0.6)])), 0.0, 0.8)
    m.add(P.drops(rng, 0.5, 70, [(0, 1.0), (0.1, 0.8), (0.5, 0)], 300, 2500, (0.2, 0.8)), 0.005, 0.8)
    n = ns(0.5)
    spray = S.biquad(S.colored(n, rng, -1.0), 'hp', 1500.0) * S.env_ad(n, 0.005, 0.12)
    m.add(norm(S.end_fade(spray)), 0.01, 0.35)
    m.add(P.drops(rng, 0.9, 25, [(0, 0), (0.2, 1.0), (0.9, 0)], 900, 3000, (0.1, 0.4)), 0.15, 0.3)
    return cozy(m.out(), lp_hz=8000, shelf=-3.0, drive=0.5)


@sfx('fish_bite', peak=-6, category=FARM,
     desc='Fish bite: a single round water "plop" with a little ripple')
def fish_bite(rng):
    m = Mix(0.5)
    n = ns(0.22)
    t = S.tvec(n)
    f = 380.0 * (900.0 / 380.0) ** np.clip(t / 0.028, 0, 1)
    y = S.sine(f, n) * S.env_ad(n, 0.001, 0.045)
    m.add(norm(S.end_fade(y)), 0.0, 1.0)
    m.add(norm(S.burst(0.05, rng, 0.0005, 0.008, filt=[('bp', 1200, 0.8)])), 0.0, 0.2)
    m.add(norm(S.bubble(1400.0, 1.0, 0.5)), 0.07, 0.25)
    m.add(norm(S.bubble(1900.0, 1.0, 0.4)), 0.12, 0.15)
    return cozy(m.out(), lp_hz=7000, shelf=-2.0, drive=0.3)
