extends Node
## Headless test of the outdoor light: the sun's seasonal day (long summer
## evenings, short winter days), its height and the way shadows fall, the day
## and night tint following it, things casting shadows that swing with the
## sun, the painted street lamps and fires giving real light after dark, the
## player's lantern, and the morning mist burning off.
## Run: godot --headless --path . res://tests/lighting_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const SPRING := GameClock.Season.SPRING
const SUMMER := GameClock.Season.SUMMER
const FALL := GameClock.Season.FALL
const WINTER := GameClock.Season.WINTER

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func set_date(season: int, day: int, hour := 12, minute := 0) -> void:
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = hour * 60 + minute


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://lighting_test_save.json"
	SaveManager.delete_save()
	GameClock.year = 2
	test_sun_times()
	test_sun_path()
	test_gradient()
	test_mist()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	await test_shadows()
	await test_lamps()
	await test_indoors()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_sun_times() -> void:
	var summer := Sun.times(SUMMER, 14)
	var winter := Sun.times(WINTER, 14)
	check(summer.y > 20.0 and winter.y < 17.5, "the sun sets after 8 PM in summer, before 5:30 PM in winter (%.2f, %.2f)" % [summer.y, winter.y])
	check(summer.y - summer.x > winter.y - winter.x + 3.0, "summer days are hours longer than winter days")
	# No jumps from one season into the next.
	var worst := 0.0
	for season in 4:
		var last := Sun.times(season, GameClock.DAYS_PER_SEASON)
		var first := Sun.times((season + 1) % 4, 1)
		worst = maxf(worst, (last - first).abs().x + (last - first).abs().y)
	check(worst < 0.2, "sunrise and sunset slide smoothly between seasons (worst step %.2f h)" % worst)
	# Horsetail Fall's firefall comes as the winter sun goes down.
	set_date(WINTER, 22)
	var sunset := Sun.times().y
	var fire := GameClock.HORSETAIL_HOUR + (GameClock.HORSETAIL_MINUTE + GameClock.HORSETAIL_MINUTES) / 60.0
	check(absf(sunset - fire) < 0.6, "Horsetail's firefall ends near the late-winter sunset (%.2f vs %.2f)" % [fire, sunset])


func test_sun_path() -> void:
	set_date(SUMMER, 14, 12)
	var noon := Sun.height()
	set_date(WINTER, 14, 12)
	var winter_noon := Sun.height()
	check(noon > 60.0 and winter_noon < 40.0 and winter_noon > 20.0, "the sun stands high at a summer noon, low in winter (%.0f, %.0f degrees)" % [noon, winter_noon])
	set_date(SUMMER, 14, 7)
	check(Sun.direction().x > 0.8, "the morning sun is in the east")
	set_date(SUMMER, 14, 19)
	check(Sun.direction().x < -0.8, "the evening sun is in the west")
	set_date(SUMMER, 14, 23)
	check(Sun.height() < -12.0 and Sun.night() > 0.99 and Sun.daylight() == 0.0, "it's full night at 11 PM in summer")
	var t := Sun.times()
	GameClock.minutes = int((t.y + 0.15) * 60.0)
	check(Sun.alpenglow() > 0.8, "alpenglow lights the granite just after sunset (%.2f)" % Sun.alpenglow())
	GameClock.minutes = int((t.y - 0.5) * 60.0)
	check(Sun.golden() > 0.5, "the last half hour of sun is golden (%.2f)" % Sun.golden())
	check(Sun.moon(GameClock.FULL_MOON_DAY) > 0.99 and Sun.moon(GameClock.FULL_MOON_DAY + 14) < 0.01, "the moon is full on day 14 and new two weeks on")


func test_gradient() -> void:
	# Sunrise and sunset land on the gradient's own, whatever the season.
	for season in 4:
		set_date(season, 10)
		var t := Sun.times()
		check(absf(Sun.gradient_progress(t.x) - Sun.GRADIENT_SUNRISE) < 0.001 and absf(Sun.gradient_progress(t.y) - Sun.GRADIENT_SUNSET) < 0.001,
			"%s sunrise and sunset line up with the day and night colours" % GameClock.SEASON_NAMES[season])
	# Winter evenings are dark by 7 PM, summer evenings still light.
	set_date(WINTER, 14, 19)
	var winter_evening := Sun.gradient_progress()
	set_date(SUMMER, 14, 19)
	var summer_evening := Sun.gradient_progress()
	check(winter_evening > Sun.GRADIENT_SUNSET + 0.03 and summer_evening < Sun.GRADIENT_SUNSET, "7 PM is after dark in winter, before sunset in summer")


func test_mist() -> void:
	var seen := 0
	for d in range(1, 29):
		set_date(FALL, d)
		var t := Sun.times()
		GameClock.minutes = int((t.x + 0.3) * 60.0)
		var dawn := ValleyAir.mist_now()
		GameClock.minutes = 13 * 60
		var afternoon := ValleyAir.mist_now()
		if dawn > 0.0:
			seen += 1
		if afternoon > 0.0:
			check(false, "the mist has burned off by 1 PM (fall day %d)" % d)
			return
	check(seen >= 6, "mist lies on many fall mornings (%d of 28)" % seen)


func test_shadows() -> void:
	set_date(SUMMER, 14, 8)
	await world.go_to_region("el_capitan_meadow", "arrival")
	await _frames(3)
	var shadows := world.region.get_node_or_null("SunShadows") as SunShadows
	check(shadows != null, "an outdoor region gets cast shadows")
	if shadows == null:
		return
	check(shadows.get_index() < world.region.entities.get_index(), "the shadows lie under the people and trees")
	check(shadows._casters.size() > 200, "trees, rocks, plants and signs cast shadows (%d)" % shadows._casters.size())
	check(world.player.get_node("Sprite") in shadows._casters, "the player casts a shadow")
	check(shadows.visible and shadows._lean.x < -0.5, "morning shadows fall long to the west")
	set_date(SUMMER, 14, 12)
	await _frames(2)
	check(shadows._lean.length() < 0.5 and shadows._lean.y < 0.0, "midday shadows are short and fall north")
	set_date(SUMMER, 14, 18)
	await _frames(2)
	check(shadows._lean.x > 0.5, "evening shadows fall to the east")
	set_date(SUMMER, 1, 23)
	await _frames(2)
	check(not shadows.visible, "no shadows on a dark, moonless night")
	set_date(SUMMER, GameClock.FULL_MOON_DAY, 23)
	await _frames(2)
	check(shadows.visible or Weather.today().clouds > 0.6, "the full moon casts faint shadows")


func test_lamps() -> void:
	set_date(SUMMER, 1, 12)
	await world.go_to_region("yosemite_village", "arrival")
	await _frames(3)
	var lamps := 0
	for sprite in world.region.entities.find_children("*", "Sprite2D", true, false):
		if sprite.texture and sprite.texture.resource_path.ends_with("lamp_wrought.png"):
			if not sprite.get_parent().find_children("*", "NightLight", true, false).is_empty():
				lamps += 1
	check(lamps >= 8, "the village street lamps give light (%d)" % lamps)
	var lantern := world.player.get_node_or_null("Lantern") as NightLight
	check(lantern != null, "the player carries a lantern")
	check(lantern != null and not lantern.visible, "the lantern is out at noon")
	GameClock.minutes = 23 * 60
	await _frames(4)
	check(lantern != null and lantern.energy > 0.3, "the lantern is lit at 11 PM")


func test_indoors() -> void:
	await world.go_to_region("curry_store", "door")
	await _frames(3)
	check(world.region.get_node_or_null("SunShadows") == null, "no sun shadows indoors")
	var lantern := world.player.get_node_or_null("Lantern") as NightLight
	check(lantern != null and lantern.energy < 0.05, "the lantern stays out indoors")
	GameClock.minutes = 12 * 60


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
