extends "res://tests/test_case.gd"
## scripts/player_look.gd (Milestone E): the palette mapping of the player sprite's hair / skin /
## outfit regions onto a chosen ramp, the region masks, and the recoloured SpriteFrames.

const PlayerLook := preload("res://scripts/player_look.gd")
const PlayerProfile := preload("res://scripts/player_profile.gd")
const BASE_FRAMES := preload("res://art/characters/player/player_frames.tres")


func _close(a: Color, b: Color, tol := 0.01) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol and absf(a.a - b.a) <= tol


func test_ramp_anchors_map_exactly() -> void:
	var from := PlayerProfile.HAIR_OPTIONS[0]["ramp"] as Array
	for option in PlayerProfile.HAIR_OPTIONS:
		var to := option["ramp"] as Array
		for i in 3:
			assert_true(_close(PlayerLook.map_color(Color(String(from[i])), from, to), Color(String(to[i]))),
				"%s: source anchor %d lands on the target anchor" % [option["name"], i])


func test_identity_ramp_leaves_colours_alone() -> void:
	var ramp := PlayerProfile.SKIN_OPTIONS[0]["ramp"] as Array
	var c := Color("#f1bda7")
	assert_eq(PlayerLook.map_color(c, ramp, ramp), c)


func test_mapping_keeps_shading_order_and_alpha() -> void:
	var from := PlayerProfile.OUTFIT_OPTIONS[0]["ramp"] as Array
	var to := PlayerProfile.OUTFIT_OPTIONS[3]["ramp"] as Array
	var shades := [Color("#633822"), Color("#774727"), Color("#8a5932"), Color("#ae6d35"), Color("#bf7945"), Color("#f49655")]
	var last := -1.0
	for c in shades:
		var y := PlayerLook.luminance(PlayerLook.map_color(c, from, to))
		assert_true(y >= last - 0.001, "darker source stays darker (%s)" % c.to_html())
		last = y
	var half := Color("#ae6d35", 0.5)
	assert_eq(PlayerLook.map_color(half, from, to).a, 0.5, "alpha is kept")


func test_region_of_mask_pixels() -> void:
	assert_eq(PlayerLook.region_of(Color(1, 0, 0, 1)), PlayerLook.REGION_HAIR)
	assert_eq(PlayerLook.region_of(Color(0, 1, 0, 1)), PlayerLook.REGION_SKIN)
	assert_eq(PlayerLook.region_of(Color(0, 0, 1, 1)), PlayerLook.REGION_OUTFIT)
	assert_eq(PlayerLook.region_of(Color(0, 0, 0, 0)), PlayerLook.REGION_NONE)
	assert_eq(PlayerLook.region_of(Color(1, 1, 1, 1)), PlayerLook.REGION_NONE)


func test_every_frame_has_a_mask_with_all_regions_on_idle() -> void:
	for anim in BASE_FRAMES.get_animation_names():
		for i in BASE_FRAMES.get_frame_count(anim):
			var tex := BASE_FRAMES.get_frame_texture(anim, i)
			var path := PlayerLook.mask_path_for(tex.resource_path)
			assert_true(path != "" and ResourceLoader.exists(path), "%s %d has a region mask (%s)" % [anim, i, path])
	var mask := (load(PlayerLook.mask_path_for(BASE_FRAMES.get_frame_texture("idle_south", 0).resource_path)) as Texture2D).get_image()
	var found := {}
	for y in mask.get_height():
		for x in mask.get_width():
			found[PlayerLook.region_of(mask.get_pixel(x, y))] = true
	for region in [PlayerLook.REGION_HAIR, PlayerLook.REGION_SKIN, PlayerLook.REGION_OUTFIT]:
		assert_true(found.has(region), "idle_south has region %d" % region)


func test_default_look_returns_the_authored_frames() -> void:
	assert_eq(PlayerLook.build_frames(BASE_FRAMES, PlayerProfile.default_appearance()), BASE_FRAMES)


func test_recoloured_frames_change_only_masked_pixels() -> void:
	var look := {"preset": 0, "hair": 4, "skin": 5, "outfit": 3}
	var frames := PlayerLook.build_frames(BASE_FRAMES, look)
	assert_ne(frames, BASE_FRAMES)
	assert_eq(frames.get_animation_names().size(), BASE_FRAMES.get_animation_names().size())
	for anim in BASE_FRAMES.get_animation_names():
		assert_eq(frames.get_frame_count(anim), BASE_FRAMES.get_frame_count(anim), "%s frame count" % anim)
		assert_eq(frames.get_animation_loop(anim), BASE_FRAMES.get_animation_loop(anim), "%s loop" % anim)
		assert_eq(frames.get_animation_speed(anim), BASE_FRAMES.get_animation_speed(anim), "%s speed" % anim)
	var src := BASE_FRAMES.get_frame_texture("idle_south", 0).get_image()
	src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var out := frames.get_frame_texture("idle_south", 0).get_image()
	var mask := (load(PlayerLook.mask_path_for(BASE_FRAMES.get_frame_texture("idle_south", 0).resource_path)) as Texture2D).get_image()
	var changed := {}
	for y in src.get_height():
		for x in src.get_width():
			var region := PlayerLook.region_of(mask.get_pixel(x, y))
			var a := src.get_pixel(x, y)
			var b := out.get_pixel(x, y)
			assert_true(_close(a, b, 1.0) and absf(a.a - b.a) < 0.01, "alpha unchanged at %d,%d" % [x, y])
			if region == PlayerLook.REGION_NONE:
				assert_true(_close(a, b), "unmasked pixel %d,%d untouched" % [x, y])
			elif not _close(a, b):
				changed[region] = true
	for region in [PlayerLook.REGION_HAIR, PlayerLook.REGION_SKIN, PlayerLook.REGION_OUTFIT]:
		assert_true(changed.has(region), "region %d was recoloured" % region)
	assert_eq(PlayerLook.build_frames(BASE_FRAMES, look), frames, "the same look is served from the cache")
