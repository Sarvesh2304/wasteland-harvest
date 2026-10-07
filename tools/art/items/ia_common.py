"""Shared bits for the item-art modules: the private colors import, repo paths, data loading and
crop colour ramps derived from data/crops.json."""
from __future__ import annotations

import importlib.util
import json
import pathlib
import sys

import ia_lib as L
from ia_lib import Ramp

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent.parent

# colors.py has a generic name; load it under a private module name so a same-named module from
# another art pipeline (loaded into the same interpreter by tools/art/build_all.py) can't shadow it.
_C_KEY = "wh_items_colors"
if _C_KEY not in sys.modules:
    _spec = importlib.util.spec_from_file_location(_C_KEY, HERE / "colors.py")
    _mod = importlib.util.module_from_spec(_spec)
    sys.modules[_C_KEY] = _mod
    _spec.loader.exec_module(_mod)
C = sys.modules[_C_KEY]


def load_json(rel):
    with open(REPO / rel, "r", encoding="utf-8") as fh:
        return json.load(fh)


ITEMS = {k: v for k, v in load_json("data/items.json").items() if not k.startswith("_")}
CROPS = {k: v for k, v in load_json("data/crops.json").items() if not k.startswith("_")}


def crop_colors(crop_id):
    return CROPS[crop_id]["colors"]


def ramp(base, n=5, **kw) -> Ramp:
    return L.auto_ramp(base, n, **kw)


def crop_ramp(crop_id, which=0, n=5, **kw) -> Ramp:
    return L.auto_ramp(crop_colors(crop_id)[which], n, **kw)


def R(cols, outline=None) -> Ramp:
    return Ramp(cols, outline)
