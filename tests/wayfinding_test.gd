extends Node
## Checks the signposts at the screen's edge on the Valley floor
## (Wayfinding): the landmarks point the right way from where you stand, the
## ones towering right over an area get no sign, a "?" points toward an area
## you haven't walked into and goes once you have, and the setting and a
## conversation hide them.
## Run: godot --headless --path . res://tests/wayfinding_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _signs(world: Node) -> Wayfinding:
	for node in world.hud.find_children("*", "Control", true, false):
		if node is Wayfinding:
			return node
	return null


## Waits for the place-name banner to go and the signs to settle.
func _settle() -> void:
	for i in 400:
		await get_tree().process_frame


func _ready() -> void:
	SaveManager.save_path = "user://wayfinding_test_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Settings.wayfinding = true
	Engine.time_scale = 4.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var signs := _signs(world)
	check(signs != null, "the HUD has signposts")

	# Pure geometry: Half Dome is east of the Village, El Capitan west.
	var village: Region = (load("res://scenes/regions/yosemite_village.tscn") as PackedScene).instantiate()
	var here := Wayfinding.lonlat_of(village, village.get_bounds().get_center())
	check(here.distance_to(village.geo_anchor) < 0.0001, "the middle of a hand-made area is its geo anchor")
	var half_dome := Wayfinding.meters_between(here, Wayfinding.LANDMARKS[0].at)
	var el_cap := Wayfinding.meters_between(here, Wayfinding.LANDMARKS[1].at)
	check(half_dome.x > 3000.0 and absf(half_dome.y) < half_dome.x, "Half Dome is a few km east of the Village (%s m)" % half_dome.round())
	check(el_cap.x < -3000.0, "El Capitan is a few km west of the Village (%s m)" % el_cap.round())
	village.free()

	await world.go_to_region("yosemite_village", "arrival")
	await _settle()
	check(signs._signs.has("Half Dome") and signs._signs["Half Dome"].dir.x > 0.9, "from the Village a sign points east to Half Dome")
	var unknown := signs._signs.keys().filter(func(k: String) -> bool: return k.begins_with("?"))
	check(not unknown.is_empty(), "and a ? points somewhere you haven't been (%s)" % [unknown])
	check(signs._alpha > 0.9, "the signs are showing")

	# El Capitan towers over its meadow: no sign for it there.
	await world.go_to_region("el_capitan_meadow", "arrival")
	await _settle()
	check(not signs._signs.has("El Capitan"), "no El Capitan sign in El Capitan Meadow")
	check(signs._signs.has("Half Dome"), "but Half Dome, far up the Valley, has one")

	# Walk into an area and its ? goes. (From the meadow's east end, Leidig
	# is near enough to point to.)
	world.player.global_position = world.region.to_global(Vector2(1600, 720))
	await _settle()
	var key := Discoveries.key_for("leidig_meadow", "Leidig Meadow")
	var toward_leidig := "?" + key
	check(signs._signs.has(toward_leidig), "a ? points east toward Leidig Meadow, not yet walked into (%s, at %s)" % [signs._signs.keys(), world.region.to_local(world.player.global_position)])
	Discoveries.found[key] = true
	await _settle()
	check(not signs._signs.has(toward_leidig), "once you've been there, its ? is gone")

	# The setting turns them off.
	Settings.wayfinding = false
	await _settle()
	check(signs._alpha == 0.0 and signs._signs.is_empty(), "the Signposts setting hides them")
	Settings.wayfinding = true

	# Indoors there are none.
	await world.go_to_region("welcome_center", "door")
	await _settle()
	check(signs._alpha == 0.0, "no signposts indoors")

	world.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	print("%d failure(s)" % failures)
	get_tree().quit(failures)
