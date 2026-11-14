extends Node
## Saves screenshots of the gear bag and the gear rack at camp: the rack's
## menu, "Pack for a climb", the rack with gear hanging on it, and the
## journal's Backpack page with the bag and the rack. Uses its own save.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/gear_bag_shot.tscn

const DONE := ["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "lamon_orchard", "leonard_belay",
	"eichorn_apron", "robbins_clean", "hodges_patrol", "wren_apron", "greg_first_rod"]


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/gear_bag_%s.png" % [dir, shot_name])


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	for i in 4:
		await get_tree().process_frame


func _ready() -> void:
	SaveManager.save_path = "user://gear_bag_shot_save.json"
	SaveManager.delete_save()
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 10 * 60
	GameClock.paused = true
	QuestLog.completed.assign(DONE)
	QuestLog.unlocks.append(Guidebook.ABILITY)
	for id: String in {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "rope": 1, "cam": 10, "quickdraw": 10, "belay_device": 1, "fly_rod": 1, "ice_axe": 1, "crampons": 1}:
		Gear.owned[id] = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "rope": 1, "cam": 10, "quickdraw": 10, "belay_device": 1, "fly_rod": 1, "ice_axe": 1, "crampons": 1}[id]
	Gear.unpack_all()
	Gear.pack_for({"rope": 1, "harness": 1, "cam": 6, "quickdraw": 6, "belay_device": 1})
	Camp.changed.emit()
	await world.go_to_region(Park.HOME_REGION, Park.HOME_SPAWN)
	for i in 12:
		await get_tree().process_frame
	var piece := world.region.find_child(CampPiece.node_name("gear_rack"), true, false) as CampPiece
	var player: Player = world.player
	player.global_position = piece.global_position + Vector2(0, 30)
	player.facing = Vector2i.UP
	for i in 12:
		await get_tree().process_frame
	await _snap(dir, scale, "rack")
	piece.open_rack(player)
	await _snap(dir, scale, "menu")
	await _press("interact")
	await _snap(dir, scale, "routes")
	await _press("ui_cancel")
	await _press("ui_cancel")
	await _press("ui_cancel")
	for i in 6:
		await get_tree().process_frame
	var journal := get_tree().get_first_node_in_group("journal")
	if journal:
		journal.open(journal.Tab.BACKPACK)
		await _snap(dir, scale, "backpack")
	SaveManager.delete_save()
	get_tree().quit()
