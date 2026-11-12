extends RefCounted
## Palette swap for the player sprite (Milestone E character creation). Turns a look
## (scripts/player_profile.gd's {"preset","hair","skin","outfit"}) into a recoloured copy of
## art/characters/player/player_frames.tres.
##
## Why pre-recoloured textures rather than a shader: the PixelLab player uses the SAME dark
## browns for hair and trousers, so a colour-keyed shader cannot tell them apart. Instead each
## frame has a region mask (art/characters/player/regions/<action>/<facing>/<n>.png, built by
## tools/art/opening/op_regions.py: red = hair, green = skin, blue = outfit), and every masked
## pixel is remapped onto the chosen ramp here, once per look, into ImageTextures. 52 frames of
## 24x24 is a few milliseconds; results are cached by look so flipping options in the creation
## screen back and forth costs nothing the second time.
##
## The remap (map_color) is pure and unit-tested: a pixel's luminance is placed on the
## region's SOURCE ramp [shade, base, light] (as drawn) and the same position is read off the
## TARGET ramp, so the sprite's shading survives — the base colour maps exactly onto the target
## base, the shade onto the target shade, and darker/lighter pixels beyond the ends darken /
## lighten past them a little. Index 0 options ARE the source ramps, so the default look returns
## the original SpriteFrames untouched.

const PlayerProfile := preload("res://scripts/player_profile.gd")

const BASE_FRAMES_PATH := "res://art/characters/player/player_frames.tres"
const PLAYER_ART_DIR := "res://art/characters/player/"
const REGION_DIR := "res://art/characters/player/regions/"

const REGION_NONE := 0
const REGION_HAIR := 1
const REGION_SKIN := 2
const REGION_OUTFIT := 3

static var _cache: Dictionary = {}


## The source ramp for a region (= option 0 of its list).
static func source_ramp(region: int) -> Array:
	match region:
		REGION_HAIR:
			return PlayerProfile.HAIR_OPTIONS[0]["ramp"]
		REGION_SKIN:
			return PlayerProfile.SKIN_OPTIONS[0]["ramp"]
		REGION_OUTFIT:
			return PlayerProfile.OUTFIT_OPTIONS[0]["ramp"]
	return []


## The target ramp a look picks for a region.
static func target_ramp(region: int, look: Dictionary) -> Array:
	var l := PlayerProfile.normalize_appearance(look)
	match region:
		REGION_HAIR:
			return PlayerProfile.HAIR_OPTIONS[int(l["hair"])]["ramp"]
		REGION_SKIN:
			return PlayerProfile.SKIN_OPTIONS[int(l["skin"])]["ramp"]
		REGION_OUTFIT:
			return PlayerProfile.OUTFIT_OPTIONS[int(l["outfit"])]["ramp"]
	return []


## Mask pixel -> region (one-hot red/green/blue; anything else or transparent = none).
static func region_of(mask_pixel: Color) -> int:
	if mask_pixel.a < 0.5:
		return REGION_NONE
	if mask_pixel.r > 0.5 and mask_pixel.g < 0.5 and mask_pixel.b < 0.5:
		return REGION_HAIR
	if mask_pixel.g > 0.5 and mask_pixel.r < 0.5 and mask_pixel.b < 0.5:
		return REGION_SKIN
	if mask_pixel.b > 0.5 and mask_pixel.r < 0.5 and mask_pixel.g < 0.5:
		return REGION_OUTFIT
	return REGION_NONE


static func luminance(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## Remaps one colour from the source ramp onto the target ramp by luminance position (see class
## doc). Alpha is preserved. Ramps are [shade, base, light] hex strings.
static func map_color(src: Color, from_ramp: Array, to_ramp: Array) -> Color:
	if from_ramp.size() != 3 or to_ramp.size() != 3 or from_ramp == to_ramp:
		return src
	var f0 := Color(String(from_ramp[0]))
	var f1 := Color(String(from_ramp[1]))
	var f2 := Color(String(from_ramp[2]))
	var t0 := Color(String(to_ramp[0]))
	var t1 := Color(String(to_ramp[1]))
	var t2 := Color(String(to_ramp[2]))
	var y := luminance(src)
	var y0 := luminance(f0)
	var y1 := luminance(f1)
	var y2 := luminance(f2)
	var out: Color
	if y <= y1:
		var t := (y - y0) / maxf(y1 - y0, 0.001)
		if t >= 0.0:
			out = t0.lerp(t1, t)
		else:
			out = t0.darkened(clampf(-t * 0.35, 0.0, 0.6))
	else:
		var t := (y - y1) / maxf(y2 - y1, 0.001)
		if t <= 1.0:
			out = t1.lerp(t2, t)
		else:
			out = t2.lightened(clampf((t - 1.0) * 0.3, 0.0, 0.5))
	out.a = src.a
	return out


## Recolours one frame image with its region mask. Both images must be the same size.
static func recolor_image(src: Image, mask: Image, look: Dictionary) -> Image:
	var out := src.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	var m := mask.duplicate() as Image
	if m.is_compressed():
		m.decompress()
	m.convert(Image.FORMAT_RGBA8)
	var ramps := {}
	for region in [REGION_HAIR, REGION_SKIN, REGION_OUTFIT]:
		ramps[region] = [source_ramp(region), target_ramp(region, look)]
	var memo := {}
	for y in mini(out.get_height(), m.get_height()):
		for x in mini(out.get_width(), m.get_width()):
			var region := region_of(m.get_pixel(x, y))
			if region == REGION_NONE:
				continue
			var c := out.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var pair: Array = ramps[region]
			if pair[0] == pair[1]:
				continue
			var key := "%d:%s" % [region, c.to_html()]
			if not memo.has(key):
				memo[key] = map_color(c, pair[0], pair[1])
			out.set_pixel(x, y, memo[key])
	return out


## The region-mask path for a frame texture path, or "" if the frame isn't player art.
static func mask_path_for(texture_path: String) -> String:
	if not texture_path.begins_with(PLAYER_ART_DIR):
		return ""
	return REGION_DIR + texture_path.substr(PLAYER_ART_DIR.length())


## Recoloured SpriteFrames for a look (cached). The default look returns `base` itself.
static func build_frames(base: SpriteFrames, look: Dictionary) -> SpriteFrames:
	if base == null or PlayerProfile.is_identity(look):
		return base
	var key := "%d:%s" % [base.get_instance_id(), PlayerProfile.look_key(look)]
	if _cache.has(key):
		return _cache[key]
	var out := SpriteFrames.new()
	if out.has_animation(&"default") and not base.has_animation(&"default"):
		out.remove_animation(&"default")
	for anim in base.get_animation_names():
		if not out.has_animation(anim):
			out.add_animation(anim)
		out.set_animation_loop(anim, base.get_animation_loop(anim))
		out.set_animation_speed(anim, base.get_animation_speed(anim))
		for i in base.get_frame_count(anim):
			var tex := base.get_frame_texture(anim, i)
			out.add_frame(anim, _recolor_texture(tex, look), base.get_frame_duration(anim, i))
	_cache[key] = out
	return out


static func _recolor_texture(tex: Texture2D, look: Dictionary) -> Texture2D:
	if tex == null:
		return tex
	var mask_path := mask_path_for(tex.resource_path)
	if mask_path == "" or not ResourceLoader.exists(mask_path):
		return tex
	var mask_tex := load(mask_path) as Texture2D
	if mask_tex == null:
		return tex
	var src := tex.get_image()
	var mask := mask_tex.get_image()
	if src == null or mask == null:
		return tex
	return ImageTexture.create_from_image(recolor_image(src, mask, look))


static func clear_cache() -> void:
	_cache.clear()
