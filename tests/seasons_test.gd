extends Node
## Headless test of the seasons you can see: snow building up on the ground
## and on rooftops through the winter and melting in spring, boot prints in
## the snow, waterfalls that shrink through the summer and run dry in fall,
## Yosemite Creek and Mirror Lake drying with them, and Horsetail Fall's
## February firefall on El Capitan.
## Run: godot --headless --path . res://tests/seasons_test.tscn
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
	SaveManager.save_path = "user://seasons_test_save.json"
	SaveManager.delete_save()
	GameClock.year = 2
	test_snow_cover()
	test_flow()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	await test_snow_in_the_village()
	await test_prints()
	await test_falls()
	await test_mirror_lake()
	await test_horsetail()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_snow_cover() -> void:
	for season in [SPRING, SUMMER, FALL]:
		check(Seasons.snow_cover(2, season, 20) == 0.0, "no snow on the ground on day 20 of %s" % GameClock.SEASON_NAMES[season])
	var early := Seasons.snow_cover(2, WINTER, 2)
	var late := Seasons.snow_cover(2, WINTER, 26)
	check(late > early and late >= 0.5, "the snow builds up over the winter (%.2f on day 2, %.2f on day 26)" % [early, late])
	var any_snow := false
	for d in range(1, 29):
		var cover := Seasons.snow_cover(2, WINTER, d)
		if cover < 0.0 or cover > 1.0:
			check(false, "snow cover stays between 0 and 1 (winter %d)" % d)
		if Weather.on_day(2, WINTER, d).snow > 0.0:
			any_snow = true
			if d > 1:
				check(cover > Seasons.snow_cover(2, WINTER, d - 1) or cover == 1.0, "a snowy day adds to the snow (winter %d)" % d)
	check(any_snow, "it snows some days in winter")
	var thaw := Seasons.snow_cover(3, SPRING, 1)
	check(thaw > 0.0 and thaw < Seasons.snow_cover(2, WINTER, 28), "the winter's snow is melting on the first day of spring")
	check(Seasons.snow_cover(3, SPRING, 10) == 0.0, "and it's gone by day 10")
	check(Seasons.snow_cover(1, SPRING, 1) == 0.0, "a new game starts with no snow")
	check(Seasons.snow_cover(2, WINTER, 9) == Seasons.snow_cover(2, WINTER, 9), "the same date gives the same snow")


func test_flow() -> void:
	check(Seasons.waterfall_flow("yosemite", SPRING, 28) == 1.0, "Yosemite Falls roars at the end of spring")
	check(Seasons.waterfall_flow("yosemite", SUMMER, 14) < Seasons.waterfall_flow("yosemite", SUMMER, 1), "and shrinks through the summer")
	check(Seasons.waterfall_flow("yosemite", SUMMER, 28) == 0.0, "it's dry by the end of summer (September)")
	check(Seasons.waterfall_flow("yosemite", FALL, 10) == 0.0, "and through most of fall")
	check(Seasons.waterfall_flow("yosemite", FALL, 28) > 0.0, "until the first storms of November")
	check(Seasons.waterfall_flow("yosemite", WINTER, 10) > 0.3, "it runs again in winter")
	check(Seasons.waterfall_flow("ephemeral", SUMMER, 20) == 0.0 and Seasons.waterfall_flow("yosemite", SUMMER, 20) > 0.0, "the small falls off the rim dry up weeks before Yosemite Falls")
	for season in 4:
		for d in [1, 14, 28]:
			if Seasons.waterfall_flow("steady", season, d) <= 0.0:
				check(false, "Bridalveil never runs dry (%s %d)" % [GameClock.SEASON_NAMES[season], d])
	check(Seasons.waterfall_flow("steady", FALL, 10) < 0.3, "Bridalveil is thin in fall")
	check(Seasons.horsetail_running(WINTER, 3) and Seasons.horsetail_running(SPRING, 10), "Horsetail Fall runs in winter and early spring")
	check(not Seasons.horsetail_running(SPRING, 20) and not Seasons.horsetail_running(SUMMER, 10) and not Seasons.horsetail_running(FALL, 10), "and is dry the rest of the year")
	set_date(SPRING, 28)
	var roar := Sound.waterfall_level()
	set_date(FALL, 10)
	check(roar == 1.0 and Sound.waterfall_level() < 0.3, "the far-off falls are loud at the end of spring and quiet in fall")


func test_snow_in_the_village() -> void:
	set_date(WINTER, 26)
	world._enter_region("yosemite_village", "arrival")
	await get_tree().process_frame
	var region: Region = world.region
	var ground := region.get_node("GroundArt") as CanvasItem
	var snow: float = (ground.material as ShaderMaterial).get_shader_parameter("snow")
	check(is_equal_approx(snow, Seasons.snow_cover()) and snow > 0.0, "the painted ground holds the winter's snow")
	var capped := _capped(region)
	check(capped.size() > 10, "roofs, cars and rocks take a snow cap (%d)" % capped.size())
	var names := capped.map(func(s: Sprite2D) -> String: return s.texture.resource_path.get_file())
	check(names.any(func(n: String) -> bool: return n.begins_with("car_")), "the parked cars hold snow")
	check(not names.any(func(n: String) -> bool: return n.begins_with("tree_") or n.contains("glow")), "trees (drawn with their own snow) and lit windows don't")
	set_date(SUMMER, 10)
	await get_tree().process_frame
	await get_tree().process_frame
	check((ground.material as ShaderMaterial).get_shader_parameter("snow") == 0.0, "no snow on the ground in summer")
	check(_capped(region).is_empty(), "and the snow caps come off")


## The sprites wearing the snow cap material.
func _capped(region: Region) -> Array:
	return region.find_children("*", "Sprite2D", true, false).filter(func(s: Sprite2D) -> bool:
		return s.material is ShaderMaterial and (s.material as ShaderMaterial).shader == preload("res://assets/shaders/snow_cap.gdshader"))


func test_prints() -> void:
	set_date(WINTER, 26)
	var steps: Footfall
	for child in world.player.get_children():
		if child is Footfall:
			steps = child
	check(steps != null, "the player has footfalls")
	if steps == null:
		return
	steps._process(0.0)
	steps._prints.clear()
	steps._step(world.player.global_position)
	steps._step(world.player.global_position + Vector2(8, 0))
	check(steps._prints.size() == 2, "each step leaves a boot print in the snow")
	set_date(WINTER, 27)
	steps._process(0.0)
	check(steps._prints.is_empty(), "the prints are gone the next day")
	set_date(SUMMER, 10)
	steps._step(world.player.global_position)
	check(steps._prints.is_empty(), "and there are none in summer")


func test_falls() -> void:
	set_date(SPRING, 28)
	world._enter_region("yosemite_village", "arrival")
	await get_tree().process_frame
	var fall := _sprite("LowerYosemiteFall")
	var mist := _sprite("FallMist")
	check(fall != null and fall.material is ShaderMaterial, "Lower Yosemite Fall is dressed for its flow")
	if fall == null:
		return
	var mat := fall.material as ShaderMaterial
	check(mat.get_shader_parameter("flow") == 1.0 and not mat.get_shader_parameter("dry") and mist.visible, "full and misty at the end of spring")
	var ground := world.region.get_node("GroundArt").material as ShaderMaterial
	check(ground.get_shader_parameter("dry_amount") == 0.0, "the creek below runs full")
	set_date(SUMMER, 14)
	await get_tree().process_frame
	await get_tree().process_frame
	var mid: float = mat.get_shader_parameter("flow")
	check(mid > 0.0 and mid < 1.0, "thinner in midsummer (%.2f)" % mid)
	set_date(FALL, 10)
	await get_tree().process_frame
	await get_tree().process_frame
	check(mat.get_shader_parameter("dry") and not mist.visible and not fall.is_playing(), "a still, dry stain in fall")
	check(ground.get_shader_parameter("dry_amount") == 1.0, "and the creek bed is dry cobbles")
	var spray: AmbientFx
	for node in world.region.find_children("*", "CPUParticles2D", true, false):
		if node is AmbientFx and node.effect == "mist":
			spray = node
	check(spray != null and not spray.emitting, "no spray at the foot of a dry fall")
	var roar: SoundEmitter = spray.find_child("Sound_waterfall", false, false) if spray else null
	if roar:
		roar._refresh_level()
	check(roar != null and roar.volume_linear == 0.0, "and no roar")
	world._enter_region("bridalveil_fall", "arrival")
	await get_tree().process_frame
	var bridalveil := _sprite("BridalveilFall")
	check(bridalveil != null and not (bridalveil.material as ShaderMaterial).get_shader_parameter("dry"), "Bridalveil still runs in fall")
	set_date(SUMMER, 20)
	world._enter_region("four_mile_trailhead", "arrival")
	await get_tree().process_frame
	var sentinel := _sprite("SentinelFall")
	check(sentinel != null and (sentinel.material as ShaderMaterial).get_shader_parameter("dry"), "Sentinel Fall is dry by late summer")


## The animated drawing called [param node_name] (a Place can share its name).
func _sprite(node_name: String) -> AnimatedSprite2D:
	var found: Array[Node] = world.region.find_children(node_name, "AnimatedSprite2D", true, false)
	return found[0] if not found.is_empty() else null


func test_mirror_lake() -> void:
	set_date(SPRING, 20)
	world._enter_region("mirror_lake", "arrival")
	await get_tree().process_frame
	var ground := world.region.get_node("GroundArt").material as ShaderMaterial
	check(ground.get_shader_parameter("dry_amount") == 0.0, "Mirror Lake is full in spring")
	var lake := Vector2(1200, 760)
	check(not SeasonalFalls.dried_up(world.region, lake), "there's water to fish in")
	set_date(FALL, 10)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ground.get_shader_parameter("dry_amount") == 1.0 and ground.get_shader_parameter("dry_kind") == 1, "by fall it's a meadow")
	check(SeasonalFalls.dried_up(world.region, lake), "with nothing to fish in")


func test_horsetail() -> void:
	# A clear late-winter evening, and a snowy one.
	var clear := -1
	var snowy := -1
	for d in range(GameClock.HORSETAIL_DAYS.x, GameClock.HORSETAIL_DAYS.y + 1):
		var weather := Weather.on_day(GameClock.year, WINTER, d)
		if weather.snow == 0.0 and clear < 0:
			clear = d
		elif weather.snow > 0.0 and snowy < 0:
			snowy = d
	check(clear > 0, "there's a clear evening in late winter")
	set_date(WINTER, clear, 17, 30)
	check(GameClock.is_horsetail_time(), "Horsetail Fall is lit at 5:30 PM on a clear late-winter evening")
	set_date(WINTER, clear, 17, 0)
	check(not GameClock.is_horsetail_time(), "not before sunset")
	set_date(WINTER, clear, 18, 0)
	check(not GameClock.is_horsetail_time(), "and not after")
	if snowy > 0:
		set_date(WINTER, snowy, 17, 30)
		check(not GameClock.is_horsetail_time(), "not when it's snowing")
	set_date(WINTER, 5, 17, 30)
	check(not GameClock.is_horsetail_time(), "not in early winter")
	set_date(SUMMER, clear, 17, 30)
	check(not GameClock.is_horsetail_time(), "not in summer")
	set_date(WINTER, clear, 13)
	world._enter_region("el_capitan_meadow", "arrival")
	await get_tree().process_frame
	var fall := world.region.find_child("HorsetailFall", true, false) as HorsetailFall
	check(fall != null, "the El Capitan Meadow overlay places Horsetail Fall")
	if fall == null:
		return
	fall._process(0.0)
	check(fall.visible and fall.level == 0.0, "it runs (unlit) on a winter afternoon")
	set_date(WINTER, clear, 17, 20)
	world.hud.message_label.text = ""
	fall._process(0.1)
	check(world.hud.message_label.text == HorsetailFall.MESSAGE, "the sun finds the fall")
	fall._process(5.0)
	check(fall.level == 1.0, "and lights it up")
	set_date(WINTER, clear, 18, 0)
	fall._process(6.0)
	check(fall.level == 0.0, "then the light goes off it")
	set_date(SUMMER, 10, 17, 30)
	fall._process(0.0)
	check(not fall.visible, "nothing on the wall in summer")
	var sign := world.region.find_child("ElCapitanSign", true, false) as InfoSign
	check(sign != null and not sign.extra_active(), "the El Capitan sign reads as usual in summer")
	set_date(WINTER, 3, 12)
	check(sign != null and "Horsetail Fall" in sign.current_text(), "and tells you about Horsetail Fall in winter")
