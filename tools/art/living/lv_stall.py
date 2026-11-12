"""The open market stall (art/env/props/market_stall_open.png, 48 x 56, footprint 3 x 1).

Tully's caravan days: the existing art/env/props/market_stall.png (env pipeline), loaded and set
on a taller canvas, bottom-aligned (identical body pixels, so swapping the texture in
props.gd set_art() changes nothing but the dressing), then dressed for business:
  * Tully's swallow-tailed slate-blue pennant (his coat's colour, a bottle-cap badge) on a pole
    lashed to the right post, flying over the awning - that is what the extra 8 rows are for;
  * two lit hanging lanterns at the awning's front corners and a string of bottle caps between;
  * goods on the counter: a bolt of teal cloth, the glass jar of caps, a stack of tins, bottles;
  * the plaque moved right, so Tully's pack-goat can stand tethered at the left end;
  * a tied burlap sack on the ground at the right end.
Every added piece gets the 1 px selective warm outline and a warm contact shadow, like the stall.
"""
from __future__ import annotations

from living.lv_common import Canvas, P, WARM, mix, outline, pix, rgba, shadow
from living import lv_goats

W, H = 48, 56
DY = H - 48                      # the stall is pasted at (0, DY): bottom-aligned
SIGN = (18, 34, 12, 6)           # plaque in market_stall.png: x, y, w, h
SIGN_TO_X = 25                   # where it moves to (leaves x 0-21 for the goat)

WOOD = [rgba(c) for c in P.WOOD_RAMP]
BRASS = [rgba(c) for c in P.BRASS_RAMP]
GLOW = [rgba(c) for c in P.WINDOW_GLOW_RAMP]
DUSTER = [rgba(c) for c in P.DUSTER_RAMP]
METAL = [rgba(c) for c in P.METAL_RAMP]
PACK = [rgba(c) for c in P.PACK_CANVAS_RAMP]
TEAL = [rgba(c) for c in P.FEST_TEAL_RAMP]
ROPE = [rgba(c) for c in ("#6a5232", "#9a7c4e", "#c4a46a")]   # = env colors.ROPE
GLASS = [rgba(c) for c in ("#3c5054", "#6a8486", "#a6bcb8", "#dce8e0")]  # clear jar glass (cool)
GLASS_GREEN = [rgba(c) for c in ("#2c4a38", "#4a7458", "#7aa68a", "#c4e0cc")]   # env colors.GLASS_GREEN
GLASS_BROWN = [rgba(c) for c in ("#3e2412", "#6a3c1c", "#985a2a", "#d49a5a")]   # env colors.GLASS_BROWN
CAPS = [rgba(P.CAP_RED), rgba(P.CAP_BLUE), rgba(P.CAP_GLINT), BRASS[3]]


def _obj(w, h):
    return Canvas(w, h)


def _finish(cv, obj, x, y, local=0.6):
    """Outline `obj` (warm selective) and composite it onto `cv` at (x, y)."""
    outline(obj, WARM, local=local)
    cv.blit(obj, x, y)


# -- pieces -----------------------------------------------------------------------------------
def pennant():
    """Pole + swallow-tailed pennant flying left with a cap badge. 13 x 15; pole = column 11."""
    o = _obj(13, 15)
    for y in range(1, 15):
        o.px(11, y, WOOD[4] if y < 14 else WOOD[3])
        o.px(12, y, WOOD[2])
    o.px(11, 0, BRASS[3]); o.px(12, 0, BRASS[1])     # finial
    rows = [                                           # flag cloth, x 0..10, rows 1..6
        "...34444444",
        ".2344444444",
        "22344c4ggb3",
        ".2233444bd3",
        "..223333332",
        "....111222.",
    ]
    cmap = {"1": DUSTER[2], "2": DUSTER[3], "3": DUSTER[4], "4": DUSTER[5],
            "c": DUSTER[3], "g": rgba(P.CAP_GLINT), "b": BRASS[3], "d": BRASS[1]}
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                o.px(i, 1 + j, cmap[ch])
    o.px(5, 3, DUSTER[5])
    return o


def lantern():
    """Small lit hanging lantern, 3 x 7 (hook, cap, glass, base)."""
    o = _obj(3, 7)
    o.px(1, 0, METAL[2])
    o.px(0, 1, BRASS[2]); o.px(1, 1, BRASS[3]); o.px(2, 1, BRASS[1])
    for y in (2, 3, 4):
        o.px(0, y, GLOW[2]); o.px(1, y, GLOW[4] if y == 3 else GLOW[3]); o.px(2, y, GLOW[1])
    o.px(0, 5, BRASS[2]); o.px(1, 5, BRASS[2]); o.px(2, 5, BRASS[0])
    o.px(1, 6, BRASS[1])
    return o


def cap_jar():
    """Glass jar of bottle caps with a tin lid, 7 x 9."""
    o = _obj(7, 9)
    for x in range(1, 6):
        o.px(x, 0, METAL[4] if x < 3 else METAL[3])
        o.px(x, 1, METAL[2])
    caps = ["rbgyrb", "gyrbyr", "brygbg", "yrbrgy", "rgbyrb", "bygrbg"]
    cm = {"r": CAPS[0], "b": CAPS[1], "g": CAPS[2], "y": CAPS[3]}
    for y in range(2, 9):
        for x in range(0, 7):
            edge_l, edge_r = x == 0, x == 6
            if y == 2 or y == 8:
                if x in (0, 6):
                    continue
            if edge_l:
                c = GLASS[2]
            elif edge_r:
                c = GLASS[0]
            elif y == 2:
                c = GLASS[1]                           # empty shoulder of the jar
            else:
                c = mix(cm[caps[y - 3 if y > 2 else 0][(x - 1) % 6]], GLASS[1], 0.25)
                if y == 8:
                    c = mix(c, GLASS[0], 0.4)
            o.px(x, y, c)
    o.px(1, 3, GLASS[3]); o.px(1, 4, GLASS[3])        # glint down the lit side
    return o


def tins():
    """Three food tins stacked 2 + 1, 8 x 8."""
    o = _obj(8, 8)
    lab = [rgba(c) for c in ("#5e2420", "#8a3a2c", "#b0523a", "#cf7650")]   # faded red label
    def tin(x0, y0):
        for x in range(4):
            o.px(x0 + x, y0, METAL[4] if x < 2 else METAL[3])
        for y in range(1, 4):
            for x in range(4):
                c = [lab[3], lab[2], lab[2], lab[1]][x]
                if y == 2:
                    c = [rgba(P.CREAM), mix(rgba(P.CREAM), lab[1], 0.3), mix(rgba(P.CREAM), lab[1], 0.3), lab[1]][x]
                o.px(x0 + x, y0 + y, c)
        for x in range(4):
            o.px(x0 + x, y0 + 4, METAL[2] if x < 3 else METAL[1])
    tin(2, 0)
    tin(0, 3)
    tin(4, 3)
    return o


def bottles():
    """A green and a brown bottle, 5 x 8."""
    o = _obj(5, 8)
    for (x0, G, top) in ((0, GLASS_GREEN, 0), (3, GLASS_BROWN, 2)):
        o.px(x0, top, BRASS[1]); o.px(x0 + 1, top, BRASS[1])          # cork
        o.px(x0, top + 1, G[2]); o.px(x0 + 1, top + 1, G[1])          # neck
        for y in range(top + 2, 8):
            o.px(x0, y, G[3] if y == top + 3 else G[2])
            o.px(x0 + 1, y, G[1] if y < 7 else G[0])
    return o


def cloth_bolt():
    """A folded bolt of teal cloth lying on the counter, 8 x 4."""
    o = _obj(8, 4)
    rows = ["44444443", "33233323", "22122212", "11011101"]
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            o.px(i, j, TEAL[int(ch)])
    o.px(0, 0, TEAL[4]); o.px(0, 1, TEAL[3])
    return o


def sack():
    """Tied burlap sack, 9 x 10."""
    o = _obj(9, 10)
    rows = [
        "...3.4...",
        "...232...",
        "....2....",
        "..34443..",
        ".3444432.",
        "344443322",
        "3443433 2",
        "34433322.",
        ".2332221.",
        "..11111..",
    ]
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in "01234":
                o.px(i, j, PACK[int(ch)])
            elif ch == " ":
                o.px(i, j, PACK[2])
    o.px(3, 1, ROPE[2]); o.px(4, 1, ROPE[1]); o.px(5, 1, ROPE[0])    # the tie
    o.px(4, 6, PACK[1]); o.px(5, 5, PACK[1])                          # a fold
    return o


# -- the stall ----------------------------------------------------------------------------------
def _move_sign(st):
    """Copy the plaque to SIGN_TO_X and patch the counter planks where it was."""
    x0, y0, w, h = SIGN
    block = st.a[y0:y0 + h, x0:x0 + w].copy()
    for y in range(y0, y0 + h):
        st.a[y, x0:x0 + w] = st.a[y, 10]             # each counter row is one plank colour
    st.a[y0:y0 + h, SIGN_TO_X:SIGN_TO_X + w] = block


def _cap_string(cv, x0, x1, y_end, sag):
    pts = []
    n = x1 - x0
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + i, round(y_end + sag * 4 * t * (1 - t))))
    for k, (x, y) in enumerate(pts):
        cv.px(x, y, ROPE[0])
    for k in range(3, n - 2, 4):
        x, y = pts[k]
        c = CAPS[(k // 4) % 4]
        cv.px(x, y + 1, c)
        cv.px(x, y + 2, mix(c, WARM, 0.45))


def market_stall_open(repo):
    base = Canvas.load(repo / "art/env/props/market_stall.png")
    assert (base.w, base.h) == (48, 48), (base.w, base.h)
    _move_sign(base)
    cv = Canvas(W, H)
    cv.blit(base, 0, DY)

    # pennant over the awning, lashed to the right post (behind the awning's front edge)
    flag = pennant()
    outline(flag, WARM, local=0.55)
    back = Canvas(W, H)
    back.blit(flag, 32, 1)
    cv.a = _under(cv, back).a
    # rope lashing where the pole meets the awning
    cv.px(43, 13, ROPE[2]); cv.px(43, 14, ROPE[1])

    # caps strung under the awning, lanterns at the corners (the awning's lower edge is row 24)
    _cap_string(cv, 7, 40, 25, 2)
    for lx in (4, 41):
        _finish(cv, lantern(), lx, 24, local=0.5)

    # goods on the counter (counter top = canvas row 36)
    _finish(cv, cloth_bolt(), 12, 33)
    _finish(cv, cap_jar(), 22, 28)
    _finish(cv, tins(), 31, 29)
    _finish(cv, bottles(), 40, 29)

    # the burlap sack at the right end, then the pack-goat at the left end, on the ground line
    s = sack()
    outline(s, WARM, local=0.6)
    shadow(cv, 43.5, 55, 5, 1)
    cv.blit(s, 38, 45)
    goat = lv_goats.pack_goat()
    shadow(cv, 11, 55, 9, 1)
    cv.blit(goat, 0, H - goat.h - 0)
    # tether: from the goat's neck to the counter's left post
    for (x, y) in pix.line_points(7, 45, 2, 38):
        if cv.alpha(x, y) == 255 and _is_goat(cv, x, y):
            continue
        cv.px(x, y, ROPE[1])
    return cv


def _is_goat(cv, x, y):
    c = tuple(int(v) for v in cv.a[y, x, :3])
    return c in {tuple(rgba(v)[:3]) for v in P.GOAT_COAT_RAMP + P.GOAT_HORN_RAMP + [P.GOAT_OUTLINE]}


def _under(cv, back):
    out = Canvas(cv.w, cv.h)
    out.blit(back, 0, 0)
    out.blit(cv, 0, 0)
    return out
