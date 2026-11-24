extends Node
## Screenshots of camping anywhere (Backpacking): you wearing the
## backpacking pack in Little Yosemite Valley at dusk with "Make camp" up,
## the box that warns about a bad spot, the morning after a clean camp,
## and the wilderness ranger standing over a bad one.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/backpacking_shot.tscn

const Terrain := preload("res://scripts/world/terrain.gd")


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 6) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/backpacking_%s.png" % [dir, shot_name])
	print("saved ", shot_name)


func _box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


## Turns past the day's page that sleeping shows.
func _close_day_page() -> void:
	for child in get_tree().root.find_children("*", "DaySummary", true, false):
		if child.is_open():
			child.press()


## A spot in the middle part of the region for which [param want] is true.
func _spot(region: Region, want: Callable, near: Vector2) -> Variant:
	var ground := region.get_ground()
	var bounds := region.get_bounds().grow(-120.0)
	var best = null
	var best_d := INF
	for cell in ground.get_used_cells():
		var at := ground.to_global(ground.map_to_local(cell))
		if not bounds.has_point(ground.to_local(at)) or not want.call(ground, at):
			continue
		var d := at.distance_to(near)
		if d < best_d:
			best_d = d
			best = at
	return best


func _place(world: Node, at: Vector2, facing := Vector2i.DOWN) -> void:
	world.player.global_position = at
	world.player.facing = facing
	world.player.interaction_area.position = Vector2(facing) * 24.0
	world._settle_view()


func _set_time(minutes: int) -> void:
	GameClock.minutes = minutes
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)


func _ready() -> void:
	SaveManager.save_path = "user://backpacking_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	var guide: FirstDay = world.get_node("FirstDay")
	for id: String in FirstDay.LESSONS:
		guide.mark(id)
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 9
	GameClock.paused = true
	Gear.add(Backpacking.PACK)
	Gear.add(Backcountry.CANISTER)
	Inventory.add(Backcountry.PERMIT)
	Inventory.add("pilot_bread", 3)
	Inventory.add("trail_mix", 2)

	await world.go_to_region("little_yosemite_valley", "camp")
	GameClock.season = GameClock.Season.SUMMER
	_set_time(19 * 60 + 15)
	var region: Region = world.region
	var camp := region.get_spawn("camp").global_position
	var clean = _spot(region, func(g: TileMapLayer, at: Vector2) -> bool:
		var t := Backpacking.type_at(g, at)
		return t >= 0 and not Terrain.is_solid(t) and t != Terrain.CREEK and Backpacking.problems(region, at).is_empty(), camp + Vector2(200, 0))
	if clean == null:
		push_error("no clean spot")
		get_tree().quit(1)
		return
	_place(world, clean, Vector2i.LEFT)
	await _snap(dir, "make_camp", 40)

	# The box, at a spot right by the trail.
	var by_trail = _spot(region, func(g: TileMapLayer, at: Vector2) -> bool: return Backpacking.type_at(g, at) == Terrain.TRAIL, clean + Vector2(0, -160))
	if by_trail != null:
		Inventory.add("dried_apples", 12)
		_place(world, by_trail)
		world.player.camp_spot.interact(world.player)
		for i in 30:
			await get_tree().process_frame
		var box := _box()
		if box:
			box.reveal_all()
			await _snap(dir, "warning", 6)
			box._cursor = 2
			box.press()
		for i in 10:
			await get_tree().process_frame

	# The ranger, in the morning, after that bad camp.
	if by_trail != null:
		_set_time(21 * 60)
		var run := func() -> void:
			await world.camp_out(by_trail, Backpacking.problems(region, by_trail, true))
		run.call()
		var shots := {"Morning. Wilderness ranger": "ranger", "taking your food": "ranger_food"}
		for i in 3000:
			await get_tree().process_frame
			_close_day_page()
			var box := _box()
			if box == null:
				continue
			box.reveal_all()
			if shots.has("Morning. Wilderness ranger") and "Morning. Wilderness ranger" in box._text_label.text:
				# the two of you, without the box over you
				box.visible = false
				await _snap(dir, "ranger_beside", 4)
				box.visible = true
			for key: String in shots.keys():
				if key in box._text_label.text:
					await _snap(dir, shots[key], 6)
					shots.erase(key)
			box.press()
			if shots.is_empty():
				break
		for i in 600:
			await get_tree().process_frame
			var box := _box()
			if box:
				box.press()
	get_tree().quit()
