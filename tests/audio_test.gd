extends Node
## Headless test of the sound (scripts/autoload/sound.gd and
## scripts/world/sound_emitter.gd): every sound the game asks for exists, the
## buses follow the volume settings (which save and load), the ambience beds
## follow the hour, season, weather and place, campfires and waterfalls carry
## their loops, and footsteps and the climbing screen make sounds.
## Run: godot --headless --path . res://tests/audio_test.tscn
## Exit code is the number of failed checks. Uses its own save and settings files.
## (Headless runs on the dummy audio driver: this checks what plays, not how
## it sounds. To change the sounds, edit tools/audio/build_sounds.gd.)

const SETTINGS_PATH := "user://audio_test_settings.cfg"
## Every sound the code plays by name (variants without their number).
const USED := ["amb_day", "amb_night", "amb_wind", "amb_rain", "waterfall", "campfire",
	"step_dirt", "step_snow", "step_wood", "step_wet", "climb_move", "climb_clip", "climb_cam",
	"climb_chalk", "climb_eat", "climb_fall", "climb_jug", "climb_crux", "climb_topout",
	"ui_move", "ui_select", "ui_back"]

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.path = SETTINGS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	Settings.load_settings()
	test_files()
	test_volumes()
	SaveManager.save_path = "user://audio_test_save.json"
	SaveManager.delete_save()
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	test_world_ambience()
	await test_emitters()
	await test_footsteps()
	await test_climbing()
	world.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	Sound.set_ambience("")
	await get_tree().create_timer(0.5).timeout # let the last sounds finish before quitting
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_files() -> void:
	var missing := PackedStringArray()
	for id: String in USED:
		var takes: int = Sound.VARIANTS.get(id, 0)
		var names := [id] if takes == 0 else range(1, takes + 1).map(func(i: int) -> String: return "%s_%d" % [id, i])
		for sound_name: String in names:
			if not ResourceLoader.exists(Sound.DIR + sound_name + ".wav"):
				missing.append(sound_name)
	check(missing.is_empty(), "every sound the game plays is in assets/audio (missing: %s)" % ", ".join(missing))
	var loop := Sound.loop_stream("waterfall")
	check(loop != null and loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end == roundi(8.0 * loop.mix_rate), "loops repeat over their whole length (the waterfall's 8 seconds: %d samples)" % (loop.loop_end if loop else 0))
	check(Sound.loop_stream("waterfall") != loop, "each emitter gets its own copy of a loop")


func test_volumes() -> void:
	for bus in [&"Master", Sound.BUS_EFFECTS, Sound.BUS_AMBIENCE]:
		check(AudioServer.get_bus_index(bus) >= 0, "the %s bus exists" % bus)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(Sound.BUS_EFFECTS)) == &"Master", "the Effects bus feeds Master")
	check(Settings.master_volume == 8 and Settings.effects_volume == 10 and Settings.ambience_volume == 10, "volumes start at 80%, 100%, 100%")
	Settings.master_volume = 5
	Settings.effects_volume = 0
	Settings.ambience_volume = 3
	Settings.save()
	Sound.apply_volumes()
	var effects := AudioServer.get_bus_index(Sound.BUS_EFFECTS)
	var ambience := AudioServer.get_bus_index(Sound.BUS_AMBIENCE)
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.5), "Master follows its setting")
	check(AudioServer.is_bus_mute(effects), "an effects volume of 0 mutes the Effects bus")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(ambience), 0.3) and not AudioServer.is_bus_mute(ambience), "Ambience follows its setting")
	Settings.reset_defaults()
	Settings.load_settings()
	check(Settings.master_volume == 5 and Settings.effects_volume == 0 and Settings.ambience_volume == 3, "volumes save and load back")
	var config := ConfigFile.new()
	config.set_value("audio", "master", 40)
	config.set_value("audio", "effects", -2)
	config.save(SETTINGS_PATH)
	Settings.load_settings()
	check(Settings.master_volume == Settings.MAX_VOLUME and Settings.effects_volume == 0, "out-of-range volumes are clamped")
	check(Settings.ambience_volume == Settings.MAX_VOLUME, "a missing volume keeps its default")
	Settings.reset_defaults()
	Settings.save()
	Sound.apply_volumes()
	var pause := PauseMenu.new()
	add_child(pause)
	pause.change_setting(PauseMenu.Setting.MASTER_VOLUME, -1)
	check(Settings.master_volume == 7 and is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.7), "the pause menu's Volume row turns the game down at once")
	check(pause._setting_value(PauseMenu.Setting.MASTER_VOLUME) == "‹  70%  ›", "and shows it as a percentage")
	for i in 12:
		pause.change_setting(PauseMenu.Setting.EFFECTS_VOLUME, -1)
	check(Settings.effects_volume == 0 and pause._setting_value(PauseMenu.Setting.EFFECTS_VOLUME) == "‹  Off  ›", "Sound effects stops at Off")
	pause.open_settings()
	pause._settings_cursor = PauseMenu.Setting.AMBIENCE_VOLUME
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	pause._settings_input(press)
	check(Settings.ambience_volume == 0, "E on a volume at 100% goes round to Off")
	pause._settings_input(press)
	check(Settings.ambience_volume == 1, "and E steps it up again")
	pause.close()
	pause.free()
	Settings.reset_defaults()
	Settings.save()
	Sound.apply_volumes()


func test_world_ambience() -> void:
	check(Sound.ambience() == "world", "World sets the ambience to follow it")
	world._enter_region("curry_village", "arrival")
	GameClock.season = GameClock.Season.SUMMER
	_clear_weather()
	GameClock.minutes = 12 * 60
	var noon := Sound.bed_targets()
	check(noon.amb_day > 0.9 and noon.amb_night == 0.0, "birds at noon, no crickets")
	GameClock.minutes = 23 * 60
	var night := Sound.bed_targets()
	check(night.amb_night > 0.9 and night.amb_day == 0.0, "crickets at night, no birds")
	GameClock.minutes = int(20.25 * 60)
	var dusk := Sound.bed_targets()
	check(dusk.amb_day > 0.0 and dusk.amb_night > 0.0, "both at dusk, crossing over")
	GameClock.season = GameClock.Season.WINTER
	GameClock.minutes = 23 * 60
	var winter := Sound.bed_targets()
	check(winter.amb_night == 0.0 and winter.amb_wind > noon.amb_wind, "no crickets in winter, and more wind")
	GameClock.season = GameClock.Season.SUMMER
	_set_weather(1.0, 0.0)
	GameClock.minutes = 12 * 60
	var rain := Sound.bed_targets()
	check(rain.amb_rain > 0.5 and rain.amb_day < noon.amb_day, "rain on a rainy day, and fewer birds")
	world._enter_region("curry_store", "")
	var indoors := Sound.bed_targets()
	check(indoors.amb_day == 0.0 and indoors.amb_wind == 0.0 and indoors.amb_rain < rain.amb_rain, "indoors only the rain on the roof")
	_clear_weather()
	world._enter_region("glacier_point", "arrival")
	check(Sound.bed_targets().amb_wind > noon.amb_wind, "the wind is up at Glacier Point")
	Sound.set_ambience("")
	var quiet := Sound.bed_targets()
	check(quiet.values().max() == 0.0, "no ambience when it's off")
	Sound.set_ambience("world")
	world._enter_region("curry_village", "arrival")


func test_emitters() -> void:
	var mist: Array = world.region.find_children("Sound_waterfall", "", true, false)
	check(mist.size() == 1, "Staircase Falls roars from its mist, and only once (%d)" % mist.size())
	world._enter_region("yosemite_village", "arrival")
	var fires := 0
	var crackling := 0
	for fx in world.region.find_children("*", "CPUParticles2D", true, false):
		if fx is AmbientFx and fx.effect == "sparks":
			fires += 1
			if fx.get_node_or_null("Sound_campfire") is SoundEmitter:
				crackling += 1
	check(fires > 0 and crackling == fires, "every Camp 4 fire ring crackles (%d of %d)" % [crackling, fires])
	check(world.region.find_children("Sound_waterfall", "", true, false).size() == 1, "Lower Yosemite Fall roars from its spray, and only once")
	world._enter_region("yosemite_valley", "arrival")
	await get_tree().process_frame
	var falls := PackedStringArray()
	for place in world.region.get_places():
		if place.get_node_or_null("Sound_waterfall"):
			falls.append(place.display_name)
	check("Yosemite Falls" in falls and "Bridalveil Fall" in falls and "Lower Yosemite Fall" in falls, "the Valley's waterfalls roar (%s)" % ", ".join(falls))
	var emitter: SoundEmitter = world.region.get_places().filter(func(p: Place) -> bool: return p.display_name == "Yosemite Falls")[0].get_node("Sound_waterfall")
	emitter._refresh_level() # the dummy driver can drop a playback that starts on the same frame
	check(emitter.bus == Sound.BUS_AMBIENCE and emitter.stream != null and emitter.playing, "a waterfall plays its loop on the Ambience bus")
	GameClock.season = GameClock.Season.SPRING
	emitter._refresh_level()
	var spring := emitter.volume_linear
	GameClock.season = GameClock.Season.FALL
	emitter._refresh_level()
	check(emitter.volume_linear < spring * 0.5, "falls are loud in spring and quiet in fall (%.2f, %.2f)" % [spring, emitter.volume_linear])
	GameClock.season = GameClock.Season.SUMMER
	world._enter_region("wawona", "arrival")
	await get_tree().process_frame
	var trailhead: Array = world.region.get_places().filter(func(p: Place) -> bool: return p.display_name.contains("Trailhead") and p.get_node_or_null("Sound_waterfall") != null)
	check(trailhead.is_empty(), "a trailhead named for a fall makes no sound")
	world._enter_region("yosemite_valley", "arrival")
	await get_tree().process_frame
	check(emitter.playing, "a waterfall starts again when you come back")


func test_footsteps() -> void:
	world._enter_region("curry_village", "arrival")
	var footfall: Footfall = world.player.find_children("*", "Footfall", true, false)[0]
	var played := _count_playing()
	footfall._step(world.player.global_position)
	check(_count_playing() > played, "a step makes a sound")
	await get_tree().process_frame


func test_climbing() -> void:
	var route: RouteData = load("res://data/routes/firefall_slab.tres")
	var minigame := ClimbMinigame.new()
	minigame.setup(route, 7)
	get_tree().root.add_child(minigame)
	await get_tree().process_frame
	check(Sound.bed_targets().amb_wind >= 0.8, "the wind rises on the climbing screen")
	minigame.skip_intro()
	var played := _count_playing()
	minigame.state.events.append({"type": "clip"})
	minigame._events()
	check(_count_playing() > played, "clipping a bolt makes a sound")
	minigame.queue_free()
	await get_tree().process_frame
	check(Sound.bed_targets().amb_wind < 0.8, "and settles when you leave it")


func _count_playing() -> int:
	var count := 0
	for player in Sound._pool:
		if player.playing:
			count += 1
	return count


func _clear_weather() -> void:
	_set_weather(0.0, 0.0)


## Sets today's weather (Weather.today() keeps one answer a day).
func _set_weather(rain: float, snow: float) -> void:
	Weather.today()
	Weather._today = {"snow": snow, "rain": rain, "clouds": 1.0 if rain + snow > 0.0 else 0.3}
