"""Runner: a fast infected. Lean, emaciated and pallid (RUNNER_SKIN_RAMP), bare ribcage, ragged
shorts, long clawed arms hanging to the knees, an aggressive forward lean and a loping stride.
Attack = a quick one-handed swipe; the telegraph (frame 1) is the clawed arm cocked high over
the head while it shrieks.
"""
from __future__ import annotations

import palette as P
from enemies import humanoid as H
from enemies import rig
from enemies.pix import ramp, rgba

RS = ramp(P.RUNNER_SKIN_RAMP)
RAG = ramp(P.CLOTH_RAMP)
BLOOD = ramp(P.BLOOD)

CMAP = {
    "1": RS[0], "2": RS[1], "3": RS[2], "4": RS[3], "5": RS[4],
    "e": rgba(P.INFECTED_EYE), "w": rgba(P.SIGNAGE_CREAM), "m": rgba(P.GORE_DARK),
    "r": rgba(P.GORE_STAIN), "R": BLOOD[0], "h": rgba(P.INFECTED_HAIR),
    "p": RAG[0], "q": RAG[1], "u": RAG[2],
}

HEAD_S = {
    "n": [".4554.",
          "455443",
          "4e32e2",
          "423322",
          ".mwwm.",
          ".2mm2.",
          "..21.."],
    "o": [".4554.",
          "4e54e3",
          "423322",
          ".mwwm.",
          ".mmmm.",
          ".2mm2.",
          "..mm.."],
    "x": [".4554.",
          "455443",
          "423322",
          "423322",
          ".mwwm.",
          ".2mm2.",
          "..rR.."],
}
HEAD_N = {"n": [".4554.",
                "455443",
                "4h44h2",
                "443322",
                ".3322.",
                ".2332.",
                "..21.."]}
HEAD_N["o"] = HEAD_N["x"] = HEAD_N["n"]
HEAD_E = {
    "n": [".4554.",
          "455444",
          "4443e4",
          "443334",
          ".33mww",
          ".23mm.",
          "..22.."],
    "o": [".4554.",
          "455444",
          "4443e4",
          "43mwww",
          ".3mmm.",
          ".2mmw.",
          "..22.."],
}
HEAD_E["x"] = HEAD_E["o"]

TORSO_S = [".5443.",
           "443342",
           "424322",
           "434232",
           "puuqqp",
           "pq.qp."]
TORSO_N = [".5443.",
           "443342",
           "442322",
           "443232",
           "puuqqp",
           "pq.qp."]
TORSO_E = ["...454.",
           "..44543",
           ".442432",
           ".4232r.",
           "puqqp..",
           ".pqp..."]

BODY = H.Body(
    cmap=CMAP,
    head_s=HEAD_S, head_n=HEAD_N, head_e=HEAD_E,
    torso_s=TORSO_S, torso_n=TORSO_N, torso_e=TORSO_E,
    head_s_at=(9, 5), head_e_at=(13, 5), torso_s_at=(9, 9), torso_e_at=(8, 9),
    legs=[RS[1], RS[2], RS[3]], shoe=(RS[1], RS[2]), shin=None,
    leg_x=(9, 13), hip_e=9, hip_y=15,
    sleeve=RS[3], sleeve_dark=RS[3], skin=(RS[2], RS[3], RS[4]), claw=True,
)


def A(pts):
    return H.Arm(pts, sleeve=0)


# ------------------------------------------------------------------------------------------------
def arms_s(bx=0, by=0, swing=0):
    """Long arms hanging to the knees; `swing` moves the hands in opposition."""
    return [A([(9 + bx, 10 + by), (8 + bx, 13 + by - swing), (8 + bx, 15 + by - swing)]),
            A([(14 + bx, 10 + by), (15 + bx, 13 + by + swing), (15 + bx, 15 + by + swing)])]


def arms_e(bx=0, by=0, swing=0):
    """Far and near arm hanging forward-down from the leaning shoulders."""
    return [A([(11 + bx, 10 + by), (13 + bx - swing, 13 + by), (14 + bx - swing, 15 + by)]),
            A([(12 + bx, 11 + by), (14 + bx + swing, 14 + by), (16 + bx + swing, 15 + by)])]


def poses():
    P_ = H.Pose
    out = {}
    for i in range(2):                                    # idle: panting crouch
        out[("idle", "S", i)] = P_(by=i, spread=1, arms=arms_s(0, i))
        out[("idle", "N", i)] = P_(by=i, spread=1, arms=arms_s(0, i))
        out[("idle", "E", i)] = P_(by=i, stride=1, arms=arms_e(0, i))
    # walk: loping, big bob, arms pumping in opposition
    sn = [dict(by=0, legs=(0, 2), sw=1), dict(by=-1, legs=(0, 0), sw=0),
          dict(by=0, legs=(2, 0), sw=-1), dict(by=-1, legs=(0, 0), sw=0)]
    for i, w in enumerate(sn):
        out[("walk", "S", i)] = P_(by=w["by"], legs=w["legs"], spread=1, arms=arms_s(0, w["by"], w["sw"]))
        out[("walk", "N", i)] = P_(by=w["by"], legs=w["legs"], spread=1, arms=arms_s(0, w["by"], -w["sw"]))
    we = [dict(stride=3, by=1, legs=(0, 0), sw=2), dict(stride=1, by=-1, legs=(0, 2), sw=0),
          dict(stride=-3, by=1, legs=(0, 0), sw=-2), dict(stride=-1, by=-1, legs=(2, 0), sw=0)]
    for i, w in enumerate(we):
        out[("walk", "E", i)] = P_(stride=w["stride"], by=w["by"], legs=w["legs"], lean=1,
                                   arms=arms_e(0, w["by"], w["sw"]))
    # attack: crouch, TELEGRAPH (claw cocked high, shrieking), swipe, recover
    out[("attack", "S", 0)] = P_(by=1, spread=1, arms=[
        A([(9, 11), (8, 14), (8, 16)]), A([(14, 11), (16, 11), (17, 9)])])
    out[("attack", "S", 1)] = P_(by=1, bx=-1, spread=1, head="o", arms=[
        A([(8, 11), (7, 14), (7, 16)]), A([(13, 11), (16, 7), (17, 2)])])
    out[("attack", "S", 2)] = P_(by=1, bx=1, spread=1, head="o", arms=[
        A([(10, 11), (9, 14), (9, 16)]), A([(15, 11), (12, 15), (7, 17)])])
    out[("attack", "S", 3)] = P_(by=0, spread=1, arms=arms_s(0, 0, 1))
    out[("attack", "N", 0)] = P_(by=1, spread=1, arms=[
        A([(9, 11), (8, 14), (8, 16)]), A([(14, 11), (16, 11), (17, 9)])])
    out[("attack", "N", 1)] = P_(by=1, bx=-1, spread=1, arms=[
        A([(8, 11), (7, 14), (7, 16)]), A([(13, 11), (16, 7), (17, 2)])])
    out[("attack", "N", 2)] = P_(by=1, bx=1, spread=1, arms=[
        A([(10, 11), (9, 14), (9, 16)]), A([(15, 11), (13, 8), (9, 6)])])
    out[("attack", "N", 3)] = P_(by=0, spread=1, arms=arms_s(0, 0, -1))
    out[("attack", "E", 0)] = P_(by=1, bx=-1, stride=2, arms=[
        A([(10, 11), (12, 14), (13, 16)]), A([(11, 12), (10, 14), (9, 13)])])
    out[("attack", "E", 1)] = P_(by=1, bx=-1, stride=2, head="o", arms=[
        A([(10, 11), (12, 14), (13, 16)]), A([(11, 11), (10, 6), (9, 2)])])
    out[("attack", "E", 2)] = P_(by=1, bx=2, stride=3, head="o", lean=1, arms=[
        A([(13, 11), (15, 14), (16, 16)]), A([(14, 12), (18, 12), (22, 13)])])
    out[("attack", "E", 3)] = P_(by=0, bx=1, stride=2, arms=arms_e(1, 0, 1))
    # hurt: snapped upright and back
    out[("hurt", "S")] = P_(by=-1, hy=-2, head="o", arms=[
        A([(9, 9), (7, 11), (6, 13)]), A([(14, 9), (16, 11), (17, 13)])])
    out[("hurt", "N")] = P_(by=-1, hy=-2, arms=[
        A([(9, 9), (7, 11), (6, 13)]), A([(14, 9), (16, 11), (17, 13)])])
    out[("hurt", "E")] = P_(by=-1, bx=-2, hx=-2, head="o", stride=1, arms=[
        A([(9, 9), (8, 12), (7, 14)]), A([(10, 10), (12, 13), (13, 15)])])
    return out


def death_frames():
    P_ = H.Pose
    f0 = BODY.frame("S", P_(by=-1, hy=-2, hx=1, head="o", spread=1, arms=[
        A([(9, 9), (7, 8), (6, 6)]), A([(14, 9), (16, 8), (17, 6)])]))
    f1 = BODY.frame("S", P_(by=4, hy=1, hx=-1, head="x", kneel=True, arms=[
        A([(9, 14), (8, 17), (8, 19)]), A([(14, 14), (15, 17), (15, 19)])]))
    lying = P_(head="x", spread=1, legs=(0, 1), arms=[
        A([(9, 10), (6, 11), (5, 8)]), A([(14, 10), (15, 13), (15, 16)])])
    for a in lying.arms:
        a.claw = False
    f2 = BODY.lying(lying, lift=2, dx=-2)
    f3 = BODY.lying(lying, lift=0, dx=-2, pool=True)
    return [f0, f1, f2, f3]


RISE = 1    # lanky: everything above the hips sits 1 px higher than the shared layout


def _raise(p):
    p.by -= RISE
    for a in p.arms:
        a.pts = [(x, y - RISE) for (x, y) in a.pts]
    return p


def frames():
    out = {k: BODY.frame(k[1], _raise(p)) for k, p in poses().items()}
    for i, f in enumerate(death_frames()):
        out[("death", i)] = f
    return out


def sheet():
    return rig.assemble(frames())
