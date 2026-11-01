#!/usr/bin/env python3
"""Validate the social-system content files against docs/SOCIAL_AND_QUESTS.md.

Checks data/dialogue.json (v2), data/gifts.json, data/requests.json and data/projects.json:

- all four parse as JSON;
- every player-visible string uses only the UI font's glyphs (read from the spec's "Text rule"
  block, with a built-in fallback), uses only the tokens its field supports, and fits its length
  limit both as written and with every token expanded to its longest possible value;
- every item id is real (data/items.json), and giftable where the spec requires it;
- every `when` key/value and world flag is from the spec's tables, `once` lines have unique ids,
  and no line is dead on arrival (e.g. snow outside winter);
- dialogue trees: every next/choice target exists or is a sentinel owned by the right NPC, every
  node is reachable, every NPC has a 2+ choice branch, the four original intro trees keep the ids
  and shapes tools/runtime_smoke.gd drives (and the text the existing tests look for), and the
  service nodes are wired as the spec says;
- content counts meet the spec's targets, and birthdays are spread out with no shared day;
- projects match the spec's table exactly (ids, npc, needs, credits).

Usage:
    python3 tools/validate_social_data.py          # check; exit 0 on success, 1 on any error
    python3 tools/validate_social_data.py --dump   # also print every player-visible line, per NPC
    python3 tools/validate_social_data.py --data DIR   # check copies in DIR instead of data/

Python 3 standard library only. Warnings are printed but never fail the run.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
SPEC = ROOT / "docs" / "SOCIAL_AND_QUESTS.md"

# -- The spec's tables, mirrored here (docs/SOCIAL_AND_QUESTS.md) --

FALLBACK_GLYPHS = (" !\"'()+,-./0123456789:;?ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                   "abcdefghijklmnopqrstuvwxyz–—‘’“”…↑↓←→%♥♡")

NPCS = {  # id: (name, personality) — spec section 1
    "mayor_harlan": ("Mayor Harlan", "Optimistic Builder"),
    "marta": ("Marta", "Pragmatic Trader"),
    "scout_kael": ("Scout Kael", "Paranoid Survivor"),
    "rancher_silas": ("Silas", "Gentle Medic"),
    "brask": ("Brask", "Gruff Soldier"),
    "wren": ("Wren", "Secretive Scavenger"),
    "doc_ama": ("Doc Ama", "Gentle Medic"),
}

PROJECTS = {  # id: (name, npc, needs, credits) — spec section 6, in board order
    "shop_expansion": ("Marta's New Shopfront", "marta",
                       {"wood": 50, "stone": 30, "fiber": 20}, 400),
    "clinic": ("The Clinic Roof", "doc_ama",
               {"wood": 40, "stone": 40, "glass": 6, "cloth_scrap": 10, "copper_wire": 3}, 600),
    "watchtower": ("The West Watchtower", "brask",
                   {"hardwood": 20, "scrap_metal": 40, "metal_bar": 6, "rubber": 4}, 800),
    "greenhouse": ("The Farm Greenhouse", "mayor_harlan",
                   {"wood": 60, "glass": 24, "metal_bar": 10, "circuit_board": 2, "battery": 2}, 1500),
}

SEASONS = ["spring", "summer", "autumn", "winter"]
SEASON_NAMES = ["Spring Rains", "Scorched Summer", "Amber Autumn", "Grey Winter"]
WEATHERS = ["clear", "rain", "storm", "snow", "radstorm"]
# What scripts/weather.gd can actually roll per season (a line asking for anything else never plays).
WEATHER_BY_SEASON = {
    "spring": {"clear", "rain", "storm"},
    "summer": {"clear", "rain", "storm", "radstorm"},
    "autumn": {"clear", "rain", "storm", "radstorm"},
    "winter": {"clear", "snow", "radstorm"},
}
TIMES = ["morning", "afternoon", "evening", "night"]
WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
WEEKDAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
TIER_ORDER = ["stranger", "acquaintance", "friend", "close"]
TIER_MIN_VALUES = ["acquaintance", "friend", "close"]
TIER_MAX_VALUES = ["stranger", "acquaintance", "friend"]
BASE_FLAGS = [
    "first_week", "after_day_28", "expedition_today", "died_recently", "veteran",
    "reached_downtown", "reached_industrial", "reached_core", "raiders_hostile", "raiders_trusted",
    "player_hurt", "player_irradiated", "rich", "has_animals", "has_settlers", "birthday",
]
FLAGS = set(BASE_FLAGS)
FLAGS |= {"project_" + p for p in PROJECTS} | {"project_%s_new" % p for p in PROJECTS}
FLAGS |= {"has_request_" + n for n in NPCS}
WHEN_KEYS = {"season", "weather", "time", "weekday", "tier", "tier_max", "flag", "not_flag"}
LINE_KEYS = {"text", "when", "priority", "once", "id"}

SENTINELS = {  # sentinel: the only NPC whose nodes may use it
    "OPEN_STORE": "marta",
    "OPEN_RANCH_STORE": "rancher_silas",
    "CLINIC_HEAL": "doc_ama",
    "OPEN_CLINIC_STORE": "doc_ama",
}
# Nodes opened directly by code rather than reached from start/service.
EXTRA_ENTRY_NODES = {
    "mayor_harlan": ["day_28_food_shortage"],   # scripts/story_beats.gd, main.gd
    "rancher_silas": ["not_yet"],               # main.gd's OPEN_RANCH_STORE redirect
}
GIFT_KINDS = {  # kind: (min, max) authored lines — spec section 3's gift targets
    "loved": (2, 3), "liked": (2, 3), "neutral": (1, 2), "disliked": (1, 2), "hated": (1, 2),
    "birthday": (1, 1), "birthday_loved": (1, 1),
}
OPTIONAL_GIFT_KINDS = {"already_today"}

GIFTABLE_TYPES = {"crop", "food", "forage", "medicine", "resource"}
NOT_GIFTABLE = {"fertilizer", "quality_fertilizer"}
GIFT_LISTS = ["loved", "liked", "disliked", "hated"]
GIFT_LIST_COUNTS = {"loved": (3, 5), "liked": (5, 8), "disliked": (2, 4), "hated": (1, 3)}
REQUIRED_TASTES = [  # spec section 4, "make it characterful"
    ("doc_ama", "loved", "cleanleaf_kale"), ("doc_ama", "hated", "rotgut"),
    ("brask", "loved", "mystery_jerky"), ("wren", "loved", "circuit_board"),
    ("wren", "loved", "rad_crystal"), ("rancher_silas", "loved", "mutant_goat_milk"),
    ("marta", "loved", "bottle_caps"),
]

POOLS = ["crop", "forage", "material", "salvage", "cooked", "artisan"]
FOOD_POOLS = {"crop", "cooked", "artisan"}
HUNT_ENEMIES = ["shambler", "runner", "bloater", "rad_hound", "any"]
REQUEST_KEYS = {"id", "npc", "kind", "pool", "items", "enemy", "count", "min_day", "min_runs",
                "min_depth", "season", "title", "text", "thanks"}
POOL_ROUTING = {  # pool/kind: NPCs allowed to post it — spec section 5's content target
    "salvage": {"scout_kael", "wren", "brask"},
    "crop": {"marta", "mayor_harlan", "doc_ama"},
    "cooked": {"marta", "mayor_harlan", "doc_ama"},
    "artisan": {"marta", "mayor_harlan", "doc_ama"},
    "material": {"mayor_harlan", "brask"},
    "hunt": {"brask", "scout_kael"},
}

LIMIT_DIALOGUE = 200
LIMIT_TITLE = 24
LIMIT_REQUEST = 180
LIMIT_PROJECT = 220
LIMIT_CHOICE = 40  # the choice list is narrow; a soft limit (warning only)

# Phrases that would treat the founders' child as a newcomer (GDD.md section 3). Errors.
STRANGER_PATTERNS = [
    r"\bnew farmer\b", r"\bnew face\b", r"\bwho are you\b", r"\bnice to meet\b",
    r"\bpleased to meet\b", r"\bmy name is\b", r"\bnewcomer\b", r"\bnew (here|in town|around here)\b",
    r"\bstranger\b", r"\bwelcome to (town|the settlement)\b",
    r"\b(i'm|i am|name's|call me)\s+(mayor\s+)?(harlan|marta|kael|silas|brask|wren|ama|doc)\b",
]
# The player has no gender in the data yet (naming comes in Milestone E). Warnings: review by eye.
GENDERED_PATTERNS = [r"\b(son|daughter|lad|lass|boy|girl|sonny|missy|young man|young lady)\b"]

TOKEN_RE = re.compile(r"\{([A-Za-z_]+)\}")


class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.notes = []

    def error(self, where, msg):
        self.errors.append("%s: %s" % (where, msg))

    def warn(self, where, msg):
        self.warnings.append("%s: %s" % (where, msg))

    def note(self, msg):
        self.notes.append(msg)


def load_json(path, report):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        report.error(path.name, "file is missing")
    except json.JSONDecodeError as e:
        report.error(path.name, "does not parse as JSON: %s" % e)
    return None


def spec_glyphs(report):
    """The glyph set from the spec's 'Text rule' code block, so this stays in sync with it."""
    try:
        text = SPEC.read_text(encoding="utf-8")
        after = text.split("glyphs only:", 1)[1]
        block = after.split("```", 2)[1]
        line = [l for l in block.split("\n") if l.strip()][0]
        if len(line) < 60:
            raise ValueError("glyph line looks truncated")
        return set(line)
    except (OSError, IndexError, ValueError) as e:
        report.warn("SOCIAL_AND_QUESTS.md", "couldn't read the glyph set (%s); using the built-in copy" % e)
        return set(FALLBACK_GLYPHS)


def plural(name):
    """scripts/quest_db.gd's plural rule, for worst-case token lengths."""
    if name.endswith("s"):
        return name
    if name.endswith(("sh", "ch", "x", "o")):
        return name + "es"
    if name.endswith("y") and len(name) > 1 and name[-2] not in "aeiou":
        return name[:-1] + "ies"
    return name + "s"


class TextChecker:
    def __init__(self, report, glyphs, items):
        self.report = report
        self.glyphs = glyphs
        names = [v.get("name", "") for k, v in items.items() if isinstance(v, dict)]
        enemy_names = ["shamblers", "runners", "bloaters", "rad-hounds", "creatures"]
        self.worst = {
            "item": max(len(plural(n)) for n in names + enemy_names),
            "season": max(len(s) for s in SEASON_NAMES),
            "count": 2,
            "due": max(len(d) for d in WEEKDAY_NAMES),
            "npc": max(len(n) for n, _ in NPCS.values()),
        }

    def check(self, where, text, limit, tokens=(), soft_limit=False):
        """Glyphs, tokens, length (raw and worst-case expanded), hygiene and framing."""
        r = self.report
        if not isinstance(text, str) or not text.strip():
            r.error(where, "missing or empty text")
            return
        used = TOKEN_RE.findall(text)
        for tok in used:
            if tok not in tokens:
                r.error(where, "token {%s} isn't filled here (allowed: %s)"
                        % (tok, ", ".join("{%s}" % t for t in tokens) or "none"))
        stripped = TOKEN_RE.sub(lambda m: "" if m.group(1) in tokens else m.group(0), text)
        bad = sorted({c for c in stripped if c not in self.glyphs})
        if bad:
            r.error(where, "characters the UI font can't draw: %s" % " ".join(repr(c) for c in bad))
        expanded = TOKEN_RE.sub(lambda m: "x" * self.worst.get(m.group(1), len(m.group(0))), text)
        for label, value in (("", text), (" with tokens expanded", expanded)):
            if len(value) > limit:
                msg = "%d characters%s (limit %d)" % (len(value), label, limit)
                (r.warn if soft_limit else r.error)(where, msg)
                break
        if text != text.strip() or "  " in text:
            r.warn(where, "stray or doubled spaces")
        low = text.lower().replace("’", "'")
        for pat in STRANGER_PATTERNS:
            if re.search(pat, low):
                r.error(where, "stranger framing (%s): %r" % (pat, text))
        for pat in GENDERED_PATTERNS:
            if re.search(pat, low):
                r.warn(where, "gendered word, check it isn't about the player: %r" % text)


# -- dialogue.json --

def check_when(where, when, npc_id, report):
    if not isinstance(when, dict):
        report.error(where, "when must be an object")
        return
    for key, value in when.items():
        if key not in WHEN_KEYS:
            report.error(where, "unknown when key %r (it would never match)" % key)
            continue
        valid = {"season": SEASONS, "weather": WEATHERS, "time": TIMES, "weekday": WEEKDAYS,
                 "tier": TIER_MIN_VALUES, "tier_max": TIER_MAX_VALUES}.get(key)
        if valid is not None and value not in valid:
            report.error(where, "%s %r is not one of %s" % (key, value, valid))
        if key in ("flag", "not_flag") and value not in FLAGS:
            report.error(where, "%s %r is not a world flag from the spec" % (key, value))
    season, weather = when.get("season"), when.get("weather")
    if season in WEATHER_BY_SEASON and weather in WEATHERS and weather not in WEATHER_BY_SEASON[season]:
        report.error(where, "%s never happens in %s, so this line can't play" % (weather, season))
    if when.get("flag") is not None and when.get("flag") == when.get("not_flag"):
        report.error(where, "flag and not_flag are the same, so this line can't play")
    if "tier" in when and "tier_max" in when and \
            TIER_ORDER.index(when["tier"]) > TIER_ORDER.index(when["tier_max"]):
        report.error(where, "tier is above tier_max, so this line can't play")
    if when.get("flag") == "first_week" and season not in (None, "spring"):
        report.error(where, "first_week is days 1-7 of spring, so this line can't play")
    if when.get("flag") == "has_request_%s" % npc_id or str(when.get("flag", "")).startswith("has_request_"):
        if when.get("flag") != "has_request_%s" % npc_id:
            report.warn(where, "%s talks about another NPC's request" % npc_id)


def walk_nodes(npc_id, entry, report):
    """Targets, sentinels, reachability, branches. Returns the nodes dict."""
    nodes = entry.get("nodes")
    where = "dialogue.%s.nodes" % npc_id
    if not isinstance(nodes, dict) or not nodes:
        report.error(where, "missing nodes")
        return {}
    for node_id, node in nodes.items():
        nw = "%s.%s" % (where, node_id)
        if not isinstance(node, dict):
            report.error(nw, "a node must be an object")
            continue
        extra = set(node) - {"text", "next", "choices"}
        if extra:
            report.error(nw, "unknown node keys %s" % sorted(extra))
        if "next" in node and "choices" in node:
            report.error(nw, "a node has next or choices, not both")
        targets = []
        if "next" in node:
            targets.append(node["next"])
        if "choices" in node:
            choices = node["choices"]
            if not isinstance(choices, list) or len(choices) < 2:
                report.error(nw, "choices must be a list of 2 or more")
                choices = choices if isinstance(choices, list) else []
            for i, choice in enumerate(choices):
                if not isinstance(choice, dict) or "next" not in choice or "text" not in choice:
                    report.error("%s.choices[%d]" % (nw, i), "a choice needs text and next")
                    continue
                if "min_affinity" in choice:
                    report.warn("%s.choices[%d]" % (nw, i), "min_affinity gating isn't in the v2 spec")
                targets.append(choice["next"])
            nexts = [c.get("next") for c in choices if isinstance(c, dict)]
            if len(set(nexts)) != len(nexts):
                report.error(nw, "two choices lead to the same place")
        for t in targets:
            if t in SENTINELS:
                if SENTINELS[t] != npc_id:
                    report.error(nw, "sentinel %s belongs to %s, not %s" % (t, SENTINELS[t], npc_id))
            elif t not in nodes:
                report.error(nw, "next %r is neither a node nor a sentinel" % t)
    start = entry.get("start")
    if start not in nodes:
        report.error("dialogue.%s" % npc_id, "start %r is not a node" % start)
    entries = [start, entry.get("service")] + EXTRA_ENTRY_NODES.get(npc_id, [])
    seen, queue = set(), [e for e in entries if e in nodes]
    while queue:
        nid = queue.pop()
        if nid in seen:
            continue
        seen.add(nid)
        node = nodes[nid]
        nxt = [node.get("next")] + [c.get("next") for c in node.get("choices", []) if isinstance(c, dict)]
        queue.extend(t for t in nxt if t in nodes)
    for nid in nodes:
        if nid not in seen:
            report.error("%s.%s" % (where, nid), "unreachable node (not start, service or a code entry point)")
    if not any(isinstance(n, dict) and len(n.get("choices", [])) >= 2 for n in nodes.values()):
        report.error(where, "no node with 2+ choices (every NPC needs a branch)")
    return nodes


def expect_shape(npc_id, nodes, report, linear=(), branches=(), terminals=()):
    """linear: (node, next); branches: (node, [next per choice]); terminals: node ids."""
    where = "dialogue.%s.nodes" % npc_id
    for nid, nxt in linear:
        node = nodes.get(nid, {})
        if node.get("next") != nxt or "choices" in node:
            report.error("%s.%s" % (where, nid), "intro shape: must be a linear beat to %r" % nxt)
    for nid, nexts in branches:
        got = [c.get("next") for c in nodes.get(nid, {}).get("choices", [])]
        if got != list(nexts):
            report.error("%s.%s" % (where, nid), "intro shape: choices must lead to %s, got %s" % (list(nexts), got))
    for nid in terminals:
        node = nodes.get(nid)
        if node is None or "next" in node or "choices" in node:
            report.error("%s.%s" % (where, nid), "intro shape: must exist and be a terminal line")


def expect_text(npc_id, nodes, nid, needles, report, any_of=False):
    text = str(nodes.get(nid, {}).get("text", ""))
    hits = [n for n in needles if n in text]
    if (any_of and not hits) or (not any_of and len(hits) != len(needles)):
        report.error("dialogue.%s.nodes.%s" % (npc_id, nid),
                     "an existing test needs %s %s in this text" % ("one of" if any_of else "all of", needles))


def check_intro_shapes(nodes_by_npc, report):
    """The trees tools/runtime_smoke.gd and tests/test_story_beats.gd drive by id and text."""
    h = nodes_by_npc.get("mayor_harlan", {})
    expect_shape("mayor_harlan", h, report,
                 linear=[("greet", "founding"), ("founding", "offer"),
                         ("day_28_food_shortage", "day_28_food_shortage_farm")],
                 branches=[("offer", ["offer_yes", "offer_no"])],
                 terminals=["offer_yes", "offer_no", "day_28_food_shortage_farm"])
    expect_text("mayor_harlan", h, "offer_yes", ["Good answer"], report)
    expect_text("mayor_harlan", h, "offer_no", ["useful"], report)
    lower = {k: {"text": str(v.get("text", "")).lower()} for k, v in h.items() if isinstance(v, dict)}
    expect_text("mayor_harlan", lower, "day_28_food_shortage", ["reserve"], report)
    expect_text("mayor_harlan", lower, "day_28_food_shortage_farm", ["farm", "counting"], report)
    m = nodes_by_npc.get("marta", {})
    expect_shape("marta", m, report, linear=[("greet", "stocktake")],
                 branches=[("stocktake", ["OPEN_STORE", "chicken"])], terminals=["chicken"])
    k = nodes_by_npc.get("scout_kael", {})
    expect_shape("scout_kael", k, report, linear=[("greet", "city"), ("city", "ask")],
                 branches=[("ask", ["inside", "danger"])], terminals=["inside", "danger"])
    s = nodes_by_npc.get("rancher_silas", {})
    expect_shape("rancher_silas", s, report, linear=[("greet", "stock"), ("stock", "offer")],
                 branches=[("offer", ["OPEN_RANCH_STORE", "look"])], terminals=["look", "not_yet"])
    expect_text("rancher_silas", s, "not_yet", ["barn", "coop"], report, any_of=True)


def check_services(dialogue, report):
    for npc_id, entry in dialogue.items():
        if npc_id not in NPCS or not isinstance(entry, dict):
            continue
        nodes = entry.get("nodes", {})
        service = entry.get("service")
        where = "dialogue.%s.service" % npc_id
        if npc_id in ("mayor_harlan", "scout_kael", "brask", "wren"):
            if "service" in entry or "service_when" in entry:
                report.error(where, "the spec gives this NPC no service")
            continue
        node = nodes.get(service, {}) if service else {}
        nexts = [c.get("next") for c in node.get("choices", [])]
        if npc_id == "marta":
            if service != "shop" or nexts[:1] != ["OPEN_STORE"]:
                report.error(where, "Marta's service must be shop, choice 0 -> OPEN_STORE")
        elif npc_id == "rancher_silas":
            # The spec names this node `stock`, but `stock` is a linear beat of Silas's intro tree
            # (greet -> stock -> offer), which tools/runtime_smoke.gd drives by id; one node can't
            # be both. The service is its own node, with the spec's wiring: choice 0 -> the store.
            if not service or service == "stock" or nexts[:1] != ["OPEN_RANCH_STORE"]:
                report.error(where, "Silas's service must be its own node, choice 0 -> OPEN_RANCH_STORE")
            else:
                report.note("Silas's service node is %r, not the spec's 'stock' (stock is a linear "
                            "intro beat that tools/runtime_smoke.gd drives into offer)." % service)
            if "service_when" in entry:
                report.error(where, "Silas's service has no condition (main.gd gates the store on a barn/coop)")
        elif npc_id == "doc_ama":
            if service != "clinic" or entry.get("service_when") != {"flag": "project_clinic"}:
                report.error(where, "Doc's service must be clinic with service_when {flag: project_clinic}")
            if nexts[:2] != ["CLINIC_HEAL", "OPEN_CLINIC_STORE"] or len(nexts) < 3:
                report.error(where, "clinic choices must be CLINIC_HEAL, OPEN_CLINIC_STORE, then a goodbye")
            else:
                bye = nodes.get(nexts[2], {})
                if "next" in bye or "choices" in bye:
                    report.error(where, "clinic choice 2 must lead to a terminal goodbye line")
            choices = node.get("choices", [])
            if choices and str(choices[0].get("text", "")).rstrip(".!") != "Patch me up":
                report.warn(where, "the spec words clinic choice 0 'Patch me up'")


def check_dialogue(dialogue, tc, report, stats, seen_ids):
    if not isinstance(dialogue, dict):
        report.error("dialogue.json", "top level must be an object")
        return
    if not isinstance(dialogue.get("_comment"), str):
        report.error("dialogue.json", "keep the top-level _comment")
    ids = set(dialogue) - {"_comment"}
    if ids != set(NPCS):
        report.error("dialogue.json", "NPC ids must be exactly %s (got %s)" % (sorted(NPCS), sorted(ids)))
    nodes_by_npc = {}
    all_texts = {}
    birthdays = {}
    for npc_id in NPCS:
        entry = dialogue.get(npc_id)
        where = "dialogue.%s" % npc_id
        if not isinstance(entry, dict):
            continue
        name, personality = NPCS[npc_id]
        if entry.get("name") != name:
            report.error(where, "name must be %r" % name)
        if entry.get("personality") != personality:
            report.error(where, "personality must be %r" % personality)
        b = entry.get("birthday")
        if not (isinstance(b, dict) and b.get("season") in SEASONS and isinstance(b.get("day"), int)
                and 2 <= b["day"] <= 27):
            report.error(where, "birthday must be {season, day} with day 2-27")
        else:
            birthdays[npc_id] = (b["season"], b["day"])
        known = {"name", "personality", "birthday", "start", "service", "service_when",
                 "lines", "repeat", "gift", "nodes"}
        if set(entry) - known:
            report.error(where, "unknown keys %s" % sorted(set(entry) - known))

        nodes = walk_nodes(npc_id, entry, report)
        nodes_by_npc[npc_id] = nodes
        for nid, node in nodes.items():
            if isinstance(node, dict):
                tc.check("%s.nodes.%s" % (where, nid), node.get("text"), LIMIT_DIALOGUE)
                for i, c in enumerate(node.get("choices", [])):
                    if isinstance(c, dict):
                        tc.check("%s.nodes.%s.choices[%d]" % (where, nid, i), c.get("text"),
                                 LIMIT_CHOICE, soft_limit=True)

        lines = entry.get("lines")
        if not isinstance(lines, list):
            report.error(where, "missing lines")
            lines = []
        s = {"lines": len(lines), "generic": 0, "seasons": set(), "weather": 0, "times": set(),
             "tiers": {"acquaintance": 0, "friend": 0, "close": 0}, "birthday": 0, "flags": 0,
             "project_new": set(), "once": 0}
        for i, line in enumerate(lines):
            lw = "%s.lines[%d]" % (where, i)
            if not isinstance(line, dict):
                report.error(lw, "a line must be an object")
                continue
            if set(line) - LINE_KEYS:
                report.error(lw, "unknown line keys %s" % sorted(set(line) - LINE_KEYS))
            text = line.get("text")
            tc.check(lw, text, LIMIT_DIALOGUE, tokens=("season",))
            if isinstance(text, str):
                if text in all_texts:
                    report.error(lw, "duplicate of %s" % all_texts[text])
                all_texts[text] = lw
            when = line.get("when", {})
            check_when(lw, when, npc_id, report)
            if not isinstance(when, dict):
                when = {}
            prio = line.get("priority", 0)
            if not isinstance(prio, int) or isinstance(prio, bool) or prio < 0:
                report.error(lw, "priority must be a whole number of 0 or more")
                prio = 0
            if "once" in line and line["once"] is not True:
                report.error(lw, "once must be true when present")
            if line.get("once") is True:
                s["once"] += 1
                lid = line.get("id")
                if not isinstance(lid, str) or not lid:
                    report.error(lw, "a once line needs an id")
                elif lid in seen_ids:
                    report.error(lw, "once id %r is already used by %s" % (lid, seen_ids[lid]))
                else:
                    seen_ids[lid] = lw
            elif "id" in line:
                report.warn(lw, "id without once does nothing")
            if not when:
                s["generic"] += 1
            if "season" in when:
                s["seasons"].add(when["season"])
            if "weather" in when:
                s["weather"] += 1
            if "time" in when:
                s["times"].add(when["time"])
            if when.get("tier") in s["tiers"]:
                s["tiers"][when["tier"]] += 1
            if "flag" in when or "not_flag" in when:
                s["flags"] += 1
            if when.get("flag") == "birthday":
                s["birthday"] += 1
                if prio != 10:
                    report.error(lw, "the birthday line plays at priority 10")
            flag = str(when.get("flag", ""))
            if flag.startswith("project_") and flag.endswith("_new"):
                pid = flag[len("project_"):-len("_new")]
                if PROJECTS.get(pid, (None, None))[1] == npc_id:
                    if prio == 5:
                        s["project_new"].add(pid)
                    else:
                        report.error(lw, "the project's own NPC plays %s at priority 5" % flag)
        # Content targets (spec section 3).
        if s["lines"] < 18:
            report.error(where, "%d daily lines (need 18+)" % s["lines"])
        if s["generic"] < 6:
            report.error(where, "%d generic lines (need 6+)" % s["generic"])
        missing = [x for x in SEASONS if x not in s["seasons"]]
        if missing:
            report.error(where, "no line for %s" % ", ".join(missing))
        if s["weather"] < 2:
            report.error(where, "%d weather lines (need a few that suit them)" % s["weather"])
        if len(s["times"]) < 2:
            report.error(where, "lines for %d times of day (need 2-3)" % len(s["times"]))
        for tier, n in s["tiers"].items():
            if n < 2:
                report.error(where, "%d %s lines (need 2)" % (n, tier))
        if s["birthday"] != 1:
            report.error(where, "%d birthday lines (need exactly 1, priority 10)" % s["birthday"])
        for pid, (_, owner, _, _) in PROJECTS.items():
            if owner == npc_id and pid not in s["project_new"]:
                report.error(where, "needs a project_%s_new line at priority 5" % pid)
        repeat = entry.get("repeat")
        if not isinstance(repeat, list) or not 3 <= len(repeat) <= 4:
            report.error(where, "repeat needs 3-4 lines")
            repeat = repeat if isinstance(repeat, list) else []
        for i, text in enumerate(repeat):
            tc.check("%s.repeat[%d]" % (where, i), text, LIMIT_DIALOGUE, tokens=("season",))
            if isinstance(text, str):
                if text in all_texts:
                    report.error("%s.repeat[%d]" % (where, i), "duplicate of %s" % all_texts[text])
                all_texts[text] = "%s.repeat[%d]" % (where, i)
        gift = entry.get("gift")
        if not isinstance(gift, dict):
            report.error(where, "missing gift lines")
            gift = {}
        unknown = set(gift) - set(GIFT_KINDS) - OPTIONAL_GIFT_KINDS
        if unknown:
            report.error(where + ".gift", "unknown kinds %s" % sorted(unknown))
        gift_count = 0
        for kind in list(GIFT_KINDS) + sorted(OPTIONAL_GIFT_KINDS):
            texts = gift.get(kind)
            if texts is None and kind in OPTIONAL_GIFT_KINDS:
                continue
            lo, hi = GIFT_KINDS.get(kind, (1, 3))
            if not isinstance(texts, list) or not lo <= len(texts) <= hi:
                report.error("%s.gift.%s" % (where, kind), "needs %d-%d lines" % (lo, hi))
                texts = texts if isinstance(texts, list) else []
            for i, text in enumerate(texts):
                tc.check("%s.gift.%s[%d]" % (where, kind, i), text, LIMIT_DIALOGUE, tokens=("item",))
                gift_count += 1
        s["gift_lines"] = gift_count
        s["repeat"] = len(repeat)
        stats[npc_id] = s

    check_intro_shapes(nodes_by_npc, report)
    check_services(dialogue, report)
    # Birthdays: no two on the same day, every season used.
    days = {}
    for npc_id, sd in birthdays.items():
        if sd in days:
            report.error("dialogue.%s.birthday" % npc_id, "shares %s %d with %s" % (sd[0], sd[1], days[sd]))
        days[sd] = npc_id
    unused = [x for x in SEASONS if x not in {sd[0] for sd in birthdays.values()}]
    if len(birthdays) == len(NPCS) and unused:
        report.error("dialogue.json", "no birthday in %s (spread them over all four seasons)" % ", ".join(unused))
    stats["_birthdays"] = birthdays


# -- gifts.json --

def giftable(item_id, items):
    item = items.get(item_id)
    return isinstance(item, dict) and item.get("type") in GIFTABLE_TYPES and \
        item_id not in NOT_GIFTABLE and not item.get("legacy", False)


def check_taste_block(where, block, items, report, counts):
    if not isinstance(block, dict):
        report.error(where, "must be an object of lists")
        return {}
    if set(block) - set(GIFT_LISTS):
        report.error(where, "unknown lists %s" % sorted(set(block) - set(GIFT_LISTS)))
    placed = {}
    for lst in GIFT_LISTS:
        ids = block.get(lst, [])
        if not isinstance(ids, list):
            report.error("%s.%s" % (where, lst), "must be a list")
            continue
        if counts:
            lo, hi = GIFT_LIST_COUNTS[lst]
            if not lo <= len(ids) <= hi:
                report.error("%s.%s" % (where, lst), "%d items (need %d-%d)" % (len(ids), lo, hi))
        for item_id in ids:
            if item_id not in items:
                report.error("%s.%s" % (where, lst), "%r is not in data/items.json" % item_id)
            elif not giftable(item_id, items):
                report.error("%s.%s" % (where, lst), "%r is not giftable (type %s)"
                             % (item_id, items[item_id].get("type")))
            if item_id in placed:
                report.error("%s.%s" % (where, lst), "%r is already in %s" % (item_id, placed[item_id]))
            placed[item_id] = lst
    return placed


def check_gifts(gifts, items, report):
    if not isinstance(gifts, dict):
        report.error("gifts.json", "top level must be an object")
        return
    if set(gifts) - {"_comment", "universal", "npcs"}:
        report.error("gifts.json", "unknown keys %s" % sorted(set(gifts) - {"_comment", "universal", "npcs"}))
    universal = check_taste_block("gifts.universal", gifts.get("universal"), items, report, counts=False)
    if universal.get("prewar_relic") != "loved":
        report.warn("gifts.universal", "the spec's example has everyone loving prewar_relic")
    npcs = gifts.get("npcs")
    if not isinstance(npcs, dict) or set(npcs) != set(NPCS):
        report.error("gifts.npcs", "needs exactly the 7 NPC ids")
        npcs = npcs if isinstance(npcs, dict) else {}
    for npc_id in NPCS:
        placed = check_taste_block("gifts.npcs.%s" % npc_id, npcs.get(npc_id, {}), items, report, counts=True)
        for nid, lst, item in REQUIRED_TASTES:
            if nid == npc_id and placed.get(item) != lst:
                report.error("gifts.npcs.%s" % npc_id, "the spec says %s %s %s" % (npc_id, lst, item))


# -- requests.json --

def item_seasons(crops, world_objects):
    """item id -> the seasons it can be grown or foraged in (absent = any season)."""
    out = {}
    for crop in (crops or {}).values():
        if isinstance(crop, dict) and crop.get("yield_item"):
            out.setdefault(crop["yield_item"], set()).update(crop.get("seasons", []))
    objs = (world_objects or {}).get("objects", world_objects or {})
    for obj in objs.values():
        if isinstance(obj, dict) and obj.get("forage_item"):
            season = str(obj.get("spawn_on", "")).replace("forage_", "")
            if season in SEASONS:
                out.setdefault(obj["forage_item"], set()).add(season)
    return out


def check_requests(requests, items, seasons_of, tc, report, stats):
    if not isinstance(requests, dict) or not isinstance(requests.get("templates"), list):
        report.error("requests.json", "needs a templates list")
        return
    if set(requests) - {"_comment", "templates"}:
        report.error("requests.json", "unknown keys %s" % sorted(set(requests) - {"_comment", "templates"}))
    ids = set()
    per_npc = {n: 0 for n in NPCS}
    for i, t in enumerate(requests["templates"]):
        where = "requests[%d]" % i
        if not isinstance(t, dict):
            report.error(where, "a template must be an object")
            continue
        tid = t.get("id")
        where = "requests.%s" % tid
        if not isinstance(tid, str) or not tid:
            report.error("requests[%d]" % i, "missing id")
        elif tid in ids:
            report.error(where, "duplicate id")
        ids.add(tid)
        if set(t) - REQUEST_KEYS:
            report.error(where, "unknown keys %s (the engine would ignore them)" % sorted(set(t) - REQUEST_KEYS))
        npc = t.get("npc")
        if npc not in NPCS:
            report.error(where, "npc %r is not one of the 7" % npc)
        else:
            per_npc[npc] += 1
        kind = t.get("kind")
        count = t.get("count")
        if not (isinstance(count, list) and len(count) == 2 and all(isinstance(c, int) for c in count)
                and 1 <= count[0] <= count[1]):
            report.error(where, "count must be [min, max] with 1 <= min <= max")
        for key in ("min_day", "min_runs", "min_depth"):
            if key in t and (not isinstance(t[key], int) or t[key] < 0):
                report.error(where, "%s must be a whole number of 0 or more" % key)
        if "season" in t and t["season"] not in SEASONS:
            report.error(where, "season %r is not a season" % t["season"])
        route = None
        if kind == "deliver":
            if ("pool" in t) == ("items" in t):
                report.error(where, "a delivery takes a pool or an items list, not both or neither")
            if "enemy" in t:
                report.error(where, "a delivery has no enemy")
            if "pool" in t:
                if t["pool"] not in POOLS:
                    report.error(where, "pool %r is not one of %s" % (t["pool"], POOLS))
                route = t["pool"]
            if "items" in t:
                lst = t["items"]
                if not isinstance(lst, list) or not lst:
                    report.error(where, "items must be a non-empty list of ids")
                    lst = []
                for item_id in lst:
                    item = items.get(item_id)
                    if not isinstance(item, dict):
                        report.error(where, "item %r is not in data/items.json" % item_id)
                    elif item.get("legacy") or item.get("type") == "quest":
                        report.error(where, "item %r can't be delivered (legacy or quest item)" % item_id)
                    gate = seasons_of.get(item_id)
                    if gate and t.get("season") not in gate:
                        report.error(where, "%r only grows in %s; gate the template on that season"
                                     % (item_id, "/".join(sorted(gate))))
        elif kind == "hunt":
            route = "hunt"
            if t.get("enemy") not in HUNT_ENEMIES:
                report.error(where, "enemy %r is not one of %s (never raiders)" % (t.get("enemy"), HUNT_ENEMIES))
            if "pool" in t or "items" in t:
                report.error(where, "a hunt has no pool or items")
        else:
            report.error(where, "kind must be deliver or hunt")
        allowed = POOL_ROUTING.get(route)
        if allowed is not None and npc not in allowed:
            report.error(where, "%s requests go to %s, not %s" % (route, sorted(allowed), npc))
        if route in ("salvage", "hunt") and t.get("min_runs", 0) < 1:
            report.error(where, "%s requests wait for the first expedition (min_runs 1+)" % route)
        title = t.get("title")
        tc.check(where + ".title", title, LIMIT_TITLE)
        text = t.get("text")
        tc.check(where + ".text", text, LIMIT_REQUEST, tokens=("count", "item", "due", "npc"))
        if isinstance(text, str):
            for tok in ("{count}", "{item}", "{due}"):
                if tok not in text:
                    report.error(where + ".text", "needs %s" % tok)
        tc.check(where + ".thanks", t.get("thanks"), LIMIT_REQUEST)
    total = sum(per_npc.values())
    for npc, n in per_npc.items():
        if not 2 <= n <= 4:
            report.error("requests.json", "%s has %d templates (need 2-4)" % (npc, n))
    if not 18 <= total <= 24:
        report.error("requests.json", "%d templates (the target is about 20)" % total)
    stats["_requests"] = per_npc


# -- projects.json --

def check_projects(projects, items, tc, report):
    if not isinstance(projects, dict) or not isinstance(projects.get("projects"), list):
        report.error("projects.json", "needs a projects list")
        return
    if set(projects) - {"_comment", "projects"}:
        report.error("projects.json", "unknown keys %s" % sorted(set(projects) - {"_comment", "projects"}))
    got = [p.get("id") if isinstance(p, dict) else None for p in projects["projects"]]
    if got != list(PROJECTS):
        report.error("projects.json", "projects must be %s, in that order (got %s)" % (list(PROJECTS), got))
    for p in projects["projects"]:
        if not isinstance(p, dict) or p.get("id") not in PROJECTS:
            continue
        pid = p["id"]
        where = "projects.%s" % pid
        name, npc, needs, credits = PROJECTS[pid]
        known = {"id", "name", "npc", "needs", "credits", "summary", "reward", "done"}
        if set(p) - known:
            report.error(where, "unknown keys %s" % sorted(set(p) - known))
        if p.get("npc") != npc:
            report.error(where, "npc must be %r (spec table)" % npc)
        if p.get("needs") != needs:
            report.error(where, "needs must be exactly %s (spec table)" % needs)
        if p.get("credits") != credits or isinstance(p.get("credits"), bool):
            report.error(where, "credits must be exactly %d (spec table)" % credits)
        if p.get("name") != name:
            report.warn(where, "name differs from the spec table's %r" % name)
        for item_id in (p.get("needs") or {}):
            if item_id not in items:
                report.error(where, "needs %r, which is not in data/items.json" % item_id)
        tc.check(where + ".name", p.get("name"), LIMIT_TITLE)
        for field in ("summary", "reward", "done"):
            tc.check("%s.%s" % (where, field), p.get(field), LIMIT_PROJECT)
        sentences = len(re.findall(r"[.!?](?:'|\")?(?=\s|$)", str(p.get("done", ""))))
        if not 2 <= sentences <= 4:
            report.warn(where + ".done", "%d sentences (the spec asks for 2-3)" % sentences)
        if len(re.findall(r"[.!?](?=\s|$)", str(p.get("reward", "")))) > 1:
            report.warn(where + ".reward", "the spec asks for one sentence")


# -- Main --

def dump(dialogue, requests, projects):
    for npc_id in NPCS:
        entry = dialogue.get(npc_id, {})
        print("\n==== %s (%s) ====" % (entry.get("name"), npc_id))
        for nid, node in entry.get("nodes", {}).items():
            print("  [node %s] %s" % (nid, node.get("text")))
            for c in node.get("choices", []):
                print("      > %s -> %s" % (c.get("text"), c.get("next")))
        for line in entry.get("lines", []):
            when = line.get("when", {})
            tag = ", ".join("%s=%s" % kv for kv in when.items()) or "generic"
            if line.get("priority"):
                tag += ", p%d" % line["priority"]
            if line.get("once"):
                tag += ", once"
            print("  (%s) %s" % (tag, line.get("text")))
        for text in entry.get("repeat", []):
            print("  (repeat) %s" % text)
        for kind, texts in entry.get("gift", {}).items():
            for text in texts:
                print("  (gift %s) %s" % (kind, text))
    print("\n==== requests ====")
    for t in requests.get("templates", []):
        print("  [%s / %s] %s\n      %s\n      thanks: %s" % (t.get("npc"), t.get("title"), t.get("id"),
                                                             t.get("text"), t.get("thanks")))
    print("\n==== projects ====")
    for p in projects.get("projects", []):
        print("  [%s] %s\n      %s\n      reward: %s\n      done: %s" % (
            p.get("id"), p.get("name"), p.get("summary"), p.get("reward"), p.get("done")))


def main(argv):
    report = Report()
    data_dir = DATA
    if "--data" in argv and argv.index("--data") + 1 < len(argv):
        data_dir = Path(argv[argv.index("--data") + 1])
    files = {name: load_json(data_dir / ("%s.json" % name), report)
             for name in ("dialogue", "gifts", "requests", "projects", "items", "crops", "world_objects")}
    items = {k: v for k, v in (files["items"] or {}).items() if k != "_comment"}
    if not items:
        report.error("items.json", "can't check item ids without data/items.json")
    tc = TextChecker(report, spec_glyphs(report), items or {"x": {"name": "x" * 20}})
    stats = {}
    if files["dialogue"] is not None:
        check_dialogue(files["dialogue"], tc, report, stats, {})
    if files["gifts"] is not None:
        check_gifts(files["gifts"], items, report)
    if files["requests"] is not None:
        check_requests(files["requests"], items, item_seasons(files["crops"], files["world_objects"]),
                       tc, report, stats)
    if files["projects"] is not None:
        check_projects(files["projects"], items, tc, report)

    if "--dump" in argv and files["dialogue"] and files["requests"] and files["projects"]:
        dump(files["dialogue"], files["requests"], files["projects"])

    print("Social data check (docs/SOCIAL_AND_QUESTS.md)")
    if any(k in stats for k in NPCS):
        print("\n  %-14s %5s %7s %7s %6s %6s %6s %6s %6s" % (
            "npc", "lines", "generic", "flagged", "a/f/c", "repeat", "gifts", "reqs", "bday"))
        for npc_id in NPCS:
            s = stats.get(npc_id)
            if not s:
                continue
            b = stats.get("_birthdays", {}).get(npc_id, ("?", 0))
            print("  %-14s %5d %7d %7d %6s %6d %6d %6s %6s" % (
                npc_id, s["lines"], s["generic"], s["flags"],
                "%d/%d/%d" % (s["tiers"]["acquaintance"], s["tiers"]["friend"], s["tiers"]["close"]),
                s["repeat"], s["gift_lines"], stats.get("_requests", {}).get(npc_id, "-"),
                "%s %d" % (b[0][:3], b[1])))
    for msg in report.notes:
        print("\nNOTE: " + msg)
    if report.warnings:
        print("\n%d warning(s):" % len(report.warnings))
        for w in report.warnings:
            print("  WARN  " + w)
    if report.errors:
        print("\n%d error(s):" % len(report.errors))
        for e in report.errors:
            print("  FAIL  " + e)
        print("\nFAILED")
        return 1
    print("\nPASSED: dialogue, gifts, requests and projects all check out.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
