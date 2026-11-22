extends Node
## Goes from area to area the ways a player does (through a door, on the trip
## map, walking over a seam) and prints the frames that took too long around
## each change, so stutter at area changes can be found. Needs a window
## (xvfb-run is fine), not --headless.
## Environment:
##   PERF_START    region to begin in (default curry_village)
##   PERF_TRIPS    comma-separated trips, each kind:region:spawn[:minutes]
##                 kind is door (no time), trip (minutes on the trip map) or
##                 walk (hold a direction key for some seconds:
##                 walk:<move_left...>:<seconds>)
##   PERF_SETTLE   frames to wait after each trip (default 90)
##   PERF_SLOW_MS  frames slower than this are listed (default 25)
##   PERF_CSV      optional path for a per-frame CSV (frame ms, trip index)
## Run: xvfb-run godot --path . res://tools/perf/transition_profile.tscn

const DEFAULT_TRIPS := "door:curry_store:arrival,door:curry_village:arrival,trip:yosemite_village:arrival:20,door:village_store_inside:arrival,door:yosemite_village:arrival,walk:move_left:6,trip:tuolumne_meadows:arrival:60"

var _world: Node
var _last := 0
var _trip := -1
var _frames: Array[PackedFloat64Array] = []
var _slow_ms := 25.0
## What the frame showed: PLAY (the world), STILL (a cover that doesn't
## move: the door's picture, the open map), MOVING (the door wipe, the map
## fading or its marker running). Stutter only shows in PLAY and MOVING.
enum { PLAY, STILL, MOVING }
const PHASES := ["play", "still", "moving"]
var _phase := PLAY
var _process_start := 0
var _physics_start := 0
var _script_us := 0.0
var _physics_us := 0.0
var _pre_draw := 0
var _draw_us := 0.0


## Runs after every other node's callbacks, to time them.
class _End extends Node:
	var profile: Node
	func _ready() -> void:
		process_priority = 1 << 30
		process_physics_priority = 1 << 30
	func _process(_delta: float) -> void:
		profile._script_us = Time.get_ticks_usec() - profile._process_start
	func _physics_process(_delta: float) -> void:
		profile._physics_us += Time.get_ticks_usec() - profile._physics_start


func _physics_process(_delta: float) -> void:
	_physics_start = Time.get_ticks_usec()


func _ready() -> void:
	process_priority = -(1 << 30)
	process_physics_priority = -(1 << 30)
	var end := _End.new()
	end.profile = self
	add_child(end)
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre_draw = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _draw_us = Time.get_ticks_usec() - _pre_draw)
	_slow_ms = float(_env("PERF_SLOW_MS", "25"))
	seed(7)
	SaveManager.save_path = "user://transition_profile_save.json"
	SaveManager.delete_save()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	for i in 5:
		await get_tree().process_frame
	await _world.go_to_region(_env("PERF_START", "curry_village"), "arrival")
	GameClock.minutes = 11 * 60
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	# let the start settle and the neighbors preload, as a player would
	await _wait_frames(240)
	_last = Time.get_ticks_usec()
	var trips := _env("PERF_TRIPS", DEFAULT_TRIPS).split(",", false)
	for i in trips.size():
		_trip = i
		var parts := trips[i].split(":")
		var t0 := Time.get_ticks_usec()
		var before := _frames.size()
		match parts[0]:
			"door":
				await _world.go_to_region(parts[1], parts[2])
			"trip":
				await _world.go_to_region(parts[1], parts[2], int(parts[3]), {"title": "Profile trip"})
			"walk":
				Input.action_press(parts[1])
				await get_tree().create_timer(float(parts[2])).timeout
				Input.action_release(parts[1])
		await _wait_frames(int(_env("PERF_SETTLE", "90")))
		_report(i, trips[i], before, (Time.get_ticks_usec() - t0) / 1000.0)
	_trip = -1
	var csv := _env("PERF_CSV", "")
	if csv != "":
		var f := FileAccess.open(csv, FileAccess.WRITE)
		f.store_line("frame_ms,trip")
		for r in _frames:
			f.store_line("%.2f,%d" % [r[0], int(r[1])])
	get_tree().quit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_process_start = now
	if _trip >= 0:
		var ms := (now - _last) / 1000.0
		var vp := get_viewport().get_viewport_rid()
		_frames.append(PackedFloat64Array([ms, _trip, RenderingServer.viewport_get_measured_render_time_cpu(vp),
				RenderingServer.viewport_get_measured_render_time_gpu(vp), _phase]))
		_phase = _phase_now()
		if ms > _slow_ms * 2.0:
			print("SLOW frame %d %.1f ms (last frame's scripts %.1f physics %.1f draw %.1f; render cpu %.1f gpu %.1f) trip %d" % [Engine.get_process_frames(), ms,
					_script_us / 1000.0, _physics_us / 1000.0, _draw_us / 1000.0, _frames[-1][2], _frames[-1][3], _trip])
	_physics_us = 0.0
	_last = now


func _phase_now() -> int:
	var journey := _world.get_node_or_null("Journey")
	if journey:
		var a: float = journey.get("_alpha")
		return MOVING if journey.get("_running") or (a > 0.0 and a < 1.0) else STILL
	var cover := _world.get_node_or_null("DoorCover")
	if cover:
		var wipe := (cover.get_child(0) as CanvasItem).material as ShaderMaterial
		var progress: Variant = wipe.get_shader_parameter("progress")
		return MOVING if progress != null and float(progress) > 0.0 else STILL
	return PLAY


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _report(i: int, what: String, from: int, took_ms: float) -> void:
	var worst := [0.0, 0.0, 0.0]
	var count := [0, 0, 0]
	var slow: Array[String] = []
	for k in range(from, _frames.size()):
		var ms: float = _frames[k][0]
		var phase := int(_frames[k][4])
		worst[phase] = maxf(worst[phase], ms)
		count[phase] += 1
		if ms > _slow_ms:
			slow.append("%d%s:%.0f" % [k - from, PHASES[phase][0], ms])
	print("TRANS %d %-36s in %-20s took %5.0f ms  worst play %5.1f (%d)  still %5.1f (%d)  moving %5.1f (%d)  slow [%s]" % [
		i, what, _world.region.region_id, took_ms, worst[0], count[0], worst[1], count[1], worst[2], count[2], " ".join(slow)])


func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback
