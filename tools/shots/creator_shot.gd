extends Node
## Saves screenshots of making your own character: the "Who's arriving?"
## screen as it opens, with a look and a name chosen, and typing a name; then
## that character in the world, in a conversation of their own, on the pause
## menu's card and on the climbing screen. Uses its own save and settings.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/creator_shot.tscn

## The look in the shots, part id -> option name.
const LOOK := {
	"skin": "Brown", "hair_style": "Braid", "hair": "Black", "hat": "Beanie", "hat_color": "Poppy",
	"top_style": "Plaid", "top": "River", "bottom": "Charcoal", "pack_color": "Pine",
}


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/creator_%s.png" % [dir, shot_name])


func _wear() -> void:
	for id: String in LOOK:
		var options: Array = PlayerLook.part(id).options
		for i in options.size():
			if options[i][0] == LOOK[id]:
				PlayerLook.set_choice(id, i)
	PlayerLook.set_player_name("Juniper")


func _ready() -> void:
	Settings.path = "user://creator_shot_settings.cfg"
	Settings.load_settings()
	SaveManager.save_path = "user://creator_shot_save.json"
	for n in range(1, SaveManager.SLOTS + 1):
		SaveManager.delete_slot(n)
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	var title: TitleScreen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	for i in 40:
		await get_tree().process_frame
	title.finish_intro()
	title.select(TitleScreen.Option.NEW_GAME)
	var creator := title._creator
	await _snap(dir, scale, "open")
	_wear()
	creator.go_to(CharacterCreator.Row.PART, "top_style")
	await _snap(dir, scale, "look")
	creator.go_to(CharacterCreator.Row.NAME)
	creator.select()
	await _snap(dir, scale, "name")
	creator._finish_name(true)
	creator.go_to(CharacterCreator.Row.START)
	await _snap(dir, scale, "start")
	title.queue_free()
	await get_tree().process_frame
	SaveManager.start_fresh()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	await world.go_to_region("curry_village", "arrival")
	for i in 12:
		await get_tree().process_frame
	await _snap(dir, scale, "world")
	var box := DialogueBox.open(world.player)
	box.say([{"speaker": "You", "text": "A tent, a pair of approach shoes, and the whole Valley to walk."}])
	for i in 90:
		await get_tree().process_frame
	await _snap(dir, scale, "talk")
	box.close()
	for i in 10:
		await get_tree().process_frame
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	await _snap(dir, scale, "pause")
	pause.close()
	world.queue_free()
	await get_tree().process_frame
	# on the wall
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1}
	GameClock.minutes = 11 * 60
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(load("res://data/routes/firefall_slab.tres"), 4)
	add_child(game)
	await get_tree().process_frame
	game.skip_intro()
	game._banner_age = 99.0
	game._speech_age = 99.0
	for i in 30:
		await get_tree().process_frame
	await _snap(dir, scale, "climb")
	print("Saved the character shots to ", dir)
	get_tree().quit()
