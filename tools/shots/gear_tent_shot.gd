extends Node
## Saves screenshots of the gear tent: pitched beside the cabin, the gear
## laid out inside by day (a mid-game rack), a piece you haven't found yet,
## "Pack for a climb", and the tent by lantern light with a full rack.
## Uses its own save. Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/gear_tent_shot.tscn

const DONE := ["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "lamon_orchard", "leonard_belay",
	"eichorn_apron", "robbins_clean", "hodges_patrol", "wren_apron", "greg_first_rod"]
const MID := {"climbing_shoes": 1, "approach_shoes": 1, "chalk_bag": 1, "harness": 1, "rope": 1, "cam": 10, "quickdraw": 10,
	"belay_device": 1, "fly_rod": 1, "ice_axe": 1, "crampons": 1, "nut_mid": 1, "cam_05": 1, "bear_canister": 1}


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 30:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/gear_tent_%s.png" % [dir, shot_name])


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
	SaveManager.save_path = "user://gear_tent_shot_save.json"
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
	Gear.owned = MID.duplicate()
	Gear.cached = {}
	Gear.unpack_all()
	Gear.pack_for({"rope": 1, "harness": 1, "cam": 6, "quickdraw": 6, "belay_device": 1})
	Camp.changed.emit()
	await world.go_to_region(Park.HOME_REGION, Park.HOME_SPAWN)
	for i in 12:
		await get_tree().process_frame
	var tent := world.region.find_child("GearTent", true, false) as GearTent
	var player: Player = world.player
	player.global_position = tent.global_position + Vector2(-30, 40)
	player.facing = Vector2i.UP
	await _snap(dir, scale, "outside")
	var view := GearTentView.open(player)
	await _snap(dir, scale, "inside")
	for i in 4:
		await _press("move_right")
	await _press("interact")
	await _snap(dir, scale, "pack_one")
	await _press("move_left")
	await _press("move_left")
	await _press("move_left")
	await _press("move_left")
	await _snap(dir, scale, "missing")
	await _press("run")
	await _snap(dir, scale, "climbs")
	await _press("ui_cancel")
	view.close()
	# a full rack, by lantern light
	GameClock.minutes = 22 * 60
	for gear: GearData in Gear.GEAR:
		if not gear.generic:
			Gear.owned[gear.id] = maxi(Gear.count(gear.id), 2 if gear.kind in ["cam", "draw"] else 1)
	Gear.unpack_all()
	Gear.changed.emit()
	view = GearTentView.open(player)
	await _snap(dir, scale, "night_full")
	view.close()
	SaveManager.delete_save()
	get_tree().quit()
