extends "res://tests/test_case.gd"
## scripts/player_profile.gd (Milestone E character creation): name filtering and the on-screen
## letter grid, pronouns, appearance normalisation/cycling, the save section's round trip
## (through real JSON text, the way a save file carries it), and the Load row / dialogue token
## that read the name back.

const PlayerProfile := preload("res://scripts/player_profile.gd")
const SaveData := preload("res://scripts/save_data.gd")
const SaveSlots := preload("res://scripts/save_slots.gd")
const TitleScreen := preload("res://scripts/title_screen.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const Opening := preload("res://scripts/opening.gd")

## The UI font's glyphs (tests/test_dialogue_content.gd's FONT_CHARS).
const FONT_CHARS := " !\"'()+,-./0123456789:;?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz–—‘’“”…↑↓←→%♥♡{}"


func after_each() -> void:
	DialogueDB.player_name = ""


## -- Names --

func test_name_chars_are_all_drawable() -> void:
	for i in PlayerProfile.NAME_CHARS.length():
		assert_true(FONT_CHARS.contains(PlayerProfile.NAME_CHARS[i]),
			"'%s' is in the UI font" % PlayerProfile.NAME_CHARS[i])
	for ch in "&#*=<>[]$@_{}":
		assert_false(PlayerProfile.NAME_CHARS.contains(ch), "'%s' is never allowed in a name" % ch)


func test_filter_name_drops_undrawable_characters() -> void:
	assert_eq(PlayerProfile.filter_name("R&o#b*i=n<>[]$@_"), "Robin")
	assert_eq(PlayerProfile.filter_name("Zoë"), "Zo", "letters outside the font are dropped")
	assert_eq(PlayerProfile.filter_name("Mary-Jo O'Neil."), "Mary-Jo O'Ne", "capped at NAME_MAX")


func test_filter_name_caps_length() -> void:
	assert_eq(PlayerProfile.filter_name("ABCDEFGHIJKLMNOP").length(), PlayerProfile.NAME_MAX)
	assert_eq(PlayerProfile.NAME_MAX, 12)


func test_filter_name_spaces() -> void:
	assert_eq(PlayerProfile.filter_name("  Ash"), "Ash", "no leading spaces")
	assert_eq(PlayerProfile.filter_name("Ash   Lee"), "Ash Lee", "no doubled spaces")
	assert_eq(PlayerProfile.filter_name("Ash "), "Ash ", "a trailing space is kept while typing")
	assert_eq(PlayerProfile.finalize_name("Ash "), "Ash", "...and trimmed when stored")
	assert_eq(PlayerProfile.finalize_name("   "), "")


func test_append_and_delete() -> void:
	var n := ""
	for ch in "Robin!":
		n = PlayerProfile.append_to_name(n, ch)
	assert_eq(n, "Robin", "the '!' is filtered out")
	assert_eq(PlayerProfile.delete_last(n), "Robi")
	assert_eq(PlayerProfile.delete_last(""), "", "deleting from nothing is safe")


func test_auto_caps() -> void:
	assert_true(PlayerProfile.auto_caps(""))
	assert_false(PlayerProfile.auto_caps("R"))
	assert_true(PlayerProfile.auto_caps("Mary "))
	assert_true(PlayerProfile.auto_caps("Mary-"))


func test_suggested_and_fallback_names() -> void:
	assert_true(PlayerProfile.SUGGESTED_NAMES.has(PlayerProfile.suggested_name(12345)))
	assert_eq(PlayerProfile.suggested_name(-1), PlayerProfile.SUGGESTED_NAMES[-1], "negative seeds wrap")
	for suggestion in PlayerProfile.SUGGESTED_NAMES:
		assert_eq(PlayerProfile.filter_name(suggestion), suggestion, "%s is a valid name" % suggestion)
	assert_eq(PlayerProfile.name_token(""), "farmer")
	assert_eq(PlayerProfile.name_token("Robin"), "Robin")


## -- Letter grid --

func test_grid_offers_only_name_characters() -> void:
	for caps in [true, false]:
		var rows := PlayerProfile.grid_rows(caps)
		assert_eq((rows[-1] as Array), PlayerProfile.GRID_COMMANDS, "last row is the commands")
		for y in rows.size() - 1:
			for cell in rows[y]:
				assert_eq(String(cell).length(), 1)
				assert_true(PlayerProfile.NAME_CHARS.contains(String(cell)), "grid cell '%s' is allowed" % cell)
				assert_true(FONT_CHARS.contains(String(cell)), "grid cell '%s' is drawable" % cell)
			assert_true((rows[y] as Array).size() <= PlayerProfile.GRID_COLUMNS)


func test_grid_has_every_letter() -> void:
	var rows := PlayerProfile.grid_rows(true)
	var flat := ""
	for y in rows.size() - 1:
		for cell in rows[y]:
			flat += String(cell)
	for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ-'.0123456789":
		assert_true(flat.contains(ch), "'%s' is on the caps grid" % ch)
	assert_eq(String(PlayerProfile.grid_rows(false)[0][0]), "a", "lower case when caps is off")


func test_grid_move_wraps_and_clamps() -> void:
	var rows := PlayerProfile.grid_rows(true)
	var last := rows.size() - 1
	assert_eq(PlayerProfile.grid_move(Vector2i(0, 0), Vector2i(-1, 0), rows), Vector2i(9, 0), "wraps left")
	assert_eq(PlayerProfile.grid_move(Vector2i(9, 0), Vector2i(1, 0), rows), Vector2i(0, 0), "wraps right")
	assert_eq(PlayerProfile.grid_move(Vector2i(0, 0), Vector2i(0, -1), rows), Vector2i(0, last), "wraps up to the commands")
	var onto_commands := PlayerProfile.grid_move(Vector2i(9, last - 1), Vector2i(0, 1), rows)
	assert_eq(onto_commands.y, last)
	assert_true(onto_commands.x < (rows[last] as Array).size(), "column clamps onto the short row")
	assert_eq(onto_commands.x, 3, "the far right letters lead to DONE")
	var back := PlayerProfile.grid_move(Vector2i(3, last), Vector2i(0, -1), rows)
	assert_true(back.x >= 6, "DONE leads back to the right side (got %d)" % back.x)
	# Every reachable position is a real cell
	var cursor := Vector2i.ZERO
	for step in 60:
		cursor = PlayerProfile.grid_move(cursor, [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 1)][step % 3], rows)
		assert_true(cursor.x < (rows[cursor.y] as Array).size(), "cursor %s is on a cell" % cursor)


func test_grid_press() -> void:
	var r := PlayerProfile.grid_press("", "R", null)
	assert_eq(r["name"], "R")
	assert_false(r["done"])
	r = PlayerProfile.grid_press("Ro", PlayerProfile.GRID_SPACE, null)
	assert_eq(r["name"], "Ro ")
	r = PlayerProfile.grid_press("Ro", PlayerProfile.GRID_DELETE, null)
	assert_eq(r["name"], "R")
	r = PlayerProfile.grid_press("Ro", PlayerProfile.GRID_DONE, null)
	assert_true(r["done"])
	assert_eq(r["name"], "Ro")
	r = PlayerProfile.grid_press("Ro", PlayerProfile.GRID_CAPS, null)
	assert_eq(r["caps_override"], true, "CAPS flips the automatic lower case to upper")
	r = PlayerProfile.grid_press("", PlayerProfile.GRID_CAPS, null)
	assert_eq(r["caps_override"], false, "...and the automatic upper case to lower")
	r = PlayerProfile.grid_press("Ro", "B", true)
	assert_eq(r["caps_override"], null, "a typed letter returns to automatic caps")
	r = PlayerProfile.grid_press("ABCDEFGHIJKL", "M", null)
	assert_eq(r["name"], "ABCDEFGHIJKL", "a full name takes no more")


## -- Pronouns --

func test_pronouns() -> void:
	assert_eq(PlayerProfile.normalize_pronouns("she"), "she")
	assert_eq(PlayerProfile.normalize_pronouns("it"), "they", "unknown -> they")
	assert_eq(PlayerProfile.normalize_pronouns(null), "they")
	assert_eq(PlayerProfile.pronoun_tokens("he")["them"], "him")
	assert_eq(PlayerProfile.pronoun_tokens("she")["their"], "her")
	assert_eq(PlayerProfile.pronoun_tokens("they")["them"], "them")
	for p in PlayerProfile.PRONOUNS:
		assert_true(PlayerProfile.PRONOUN_LABELS.has(p))


## -- Appearance --

func test_normalize_appearance() -> void:
	assert_eq(PlayerProfile.normalize_appearance(null), PlayerProfile.default_appearance())
	assert_eq(PlayerProfile.normalize_appearance({"hair": 2.0, "skin": 99, "outfit": "x"}),
		{"preset": 0, "hair": 2, "skin": 0, "outfit": 0}, "floats ints, out of range and junk")
	assert_eq(PlayerProfile.normalize_appearance({"hair": -1}), PlayerProfile.default_appearance())


func test_cycle_wraps() -> void:
	var look := PlayerProfile.default_appearance()
	look = PlayerProfile.cycle(look, "hair", -1)
	assert_eq(int(look["hair"]), PlayerProfile.HAIR_OPTIONS.size() - 1)
	look = PlayerProfile.cycle(look, "hair", 1)
	assert_eq(int(look["hair"]), 0)
	look = PlayerProfile.cycle(look, "outfit", 3)
	assert_eq(int(look["outfit"]), 3)


func test_presets_apply_their_look() -> void:
	for i in PlayerProfile.PRESETS.size():
		var look := PlayerProfile.apply_preset(PlayerProfile.default_appearance(), i)
		assert_eq(int(look["preset"]), i)
		for field in ["hair", "skin", "outfit"]:
			assert_eq(int(look[field]), int(PlayerProfile.PRESETS[i][field]), "preset %d %s" % [i, field])
			assert_true(int(look[field]) < PlayerProfile.options_for(field).size(), "preset %d %s in range" % [i, field])
	var stepped := PlayerProfile.cycle(PlayerProfile.default_appearance(), "preset", 1)
	assert_eq(int(stepped["hair"]), int(PlayerProfile.PRESETS[1]["hair"]), "stepping the preset applies it")
	assert_true(PlayerProfile.PRESETS.size() >= 4, "a handful of presets")


func test_option_names_are_drawable_and_distinct() -> void:
	for field in PlayerProfile.LOOK_FIELDS:
		var seen := {}
		for option in PlayerProfile.options_for(field):
			var n := String(option["name"])
			for i in n.length():
				assert_true(FONT_CHARS.contains(n[i]), "%s option '%s' is drawable" % [field, n])
			assert_false(seen.has(n), "%s option names are distinct" % field)
			seen[n] = true
			if field != "preset":
				assert_eq((option["ramp"] as Array).size(), 3, "%s '%s' ramp is [shade, base, light]" % [field, n])


func test_identity_and_key() -> void:
	assert_true(PlayerProfile.is_identity(PlayerProfile.default_appearance()))
	assert_true(PlayerProfile.is_identity({"preset": 3, "hair": 0, "skin": 0, "outfit": 0}),
		"the preset name alone doesn't change pixels")
	assert_false(PlayerProfile.is_identity({"hair": 1}))
	assert_eq(PlayerProfile.look_key({"preset": 2, "hair": 1, "skin": 2, "outfit": 3}), "1-2-3")


## -- Save section --

func test_profile_round_trips_through_a_save_file() -> void:
	var look := {"preset": 2, "hair": 3, "skin": 1, "outfit": 3}
	var data := SaveData.build_save({"settlement_id": "forest_edge", "day": 4,
		"profile": PlayerProfile.encode_profile("Robin", "she", look)})
	var parsed := SaveData.parse_save(JSON.stringify(data, "\t"))
	assert_false(parsed.is_empty(), "the save parses")
	var profile := PlayerProfile.decode_profile(parsed.get("profile", {}))
	assert_eq(profile["name"], "Robin")
	assert_eq(profile["pronouns"], "she")
	assert_eq(profile["appearance"], look, "JSON floats come back as the same ints")
	assert_true(typeof(profile["appearance"]["hair"]) == TYPE_INT)


func test_old_save_without_profile_gets_defaults() -> void:
	var parsed := SaveData.parse_save(JSON.stringify(
		{"version": SaveData.SAVE_VERSION, "settlement_id": "open_plains", "day": 9}))
	var profile := PlayerProfile.decode_profile(parsed.get("profile", {}))
	assert_eq(profile["name"], "")
	assert_eq(profile["pronouns"], "they")
	assert_eq(profile["appearance"], PlayerProfile.default_appearance())
	assert_eq(PlayerProfile.decode_profile("garbage")["pronouns"], "they", "a malformed section is harmless")


func test_encode_profile_sanitises() -> void:
	var p := PlayerProfile.encode_profile("  Bad#Name&That Is Long ", "zz", {"hair": 500})
	assert_eq(p["name"], "BadNameThat", "filtered, capped, trimmed")
	assert_eq(p["pronouns"], "they")
	assert_eq(int(p["appearance"]["hair"]), 0)


func test_slot_summary_and_row_show_the_name() -> void:
	var data := {"version": SaveData.SAVE_VERSION, "settlement_id": "forest_edge", "day": 12,
		"profile": PlayerProfile.encode_profile("Robin", "they", {})}
	var summary := SaveSlots.summarize(3, data)
	assert_eq(summary["player_name"], "Robin")
	assert_eq(TitleScreen.format_slot_row(summary), "3. Robin — Forest Edge — Day 12")
	var old := SaveSlots.summarize(2, {"settlement_id": "forest_edge", "day": 5})
	assert_eq(old["player_name"], "", "a pre-profile save has no name")
	assert_eq(TitleScreen.format_slot_row(old), "2. Forest Edge — Day 5", "...and keeps the old row")
	assert_eq(SaveSlots.summarize(1, {"settlement_id": "forest_edge", "profile": 7})["player_name"], "",
		"a malformed profile section is harmless")


## -- Text tokens --

func test_dialogue_name_token() -> void:
	DialogueDB.player_name = ""
	assert_eq(DialogueDB.fill("There you are, {name}!", {}), "There you are, farmer!")
	DialogueDB.player_name = "Robin"
	assert_eq(DialogueDB.fill("There you are, {name}!", {}), "There you are, Robin!")
	assert_eq(DialogueDB.fill("{name} and {item}", {"item": "Dustwheat"}), "Robin and Dustwheat")
	assert_eq(DialogueDB.fill("Hi {name}", {"name": "Kit"}), "Hi Kit", "an explicit token wins")


func test_opening_page_text_tokens() -> void:
	var tokens := PlayerProfile.pronoun_tokens("she")
	tokens["name"] = "Robin"
	tokens["settlement"] = "Forest Edge"
	assert_eq(Opening.fill_page_text("{name} of {settlement}: call {them} home.", tokens),
		"Robin of Forest Edge: call her home.")
	for page in Opening.INTRO_PAGES + Opening.MONTAGE_PAGES:
		var text := Opening.fill_page_text(String(page["text"]),
			{"name": "ABCDEFGHIJKL", "settlement": "Forest Edge", "them": "them", "their": "their",
				"they": "they", "child": "baby"})
		assert_false(text.contains("{") or text.contains("}"), "page '%s' has no unknown tokens" % page["art"])
		assert_true(text.length() <= 170, "page '%s' fits three caption lines (%d)" % [page["art"], text.length()])
		for i in text.length():
			assert_true(FONT_CHARS.contains(text[i]), "page '%s' char '%s' is drawable" % [page["art"], text[i]])
		assert_true(ResourceLoader.exists("res://art/opening/%s.png" % page["art"]), "page '%s' has its art" % page["art"])


func test_menu_profile_line() -> void:
	var MenuScreen = load("res://scripts/menu_screen.gd")
	assert_eq(MenuScreen.profile_line("Juniper", "she", "forest_edge"), "Juniper (She / her), farmer of Forest Edge")
	assert_eq(MenuScreen.profile_line("", "they", "open_plains"), "Farmer of Open Plains", "a pre-profile save")
