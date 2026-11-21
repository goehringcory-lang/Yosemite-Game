extends Node
## Screenshots of the Happenings around the park: the painter at Tunnel
## View as a storm clears, the fisherman at Happy Isles with his lost fly
## box glinting down the bank, a question in El Capitan Meadow, and the
## Journal's "Heard around the park" and the Logbook's tally.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/happenings_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, frames := 20) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/happenings_%s.png" % [dir, shot_name])


## A day [param id] fits, after the first morning.
func _day_for(id: String) -> Vector3i:
	var h := Happenings.get_happening(id)
	for year in [1, 2]:
		for season in h.seasons:
			for day in range(2, GameClock.DAYS_PER_SEASON + 1):
				if Happenings.fits_day(h, year, season, day):
					return Vector3i(year, season, day)
	return Vector3i(1, 0, 2)


## Goes to [param id]'s area on a day it's out (with [param also] heard
## about too), at [param hour], and stands you [param from] its person.
func _go(world: Node, id: String, hour: float, from: Vector2, also := []) -> HappeningFigure:
	var h := Happenings.get_happening(id)
	var date := _day_for(id)
	GameClock.year = date.x
	GameClock.season = date.y
	GameClock.day = date.z
	GameClock.minutes = int(hour * 60.0)
	Happenings.day_of = Friendship.today()
	Happenings.out_today = PackedStringArray([id] + also)
	Happenings.done_today = []
	await world.go_to_region(h.region, "arrival")
	GameClock.paused = true
	GameClock.minutes = int(hour * 60.0)
	GameClock._elapsed = 0.0
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	for i in 10:
		await get_tree().physics_frame
	var figure: HappeningFigure = null
	for node in world.region.entities.get_children():
		if node is HappeningFigure and node.happening.id == id:
			figure = node
	if figure:
		world.player.global_position = figure.global_position + from
		world.player.facing = Vector2i.UP
		world._camera().reset_smoothing()
	else:
		push_warning("%s is not out" % id)
	world.hud.message_label.modulate.a = 0.0
	return figure


func _box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


func _ready() -> void:
	SaveManager.save_path = "user://happenings_shot_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	for hub in ["glacier_point", "tuolumne_meadows", "wawona", "el_portal"]:
		Park.unlock_hub(hub)

	# Tunnel View, the afternoon a storm clears.
	await _go(world, "tunnel_view_storm", 16.5, Vector2(-50, 50))
	await _snap(dir, "tunnel_view", 30)

	# Happy Isles: Walt's told you about his fly box, and there it is.
	var walt := await _go(world, "happy_isles_fly_box", 9.0, Vector2(120, 40))
	Happenings.asked_today = PackedStringArray(["happy_isles_fly_box"])
	Happenings.changed.emit()
	if walt:
		var lost := HappeningField.spot_in(world.region, "isles", Vector2(230, 70))
		world.player.global_position = (walt.global_position + lost) / 2.0 + Vector2(0, 50)
		world._camera().reset_smoothing()
	await _snap(dir, "happy_isles", 30)

	# El Capitan Meadow: where are the climbers?
	var harold := await _go(world, "el_cap_spotting", 11.0, Vector2(0, 28))
	if harold:
		harold.interact(world.player)
		for i in 200:
			await get_tree().process_frame
			var box := _box()
			if box == null:
				continue
			if not box._options.is_empty():
				break
			box.reveal_all()
			if i % 12 == 11:
				box.press()
		await _snap(dir, "question", 6)
		var box := _box()
		if box:
			box.press(false)
			await get_tree().process_frame
			box.close()
	world.player.can_act = true

	# The Journal: heard around the park today, and the Logbook's tally.
	await _go(world, "glacier_breakfast", 7.0, Vector2(0, 40), ["mirror_lake_reflection", "leidig_evening_talk"])
	Happenings.seen = {"el_cap_spotting": 1, "happy_isles_fly_box": 1, "tunnel_view_storm": 2, "mirror_lake_gone": 1}
	Achievements.pending_toasts().clear()
	Perks.pending_toasts().clear()
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.JOURNAL)
	for i in 30:
		await get_tree().process_frame
	# scroll to the "Heard around the park" heading
	for label in journal._body.get_children():
		if label is Label and label.text == "Heard around the park":
			journal.scroll_by(int(label.position.y) - 8)
	await _snap(dir, "journal", 10)
	journal.show_tab(Journal.Tab.LOGBOOK)
	for i in 10:
		await get_tree().process_frame
	for label in journal._body.get_children():
		if label is Label and label.text.begins_with("Happenings:"):
			journal.scroll_by(int(label.position.y) - 8)
	await _snap(dir, "logbook", 10)
	SaveManager.delete_save()
	get_tree().quit()
