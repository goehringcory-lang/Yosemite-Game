extends Node
## Checks the seams where one outdoor region's road runs off the map edge
## onto the next (see Seam): every walking seam on the Valley floor lines up
## edge to edge, the next region is laid beside this one as the player comes
## near, and walking over the edge carries on into it with no fade, no pause
## and nothing jumping on screen, and back again.
## Run: godot --headless --path . res://tests/seams_test.tscn
## Exit code is the number of failed checks.

## Every road and trail that walks straight from one Valley floor area into
## the next: region -> its exits that are seams.
const SEAMS := {
	"yosemite_village": ["NorthsideWest", "NorthsideEast", "SouthsideWest", "SouthsideEast"],
	"leidig_meadow": ["ToVillage", "ToElCapitan"],
	"el_capitan_meadow": ["ToLeidigMeadow", "NorthsideDriveWest"],
	"big_oak_flat_junction": ["ToElCapitan"],
	"bridalveil_fall": ["ToFourMile", "ToTunnelView"],
	"tunnel_view": ["ToBridalveil"],
	"four_mile_trailhead": ["ToVillage", "ToBridalveil"],
	"housekeeping_camp": ["ToVillage", "ToCurry"],
	"curry_village": ["WestRoad", "EastRoad", "HomesteadGate"],
	"upper_pines": ["ToCurry", "ToHappyIsles"],
	"happy_isles": ["ToUpperPines", "ToTenayaCreek"],
	"tenaya_creek": ["ToHappyIsles", "ToMirrorLake"],
	"mirror_lake": ["ToTenayaCreek", "ToCrowsCamp"],
	"crows_camp": ["ToMirrorLake"],
	"ahwahnee_meadow": ["ToVillage", "ToAhwahnee"],
	"the_ahwahnee": ["ToStonemanBridge", "NorthsideDriveWest"],
	"ahwahnee_trail": ["ToHomestead", "ToAhwahnee"],
	"lamon_homestead": ["ToCurryVillage", "NorthToAhwahnee"],
}

var failures := 0


## How far the view lags the drawn player, as of the last frame drawn.
var _lag := Vector2.ZERO
var _camera: Camera2D


## Notes the lag once everything has moved this frame (this runs last).
func _process(_delta: float) -> void:
	if is_instance_valid(_camera):
		_lag = _camera.get_screen_center_position() - _camera.global_position


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	process_priority = 1 << 30
	SaveManager.save_path = "user://seams_test_save.json"
	SaveManager.delete_save()
	_check_all_seams()
	Engine.time_scale = 4.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	await world.go_to_region("yosemite_village", "west_road")
	# Arriving by a fade beside an edge, the camera is already settled there.
	var camera: Camera2D = world.player.get_node("Camera")
	var settled := camera.get_screen_center_position()
	for i in 10:
		await get_tree().process_frame
	check(camera.get_screen_center_position().distance_to(settled) < 2.0,
			"the camera doesn't drift after arriving by the edge (%s -> %s)" % [settled, camera.get_screen_center_position()])
	check(world.seam != null and world.seam.neighbor.region_id == "leidig_meadow", "arriving by the edge lays the next region out at once")
	check(camera.limit_left < 0, "and the camera can look over the edge")
	_check_blend(world, true)
	await _walk_across(world, "move_left", "leidig_meadow")
	await _walk_across(world, "move_right", "yosemite_village")
	# A north-south seam: from the hotel down the trail by Stoneman Bridge.
	await world.go_to_region("the_ahwahnee", "south_entry")
	await _walk_across(world, "move_down", "ahwahnee_trail")
	_check_blend(world, true)
	var ahwahnee: Region = world.seam.neighbor
	world.seam.close()
	check(Seam._grounds(ahwahnee).all(func(g: Sprite2D) -> bool: return not g.material.get_shader_parameter("seam_on")),
			"closing a seam puts the ground's edge back")
	world.seam.open(world.region)

	# A drive that takes clock time still fades.
	check(Seam.candidates(load("res://scenes/regions/big_oak_flat_junction.tscn").instantiate()).all(
			func(e: RegionExit) -> bool: return e.minutes == 0), "roads that take clock time aren't seams")

	world.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	print("%d failure(s)" % failures)
	get_tree().quit(failures)


## Each listed exit meets the next map edge to edge, and the seam back the
## other way lines up with it.
func _check_all_seams() -> void:
	var regions := {}
	for id in SEAMS:
		regions[id] = (load("res://scenes/regions/%s.tscn" % id) as PackedScene).instantiate()
	for id in SEAMS:
		var region: Region = regions[id]
		var found := Seam.candidates(region).map(func(e: RegionExit) -> String: return e.name)
		for exit_name in SEAMS[id]:
			var exit: RegionExit = region.find_child(exit_name, true, false)
			check(exit != null and exit_name in found, "%s: %s is a walking exit on the map edge" % [id, exit_name])
			if exit == null or not regions.has(exit.target_region):
				continue
			var seam := Seam.make(region, exit, regions[exit.target_region])
			check(seam != null, "%s: %s meets %s edge to edge" % [id, exit_name, exit.target_region])
			if seam:
				# the neighbor's edge tucks under this one by the overlap,
				# and the way back lands on the same spot
				check(is_equal_approx(seam._overlap(), Seam.OVERLAP), "%s: %s overlaps by %d px" % [id, exit_name, Seam.OVERLAP])
				var back := seam.reversed(region)
				check(back.offset == -seam.offset and is_equal_approx(back._overlap(), Seam.OVERLAP),
						"%s: %s lines up with the seam back" % [id, exit_name])
	for region: Region in regions.values():
		region.free()


## The grounds on both sides of the open seam blend into each other.
func _check_blend(world: Node, on: bool) -> void:
	var grounds := Seam._grounds(world.region) + Seam._grounds(world.seam.neighbor)
	check(grounds.size() >= 2 and grounds.all(func(g: Sprite2D) -> bool: return g.material.get_shader_parameter("seam_on") == on),
			"%s and %s: the grounds blend over the seam" % [world.region.region_id, world.seam.neighbor.region_id])


## Walks [param action] from where the player stands until they're in
## [param into], checking the walk never stops or fades.
func _walk_across(world: Node, action: String, into: String) -> void:
	var from: String = world.region.region_id
	var player: Player = world.player
	var camera: Camera2D = player.get_node("Camera")
	_camera = camera
	for i in 600:
		if world.seam and world.seam.neighbor.region_id == into:
			break
		await get_tree().process_frame
	check(world.seam != null and world.seam.neighbor.region_id == into and world.seam.neighbor.is_inside_tree(),
			"%s: %s is laid beside it near the edge" % [from, into])
	if world.seam == null:
		return
	var shift: Vector2 = -world.seam.offset
	var faded := false
	var stopped := false
	var jump := 0.0
	var crossed := false
	# How far the view lags the player, and how much that changes from one
	# frame to the next walking along before the seam, and over it.
	var lag := Vector2.INF
	var settled := 0.0
	var lurch := 0.0
	Input.action_press(action)
	for i in 900:
		var before: Vector2 = camera.get_screen_center_position()
		var was: String = world.region.region_id
		await get_tree().process_frame
		faded = faded or world.hud.fade.color.a > 0.0
		stopped = stopped or not player.can_act or GameClock.paused
		if world.region.region_id != was:
			crossed = true
			# The camera hands over as this frame is drawn (after this
			# signal), so look a frame on: two frames' steps, in its new
			# pixels.
			await get_tree().process_frame
			jump = (camera.get_screen_center_position() - (before + shift)).length()
			# the camera's lag on the player carries over (two frames on)
			lurch = (_lag - lag).length()
			# walk on a little way into the new region
			for j in 20:
				await get_tree().physics_frame
			break
		var now := _lag
		if lag != Vector2.INF and i > 2:
			settled = maxf(settled, (now - lag).length())
		lag = now
	Input.action_release(action)
	check(crossed and world.region.region_id == into, "%s: walking on leads into %s" % [from, into])
	check(not faded, "%s -> %s: no fade" % [from, into])
	check(not stopped, "%s -> %s: the player never stops and the clock runs on" % [from, into])
	check(jump < 24.0, "%s -> %s: the view doesn't jump over the seam (%.1f px)" % [from, into, jump])
	check(lurch < 2.0 * settled + 3.0, "%s -> %s: the view glides on without a lurch (its lag on the player changes by %.1f px over the seam, up to %.1f a frame before)" % [from, into, lurch, settled])
	check(player.get_parent() == world.region.entities and world.region.position == Vector2.ZERO,
			"%s: the player is in its Entities and it sits at the origin" % into)
	check(world.seam != null and world.seam.neighbor.region_id == from and world.seam.neighbor.is_inside_tree(),
			"%s: %s stays laid out behind" % [into, from])
	check(world.region.get_bounds().has_point(world.region.to_local(player.global_position)), "%s: the player stands on its map" % into)
