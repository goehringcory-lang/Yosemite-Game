extends Node
## Headless test of the ground and people reacting to the weather: wet ground
## and puddles in the rain (Seasons.wetness and the ground shader's uniforms),
## tracks in the snow (Footprints) and breath in the cold (Breath, Seasons.cold).
## Run: godot --headless --path . res://tests/weather_fx_test.tscn
## Exit code is the number of failed checks. Uses its own save.

## Dates from the weather table (Weather.on_day, year 1): spring day 2 rains
## and day 3 is dry; spring day 4 follows a dry day. Winter day 14 has deep
## snow on a clear day.
const RAIN_DAY := 2
const DRY_DAY := 4
const SNOW_DAY := 14

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://weather_fx_test_save.json"
	SaveManager.delete_save()
	GameClock.year = 1
	test_wetness()
	test_cold()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	await test_ground()
	await test_tracks()
	await test_breath()
	world.queue_free()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _set_day(season: int, day: int, hour: float) -> void:
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = int(hour * 60.0)


func test_wetness() -> void:
	_set_day(GameClock.Season.SPRING, RAIN_DAY, 12)
	check(Weather.today().rain > 0.0, "the rainy test day rains")
	check(Seasons.wetness() >= 0.55, "the ground is soaked while it rains")
	_set_day(GameClock.Season.SPRING, RAIN_DAY + 1, 6.5)
	var dawn := Seasons.wetness()
	check(Weather.today().rain == 0.0 and dawn > 0.5, "the morning after rain is still wet at dawn")
	GameClock.minutes = 9 * 60
	var mid := Seasons.wetness()
	check(mid > 0.0 and mid < dawn, "the puddles shrink through the morning")
	GameClock.minutes = 12 * 60
	check(Seasons.wetness() == 0.0, "dry by noon the day after")
	_set_day(GameClock.Season.SPRING, DRY_DAY, 7)
	check(Seasons.wetness() == 0.0, "dry after a dry day")
	_set_day(GameClock.Season.WINTER, SNOW_DAY - 1, 12)
	check(Seasons.wetness() == 0.0, "snow doesn't make puddles")


func test_cold() -> void:
	_set_day(GameClock.Season.WINTER, SNOW_DAY, 14)
	check(Seasons.cold(), "cold all winter")
	_set_day(GameClock.Season.SUMMER, 10, 6)
	check(not Seasons.cold(), "never cold in summer")
	_set_day(GameClock.Season.FALL, 5, 6.5)
	check(Seasons.cold(), "a fall dawn is cold")
	GameClock.minutes = 14 * 60
	check(not Seasons.cold(), "a fall afternoon is not")


func _ground_mat() -> ShaderMaterial:
	var ground := world.region.get_node_or_null("GroundArt") as CanvasItem
	return ground.material as ShaderMaterial if ground else null


func test_ground() -> void:
	_set_day(GameClock.Season.SPRING, RAIN_DAY, 12)
	await world.go_to_region("curry_village", "arrival")
	for i in 3:
		await get_tree().process_frame
	var mat := _ground_mat()
	check(mat != null, "Curry Village's ground has the seasonal material")
	if mat == null:
		return
	for child in world.region.get_children():
		if child.has_method("apply_wet"):
			child.apply_wet()
	check(float(mat.get_shader_parameter("wet")) >= 0.55, "the ground shader is told it's wet in the rain")
	check(float(mat.get_shader_parameter("rain")) > 0.0, "and that rain is falling (rings)")
	_set_day(GameClock.Season.SPRING, RAIN_DAY + 1, 12)
	for child in world.region.get_children():
		if child.has_method("apply"):
			child.apply()
		if child.has_method("apply_wet"):
			child.apply_wet()
	check(float(mat.get_shader_parameter("wet")) == 0.0 and float(mat.get_shader_parameter("rain")) == 0.0, "and dry again by the next noon")


func _walk(from: Vector2, to: Vector2) -> void:
	var steps := int(from.distance_to(to) / 2.0)
	for i in steps:
		world.player.global_position = from.lerp(to, float(i + 1) / steps)
		await get_tree().process_frame


func test_tracks() -> void:
	var tracks := world.get_node_or_null("Footprints") as Footprints
	check(tracks != null, "World has footprints")
	if tracks == null:
		return
	_set_day(GameClock.Season.SUMMER, 10, 12)
	await get_tree().process_frame
	var at: Vector2 = world.player.global_position
	await _walk(at, at + Vector2(80, 0))
	check(tracks.print_count() == 0 and not tracks.visible, "no tracks without snow")
	_set_day(GameClock.Season.WINTER, SNOW_DAY, 10)
	await get_tree().process_frame
	at = world.player.global_position
	var before := tracks.print_count()
	await _walk(at, at + Vector2(-90, 0))
	var made := tracks.print_count() - before
	# (people walking about leave theirs too, so at least the player's)
	check(made >= 9, "walking 90 px through snow leaves a print a stride (%d)" % made)
	check(tracks.visible, "the tracks show in the snow")
	await world.go_to_region("yosemite_village", "arrival")
	await get_tree().process_frame
	# what the people about the Valley left since arriving is fine; the
	# player's old trail is gone
	check(tracks.print_count() < before + made, "a new area starts with fresh snow")


func test_breath() -> void:
	var breath := world.get_node_or_null("Breath") as Breath
	check(breath != null, "World has breath")
	if breath == null:
		return
	_set_day(GameClock.Season.WINTER, SNOW_DAY, 10)
	await get_tree().process_frame
	breath.exhale(world.player.global_position, Vector2.LEFT)
	await get_tree().process_frame
	check(breath.puff_count() >= 3, "a breath is a little puff of blobs")
	var t := 0.0
	while breath.puff_count() > 0 and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(breath.puff_count() == 0, "and it fades away")
	_set_day(GameClock.Season.SUMMER, 10, 13)
	await get_tree().process_frame
	breath.exhale(world.player.global_position, Vector2.LEFT)
	await get_tree().process_frame
	check(breath.puff_count() == 0, "no breath on a summer afternoon")
