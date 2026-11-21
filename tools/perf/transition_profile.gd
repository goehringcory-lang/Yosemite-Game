extends Node
## Goes through each kind of transition between places (a door, a fade, a
## trip on the map, a drive) and prints, frame by frame, how long each frame
## took and how far the cover over the screen had got, so a transition that
## skips ahead after a long frame, or cuts, shows up in numbers.
## Needs a window (not --headless):
##   xvfb-run godot --path . res://tools/perf/transition_profile.tscn
## Environment: TRANS_ONLY (one kind: door, fade, journey, drive),
## TRANS_CSV (a path for every frame's numbers).

var _world: Node
var _rows: Array = []
var _recording := false
var _last_usec := 0
var _kind := ""


func _ready() -> void:
	process_priority = 1 << 30
	# a way out if something hangs
	get_tree().create_timer(240.0, true, false, true).timeout.connect(get_tree().quit.bind(1))
	SaveManager.save_path = "user://transition_profile_save.json"
	SaveManager.delete_save()
	_world = load("res://scenes/world/world.tscn").instantiate()
	add_child(_world)
	for i in 3:
		await get_tree().process_frame
	await _world.go_to_region("curry_village", "arrival")
	GameClock.minutes = 11 * 60
	for i in 20:
		await get_tree().process_frame
	var only := OS.get_environment("TRANS_ONLY")
	var csv := ""
	for kind in ["door", "door_back", "fade", "journey", "drive"]:
		if only != "" and not kind.begins_with(only):
			continue
		await _run(kind)
		csv += _report(kind)
	if OS.get_environment("TRANS_CSV") != "":
		var f := FileAccess.open(OS.get_environment("TRANS_CSV"), FileAccess.WRITE)
		f.store_string(csv)
	get_tree().quit()


func _run(kind: String) -> void:
	_rows.clear()
	_kind = kind
	_last_usec = Time.get_ticks_usec()
	_recording = true
	match kind:
		"door":
			await _world.go_to_region("curry_store", "door")
		"door_back":
			await _world.go_to_region("curry_village", "arrival")
		"fade":
			_world.journeys = false
			await _world.go_to_region("happy_isles", "arrival", 20)
			_world.journeys = true
		"journey":
			await _world.go_to_region("glacier_point", "ledge_trail_top", 180, {"title": "Four Mile Trail", "on_foot": true})
		"drive":
			GameClock.minutes = 11 * 60
			var legs: Array = Park.legs_from(_world.region.hub_id)
			for leg in legs:
				if leg.open:
					print("TRANS drive to ", leg.to)
					await _world.travel(leg)
					break
	# and a while after, as the new place settles
	for i in 45:
		await get_tree().process_frame
	_recording = false
	for i in 20:
		await get_tree().process_frame


func _process(_delta: float) -> void:
	if not _recording:
		return
	var now := Time.get_ticks_usec()
	_rows.append([(now - _last_usec) / 1000.0, _cover()])
	_last_usec = now


## How much of the screen is covered this frame, 0 to 1: the HUD's fade,
## the door picture still showing, or the trip map's veil.
func _cover() -> float:
	var hud: HUD = _world.hud
	var amount: float = hud.fade.color.a if hud.fade.visible else 0.0
	var door := _world.get_node_or_null("DoorCover")
	if door:
		var mat := (door.get_child(0) as CanvasItem).material as ShaderMaterial
		var progress = mat.get_shader_parameter("progress")
		amount = maxf(amount, 1.0 - (float(progress) if progress != null else 0.0))
	for child in _world.get_children():
		if child is Journey:
			amount = maxf(amount, child._alpha)
	return amount


func _report(kind: String) -> String:
	var worst := 0.0
	var biggest_step := 0.0
	var steps := 0
	var moving := false
	var line := ""
	var csv := ""
	for i in _rows.size():
		var ms: float = _rows[i][0]
		var cover: float = _rows[i][1]
		worst = maxf(worst, ms)
		if i > 0:
			var step := absf(cover - float(_rows[i - 1][1]))
			if step > 0.0005:
				steps += 1
				biggest_step = maxf(biggest_step, step)
		line += "%d:%.2f " % [roundi(ms), cover]
		csv += "%s,%d,%.2f,%.3f\n" % [kind, i, ms, cover]
	print("TRANS %s frames=%d worst_frame=%.1fms moving_frames=%d biggest_jump=%.2f" % [kind, _rows.size(), worst, steps, biggest_step])
	print("  ", line)
	return csv
