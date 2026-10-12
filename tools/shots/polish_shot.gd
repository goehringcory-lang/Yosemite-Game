extends Node
## Screenshots of the game-feel touches: the "you got this" cards, a
## conversation with a portrait, the clock dial, and the end-of-day summary.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/polish_shot.tscn


func _snap(dir: String, shot_name: String, frames := 8) -> void:
	for i in frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/polish_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://polish_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	await world.go_to_region("curry_village", "arrival")
	for i in 12:
		await get_tree().process_frame
	# The cards: a stack of forage, a cooked dish, and new gear.
	Inventory.add("wild_strawberry")
	Inventory.add("wild_strawberry")
	Inventory.add("miners_lettuce")
	Inventory.add("acorn_cake")
	Gear.add("cam")
	await _snap(dir, "toasts", 20)
	# A conversation with a portrait, and a shop's choices.
	var box := DialogueBox.open(world.player)
	box.say([{"speaker": "Wren Alvarez", "text": "Heels low, trust the rubber. That's all slab is. Well, that and not looking down. Ready when you are: I'll belay first."}])
	box.reveal_all()
	await _snap(dir, "dialogue")
	box.choose("What'll it be? Everything here trades for food.", ["A cam for 40 food energy", "Two quickdraws for 24 food energy", "Nothing, thanks"], "Marty Kessler")
	box.reveal_all()
	await _snap(dir, "dialogue_choice")
	box.close()
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	pause._show_page(PauseMenu.Page.SETTINGS)
	await _snap(dir, "settings")
	pause.close()
	get_tree().quit()
