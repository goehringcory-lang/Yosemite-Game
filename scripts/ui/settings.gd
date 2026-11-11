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
enum Graphics { HIGH, LOW, AUTO }
## How much room the timed activities give you (see [method pace] and
## [method room]).
enum Timing { STANDARD, RELAXED, GENTLE }

const DEFAULT_PATH := "user://settings.cfg"
const TEXT_SPEED_NAMES := ["Slow", "Normal", "Fast", "Instant"]
## Letters a second the dialogue box reveals at each speed (0: all at once).
const TEXT_SPEED_CPS := [30.0, 60.0, 120.0, 0.0]
const PROMPT_NAMES := ["Auto", "Keyboard", "Gamepad"]
const TIMING_NAMES := ["Standard", "Relaxed", "Gentle"]
## At each Timing: how fast the meters' markers, the fish and the slackline
## move (1 is as designed), and how much wider the greens and longer the
## time limits are.
const TIMING_PACE := [1.0, 0.75, 0.55]
const TIMING_ROOM := [1.0, 1.3, 1.6]
## Taps a second a held key counts for when [member hold_taps] is on.
const HOLD_TAPS_PER_SECOND := 4.0
const GRAPHICS_NAMES := ["High", "Low", "Auto"]
## The Full screen row's choices: a window, full screen filled, or full
## screen in whole-pixel steps (see [member pixel_perfect]).
const FULLSCREEN_NAMES := ["Off", "Fill", "Pixel perfect"]
## The order the pause menu steps through the graphics levels.
const GRAPHICS_ORDER := [Graphics.AUTO, Graphics.HIGH, Graphics.LOW]
## The renderer for High and for Low. Low is the simpler Compatibility
## renderer (OpenGL), for older computers; it also draws the picture at
## 960x540 and scales it up (see apply_graphics), which takes a third of the
## work at 1920x1080.
const GRAPHICS_RENDERERS := ["forward_plus", "gl_compatibility"]
## The file project.godot reads over its own settings at start-up
## (application/config/project_settings_override), so Low can pick the
## renderer before the window opens.
const GRAPHICS_OVERRIDE := "user://graphics.cfg"
const MIN_SCALE := 1
const MAX_SCALE := 3
const BASE_SIZE := Vector2i(960, 540)
## Volumes run from 0 (off) to MAX_VOLUME in whole steps.
const MAX_VOLUME := 10

## Where the settings are kept. Tests point this at their own file.
static var path := DEFAULT_PATH
static var text_speed := TextSpeed.NORMAL
static var fullscreen := false
## Full screen in whole-pixel steps (2x, 3x...), leaving a border where the
## screen isn't a whole multiple of 960x540, instead of filling the screen.
## Only full screen looks at it: a window is always filled.
static var pixel_perfect := false
## Window size in whole steps of 960x540 (2 = 1920x1080, the default window).
static var window_scale := 2
## Which buttons the on-screen hints name: follow the last device used, or
## always the keyboard's or the gamepad's.
static var prompts := Prompts.AUTO
## The first day's tips (FirstDay): the card naming the next thing to try.
static var tips := true
## Assist: how forgiving the timed activities are. It slows the markers on
## the climbing, casting, cables and trail-work meters, the fish on the line
## and the slackline, and widens their greens and time limits.
static var timing := Timing.STANDARD
## Assist: on a crux that wants quick taps (and the left-right ones), holding
## the key counts as tapping it.
static var hold_taps := false
## Controller rumble (see Rumble).
static var vibration := true
## Pause the game when its window isn't the one in front (see LookAway).
static var pause_away := true
## Trees and plants sway and gusts cross the grass (see Wind). Off stills
## them, for anyone the movement bothers.
static var wind := true
## Volume of everything, of one-shot sounds (steps, climbing, menus), and of
## the ambience (birds, wind, rain, campfires, waterfalls); 0 to MAX_VOLUME.
static var master_volume := 8
static var effects_volume := MAX_VOLUME
## Volume of the music, 0 to MAX_VOLUME.
static var music_volume := 8
static var ambience_volume := MAX_VOLUME
## The UI's letters: a pixel font (DotGothic16, the default) that matches the
## pixel art as in Stardew Valley and keeps every letter distinct, or smooth
## Noto Sans.
static var pixel_font := true
## High (Forward+, drawn at the window's size), Low (Compatibility, drawn at
## 960x540 and scaled up), or Auto: High until the game finds it runs slowly
## on this computer (see GraphicsWatch), then Low. The drawing size changes at
## once; the renderer the next time the game starts.
static var graphics := Graphics.AUTO
## Auto found this computer too slow for High, so Auto means Low here.
static var auto_low := false
## The renderer the game started with ("" until settings first load).
static var _started_renderer := ""
const SMOOTH_FONT := "res://assets/fonts/NotoSans-Regular.ttf"
const PIXEL_FONT := "res://assets/fonts/DotGothic16Prop-Regular.ttf"
static var _fonts: Dictionary = {}

## The keys the player can change on the Controls page: a name, the actions
## the key does, the key it starts as (a physical key, as on a US keyboard),
## and the gamepad button for it (gamepad buttons stay as they are). Each
## action's other keys (the arrows, C, X) stay too, so the menus always work.
const BINDINGS := [
	{"id": "up", "name": "Walk up", "actions": ["move_up"], "key": KEY_W, "pad": "Stick up"},
	{"id": "down", "name": "Walk down", "actions": ["move_down"], "key": KEY_S, "pad": "Stick down"},
	{"id": "left", "name": "Walk left", "actions": ["move_left"], "key": KEY_A, "pad": "Stick left"},
	{"id": "right", "name": "Walk right", "actions": ["move_right"], "key": KEY_D, "pad": "Stick right"},
	{"id": "run", "name": "Run, climb aid", "actions": ["run", "assist"], "key": KEY_SHIFT, "pad": "B or RT, Y"},
	{"id": "interact", "name": "Talk, read, eat", "actions": ["interact"], "key": KEY_E, "pad": "A"},
	{"id": "use", "name": "Use, place a cam", "actions": ["use_tool"], "key": KEY_SPACE, "pad": "X"},
	{"id": "gift", "name": "Give a gift", "actions": ["gift"], "key": KEY_G, "pad": "LB"},
	{"id": "map", "name": "Map", "actions": ["map"], "key": KEY_M, "pad": "Back"},
	{"id": "journal", "name": "Journal", "actions": ["journal"], "key": KEY_J, "pad": "Y"},
	{"id": "quests", "name": "Quests", "actions": ["quests"], "key": KEY_Q, "pad": "Y, then RB"},
	{"id": "backpack", "name": "Backpack", "actions": ["backpack"], "key": KEY_B, "pad": "Y, then RB"},
	{"id": "press", "name": "Press book", "actions": ["press_book"], "key": KEY_P, "pad": "Y, then RB"},
	{"id": "camera", "name": "Camera", "actions": ["camera"], "key": KEY_F, "pad": "RB"},
]
## Keys the menus need, so they can't be given to anything else.
const RESERVED_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
## The player's changed keys: binding id -> physical keycode. Keys left out
## are as in BINDINGS.
static var keys: Dictionary = {}
## Each action's events as the project set them up, before any key changed.
static var _original_events: Dictionary = {}
static var _key_pattern: RegEx

static var _loaded := false
## True once settings came from a file or the player changed one, so the
## window is only resized when they asked for it.
static var _customized := false


static func ensure_loaded() -> void:
	OldUserDir.migrate()
	if not _loaded:
		load_settings()
		apply_font()
		if _started_renderer == "":
			_started_renderer = renderer()


## The font for the UI, as chosen: DotGothic16 or Noto Sans.
static func ui_font() -> Font:
	ensure_loaded()
	var path := PIXEL_FONT if pixel_font else SMOOTH_FONT
	if not _fonts.has(path):
		var font := load(path) as FontFile
		if font == null:
			return ThemeDB.fallback_font
		if path == PIXEL_FONT:
			font = font.duplicate() as FontFile
			# a touch of smoothing keeps the strokes even at the small sizes
			font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
			# no ligatures: every letter stays its own
			var ts := TextServerManager.get_primary_interface()
			font.opentype_feature_overrides = {
				ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0,
				ts.name_to_tag("dlig"): 0, ts.name_to_tag("calt"): 0,
			}
			# its lines run a pixel taller than Noto's; trim that so every
			# screen keeps the layout it was made for
			var trimmed := FontVariation.new()
			trimmed.base_font = font
			trimmed.spacing_top = -1
			_fonts[path] = trimmed
			return trimmed

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
	pixel_perfect = bool(config.get_value("display", "pixel_perfect", pixel_perfect))
	window_scale = clampi(int(config.get_value("display", "window_scale", window_scale)), MIN_SCALE, MAX_SCALE)
	prompts = clampi(int(config.get_value("input", "prompts", prompts)), 0, Prompts.size() - 1) as Prompts
	tips = bool(config.get_value("input", "tips", tips))
	timing = clampi(int(config.get_value("assist", "timing", timing)), 0, Timing.size() - 1) as Timing
	hold_taps = bool(config.get_value("assist", "hold_taps", hold_taps))
	vibration = bool(config.get_value("input", "vibration", vibration))
	pause_away = bool(config.get_value("input", "pause_away", pause_away))
	wind = bool(config.get_value("display", "wind", wind))
	master_volume = clampi(int(config.get_value("audio", "master", master_volume)), 0, MAX_VOLUME)
	effects_volume = clampi(int(config.get_value("audio", "effects", effects_volume)), 0, MAX_VOLUME)
	music_volume = clampi(int(config.get_value("audio", "music", music_volume)), 0, MAX_VOLUME)
	ambience_volume = clampi(int(config.get_value("audio", "ambience", ambience_volume)), 0, MAX_VOLUME)
	pixel_font = bool(config.get_value("display", "pixel_font", pixel_font))
	if config.has_section_key("display", "graphics_level"):
		graphics = clampi(int(config.get_value("display", "graphics_level", graphics)), 0, Graphics.size() - 1) as Graphics
	elif int(config.get_value("display", "graphics", Graphics.HIGH)) == Graphics.LOW:
		# from before Auto: Low stays Low, High (the old default) becomes Auto
		graphics = Graphics.LOW
	auto_low = bool(config.get_value("display", "auto_low", auto_low))
	for binding: Dictionary in BINDINGS:
		var key := int(config.get_value("keys", binding.id, 0))
		if key > 0 and key != binding.key and not key in RESERVED_KEYS:
			keys[binding.id] = key
	_drop_clashes()
	apply_keys()


static func save() -> Error:
	_loaded = true
	_customized = true
	var config := ConfigFile.new()
	config.set_value("text", "speed", int(text_speed))
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "pixel_perfect", pixel_perfect)
	config.set_value("display", "window_scale", window_scale)
	config.set_value("input", "prompts", int(prompts))
	config.set_value("input", "tips", tips)
	config.set_value("assist", "timing", int(timing))
	config.set_value("assist", "hold_taps", hold_taps)
	config.set_value("input", "vibration", vibration)
	config.set_value("input", "pause_away", pause_away)
	config.set_value("display", "wind", wind)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "ambience", ambience_volume)
	config.set_value("display", "pixel_font", pixel_font)
	config.set_value("display", "graphics_level", int(graphics))
	config.set_value("display", "auto_low", auto_low)
	for id: String in keys:
		config.set_value("keys", id, int(keys[id]))
	_save_graphics_override()
	return config.save(path)


## The override file beside the settings: the game's own, or a test's.
static func graphics_override_path() -> String:
	return GRAPHICS_OVERRIDE if path == DEFAULT_PATH else path.get_basename() + "_graphics.cfg"


## Writes the renderer for Low into the override file, or removes the file for
## High so the project's own renderer (Forward+) stands.
static func _save_graphics_override() -> void:
	var file := graphics_override_path()
	if not low():
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
		return
	var config := ConfigFile.new()
	config.set_value("rendering", "renderer/rendering_method", renderer())
	config.save(file)


## True when the game should look after slower computers: Low, or Auto on a
## computer found to be slow.
static func low() -> bool:
	ensure_loaded()
	return graphics == Graphics.LOW or (graphics == Graphics.AUTO and auto_low)


## The renderer the graphics level asks for.
static func renderer() -> String:
	return GRAPHICS_RENDERERS[1 if low() else 0]


## "High", "Low", or "Auto (High)" / "Auto (Low)" for what Auto chose.
static func graphics_name() -> String:
	ensure_loaded()
	if graphics == Graphics.AUTO:
		return "Auto (%s)" % GRAPHICS_NAMES[Graphics.LOW if auto_low else Graphics.HIGH]
	return GRAPHICS_NAMES[graphics]


## True when the renderer the graphics level asks for isn't the one the game
## started with, so that part waits for a restart.
static func graphics_pending() -> bool:
	ensure_loaded()
	return _started_renderer != "" and renderer() != _started_renderer


## Draws the picture at the window's size (High), or at 960x540 scaled up
## (Low): the pixel art looks the same, but there are a quarter as many pixels
## to fill at 1920x1080, and every full-screen effect costs a quarter as much.
static func apply_graphics(window: Window) -> void:
	if window == null or DisplayServer.get_name() == "headless":
		return
	var mode := Window.CONTENT_SCALE_MODE_VIEWPORT if low() else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if window.content_scale_mode != mode:
		window.content_scale_mode = mode


static func reset_defaults() -> void:
	text_speed = TextSpeed.NORMAL
	fullscreen = false
	pixel_perfect = false
	window_scale = 2
	prompts = Prompts.AUTO
	tips = true
	timing = Timing.STANDARD
	hold_taps = false
	vibration = true
	pause_away = true
	wind = true
	master_volume = 8
	effects_volume = MAX_VOLUME
	music_volume = 8
	ambience_volume = MAX_VOLUME
	pixel_font = true
	graphics = Graphics.AUTO
	auto_low = false
	keys.clear()
	apply_keys()
	_customized = false


## How fast the timed activities run under the Timing assist: 1 as designed,
## less when it's relaxed. Meters multiply their marker's speed by it.
static func pace() -> float:
	ensure_loaded()
	return TIMING_PACE[timing]


## How much wider the greens and longer the time limits are under the Timing
## assist: 1 as designed, more when it's relaxed.
static func room() -> float:
	ensure_loaded()
	return TIMING_ROOM[timing]


## Letters a second for the dialogue reveal, or 0 to show a page at once.
static func chars_per_second() -> float:
	ensure_loaded()
	return TEXT_SPEED_CPS[text_speed]


## Which Full screen choice is on: 0 a window, 1 Fill, 2 Pixel perfect
## (an index into [constant FULLSCREEN_NAMES]).
static func fullscreen_choice() -> int:
	if not fullscreen:
		return 0
	return 2 if pixel_perfect else 1


## Turns on Full screen choice [param choice] (see [method fullscreen_choice]).
static func set_fullscreen_choice(choice: int) -> void:
	choice = clampi(choice, 0, FULLSCREEN_NAMES.size() - 1)
	fullscreen = choice > 0
	pixel_perfect = choice == 2


## How the picture grows to the window: in any step that fills it (the
## default, so a 2560x1440 screen or a Steam Deck is covered edge to edge), or
## in whole steps only, for Pixel perfect full screen. The project starts
## with the first (Godot's default display/window/stretch/scale_mode).
static func stretch() -> Window.ContentScaleStretch:
	ensure_loaded()
	if fullscreen and pixel_perfect:
		return Window.CONTENT_SCALE_STRETCH_INTEGER
	return Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## Puts [method stretch] into effect on [param window], at once.
static func apply_stretch(window: Window) -> void:
	if window == null or DisplayServer.get_name() == "headless":
		return
	var mode := stretch()
	if window.content_scale_stretch != mode:
		window.content_scale_stretch = mode


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
	apply_graphics(window)
	apply_stretch(window)
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


# ---------------------------------------------------------------- keys


## The binding (from BINDINGS) with id [param id], or {}.
static func binding(id: String) -> Dictionary:
	for b: Dictionary in BINDINGS:
		if b.id == id:
			return b
	return {}


## The physical key binding [param id] is on now.
static func key_for(id: String) -> int:
	return int(keys.get(id, binding(id).get("key", 0)))


## The name of a physical key as the keyboard in use labels it ("E", "Space").
static func key_label(physical: int) -> String:
	var shown := physical
	if DisplayServer.get_name() != "headless":
		var mapped := DisplayServer.keyboard_get_keycode_from_physical(physical)
		if mapped != KEY_NONE:
			shown = mapped
	var name := OS.get_keycode_string(shown)
	return name if name != "" else "?"


## Puts binding [param id] on [param physical]. A key another binding had
## swaps over to it, so no key does two things. Returns false for a key the
## menus keep (Esc, Enter, Tab, the arrows).
static func set_key(id: String, physical: int) -> bool:
	if physical in RESERVED_KEYS or binding(id).is_empty():
		return false
	var old := key_for(id)
	for b: Dictionary in BINDINGS:
		if b.id != id and key_for(b.id) == physical:
			_store_key(b.id, old)
	_store_key(id, physical)
	apply_keys()
	return true


static func _store_key(id: String, physical: int) -> void:
	if physical == int(binding(id).key):
		keys.erase(id)
	else:
		keys[id] = physical


## Every key back as it started.
static func reset_keys() -> void:
	keys.clear()
	apply_keys()


## A hand-edited settings file could put two bindings on one key; the later
## one goes back to its own key.
static func _drop_clashes() -> void:
	var used := {}
	for b: Dictionary in BINDINGS:
		var key := key_for(b.id)
		if used.has(key):
			keys.erase(b.id)
		used[key_for(b.id)] = true


## Puts the chosen keys into the InputMap: each action's first key becomes
## its binding's key, and its other keys and buttons stay.
static func apply_keys() -> void:
	for b: Dictionary in BINDINGS:
		for action: String in b.actions:
			if not InputMap.has_action(action):
				continue
			if not _original_events.has(action):
				_original_events[action] = InputMap.action_get_events(action)
			var physical := key_for(b.id)
			InputMap.action_erase_events(action)
			var replaced := false
			for event: InputEvent in _original_events[action]:
				if event is InputEventKey and not replaced:
					replaced = true
					var key := event.duplicate() as InputEventKey
					key.keycode = KEY_NONE
					key.physical_keycode = physical as Key
					InputMap.action_add_event(action, key)
				else:
					InputMap.action_add_event(action, event)


## [param keyboard] (a hint's key names: "E", "WASD", "J/Esc") with the
## player's changed keys put in, so every hint names the key that works.
static func key_text(keyboard: String) -> String:
	if keys.is_empty():
		return keyboard
	if _key_pattern == null:
		_key_pattern = RegEx.create_from_string("(?<![A-Za-z])(WASD|Space|Shift|[EGMJQBPF])(?![A-Za-z])")
	var out := ""
	var at := 0
	for found in _key_pattern.search_all(keyboard):
		out += keyboard.substr(at, found.get_start() - at)
		out += _hint_name(found.get_string(1))
		at = found.get_end()
	return out + keyboard.substr(at)


const _HINT_IDS := {"Space": "use", "Shift": "run", "E": "interact", "G": "gift", "M": "map", "J": "journal", "Q": "quests", "B": "backpack", "P": "press", "F": "camera"}


static func _hint_name(token: String) -> String:
	if token == "WASD":
		var names := ""
		for id in ["up", "left", "down", "right"]:
			names += key_label(key_for(id))
		return names if names.length() == 4 else "%s/%s/%s/%s" % [key_label(key_for("up")), key_label(key_for("left")), key_label(key_for("down")), key_label(key_for("right"))]
	return key_label(key_for(_HINT_IDS[token]))
