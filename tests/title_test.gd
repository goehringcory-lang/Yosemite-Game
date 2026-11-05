extends Node
## Headless test of the title screen (scripts/ui/title_screen.gd) and the
## credits (scripts/ui/credits.gd): the menu with and without a save, New Game
## asking before it starts over, Settings and Credits opening and closing by
## keys, the credits carrying the required map data and license notices, and
## SaveManager starting fresh without losing the old save.
## Run: godot --headless --path . res://tests/title_test.tscn
## Exit code is the number of failed checks. Uses its own save and settings files.

const SAVE_PATH := "user://title_test_save.json"
const SETTINGS_PATH := "user://title_test_settings.cfg"

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
	SaveManager.delete_save()
	test_project()
	test_credits_text()
	await test_without_save()
	await test_with_save()
	await test_fresh_start()
	await test_intro()
	await test_end_credits()
	test_reset_all()
	SaveManager.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_project() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/title_screen.tscn", "the game opens on the title screen")
	check(ResourceLoader.exists(TitleScreen.WORLD_SCENE), "the title screen's world scene exists")


func test_credits_text() -> void:
	var credits := Credits.credits_bbcode()
	check(credits.contains("Map data © OpenStreetMap contributors") and credits.contains("Open Database License (ODbL)"), "the credits carry the OpenStreetMap credit the ODbL requires")
	check(credits.contains("USGS 3D Elevation Program"), "the credits name the elevation data")
	check(credits.contains("Noto Sans") and credits.contains("SIL Open Font License"), "the credits name the font and its license")
	check(credits.contains("Godot Engine"), "the credits name the engine")
	var licenses := Credits.licenses_bbcode()
	check(licenses.contains("Permission is hereby granted"), "the Licenses page has Godot's license text")
	check(licenses.contains("Noto Project Authors") and licenses.contains("SIL OPEN FONT LICENSE Version 1.1"), "the Licenses page has the font's full license")
	check(licenses.contains("FreeType"), "the Licenses page lists the libraries built into Godot")
	check(FileAccess.file_exists(Credits.FONT_LICENSE), "the font's license file is in the project")


func _open_title() -> TitleScreen:
	var title: TitleScreen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	return title


func test_without_save() -> void:
	var title := await _open_title()
	check(TitleScreen.Option.CONTINUE not in title.options(), "with no save there is no Continue")
	check(title.cursor_option() == TitleScreen.Option.NEW_GAME, "and the cursor starts on New Game")
	check(Sound.ambience() == "title", "the title screen plays its ambience")
	_press("move_up")
	check(title.cursor_option() == TitleScreen.Option.QUIT, "Up from the top wraps round to Quit")
	_press("move_down")
	_press("move_down")
	_press("interact")
	check(title._pause.is_open() and title._pause.page() == PauseMenu.Page.SETTINGS, "Settings opens the Settings page on its own")
	check(not title._menu.visible, "and the title menu hides under it")
	_press("move_right")
	check(Settings.text_speed == Settings.TextSpeed.FAST, "the Settings page works from the title screen")
	for i in PauseMenu.Setting.BACK:
		_press("move_down")
	_press("interact")
	check(not title._pause.is_open() and title._menu.visible, "Back on Settings returns to the title menu")
	_press("interact")
	_press("ui_cancel")
	check(not title._pause.is_open(), "and so does Esc")
	_press("move_down")
	_press("interact")
	check(title._credits.is_open() and title._credits.page() == Credits.Page.CREDITS, "Credits opens the credits")
	_press("move_right")
	check(title._credits.page() == Credits.Page.LICENSES, "Right turns to the Licenses page")
	_press("move_left")
	check(title._credits.page() == Credits.Page.CREDITS, "Left turns back")
	_press("ui_cancel")
	check(not title._credits.is_open() and title._menu.visible, "Esc closes the credits")
	title.queue_free()
	await get_tree().process_frame


func test_with_save() -> void:
	FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_string("{}")
	var title := await _open_title()
	check(title.options()[0] == TitleScreen.Option.CONTINUE, "with a save, Continue comes first")
	check(title.cursor_option() == TitleScreen.Option.CONTINUE, "and the cursor starts on it")
	_press("move_down")
	_press("interact")
	check(title._confirm_new and not title._starting, "New Game asks before starting over")
	check(not SaveManager._fresh, "and nothing changes yet")
	_press("ui_cancel")
	check(not title._confirm_new, "Esc takes the question back")
	title.queue_free()
	await get_tree().process_frame


func test_fresh_start() -> void:
	FileAccess.open(SAVE_PATH, FileAccess.WRITE).store_string(JSON.stringify({"nodes": {"World": {"region": "wawona"}}}))
	check(SaveManager.peek_node("World").get("region") == "wawona", "a save is there to start with")
	SaveManager.start_fresh()
	check(SaveManager.peek_node("World").is_empty() and not SaveManager.load_game(), "after New Game the old save isn't loaded")
	check(SaveManager.has_save(), "but it stays on disk until the first sleep")
	var world: Node = load(TitleScreen.WORLD_SCENE).instantiate()
	add_child(world)
	await get_tree().process_frame
	check(world.region.region_id == Park.HOME_REGION, "the new game starts at home (%s)" % world.region.region_id)
	SaveManager.save_game()
	check(not SaveManager._fresh and SaveManager.load_game(), "the first save is the new game's, and loads again")
	world.queue_free()
	await get_tree().process_frame


## The opening: the logo and menu come in, any key finishes that at once, and
## the sky has its clouds and, now and then, ravens.
func test_intro() -> void:
	var title := await _open_title()
	check(title.intro_playing() and title._logo.modulate.a < 0.5 and title._menu.modulate.a < 0.5, "the logo and menu come in when the title opens")
	var sky: TitleSky = title.find_children("*", "TitleSky", true, false)[0]
	check(sky != null and not sky.ravens_flying(), "the sky starts with no ravens")
	_press("move_down")
	check(not title.intro_playing() and title._logo.modulate.a == 1.0 and title._menu.modulate.a == 1.0 and title._fade.color.a == 0.0, "a key finishes the opening at once")
	check(title.cursor_option() != title.options()[0], "and still moves the cursor")
	sky._process(TitleSky.FIRST_RAVENS + 0.1)
	check(sky.ravens_flying(), "ravens cross the sky soon after")
	sky._process((TitleSky.SCREEN.x + 100.0) / TitleSky.RAVEN_SPEED)
	check(not sky.ravens_flying(), "and are gone once across")
	check(TitleSky._cloud_shape(30, 1).size() > 4, "the clouds have a shape")
	title.queue_free()
	await get_tree().process_frame


## The roll at the end of the story: what it says, that it holds the game, and
## that Esc ends it and gives the game back.
func test_end_credits() -> void:
	var text := "\n".join(EndCredits.lines().map(func(l: Array) -> String: return l[1]))
	check(text.contains("Map data © OpenStreetMap contributors") and text.contains("Open Database License (ODbL)"), "the end credits carry the OpenStreetMap credit too")
	check(text.contains("Cory Goehring") and text.contains("Godot Engine") and text.ends_with(EndCredits.LAST_LINE), "and who made it, the engine, and a thank-you last")
	var named := 0
	for character: CharacterData in QuestLog.CHARACTERS:
		if character.needs_tribal_review:
			check(not EndCredits.register_names().has(character.display_name), "%s waits on tribal review and isn't listed" % character.display_name)
		else:
			named += 1
	check(named > 0 and EndCredits.register_names().size() == named, "everyone else in the Register is named (%d)" % named)
	check(EndCredits.staff_names().size() == QuestLog.STAFF.size(), "and the valley's people today")
	GameClock.paused = false
	Sound.set_ambience("world")
	var roll := EndCredits.roll(get_tree())
	var ended := [false]
	roll.finished.connect(func() -> void: ended[0] = true)
	for i in 10:
		await get_tree().process_frame
	check(roll.is_rolling() and GameClock.paused and Sound.ambience() == "title", "the roll holds the clock and plays the title music")
	check(roll.scrolled() > 0.0, "and climbs")
	check(roll._end < INF and roll._end > EndCredits.SCREEN.y, "and knows where it ends")
	_press("ui_cancel")
	check(not roll.is_rolling(), "Esc skips it")
	await get_tree().create_timer(EndCredits.FADE_OUT + 0.3).timeout
	check(ended[0] and not GameClock.paused and Sound.ambience() == "world", "and the game comes back as it was")
	check(get_tree().get_nodes_in_group("end_credits").is_empty(), "and the roll is gone")


## Quit to title puts everything back to a new game's start.
func test_reset_all() -> void:
	GameClock.day = 9
	GameClock.minutes = 15 * 60
	GameClock.paused = true
	Inventory.items["granola_bar"] = 3
	QuestLog.completed.append("some_quest")
	NewGame.reset_all()
	check(GameClock.day == 1 and GameClock.minutes == GameClock.DAY_START_HOUR * 60 and not GameClock.paused, "the clock goes back to the first morning")
	check(Inventory.items.is_empty() and QuestLog.completed.is_empty(), "and the backpack and quests are empty")
	check(ResourceLoader.exists(TitleScreen.SCENE), "the title screen to go back to exists")


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
