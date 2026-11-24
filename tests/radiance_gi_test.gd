extends Node
## Tests the 2D Radiance Cascades Global Illumination system
## (scripts/world/radiance_gi.gd): pipeline attachment, layer ordering, occluder
## and emitter discovery outdoors and indoors, daytime AO and golden-hour
## bounce uniforms, NightLight coordination, and clean disable when
## LitSprites.enabled is false (SHOT_UNLIT=1 / Low graphics).
## Run: godot --headless --path . res://tests/radiance_gi_test.tscn

const SUMMER := 1

var world: Node
var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _frames(n := 4) -> void:
	for i in n:
		await get_tree().process_frame


func set_date(season: int, day: int, hour: float) -> void:
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = roundi(hour * 60.0)
	GameClock.paused = true


func _ready() -> void:
	SaveManager.save_path = "user://radiance_gi_test_save.json"
	SaveManager.delete_save()
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await _frames(4)

	await test_pipeline_and_layers()
	await test_outdoor_day_and_night()
	await test_indoors()
	await test_disable_toggle()

	LitSprites.enabled = true
	RadianceGI.enabled = true
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_pipeline_and_layers() -> void:
	var gi := world.get_node_or_null("RadianceGI") as RadianceGI
	check(gi != null, "World attaches RadianceGI")
	if gi == null:
		return
	var atmos := world.get_node_or_null("Atmosphere") as CanvasLayer
	check(gi.layer == 0, "RadianceGI sits on CanvasLayer 0 (within AirGlow bloom range)")
	check(atmos != null and gi.layer < atmos.layer, "RadianceGI composites before Atmosphere (layer %d < %d)" % [gi.layer, atmos.layer if atmos else -1])
	if RadianceGI.active():
		check(gi._built, "GI pipeline builds on High / Forward+")
		check(gi._viewports.size() == 16, "pipeline builds all 16 passes (scene + seed + 8 JFA + SDF + 4 cascades + resolve = %d)" % gi._viewports.size())


func test_outdoor_day_and_night() -> void:
	var gi := world.get_node("RadianceGI") as RadianceGI
	set_date(SUMMER, 14, 12.0)
	await world.go_to_region("curry_village", "arrival")
	await _frames(4)
	if not RadianceGI.active():
		check(not gi.visible, "RadianceGI stays hidden when inactive")
		return
	check(gi.visible, "RadianceGI is visible outdoors in Curry Village")
	check(gi._occluders.size() >= 10, "collects upright occluder footprints (%d)" % gi._occluders.size())
	check(gi._lights.size() >= 3, "collects NightLight emitters (%d)" % gi._lights.size())
	var day_ao: float = gi._composite_mat.get_shader_parameter("ao_strength")
	check(day_ao > 0.3, "enables daytime sky-occlusion AO outdoors (%.2f)" % day_ao)

	set_date(SUMMER, 14, 19.5)
	await _frames(4)
	var golden_bounce: float = gi._composite_mat.get_shader_parameter("bounce_strength")
	check(golden_bounce > 0.08, "enables golden-hour indirect bounce at sunset (%.2f)" % golden_bounce)

	set_date(SUMMER, 14, 22.0)
	await _frames(4)
	var night_gi: float = gi._composite_mat.get_shader_parameter("gi_strength")
	var night_ao: float = gi._composite_mat.get_shader_parameter("ao_strength")
	check(night_gi > 0.9, "boosts emissive GI strength at night (%.2f)" % night_gi)
	check(night_ao < 0.05, "fades daytime sky AO out at night (%.2f)" % night_ao)


func test_indoors() -> void:
	var gi := world.get_node("RadianceGI") as RadianceGI
	set_date(SUMMER, 14, 12.0)
	await world.go_to_region("ahwahnee_great_lounge", "door")
	await _frames(4)
	if not RadianceGI.active():
		return
	var indoor_ao: float = gi._composite_mat.get_shader_parameter("ao_strength")
	check(indoor_ao == 0.0, "no outdoor sky AO indoors")
	check(gi._room_windows != null, "hooks RoomWindows for indoor daylight emission")
	set_date(SUMMER, 14, 22.0)
	await _frames(4)
	var indoor_gi: float = gi._composite_mat.get_shader_parameter("gi_strength")
	check(indoor_gi > 0.85, "hearth and lamps drive indoor night GI (%.2f)" % indoor_gi)


func test_disable_toggle() -> void:
	var gi := world.get_node("RadianceGI") as RadianceGI
	LitSprites.enabled = false
	await _frames(3)
	check(not RadianceGI.active(), "SHOT_UNLIT / LitSprites.enabled=false disables RadianceGI")
	check(not gi.visible, "composite hides when disabled")
	var all_disabled := true
	for vp in gi._viewports:
		if vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			all_disabled = false
	check(all_disabled, "all SubViewports pause when disabled")
	LitSprites.enabled = true
	await _frames(3)
	if RadianceGI.active():
		check(gi.visible, "re-enabling LitSprites restores RadianceGI")
