"""Accompaniment generators: they read the song's chord chart and write events into a Part.

Every generator voice-leads (each new chord's voicing is chosen to move as little as
possible from the previous one) and lets plucked notes ring like a real instrument would:
a string rings until it is plucked again or the chord changes.
"""
from __future__ import annotations

from .notation import parse_grid
from .theory import (bass_note, fifth_below_or_above, guitar_voicing, nearest, scale_pcs,
                     voice)


def chord_spans(song, bars, merge: bool = True):
    """(start, dur, chord) spans covering the bars, merging repeated identical chords."""
    bars = list(song.bar_list(bars))
    out = []
    for b in bars:
        b0 = song.bar_beat(b)
        for t, d, c in song.chords_in(b0, b0 + song.bpb):
            if merge and out and out[-1][2].symbol == c.symbol and abs(out[-1][0] + out[-1][1] - t) < 1e-9:
                out[-1] = (out[-1][0], out[-1][1] + d, c)
            else:
                out.append((t, d, c))
    return out


def _span_index(spans, t):
    for i, (s, d, c) in enumerate(spans):
        if s - 1e-9 <= t < s + d - 1e-9:
            return i
    return None


def _ring_durations(plucks, spans, ring_over: float, max_ring: float):
    """plucks: list of [t, string_id, pitch, vel]; returns list with durations appended."""
    plucks.sort(key=lambda x: x[0])
    out = []
    for i, (t, sid, p, v) in enumerate(plucks):
        nxt = None
        for j in range(i + 1, len(plucks)):
            if plucks[j][1] == sid or plucks[j][2] == p:
                nxt = plucks[j][0]
                break
        si = _span_index(spans, t)
        span_end = spans[si][0] + spans[si][1] if si is not None else t + max_ring
        end = span_end + ring_over
        if nxt is not None:
            end = min(end, nxt)
        end = min(end, t + max_ring)
        out.append((t, max(0.05, end - t), p, v))
    return out


def fingerpick(part, bars, pattern: str, vel: float = 0.7, n_upper: int = 3, lo: int = 52,
               hi: int = 74, bass_lo: int = 40, bass_hi: int = 52, ring_over: float = 0.12,
               max_ring: float = 8.0, top_max: int | None = None, accent_beats=(0,),
               bass_vel: float = 1.0, transpose: int = 0, flags=()):
    """Fingerpicking.  pattern tokens per bar step: B=bass, A=alternate bass, 1..4=upper
    string (low->high), combos like 'B3' (pinch), '-' rest.  e.g. Travis:
    'B 3 A 2 B 3 A 2'."""
    song = part.song
    steps = pattern.split()
    spans = chord_spans(song, bars)
    voicings = {}
    prev = None
    prev_bass = None
    for i, (s, d, c) in enumerate(spans):
        v = guitar_voicing(c, prev, n_upper, lo, hi, bass_lo, bass_hi, prev_bass, top_max)
        voicings[i] = v
        prev, prev_bass = v, v[0]
    plucks = []
    for b in song.bar_list(bars):
        b0 = song.bar_beat(b)
        step = song.bpb / len(steps)
        for k, st in enumerate(steps):
            if st in ("-", "."):
                continue
            t = b0 + k * step
            si = _span_index(spans, t)
            if si is None:
                continue
            v = voicings[si]
            c = spans[si][2]
            on_accent = any(abs((k * step) - a) < 1e-6 for a in accent_beats)
            for ch in st:
                if ch == "B":
                    p, sid, vv = v[0], "B", vel * bass_vel * (1.0 if on_accent else 0.9)
                elif ch == "A":
                    p = fifth_below_or_above(c, v[0], bass_lo - 2, bass_hi + 2)
                    sid, vv = "A", vel * bass_vel * 0.88
                elif ch.isdigit():
                    up = v[1:]
                    idx = min(int(ch), len(up)) - 1
                    p, sid, vv = up[idx], f"U{idx}", vel * 0.82
                else:
                    raise ValueError(f"bad fingerpick token {st!r}")
                plucks.append([t, sid, p + transpose, vv])
    for t, d, p, v in _ring_durations(plucks, spans, ring_over, max_ring):
        part.add(t, d, p, v, flags)


def strum(part, bars, pattern: str, vel: float = 0.7, n_upper: int = 4, lo: int = 52,
          hi: int = 76, bass_lo: int = 40, bass_hi: int = 52, spread_ms: float = 22.0,
          up_strings: int = 3, gate: float = 0.96, top_max: int | None = None,
          bass_in_down: bool = True, flags=()):
    """Strummed chords.  One char per step: D/d down (loud/soft), U/u up, x muted chuck,
    B bass only (boom), C chord only (chick), '-' rest, '~' hold."""
    song = part.song
    steps = [c for c in pattern if not c.isspace()]
    spans = chord_spans(song, bars)
    voicings = {}
    prev, prev_bass = None, None
    for i, (s, d, c) in enumerate(spans):
        v = guitar_voicing(c, prev, n_upper, lo, hi, bass_lo, bass_hi, prev_bass, top_max)
        voicings[i] = v
        prev, prev_bass = v, v[0]
    hits = []  # (t, kind)
    for b in song.bar_list(bars):
        b0 = song.bar_beat(b)
        step = song.bpb / len(steps)
        for k, ch in enumerate(steps):
            t = b0 + k * step
            if ch in "-.":
                hits.append((t, "rest"))
            elif ch == "~":
                continue
            else:
                hits.append((t, ch))
    hits.sort()
    for i, (t, kind) in enumerate(hits):
        if kind == "rest":
            continue
        si = _span_index(spans, t)
        if si is None:
            continue
        nxt = hits[i + 1][0] if i + 1 < len(hits) else spans[si][0] + spans[si][1]
        span_end = spans[si][0] + spans[si][1]
        dur = max(0.05, (min(nxt, span_end + 0.05) - t) * gate)
        v = voicings[si]
        c = spans[si][2]
        if kind in "Dd":
            ps = v if bass_in_down else v[1:]
            amp = vel * (1.0 if kind == "D" else 0.72)
            n = len(ps)
            for j, p in enumerate(ps):
                off = spread_ms * j / max(1, n - 1)
                part.add(t, dur, p, amp * (0.92 + 0.08 * j / max(1, n - 1)), flags,
                         offset_ms=off)
        elif kind in "Uu":
            ps = v[-up_strings:][::-1]
            amp = vel * (0.78 if kind == "U" else 0.6)
            n = len(ps)
            for j, p in enumerate(ps):
                off = spread_ms * 0.7 * j / max(1, n - 1)
                part.add(t, dur, p, amp * (1.0 - 0.1 * j / max(1, n - 1)), flags,
                         offset_ms=off)
        elif kind == "x":
            for j, p in enumerate(v[1:]):
                part.add(t, 0.06, p, vel * 0.32, set(flags) | {"mute"}, offset_ms=5.0 * j)
        elif kind == "B":
            part.add(t, dur, v[0], vel, flags)
        elif kind == "A":
            p = fifth_below_or_above(c, v[0], bass_lo - 2, bass_hi + 2)
            part.add(t, dur, p, vel * 0.9, flags)
        elif kind == "C":
            n = len(v) - 1
            for j, p in enumerate(v[1:]):
                part.add(t, dur, p, vel * 0.75, flags, offset_ms=spread_ms * 0.6 * j / max(1, n - 1))
        else:
            raise ValueError(f"bad strum char {kind!r}")


def bassline(part, bars, steps: str, vel: float = 0.8, lo: int = 31, hi: int = 50,
             center: float = 40.0, gate: float = 0.9, key: str | None = None,
             mode: str = "major", accent_first: float = 1.08, flags=(), vels=None):
    """Step bass.  Tokens per bar: 1 (bass note / slash bass), R (true root), 3, 5, 6, 7,
    8 (octave above), 2 (ninth), 4, L (fifth below), a (chromatic approach to the next
    chord's bass), w (diatonic step approach), '-' (extend previous), '.' (rest)."""
    song = part.song
    toks = steps.split()
    scale = scale_pcs(key or song.key, mode)
    prev = None
    evs = []
    for b in song.bar_list(bars):
        b0 = song.bar_beat(b)
        step = song.bpb / len(toks)
        for k, tk in enumerate(toks):
            t = b0 + k * step
            if k > 0 and tk not in (".", "1", "R") and any(abs(c0 - t) < 1e-9 for c0, _d, _c in song.chart):
                tk = "1"          # a chord change always gets the new chord's bass note
            if tk == ".":
                evs.append(None)
                continue
            if tk == "-":
                if evs and evs[-1] is not None:
                    evs[-1][1] += step
                continue
            c = song.chord_at(t)
            base = bass_note(c, lo, hi, prev, center)
            if tk == "1":
                p = base
            elif tk == "R":
                p = nearest(c.root, base, lo, hi)
            elif tk == "5":
                p = fifth_below_or_above(c, base, lo, hi) if c.bass == c.root else nearest(c.fifth_pc(), base + 4, lo, hi)
            elif tk == "L":
                p = base - 5 if base - 5 >= lo else base + 7
            elif tk == "8":
                p = base + 12 if base + 12 <= hi + 7 else base
            elif tk in "234 67":
                iv = {"2": 14, "3": None, "4": 5, "6": 9, "7": None}[tk]
                if tk == "3":
                    tp = c.third_pc()
                    pc = tp if tp is not None else (c.root + 4) % 12
                elif tk == "7":
                    pcs = [pc for pc, r in c.roles() if r == "seventh"]
                    pc = pcs[0] if pcs else (c.root + 10) % 12
                else:
                    pc = (c.root + iv) % 12
                p = nearest(pc, base + 3, lo, hi + 5)
            elif tk in ("a", "w"):
                tn = t + step
                nc = song.chord_at(tn) if tn < song.total_beats else song.next_chord_after(t)
                if nc is None:
                    nc = c
                target = bass_note(nc, lo, hi, prev, center)
                if tk == "a":
                    cur = prev if prev is not None else base
                    p = target - 1 if cur < target else target + 1
                else:
                    below = [x for x in range(target - 3, target) if x % 12 in scale]
                    above = [x for x in range(target + 1, target + 4) if x % 12 in scale]
                    cur = prev if prev is not None else base
                    opts = (below[-1:] + above[:1]) or [target - 2]
                    p = min(opts, key=lambda x: abs(x - cur))
            else:
                raise ValueError(f"bad bass token {tk!r}")
            vv = vel * (accent_first if k == 0 else 1.0)
            if vels is not None:
                vv = vel * vels[k % len(vels)]
            evs.append([t, step, p, vv])
            prev = p
    for e in evs:
        if e is None:
            continue
        t, d, p, v = e
        part.add(t, d * gate, p, v, flags)


def walking_bass(part, bars, vel: float = 0.75, lo: int = 31, hi: int = 50,
                 key: str | None = None, mode: str = "major", gate: float = 0.88, flags=()):
    """Quarter-note walking line: root on the chord's first beat, chord tones / scale
    steps in between, chromatic or dominant approach into the next chord."""
    song = part.song
    scale = scale_pcs(key or song.key, mode)
    rng = song.rng("walk", part.name)
    prev = None
    beats = []
    for b in song.bar_list(bars):
        b0 = song.bar_beat(b)
        for k in range(int(song.bpb)):
            beats.append(b0 + k)
    for i, t in enumerate(beats):
        c = song.chord_at(t)
        nxt_t = beats[i + 1] if i + 1 < len(beats) else t + 1
        nc = song.chord_at(nxt_t) if nxt_t < song.total_beats else song.next_chord_after(t) or c
        chord_start = any(abs(s0 - t) < 1e-9 for s0, _d, _c in song.chart)
        target = bass_note(nc, lo, hi, prev, 40)
        if chord_start or prev is None:
            p = bass_note(c, lo, hi, prev, 40)
        elif nc.symbol != c.symbol or (i + 1 < len(beats) and abs(nxt_t % song.bpb) < 1e-9):
            # approach the next chord tone from a half step or a scale step
            if rng.random() < 0.55:
                p = target - 1 if prev < target else target + 1
            else:
                cands = [x for x in range(target - 2, target + 3) if x != target and x % 12 in scale]
                p = min(cands, key=lambda x: abs(x - prev)) if cands else target - 1
        else:
            tones = [x for x in range(lo, hi + 1) if x % 12 in c.pcs and abs(x - prev) <= 7 and x != prev]
            steps_ = [x for x in range(prev - 2, prev + 3) if x % 12 in scale and x != prev and lo <= x <= hi]
            pool = tones + steps_
            if not pool:
                pool = [prev + 2]
            # gentle drift toward the middle of the range
            mid = (lo + hi) / 2
            pool.sort(key=lambda x: abs(x - prev) + 0.15 * abs(x - mid) + rng.random() * 2.0)
            p = pool[0]
        p = max(lo, min(hi, p))
        part.add(t, gate, p, vel * (1.06 if abs(t % song.bpb) < 1e-9 else 0.95), flags)
        prev = p


def pad(part, bars, n: int = 4, lo: int = 55, hi: int = 76, vel: float = 0.6,
        top_max: int | None = None, rootless: bool = False, overlap: float = 0.0,
        keep_fifth: bool = True, center=None, max_gap: int = 9, flags=(), merge=True,
        rhythm: str | None = None, steps: int = 2, gate: float = 0.95):
    """Sustained voice-led chords (one event per chord span), or re-struck on a grid."""
    song = part.song
    spans = chord_spans(song, bars, merge)
    prev = None
    for s, d, c in spans:
        v = voice(c, n, lo, hi, prev, rootless=rootless, keep_fifth=keep_fifth,
                  top_max=top_max, center=center, max_gap=max_gap)
        prev = v
        if rhythm is None:
            part.add(s, d + overlap, list(v), vel, flags)
        else:
            hits = parse_grid(rhythm, steps)
            plen = song.bpb
            tb = s - (s % plen)
            while tb < s + d - 1e-9:
                pts = [(tb + o, vv) for o, vv in hits if s - 1e-9 <= tb + o < s + d - 1e-9]
                for j, (t, vv) in enumerate(pts):
                    nxt = pts[j + 1][0] if j + 1 < len(pts) else min(s + d, tb + plen)
                    part.add(t, max(0.05, (nxt - t) * gate), list(v), vel * vv, flags)
                tb += plen
    return prev


def arp(part, bars, rate: float = 0.25, order="up", n: int = 4, lo: int = 60, hi: int = 84,
        vel: float = 0.6, gate: float = 0.8, octaves: int = 1, accent_every: int | None = None,
        rootless=False, top_max=None, flags=(), skip_rate: float = 0.0, seed_tag="arp"):
    """Arpeggiate each chord: order 'up' | 'down' | 'updown' | 'random' | list of indices."""
    song = part.song
    rng = song.rng(seed_tag, part.name)
    spans = chord_spans(song, bars)
    prev = None
    for s, d, c in spans:
        v = voice(c, n, lo, hi, prev, rootless=rootless, top_max=top_max)
        prev = v
        notes = list(v)
        for o in range(1, octaves):
            notes += [x + 12 * o for x in v]
        if order == "up":
            seq = notes
        elif order == "down":
            seq = notes[::-1]
        elif order == "updown":
            seq = notes + notes[-2:0:-1]
        elif order == "random":
            seq = None
        else:
            seq = [notes[i % len(notes)] for i in order]
        t = s
        i = 0
        while t < s + d - 1e-9:
            if skip_rate and rng.random() < skip_rate:
                t += rate
                i += 1
                continue
            p = seq[i % len(seq)] if seq is not None else notes[rng.integers(len(notes))]
            vv = vel * (1.12 if accent_every and i % accent_every == 0 else 1.0)
            part.add(t, rate * gate, p, vv, flags)
            t += rate
            i += 1


def comp(part, bars, rhythm: str, vel: float = 0.6, n: int = 4, lo: int = 50, hi: int = 72,
         rootless: bool = True, gate: float = 0.9, steps: int = 2, top_max=None, flags=(),
         keep_fifth=False):
    """Keyboard comping on a per-bar grid rhythm (e.g. 'x..x .x..' in 8ths)."""
    song = part.song
    hits = parse_grid(rhythm, steps)
    spans = chord_spans(song, bars)
    vo = {}
    prev = None
    for i, (s, d, c) in enumerate(spans):
        vo[i] = voice(c, n, lo, hi, prev, rootless=rootless, top_max=top_max, keep_fifth=keep_fifth)
        prev = vo[i]
    times = []
    for b in song.bar_list(bars):
        b0 = song.bar_beat(b)
        for o, v in hits:
            times.append((b0 + o, v))
    for j, (t, v) in enumerate(times):
        si = _span_index(spans, t)
        if si is None:
            continue
        nxt = times[j + 1][0] if j + 1 < len(times) else t + 1.0
        end = min(nxt, spans[si][0] + spans[si][1] + 0.5)
        part.add(t, max(0.08, (end - t) * gate), list(vo[si]), vel * v, flags)


def banjo_roll(part, bars, roll: str = "0 1 2 3 0 2 1 3", drone: int = 67, vel: float = 0.6,
               lo: int = 50, hi: int = 72, ring_over: float = 0.1, flags=()):
    """Three-finger banjo rolls over chord tones plus the high drone (5th) string."""
    song = part.song
    idx = [int(x) for x in roll.split()]
    spans = chord_spans(song, bars)
    vo = {}
    prev = None
    for i, (s, d, c) in enumerate(spans):
        vo[i] = voice(c, 3, lo, hi, prev, max_gap=7)
        prev = vo[i]
    plucks = []
    for b in song.bar_list(bars):
        b0 = song.bar_beat(b)
        step = song.bpb / len(idx)
        for k, ix in enumerate(idx):
            t = b0 + k * step
            si = _span_index(spans, t)
            if si is None:
                continue
            strings = list(vo[si]) + [drone]
            p = strings[ix]
            vv = vel * (1.0 if k % 3 == 0 else 0.85) * (0.8 if ix == 3 else 1.0)
            plucks.append([t, f"S{ix}", p, vv])
    for t, d, p, v in _ring_durations(plucks, spans, ring_over, 3.0):
        part.add(t, d, p, v, flags)


def waltz(part, bars, vel: float = 0.65, n_upper: int = 3, lo: int = 55, hi: int = 72,
          bass_lo: int = 40, bass_hi: int = 52, chord_gate: float = 0.8, flags=(),
          bass_part=None, pattern: str = "B C C"):
    """Oom-pah-pah: bass on 1 (alternating root/fifth on repeated chords), chord on 2 & 3."""
    song = part.song
    toks = pattern.split()
    spans = chord_spans(song, bars)
    vo = {}
    prev, pb = None, None
    for i, (s, d, c) in enumerate(spans):
        vo[i] = guitar_voicing(c, prev, n_upper, lo, hi, bass_lo, bass_hi, pb)
        prev, pb = vo[i], vo[i][0]
    bp = bass_part or part
    for bi, b in enumerate(song.bar_list(bars)):
        b0 = song.bar_beat(b)
        step = song.bpb / len(toks)
        for k, tk in enumerate(toks):
            t = b0 + k * step
            si = _span_index(spans, t)
            if si is None:
                continue
            v = vo[si]
            c = spans[si][2]
            first_bar_of_span = abs(b0 - (spans[si][0] - spans[si][0] % song.bpb)) < 1e-9
            if tk == "B":
                p = v[0] if first_bar_of_span or bi % 2 == 0 else fifth_below_or_above(c, v[0], bass_lo - 2, bass_hi + 2)
                bp.add(t, step * 0.95, p, vel * 1.05, flags)
            elif tk == "A":
                p = fifth_below_or_above(c, v[0], bass_lo - 2, bass_hi + 2)
                bp.add(t, step * 0.95, p, vel, flags)
            elif tk == "C":
                for j, p in enumerate(v[1:]):
                    part.add(t, step * chord_gate, p, vel * 0.72, flags, offset_ms=4.0 * j)
            elif tk in "-.":
                continue
            else:
                raise ValueError(tk)
