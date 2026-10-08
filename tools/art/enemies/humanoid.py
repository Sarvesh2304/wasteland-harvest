"""Paper-doll humanoid used by the shambler, runner and raider sheets.

A `Body` holds hand-authored ASCII parts (heads per facing with expression variants, torsos per
facing) plus the colours for the procedural pieces (legs, arms, hands). A `Pose` says where
everything goes in one frame; `Body.frame(facing, pose)` composites the parts back to front
(each part casting a 1 px contour onto what it overlaps) and outlines the silhouette with the
cold ruins outline. `Body.lying()` builds the corpse by rotating the un-outlined front view 90
degrees clockwise: the figure's lit left side becomes its top, so the top-left light survives.
"""
from __future__ import annotations

import numpy as np

import palette as P
from enemies import pix, rig
from enemies.pix import Canvas, mix, rgba


class Arm:
    """Arm polyline in frame coordinates (shoulder first). `sleeve`: pixels of sleeve colour
    from the shoulder; the last pixel is the hand. `claw`: splayed finger pixels past the hand
    (None = the Body's default). `item`: optional callable(cv, hx, hy, dx, dy) drawn after."""

    def __init__(self, pts, sleeve=1, claw=None, item=None, hand=True, colors=None):
        self.pts = pts
        self.sleeve = sleeve
        self.claw = claw
        self.item = item
        self.hand = hand
        self.colors = colors


class Pose:
    """One frame's posture. Offsets in pixels, +y is down."""

    def __init__(self, **kw):
        self.bx = 0          # upper body x shift (sway / lunge)
        self.by = 0          # upper body y shift (bob; + = lower)
        self.hx = 0          # head offset relative to the torso
        self.hy = 0
        self.head = "n"      # head variant key
        self.torso = None    # optional torso variant key (Body.torso_* dicts)
        self.legs = (0, 0)   # S/N: lift of (left, right) foot. E: (far, near)
        self.stride = 0      # E: + puts the near foot forward
        self.lean = 0        # E: head pushed forward
        self.kneel = False   # S/N: kneeling (death)
        self.spread = 0      # S/N: feet pushed apart (lying corpse)
        self.arms = []       # S/N: any order (front of torso). E: [far, near]
        self.__dict__.update(kw)


class Body:
    def __init__(self, cmap, head_s, head_n, head_e, torso_s, torso_n, torso_e, head_s_at,
                 head_e_at, torso_s_at, torso_e_at, legs, shoe, shin=None, leg_x=(10, 13),
                 hip_e=10, hip_y=16, sleeve=None, sleeve_dark=None, skin=None, claw=False,
                 arms_behind_s=False, leg_w=2, wrap=None):
        self.cmap = cmap
        self.head = {"S": head_s, "N": head_n, "E": head_e}
        self.torso = {"S": torso_s, "N": torso_n, "E": torso_e}
        self.head_at = {"S": head_s_at, "N": head_s_at, "E": head_e_at}
        self.torso_at = {"S": torso_s_at, "N": torso_s_at, "E": torso_e_at}
        self.legc = legs              # ramp dark -> light (>= 3)
        self.shoe = shoe              # (dark, light)
        self.shin = shin              # (lit, dark) bare shin through a torn trouser leg, or None
        self.leg_x = leg_x
        self.hip_e = hip_e
        self.hip_y = hip_y
        self.sleeve = sleeve
        self.sleeve_dark = sleeve_dark or sleeve
        self.skin = skin              # (shade, base, light)
        self.claw = claw
        self.arms_behind_s = arms_behind_s
        self.leg_w = leg_w
        self.wrap = wrap              # optional wrist-wrap colour (pixel before the hand)

    # -- parts ----------------------------------------------------------------------------------
    def _torso_rows(self, facing, pose):
        t = self.torso[facing]
        if isinstance(t, dict):
            return t[pose.torso or "n"]
        return t

    def legs_sn(self, pose, facing):
        cv = rig.layer()
        L = self.legc
        hip = self.hip_y + pose.by
        if pose.kneel:
            # kneeling, seen front/back: knees poke out under the hem, shins folded away
            for side, x0 in enumerate(self.leg_x):
                xo = x0 + (-1 if side == 0 else 1)
                for (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1)):
                    c = L[2] if (dx == 0 and side == 0) or dy == 0 else L[1]
                    cv.px(xo + dx, rig.GROUND - 1 + dy, c)
            return cv
        for side, x0 in enumerate(self.leg_x):
            lift = pose.legs[side]
            bottom = rig.GROUND - lift
            top_x = x0 + pose.bx
            foot_x = x0 + (pose.spread if side == 1 else -pose.spread)
            for y in range(hip, bottom + 1):
                t = (y - hip) / max(1, bottom - hip)
                x = int(round(top_x + (foot_x - top_x) * t))
                lit, dark = (L[2], L[1]) if side == 0 else (L[1], L[0])
                if y == bottom:
                    lit, dark = self.shoe[1], self.shoe[0]
                elif self.shin and facing == "S" and side == 0 and y == bottom - 1:
                    lit, dark = self.shin
                cv.px(x, y, lit)
                if self.leg_w > 1:
                    cv.px(x + 1, y, dark)
        return cv

    def legs_e(self, pose):
        """Side-view legs: returns (far, near) layers. Near leg lit, far leg shaded."""
        L = self.legc
        far = rig.layer()
        near = rig.layer()
        hip_y = self.hip_y + pose.by
        hx = self.hip_e + pose.bx
        s = pose.stride
        for cv, sign, cols, lift in ((far, -1, (L[1], L[0]), pose.legs[0]),
                                    (near, 1, (L[2], L[1]), pose.legs[1])):
            foot_x = hx + sign * s + (1 if lift else 0)
            foot_y = rig.GROUND - lift
            knee_y = hip_y + max(1, (foot_y - hip_y) // 2)
            knee_x = hx + (sign * s) // 2 + (1 if lift else 0)
            pts = [(hx, hip_y), (knee_x, knee_y), (foot_x, foot_y - 1)]
            rig.limb(cv, pts, list(cols), width=self.leg_w, horizontal=False)
            cv.px(foot_x, foot_y, self.shoe[0])
            cv.px(foot_x + 1, foot_y, self.shoe[0])
            cv.px(foot_x + 2, foot_y, self.shoe[1])
        return far, near

    def draw_arm(self, cv, arm):
        path = pix.poly_points(arm.pts)
        shade, base, light = arm.colors or self.skin
        for k, (x, y) in enumerate(path):
            if k < arm.sleeve:
                c = self.sleeve if k == 0 else self.sleeve_dark
            elif k == len(path) - 1 and arm.hand:
                c = light
            elif self.wrap is not None and k == len(path) - 2 and len(path) >= 4:
                c = self.wrap
            else:
                c = base
            cv.px(x, y, c)
        hx, hy = path[-1]
        if len(path) > 1:
            px_, py_ = path[-2]
        else:
            px_, py_ = hx, hy - 1
        dx, dy = hx - px_, hy - py_
        claw = self.claw if arm.claw is None else arm.claw
        if claw:
            if abs(dx) >= abs(dy):
                s = 1 if dx >= 0 else -1
                cv.px(hx + s, hy, shade)
                cv.px(hx + s, hy + 1, mix(shade, pix.COLD, 0.35))
            else:
                s = 1 if dy >= 0 else -1
                cv.px(hx - 1, hy + s, shade)
                cv.px(hx + 1, hy + s, mix(shade, pix.COLD, 0.35))
        if arm.item:
            arm.item(cv, hx, hy, dx, dy)
        return cv

    def arms_layer(self, arms):
        cv = rig.layer()
        for a in arms:
            self.draw_arm(cv, a)
        return cv

    # -- frames ---------------------------------------------------------------------------------
    def layers(self, facing, pose):
        bx, by = pose.bx, pose.by
        hx0, hy0 = self.head_at[facing]
        tx0, ty0 = self.torso_at[facing]
        head = rig.stamp(self.head[facing][pose.head], self.cmap,
                         hx0 + bx + pose.hx + (pose.lean if facing == "E" else 0), hy0 + by + pose.hy)
        torso = rig.stamp(self._torso_rows(facing, pose), self.cmap, tx0 + bx, ty0 + by)
        if facing == "S":
            legs = self.legs_sn(pose, "S")
            arms = self.arms_layer(pose.arms)
            if self.arms_behind_s:
                return [arms, legs, torso, head]
            return [legs, torso, head, arms]
        if facing == "N":
            legs = self.legs_sn(pose, "N")
            arms = self.arms_layer(pose.arms)
            return [arms, legs, torso, head]
        far_leg, near_leg = self.legs_e(pose)
        arms = list(pose.arms)
        far_arm = self.arms_layer(arms[:1])
        near_arm = self.arms_layer(arms[1:])
        return [far_arm, far_leg, near_leg, torso, head, near_arm]

    def frame(self, facing, pose, outline=True):
        if facing == "W":
            return self.frame("E", pose, outline).flip_h()
        return rig.compose(self.layers(facing, pose), outline=outline)

    def lying(self, pose, lift=0, dx=0, pool=None, extra=None):
        """Corpse / toppling body: the front view rotated 90 deg clockwise (head to the right),
        resting on the ground row (raised by `lift`). `pool` = (cx, cy, rx, ry) blood pool
        drawn under it; `extra(cv)` may add details before outlining."""
        body = rig.compose(self.layers("S", pose), outline=False)
        rot = Canvas.from_array(np.ascontiguousarray(np.rot90(body.a, k=-1)))
        x0, y0, x1, y1 = pix.bbox(rot)
        w = x1 - x0 + 1
        sx = (rig.FW - w) // 2 - x0 + dx
        sy = (rig.GROUND - lift) - y1
        lay = rig.layer()
        lay.blit(rot, sx, sy)
        if extra:
            extra(lay)
        pix.outline(lay, pix.COLD, local=0.72)
        out = rig.layer()
        if pool:
            if pool is True:
                bx0, by0, bx1, by1 = pix.bbox(lay)
                pool = (bx1 - 4.0, by1 - 0.5, 4.6, 2.2)
            blood_pool(out, *pool)
        out.blit(lay, 0, 0)
        return out


def blood_pool(cv, cx, cy, rx, ry, colors=None, seed=3):
    """Flat ground pool: dark core, slightly lighter wet rim highlight on the top-left."""
    dark, mid = colors or (rgba(P.GORE_DARK), rgba(P.BLOOD[0]))
    r = pix.rng(seed)
    for y in range(cv.h):
        for x in range(cv.w):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            wob = 1.0 + 0.18 * ((x * 7 + y * 13 + seed) % 5 - 2) / 2
            if d <= wob:
                c = mid if d > 0.45 else dark
                if d > 0.45 and (x + 0.5 < cx - rx * 0.3) and y + 0.5 < cy:
                    c = mix(mid, P.BLOOD[1], 0.4)
                cv.px(x, y, c)
    return cv
