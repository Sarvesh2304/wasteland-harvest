extends RefCounted
## Who the player is (Milestone E, GDD.md §3 "The birth/intro sequence"): the name the parents
## gave them, their pronouns, and their look. Pure static data + rules — no nodes, no file I/O —
## so all of it is headlessly unit-tested (tests/test_player_profile.gd), the same split
## save_data.gd / farm_grid.gd use. The live values sit on the GameState autoload
## (player_name / player_pronouns / player_appearance); this file only knows what valid values
## look like and how they serialise.
##
## ## Names
## The UI font only draws the glyphs listed in tests/test_dialogue_content.gd's FONT_CHARS, and
## the name shows up inside dialogue, on the Load screen and in the menu, so a name is limited to
## NAME_CHARS (letters, digits, space, hyphen, apostrophe, full stop) and NAME_MAX characters —
## short enough for a dialogue line and a Load row. filter_name() is applied to every keystroke
## and every letter-grid press, so an undrawable character can never get in.
##
## ## Appearance (moderate customisation, per GDD §3: presets + cosmetic tweaks, NOT modular)
## {"preset": int, "hair": int, "skin": int, "outfit": int} — indices into PRESETS and the three
## option lists below. Index 0 of each option list is the sprite exactly as PixelLab drew it, so
## the default look costs nothing. scripts/player_look.gd turns a look into recoloured frames.
## Every list's ramp is [shade, base, light]; the same hex values are mirrored in the
## "Character creation" block of tools/art/palette.py (the intro art paints the parents with
## them).
##
## ## Save section (additive, no SAVE_VERSION bump — same rule as "story_flags"/"affinity")
##   "profile": {"name": "Robin", "pronouns": "they",
##               "appearance": {"preset": 0, "hair": 2, "skin": 1, "outfit": 3}}
## A save from before Milestone E has no "profile": decode_profile() gives the defaults (no name,
## they/them, the default look), and NPC lines fall back to calling the player "farmer".

const NAME_MAX := 12
## Every character a name may contain (all drawable by the UI font).
const NAME_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -'."
## What NPC lines say for {name} when a save has no name (pre-Milestone-E saves).
const FALLBACK_NAME := "farmer"
## Offered when the player confirms an empty name (the parents always pick something).
const SUGGESTED_NAMES: Array[String] = ["Robin", "Ash", "Wren", "Sage", "Rowan", "Ellis",
	"Juniper", "Avery", "Hollis", "Marlo", "Kit", "Remy"]

## The on-screen letter grid (controller-friendly name entry). Upper/lower case is a toggle:
## GRID_LETTERS is shown upper-cased while caps is on. Every character here is in NAME_CHARS.
const GRID_COLUMNS := 10
const GRID_LETTERS := "abcdefghijklmnopqrstuvwxyz-'.0123456789"
## The command row under the letters.
const GRID_CAPS := "CAPS"
const GRID_SPACE := "SPACE"
const GRID_DELETE := "DEL"
const GRID_DONE := "DONE"
const GRID_COMMANDS: Array[String] = [GRID_CAPS, GRID_SPACE, GRID_DELETE, GRID_DONE]

const PRONOUNS: Array[String] = ["he", "she", "they"]
const DEFAULT_PRONOUNS := "they"
const PRONOUN_LABELS := {"he": "He / him", "she": "She / her", "they": "They / them"}
## Pronoun forms for intro/montage text tokens ({they} {them} {their} {child}).
const PRONOUN_FORMS := {
	"he": {"they": "he", "them": "him", "their": "his", "child": "boy"},
	"she": {"they": "she", "them": "her", "their": "her", "child": "girl"},
	"they": {"they": "they", "them": "them", "their": "their", "child": "baby"},
}

## Cosmetic options: {"name", "ramp": [shade, base, light]}. Index 0 = as drawn (identity).
const HAIR_OPTIONS: Array[Dictionary] = [
	{"name": "Chestnut", "ramp": ["#321816", "#3f211c", "#4e2e25"]},
	{"name": "Ink", "ramp": ["#141012", "#1d1613", "#2d231e"]},
	{"name": "Auburn", "ramp": ["#4a1c12", "#76301c", "#a24526"]},
	{"name": "Ginger", "ramp": ["#8a4a22", "#b06a34", "#cc8a4e"]},
	{"name": "Straw", "ramp": ["#7a6238", "#a0844c", "#c2a868"]},
	{"name": "Ash grey", "ramp": ["#5f5b55", "#827d75", "#a6a197"]},
	{"name": "Plum dye", "ramp": ["#3f2431", "#573443", "#704657"]},
]
const SKIN_OPTIONS: Array[Dictionary] = [
	{"name": "Peach", "ramp": ["#d0886d", "#ffbe99", "#ffd1b3"]},
	{"name": "Fair", "ramp": ["#cf8a72", "#eaab92", "#f8c9b0"]},
	{"name": "Tan", "ramp": ["#b47552", "#cf9370", "#e4b08c"]},
	{"name": "Bronze", "ramp": ["#8c5534", "#ad6e45", "#c98b5c"]},
	{"name": "Brown", "ramp": ["#7a4a31", "#9a6242", "#b67d57"]},
	{"name": "Deep", "ramp": ["#4a2c1c", "#6b3f27", "#8c5534"]},
]
const OUTFIT_OPTIONS: Array[Dictionary] = [
	{"name": "Duster tan", "ramp": ["#774727", "#ae6d35", "#dc8340"]},
	{"name": "Olive", "ramp": ["#4a5131", "#6a7444", "#8d9660"]},
	{"name": "Rust red", "ramp": ["#7e2a1e", "#a83a26", "#c4583a"]},
	{"name": "Slate blue", "ramp": ["#293646", "#3a4c60", "#6b8294"]},
	{"name": "Plum", "ramp": ["#3f2431", "#573443", "#8a5c6c"]},
	{"name": "Teal", "ramp": ["#2f5452", "#43726c", "#84b3a4"]},
	{"name": "Charcoal", "ramp": ["#2f2b28", "#423d38", "#6e665c"]},
	{"name": "Canvas", "ramp": ["#7e7252", "#a39470", "#ddd0a8"]},
]

## Base presets: a named starting look each (hair / skin / outfit indices). Choosing a preset
## sets all three; the cosmetic rows then tweak from there (and the preset row keeps its name —
## the tweaks are "your" version of it).
const PRESETS: Array[Dictionary] = [
	{"name": "Farmhand", "hair": 0, "skin": 0, "outfit": 0},
	{"name": "Scavenger", "hair": 1, "skin": 3, "outfit": 6},
	{"name": "Tinker", "hair": 3, "skin": 1, "outfit": 3},
	{"name": "Drifter", "hair": 4, "skin": 2, "outfit": 1},
	{"name": "Medic", "hair": 2, "skin": 4, "outfit": 7},
	{"name": "Firebrand", "hair": 6, "skin": 5, "outfit": 2},
]

## The appearance fields, in creation-screen order.
const LOOK_FIELDS: Array[String] = ["preset", "hair", "skin", "outfit"]


## -- Names --

## Keeps only drawable characters, never starts with or doubles a space, and caps the length.
## (Trailing spaces are kept while typing — finalize_name() trims them.)
static func filter_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var ch := raw[i]
		if not NAME_CHARS.contains(ch):
			continue
		if ch == " " and (out == "" or out.ends_with(" ")):
			continue
		if out.length() >= NAME_MAX:
			break
		out += ch
	return out


## The name as stored: filtered and trimmed. Empty stays empty (the caller decides the default).
static func finalize_name(raw: String) -> String:
	return filter_name(raw).strip_edges()


## Appends typed/picked text to a name being edited, through the same filter.
static func append_to_name(current: String, text: String) -> String:
	return filter_name(current + text)


static func delete_last(current: String) -> String:
	return current.substr(0, maxi(current.length() - 1, 0))


## A deterministic suggestion (shown as the placeholder; used if the player confirms nothing).
static func suggested_name(seed_value: int) -> String:
	return SUGGESTED_NAMES[posmod(seed_value, SUGGESTED_NAMES.size())]


## What dialogue says for {name}.
static func name_token(name: String) -> String:
	return name if name != "" else FALLBACK_NAME


## Caps automatically at the start of the name and after a space or hyphen, so a controller
## player gets "Mary-Jo Rae" without touching CAPS (the toggle flips the automatic choice).
static func auto_caps(current: String) -> bool:
	return current == "" or current.ends_with(" ") or current.ends_with("-")


## -- Letter grid (pure layout + navigation math) --

## Rows of cells: the letters in rows of GRID_COLUMNS, then the command row.
static func grid_rows(caps: bool) -> Array:
	var rows: Array = []
	var row: Array[String] = []
	for i in GRID_LETTERS.length():
		var ch := GRID_LETTERS[i]
		row.append(ch.to_upper() if caps else ch)
		if row.size() == GRID_COLUMNS:
			rows.append(row)
			row = []
	if not row.is_empty():
		rows.append(row)
	var commands: Array[String] = []
	commands.assign(GRID_COMMANDS)
	rows.append(commands)
	return rows


## Moves the grid cursor (row, col) by (dx, dy), wrapping both ways; moving onto a shorter row
## clamps the column, so the cursor never lands on an empty cell.
static func grid_move(cursor: Vector2i, delta: Vector2i, rows: Array) -> Vector2i:
	var y := posmod(cursor.y + delta.y, rows.size())
	var width: int = (rows[y] as Array).size()
	var x := cursor.x
	if delta.x != 0:
		x = posmod(cursor.x + delta.x, width)
	else:
		# Vertical moves between rows of different widths keep the relative position (the
		# 4-wide command row maps each command to a band of letter columns and back).
		var from_width: int = (rows[cursor.y] as Array).size()
		if from_width != width:
			x = clampi(int(float(cursor.x) * width / from_width), 0, width - 1)
		x = mini(x, width - 1)
	return Vector2i(x, y)


## Applies one grid press to the name being edited. Returns {"name", "caps_override", "done"}.
## `caps_override`: null = follow auto_caps, true/false = the player's explicit CAPS toggle,
## which lasts until the next character goes in.
static func grid_press(current: String, cell: String, caps_override) -> Dictionary:
	var result := {"name": current, "caps_override": caps_override, "done": false}
	match cell:
		GRID_CAPS:
			var caps_now: bool = auto_caps(current) if caps_override == null else bool(caps_override)
			result["caps_override"] = not caps_now
		GRID_SPACE:
			result["name"] = append_to_name(current, " ")
			result["caps_override"] = null
		GRID_DELETE:
			result["name"] = delete_last(current)
			result["caps_override"] = null
		GRID_DONE:
			result["done"] = true
		_:
			result["name"] = append_to_name(current, cell)
			result["caps_override"] = null
	return result


## -- Pronouns --

static func normalize_pronouns(value) -> String:
	var p := String(value) if value != null else ""
	return p if PRONOUNS.has(p) else DEFAULT_PRONOUNS


static func pronoun_tokens(pronouns: String) -> Dictionary:
	return (PRONOUN_FORMS[normalize_pronouns(pronouns)] as Dictionary).duplicate()


## -- Appearance --

static func default_appearance() -> Dictionary:
	return {"preset": 0, "hair": 0, "skin": 0, "outfit": 0}


static func options_for(field: String) -> Array[Dictionary]:
	match field:
		"preset":
			return PRESETS
		"hair":
			return HAIR_OPTIONS
		"skin":
			return SKIN_OPTIONS
		"outfit":
			return OUTFIT_OPTIONS
	return []


## Any dictionary (a save from disk, a half-built look) -> a valid look: every field present,
## an int, and in range (out-of-range or garbage falls back to 0, never an error).
static func normalize_appearance(raw) -> Dictionary:
	var out := default_appearance()
	if not (raw is Dictionary):
		return out
	for field in LOOK_FIELDS:
		var value = (raw as Dictionary).get(field, 0)
		var index := int(value) if (value is int or value is float) else 0
		out[field] = index if index >= 0 and index < options_for(field).size() else 0
	return out


## Applies a preset: its hair/skin/outfit replace the current ones.
static func apply_preset(look: Dictionary, preset_index: int) -> Dictionary:
	var out := normalize_appearance(look)
	var index := posmod(preset_index, PRESETS.size())
	out["preset"] = index
	for field in ["hair", "skin", "outfit"]:
		out[field] = int(PRESETS[index][field])
	return out


## Steps one field's option by delta (wrapping). Stepping the preset applies it.
static func cycle(look: Dictionary, field: String, delta: int) -> Dictionary:
	var out := normalize_appearance(look)
	var count := options_for(field).size()
	if count == 0:
		return out
	var next := posmod(int(out[field]) + delta, count)
	if field == "preset":
		return apply_preset(out, next)
	out[field] = next
	return out


static func option_name(field: String, index: int) -> String:
	var options := options_for(field)
	if index < 0 or index >= options.size():
		return ""
	return String(options[index]["name"])


## True when the look draws the sprite exactly as authored (no recolour work needed).
static func is_identity(look: Dictionary) -> bool:
	var l := normalize_appearance(look)
	return int(l["hair"]) == 0 and int(l["skin"]) == 0 and int(l["outfit"]) == 0


## A stable cache key for a look's recoloured frames (the preset name doesn't change pixels).
static func look_key(look: Dictionary) -> String:
	var l := normalize_appearance(look)
	return "%d-%d-%d" % [int(l["hair"]), int(l["skin"]), int(l["outfit"])]


## -- Save section --

static func encode_profile(name: String, pronouns: String, appearance: Dictionary) -> Dictionary:
	return {
		"name": finalize_name(name),
		"pronouns": normalize_pronouns(pronouns),
		"appearance": normalize_appearance(appearance),
	}


static func decode_profile(data) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	return encode_profile(String(d.get("name", "")), String(d.get("pronouns", DEFAULT_PRONOUNS)),
		d.get("appearance", {}))
