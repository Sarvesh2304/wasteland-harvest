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
		MenuScreen.TAB_ASSIGNMENTS, MenuScreen.TAB_OPTIONS]
	for i in ring.size():
		assert_eq(MenuScreen.next_tab(ring[i]), ring[(i + 1) % ring.size()],
			"%s -> %s" % [MenuScreen.TAB_NAMES[ring[i]], MenuScreen.TAB_NAMES[ring[(i + 1) % ring.size()]]])


func test_tab_names_cover_exactly_the_real_tabs() -> void:
	# Every tab is a working system (Milestone B added CRAFT, SKILLS, JOURNAL and PEOPLE); no
	# placeholder stubs. INVENTORY became ITEMS so eight names fit the tab bar.
	assert_eq(MenuScreen.TAB_NAMES, ["ITEMS", "CRAFT", "SKILLS", "JOURNAL", "PEOPLE", "BUILD", "SETTLERS", "OPTIONS"])
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
	assert_eq(MenuScreen.next_tab(MenuScreen.TAB_OPTIONS), MenuScreen.TAB_INVENTORY, "wraps forward")
	assert_eq(MenuScreen.prev_tab(MenuScreen.TAB_INVENTORY), MenuScreen.TAB_OPTIONS, "wraps back")
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


## -- OPTIONS tab (Milestone E part 2: the shared options screen replaced the hand-kept list) --

func test_options_tab_names_the_options_screen() -> void:
	assert_eq(MenuScreen.TAB_NAMES[MenuScreen.TAB_OPTIONS], "OPTIONS")


func test_hint_text_names_the_device_in_use() -> void:
	var keys := MenuScreen.hint_text(false)
	var pad := MenuScreen.hint_text(true)
	assert_true(keys.contains("Tab") and keys.contains("Esc"), keys)
	assert_true(pad.contains("LB") and pad.contains("B: close"), pad)


## -- Save & Return footer (press-again-to-confirm guard) --

func test_quit_hint_armed_and_idle_are_distinct_and_both_name_the_action() -> void:
	var idle := MenuScreen.quit_hint(false)
	var armed := MenuScreen.quit_hint(true)
	assert_ne(idle, armed, "arming visibly changes the footer")
	assert_true(idle.find("Save & Return to Title") != -1)
	assert_true(armed.find("Save & Return to Title") != -1)
	assert_true(armed.find("AGAIN") != -1, "the armed state reads as a confirm prompt")
	assert_true(MenuScreen.quit_hint(false, "A").begins_with("A — "), "the pad's button is named")
