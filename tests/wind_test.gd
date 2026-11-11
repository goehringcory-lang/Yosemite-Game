extends Node
## Headless test of the wind (Wind): which art sways and how far, that a
## region's trees and plants get a swaying material and nothing else does,
## that it survives a change of season, and that the Wind setting and the
## weather set its strength.
## Run: godot --headless --path . res://tests/wind_test.tscn
## Exit code is the number of failed checks. Uses its own settings and save.

const TEST_PATH := "user://wind_test.cfg"
const AHW := "res://assets/sprites/ahwahnee/"

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
	SaveManager.save_path = "user://wind_test_save.json"
	SaveManager.delete_save()
	test_leans()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	await test_region()
	await test_strength()
	world.queue_free()
	SaveManager.delete_save()
	Settings.reset_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_leans() -> void:
	var pine := Wind.lean_for(AHW + "tree_ponderosa_a.png")
	var oak := Wind.lean_for(AHW + "tree_black_oak_a.png")
	check(pine > oak and oak >= Wind.TREE_LEAN_RANGE.x and pine <= Wind.TREE_LEAN_RANGE.y, "a tall pine leans farther than an oak, both within the range")
	check(Wind.lean_for(AHW + "seasons/tree_black_oak_a_fall.png") == oak, "the fall oak leans like the summer one")
	check(Wind.lean_for(AHW + "plant_fern_a.png") == Wind.PLANT_LEAN and Wind.lean_for(AHW + "plant_lupine.png") == Wind.PLANT_LEAN, "ferns and lupine sway as plants")
	check(Wind.lean_for(AHW + "tree_grizzly_giant.png") == Wind.GIANT_LEAN, "a giant sequoia hardly moves")
	for still: String in ["tree_snag.png", "tree_fallen_monarch.png", "plant_mushrooms.png", "rock_granite_a.png", "log_stump.png"]:
		check(Wind.lean_for(AHW + still) == 0.0, "%s stands still" % still)
	check(Wind.lean_for("res://assets/sprites/cars/car_red.png") == 0.0 and Wind.lean_for("res://icon.svg") == 0.0, "cars and art from elsewhere stand still")
	check(Wind.TREE_LEAN_RANGE.y * 1.5 <= 15.0, "the hardest lean fits in the room the shader leaves either side")


func _sway_of(sprite: Sprite2D) -> float:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return 0.0
	var value: Variant = mat.get_shader_parameter("sway")
	return float(value) if value != null else 0.0


func test_region() -> void:
	await world.go_to_region("el_capitan_meadow", "arrival")
	var trees := 0
	var plants := 0
	var wrong := ""
	for node in world.region.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null:
			continue
		var art := sprite.texture.resource_path
		var lean := Wind.lean_for(art)
		if art.get_file().begins_with("tree_") and lean > 0.0:
			trees += 1
		elif art.get_file().begins_with("plant_") and lean > 0.0:
			plants += 1
		if not is_equal_approx(_sway_of(sprite), lean) and wrong == "":
			wrong = "%s sways %s, should %s" % [art.get_file(), _sway_of(sprite), lean]
	check(trees > 20 and plants > 20, "El Capitan Meadow has trees and plants that sway (%d, %d)" % [trees, plants])
	check(wrong == "", "every sprite there sways as far as its art says, and the rest not at all" + ("" if wrong == "" else ": " + wrong))
	check(_sway_of(world.player.sprite) == 0.0, "the player doesn't sway")
	var ground := world.region.get_node("GroundArt") as Sprite2D
	check(ground.material is ShaderMaterial and (ground.material as ShaderMaterial).get_shader_parameter("gust_grass") != 0.0, "gusts cross the painted grass")
	# the seasons swap the art; the new picture still sways
	var oak: Sprite2D = null
	for node in world.region.find_children("TreeBlackOak*", "", true, false):
		oak = node.get_node("Sprite")
		break
	check(oak != null, "there is a black oak")
	if oak:
		var summer := oak.texture
		GameClock.season = GameClock.Season.FALL
		await get_tree().process_frame
		await get_tree().process_frame
		check(oak.texture != summer and _sway_of(oak) == Wind.lean_for(oak.texture.resource_path) and _sway_of(oak) > 0.0, "the oak in its fall leaves still sways")
		GameClock.season = GameClock.Season.SUMMER
		await get_tree().process_frame
		await get_tree().process_frame


func test_strength() -> void:
	var wind := world.get_node("Wind") as Wind
	check(wind != null, "World has a Wind")
	var fair := Wind.strength_now()
	check(fair >= 0.8 and fair <= 1.5, "on an ordinary day the wind is about 1 (%.2f)" % fair)
	var calm := {"snow": 0.0, "rain": 0.0, "clouds": 0.0}
	var storm := {"snow": 0.0, "rain": 1.0, "clouds": 1.0}
	Weather.today()
	var kept: Dictionary = Weather._today
	Weather._today = calm
	var still_day := Wind.strength_now()
	Weather._today = storm
	check(Wind.strength_now() > still_day + 0.5 and Wind.strength_now() <= 1.5, "it blows harder in a storm than under a clear sky")
	Weather._today = kept
	Settings.wind = false
	check(Wind.strength_now() == 0.0, "the Wind setting turned off stills the air")
	await get_tree().create_timer(2.5).timeout
	check(is_zero_approx(wind._strength), "and the trees come to rest over a moment")
	Settings.wind = true
	Wind.enabled = false
	check(Wind.strength_now() == 0.0, "Wind.enabled = false stills it too (for screenshots that must match)")
	Wind.enabled = true
