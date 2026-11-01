extends "res://tests/test_case.gd"
## Unit tests for scripts/menu_screen.gd's pure display/navigation math (the 2026-07-12 in-game
## tabbed menu) — same pure-logic/stateful-shell split as test_title_screen.gd: the statics are
## tested headlessly here; the open/close/gate behavior is driven through the real scene by
## tools/runtime_smoke.gd's menu stages.

const MenuScreen := preload("res://scripts/menu_screen.gd")
const BuildingDB := preload("res://scripts/building_db.gd")


## -- Tab cycling (forward-only ring over the four live tabs) --

func test_next_tab_cycles_forward_and_wraps() -> void:
	var ring := [MenuScreen.TAB_INVENTORY, MenuScreen.TAB_CRAFT, MenuScreen.TAB_SKILLS,
		MenuScreen.TAB_JOURNAL, MenuScreen.TAB_PEOPLE, MenuScreen.TAB_BUILD,
		MenuScreen.TAB_ASSIGNMENTS, MenuScreen.TAB_CONTROLS]
	for i in ring.size():
		assert_eq(MenuScreen.next_tab(ring[i]), ring[(i + 1) % ring.size()],
			"%s -> %s" % [MenuScreen.TAB_NAMES[ring[i]], MenuScreen.TAB_NAMES[ring[(i + 1) % ring.size()]]])


func test_tab_names_cover_exactly_the_real_tabs() -> void:
	# Every tab is a working system (Milestone B added CRAFT, SKILLS, JOURNAL and PEOPLE); no
	# placeholder stubs. INVENTORY became ITEMS so eight names fit the tab bar.
	assert_eq(MenuScreen.TAB_NAMES, ["ITEMS", "CRAFT", "SKILLS", "JOURNAL", "PEOPLE", "BUILD", "SETTLERS", "CONTROLS"])
	assert_eq(MenuScreen.TAB_NAMES[MenuScreen.TAB_CRAFT], "CRAFT")
	assert_eq(MenuScreen.TAB_NAMES[MenuScreen.TAB_JOURNAL], "JOURNAL")
	assert_eq(MenuScreen.TAB_NAMES[MenuScreen.TAB_PEOPLE], "PEOPLE")
	assert_eq(MenuScreen.TAB_NAMES[MenuScreen.TAB_ASSIGNMENTS], "SETTLERS")


func test_tab_names_fit_the_tab_bar() -> void:
	# The pixel font advances 5 px a glyph; the bar is 296 px with 6 px between names.
	var chars := 0
	for name in MenuScreen.TAB_NAMES:
		chars += String(name).length()
	assert_true(chars * 5 + (MenuScreen.TAB_NAMES.size() - 1) * 6 <= 296, "%d chars fit" % chars)


func test_tabs_cycle_both_ways() -> void:
	assert_eq(MenuScreen.next_tab(MenuScreen.TAB_CONTROLS), MenuScreen.TAB_INVENTORY, "wraps forward")
	assert_eq(MenuScreen.prev_tab(MenuScreen.TAB_INVENTORY), MenuScreen.TAB_CONTROLS, "wraps back")
	assert_eq(MenuScreen.prev_tab(MenuScreen.TAB_SKILLS), MenuScreen.TAB_CRAFT)


## -- Build-tab catalog rows (affordability must be BuildGrid.can_afford's verdict) --

func test_catalog_rows_cover_the_whole_catalog_in_order() -> void:
	var rows := MenuScreen.catalog_rows(BuildingDB.ids(), {})
	assert_eq(rows.size(), BuildingDB.ids().size(), "one row per catalog entry")
	assert_eq(String(rows[0]["id"]), "shelter_tent", "catalog order preserved (cabin first)")
	assert_eq(String(rows[1]["id"]), "storage_shed", "catalog order preserved (barn second)")
	# Phase 8 Stage 1: display names renamed (Shelter Tent -> Shelter Cabin, Storage Shed ->
	# Storage Barn) as part of the is_storage -> interaction schema migration; the ids/mechanics
	# are unchanged (see data/buildings.json's own comment).
	assert_eq(String(rows[0]["name"]), "Shelter Cabin")
	assert_eq(String(rows[1]["name"]), "Storage Barn")


func test_catalog_rows_cost_text_matches_builders_placement_label() -> void:
	# The menu reuses builder.gd's own static cost_text() — assert the exact strings the
	# placement preview has always shown, so a drift would fail loudly here.
	var rows := MenuScreen.catalog_rows(BuildingDB.ids(), {})
	assert_eq(String(rows[0]["cost_text"]), "6 Wood")
	assert_eq(String(rows[1]["cost_text"]), "12 Wood, 4 Stone, 2 Scrap Metal")


func test_catalog_rows_affordability_nothing_owned() -> void:
	for row in MenuScreen.catalog_rows(BuildingDB.ids(), {}):
		assert_false(bool(row["affordable"]), "%s unaffordable with an empty inventory" % row["id"])


func test_catalog_rows_affordability_partial_and_exact() -> void:
	# 6 wood: exactly the tent's cost, nowhere near the shed's.
	var rows := MenuScreen.catalog_rows(BuildingDB.ids(), {"wood": 6})
	assert_true(bool(rows[0]["affordable"]), "tent affordable at exactly 6 wood")
	assert_false(bool(rows[1]["affordable"]), "shed still unaffordable on wood alone")
	# The shed's exact cost (Forest Edge's day-1 starting bonus covers it — same numbers).
	rows = MenuScreen.catalog_rows(BuildingDB.ids(), {"wood": 12, "stone": 4, "scrap_metal": 2})
	assert_true(bool(rows[0]["affordable"]), "tent affordable from the shed-cost pile")
	assert_true(bool(rows[1]["affordable"]), "shed affordable at its exact cost")
	# One line short (missing scrap entirely) must fail, matching BuildGrid.can_afford.
	rows = MenuScreen.catalog_rows(BuildingDB.ids(), {"wood": 12, "stone": 4})
	assert_false(bool(rows[1]["affordable"]), "a single missing cost line blocks affordability")


func test_build_row_text_flags_missing_materials_in_text_not_just_color() -> void:
	var affordable := {"id": "shelter_tent", "name": "Shelter Tent", "cost_text": "6 Wood",
		"affordable": true}
	var unaffordable := {"id": "shelter_tent", "name": "Shelter Tent", "cost_text": "6 Wood",
		"affordable": false}
	assert_eq(MenuScreen.build_row_text(affordable), "Shelter Tent — 6 Wood")
	assert_eq(MenuScreen.build_row_text(unaffordable),
		"Shelter Tent — 6 Wood  — missing materials")


## -- Controls tab (hand-maintained list; see CONTROLS_REFERENCE's sync warning) --

func test_controls_reference_actions_all_exist_in_the_input_map() -> void:
	# The strong half (key names matching project.godot) has NO automated sync by design; this
	# guards the weak half — every action the list documents still exists, so a renamed/removed
	# action can't leave a controls line describing nothing.
	for entry in MenuScreen.CONTROLS_REFERENCE:
		for action in entry["actions"]:
			assert_true(InputMap.has_action(String(action)),
				"controls line '%s' references live action '%s'" % [entry["does"], action])


func test_controls_lines_render_one_line_per_entry() -> void:
	var lines := MenuScreen.controls_lines()
	assert_eq(lines.size(), MenuScreen.CONTROLS_REFERENCE.size())
	assert_eq(lines[0], "W/A/S/D, Arrows, L-stick — Move")
	for line in lines:
		assert_true(line.find(" — ") != -1, "every line pairs keys with a description: %s" % line)


func test_controls_list_documents_the_menus_own_keys() -> void:
	# The menu must explain itself: its open/close key, tab cycling, and Esc all appear.
	var joined := " | ".join(MenuScreen.controls_lines())
	assert_true(joined.find("Tab, I, Y — Open/close this menu") != -1, "menu key documented")
	assert_true(joined.find("menu tab") != -1, "Q's tab-cycling role documented")
	assert_true(joined.find("Esc — Close menu") != -1, "Esc close documented")


## -- Save & Return footer (press-again-to-confirm guard) --

func test_quit_hint_armed_and_idle_are_distinct_and_both_name_the_action() -> void:
	var idle := MenuScreen.quit_hint(false)
	var armed := MenuScreen.quit_hint(true)
	assert_ne(idle, armed, "arming visibly changes the footer")
	assert_true(idle.find("Save & Return to Title") != -1)
	assert_true(armed.find("Save & Return to Title") != -1)
	assert_true(armed.find("AGAIN") != -1, "the armed state reads as a confirm prompt")
