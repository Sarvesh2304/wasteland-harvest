"""Paper doll for the code-drawn townsfolk (Brask, Wren, Doc Ama).

Matches the PixelLab NPC frames in art/characters/<id>/{idle,walk}/<dir>/<n>.png:
  * 24x24 canvas, figure centred between columns 11 and 12;
  * body pixels end on GROUND = 19 (boot soles) and the 1 px warm outline under them is row 20,
    the same lowest opaque row as the PixelLab townsfolk and the enemy sheets;
  * a figure is 8 px wide (a 6 px torso plus a 1 px arm each side) and ~17 px tall, so with the
    outline it is ~10 x 19 px: the slim townsfolk silhouette, not the bulkier 12 px enemies;
  * light from the top-left; 1 px selective outline (enemies.pix.outline with the WARM colour):
    OUTLINE_WARM below/right of the silhouette, a dark shade of the local material above/left.

A character module builds a `Look`: a colour map, ASCII heads / torsos per facing ("S", "N",
"E", and optionally "W" = the same right-facing view but showing the LEFT flank, mirrored at the
end), arm pixel columns, leg colours and an optional accessory painter. `Look.frame(dir, pose)`
renders one frame; `Look.frames()` renders all idle / walk frames.

Facing conventions: S = toward the camera, N = away. Facing east the camera sees the character's
RIGHT side (their left arm is the far arm); facing west it sees their LEFT side. Asymmetric gear
(an armband, a bag, a club) is drawn per side through the "W" parts instead of being mirrored.
"""
from __future__ import annotations

import numpy as np

from enemies import pix, rig
from enemies.pix import Canvas, rgba

FW = rig.FW
FH = rig.FH
GROUND = 19
WARM = pix.WARM
DIRS = ["south", "north", "east", "west"]
_D = {"south": "S", "north": "N", "east": "E", "west": "W"}


class Pose:
    """One frame's posture (pixels, +y down).
    by     upper-body bob (head, torso, arms, gear): + = lower
    lift   S/N: (viewer-left foot, viewer-right foot) raised px; E/W: (far foot, near foot)
    stride E/W: + = near foot forward (toward +x before the W mirror), far foot back
    swing  arm swing: + = the viewer-left (S/N) or near (E/W) hand forward, the other one back
    """

    def __init__(self, by=0, lift=(0, 0), stride=0, swing=0):
        self.by = by
        self.lift = lift
        self.stride = stride
        self.swing = swing


# idle: a breath - the upper body settles 1 px on frames 1-2, feet planted
IDLE = [Pose(by=0), Pose(by=1), Pose(by=1), Pose(by=0)]
# walk, front/back: contact (one foot lifted, arms swung) -> passing (body up 1 px) -> mirror
WALK_SN = [Pose(by=0, lift=(0, 1), swing=1), Pose(by=-1),
           Pose(by=0, lift=(1, 0), swing=-1), Pose(by=-1)]
# walk, side: near foot forward -> passing (far foot lifted, body up) -> far foot forward -> passing
WALK_E = [Pose(by=0, stride=3, swing=-1), Pose(by=-1, lift=(1, 0)),
          Pose(by=0, stride=-3, swing=1), Pose(by=-1, lift=(0, 1))]


def layer():
    return Canvas(FW, FH)


def stamp(rows, cmap, x, y):
    cv = layer()
    cv.blit(pix.part(rows, cmap), x, y)
    return cv


class Arm:
    """S/N arm: a pixel column from the shoulder down (keys top -> bottom, last = hand).
    E/W arm: the same keys along a line from the shoulder that swings at the hand."""

    def __init__(self, keys, x, y):
        self.keys = list(keys)
        self.x = x
        self.y = y


class Look:
    def __init__(self, cmap, head, torso, arms, legs, boots, leg_x, hip_y, hip_e, gear=None,
                 boot_rows=2, front_gap=True, foot_len=3):
        self.cmap = {k: rgba(v) for k, v in cmap.items()}
        self.head = head        # facing -> (rows, x, y)
        self.torso = torso      # facing -> (rows, x, y)
        self.arms = arms        # "S"/"N": (left Arm, right Arm); "E"/"W": (far Arm, near Arm)
        self.legs = [rgba(c) for c in legs]     # trouser ramp dark -> light (3)
        self.boots = [rgba(c) for c in boots]   # boot ramp dark -> light (3)
        self.leg_x = leg_x      # S/N: left columns of the two 2 px legs
        self.hip_y = hip_y      # first trouser row (hidden under the torso / coat)
        self.hip_e = hip_e      # E/W: hip column
        self.gear = gear        # optional callable(look, facing, pose, cv_layers) -> list of layers
        self.boot_rows = boot_rows
        self.front_gap = front_gap
        self.foot_len = foot_len

    # -- parts ------------------------------------------------------------------------------------
    def _part(self, table, facing, by):
        rows, x, y = table.get(facing) or table["E"]
        return stamp(rows, self.cmap, x, y + by)

    def legs_front(self, pose, facing):
        cv = layer()
        L, B = self.legs, self.boots
        hip = self.hip_y + pose.by
        for side, x0 in enumerate(self.leg_x):
            bottom = GROUND - pose.lift[side]
            lit, dark = (L[2], L[1]) if side == 0 else (L[1], L[0])
            for y in range(hip, bottom + 1):
                boot = y > bottom - self.boot_rows
                if boot:
                    a, b = (B[2], B[1]) if side == 0 else (B[1], B[0])
                    if y == bottom:          # sole row: darker, toe cap lit on the outer side
                        a, b = (B[1], B[0])
                else:
                    a, b = lit, dark
                cv.px(x0, y, a)
                cv.px(x0 + 1, y, b)
        return cv

    def legs_side(self, pose):
        """Returns (far, near) leg layers for the right-facing view. Each leg is a 2 px line
        from the hip to the boot; striding feet fan out, a lifted (passing) foot is tucked 1 px
        back and raised."""
        L, B = self.legs, self.boots
        hip = self.hip_y + pose.by
        out = []
        for idx, (sign, cols, bcols) in enumerate(((-1, (L[1], L[0]), (B[1], B[0])),
                                                   (1, (L[2], L[1]), (B[2], B[1])))):
            cv = layer()
            lift = pose.lift[idx]
            fx = self.hip_e + sign * pose.stride - (1 if lift else 0)
            fy = GROUND - lift
            ankle = fy - self.boot_rows + 1
            path = pix.poly_points([(self.hip_e, hip), (fx, ankle - 1)])
            for (x, y) in path:
                cv.px(x, y, cols[0])
                cv.px(x + 1, y, cols[1])
            for y in range(ankle, fy):                       # boot shaft
                cv.px(fx, y, bcols[0])
                cv.px(fx + 1, y, bcols[1])
            n = self.foot_len - (1 if lift else 0)          # sole; a lifted foot points down
            for k in range(n):
                cv.px(fx + k, fy, bcols[1] if k < n - 1 else bcols[0])
            out.append(cv)
        return out[0], out[1]

    def leg_x_at(self, pose, near, y):
        """Side view: left column of the near (or far) leg on row y (for knee patches etc.)."""
        idx = 1 if near else 0
        sign = 1 if near else -1
        lift = pose.lift[idx]
        fx = self.hip_e + sign * pose.stride - (1 if lift else 0)
        ankle = GROUND - lift - self.boot_rows + 1
        for (x, yy) in pix.poly_points([(self.hip_e, self.hip_y + pose.by), (fx, ankle - 1)]):
            if yy == y:
                return x
        return fx

    def arm_front(self, arm, delta, by):
        """S/N arm column; delta +1 = one pixel longer (hand forward toward the camera)."""
        cv = layer()
        keys = list(arm.keys)
        if delta > 0:
            keys = keys[:-1] + [keys[-2]] * delta + keys[-1:]
        elif delta < 0:
            keys = keys[:-2 + delta] + keys[-2:] if len(keys) + delta >= 2 else keys[-2:]
        for k, key in enumerate(keys):
            cv.px(arm.x, arm.y + by + k, self.cmap[key])
        return cv

    def arm_side(self, arm, swing, by):
        cv = layer()
        n = len(arm.keys)
        x0, y0 = arm.x, arm.y + by
        pts = pix.poly_points([(x0, y0), (x0, y0 + n // 2 - 1), (x0 + swing, y0 + n - 1)])
        if len(pts) != n:                     # keep exactly one pixel per key
            pts = [(x0 + (swing if k >= n // 2 + 1 else 0), y0 + k) for k in range(n)]
        for (x, y), key in zip(pts, arm.keys):
            cv.px(x, y, self.cmap[key])
        return cv

    # -- frames -----------------------------------------------------------------------------------
    def layers(self, facing, pose):
        by = pose.by
        head = self._part(self.head, facing, by)
        torso = self._part(self.torso, facing, by)
        gear = self.gear(self, facing, pose) if self.gear else {}
        if facing in ("S", "N"):
            left, right = self.arms[facing]
            sgn = 1 if facing == "S" else -1      # forward is toward the camera only when facing S
            arms = [self.arm_front(left, sgn * pose.swing, by),
                    self.arm_front(right, -sgn * pose.swing, by)]
            legs = self.legs_front(pose, facing)
            seq = [("legs", legs, False), ("torso", torso, False)]
            seq += [(n, g, c) for (n, g, c) in gear.get("under", [])]
            seq += [("head", head, False)]
            seq += [("arm", a, False) for a in arms]
            seq += [(n, g, c) for (n, g, c) in gear.get("over", [])]
            return seq
        far_arm, near_arm = self.arms[facing] if facing in self.arms else self.arms["E"]
        far_leg, near_leg = self.legs_side(pose)
        seq = [("far_arm", self.arm_side(far_arm, -pose.swing, by), False),
               ("far_leg", far_leg, False), ("near_leg", near_leg, True),
               ("torso", torso, True)]
        seq += [(n, g, c) for (n, g, c) in gear.get("under", [])]
        seq += [("head", head, True),
                ("near_arm", self.arm_side(near_arm, pose.swing, by), True)]
        seq += [(n, g, c) for (n, g, c) in gear.get("over", [])]
        return seq

    def frame(self, direction, pose, outline=True):
        facing = _D[direction]
        if facing == "W":           # drawn facing right with the "W" parts, then mirrored
            return self._frame("W", pose, outline, side=True).flip_h()
        return self._frame(facing, pose, outline, side=facing == "E")

    def _frame(self, facing, pose, outline, side):
        out = layer()
        for name, cv, cast in self.layers(facing, pose):
            if cast:
                out.over(cv, 0, 0, contour=WARM, strong=0.45)
            else:
                out.blit(cv, 0, 0)
        if outline:
            skip = None
            if not side and self.front_gap:
                skip = self._leg_gap(out, pose)
            pix.outline(out, WARM, local=0.62, skip=skip)
        return out

    def _leg_gap(self, cv, pose):
        """Columns between the two front-view legs below the torso stay see-through."""
        skip = np.zeros((FH, FW), bool)
        x_in = self.leg_x[0] + 2
        x_out = self.leg_x[1]
        if x_out <= x_in:
            return None
        op = cv.a[:, :, 3] == 255
        for y in range(FH):
            if op[y, x_in - 1] and op[y, x_out] and not op[y, x_in:x_out].any():
                skip[y, x_in:x_out] = True
        return skip

    def frames(self):
        out = {}
        for d in DIRS:
            f = _D[d]
            walk = WALK_E if f in ("E", "W") else WALK_SN
            for i, p in enumerate(IDLE):
                out[("idle", d, i)] = self.frame(d, p)
            for i, p in enumerate(walk):
                out[("walk", d, i)] = self.frame(d, p)
        return out


def check_frame(cv, key):
    """Contract shared with the PixelLab NPC frames (see the module docstring)."""
    assert (cv.w, cv.h) == (FW, FH), key
    a = cv.a
    ys, xs = np.nonzero(a[:, :, 3] > 0)
    assert len(xs), f"{key}: empty frame"
    assert ys.max() == GROUND + 1, f"{key}: lowest opaque row {ys.max()} != {GROUND + 1}"
    assert ((a[:, :, 3] == 0) | (a[:, :, 3] == 255)).all(), f"{key}: translucent pixel"
    assert not ((a[:, :, 3] == 255) & (a[:, :, :3].sum(axis=2) == 0)).any(), f"{key}: pure black"
    w = xs.max() - xs.min() + 1
    assert 7 <= w <= 13, f"{key}: width {w}"
    return True
