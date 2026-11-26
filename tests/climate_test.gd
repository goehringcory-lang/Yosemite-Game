extends Node
## Headless test of the park's climate by height (Climate): the Valley floor
## keeps exactly the weather and snow it always had; the same storm is snow
## up high and rain down the canyon; the high country's snow comes deeper and
## melts out weeks later; the summer afternoon storm rains on Tuolumne and
## not on the Valley; and walking into an area (World) makes its weather,
## snow, breath and sounds the ones you get.
## Run: godot --headless --path . res://tests/climate_test.tscn
## Exit code is the number of failed checks. Uses its own settings and save.

const TEST_PATH := "user://climate_test.cfg"

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_settings()
	Settings.reset_defaults()
	SaveManager.save_path = "user://climate_test_save.json"
	SaveManager.delete_save()
	test_heights()
	test_valley_unchanged()
	test_storm_by_height()
	test_snowpack()
	test_storm_hour()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	await test_places()
	world.queue_free()
	Climate.arrive("", "")
	SaveManager.delete_save()
	Settings.reset_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_heights() -> void:
	check(Climate.zone("el_portal") == "foothill" and Climate.zone("curry_village") == "valley"
		and Climate.zone("crane_flat") == "montane" and Climate.zone("tuolumne_meadows") == "subalpine",
		"El Portal is foothill, Curry the Valley, Crane Flat montane, Tuolumne subalpine")
	check(Climate.elevation("tuolumne_lodge", "tuolumne_meadows") == 8600, "a building is as high as its hub")
	check(Climate.elevation("nowhere") == Climate.VALLEY_FT, "anywhere unknown is the Valley floor")
	# every area above the oaks is one the high-country squirrels and birds live in
	for id: String in Climate.ELEVATION:
		if Climate.is_mountain(id):
			check(id in Critters.HIGH_REGIONS, "%s is high-country wildlife ground" % id)


func test_valley_unchanged() -> void:
	var same := true
	for y in [1, 2, 3]:
		for s in 4:
			for d in range(1, GameClock.DAYS_PER_SEASON + 1):
				var base := Weather.on_day(y, s, d)
				if Climate.weather_at(y, s, d, Climate.VALLEY_FT) != base or Climate.weather_at(y, s, d, 3900) != base:
					same = false
	check(same, "the Valley floor (and Hetch Hetchy) have the park's weather, unchanged, three years over")
	Climate.arrive("curry_village", "yosemite_valley")
	GameClock.year = 2
	GameClock.season = GameClock.Season.WINTER
	GameClock.day = 10
	check(is_same(Weather.today(), Weather.park_today()), "on the Valley floor today() is the park's own weather")


func test_storm_by_height() -> void:
	var spring_rain := Vector3i(-1, -1, -1)
	var winter_snow := Vector3i(-1, -1, -1)
	for y in [1, 2, 3]:
		for d in range(1, 8):
			if spring_rain.x < 0 and Weather.on_day(y, GameClock.Season.SPRING, d).rain > 0.0:
				spring_rain = Vector3i(y, GameClock.Season.SPRING, d)
		for d in range(1, 29):
			if winter_snow.x < 0 and Weather.on_day(y, GameClock.Season.WINTER, d).snow > 0.0:
				winter_snow = Vector3i(y, GameClock.Season.WINTER, d)
	check(spring_rain.x > 0 and winter_snow.x > 0, "found an early spring rain and a winter snow")
	var up := Climate.weather_at(spring_rain.x, spring_rain.y, spring_rain.z, 8600)
	check(up.snow > 0.0 and up.rain == 0.0, "an early spring rain in the Valley is snow on Tuolumne")
	var mid := Climate.weather_at(spring_rain.x, spring_rain.y, spring_rain.z, 6100)
	check(mid.rain > 0.0 and mid.snow == 0.0, "...and still rain at Little Yosemite")
	var low := Climate.weather_at(winter_snow.x, winter_snow.y, winter_snow.z, 2000)
	check(low.rain > 0.0 and low.snow == 0.0, "a Valley snow is rain down the canyon at El Portal")
	var deep := Climate.weather_at(winter_snow.x, winter_snow.y, winter_snow.z, 8600)
	check(deep.snow >= Weather.on_day(winter_snow.x, winter_snow.y, winter_snow.z).snow, "and comes harder up high")
	var summer := true
	for d in range(1, 29):
		var w := Climate.weather_at(2, GameClock.Season.SUMMER, d, 8600)
		if w.snow > 0.0:
			summer = false
	check(summer, "no snow falls in summer, even on Tuolumne")


func test_snowpack() -> void:
	check(Climate.mountain_snow(1, GameClock.Season.SPRING, 1, 8600) > 0.6, "a new game's first spring morning: Tuolumne under the winter's snow")
	check(Seasons.snow_cover(1, GameClock.Season.SPRING, 1, "curry_village") == 0.0, "...and the Valley floor bare, as always")
	check(Seasons.snow_cover(2, GameClock.Season.WINTER, 20, "el_portal") == 0.0, "never snow lying at El Portal")
	var bare := {}
	for ft in [6100, 7200, 8600]:
		for s in [GameClock.Season.SPRING, GameClock.Season.SUMMER]:
			for d in range(1, 29):
				if not bare.has(ft) and Climate.mountain_snow(2, s, d, ft) < 0.05:
					bare[ft] = s * 28 + d
	print("      bare by (day of spring and summer): ", bare)
	check(bare.get(6100, 99) < bare.get(7200, 99) and bare.get(7200, 99) < bare.get(8600, 99), "the higher it is, the later the snow melts out")
	check(bare.get(7200, 0) >= 15 and bare.get(7200, 0) <= 28, "Glacier Point is bare late in spring, about when its road opens (%d)" % bare.get(7200, 0))
	check(bare.get(8600, 0) > 28 and bare.get(8600, 0) <= 40, "Tuolumne melts out early in summer, when the Tioga Road opens (%d)" % bare.get(8600, 0))
	check(Climate.mountain_snow(2, GameClock.Season.SUMMER, 20, 8600) == 0.0, "and late summer is bare")


func test_storm_hour() -> void:
	var same := true
	for d in range(1, 29):
		var wall := WallWeather.on_day("cathedral_peak", 2, GameClock.Season.SUMMER, d)
		if float(wall.storm_hour) != WallWeather.alpine_storm_hour(2, GameClock.Season.SUMMER, d):
			same = false
	check(same, "the high country's storm hour is the climbs' forecast")


func _storm_day() -> int:
	for d in range(1, 29):
		GameClock.day = d
		HighCountry._storm_date = Vector3i(-1, -1, -1)
		if HighCountry.storm_hour() > 0.0 and Climate.shower_strength() > 0.4:
			return d
	return -1


func test_places() -> void:
	GameClock.year = 2
	GameClock.season = GameClock.Season.SUMMER
	var d := _storm_day()
	check(d > 0, "found a summer day with a wet afternoon storm")
	var storm := HighCountry.storm_hour()
	GameClock.minutes = int((storm + 0.3) * 60.0)
	world._enter_region("tuolumne_meadows", "arrival")
	check(Climate.place == "tuolumne_meadows", "arriving sets where you are")
	check(Weather.shower() > 0.3 and Weather.rain_now() > 0.3, "the afternoon storm rains on Tuolumne")
	check(Seasons.wetness() > 0.3, "and wets the ground")
	check(Sound.bed_targets().amb_rain > 0.2, "and you hear it")
	world._enter_region("curry_village", "arrival")
	check(Weather.shower() == 0.0 and Weather.today().rain == 0.0, "while the Valley stays dry")
	GameClock.minutes = int((storm + 2.0) * 60.0)
	world._enter_region("tuolumne_meadows", "arrival")
	check(Weather.shower() == 0.0 and Seasons.wetness() > 0.0, "it passes, and the ground dries after")
	# a summer morning is cold up high, not in the Valley
	GameClock.minutes = 6 * 60
	check(Seasons.cold(), "you see your breath on a Tuolumne summer dawn")
	world._enter_region("curry_village", "arrival")
	check(not Seasons.cold(), "not on the Valley floor")
	# snow under foot: early spring of a new game, the Valley bare
	GameClock.year = 1
	GameClock.season = GameClock.Season.SPRING
	GameClock.day = 2
	GameClock.minutes = 12 * 60
	world._enter_region("tuolumne_meadows", "arrival")
	check(Seasons.snow_cover() > 0.5, "Tuolumne in early spring lies under snow")
	world._enter_region("curry_village", "arrival")
	check(Seasons.snow_cover() == 0.0, "while the Valley floor is green")
	# the sounds of the high country
	GameClock.season = GameClock.Season.SUMMER
	world._enter_region("tuolumne_meadows", "arrival")
	var calls := Sound.call_choices()
	check(calls.get("call_nutcracker", 0) > 0 and calls.get("call_pika", 0) > 0 and calls.get("call_marmot", 0) > 0,
		"nutcrackers, pikas and marmots call on Tuolumne")
	var up := Sound.bed_targets()
	world._enter_region("curry_village", "arrival")
	var down := Sound.bed_targets()
	check(up.amb_wind > down.amb_wind and up.amb_day < down.amb_day, "up high it's more wind and fewer songbirds")
	check(Sound.call_choices().get("call_nutcracker", 0) == 0, "no nutcrackers on the Valley floor")
	world._enter_region("hetch_hetchy", "arrival")
	check(Sound.call_choices().get("call_canyon_wren", 0) >= 3, "canyon wrens sing off Hetch Hetchy's walls")
	await get_tree().process_frame
