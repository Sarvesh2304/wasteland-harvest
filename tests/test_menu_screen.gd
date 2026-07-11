extends "res://tests/test_case.gd"
## Unit tests for scripts/menu_screen.gd's pure display/navigation math (the 2026-07-12 in-game
## tabbed menu) — same pure-logic/stateful-shell split as test_title_screen.gd: the statics are
## tested headlessly here; the open/close/gate behavior is driven through the real scene by
## tools/runtime_smoke.gd's menu stages.

const MenuScreen := preload("res://scripts/menu_screen.gd")
const BuildingDB := preload("res://scripts/building_db.gd")


## -- Tab cycling (forward-only ring over the 3 tabs) --

func test_next_tab_cycles_forward_and_wraps() -> void:
	assert_eq(MenuScreen.next_tab(MenuScreen.TAB_INVENTORY), MenuScreen.TAB_BUILD,
		"Inventory -> Build")
	assert_eq(MenuScreen.next_tab(MenuScreen.TAB_BUILD), MenuScreen.TAB_CONTROLS,
		"Build -> Controls")
	assert_eq(MenuScreen.next_tab(MenuScreen.TAB_CONTROLS), MenuScreen.TAB_INVENTORY,
		"Controls wraps back to Inventory")


func test_tab_names_cover_exactly_the_real_tabs() -> void:
	# Scope guard: per the 2026-07-12 session's explicit decision, NO placeholder tabs for
	# systems that don't exist yet (Social is Phase 7, Crafting Phase 10, Map Phase 14).
	assert_eq(MenuScreen.TAB_NAMES.size(), 3, "exactly the 3 real tabs, no stubs")
	assert_eq(MenuScreen.TAB_NAMES, ["INVENTORY", "BUILD", "CONTROLS"])


## -- Build-tab catalog rows (affordability must be BuildGrid.can_afford's verdict) --

func test_catalog_rows_cover_the_whole_catalog_in_order() -> void:
	var rows := MenuScreen.catalog_rows(BuildingDB.ids(), {})
	assert_eq(rows.size(), BuildingDB.ids().size(), "one row per catalog entry")
	assert_eq(String(rows[0]["id"]), "shelter_tent", "catalog order preserved (tent first)")
	assert_eq(String(rows[1]["id"]), "storage_shed", "catalog order preserved (shed second)")
	assert_eq(String(rows[0]["name"]), "Shelter Tent")
	assert_eq(String(rows[1]["name"]), "Storage Shed")


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
	assert_eq(lines[0], "W/A/S/D or Arrows — Move")
	for line in lines:
		assert_true(line.find(" — ") != -1, "every line pairs keys with a description: %s" % line)


func test_controls_list_documents_the_menus_own_keys() -> void:
	# The menu must explain itself: its open/close key, tab cycling, and Esc all appear.
	var joined := " | ".join(MenuScreen.controls_lines())
	assert_true(joined.find("Tab — Open/close this menu") != -1, "menu key documented")
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
