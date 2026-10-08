"""Raider: a living human scavenger, not a zombie. Warm skin (SKIN_RAMPS[0]) under a mohawk,
goggles and a rust-red bandana; a dark leather jacket with a rusty scrap pauldron on the right
shoulder and a rust bandolier; charcoal trousers and heavy boots. Carries a pipe pistol: held low
in idle / walk, raised (frame 0) and aimed (frame 1, the telegraph), kicked by the shot (frame 2;
the muzzle flash is a separate FX), lowered again (frame 3).
"""
from __future__ import annotations

import palette as P
from enemies import humanoid as H
from enemies import rig
from enemies.pix import mix, ramp, rgba

SK = ramp(P.SKIN_RAMPS[0])
LEA = ramp(P.RAIDER_LEATHER_RAMP)
TRO = ramp(P.RAIDER_TROUSER_RAMP)
RUST = ramp(P.RUST_RAMP)
RED = ramp(P.RAIDER_RED_RAMP)
MET = ramp(P.METAL_RAMP)
WOOD = ramp(P.WOOD_RAMP)
BLOOD = ramp(P.BLOOD)
MUZZLE = mix(MET[0], P.OUTLINE_COLD, 0.6)

CMAP = {
    "1": SK[0], "2": SK[1], "3": SK[2], "4": SK[3], "5": SK[4],
    "h": rgba(P.RAIDER_HAIR), "H": LEA[2],
    "g": MET[1], "L": MET[5], "G": MET[0],
    "x": RED[1], "y": RED[2], "z": RED[3],
    "a": LEA[0], "b": LEA[1], "c": LEA[2], "d": LEA[3],
    "M": MET[2], "N": MET[3], "O": MET[4],
    "k": LEA[0], "r": rgba(P.GORE_STAIN), "R": BLOOD[0],
}

HEAD_S = {
    "n": ["..hH..",
          "..hh..",
          ".3hh3.",
          "43hh32",
          "gLggLg",
          "xzyyyx",
          ".xyyx.",
          "..yx.."],
    "x": ["..hH..",
          "..hh..",
          ".3hh3.",
          "43hh32",
          "gGggGg",
          "xzyyyx",
          ".xyyx.",
          "..yx.."],
}
HEAD_S["o"] = HEAD_S["n"]
HEAD_N = {"n": ["..hH..",
                "..hh..",
                ".3hh3.",
                "32hh23",
                "gggggg",
                "32hh22",
                ".2xy2.",
                "..yx.."]}
HEAD_N["o"] = HEAD_N["x"] = HEAD_N["n"]
HEAD_E = {
    "n": ["..hH..",
          ".hhh..",
          "3hhh4.",
          "32444.",
          "ggggLg",
          "32xzyy",
          ".3xyy.",
          "..xx.."],
}
HEAD_E["o"] = HEAD_E["x"] = HEAD_E["n"]

TORSO_S = [".ON......",
           "MNOcddcb.",
           "MyMcxcbba",
           ".bccbxbba",
           ".bcccbxba",
           ".kkkNkkk.",
           "..b...a.."]
TORSO_N = [".......NO",
           ".bcddcMNO",
           "abbcycMyM",
           "abbcyybb.",
           "abbycybb.",
           ".kkkkkkk.",
           "..b...a.."]
TORSO_E = ["..ON..",
           ".MNOc.",
           "bMyMdc",
           "bccxcb",
           "bcccxb",
           "kkkNkk",
           ".b..a."]

BODY = H.Body(
    cmap=CMAP,
    head_s=HEAD_S, head_n=HEAD_N, head_e=HEAD_E,
    torso_s=TORSO_S, torso_n=TORSO_N, torso_e=TORSO_E,
    head_s_at=(9, 2), head_e_at=(10, 2), torso_s_at=(7, 8), torso_e_at=(9, 8),
    legs=TRO, shoe=(LEA[0], RUST[2]), shin=None,
    leg_x=(10, 13), hip_e=10, hip_y=15,
    sleeve=LEA[2], sleeve_dark=LEA[1], skin=(SK[1], SK[2], SK[3]), claw=False, wrap=RED[2],
)


# ------------------------------------------------------------------------------------------------
# the pipe pistol, drawn at the gun hand
# ------------------------------------------------------------------------------------------------
def pistol(mode):
    def draw(cv, hx, hy, dx, dy):
        if mode == "low_s":          # hanging at the side, muzzle down
            cv.px(hx, hy + 1, MET[3]); cv.px(hx, hy + 2, RUST[3]); cv.px(hx, hy + 3, MET[1])
        elif mode == "low_n":
            cv.px(hx, hy + 1, MET[1]); cv.px(hx, hy + 2, MET[0])
        elif mode == "low_e":        # held at the hip, pointing forward-down
            cv.px(hx + 1, hy, MET[3]); cv.px(hx + 2, hy + 1, RUST[3]); cv.px(hx + 3, hy + 1, MET[1])
            cv.px(hx, hy + 1, WOOD[2])
        elif mode == "aim_e":        # locked out at eye level
            cv.px(hx, hy - 1, MET[4])
            for k, c in enumerate((MET[3], MET[2], RUST[3], MET[2], MET[1])):
                cv.px(hx + 1 + k, hy, c)
            cv.px(hx, hy + 1, WOOD[2]); cv.px(hx + 1, hy - 1, MET[4])
        elif mode == "kick_e":       # muzzle jerked up by the shot
            cv.px(hx, hy + 1, WOOD[2])
            for (x, y, c) in ((1, 0, MET[3]), (2, 0, MET[2]), (3, -1, RUST[3]), (4, -1, MET[2]),
                              (5, -2, MET[1])):
                cv.px(hx + x, hy + y, c)
        elif mode in ("aim_s", "kick_s"):   # pointed at the viewer: foreshortened, dark muzzle
            o = -1 if mode == "kick_s" else 0
            cv.px(hx, hy + 1 + o, MET[4]); cv.px(hx + 1, hy + 1 + o, MET[3])
            cv.px(hx, hy + 2 + o, MET[3]); cv.px(hx + 1, hy + 2 + o, RUST[3])
            cv.px(hx, hy + 3 + o, MUZZLE); cv.px(hx + 1, hy + 3 + o, MET[1])
        elif mode in ("aim_n", "kick_n"):   # pointed away: barrel above the hands
            o = -1 if mode == "kick_n" else 0
            cv.px(hx, hy - 1 + o, MET[3]); cv.px(hx, hy - 2 + o, RUST[3]); cv.px(hx, hy - 3 + o, MET[1])
        elif mode == "dropped":      # lying on the ground beside the corpse
            for k, c in enumerate((WOOD[2], MET[3], MET[2], RUST[3], MET[1])):
                cv.px(hx + 1 + k, hy, c)
    return draw


def A(pts, gun=None, sleeve=0):
    return H.Arm(pts, sleeve=sleeve, item=pistol(gun) if gun else None)


# ------------------------------------------------------------------------------------------------
def arms_s(bx=0, by=0, swing=0, gun="low_s"):
    return [A([(8 + bx, 10 + by), (8 + bx, 12 + by - swing), (8 + bx, 14 + by - swing)]),
            A([(15 + bx, 10 + by), (16 + bx, 12 + by + swing), (16 + bx, 14 + by + swing)], gun)]


def arms_n(bx=0, by=0, swing=0):
    return [A([(8 + bx, 10 + by), (7 + bx, 12 + by - swing), (7 + bx, 14 + by - swing)], "low_n"),
            A([(15 + bx, 10 + by), (15 + bx, 12 + by + swing), (15 + bx, 14 + by + swing)])]


def arms_e(bx=0, by=0, swing=0, gun="low_e"):
    far = A([(11 + bx, 10 + by), (11 + bx - swing, 12 + by), (11 + bx - swing, 13 + by)])
    near = A([(12 + bx, 10 + by), (13 + bx + swing, 12 + by), (14 + bx + swing, 13 + by)], gun)
    return [far, near]


def poses():
    P_ = H.Pose
    out = {}
    for i in range(2):                                   # idle: weight shift, gun low
        out[("idle", "S", i)] = P_(by=i, arms=arms_s(0, i))
        out[("idle", "N", i)] = P_(by=i, arms=arms_n(0, i))
        out[("idle", "E", i)] = P_(by=i, arms=arms_e(0, i))
    sn = [dict(by=0, legs=(0, 1), sw=1), dict(by=-1, legs=(0, 0), sw=0),
          dict(by=0, legs=(1, 0), sw=-1), dict(by=-1, legs=(0, 0), sw=0)]
    for i, w in enumerate(sn):
        out[("walk", "S", i)] = P_(by=w["by"], legs=w["legs"], arms=arms_s(0, w["by"], w["sw"]))
        out[("walk", "N", i)] = P_(by=w["by"], legs=w["legs"], arms=arms_n(0, w["by"], -w["sw"]))
    we = [dict(stride=2, by=0, legs=(0, 0), sw=1), dict(stride=0, by=-1, legs=(0, 1), sw=0),
          dict(stride=-2, by=0, legs=(0, 0), sw=-1), dict(stride=0, by=-1, legs=(1, 0), sw=0)]
    for i, w in enumerate(we):
        out[("walk", "E", i)] = P_(stride=w["stride"], by=w["by"], legs=w["legs"],
                                   arms=arms_e(0, w["by"], w["sw"]))
    # attack: raise, AIM (telegraph), shot kick, lower
    out[("attack", "S", 0)] = P_(arms=[A([(8, 10), (8, 12), (9, 13)]),
                                       A([(15, 10), (16, 12), (15, 13)], "aim_s")])
    out[("attack", "S", 1)] = P_(hy=1, arms=[A([(8, 10), (6, 11), (10, 11)]),
                                             A([(15, 10), (17, 11), (12, 11)], "aim_s")])
    out[("attack", "S", 2)] = P_(by=-1, arms=[A([(8, 9), (6, 9), (10, 9)]),
                                              A([(15, 9), (17, 9), (12, 9)], "kick_s")])
    out[("attack", "S", 3)] = P_(arms=arms_s(0, 0, gun="low_s"))
    out[("attack", "N", 0)] = P_(arms=[A([(8, 10), (7, 10), (11, 8)]),
                                       A([(15, 10), (16, 10), (13, 7)], "aim_n")])
    out[("attack", "N", 1)] = P_(arms=[A([(8, 10), (6, 9), (12, 6)]),
                                       A([(15, 10), (17, 9), (13, 5)], "aim_n")])
    out[("attack", "N", 2)] = P_(by=1, arms=[A([(8, 11), (6, 10), (12, 7)]),
                                             A([(15, 11), (17, 10), (13, 6)], "kick_n")])
    out[("attack", "N", 3)] = P_(arms=arms_n(0, 0))
    out[("attack", "E", 0)] = P_(arms=[A([(11, 10), (12, 12), (13, 12)]),
                                       A([(12, 10), (15, 11), (16, 10)], "aim_e")])
    out[("attack", "E", 1)] = P_(hx=0, stride=1, arms=[A([(11, 10), (14, 10), (16, 9)]),
                                                       A([(12, 10), (15, 9), (17, 9)], "aim_e")])
    out[("attack", "E", 2)] = P_(bx=-1, stride=1, arms=[A([(10, 10), (13, 9), (15, 8)]),
                                                        A([(11, 10), (14, 9), (16, 8)], "kick_e")])
    out[("attack", "E", 3)] = P_(arms=arms_e(0, 0))
    # hurt: knocked back, gun hand flung
    out[("hurt", "S")] = P_(by=-1, hy=-1, arms=[A([(8, 9), (6, 10), (5, 12)]),
                                                A([(15, 9), (17, 10), (18, 12)], "low_s")])
    out[("hurt", "N")] = P_(by=-1, hy=-1, arms=[A([(8, 9), (6, 10), (5, 12)], "low_n"),
                                                A([(15, 9), (17, 10), (18, 12)])])
    out[("hurt", "E")] = P_(bx=-2, hx=-1, stride=1, arms=[A([(9, 10), (8, 12), (7, 13)]),
                                                          A([(10, 10), (12, 12), (13, 14)], "low_e")])
    return out


def death_frames():
    P_ = H.Pose
    f0 = BODY.frame("S", P_(by=1, hx=1, arms=[A([(8, 11), (10, 12), (12, 12)]),
                                              A([(15, 11), (17, 13), (17, 15)], "low_s")]))
    f1 = BODY.frame("S", P_(by=4, hy=1, hx=-1, head="x", kneel=True, arms=[
        A([(8, 14), (7, 16), (7, 18)]), A([(15, 14), (16, 16), (16, 18)])]))
    lying = P_(head="x", spread=1, legs=(1, 0), arms=[
        A([(8, 10), (6, 11), (5, 9)]), A([(15, 10), (16, 12), (16, 14)])])
    f2 = BODY.lying(lying, lift=2, dx=-2)
    f3 = BODY.lying(lying, lift=0, dx=-2, pool=True, extra=None)
    pistol("dropped")(f3, 7, 20 - 1, 1, 0)
    return [f0, f1, f2, f3]


def frames():
    out = {k: BODY.frame(k[1], p) for k, p in poses().items()}
    for i, f in enumerate(death_frames()):
        out[("death", i)] = f
    return out


def sheet():
    return rig.assemble(frames())
