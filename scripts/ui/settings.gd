class_name Settings
extends RefCounted
## Player settings, kept in user://settings.cfg (apart from the save game, so
## they hold across new games). Changed from the pause menu's Settings page.
##
##   Settings.ensure_loaded()
##   Settings.text_speed = Settings.TextSpeed.FAST
##   Settings.save()
##   Settings.apply(get_window())
##   Sound.apply_volumes()

enum TextSpeed { SLOW, NORMAL, FAST, INSTANT }
enum Prompts { AUTO, KEYBOARD, GAMEPAD }

const DEFAULT_PATH := "user://settings.cfg"
const TEXT_SPEED_NAMES := ["Slow", "Normal", "Fast", "Instant"]
## Letters a second the dialogue box reveals at each speed (0: all at once).
const TEXT_SPEED_CPS := [30.0, 60.0, 120.0, 0.0]
const PROMPT_NAMES := ["Auto", "Keyboard", "Gamepad"]
const MIN_SCALE := 1
const MAX_SCALE := 6
const BASE_SIZE := Vector2i(480, 270)
## Volumes run from 0 (off) to MAX_VOLUME in whole steps.
const MAX_VOLUME := 10

## Where the settings are kept. Tests point this at their own file.
static var path := DEFAULT_PATH
static var text_speed := TextSpeed.NORMAL
static var fullscreen := false
## Window size in whole steps of 480x270 (3 = 1440x810, the default window).
static var window_scale := 3
## Which buttons the on-screen hints name: follow the last device used, or
## always the keyboard's or the gamepad's.
static var prompts := Prompts.AUTO
## Volume of everything, of one-shot sounds (steps, climbing, menus), and of
## the ambience (birds, wind, rain, campfires, waterfalls); 0 to MAX_VOLUME.
static var master_volume := 8
static var effects_volume := MAX_VOLUME
## Volume of the music, 0 to MAX_VOLUME.
static var music_volume := 8
static var ambience_volume := MAX_VOLUME
## The UI's letters: smooth (Noto Sans, the default, easiest to read) or a
## pixel font (Pixelify Sans) that matches the pixel art, as in Stardew Valley.
static var pixel_font := false
const SMOOTH_FONT := "res://assets/fonts/NotoSans-Regular.ttf"
const PIXEL_FONT := "res://assets/fonts/PixelifySans.ttf"
static var _fonts: Dictionary = {}

static var _loaded := false
## True once settings came from a file or the player changed one, so the
## window is only resized when they asked for it.
static var _customized := false


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()
		apply_font()


## The font for the UI, as chosen: Noto Sans, or crisp Pixelify Sans.
static func ui_font() -> Font:
	ensure_loaded()
	var path := PIXEL_FONT if pixel_font else SMOOTH_FONT
	if not _fonts.has(path):
		var font := load(path) as FontFile
		if font == null:
			return ThemeDB.fallback_font
		if path == PIXEL_FONT:
			font = font.duplicate() as FontFile
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts[path] = font
	return _fonts[path]


## Puts the chosen font on every screen that uses the project's theme.
static func apply_font() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var font := ui_font()
	if theme.default_font != font:
		theme.default_font = font


## Reads [member path]; missing keys keep their defaults.
static func load_settings() -> void:
	reset_defaults()
	_loaded = true
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	_customized = true
	text_speed = clampi(int(config.get_value("text", "speed", text_speed)), 0, TextSpeed.size() - 1) as TextSpeed
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	window_scale = clampi(int(config.get_value("display", "window_scale", window_scale)), MIN_SCALE, MAX_SCALE)
	prompts = clampi(int(config.get_value("input", "prompts", prompts)), 0, Prompts.size() - 1) as Prompts
	master_volume = clampi(int(config.get_value("audio", "master", master_volume)), 0, MAX_VOLUME)
	effects_volume = clampi(int(config.get_value("audio", "effects", effects_volume)), 0, MAX_VOLUME)
	music_volume = clampi(int(config.get_value("audio", "music", music_volume)), 0, MAX_VOLUME)
	ambience_volume = clampi(int(config.get_value("audio", "ambience", ambience_volume)), 0, MAX_VOLUME)
	pixel_font = bool(config.get_value("display", "pixel_font", pixel_font))


static func save() -> Error:
	_loaded = true
	_customized = true
	var config := ConfigFile.new()
	config.set_value("text", "speed", int(text_speed))
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "window_scale", window_scale)
	config.set_value("input", "prompts", int(prompts))
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "ambience", ambience_volume)
	config.set_value("display", "pixel_font", pixel_font)
	return config.save(path)


static func reset_defaults() -> void:
	text_speed = TextSpeed.NORMAL
	fullscreen = false
	window_scale = 3
	prompts = Prompts.AUTO
	master_volume = 8
	effects_volume = MAX_VOLUME
	music_volume = 8
	ambience_volume = MAX_VOLUME
	pixel_font = false
	_customized = false


## Letters a second for the dialogue reveal, or 0 to show a page at once.
static func chars_per_second() -> float:
	ensure_loaded()
	return TEXT_SPEED_CPS[text_speed]


## The largest window scale that fits the screen the window is on.
static func max_window_scale() -> int:
	if DisplayServer.get_name() == "headless":
		return MAX_SCALE
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	return clampi(mini(usable.x / BASE_SIZE.x, usable.y / BASE_SIZE.y), MIN_SCALE, MAX_SCALE)


## Puts the display settings into effect. Does nothing headless, or before
## the player has changed anything (the project's window size stands).
static func apply(window: Window) -> void:
	ensure_loaded()
	if window == null or DisplayServer.get_name() == "headless" or not _customized:
		return
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	var size := BASE_SIZE * clampi(window_scale, MIN_SCALE, max_window_scale())
	if window.size != size:
		window.size = size
		window.move_to_center()
