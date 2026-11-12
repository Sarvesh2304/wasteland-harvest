extends "res://tests/test_case.gd"
## Milestone E balance pass (docs/BALANCE.md): bigger buildings charge a Credits fee on top of
## their materials, shown in the cost line and checked wherever affordability is.

const BuildingDB := preload("res://scripts/building_db.gd")
const Builder := preload("res://scripts/builder.gd")
const MenuScreen := preload("res://scripts/menu_screen.gd")


func test_fees_are_read_and_default_to_zero() -> void:
	assert_eq(BuildingDB.credits("barn"), 1200)
	assert_eq(BuildingDB.credits("shelter_tent"), 0, "no fee unless the catalog sets one")
	assert_eq(BuildingDB.credits("storage_shed"), 0, "the first build stays free (the day-1 bonus covers it)")
	assert_eq(BuildingDB.credits("not_a_building"), 0)


func test_cost_text_leads_with_the_fee() -> void:
	assert_true(Builder.cost_text("barn").begins_with("1200 Cr, "), Builder.cost_text("barn"))
	assert_false(Builder.cost_text("shelter_tent").contains("Cr"), "no fee, no Cr")


func test_build_tab_needs_the_credits_too() -> void:
	var have := BuildingDB.cost("barn").duplicate()
	var row := _row(MenuScreen.catalog_rows(BuildingDB.ids(), have), "barn")
	assert_false(bool(row["affordable"]), "materials alone don't buy a barn")
	have["credits"] = 1199
	assert_false(bool(_row(MenuScreen.catalog_rows(BuildingDB.ids(), have), "barn")["affordable"]), "one short")
	have["credits"] = 1200
	assert_true(bool(_row(MenuScreen.catalog_rows(BuildingDB.ids(), have), "barn")["affordable"]), "exact")


func test_every_fee_is_sane() -> void:
	for id in BuildingDB.ids():
		var fee := BuildingDB.credits(id)
		assert_true(fee >= 0 and fee <= 5000, "%s's fee %d" % [id, fee])


func _row(rows: Array[Dictionary], id: String) -> Dictionary:
	for row in rows:
		if String(row["id"]) == id:
			return row
	return {}
