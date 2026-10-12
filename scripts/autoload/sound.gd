extends Node
## Plays the game's sounds (autoload "Sound"). The sounds themselves are made
## by tools/audio/build_sounds.gd into assets/audio/.
##
##   Sound.play("climb_clip")           a one-shot on the Effects bus
##   Sound.play("step_dirt")            picks step_dirt_1, _2 or _3
##   Sound.set_ambience("world")        the ambience beds follow the world
##
## Three buses, each with a volume on the pause menu's Settings page: Master,
## Effects (one-shots) and Ambience (the beds, and the campfires and
## waterfalls placed in the world by SoundEmitter).
##
## Music (tools/audio/build_music.gd) plays the way it does in Stardew
## Valley: a piece for the season, or the night, now and then, with the
## ambience on its own in between. It rests in the rain and on the wall, comes
## in softer indoors, and fades out when the time of day or the season calls
## for a different piece. The title screen's theme loops.
##
## The beds are four loops (birds by day, crickets at night, wind, rain) that
## fade up and down together. In "world" mode their mix follows the hour, the
## season, the weather, the region (quiet indoors, windy up high), and the
## climbing screen.

const DIR := "res://assets/audio/"
const BUS_EFFECTS := &"Effects"
const BUS_AMBIENCE := &"Ambience"
const BUS_MUSIC := &"Music"
## The day's piece for each season (GameClock.Season order), and the night's.
const SEASON_MUSIC := ["music_spring", "music_summer", "music_fall", "music_winter"]
## Each season's afternoon piece (from AFTERNOON_FROM), so a day isn't one tune.
const SEASON_MUSIC_AFTERNOON := ["music_spring_b", "music_summer_b", "music_fall_b", "music_winter_b"]
const AFTERNOON_FROM := 13
const NIGHT_MUSIC := "music_night"
const TITLE_MUSIC := "music_title"
## Seconds of quiet between one piece and the next, at random in this range.
const MUSIC_REST := Vector2(30.0, 75.0)
## Seconds to wait before the first piece, and after a change of piece.
const MUSIC_START := 2.5
## Seconds to fade a piece out when it no longer fits.
const MUSIC_FADE := 2.5
## Music level indoors, against 1 outside.
const MUSIC_INDOORS := 0.55
## The night piece plays from this hour until morning.
const NIGHT_FROM := 20
const NIGHT_UNTIL := 6
## Sounds that come in numbered takes (name_1, name_2, ...).
const VARIANTS := {"step_dirt": 3, "step_snow": 3, "step_wood": 3, "step_wet": 3, "climb_move": 3}
const BEDS := ["amb_day", "amb_night", "amb_wind", "amb_rain"]
## Seconds for a bed to fade most of the way to its new level.
const BED_FADE := 1.5
## Hubs high enough that the wind is always up.
const HIGH_COUNTRY := ["glacier_point", "tuolumne_meadows"]
const POOL_SIZE := 10

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _beds: Dictionary = {}
var _mode := ""
var _streams: Dictionary = {}
var _music: AudioStreamPlayer
## The piece playing (or due next), and the seconds until it starts.
var _music_id := ""
var _music_wait := MUSIC_START


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [BUS_EFFECTS, BUS_AMBIENCE, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_EFFECTS
		add_child(player)
		_pool.append(player)
	for bed: String in BEDS:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_AMBIENCE
		player.stream = loop_stream(bed)
		player.volume_linear = 0.0
		add_child(player)
		_beds[bed] = player
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	GameClock.day_started.connect(_on_day_started.unbind(3))
	Settings.ensure_loaded()
	apply_volumes()


func _exit_tree() -> void:
	# Let go of every stream on quit, so none is still playing at exit.
	for player: AudioStreamPlayer in _pool + _beds.values() + [_music]:
		player.stop()
		player.stream = null
	_streams.clear()
	# The audio thread lets go of a stopped sound on its next mix; give it time
	# for one before the engine checks for leaks (40 ms wasn't always enough).
	OS.delay_msec(100)


## Sets each bus to its volume setting (0 to 10; 0 mutes it).
func apply_volumes() -> void:
	Settings.ensure_loaded()
	_set_bus(&"Master", Settings.master_volume)
	_set_bus(BUS_EFFECTS, Settings.effects_volume)
	_set_bus(BUS_AMBIENCE, Settings.ambience_volume)
	_set_bus(BUS_MUSIC, Settings.music_volume)


func _set_bus(bus: StringName, level: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= 0)
	AudioServer.set_bus_volume_linear(index, float(level) / Settings.MAX_VOLUME)


## Plays sound [param id] once. [param volume_db] is relative to the sound's
## own level; [param jitter] varies the pitch a little each time so repeats
## don't sound stamped.
## [param pitch] sets the pitch it varies around (a speaker's voice, say).
func play(id: String, volume_db := 0.0, jitter := 0.05, pitch := 1.0) -> void:
	var stream := _stream(_pick(id))
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	player.play()


## The ambience to play: "world" (follows the world), "title", "climb", or ""
## for none.
func set_ambience(mode: String) -> void:
	_mode = mode


func ambience() -> String:
	return _mode


## A looping copy of sound [param id], for the beds and SoundEmitters.
func loop_stream(id: String) -> AudioStreamWAV:
	var stream := _stream(id)
	if stream == null:
		return null
	var looped := stream.duplicate() as AudioStreamWAV
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looped.loop_begin = 0
	# In samples. The import compresses the data (QOA), so count by length.
	looped.loop_end = roundi(looped.get_length() * looped.mix_rate)
	return looped


## How loud the waterfalls are this season, 0 to 1: full with spring snowmelt,
## a trickle by fall (Yosemite Falls often dries up by late summer).
static func waterfall_level() -> float:
	match GameClock.season:
		GameClock.Season.SPRING:
			return 1.0
		GameClock.Season.SUMMER:
			return 0.7
		GameClock.Season.FALL:
			return 0.25
	return 0.45


## How loud each bed should be now, by name (0 to 1).
func bed_targets() -> Dictionary:
	var targets := {"amb_day": 0.0, "amb_night": 0.0, "amb_wind": 0.0, "amb_rain": 0.0}
	var mode := _mode
	# Up on the wall you hear the wind, whatever the region below.
	if mode == "world" and get_tree().get_first_node_in_group("climb_screen"):
		mode = "climb"
	match mode:
		"title":
			targets.amb_day = 0.6
			targets.amb_wind = 0.25
		"climb":
			var day := _daylight()
			targets.amb_day = 0.35 * day
			targets.amb_night = 0.35 * (1.0 - day)
			targets.amb_wind = 0.8
		"world":
			_world_targets(targets)
	return targets


func _world_targets(targets: Dictionary) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world else null
	var weather := Weather.today()
	var rain := clampf(weather.rain, 0.0, 1.0)
	var winter := GameClock.season == GameClock.Season.WINTER
	if region and region.indoors:
		# Indoors you only hear the rain on the roof.
		targets.amb_rain = 0.25 * rain
		return
	var day := _daylight()
	var high := region != null and region.hub_id in HIGH_COUNTRY
	targets.amb_day = day * (0.4 if winter else 1.0) * (1.0 - 0.7 * rain)
	# No crickets in the snow.
	targets.amb_night = (1.0 - day) * (0.0 if winter else 1.0) * (1.0 - 0.5 * rain)
	targets.amb_wind = clampf(0.2 + (0.4 if high else 0.0) + (0.3 if winter else 0.0) + 0.3 * weather.snow, 0.0, 1.0)
	targets.amb_rain = 0.8 * rain


## 1 by day, 0 at night, easing through dawn (5:30 to 7) and dusk (19:30 to 21).
func _daylight() -> float:
	var hour := GameClock.hour + GameClock.minute / 60.0
	if hour < 12.0:
		return smoothstep(5.5, 7.0, hour)
	return 1.0 - smoothstep(19.5, 21.0, hour)


## The piece that fits now, or "" for quiet.
func music_choice() -> String:
	var mode := _mode
	if mode == "world" and get_tree().get_first_node_in_group("climb_screen"):
		return ""
	match mode:
		"title":
			return TITLE_MUSIC
		"world":
			if Weather.today().rain > 0.4:
				return ""
			if GameClock.hour >= NIGHT_FROM or GameClock.hour < NIGHT_UNTIL:
				return NIGHT_MUSIC
			if GameClock.hour >= AFTERNOON_FROM:
				return SEASON_MUSIC_AFTERNOON[GameClock.season]
			return SEASON_MUSIC[GameClock.season]
	return ""


## The piece playing now, or "" between pieces.
func music_playing() -> String:
	return _music_id if _music.playing else ""


func _music_level() -> float:
	var world := get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world else null
	return MUSIC_INDOORS if region and region.indoors else 1.0


func _update_music(delta: float) -> void:
	var want := music_choice()
	if _music.playing:
		var target := _music_level() if want == _music_id else 0.0
		_music.volume_linear = move_toward(_music.volume_linear, target, delta / MUSIC_FADE)
		if target <= 0.0 and _music.volume_linear <= 0.0:
			_music.stop()
			_music_wait = MUSIC_START
		return
	if want != _music_id:
		_music_id = want
		_music_wait = minf(_music_wait, MUSIC_START)
	if want == "":
		return
	_music_wait -= delta
	if _music_wait > 0.0:
		return
	_music.stream = loop_stream(want) if want == TITLE_MUSIC else _stream(want)
	if _music.stream == null:
		_music_wait = MUSIC_REST.y
		return
	_music.volume_linear = _music_level()
	_music.play()


func _on_music_finished() -> void:
	_music_wait = randf_range(MUSIC_REST.x, MUSIC_REST.y)


## A new morning starts with music, like the first walk out of the tent.
func _on_day_started() -> void:
	if not _music.playing:
		_music_wait = MUSIC_START


func _process(delta: float) -> void:
	_update_music(delta)
	var targets := bed_targets()
	var k := 1.0 - exp(-delta * 3.0 / BED_FADE)
	for bed: String in BEDS:
		var player: AudioStreamPlayer = _beds[bed]
		if player.stream == null:
			continue
		var target: float = targets[bed]
		player.volume_linear = lerpf(player.volume_linear, target, k)
		if player.volume_linear > 0.002 and not player.playing:
			player.play(randf() * player.stream.get_length())
		elif player.volume_linear <= 0.002 and target <= 0.0 and player.playing:
			player.stop()


func _pick(id: String) -> String:
	var takes: int = VARIANTS.get(id, 0)
	return "%s_%d" % [id, randi_range(1, takes)] if takes > 0 else id


func _stream(id: String) -> AudioStreamWAV:
	if not _streams.has(id):
		var path := DIR + id + ".wav"
		_streams[id] = load(path) if ResourceLoader.exists(path) else null
		if _streams[id] == null:
			push_warning("No sound named %s" % id)
	return _streams[id]
