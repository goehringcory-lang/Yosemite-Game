extends Node
## Headless performance bench. Boots the real world scene, visits every region
## (the five hubs and the hand-made areas) in walking order, and measures:
##   - load ms: a first visit (World._enter_region: load or take the
##     background-loaded scene, instantiate, story overlay, restore)
##   - 1st frm: the first frame there (forage for the new day, tile maps and
##     physics building, everything's first update)
##   - back ms: a return visit (the region is cached in World)
##   - forage: a new day's forage respawn; map: opening the map (M)
##   - frame time over `frames` frames by day and at night while walking: the
##     average, 99th percentile and peak wall time from one frame to the next
##   - nodes in the region
## then opens the climbing screen on a few routes ("open ms": painting the
## sky, landscape and wall) and times its frames.
##
## Run:  godot --headless --fixed-fps 60 --path . res://tools/perf/bench.tscn [-- frames=600 dwell=2 only=yosemite_valley,wawona]
## --fixed-fps 60 gives every frame a 1/60 s step (so one physics tick a frame,
## like a real 60 fps game) while running as fast as the CPU allows.
## Numbers are printed as a table and also written to user://bench.json.
## Headless has no GPU, so these are CPU (script, physics, scene) costs only.

const REGIONS := [
	"lamon_homestead", "yosemite_valley", "curry_village", "yosemite_village",
	"ahwahnee_trail", "the_ahwahnee", "curry_mountain_shop", "el_portal", "wawona",
	"glacier_point", "tuolumne_meadows",
]
const ROUTES := ["swan_slab", "glacier_point_apron", "the_nose", "separate_reality"]

var frames := 600
## Real seconds spent in each region after measuring it, before the next.
var dwell := 2.0
var only: PackedStringArray = []
var results := {"regions": {}, "climb": {}}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("frames="):
			frames = int(arg.trim_prefix("frames="))
		elif arg.begins_with("dwell="):
			dwell = float(arg.trim_prefix("dwell="))
		elif arg.begins_with("only="):
			only = arg.trim_prefix("only=").split(",")
	SaveManager.save_path = "user://bench_save.json"
	SaveManager.delete_save()
	Engine.max_fps = 0
	# Headless sleeps ~7 ms a frame in low-processor mode; turn that off so the
	# wall time between frames is the real cost of a frame.
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	var boot_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await get_tree().process_frame
	await get_tree().process_frame
	print("world boot: %.1f ms" % boot_ms)
	results["boot_ms"] = boot_ms
	GameClock.paused = false
	world.player.can_act = true

	print("\n%-22s %9s %7s %8s %8s %7s %6s | %7s %7s %7s | %7s %7s %7s" % ["region", "load ms", "1st frm", "back ms", "forage", "map", "nodes",
		"day avg", "day p99", "peak", "ngt avg", "ngt p99", "peak"])
	for id: String in REGIONS:
		if not only.is_empty() and id not in only:
			continue
		if not ResourceLoader.exists(world.region_scene_path(id)):
			continue
		var r := {}
		# First visit: load, instantiate, story overlay, restore, forage.
		var t := Time.get_ticks_usec()
		world._enter_region(id, "arrival")
		r["load_ms"] = (Time.get_ticks_usec() - t) / 1000.0
		# The first frame there, when everything new runs its first update.
		t = Time.get_ticks_usec()
		await get_tree().process_frame
		r["first_frame_ms"] = (Time.get_ticks_usec() - t) / 1000.0
		await _settle()
		# A return visit (the region is cached).
		world._enter_region("lamon_homestead" if id != "lamon_homestead" else "yosemite_valley", "")
		await _settle()
		t = Time.get_ticks_usec()
		world._enter_region(id, "arrival")
		r["back_ms"] = (Time.get_ticks_usec() - t) / 1000.0
		await _settle()
		# A new day's forage (the habitat scan and placing items).
		r["forage_ms"] = 0.0
		if world.forage:
			t = Time.get_ticks_usec()
			await world.forage.respawn()
			r["forage_ms"] = (Time.get_ticks_usec() - t) / 1000.0
		# Opening the map (M) here, then closing it.
		t = Time.get_ticks_usec()
		world.open_map()
		await get_tree().process_frame
		r["map_ms"] = (Time.get_ticks_usec() - t) / 1000.0
		world.park_map.close()
		await get_tree().process_frame
		r["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		r["region_nodes"] = world.region.get_child_count() + world.region.find_children("*", "", true, false).size()
		GameClock.minutes = 12 * 60
		GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
		r["day"] = await _measure(world)
		GameClock.minutes = 22 * 60
		GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
		r["night"] = await _measure(world)
		GameClock.minutes = 12 * 60
		results.regions[id] = r
		# A player stays a while in each place; give background work (if any)
		# the same couple of seconds before moving on.
		await _dwell()
		print("%-22s %9.1f %7.1f %8.2f %8.1f %7.1f %6d | %7.3f %7.3f %7.3f | %7.3f %7.3f %7.3f" % [id, r.load_ms, r.first_frame_ms, r.back_ms, r.forage_ms, r.map_ms, r.region_nodes,
			r.day.avg_ms, r.day.p99_ms, r.day.peak_ms, r.night.avg_ms, r.night.p99_ms, r.night.peak_ms])

	world.queue_free()
	await get_tree().process_frame

	print("\n%-22s %9s | %7s %7s %7s" % ["climb route", "open ms", "avg", "p99", "peak"])
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 8, "rope": 1, "cam": 10,
		"aiders": 2, "ascenders": 2, "haul_bag": 1, "portaledge": 1, "ice_axe": 1, "crampons": 1}
	for route_id: String in ROUTES:
		var path := "res://data/routes/%s.tres" % route_id
		if not ResourceLoader.exists(path):
			continue
		GameClock.paused = true
		var t := Time.get_ticks_usec()
		var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
		game.setup(load(path), 7)
		add_child(game)
		var open_ms := (Time.get_ticks_usec() - t) / 1000.0
		game.skip_intro()
		await _settle()
		var m := await _measure(null)
		results.climb[route_id] = {"open_ms": open_ms, "frame": m}
		print("%-22s %9.1f | %7.3f %7.3f %7.3f" % [route_id, open_ms, m.avg_ms, m.p99_ms, m.peak_ms])
		game.queue_free()
		await get_tree().process_frame

	var file := FileAccess.open("user://bench.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(results, "\t"))
	SaveManager.delete_save()
	print("\nBENCH DONE")
	get_tree().quit(0)


func _dwell() -> void:
	var until := Time.get_ticks_msec() + int(dwell * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _settle() -> void:
	for i in 10:
		await get_tree().process_frame


## Frame time: the wall time from one frame to the next (process, physics,
## redraws and the dummy renderer), as an average, the 99th percentile and the
## peak, after a short warm-up.
func _measure(world: Node) -> Dictionary:
	var times := PackedFloat64Array()
	for i in 20:
		await get_tree().process_frame
	var last := Time.get_ticks_usec()
	for i in frames:
		if world and i % 60 == 0:
			# Walk about a little so the location banner, prompts and physics do work.
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press("move_right" if (i / 60) % 2 == 0 else "move_left")
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	Input.action_release("move_right")
	Input.action_release("move_left")
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in times:
		total += t
	return {"avg_ms": total / frames, "p99_ms": sorted[int(frames * 0.99) - 1], "peak_ms": sorted[frames - 1]}
