extends Node
## Uses every way between two places in the real World, one after another,
## the way a player would: walks into each exit at the edge of every region
## (a seam, a road or a trail), goes through every gate and building door,
## and keeps holding the direction they were walking for a moment after
## arriving. For each one it checks the move is one clean change of place:
##  - it lands in the region the way leads to, on the spot it names (not
##    shoved off it because the spot is inside something solid);
##  - the place changes once, not twice (no exit that fires again as you
##    arrive, and no arrival that walks you straight back out);
##  - the landing spot doesn't stand inside another exit, so nothing fires
##    the moment the player stirs;
##  - where you land is beside a way back to where you came from, so going
##    back puts you where you left;
##  - across a seam (see Seam) the player and the view carry on with no
##    jump on screen, and an edge that is a seam is always walked across,
##    even when the region past it wasn't laid out in time.
## It prints one line per way with how long the slowest frame took, as a
## guide to stutter (headless, so loading and set-up only, no drawing).
## Run: godot --headless --path . res://tests/transitions_test.tscn
## Exit code is the number of failed checks.

const REGIONS_DIR := "res://scenes/regions/"
## Physics ticks to wait for a way to fire after walking into it.
const WALK_TICKS := 240
## Physics ticks to keep walking on after arriving (about 0.7 s).
const HOLD_TICKS := 42
## The most the player may move on screen in one frame walking over a seam
## (at Engine.time_scale 2: the walk itself is a few pixels a frame, and the
## view easing over as a seam opens up is up to about 25, more on a slow
## frame; a cut moves it hundreds).
const JUMP_PX := 96.0
## How far back from a seam the walk to it starts.
const SEAM_RUN := 200.0
## How far from its spot a landing may end up (the world nudges a spot just
## inside a bush out of it, which is a pop on screen if it's far).
const LANDING_SLACK := 12.0
## A way back counts as beside the landing spot within this many pixels.
const BACK_NEAR := 320.0
## A ways in that are known to be one way, or land away from the way back on
## purpose: "region/way".
const ONE_WAY := {
	# one bridge, crossed once, north to south (see README, "one way")
	"el_capitan_meadow/ToElCapBridge": true,
}

var failures := 0
var world: Node
var player: Player
## Region ids, in order, from World.region_changed since the last clear.
var changes: Array[String] = []
## How many of those were cuts (a door, a fade, a jump to a spot) rather
## than walking over a seam.
var cuts := 0
## The longest frame, in ms, since the last clear.
var worst_frame := 0.0
var _last_tick := 0
## The player's spot on screen and its biggest jump between two frames.
var _screen_at := Vector2.INF
var worst_jump := 0.0
var _watch_screen := false
## One line per way, printed at the end.
var report: Array[String] = []


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_tick != 0:
		worst_frame = maxf(worst_frame, (now - _last_tick) / 1000.0)
	_last_tick = now
	if _watch_screen and is_instance_valid(player):
		var at := player.get_global_transform_with_canvas().origin
		if _screen_at != Vector2.INF:
			worst_jump = maxf(worst_jump, at.distance_to(_screen_at))
			if OS.has_environment("TRANSITIONS_DEBUG") and at.distance_to(_screen_at) > JUMP_PX:
				print("JUMP %s -> %s in %s seam=%s crossed=%s busy=%s pos=%s" % [_screen_at, at, world.region.region_id,
					world.seam.neighbor.region_id if world.seam else "none", world._crossed, world._busy, player.global_position])
		_screen_at = at


func _ready() -> void:
	# after everything else, so the player's spot on screen is this frame's
	process_priority = 1 << 30
	SaveManager.save_path = "user://transitions_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 2.0
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	player = world.player
	await get_tree().process_frame
	await get_tree().process_frame
	world.region_changed.connect(func(r: Region) -> void:
		changes.append(r.region_id)
		if OS.has_environment("TRANSITIONS_DEBUG"):
			print("CHANGE to %s at %s" % [r.region_id, player.global_position])
		# _cross_seam sets this just before it says the region changed
		cuts += 0 if world._crossed else 1)
	Park.open_world = true

	var only := OS.get_environment("TRANSITIONS_ONLY")
	var ids: Array[String] = []
	for file in DirAccess.get_files_at(REGIONS_DIR):
		if file.ends_with(".tscn") and (only == "" or file.get_basename() in only.split(",")):
			ids.append(file.get_basename())
	ids.sort()
	var ways := 0
	for id in ids:
		await _enter(id)
		var r: Region = world.region
		var targets: Array[NodePath] = []
		for node in r.find_children("*", "", true, false):
			if (node is RegionExit and (node.target_region != "" or node.drive_to != "")) \
					or (node is RegionDoor and node.target_region != ""):
				targets.append(r.get_path_to(node))
		for path in targets:
			await _enter(id)
			var way := world.region.get_node(path) as Node2D
			if way is RegionExit:
				await _walk_into(id, way)
			else:
				await _go_through(id, way)
			ways += 1
	for line in report:
		print("  " + line)
	check(only != "" or ways > 100, "used every way between places (%d)" % ways)
	await _check_late_seam()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	Engine.time_scale = 1.0
	get_tree().quit(failures)


## Puts the player in region [param id] by its first spot, with the clock at
## midday (shops open, nothing too late to set out on), and waits for it to
## settle.
func _enter(id: String) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	for i in 120:
		if not world._busy:
			break
		await get_tree().process_frame
	GameClock.minutes = 12 * 60
	world._door_back = {}
	world._enter_region(id, _start(world._get_region(id)))
	player.can_act = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	changes.clear()


func _start(r: Region) -> String:
	for spawn_name in ["arrival", "south_entry", "door"]:
		if r.get_spawn(spawn_name):
			return spawn_name
	var markers := r.get_node_or_null("Markers")
	if markers:
		for child in markers.get_children():
			if child is Marker2D:
				return child.name
	return ""


## The exit's trigger, in world coordinates.
static func _rects(way: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for shape_node in way.find_children("*", "CollisionShape2D", true, false):
		var shape := (shape_node as CollisionShape2D).shape
		if shape:
			rects.append(shape_node.global_transform * shape.get_rect())
	return rects


## The way out of the map edge nearest the exit, as a direction to walk.
static func _outward(r: Region, at: Vector2) -> Vector2i:
	var b := r.get_bounds()
	var local := r.to_local(at)
	var gaps := [local.x - b.position.x, b.end.x - local.x, local.y - b.position.y, b.end.y - local.y]
	return [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][gaps.find(gaps.min())]


static func _action(dir: Vector2i) -> String:
	match dir:
		Vector2i.LEFT: return "move_left"
		Vector2i.RIGHT: return "move_right"
		Vector2i.UP: return "move_up"
	return "move_down"


## Where the way named [param spawn] in [param id] lands, or null.
func _landing(id: String, spawn: String) -> Marker2D:
	return world._get_region(id).get_spawn(spawn) if spawn != "" else null


## Walks into [param exit] from just short of it, keeps walking after
## arriving, and checks the move.
func _walk_into(from: String, exit: RegionExit) -> void:
	var what := "%s/%s" % [from, exit.name]
	var rects := _rects(exit)
	if rects.is_empty():
		check(false, "%s: has a trigger to walk into" % what)
		return
	var trigger := rects[0]
	# (an edge exit whose maps don't meet edge to edge, like El Capitan
	# Bridge, is a cut)
	var is_seam: bool = exit in world._seam_exits(world.region) and world._seam_for(exit) != null
	# Walk at it the way a player would: off the map at an edge, and into a
	# doorway in the middle of a map from the open side (up, into a
	# building's door, where that's open).
	var dirs: Array[Vector2i] = [_outward(world.region, trigger.get_center())]
	var local: Vector2 = world.region.to_local(trigger.get_center())
	if Seam._side_of(world.region.get_bounds(), local, Seam.EXIT_SLACK) == Vector2i.ZERO:
		dirs = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
	var dir := dirs[0]
	var short := Vector2.ZERO
	for d in dirs:
		# stand just short of it (a seam from well back, as you'd walk up to
		# it, so the region past it is laid out as it would be)
		short = trigger.get_center() - Vector2(d) * (absf(Vector2(d).dot(trigger.size)) * 0.5 + (SEAM_RUN if is_seam else 40.0))
		if not player.test_move(Transform2D(0.0, short), Vector2.ZERO) \
				and not player.test_move(Transform2D(0.0, short), trigger.get_center() - short):
			dir = d
			break
	short = trigger.get_center() - Vector2(dir) * (absf(Vector2(dir).dot(trigger.size)) * 0.5 + (SEAM_RUN if is_seam else 40.0))
	player.global_position = short
	await world._unstick_player()
	# let the view catch up with the move before watching for jumps
	world._camera().reset_smoothing()
	for i in 8:
		await get_tree().process_frame
	# walking up from further off, the region past a seam would be loaded
	# and laid out by now (the late case is _check_late_seam)
	for i in 600 if is_seam else 0:
		if world.seam and world.seam.exit == exit:
			break
		await get_tree().process_frame
	changes.clear()
	cuts = 0
	worst_frame = 0.0
	worst_jump = 0.0
	_screen_at = Vector2.INF
	_watch_screen = is_seam
	var expected := _expected(exit)
	var action := _action(dir)
	Input.action_press(action)
	var walked := true
	for i in WALK_TICKS:
		await get_tree().physics_frame
		if not changes.is_empty():
			break
	if changes.is_empty():
		# something stands in the way of the straight walk (exit_access_test
		# checks it can be walked to some other way): use it from here
		walked = false
		world.use_exit(exit)
		for i in 10:
			await get_tree().physics_frame
			if not changes.is_empty() or world._busy:
				break
	# let go for the landing (it is measured standing still), then walk on
	Input.action_release(action)
	await _settle()
	var landed_at := player.global_position
	var landed_in := world.region.region_id as String
	Input.action_press(action)
	for i in HOLD_TICKS:
		await get_tree().physics_frame
	Input.action_release(action)
	await _settle()
	_watch_screen = false
	if changes.is_empty():
		# a drive that wasn't taken (a closed road, a map instead)
		report.append("%-48s stays (%s)" % [what, exit.label])
		return
	check(changes[0] == expected or expected == "", "%s: leads to %s (went to %s)" % [what, expected, changes[0]])
	check(changes.size() == 1, "%s: changes place once, not again as you walk on (%s)" % [what, " -> ".join(changes)])
	if is_seam and walked:
		check(cuts == 0, "%s: walks over the edge into %s, with no cut to its far spot" % [what, expected])
		check(worst_jump < JUMP_PX, "%s: walking over the edge, nothing jumps on screen (%.0f px)" % [what, worst_jump])
	elif exit.target_region != "":
		_check_landing(what, from, landed_in, landed_at, exit.target_spawn if exit.target_region == landed_in else "")
	report.append("%-48s -> %-24s %s worst frame %5.1f ms%s" % [what, landed_in,
		"seam" if is_seam else "cut ", worst_frame, "" if walked else " (used from a script)"])


## Goes through [param door] (a gate or a building door) the way the player
## does, facing it and pressing the button, and checks the move.
func _go_through(from: String, door: RegionDoor) -> void:
	var what := "%s/%s" % [from, door.name]
	player.facing = Vector2i.UP
	changes.clear()
	worst_frame = 0.0
	if door is BuildingDoor and not (door as BuildingDoor).is_open_now():
		return
	door.interact(player)
	for i in 10:
		await get_tree().physics_frame
		if not changes.is_empty() or world._busy:
			break
	await _settle()
	var landed_at := player.global_position
	var landed_in := world.region.region_id as String
	# walk on in the way you went in (up, into a building)
	if door is BuildingDoor:
		Input.action_press("move_up")
		for i in HOLD_TICKS:
			await get_tree().physics_frame
		Input.action_release("move_up")
		await _settle()
	else:
		for i in HOLD_TICKS:
			await get_tree().physics_frame
	if changes.is_empty():
		report.append("%-48s stays (%s)" % [what, door.label])
		return
	check(changes[0] == door.target_region, "%s: leads to %s (went to %s)" % [what, door.target_region, changes[0]])
	check(changes.size() == 1, "%s: changes place once, not again as you walk on (%s)" % [what, " -> ".join(changes)])
	_check_landing(what, from, landed_in, landed_at, door.target_spawn)
	report.append("%-48s -> %-24s door worst frame %5.1f ms" % [what, landed_in, worst_frame])


## The region a walk into [param exit] should end up in.
static func _expected(exit: RegionExit) -> String:
	if exit.target_region != "":
		return exit.target_region
	if exit.stop_region != "":
		return exit.stop_region
	var hub := Park.get_hub(exit.drive_to)
	if hub == null:
		return ""
	return hub.arrival_region if hub.arrival_region != "" else hub.id


## The player landed at [param at] in [param into] by the spot named
## [param spawn]: on it, not in another exit, and beside a way back.
func _check_landing(what: String, from: String, into: String, at: Vector2, spawn: String) -> void:
	var r: Region = world.region
	var spot := r.get_spawn(spawn) if spawn != "" else null
	if spot:
		# (someone standing on the spot, a traveler passing a doorstep, moves
		# the player aside; that's them, not the spot)
		check(spot.global_position.distance_to(at) < LANDING_SLACK or _people_on(spot.global_position),
			"%s: lands on %s, not pushed off it (%.0f px, %s -> %s)" % [what, spawn, spot.global_position.distance_to(at), spot.global_position, at])
	var body := _body_at(at)
	var inside := PackedStringArray()
	var back := INF
	for node in r.find_children("*", "", true, false):
		if node is RegionExit:
			for rect in _rects(node):
				if rect.intersects(body):
					inside.append(node.name)
		if (node is RegionExit or node is RegionDoor) and node.target_region == from:
			for rect in _rects(node):
				back = minf(back, _gap(rect, at))
	check(inside.is_empty(), "%s: lands clear of every exit in %s (in %s)" % [what, into, ", ".join(inside)])
	if not ONE_WAY.has(what) and from != into:
		check(back <= BACK_NEAR, "%s: lands beside a way back to %s (%.0f px off)" % [what, from, back])


## Is someone (a person walking about) standing where the player would land?
func _people_on(at: Vector2) -> bool:
	var collision := player.get_node("Collision") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = Transform2D(0.0, at + collision.position)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	for hit in world.region.get_world_2d().direct_space_state.intersect_shape(query, 8):
		if hit.collider is CharacterBody2D:
			return true
	return false


func _body_at(at: Vector2) -> Rect2:
	var collision := player.get_node("Collision") as CollisionShape2D
	var size: Vector2 = (collision.shape as RectangleShape2D).size
	return Rect2(at + collision.position - size / 2.0, size)


static func _gap(rect: Rect2, at: Vector2) -> float:
	return at.distance_to(at.clamp(rect.position, rect.end))


## Waits for the move under way to finish.
func _settle() -> void:
	for i in 300:
		await get_tree().process_frame
		if not world._busy:
			break
	await get_tree().physics_frame
	await get_tree().physics_frame


## A seam's region past the edge that isn't laid out yet when the player
## walks into the exit (a slow disk, or straight off a fade beside the
## edge): the player still walks over, not cut to the far spot.
func _check_late_seam() -> void:
	await _enter("leidig_meadow")
	var exit := world.region.find_child("ToVillage", true, false) as RegionExit
	world._drop_seam()
	var old: Region = world._regions.get("yosemite_village")
	world._regions.erase("yosemite_village")
	if old and old.get_parent() == null:
		old.free()
	world._preloaded.clear()
	world._seams.clear()
	changes.clear()
	player.global_position = _rects(exit)[0].get_center()
	world._camera().reset_smoothing()
	await get_tree().physics_frame
	cuts = 0
	worst_jump = 0.0
	_screen_at = Vector2.INF
	_watch_screen = true
	Input.action_press("move_right")
	for i in WALK_TICKS:
		await get_tree().physics_frame
		if not changes.is_empty():
			break
	for i in HOLD_TICKS:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_watch_screen = false
	check(changes == ["yosemite_village"] and cuts == 0,
		"walking into a seam before the region past it is laid out waits for it and walks on over, with no cut (%s)" % " -> ".join(changes))
	# the view, held at the old edge until then, pans over as the region
	# past it opens up (the camera's own easing)
	print("      the view moved at most %.0f px in a frame" % worst_jump)
