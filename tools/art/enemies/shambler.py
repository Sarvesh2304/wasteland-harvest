"""Shambler: the basic infected. Hunched, arms reaching, torn filthy work clothes, grey-green
rotting skin (ZOMBIE_SKIN_RAMP), a shuffling lurch. Attack = a two-handed clawing lunge whose
telegraph (frame 1) is both arms thrown up over the head with the jaw hanging open.
"""
from __future__ import annotations

import palette as P
from enemies import humanoid as H
from enemies import rig
from enemies.pix import ramp, rgba

ZS = ramp(P.ZOMBIE_SKIN_RAMP)
SHIRT = ramp(P.INFECTED_SHIRT_RAMP)
TROUSER = ramp(P.INFECTED_TROUSER_RAMP)
BLOOD = ramp(P.BLOOD)

CMAP = {
    "1": ZS[0], "2": ZS[1], "3": ZS[2], "4": ZS[3], "5": ZS[4],
    "e": rgba(P.INFECTED_EYE), "m": rgba(P.GORE_DARK), "r": rgba(P.GORE_STAIN), "R": BLOOD[0],
    "a": SHIRT[0], "b": SHIRT[1], "c": SHIRT[2], "d": SHIRT[3],
    "p": TROUSER[0], "q": TROUSER[1], "u": TROUSER[2],
    "h": rgba(P.INFECTED_HAIR), "f": rgba(P.FILTH),
}

# heads: 6 wide x 7 tall. n = neutral, o = jaw hanging open (telegraph / hurt), x = dead
HEAD_S = {
    "n": [".hh4h.",
          "h45544",
          "445443",
          "4e22e2",
          ".43322",
          ".3mm2.",
          "..mr.."],
    "o": [".hh4h.",
          "h45544",
          "4e44e2",
          "432222",
          ".3mm2.",
          ".2mm1.",
          "..rr.."],
    "x": [".hh4h.",
          "h45544",
          "445443",
          "412212",
          ".43322",
          ".3mm2.",
          "..rR.."],
}
HEAD_N = {"n": [".hhhh.",
                "hh43hh",
                "h43hhh",
                "hhhhhh",
                ".hhhh.",
                ".3322.",
                "..32.."]}
HEAD_N["o"] = HEAD_N["x"] = HEAD_N["n"]
HEAD_E = {
    "n": [".hhhh.",
          "hh455.",
          "hh4444",
          "h33e24",
          ".33444",
          ".23mm.",
          "..22r."],
    "o": [".hhhh.",
          "hh455.",
          "hh4444",
          "h33e24",
          ".32mmm",
          ".23mm.",
          "..2rr."],
}
HEAD_E["x"] = HEAD_E["o"]

TORSO_S = [".cdddcb.",
           "cdcccbba",
           "ccrccbba",
           "bcc3cbba",
           ".bcc2ba.",
           ".a.bba.a"]
TORSO_N = [".cddccb.",
           "cdcccbba",
           "cc33cbba",
           "bcr2cbaa",
           ".bccbba.",
           ".a.bba.a"]
TORSO_E = [".cd..",
           "cddc.",
           "cdccb",
           "bcccb",
           "bccrb",
           ".bc3b",
           ".bcba",
           ".a.ba"]

BODY = H.Body(
    cmap=CMAP,
    head_s=HEAD_S, head_n=HEAD_N, head_e=HEAD_E,
    torso_s=TORSO_S, torso_n=TORSO_N, torso_e=TORSO_E,
    head_s_at=(9, 4), head_e_at=(11, 4), torso_s_at=(8, 9), torso_e_at=(8, 7),
    legs=TROUSER, shoe=(TROUSER[0], rgba(P.FILTH)), shin=(ZS[3], ZS[2]),
    leg_x=(10, 13), hip_e=9, hip_y=15,
    sleeve=SHIRT[2], sleeve_dark=SHIRT[1], skin=(ZS[2], ZS[3], ZS[4]), claw=True,
)


# ------------------------------------------------------------------------------------------------
# poses
# ------------------------------------------------------------------------------------------------
def arms_s(bx=0, by=0, lift=0, spread=0):
    """Reaching arms from the front: forearms angled out, clawed hands at chest height."""
    return [H.Arm([(8 + bx, 10 + by), (7 + bx - spread, 11 + by - lift),
                   (6 + bx - spread, 12 + by - lift)], sleeve=1),
            H.Arm([(15 + bx, 10 + by), (16 + bx + spread, 11 + by - lift),
                   (17 + bx + spread, 11 + by - lift)], sleeve=0)]


def arms_n(bx=0, by=0, lift=0):
    return [H.Arm([(8 + bx, 10 + by), (7 + bx, 10 + by - lift), (6 + bx, 9 + by - lift)], sleeve=1),
            H.Arm([(15 + bx, 10 + by), (16 + bx, 10 + by - lift), (17 + bx, 9 + by - lift)], sleeve=0)]


def arms_e(bx=0, by=0, drop=0, reach=0):
    """Both arms stretched out under the chin, far hand a pixel higher and shorter."""
    far = H.Arm([(10 + bx, 11 + by), (15 + bx + reach, 11 + by + drop),
                 (18 + bx + reach, 11 + by + drop)], sleeve=0)
    near = H.Arm([(11 + bx, 12 + by), (16 + bx + reach, 12 + by + drop),
                  (19 + bx + reach, 12 + by + drop)], sleeve=2)
    return [far, near]


def arms_up_s(by=0):
    return [H.Arm([(8, 9 + by), (6, 6 + by), (5, 3 + by)], sleeve=1),
            H.Arm([(15, 9 + by), (17, 6 + by), (18, 3 + by)], sleeve=0)]


def arms_limp_s(bx=0, by=0):
    return [H.Arm([(8 + bx, 10 + by), (7 + bx, 12 + by), (7 + bx, 14 + by)], sleeve=1, claw=False),
            H.Arm([(15 + bx, 10 + by), (16 + bx, 12 + by), (16 + bx, 14 + by)], sleeve=0, claw=False)]


def poses():
    P_ = H.Pose
    out = {}
    for i in range(2):                       # idle: slump and sway
        out[("idle", "S", i)] = P_(by=i, arms=arms_s(0, i, lift=-i))
        out[("idle", "N", i)] = P_(by=i, arms=arms_n(0, i))
        out[("idle", "E", i)] = P_(by=i, arms=arms_e(0, i, drop=i))
    walk_sn = [dict(bx=0, by=0, legs=(0, 1), hx=0), dict(bx=-1, by=1, legs=(0, 0), hx=-1),
               dict(bx=0, by=0, legs=(1, 0), hx=0), dict(bx=1, by=1, legs=(0, 0), hx=1)]
    for i, w in enumerate(walk_sn):          # lurching shuffle, head lolling with the sway
        out[("walk", "S", i)] = P_(arms=arms_s(w["bx"], w["by"], lift=w["by"] - 1), **w)
        out[("walk", "N", i)] = P_(arms=arms_n(w["bx"], w["by"]), **w)
    walk_e = [dict(stride=2, by=1, legs=(0, 0), lean=1), dict(stride=0, by=0, legs=(0, 1)),
              dict(stride=-2, by=1, legs=(0, 0), lean=1), dict(stride=0, by=0, legs=(1, 0))]
    for i, w in enumerate(walk_e):
        out[("walk", "E", i)] = P_(arms=arms_e(w.get("lean", 0), w["by"], drop=w["by"]), **w)
    # attack: windup, TELEGRAPH (arms up, jaw open), clawing lunge, recover
    out[("attack", "S", 0)] = P_(by=-1, hy=-1, arms=arms_s(0, -1, lift=3, spread=1))
    out[("attack", "S", 1)] = P_(by=-1, hy=-1, head="o", arms=arms_up_s(-1))
    out[("attack", "S", 2)] = P_(by=1, hy=1, head="o", arms=[
        H.Arm([(8, 11), (7, 14), (6, 17)], sleeve=1), H.Arm([(15, 11), (16, 14), (17, 17)], sleeve=0)])
    out[("attack", "S", 3)] = P_(by=1, arms=arms_s(0, 1, lift=-1))
    out[("attack", "N", 0)] = P_(by=-1, arms=arms_n(0, -1, lift=2))
    out[("attack", "N", 1)] = P_(by=-1, arms=arms_up_s(-1))
    out[("attack", "N", 2)] = P_(by=1, hy=-1, arms=arms_n(0, 1, lift=2))
    out[("attack", "N", 3)] = P_(by=0, arms=arms_n(0, 0))
    out[("attack", "E", 0)] = P_(bx=-1, stride=1, arms=arms_e(-1, 0, drop=-2, reach=-1))
    out[("attack", "E", 1)] = P_(bx=-2, by=-1, stride=2, head="o", hx=-1, arms=[
        H.Arm([(8, 9), (8, 4), (9, 0)], sleeve=0), H.Arm([(9, 10), (13, 5), (15, 1)], sleeve=2)])
    out[("attack", "E", 2)] = P_(bx=2, by=1, stride=3, head="o", lean=1, arms=[
        H.Arm([(12, 12), (16, 13), (19, 14)], sleeve=0), H.Arm([(13, 13), (17, 14), (20, 15)], sleeve=2)])
    out[("attack", "E", 3)] = P_(bx=1, stride=2, arms=arms_e(1, 0, drop=1))
    # hurt: recoil, head snapped back
    out[("hurt", "S")] = P_(by=-1, hy=-1, head="o", arms=arms_s(0, -1, lift=-2, spread=1))
    out[("hurt", "N")] = P_(by=-1, hy=-1, arms=arms_n(0, -1, lift=-1))
    out[("hurt", "E")] = P_(bx=-1, hx=-2, head="o", stride=1, arms=[
        H.Arm([(9, 11), (12, 13), (14, 14)], sleeve=0), H.Arm([(10, 12), (13, 14), (15, 15)], sleeve=2)])
    return out


def death_frames():
    """Stagger, knees buckle, topple, corpse (direction-agnostic, drawn front-on)."""
    P_ = H.Pose
    f0 = BODY.frame("S", P_(by=1, hx=1, head="o", arms=[
        H.Arm([(8, 11), (6, 13), (5, 15)], sleeve=1), H.Arm([(15, 11), (17, 13), (18, 15)], sleeve=0)]))
    f1 = BODY.frame("S", P_(by=4, hy=1, hx=-1, head="x", kneel=True, arms=arms_limp_s(0, 4)))
    lying = P_(head="x", spread=1, legs=(1, 0), arms=[
        H.Arm([(8, 10), (5, 11), (5, 8)], sleeve=1, claw=False),
        H.Arm([(15, 10), (16, 12), (16, 14)], sleeve=0, claw=False)])
    f2 = BODY.lying(lying, lift=2, dx=-2)
    f3 = BODY.lying(lying, lift=0, dx=-2, pool=True)
    return [f0, f1, f2, f3]


def frames():
    out = {k: BODY.frame(k[1], p) for k, p in poses().items()}
    for i, f in enumerate(death_frames()):
        out[("death", i)] = f
    return out


def sheet():
    return rig.assemble(frames())
