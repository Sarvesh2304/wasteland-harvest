"""registry.py -- the catalogue of every SFX / ambience file.

File names are an engine API contract: the game references these exact names.  Each generator
module registers its sounds with the decorators below; build_all.py renders the registry.

    @sfx('hoe', peak=-6, variants=3, category=FARM, desc=[...])
    def hoe(rng, v): ...            # returns a mono float array (any scale)

    @amb('amb_rain', lufs=-23, desc='...')
    def amb_rain(rng): ...          # returns a (2, n) float array that loops seamlessly

Variant groups register `<name>_1 .. <name>_N`; the generator receives v = 1..N.
"""
from __future__ import annotations

from dataclasses import dataclass, field

UI = 'UI'
FARM = 'Farming & world'
COMBAT = 'Combat & ruins'
AMBIENCE = 'Ambience'


@dataclass
class Entry:
    name: str
    kind: str              # 'sfx' | 'amb'
    category: str
    fn: object
    kwargs: dict = field(default_factory=dict)
    level: float = -12.0   # target sample-peak dBFS (sfx) or integrated LUFS (amb)
    desc: str = ''
    group: str | None = None
    cost: float = 1.0      # rough relative render cost, used to schedule long jobs first
    mcap: float | None = None  # ceiling on max momentary loudness (LUFS, 400 ms) for sfx


REGISTRY: dict[str, Entry] = {}


def _pick(v, i):
    if isinstance(v, (list, tuple)):
        return v[i]
    return v


def _add(e: Entry):
    if e.name in REGISTRY:
        raise ValueError(f'duplicate sound name {e.name}')
    REGISTRY[e.name] = e


# Perceived-loudness ceilings (max momentary loudness, LUFS) applied after peak normalisation, so
# long/sustained sounds don't end up louder than short punchy ones that share a peak target.
MCAP_DEFAULT = {UI: -20.0, FARM: -17.5, COMBAT: -16.0}


def sfx(name, peak, desc, category, variants=0, cost=1.0, mcap='default'):
    """Register a one-shot (or a variant group when variants > 0).  peak/desc may be per-variant
    lists.  mcap: momentary-loudness ceiling (LUFS); 'default' = per-category, None = off."""
    cap = MCAP_DEFAULT.get(category) if mcap == 'default' else mcap

    def deco(fn):
        if variants:
            for i in range(variants):
                _add(Entry(f'{name}_{i + 1}', 'sfx', category, fn, {'v': i + 1},
                           float(_pick(peak, i)), _pick(desc, i), name, cost, cap))
        else:
            _add(Entry(name, 'sfx', category, fn, {}, float(peak), desc, None, cost, cap))
        return fn
    return deco


def amb(name, lufs, desc, cost=20.0):
    def deco(fn):
        _add(Entry(name, 'amb', AMBIENCE, fn, {}, float(lufs), desc, None, cost))
        return fn
    return deco
