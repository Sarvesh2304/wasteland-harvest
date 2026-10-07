extends Node
## Audio manager (autoload "Audio", 2026-10-07). One place that knows where sounds live and how
## they're mixed. Every system asks for sounds by NAME (the contract in audio/README.md); missing
## files are silently skipped, so gameplay never depends on audio existing.
##
## Buses (created at runtime if absent): Master > Music, SFX, Ambience, UI.
## - play_sfx(name): non-positional one-shot; "name" resolves to name.wav or a random one of
##   name_1.wav, name_2.wav, ... (variants), with a little random pitch so repeats never sound
##   mechanical.
## - play_sfx_at(name, world_pos): positional one-shot (distance-attenuated).
## - play_music(track) / play_ambience(name): looping, cross-faded between two players each.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const AMBIENCE_DIR := "res://audio/ambience/"
const BUSES: Array[String] = ["Music", "SFX", "Ambience", "UI"]
const SFX_POOL_SIZE := 14
const POSITIONAL_POOL_SIZE := 10
## Names that route to the UI bus instead of SFX.
const UI_PREFIXES: Array[String] = ["ui_", "dialogue_blip", "notify", "level_up", "quest_", "save",
	"achievement"]

## Default mix (linear), overridable by settings.
var bus_volumes := {"Master": 0.9, "Music": 0.55, "SFX": 0.8, "Ambience": 0.6, "UI": 0.7}

var _variants: Dictionary = {}      # name -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _pool_next := 0
var _pos_pool: Array[AudioStreamPlayer2D] = []
var _pos_next := 0
var _music: Array[AudioStreamPlayer] = []
var _music_active := 0
var _music_track := ""
var _amb: Array[AudioStreamPlayer] = []
var _amb_active := 0
var _amb_name := ""
var _rng := RandomNumberGenerator.new()
## Per-name cooldown so 20 simultaneous identical sounds don't stack into a roar.
var _last_played: Dictionary = {}
const MIN_REPEAT_SECONDS := 0.03


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in POSITIONAL_POOL_SIZE:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = "SFX"
		p2.max_distance = 360.0
		p2.attenuation = 1.6
		add_child(p2)
		_pos_pool.append(p2)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
		var a := AudioStreamPlayer.new()
		a.bus = "Ambience"
		a.volume_db = -80.0
		add_child(a)
		_amb.append(a)


func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	for bus_name in bus_volumes:
		set_bus_volume(bus_name, float(bus_volumes[bus_name]))


## Linear 0..1 volume for a bus (0 mutes).
func set_bus_volume(bus_name: String, linear: float) -> void:
	bus_volumes[bus_name] = clampf(linear, 0.0, 1.0)
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func get_bus_volume(bus_name: String) -> float:
	return float(bus_volumes.get(bus_name, 1.0))


## Resolves a sound name to its variant streams (cached). Empty when no file exists.
func _streams_for(sound_name: String) -> Array:
	if _variants.has(sound_name):
		return _variants[sound_name]
	var found: Array = []
	for ext in [".wav", ".ogg"]:
		var single: String = SFX_DIR + sound_name + String(ext)
		if ResourceLoader.exists(single):
			found.append(load(single))
	var i := 1
	while i <= 12:
		var hit := false
		for ext in [".wav", ".ogg"]:
			var path: String = "%s%s_%d%s" % [SFX_DIR, sound_name, i, ext]
			if ResourceLoader.exists(path):
				found.append(load(path))
				hit = true
				break
		if not hit:
			break
		i += 1
	_variants[sound_name] = found
	return found


func has_sfx(sound_name: String) -> bool:
	return not _streams_for(sound_name).is_empty()


func _pick(sound_name: String) -> AudioStream:
	var streams := _streams_for(sound_name)
	if streams.is_empty():
		return null
	return streams[_rng.randi_range(0, streams.size() - 1)]


func _cooldown_ok(sound_name: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound_name, -1.0)) < MIN_REPEAT_SECONDS:
		return false
	_last_played[sound_name] = now
	return true


func _bus_for(sound_name: String) -> String:
	for prefix in UI_PREFIXES:
		if sound_name.begins_with(prefix):
			return "UI"
	return "SFX"


## Non-positional one-shot. volume_db is relative to the file's own level.
func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.05,
		pitch: float = 1.0) -> void:
	if sound_name == "" or not _cooldown_ok(sound_name):
		return
	var stream := _pick(sound_name)
	if stream == null:
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stop()
	p.stream = stream
	p.bus = _bus_for(sound_name)
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.1, pitch * (1.0 + _rng.randf_range(-pitch_variation, pitch_variation)))
	p.play()


## Positional one-shot at a world position (attenuates with distance from the listener/camera).
func play_sfx_at(sound_name: String, world_pos: Vector2, volume_db: float = 0.0,
		pitch_variation: float = 0.06) -> void:
	if sound_name == "" or not _cooldown_ok(sound_name + "@"):
		return
	var stream := _pick(sound_name)
	if stream == null:
		return
	var p := _pos_pool[_pos_next]
	_pos_next = (_pos_next + 1) % _pos_pool.size()
	p.stop()
	p.stream = stream
	p.global_position = world_pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
	p.play()


## -- Music / ambience (looping, cross-faded) --

func current_music() -> String:
	return _music_track


func play_music(track: String, fade_seconds: float = 1.5) -> void:
	if track == _music_track:
		return
	_music_track = track
	_crossfade(_music, track, MUSIC_DIR, fade_seconds, true)


func stop_music(fade_seconds: float = 1.5) -> void:
	play_music("", fade_seconds)


## A one-shot musical stinger over the music (music ducks briefly).
func play_stinger(track: String, volume_db: float = 0.0) -> void:
	var path := MUSIC_DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stop()
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	p.stream = stream
	p.bus = "Music"
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()


func current_ambience() -> String:
	return _amb_name


func play_ambience(amb_name: String, fade_seconds: float = 2.0) -> void:
	if amb_name == _amb_name:
		return
	_amb_name = amb_name
	_crossfade(_amb, amb_name, AMBIENCE_DIR, fade_seconds, false)


func _crossfade(players: Array, track: String, dir: String, fade_seconds: float, is_music: bool) -> void:
	var active_idx := _music_active if is_music else _amb_active
	var old: AudioStreamPlayer = players[active_idx]
	var nxt: AudioStreamPlayer = players[1 - active_idx]
	if is_music:
		_music_active = 1 - active_idx
	else:
		_amb_active = 1 - active_idx
	_fade(old, -80.0, fade_seconds, true)
	if track == "":
		return
	var path := dir + track + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	_fade(nxt, 0.0, fade_seconds, false)


var _fades: Dictionary = {}  # player -> running Tween (killed when the player is re-faded)


func _fade(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool) -> void:
	var running: Tween = _fades.get(p)
	if running != null and running.is_valid():
		running.kill()
	var tw := create_tween()
	_fades[p] = tw
	tw.tween_property(p, "volume_db", to_db, maxf(seconds, 0.01))
	if stop_after:
		tw.tween_callback(p.stop)
