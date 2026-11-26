extends Node
## Tours the whole open world in a running game, the way a player gets
## around: through every road, trail and door to every region the park has,
## on the drives and trails between hubs, and back. On each arrival it checks
## that the trip ended (not left half way under a fade), that the player
## stands on open ground inside the map, can move and isn't frozen with the
## clock stopped, that the HUD stays on the screen, and that no frame while
## playing stalled. It saves on every arrival, and in a spread of places
## (each hub and the far corners of the park) quits to the title and loads
## that save, checking the game comes back where it was. Last, it checks the
## game didn't grow without end over the tour.
##
## exit_access_test checks the same ways in and out on the maps alone; this
## takes them in a live World, with the seams, the loading and the story on.
##
## The worst frames are printed at the end (in this run's CPU time; the
## tests have no GPU). PERF_TOUR_ONLY=a,b,c tours just those regions.
## Run: godot --headless --path . res://tests/open_world_tour_test.tscn
## Exit code is the number of failed checks.

const SAVE := "user://open_world_tour_test_save.json"
const REGIONS_DIR := "res://scenes/regions/"
## Quit to the title and load the save in these (where they are reached).
const RELOAD_IN := ["yosemite_village", "curry_village", "glacier_point", "taft_point",
	"tuolumne_meadows", "cathedral_lakes", "tenaya_lake", "hetch_hetchy", "crane_flat",
	"wawona", "el_portal", "half_dome", "little_yosemite_valley", "the_ahwahnee"]
## A frame this long while playing (not under a trip's cover) fails.
## CI machines are slow and shared, so this is a stall, not a judder.
const STALL_MS := 500.0
## A trip that takes this long to finish (real time) fails.
const TRIP_SECONDS := 12.0
## Frames watched after each arrival.
const PLAY_FRAMES := 20

var failures := 0
var world: Node
## region id -> the spawn the tour came in by (to come back to it)
var entered_by := {}
## Every way out seen: [from, to, kind]
var ways := []
## The worst frames: [ms, where]
var worst := []
var trips := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		print("FAIL  " + what)
		failures += 1


func pass_note(what: String) -> void:
	print("PASS  " + what)


func _ready() -> void:
	SaveManager.save_path = SAVE
	SaveManager.delete_save()
	Engine.time_scale = 10.0
	world = await _start_world()
	_open_everything()
	var start_mem := OS.get_static_memory_usage()
	var start_id: String = world.region.region_id
	entered_by[start_id] = ""
	var only := OS.get_environment("PERF_TOUR_ONLY").split(",", false)
	# depth first, so the next way out is usually from where the player stands
	var stack: Array = []
	_push_ways(stack)
	await _check_arrival(start_id, "the start")
	var all := _all_regions()
	while not stack.is_empty():
		var way: Dictionary = stack.pop_back()
		if entered_by.has(way.to):
			continue
		if not only.is_empty() and not (way.to in only or way.from in only):
			continue
		if world.region.region_id != way.from:
			await _go(way.from, str(entered_by[way.from]), 0, "back to %s" % way.from)
			if world.region.region_id != way.from:
				continue
		await _take(way)
		if world.region.region_id != way.to:
			continue
		entered_by[way.to] = way.spawn
		await _check_arrival(way.to, "%s from %s" % [way.to, way.from])
		if way.to in RELOAD_IN and OS.get_environment("PERF_TOUR_NO_RELOAD") == "":
			await _check_reload(way.to)
		_push_ways(stack)
	await _check_odd_saves()
	if only.is_empty():
		var missed := all.filter(func(id: String) -> bool: return not entered_by.has(id))
		check(missed.is_empty(), "the tour reached every region (%d of %d; missed %s)"
			% [entered_by.size(), all.size(), ", ".join(PackedStringArray(missed))])
		pass_note("toured %d regions in %d trips" % [entered_by.size(), trips])
	# Every region stays in memory once visited (World keeps them, so a
	# rebuilt one can't look different). Note what the whole park costs.
	var grown := (OS.get_static_memory_usage() - start_mem) / 1048576.0
	print("NOTE  memory grew %.0f MB over the tour; %d objects, %d nodes" % [grown,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("NOTE  worst playing frames:")
	for entry in worst.slice(0, 10):
		print("      %6.1f ms  %s" % [entry[0], entry[1]])
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _start_world() -> Node:
	var made: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(made)
	await get_tree().process_frame
	await get_tree().process_frame
	while made._busy:
		await get_tree().process_frame
	return made


## Every hub, door and road open, at midday in summer, so the tour isn't
## stopped by a season, a closing time or the story.
func _open_everything() -> void:
	Park.open_world = true
	for hub in ParkAtlas.HUBS:
		Park.unlock_hub(hub.id)
	GameClock.season = GameClock.Season.SUMMER
	_midday()


func _midday() -> void:
	GameClock.minutes = 10 * 60
	GameClock._elapsed = 0.0


func _all_regions() -> Array:
	var ids := []
	for file in DirAccess.get_files_at(REGIONS_DIR):
		if file.ends_with(".tscn"):
			ids.append(file.get_basename())
	return ids


## The ways out of the region the player is in now, onto [param stack].
func _push_ways(stack: Array) -> void:
	var here: Region = world.region
	var found := []
	for node in here.find_children("*", "", true, false):
		if (node is RegionExit or node is RegionDoor) and node.target_region != "":
			found.append({"from": here.region_id, "to": node.target_region, "spawn": node.target_spawn,
				"minutes": node.minutes, "kind": "door" if node is RegionDoor else "exit", "node": node.name})
		elif (node is RegionExit and (node.drive_to != "" or node.travel_to != "")) or node is TravelPoint:
			for leg in Park.legs_from(here.hub_id):
				var hub := Park.get_hub(leg.to)
				found.append({"from": here.region_id, "to": hub.arrival_region if hub.arrival_region != "" else hub.id,
					"leg": leg, "spawn": str(leg.spawn), "kind": "drive"})
		elif node is ShuttleStop:
			for stop: Dictionary in node.destinations():
				found.append({"from": here.region_id, "to": stop.region, "spawn": str(stop.get("spawn", "")),
					"minutes": ShuttleStop.RIDE_MINUTES, "kind": "shuttle"})
	for way in found:
		ways.append([way.from, way.to, way.kind])
	# taken last-pushed first: walk the doors and roads before the drives
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.kind == "drive" and b.kind != "drive")
	stack.append_array(found)


func _take(way: Dictionary) -> void:
	var what := "%s -> %s (%s %s)" % [way.from, way.to, way.kind, way.get("node", "")]
	if way.has("leg"):
		var leg: Dictionary = way.leg
		check(leg.open, "%s: the leg is open with the park open" % what)
		await _trip(func() -> void: await world.travel(leg), way.to, what)
	else:
		await _go(way.to, way.spawn, int(way.minutes), what)


func _go(id: String, spawn: String, minutes: int, what: String) -> void:
	await _trip(func() -> void: await world.go_to_region(id, spawn if spawn != "" else "arrival", minutes), id, what)


## Runs a trip and waits for it to end, watching the frames.
func _trip(go: Callable, id: String, what: String) -> void:
	_midday()
	trips += 1
	await get_tree().physics_frame
	var started := Time.get_ticks_msec()
	go.call()
	await get_tree().process_frame
	while world._busy and Time.get_ticks_msec() - started < TRIP_SECONDS * 1000.0:
		await get_tree().process_frame
	var took := (Time.get_ticks_msec() - started) / 1000.0
	if OS.get_environment("PERF_TOUR_VERBOSE") != "":
		print("      %5.1f s  %6.0f MB  %6.0f MB tex  %s" % [took, OS.get_static_memory_usage() / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, what])
	check(not world._busy, "%s: the trip ends (still going after %.0f s)" % [what, took])
	check(world.region.region_id == id, "%s: arrives in %s (is in %s)" % [what, id, world.region.region_id])


## The checks on arriving in [param id].
func _check_arrival(id: String, what: String) -> void:
	var player: Player = world.player
	# watch it play a moment, as the player would
	var last := Time.get_ticks_usec()
	for i in PLAY_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		worst.append([ms, "%s (frame %d after arriving)" % [id, i]])
		check(ms < STALL_MS, "%s: no stall while playing (%.0f ms frame %d after arriving)" % [what, ms, i])
	check(player.can_act, "%s: the player can move" % what)
	check(not GameClock.paused, "%s: the clock runs" % what)
	check(not world._transitioning, "%s: the transition finished" % what)
	check(player.get_parent() == world.region.entities, "%s: the player is in the region" % what)
	await get_tree().physics_frame
	check(not player.test_move(player.global_transform, Vector2.ZERO),
		"%s: the player stands on open ground (at %s)" % [what, player.position.round()])
	var ground: Rect2 = world.region.get_bounds() if world.region.has_method("get_bounds") else _ground_rect(world.region)
	check(ground.grow(8.0).has_point(player.position), "%s: the player is on the map (%s in %s)" % [what, player.position.round(), ground])
	check(world.location_name() != "", "%s: the place has a name" % what)
	_check_hud_on_screen(what)
	check(SaveManager.save_game(), "%s: saves" % what)
	var info := SaveManager.slot_info(SaveManager.slot)
	check(str(info.get("place", "")) != "", "%s: the save says where it is" % what)


func _ground_rect(region: Region) -> Rect2:
	var ground := region.get_ground()
	var used := ground.get_used_rect()
	var size := Vector2(ground.tile_set.tile_size) if ground.tile_set else Vector2(32, 32)
	var top_left := ground.to_global(Vector2(used.position) * size) - region.global_position
	return Rect2(top_left, Vector2(used.size) * size)


## Nothing on the HUD sits off the screen (the UI is laid out at 480x270).
func _check_hud_on_screen(what: String) -> void:
	var screen := Rect2(Vector2.ZERO, UiScale.SCREEN).grow(1.0)
	var off := PackedStringArray()
	for layer in [world.hud]:
		for node in (layer as Node).find_children("*", "Control", true, false):
			var control := node as Control
			if not control.is_visible_in_tree() or control.size == Vector2.ZERO:
				continue
			if control.modulate.a <= 0.01 or _clipped(control):
				continue
			var rect := control.get_global_rect()
			if not screen.encloses(rect):
				off.append("%s %s" % [control.name, rect])
	check(off.is_empty(), "%s: the HUD stays on screen (%s)" % [what, ", ".join(off)])


## Inside a ScrollContainer or a clipping parent, where off-screen is fine.
func _clipped(control: Control) -> bool:
	var at := control.get_parent()
	while at is Control:
		if at is ScrollContainer or (at as Control).clip_contents:
			return true
		at = at.get_parent()
	return false


## Quits to the title and loads the save made just now: the game comes back
## in [param id], where the player stood, at the time it was.
func _check_reload(id: String) -> void:
	var player: Player = world.player
	var at := player.position
	var facing := player.facing
	var minutes := GameClock.minutes
	var day := GameClock.day
	check(SaveManager.save_game(), "%s: saves before quitting" % id)
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.clear_pending()
	NewGame.reset_all()
	var started := Time.get_ticks_msec()
	world = await _start_world()
	var took := Time.get_ticks_msec() - started
	_open_everything()
	GameClock.minutes = minutes
	check(world.region.region_id == id, "load in %s: comes back in %s (is in %s)" % [id, id, world.region.region_id])
	check(world.player.position.distance_to(at) < 2.0, "load in %s: the player is where they saved (%s, saved at %s)"
		% [id, world.player.position.round(), at.round()])
	check(world.player.facing == facing, "load in %s: facing the same way" % id)
	check(GameClock.day == day, "load in %s: the same day" % id)
	await _check_arrival(id, "load in %s" % id)
	pass_note("load in %s took %d ms" % [id, took])


## Saves that no longer fit the park (it changed after they were made) still
## load into a playable spot: a spot something now stands on, a spot off the
## map, and an area that has gone.
func _check_odd_saves() -> void:
	await _go("curry_village", "arrival", 0, "to Curry Village for the odd saves")
	await _check_arrival("curry_village", "curry_village before the odd saves")
	var region: Region = world.region
	var blocked := Vector2.INF
	var bounds := region.get_bounds()
	var step := 32.0
	var y := bounds.position.y + 64.0
	while y < bounds.end.y - 64.0 and blocked == Vector2.INF:
		var x := bounds.position.x + 64.0
		while x < bounds.end.x - 64.0:
			var spot := region.to_global(Vector2(x, y))
			# boxed in on a blocked tile, with open ground within a few steps
			if world.player.test_move(Transform2D(0.0, spot), Vector2.ZERO) \
					and not world.player.test_move(Transform2D(0.0, spot + Vector2(0, 64)), Vector2.ZERO):
				blocked = Vector2(x, y)
				break
			x += step
		y += step
	check(blocked != Vector2.INF, "found a blocked spot in Curry Village to save on")
	if blocked != Vector2.INF:
		await _reload_with(func(data: Dictionary) -> void:
			data.nodes.Player.x = blocked.x
			data.nodes.Player.y = blocked.y)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(world.region.region_id == "curry_village", "saved on a spot that's blocked now: loads in Curry Village")
		check(not world.player.test_move(world.player.global_transform, Vector2.ZERO),
			"saved on a spot that's blocked now: the player is stepped clear (at %s)" % world.player.position.round())
		check(world.player.position.distance_to(blocked) < 200.0, "and stays near where they saved (%s, saved at %s)"
			% [world.player.position.round(), blocked])
	await _reload_with(func(data: Dictionary) -> void:
		data.nodes.Player.x = bounds.end.x + 5000.0
		data.nodes.Player.y = bounds.end.y + 5000.0)
	await get_tree().physics_frame
	check(world.region.get_bounds().has_point(world.player.position), "saved off the map: loads on the map (%s)" % world.player.position.round())
	await _reload_with(func(data: Dictionary) -> void:
		data.nodes.World.region = "a_place_that_has_gone"
		data.nodes.Player.x = 3.0
		data.nodes.Player.y = 3.0)
	await get_tree().physics_frame
	check(world.region.region_id == Park.HOME_REGION, "saved in an area that has gone: loads at home (in %s)" % world.region.region_id)
	check(world.player.position.distance_to(Vector2(3, 3)) > 32.0, "and at home's spawn, not the old spot (%s)" % world.player.position.round())
	await _check_arrival(world.region.region_id, "after the odd saves")


## Saves, changes the save file with [param edit], and loads it.
func _reload_with(edit: Callable) -> void:
	check(SaveManager.save_game(), "saves before changing the save")
	var data = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
	edit.call(data)
	var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.clear_pending()
	NewGame.reset_all()
	world = await _start_world()
	_open_everything()
