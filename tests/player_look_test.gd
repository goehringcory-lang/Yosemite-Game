extends Node
## Headless test of making your own character (scripts/player/player_look.gd,
## scripts/ui/character_creator.gd): the look painted in the game comes out
## pixel for pixel as the shipped art, every option changes the picture, the
## look and name save with the game, the character screen works by keys from
## the title screen and from the pause menu, and the walking sprite, the
## portrait and the climbing figure all take the look.
## Run: godot --headless --path . res://tests/player_look_test.tscn
## Exit code is the number of failed checks. Uses its own save and settings files.

const Looks = preload("res://tools/npcgen/looks.gd")
const SAVE_PATH := "user://player_look_test_save.json"
const SETTINGS_PATH := "user://player_look_test_settings.cfg"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.path = SETTINGS_PATH
	Settings.load_settings()
	SaveManager.save_path = SAVE_PATH
	for n in range(1, SaveManager.SLOTS + 1):
		SaveManager.delete_slot(n)
	PlayerLook.reset()
	test_painted_as_shipped()
	test_options()
	test_name()
	test_save()
	test_climber()
	await test_title()
	await test_in_game()
	PlayerLook.reset()
	for n in range(1, SaveManager.SLOTS + 1):
		SaveManager.delete_slot(n)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Pixels that differ between two pictures (a see-through pixel's color
## doesn't count); -1 if their sizes differ.
func _differences(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if (p.a > 0.5) != (q.a > 0.5) or (p.a > 0.5 and p.to_rgba32() != q.to_rgba32()):
				n += 1
	return n


func _image(path: String) -> Image:
	var image := (load(path) as Texture2D).get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## The game's own painting of a look matches what tools/npcgen and
## tools/art32 made of the same look, so your character belongs with the cast.
func test_painted_as_shipped() -> void:
	check(PlayerLook.is_default() and PlayerLook.sheet() == load(PlayerLook.DEFAULT_SHEET), "the look the game shipped with uses the shipped sheet")
	var mine := PlayerLook.look()
	for key: String in Looks.PLAYER:
		check(str(mine.get(key)) == str(Looks.PLAYER[key]), "the first option of every part is the shipped look (%s)" % key)
	var sheet := Palette32.character_sheet(FigurePainter.new().draw_sheet(mine))
	check(_differences(sheet, _image(PlayerLook.DEFAULT_SHEET)) == 0, "the walking sheet painted in the game is the shipped one, pixel for pixel")
	var faces := Palette32.snap(PortraitPainter.new().strip(mine, "player"))
	check(_differences(faces, _image(PlayerLook.DEFAULT_FACES)) == 0, "and so are the four faces of the portrait")
	var wren := Palette32.character_sheet(FigurePainter.new().draw_sheet(Looks.LOOKS.wren_alvarez))
	check(_differences(wren, _image("res://assets/sprites/npcs/wren_alvarez.png")) == 0, "one of the cast painted the same way matches too")
	check(Palette32.nearest(Color("5c8f3c")) == Color("5c8f3c") and Palette32.nearest(Color("5c8f3d")) == Color("5c8f3c"), "a color snaps to the palette's nearest")


## Every option of every part gives a walking sheet and a portrait unlike the
## others (hair is compared bareheaded: a brimmed hat hides a bun).
func test_options() -> void:
	var painter := FigurePainter.new()
	var portraits := PortraitPainter.new()
	for part: Dictionary in PlayerLook.PARTS:
		PlayerLook.reset()
		check(part.options.size() >= 2 and str(part.name) != "", "%s has options to choose from" % part.id)
		var sheets: Array[Image] = []
		var faces: Array[Image] = []
		for i in part.options.size():
			if part.id == "hair_style":
				# a brimmed hat hides a bun, so hair is told apart bareheaded
				PlayerLook.set_choice("hat", PlayerLook.part("hat").options.size() - 1)
			PlayerLook.set_choice(part.id, i)
			sheets.append(Palette32.character_sheet(painter.draw_sheet(PlayerLook.look())))
			faces.append(Palette32.snap(portraits.paint(PlayerLook.look(), "player")))
		var same := PackedStringArray()
		for i in part.options.size():
			for j in range(i + 1, part.options.size()):
				if _differences(sheets[i], sheets[j]) == 0 and _differences(faces[i], faces[j]) == 0:
					same.append("%s = %s" % [part.options[i][0], part.options[j][0]])
		check(same.is_empty(), "every %s option looks different (%s)" % [part.id, ", ".join(same)])
	PlayerLook.reset()
	PlayerLook.set_choice("skin", -1)
	check(PlayerLook.chosen("skin") == PlayerLook.part("skin").options.size() - 1, "Left from the first option wraps to the last")
	var before := PlayerLook.version
	PlayerLook.set_choice("skin", PlayerLook.chosen("skin"))
	check(PlayerLook.version == before, "choosing what you have changes nothing")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	PlayerLook.randomize_look(rng)
	var first := PlayerLook.save_data()
	PlayerLook.randomize_look(rng)
	check(first != PlayerLook.save_data() and PlayerLook.player_name in PlayerLook.NAMES, "Surprise me deals a new look and a name each time")
	check(not PlayerLook.is_default() and PlayerLook.sheet() is ImageTexture and PlayerLook.sheet().get_size() == (load(PlayerLook.DEFAULT_SHEET) as Texture2D).get_size(),
		"a look of your own is painted at the shipped sheet's size")
	check(PlayerLook.face("happy") != PlayerLook.face("sad") and PlayerLook.face("happy").get_size() == Vector2(80, 80), "with a face for each mood")
	PlayerLook.reset()


func test_name() -> void:
	check(PlayerLook.display_name() == "You", "with no name you are \"You\"")
	PlayerLook.set_player_name("   Juniper of the High Sierra  \n")
	check(PlayerLook.player_name == "Juniper of t" and PlayerLook.player_name.length() <= PlayerLook.MAX_NAME, "a name is trimmed and kept short (%s)" % PlayerLook.player_name)
	PlayerLook.set_player_name("[E] Sage")
	check(PlayerLook.player_name == "E Sage", "and can't carry the brackets hints use")
	PlayerLook.set_player_name("Sage")
	check(PlayerLook.display_name() == "Sage", "your name is what your own lines carry")
	check(Portraits.for_speaker("You") == PlayerLook.face() and Portraits.for_speaker("Sage") == PlayerLook.face(), "and your face goes with it")
	PlayerLook.set_player_name("Wren Alvarez")
	check(Portraits.for_speaker("Wren Alvarez") != PlayerLook.face(), "taking a cast member's name doesn't take their face in their own lines")
	for part: Dictionary in PlayerLook.PARTS:
		for option: Array in part.options:
			check(str(option[0]).length() <= 12, "option names fit their row (%s)" % option[0])
	PlayerLook.reset()


func test_save() -> void:
	PlayerLook.set_choice("hat", 3)
	PlayerLook.set_choice("top", 4)
	PlayerLook.set_choice("glasses", 1)
	PlayerLook.set_player_name("Sorrel")
	var saved := PlayerLook.save_data()
	check(SaveManager.save_game(), "the game saves")
	var text := JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)))
	check(text.contains("Sorrel") and SaveManager.slot_info(1).get("name") == "Sorrel", "the save carries your name, for the slot's line too")
	PlayerLook.reset()
	check(SaveManager.load_game() and PlayerLook.save_data() == saved, "loading brings the look and name back")
	check(PlayerLook.chosen("hat") == 3 and PlayerLook.chosen("glasses") == 1, "each part as it was chosen")
	# a save from before you could choose
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	old.erase("player")
	FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify(old))
	check(SaveManager.load_game() and PlayerLook.is_default() and PlayerLook.player_name == "", "a save from before this loads as the look it had")
	PlayerLook.load_data({"name": 7, "look": {"hat": "crown", "top": false, "skin": "c8905e"}})
	check(PlayerLook.chosen("hat") == 0 and PlayerLook.chosen("top") == 0 and PlayerLook.chosen_name("skin") == "Tan", "options a save names that aren't there fall back to the first")
	PlayerLook.set_choice("hat", 2)
	NewGame.reset_all()
	check(PlayerLook.is_default() and PlayerLook.player_name == "", "quitting to the title leaves no look behind for the next game")
	SaveManager.delete_save()


## The climbing figure wears your colors, and goes back to its own.
func test_climber() -> void:
	PlayerLook.reset()
	var pose := {"hr": Vector2(6, -18), "hl": Vector2(-6, -16), "fr": Vector2(4, 16), "fl": Vector2(-4, 18)}
	var kit := {"climbing_shoes": 1, "harness": 1}
	var shipped := ClimbSprites.climber(pose, kit).get_image()
	check(PlayerLook.climb_colors().is_empty() and ClimbSprites.SHIRT == ClimbSprites.DEFAULT_COLORS.shirt, "the shipped look climbs in the shipped colors")
	PlayerLook.set_choice("top", 4)
	PlayerLook.set_choice("hat", PlayerLook.part("hat").options.size() - 1)
	var mine := ClimbSprites.climber(pose, kit).get_image()
	check(ClimbSprites.SHIRT == Palette32.nearest(Color(str(PlayerLook.chosen_value("top")))) and ClimbSprites.HAT_KIND == "none", "a look of your own puts its shirt on the climber, and takes the hat off")
	check(_differences(shipped, mine) > 0, "so the climber is painted afresh")
	PlayerLook.reset()
	check(_differences(shipped, ClimbSprites.climber(pose, kit).get_image()) == 0, "and the shipped look paints as it always did")


func _open_title() -> TitleScreen:
	var title: TitleScreen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title.finish_intro()
	return title


## New Game goes by way of the character screen, worked by keys.
func test_title() -> void:
	var title := await _open_title()
	_press("interact")
	var creator := title._creator
	check(creator.is_open() and not title._starting and not title._menu.visible, "New Game opens the character screen first")
	check(creator.row() == CharacterCreator.Row.NAME and PlayerLook.is_default(), "on Name, with the shipped look")
	_press("move_right")
	check(PlayerLook.player_name == PlayerLook.NAMES[0], "Right on Name deals a name (%s)" % PlayerLook.player_name)
	_press("interact")
	check(creator._editing and creator._name_edit.visible, "E opens the name to type in")
	_press("move_down")
	check(creator.row() == CharacterCreator.Row.NAME, "and the keys don't move the cursor while typing")
	creator._name_edit.text = "Tioga Pat"
	creator._name_edit.text_submitted.emit("Tioga Pat")
	check(not creator._editing and PlayerLook.player_name == "Tioga Pat", "Enter keeps the name typed")
	_press("interact")
	creator._name_edit.text = "Someone else"
	_press("ui_cancel")
	check(not creator._editing and creator.is_open() and PlayerLook.player_name == "Tioga Pat", "Esc while typing keeps the old name and stays on the screen")
	_press("move_down")
	_press("move_right")
	check(PlayerLook.chosen("skin") == 1, "Right changes the part under the cursor")
	_press("move_left")
	_press("move_left")
	check(PlayerLook.chosen("skin") == PlayerLook.part("skin").options.size() - 1, "and Left goes back, round the end")
	await get_tree().process_frame
	await get_tree().process_frame
	check(creator._figure_frame.atlas == PlayerLook.sheet() and creator._face.texture == PlayerLook.face("happy") and creator._caption.text == "Tioga Pat",
		"the picture beside the list keeps up")
	for i in creator._rows.size():
		_press("move_down")
		var line: Control = creator._lines[creator._cursor]
		check(line.visible, "the row under the cursor is always in view (%d)" % creator._cursor)
	check(creator._lines[creator._rows.size() - 1].visible and creator._lines[creator._rows.size() - 2].visible, "Start and Surprise me never scroll away")
	creator.go_to(CharacterCreator.Row.SURPRISE)
	var before := PlayerLook.version
	_press("interact")
	check(PlayerLook.version != before, "Surprise me changes the look")
	_press("ui_cancel")
	check(not creator.is_open() and title._menu.visible and PlayerLook.is_default() and PlayerLook.player_name == "", "Esc goes back to the title and forgets the look")
	check(not SaveManager._fresh and not title._starting, "and no new game is started")
	_press("interact")
	creator.go_to(CharacterCreator.Row.PART, "top")
	_press("move_right")
	creator.go_to(CharacterCreator.Row.START)
	_press("interact")
	check(title._starting and SaveManager._fresh and PlayerLook.chosen("top") == 1, "Start begins the new game as you made yourself")
	title.queue_free()
	await get_tree().process_frame
	SaveManager.cancel_fresh()

	# with a game saved, New Game picks a slot first, and Load never asks
	FileAccess.open(SaveManager.slot_path(1), FileAccess.WRITE).store_string(JSON.stringify({"clock": {"day": 2}, "summary": {"saved_at": 1000, "name": "Sorrel"}}))
	title = await _open_title()
	title.select(TitleScreen.Option.NEW_GAME)
	check(title._pause.is_open() and not title._creator.is_open(), "with a save, New Game asks for a slot first")
	title._pause._refresh()
	check(title._pause._slot_details[0].text.contains("Sorrel"), "a slot's line says whose game it is")
	title._pause.choose_slot(2)
	check(title._creator.is_open() and not title._starting and SaveManager.slot == 2, "then the character screen")
	_press("ui_cancel")
	check(not SaveManager._fresh and title._menu.visible, "backing out leaves the saves as they were")
	title.select(TitleScreen.Option.LOAD)
	title._pause.choose_slot(1)
	check(title._starting and not title._creator.is_open(), "Load game starts at once")
	title.queue_free()
	await get_tree().process_frame
	SaveManager.delete_slot(1)
	SaveManager.slot = 1
	PlayerLook.reset()


## In a game: the player wears the look, and the pause menu's "Your look"
## changes it or leaves it be.
func test_in_game() -> void:
	PlayerLook.set_choice("top", 3)
	PlayerLook.set_player_name("Lark")
	SaveManager.start_fresh()
	var world: Node = load(TitleScreen.WORLD_SCENE).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Player = world.player
	check(player.sprite.texture == PlayerLook.sheet() and player.sprite.hframes == CharacterSheet.columns(PlayerLook.sheet()), "the player walks about in the look you made")
	check(PlayerLook.chosen("top") == 3 and PlayerLook.player_name == "Lark", "and a new game keeps it")
	var pause: PauseMenu = get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	check(pause._card_date.text.begins_with("Lark") and pause._card_face.texture == PlayerLook.face(), "the pause menu's card has your name and face")
	pause._cursor = PauseMenu.Option.LOOK
	_press("interact")
	var creator := pause._creator
	check(creator != null and creator.is_open() and not pause._panel.visible and pause.is_open(), "Your look opens the character screen over the pause menu")
	check(PlayerLook.chosen("top") == 3 and PlayerLook.player_name == "Lark", "on the look you have")
	creator.go_to(CharacterCreator.Row.PART, "hat")
	_press("move_right")
	check(PlayerLook.chosen("hat") == 1, "it changes as on the title screen")
	_press("ui_cancel")
	check(not creator.is_open() and pause.is_open() and pause._panel.visible, "Esc goes back to the pause menu")
	check(PlayerLook.chosen("hat") == 0 and PlayerLook.chosen("top") == 3 and PlayerLook.player_name == "Lark", "and leaves you as you were")
	_press("interact")
	creator.go_to(CharacterCreator.Row.PART, "hat")
	_press("move_right")
	creator.go_to(CharacterCreator.Row.START)
	_press("interact")
	check(not creator.is_open() and PlayerLook.chosen("hat") == 1 and player.sprite.texture == PlayerLook.sheet(), "Done puts the new look on at once")
	check(pause._card_face.texture == PlayerLook.face(), "on the card too")
	pause.close()
	# saved, and loaded into a game that starts from the shipped look
	var saved := PlayerLook.save_data()
	check(SaveManager.save_game(), "the game saves with the look")
	world.queue_free()
	await get_tree().process_frame
	NewGame.reset_all()
	world = load(TitleScreen.WORLD_SCENE).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	player = world.player
	check(PlayerLook.save_data() == saved and player.sprite.texture == PlayerLook.sheet() and not PlayerLook.is_default(),
		"carrying on a saved game puts its look back on the player")
	world.queue_free()
	await get_tree().process_frame
	NewGame.reset_all()
	SaveManager.delete_save()


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
