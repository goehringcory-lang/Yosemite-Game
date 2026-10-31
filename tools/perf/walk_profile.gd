extends Node
## Walks the player about a region and prints how long each frame took, and
## where it was spent, so stutter can be found. Needs a window (not --headless).
## Environment:
##   PERF_REGION   region id (default curry_village)
##   PERF_SPAWN    spawn name (default arrival)
##   PERF_HOUR     game hour (default 12)
##   PERF_SECONDS  seconds of walking (default 8)
##   PERF_WALK     walk this one way the whole time (move_left...), e.g.
##                 over a seam, instead of round in a square
##   PERF_CSV      optional path for a per-frame CSV
##   PERF_SHOT     optional path for a screenshot taken mid-walk
##   PERF_OFF      comma-separated node names to switch off (hide and stop
##                 processing), to see what each one costs
## Run: xvfb-run godot --path . res://tools/perf/walk_profile.tscn

var _rows: Array[PackedFloat64Array] = []
var _world: Node
var _walking := false
var _t := 0.0
var _last_usec := 0
const DIRS := ["move_right", "move_down", "move_left", "move_up"]
## Microseconds at the start of this frame's _process and _physics_process
## callbacks (this node runs first, _End last).
var _process_start := 0
var _physics_start := 0
var _script_us := 0.0
var _physics_us := 0.0


## Runs after every other node's callbacks, to time them.
class _End extends Node:
	var profile: Node
	func _ready() -> void:
		process_priority = 1 << 30
		process_physics_priority = 1 << 30
	func _process(_delta: float) -> void:
		profile._script_us = Time.get_ticks_usec() - profile._process_start
		profile._sample()
	func _physics_process(_delta: float) -> void:
		profile._physics_us += Time.get_ticks_usec() - profile._physics_start


func _ready() -> void:
	process_priority = -(1 << 30)
	process_physics_priority = -(1 << 30)
	var end := _End.new()
	end.profile = self
	add_child(end)
	SaveManager.save_path = "user://walk_profile_save.json"
	SaveManager.delete_save()
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	var region_id := _env("PERF_REGION", "curry_village")
	await _world.go_to_region(region_id, _env("PERF_SPAWN", "arrival"))
	GameClock.minutes = int(_env("PERF_HOUR", "12")) * 60
	for i in 30:
		await get_tree().process_frame
	for off in _env("PERF_OFF", "").split(",", false):
		for node in get_tree().root.find_children(off, "", true, false):
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is CanvasItem or node is CanvasLayer:
				node.visible = false
			print("PERF off ", node.get_path())
	if _env("PERF_CENSUS", "") != "":
		_census()
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_walking = true
	_last_usec = Time.get_ticks_usec()
	var seconds := float(_env("PERF_SECONDS", "8"))
	if _env("PERF_SHOT", "") != "":
		await get_tree().create_timer(minf(seconds, 1.0)).timeout
		get_viewport().get_texture().get_image().save_png(_env("PERF_SHOT", ""))
		seconds -= minf(seconds, 1.0)
	await get_tree().create_timer(seconds).timeout
	_walking = false
	for a in DIRS:
		Input.action_release(a)
	_report(region_id)
	get_tree().quit()


func _physics_process(_delta: float) -> void:
	_physics_start = Time.get_ticks_usec()


func _process(delta: float) -> void:
	_process_start = Time.get_ticks_usec()
	if not _walking:
		return
	_t += delta
	var dir: String = _env("PERF_WALK", DIRS[int(_t / 1.5) % DIRS.size()])
	for a in DIRS:
		if a == dir:
			Input.action_press(a)
		else:
			Input.action_release(a)


## Notes this frame's numbers, once every other node has had its turn (so
## the camera and the walkers are where this frame draws them).
func _sample() -> void:
	if not _walking:
		return
	var now := Time.get_ticks_usec()
	var vp := get_viewport().get_viewport_rid()
	var player: Node2D = _world.player
	var canvas := get_viewport().canvas_transform.origin
	# Where the player is drawn this frame, in world pixels (SmoothMotion
	# keeps the camera on the drawn walker), and on screen.
	var drawn := player.global_position + (player.get_node("Camera") as Node2D).position
	var on_screen := get_viewport().canvas_transform * drawn
	_rows.append(PackedFloat64Array([
		(now - _last_usec) / 1000.0,
		_script_us / 1000.0,
		_physics_us / 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp),
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		on_screen.x, on_screen.y, canvas.x, canvas.y,
		drawn.x, drawn.y, player.velocity.length(),
	]))
	_last_usec = now
	_physics_us = 0.0
	var r := _rows[-1]
	if _rows.size() > 2:
		var view_step := Vector2(r[8] - _rows[-2][8], r[9] - _rows[-2][9]).length()
		var prev_step := Vector2(_rows[-2][8] - _rows[-3][8], _rows[-2][9] - _rows[-3][9]).length()
		if r[0] > 25.0 or absf(view_step - prev_step) > 3.0:
			print("PERF frame %d/%d t=%.2f %s frame %.1f ms scripts %.1f physics %.1f view step %.1f (was %.1f)" % [
				_rows.size(), Engine.get_process_frames(), _t, _world.region.region_id, r[0], r[1], r[2], view_step, prev_step])


func _report(region_id: String) -> void:
	var names := ["frame_ms", "scripts_ms", "physics_scripts_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls"]
	print("PERF region=%s frames=%d nodes=%d" % [region_id, _rows.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	for c in names.size():
		var values: Array[float] = []
		for r in _rows:
			values.append(r[c])
		values.sort()
		var mean := 0.0
		for v in values:
			mean += v
		mean /= maxf(values.size(), 1)
		print("PERF %-14s mean %7.2f  p50 %7.2f  p95 %7.2f  max %7.2f" % [names[c], mean,
				values[values.size() / 2], values[int(values.size() * 0.95)], values[-1]])
	# Smoothness: how far the view and the player moved each frame, as a
	# share of how far they should have (speed * frame time). Frames where
	# either stood still while walking, or lurched, show as judder.
	var still := 0
	var lurch := 0
	var counted := 0
	for i in range(2, _rows.size() - 1):
		var expected: float = _rows[i][12] * _rows[i][0] / 1000.0
		if expected < 0.5:
			continue
		var walked := _step(i)
		# standing still between two frames of walking (not stopped at a wall)
		if walked < expected * 0.3 and _step(i - 1) > expected * 0.5 and _step(i + 1) > expected * 0.5:
			still += 1
		elif walked > expected * 1.7:
			lurch += 1
		counted += 1
	print("PERF smooth walking_frames=%d stood_still=%d lurched=%d" % [counted, still, lurch])
	var csv := _env("PERF_CSV", "")
	if csv != "":
		var f := FileAccess.open(csv, FileAccess.WRITE)
		f.store_line("frame_ms,process_ms,physics_ms,render_cpu_ms,render_gpu_ms,draw_calls,player_x,player_y,canvas_x,canvas_y")
		for r in _rows:
			f.store_line(",".join(Array(r).map(func(v): return str(v))))


## How far the player was drawn from where they were the frame before.
func _step(i: int) -> float:
	return Vector2(_rows[i][10] - _rows[i - 1][10], _rows[i][11] - _rows[i - 1][11]).length()


func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback


## Prints how many processing nodes there are of each script or class.
func _census() -> void:
	var counts := {}
	for node in get_tree().root.find_children("*", "", true, false):
		if not (node.is_processing() or node.is_physics_processing()):
			continue
		var script: Script = node.get_script()
		var key: String = script.resource_path.get_file() if script else node.get_class()
		counts[key] = counts.get(key, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys:
		print("PERF census %4d %s" % [counts[k], k])
