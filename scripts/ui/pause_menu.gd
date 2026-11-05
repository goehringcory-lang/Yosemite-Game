class_name PauseMenu
extends CanvasLayer
## Esc (gamepad Start) pauses the game. World adds one. Four pages:
##   Main: Resume, Save game, Settings, Controls, Quit to title, Quit to
##     desktop, and your current goal
##   Settings: text speed, full screen, window size, button prompts, font,
##     graphics, the volumes, and the way to Controls
##   Controls: each control's key, which you can change, and its gamepad button
##   Saves: the save slots, to save into (or, from the title screen, to load
##     or to start a new game in)
## Up/Down choose, E (A) selects, Left/Right change a setting, Esc (B) goes back.
## The title screen opens the Settings page on its own with open_settings(),
## and the Saves page with open_slots().

signal closed
## The title screen's Load game or New Game picked slot [param slot]: the
## slot is set on SaveManager (and New Game has called start_fresh()), so the
## World can start.
signal slot_chosen(slot: int)

enum Page { MAIN, SETTINGS, CONTROLS, SLOTS }
## What the Saves page is for.
enum SlotMode { SAVE, LOAD, NEW }

const CONTROLS := [
	["Walk (hold to run)", "WASD or arrows (Shift)", "Stick or D-pad (B or RT)"],
	["Talk, read, use", "E, Space, X, C, or click", "A or X"],
	["Give a gift", "G", "LB"],
	["Park and area map", "M (Tab: tabs)", "Back (LB/RB: tabs)"],
	["Journal, quests, backpack", "J, Q, B (Tab: tabs)", "Y (LB/RB: tabs)"],
	["Pause, or go back", "Esc", "Start, or B"],
	["Menus: choose, confirm", "Up/Down, E or Enter", "Stick or D-pad, A"],
	["Dialogue: show all, next", "E (twice)", "A (twice)"],
	["Climb: move up", "W / Up (A, D: diagonal)", "Stick up / left / right"],
	["Climb: place a cam, clip a bolt", "Space or C", "X"],
	["Climb: eat, chalk up, retreat", "E / Esc", "A / B"],
	["Climb: aid or jug", "Shift + arrow", "Y + stick"],
]
enum Option { RESUME, SAVE, SETTINGS, CONTROLS, QUIT_TITLE, QUIT }
const OPTIONS := ["Resume", "Save game", "Settings", "Controls", "Quit to title", "Quit to desktop"]
const QUIT_CONFIRM := "Quit? Progress since your last save is lost. Press again to quit."
const QUIT_SAVED := "Quit? Your game is saved. Press again to quit."
const TITLE_CONFIRM := "To the title? Progress since your last save is lost. Press again."
const TITLE_SAVED := "To the title? Your game is saved. Press again."
enum Setting { TEXT_SPEED, FULLSCREEN, WINDOW_SIZE, PROMPTS, TIPS, FONT, GRAPHICS, MASTER_VOLUME, MUSIC_VOLUME, EFFECTS_VOLUME, AMBIENCE_VOLUME, CONTROLS, BACK }
const SETTING_NAMES := ["Text speed", "Full screen", "Window size", "Button prompts", "Tips", "Font", "Graphics", "Volume", "Music", "Sound effects", "Ambience", "Controls", "Back"]
const SETTING_HELP := [
	"How fast conversations appear. Press E (A) to show a page at once.",
	"Fill the screen. The picture stays sharp in whole-pixel steps.",
	"The window's size, in whole steps of 960 x 540.",
	"Which buttons hints name. Auto follows the last device you used.",
	"The first day's card under the clock, naming the next thing to try.",
	"Smooth letters are easiest to read; pixel letters match the art.",
	"Low uses a simpler renderer for older computers. A change takes effect when you next start the game.",
	"How loud the whole game is.",
	"The songs for each season, the night, and the title screen.",
	"Footsteps, climbing, and menus.",
	"Birds, crickets, wind, rain, campfires, and waterfalls.",
	"See every control, and change which key does what.",
	"Back to the pause menu.",
]
## The Controls page's rows after the keys.
## How many keys the Controls page lists in its left column.
const CONTROLS_PER_COLUMN := 7
const CONTROLS_RESET := "Reset keys"
const CONTROLS_BACK := "Back"
const CONTROLS_NOTE := "Menus also take the arrows, Enter, and Esc. Climbing: E eats or chalks up, Esc retreats."
const LISTEN_TEXT := "Press a key for %s.  Esc keeps the old one."
const RESERVED_TEXT := "Esc, Enter, Tab, and the arrows stay with the menus."
## A line that plays at the chosen text speed while Text speed is selected.
const SPEED_SAMPLE := "Sample: The granite glows gold at dusk."
const HEADING := Color(1, 0.831, 0.541)
const DIM := Color(0.961, 0.933, 0.878, 0.6)
const PANEL_POS := Vector2(30, 16)
const PANEL_SIZE := Vector2(420, 238)
## The shortest the panel gets when it fits a short page.
const PANEL_MIN_HEIGHT := 150.0
## The width of the card beside the pause menu's choices.
const CARD_WIDTH := 132.0
const NAME_WIDTH := 96
const VOLUME_SETTINGS := [Setting.MASTER_VOLUME, Setting.MUSIC_VOLUME, Setting.EFFECTS_VOLUME, Setting.AMBIENCE_VOLUME]

var _panel: PanelContainer
var _title: Label
var _footer: Label
## True from open() to close(); the panel stays up a moment longer as it fades out.
var _open := false
var _pages: Array[Control] = []
var _page := Page.MAIN
var _option_labels: Array[Label] = []
var _goal_label: Label
var _card_date: Label
var _help_title: Label
var _card_stats: Label
var _setting_names: Array[Label] = []
## Volume setting -> its slider bar.
var _sliders: Dictionary = {}
var _setting_values: Array[Label] = []
var _help_label: Label
var _sample_label: Label
var _sample_shown := 0.0
var _device_headers: Array[Label] = []
## Controls page: a name, key and pad label per binding, then Reset and Back.
var _control_names: Array[Label] = []
var _control_keys: Array[Label] = []
var _control_note: Label
var _controls_cursor := 0
## The binding (an index into Settings.BINDINGS) waiting for a key, or -1.
var _listening := -1
var _controls_message := ""
## Controls was opened from the Settings page, so Back goes there.
var _controls_from_settings := false
## Saves page: two lines per slot, then Back.
var _slot_labels: Array[Label] = []
var _slot_details: Array[Label] = []
var _slot_back: Label
var _slot_note: Label
var _slot_mode := SlotMode.SAVE
var _slot_cursor := 0
## The slot waiting for a second press before it's written over (0: none).
var _slot_confirm := 0
## Opened by open_slots(): backing out of Saves closes the menu.
var _slots_only := false
var _cursor := 0
var _settings_cursor := 0
var _confirm_quit := false
## "Saved at 2:15 PM." after Save game, until the menu closes.
var _save_note := ""
## Nothing has happened since the last save from this menu, so quitting loses nothing.
var _just_saved := false
var _was_paused := false
## Opened by open_settings(): backing out of Settings closes the menu.
var _settings_only := false
## The brass tab the page title sits on, the bar behind the chosen row, and the
## plain style every other row gets (it keeps the rows' text in the same place).
var _title_style: StyleBoxTexture
var _select_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty


func _ready() -> void:
	layer = 28
	UiScale.layer(self)
	add_to_group("pause_menu")
	Settings.ensure_loaded()
	Settings.apply(get_window())
	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", HEADING)
	# a brass tab on the panel's top-left edge, the page's name sitting in it
	_title_style = _style("res://assets/ui/tag.png", 4.0)
	_title_style.content_margin_left = 6.0
	_title_style.content_margin_right = 6.0
	_title_style.expand_margin_top = 5.0
	_title_style.expand_margin_left = 2.0
	_title.add_theme_stylebox_override("normal", _title_style)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN # the tab hugs the title
	column.add_child(_title)
	_select_style = _style("res://assets/ui/select.png", 2.0)
	_select_style.content_margin_left = 2.0
	_select_style.expand_margin_top = 1.0
	_select_style.expand_margin_bottom = 1.0
	_plain_style = StyleBoxEmpty.new()
	_plain_style.content_margin_left = 2.0
	_pages.append(_build_main())
	_pages.append(_build_settings())
	_pages.append(_build_controls())
	_pages.append(_build_slots())
	for page in _pages:
		column.add_child(page)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	_footer = ButtonHints.new()
	_footer.add_theme_color_override("font_color", DIM)
	column.add_child(_footer)


## A nine-slice style from a texture, with its corners [param margin] pixels in.
func _style(path: String, margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	return style


func _build_main() -> Control:
	var both := HBoxContainer.new()
	both.add_theme_constant_override("separation", 8)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 2)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	both.add_child(page)
	for option in OPTIONS:
		var label := _label(option)
		page.add_child(label)
		_option_labels.append(label)
	page.add_child(_spacer(8))
	page.add_child(_label("Goal", HEADING))
	_goal_label = _label("")
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_label.custom_minimum_size.x = PANEL_SIZE.x - 16 - CARD_WIDTH - 8
	page.add_child(_goal_label)
	page.add_child(_spacer(4))
	var note := _label("Save here any time. Sleeping in your tent saves too.", DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = _goal_label.custom_minimum_size.x
	page.add_child(note)
	both.add_child(_build_card())
	return both


## The card beside the pause menu, like the player's page in Stardew Valley's
## menu: your face, the day, and how your time in the Valley is going.
func _build_card() -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.082, 0.078, 0.11, 0.2)
	style.border_color = Color(0.69, 0.573, 0.373, 0.55)
	style.border_width_left = 1
	style.content_margin_left = 8.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.x = CARD_WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	card.add_child(column)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("5e4a38")
	frame_style.border_color = Color("b0925f")
	frame_style.set_border_width_all(1)
	frame_style.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := TextureRect.new()
	face.texture = Portraits.for_speaker("You")
	face.custom_minimum_size = Vector2(48, 48)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(face)
	frame.visible = face.texture != null
	column.add_child(frame)
	_card_date = _label("", HEADING)
	_card_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_card_date)
	_card_stats = _label("")
	_card_stats.add_theme_constant_override("line_spacing", 0)
	column.add_child(_card_stats)
	return card


## What the card says: today, and a tally of the game so far.
static func card_text() -> PackedStringArray:
	var gear := 0
	for id: String in Gear.owned:
		gear += int(Gear.owned[id])
	var friends := 0
	var hearts := 0
	for id: String in Friendship.points:
		var h := Friendship.hearts(id)
		hearts += h
		if h > 0:
			friends += 1
	return PackedStringArray([
		"Food: %d energy" % Barter.purse(),
		"Gear: %d piece%s" % [gear, "" if gear == 1 else "s"],
		"Friends: %d (%d hearts)" % [friends, hearts],
		"Quests done: %d" % QuestLog.completed.size(),
		"Climbs: %d" % QuestLog.climbed.size(),
	])


func _build_settings() -> Control:
	var both := HBoxContainer.new()
	both.add_theme_constant_override("separation", 8)
	var page := VBoxContainer.new()
	# Rows sit close so all eleven settings and the hint line fit.
	page.add_theme_constant_override("separation", 0)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	both.add_child(page)
	for i in SETTING_NAMES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_label := _label(SETTING_NAMES[i])
		name_label.custom_minimum_size.x = NAME_WIDTH
		row.add_child(name_label)
		if i in VOLUME_SETTINGS:
			# a slider bar for each volume, ten notches, filled to the level
			var bar := Control.new()
			bar.custom_minimum_size = Vector2(52, 8)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.draw.connect(_draw_slider.bind(bar, i))
			row.add_child(bar)
			_sliders[i] = bar
		var value := _label("")
		row.add_child(value)
		page.add_child(row)
		_setting_names.append(name_label)
		_setting_values.append(value)
	# what the chosen setting does, in a card beside the list
	var card := _card_panel()
	card.custom_minimum_size.x = CARD_WIDTH
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	_help_title = _label("", HEADING)
	column.add_child(_help_title)
	_help_label = _label("", DIM)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.custom_minimum_size.x = CARD_WIDTH - 14
	column.add_child(_help_label)
	_sample_label = _label(SPEED_SAMPLE)
	_sample_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sample_label.custom_minimum_size.x = CARD_WIDTH - 14
	column.add_child(_sample_label)
	both.add_child(card)
	return both


## The framed card used beside the pause menu's and settings' lists.
func _card_panel() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.082, 0.078, 0.11, 0.2)
	style.border_color = Color(0.69, 0.573, 0.373, 0.55)
	style.border_width_left = 1
	style.content_margin_left = 8.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	card.add_theme_stylebox_override("panel", style)
	return card


func _build_controls() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	# the keys in two columns side by side, so all of them fit the screen
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 0)
	page.add_child(grid)
	for side in 2:
		if side == 1:
			grid.add_child(_spacer_x(10))
		grid.add_child(_label(""))
		for header in ["Keyboard", "Gamepad"]:
			var label := _label(header, HEADING)
			grid.add_child(label)
			_device_headers.append(label)
	var count := Settings.BINDINGS.size()
	_control_names.resize(count)
	_control_keys.resize(count)
	for row in CONTROLS_PER_COLUMN:
		for side in 2:
			var i := row + side * CONTROLS_PER_COLUMN
			if side == 1:
				grid.add_child(_spacer_x(10))
			if i >= count:
				for n in 3:
					grid.add_child(_label(""))
				continue
			var b: Dictionary = Settings.BINDINGS[i]
			var name_label := _label(b.name)
			grid.add_child(name_label)
			_control_names[i] = name_label
			var key := ButtonHints.new()
			key.custom_minimum_size = Vector2(30, 12)
			grid.add_child(key)
			_control_keys[i] = key
			grid.add_child(_label(b.pad, DIM))
	page.add_child(_spacer(3))
	for text in [CONTROLS_RESET, CONTROLS_BACK]:
		var label := _label(text)
		page.add_child(label)
		_control_names.append(label)
	page.add_child(_spacer(3))
	_control_note = _label("", DIM)
	_control_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_control_note.custom_minimum_size.x = PANEL_SIZE.x - 16
	page.add_child(_control_note)
	return page


func _spacer_x(width: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.x = width
	return spacer


func _build_slots() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	for n in SaveManager.SLOTS:
		var label := _label("")
		page.add_child(label)
		_slot_labels.append(label)
		var detail := _label("", DIM)
		page.add_child(detail)
		_slot_details.append(detail)
		page.add_child(_spacer(3))
	_slot_back = _label("")
	page.add_child(_slot_back)
	page.add_child(_spacer(4))
	_slot_note = _label("", DIM)
	_slot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_note.custom_minimum_size.x = PANEL_SIZE.x - 16
	page.add_child(_slot_note)
	return page


func is_open() -> bool:
	return _open


func open() -> void:
	if is_open():
		return
	_cursor = 0
	_confirm_quit = false
	_save_note = ""
	_just_saved = false
	_settings_only = false
	_slots_only = false
	_listening = -1
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and not hud.device_changed.is_connected(_refresh):
		hud.device_changed.connect(_refresh)
	_open = true
	_show_page(Page.MAIN)
	_panel.visible = true
	MenuInput.pop_in(_panel)
	_was_paused = GameClock.paused
	GameClock.paused = true
	_set_player_can_act(false)


## Opens straight onto the Settings page; Back closes the menu.
func open_settings() -> void:
	open()
	_settings_only = true
	_show_page(Page.SETTINGS)


## Opens straight onto the Saves page, for the title screen's Load game
## (SlotMode.LOAD) or New Game (SlotMode.NEW); Back closes the menu.
func open_slots(mode: SlotMode) -> void:
	open()
	_slots_only = true
	_show_slots(mode)


## Turns to the Saves page, the cursor on the slot that makes sense: the one
## being played (Save), the newest (Load), or the first empty one (New Game).
func _show_slots(mode: SlotMode) -> void:
	_slot_mode = mode
	_slot_confirm = 0
	_save_note = ""
	var n := SaveManager.slot
	match mode:
		SlotMode.LOAD:
			n = SaveManager.latest_slot()
		SlotMode.NEW:
			n = SaveManager.first_empty_slot()
	_slot_cursor = clampi(n, 1, SaveManager.SLOTS) - 1
	_show_page(Page.SLOTS)


func close() -> void:
	if not is_open():
		return
	_open = false
	MenuInput.pop_out(_panel)
	Sound.play("ui_close")
	GameClock.paused = _was_paused
	_set_player_can_act(true)
	closed.emit()


## Sizes the panel to the page showing, centered on the screen, so a short
## page isn't a tall board with its bottom half empty.
func _fit_panel() -> void:
	_panel.custom_minimum_size = Vector2(PANEL_SIZE.x, 0)
	var height := clampf(_panel.get_combined_minimum_size().y + 6.0, PANEL_MIN_HEIGHT, UiScale.SCREEN.y - 8.0)
	_panel.size = Vector2(PANEL_SIZE.x, height)
	_panel.custom_minimum_size = _panel.size
	_panel.position = Vector2(PANEL_POS.x, roundf((UiScale.SCREEN.y - height) / 2.0))
	_panel.pivot_offset = _panel.size / 2.0


## The page showing now (Page.MAIN, SETTINGS or CONTROLS).
func page() -> Page:
	return _page


func _show_page(which: Page) -> void:
	if which != _page and _open:
		MenuInput.fade_page(_pages[which])
	_page = which
	for i in _pages.size():
		_pages[i].visible = i == which
	_title.text = ["Paused", "Settings", "Controls", _slots_title()][which]
	_fit_panel.call_deferred()
	if which == Page.SETTINGS:
		_settings_cursor = 0
		_restart_sample()
	if which == Page.CONTROLS:
		_controls_cursor = 0
		_listening = -1
		_controls_message = ""
	_refresh()


func _slots_title() -> String:
	return ["Save game", "Load game", "New game"][_slot_mode]


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		if event.is_action_pressed("pause") and _player_can_act():
			get_viewport().set_input_as_handled()
			var hud := get_tree().get_first_node_in_group("hud") as HUD
			if hud and hud.info_panel.visible:
				hud.hide_info() # Esc closes the sign you're reading first
			else:
				open()
		return
	get_viewport().set_input_as_handled()
	if _listening >= 0:
		_listen_input(event)
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		Sound.play("ui_back")
		_back()
		return
	match _page:
		Page.MAIN:
			_main_input(event)
		Page.SETTINGS:
			_settings_input(event)
		Page.CONTROLS:
			_controls_input(event)
		Page.SLOTS:
			_slots_input(event)


## Back from the page showing: to the page that opened it, or closed.
func _back() -> void:
	match _page:
		Page.MAIN:
			close()
		Page.SETTINGS:
			if _settings_only:
				close()
			else:
				_cursor = Option.SETTINGS
				_show_page(Page.MAIN)
		Page.CONTROLS:
			if _controls_from_settings:
				_controls_from_settings = false
				_show_page(Page.SETTINGS)
				_settings_cursor = Setting.CONTROLS
				_refresh()
			else:
				_cursor = Option.CONTROLS
				_show_page(Page.MAIN)
		Page.SLOTS:
			if _slots_only:
				close()
			else:
				_cursor = Option.SAVE
				_show_page(Page.MAIN)


func _main_input(event: InputEvent) -> void:
	var step := MenuInput.vertical(event)
	if step != 0:
		_cursor = wrapi(_cursor + step, 0, OPTIONS.size())
		_confirm_quit = false
		Sound.play("ui_move")
		_refresh()
	elif MenuInput.confirm(event):
		Sound.play("ui_select")
		MenuInput.press(_option_labels[_cursor])
		match _cursor:
			Option.RESUME:
				close()
			Option.SAVE:
				_show_slots(SlotMode.SAVE)
			Option.SETTINGS:
				_show_page(Page.SETTINGS)
			Option.CONTROLS:
				_controls_from_settings = false
				_show_page(Page.CONTROLS)
			Option.QUIT_TITLE:
				if _confirm_quit:
					quit_to_title()
				else:
					_confirm_quit = true
					_refresh()
			Option.QUIT:
				if _confirm_quit:
					get_tree().quit()
				else:
					_confirm_quit = true
					_refresh()


## Leaves the game for the title screen: the screen fades to black, every
## autoload goes back to a new game's state (NewGame.reset_all), so whatever
## is played next starts clean, and the title screen comes up.
func quit_to_title() -> void:
	_open = false
	_panel.visible = false
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = UiScale.SCREEN
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	await tween.finished
	SaveManager.clear_pending()
	SaveManager._fresh = false # Continue loads the save on disk again
	NewGame.reset_all()
	get_tree().change_scene_to_file(TitleScreen.SCENE)


## Saves the game where the player stands, in the slot being played, and
## notes the time on the menu.
func save_game() -> void:
	_just_saved = SaveManager.save_game()
	if _just_saved:
		_save_note = "Saved in slot %d at %s." % [SaveManager.slot, GameClock.get_time_string()]
	else:
		_save_note = "Couldn't save. Check that the game can write to its save folder."
	_refresh()


func _slots_input(event: InputEvent) -> void:
	var rows := SaveManager.SLOTS + 1 # the slots, then Back
	var step := MenuInput.vertical(event)
	if step != 0:
		_slot_cursor = wrapi(_slot_cursor + step, 0, rows)
		_slot_confirm = 0
		Sound.play("ui_move")
		_refresh()
	elif MenuInput.confirm(event):
		if _slot_cursor >= SaveManager.SLOTS:
			Sound.play("ui_back")
			_back()
			return
		choose_slot(_slot_cursor + 1)


## Does what the Saves page does with slot [param n]: saves into it, loads
## it, or starts a new game in it. Writing over another game asks first.
func choose_slot(n: int) -> void:
	_slot_cursor = n - 1
	var used := SaveManager.slot_used(n)
	match _slot_mode:
		SlotMode.SAVE:
			if used and n != SaveManager.slot and _slot_confirm != n:
				_slot_confirm = n
				Sound.play("ui_select")
				_refresh()
				return
			_slot_confirm = 0
			SaveManager.slot = n
			Sound.play("ui_select")
			save_game()
		SlotMode.LOAD:
			if not used:
				Sound.play("ui_back")
				return
			Sound.play("ui_select")
			SaveManager.slot = n
			close()
			slot_chosen.emit(n)
		SlotMode.NEW:
			if used and _slot_confirm != n:
				_slot_confirm = n
				Sound.play("ui_select")
				_refresh()
				return
			Sound.play("ui_select")
			SaveManager.slot = n
			SaveManager.start_fresh()
			close()
			slot_chosen.emit(n)


func _controls_input(event: InputEvent) -> void:
	var rows := Settings.BINDINGS.size() + 2 # the keys, Reset keys, Back
	var step := MenuInput.vertical(event)
	var side := MenuInput.horizontal(event)
	var keys := Settings.BINDINGS.size()
	if side != 0 and _controls_cursor < keys:
		# Left/Right cross between the two columns of keys
		var other := _controls_cursor + side * CONTROLS_PER_COLUMN
		if other >= 0 and other < keys:
			_controls_cursor = other
		elif side > 0:
			_controls_cursor = keys - 1
		Sound.play("ui_move")
		_controls_message = ""
		_refresh()
	elif step != 0:
		_controls_cursor = wrapi(_controls_cursor + step, 0, rows)
		_controls_message = ""
		Sound.play("ui_move")
		_refresh()
	elif MenuInput.confirm(event):
		Sound.play("ui_select")
		if _controls_cursor == rows - 1:
			_back()
		elif _controls_cursor == rows - 2:
			reset_keys()
		else:
			_listening = _controls_cursor
			_controls_message = ""
			_refresh()


## While a key is wanted: the next key pressed is the binding's (Esc keeps
## the old key). Gamepad buttons and the mouse are ignored.
func _listen_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		if event.is_action_pressed("ui_cancel") and not event is InputEventKey:
			_listening = -1
			_refresh()
		return
	var key := event as InputEventKey
	var physical := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if physical == KEY_ESCAPE:
		Sound.play("ui_back")
		_listening = -1
		_refresh()
		return
	bind_key(_listening, physical)


## Puts binding [param index] (into Settings.BINDINGS) on [param physical],
## saves, and tells the HUD so its hints name the new key.
func bind_key(index: int, physical: int) -> void:
	_listening = -1
	var b: Dictionary = Settings.BINDINGS[index]
	if Settings.set_key(b.id, physical):
		Sound.play("ui_select")
		_controls_message = "%s is now %s." % [b.name, Settings.key_label(physical)]
		_keys_changed()
	else:
		Sound.play("ui_back")
		_controls_message = RESERVED_TEXT
		_refresh()


func reset_keys() -> void:
	Settings.reset_keys()
	_controls_message = "Every key is back as it started."
	_keys_changed()


func _keys_changed() -> void:
	Settings.save()
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.refresh_settings()
	_refresh()


func _settings_input(event: InputEvent) -> void:
	var step := MenuInput.vertical(event)
	if step != 0:
		_settings_cursor = wrapi(_settings_cursor + step, 0, SETTING_NAMES.size())
		Sound.play("ui_move")
		_restart_sample()
		_refresh()
		return
	var change := MenuInput.horizontal(event)
	if change == 0 and MenuInput.confirm(event) and _settings_cursor == Setting.CONTROLS:
		Sound.play("ui_select")
		_controls_from_settings = true
		_show_page(Page.CONTROLS)
		return
	if change == 0 and MenuInput.confirm(event):
		if _settings_cursor == Setting.BACK:
			if _settings_only:
				close()
				return
			_cursor = OPTIONS.find("Settings")
			_show_page(Page.MAIN)
			return
		change = 1
		# E steps a volume up, and from 100% round to Off (Left/Right stop at
		# the ends, so Left from Off never jumps to full).
		if _settings_cursor in [Setting.MASTER_VOLUME, Setting.MUSIC_VOLUME, Setting.EFFECTS_VOLUME, Setting.AMBIENCE_VOLUME] \
				and _volume(_settings_cursor) >= Settings.MAX_VOLUME:
			change = -Settings.MAX_VOLUME
	if change != 0:
		change_setting(_settings_cursor, change)
		if _settings_cursor < _setting_values.size():
			MenuInput.press(_setting_values[_settings_cursor])


## Steps setting [param which] (a Setting) by [param step], then saves and applies it.
func change_setting(which: int, step: int) -> void:
	match which:
		Setting.TEXT_SPEED:
			Settings.text_speed = wrapi(Settings.text_speed + step, 0, Settings.TextSpeed.size()) as Settings.TextSpeed
			_restart_sample()
		Setting.FONT:
			Settings.pixel_font = not Settings.pixel_font
			Settings.apply_font()
		Setting.GRAPHICS:
			var order := Settings.GRAPHICS_ORDER
			Settings.graphics = order[wrapi(order.find(Settings.graphics) + step, 0, order.size())]
			# picking Auto again looks afresh at how the game runs here
			Settings.auto_low = false
		Setting.FULLSCREEN:
			Settings.fullscreen = not Settings.fullscreen
		Setting.WINDOW_SIZE:
			if Settings.fullscreen:
				return
			Settings.window_scale = clampi(Settings.window_scale + step, Settings.MIN_SCALE, Settings.max_window_scale())
		Setting.PROMPTS:
			Settings.prompts = wrapi(Settings.prompts + step, 0, Settings.Prompts.size()) as Settings.Prompts
		Setting.TIPS:
			Settings.tips = not Settings.tips
		Setting.MASTER_VOLUME:
			Settings.master_volume = clampi(Settings.master_volume + step, 0, Settings.MAX_VOLUME)
		Setting.MUSIC_VOLUME:
			Settings.music_volume = clampi(Settings.music_volume + step, 0, Settings.MAX_VOLUME)
		Setting.EFFECTS_VOLUME:
			Settings.effects_volume = clampi(Settings.effects_volume + step, 0, Settings.MAX_VOLUME)
		Setting.AMBIENCE_VOLUME:
			Settings.ambience_volume = clampi(Settings.ambience_volume + step, 0, Settings.MAX_VOLUME)
		_:
			return
	Settings.save()
	Settings.apply(get_window())
	Sound.apply_volumes()
	if which in [Setting.MASTER_VOLUME, Setting.EFFECTS_VOLUME]:
		Sound.play("ui_select", 0.0, 0.0) # a sample at the new level
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud:
		hud.refresh_settings()
	_refresh()


func _process(delta: float) -> void:
	if not is_open() or _page != Page.SETTINGS or not _sample_label.visible:
		return
	var cps := Settings.chars_per_second()
	if cps <= 0.0 or _sample_shown >= SPEED_SAMPLE.length():
		_sample_label.visible_characters = -1
		return
	_sample_shown += delta * cps
	_sample_label.visible_characters = int(_sample_shown)


func _restart_sample() -> void:
	_sample_shown = 0.0
	_sample_label.visible_characters = 0 if Settings.chars_per_second() > 0.0 else -1


func _refresh() -> void:
	for i in _option_labels.size():
		var text: String = OPTIONS[i]
		if i == Option.SAVE and _save_note != "":
			text += "   " + _save_note
		elif i == Option.QUIT and _confirm_quit and i == _cursor:
			text = QUIT_SAVED if _just_saved else QUIT_CONFIRM
		elif i == Option.QUIT_TITLE and _confirm_quit and i == _cursor:
			text = TITLE_SAVED if _just_saved else TITLE_CONFIRM
		_set_choice(_option_labels[i], text, i == _cursor)
	_goal_label.text = HUD.objective_text() if HUD.objective_text() != "" else "Explore, and talk to people around the valley."
	_card_date.text = "%s, Year %d" % [GameClock.get_date_string(), GameClock.year]
	_card_stats.text = "\n".join(card_text())
	for i in _setting_names.size():
		_set_choice(_setting_names[i], SETTING_NAMES[i], i == _settings_cursor)
		_setting_values[i].text = _setting_value(i)
		if _sliders.has(i):
			_sliders[i].queue_redraw()
		_setting_values[i].modulate = DIM if i == Setting.WINDOW_SIZE and Settings.fullscreen else Color.WHITE
	_help_label.text = SETTING_HELP[_settings_cursor]
	_help_title.text = SETTING_NAMES[_settings_cursor]
	if _settings_only and _settings_cursor == Setting.BACK:
		_help_label.text = "Back to the title screen."
	_sample_label.visible = _settings_cursor == Setting.TEXT_SPEED
	_refresh_controls()
	_refresh_slots()
	# Mark the column for the device in use, in words as well as color.
	var gamepad := MenuInput.button(get_tree(), "k", "g") == "g"
	for i in _device_headers.size():
		var pad := i % 2 == 1
		_device_headers[i].text = ["Keyboard", "Gamepad"][i % 2]
		_device_headers[i].modulate = Color.WHITE if pad == gamepad else DIM
	_footer.text = _footer_text()


func _refresh_controls() -> void:
	for i in _control_names.size():
		var text: String = Settings.BINDINGS[i].name if i < Settings.BINDINGS.size() else [CONTROLS_RESET, CONTROLS_BACK][i - Settings.BINDINGS.size()]
		_set_choice(_control_names[i], text, i == _controls_cursor)
	for i in _control_keys.size():
		var id: String = Settings.BINDINGS[i].id
		_control_keys[i].text = "..." if i == _listening else "[%s]" % Settings.key_label(Settings.key_for(id))
		_control_keys[i].modulate = Color.WHITE if Settings.key_for(id) == int(Settings.BINDINGS[i].key) else HEADING
	if _listening >= 0:
		_control_note.text = LISTEN_TEXT % Settings.BINDINGS[_listening].name
	elif _controls_message != "":
		_control_note.text = _controls_message
	else:
		_control_note.text = CONTROLS_NOTE


## Each slot's two lines: "Slot 1   Spring 4 (Thu), Year 1" and where and
## when, or "Empty".
func _refresh_slots() -> void:
	for i in _slot_labels.size():
		var n := i + 1
		var info := SaveManager.slot_info(n)
		var text := "Slot %d   " % n
		var detail := ""
		if info.is_empty():
			text += "Empty"
			detail = "Start a new game here." if _slot_mode == SlotMode.NEW else ""
		elif info.get("broken", false):
			text += "Can't be read"
		else:
			text += str(info.date)
			var parts := PackedStringArray()
			if str(info.place) != "":
				parts.append(str(info.place))
			parts.append(str(info.time))
			if int(info.saved_at) > 0:
				parts.append("saved " + _when(int(info.saved_at)))
			detail = " · ".join(parts)
		if _slot_mode == SlotMode.SAVE and n == SaveManager.slot and not _slots_only:
			text += "   (this game)"
		if _slot_confirm == n:
			detail = "Press again to replace this game." if _slot_mode == SlotMode.SAVE else "Press again to start over here. The old game is replaced when you first sleep."
		_set_choice(_slot_labels[i], text, i == _slot_cursor)
		_slot_details[i].text = "      " + detail
	_set_choice(_slot_back, "Back", _slot_cursor >= SaveManager.SLOTS)
	_slot_note.modulate = HEADING if _save_note != "" else Color.WHITE
	match _slot_mode:
		SlotMode.SAVE when _save_note != "":
			_slot_note.text = _save_note
		SlotMode.SAVE:
			_slot_note.text = "Save into any slot. Saving in another slot keeps this game there from now on, and sleeping in your tent saves there too."
		SlotMode.LOAD:
			_slot_note.text = "Pick a game to carry on."
		SlotMode.NEW:
			_slot_note.text = "Pick a slot for the new game. Each slot is its own game."


## "Nov 5, 7:24 PM" for a Unix time, in the computer's time zone.
static func _when(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var hour := int(d.hour)
	return "%s %d, %d:%02d %s" % [MONTHS[int(d.month) - 1], int(d.day), 12 if hour % 12 == 0 else hour % 12, int(d.minute), "AM" if hour < 12 else "PM"]


## "< Normal >" for a setting's current value.
func _setting_value(which: int) -> String:
	var value := ""
	match which:
		Setting.TEXT_SPEED:
			value = Settings.TEXT_SPEED_NAMES[Settings.text_speed]
		Setting.FONT:
			value = "Pixel" if Settings.pixel_font else "Smooth"
		Setting.GRAPHICS:
			value = Settings.graphics_name()
			if Settings.graphics_pending():
				value += " (on restart)"
		Setting.FULLSCREEN:
			value = "On" if Settings.fullscreen else "Off"
		Setting.WINDOW_SIZE:
			if Settings.fullscreen:
				return "(full screen)"
			value = "%dx  (%d x %d)" % [Settings.window_scale, Settings.BASE_SIZE.x * Settings.window_scale, Settings.BASE_SIZE.y * Settings.window_scale]
		Setting.PROMPTS:
			value = Settings.PROMPT_NAMES[Settings.prompts]
		Setting.TIPS:
			value = "On" if Settings.tips else "Off"
		Setting.MASTER_VOLUME, Setting.MUSIC_VOLUME, Setting.EFFECTS_VOLUME, Setting.AMBIENCE_VOLUME:
			value = _volume_text(_volume(which))
		_:
			return ""
	return "‹  %s  ›" % value


## A volume's slider: ten notches, gold up to the level on the chosen row.
func _draw_slider(bar: Control, which: int) -> void:
	var level := _volume(which)
	var chosen := which == _settings_cursor
	var on := Color(1, 0.831, 0.541) if chosen else Color(0.894, 0.867, 0.8)
	bar.draw_rect(Rect2(0, 0, 52, 8), Color("2a1b14"))
	for n in Settings.MAX_VOLUME:
		var notch := Rect2(1 + n * 5, 1, 4, 6)
		bar.draw_rect(notch, on if n < level else Color(0.369, 0.29, 0.22))
		if n < level:
			bar.draw_rect(Rect2(notch.position, Vector2(4, 1)), on.lightened(0.4))


## The level of volume setting [param which] (0 to Settings.MAX_VOLUME).
func _volume(which: int) -> int:
	match which:
		Setting.MASTER_VOLUME:
			return Settings.master_volume
		Setting.MUSIC_VOLUME:
			return Settings.music_volume
		Setting.EFFECTS_VOLUME:
			return Settings.effects_volume
	return Settings.ambience_volume


## "70%", or "Off" at 0.
func _volume_text(level: int) -> String:
	return "Off" if level <= 0 else "%d%%" % (level * 100 / Settings.MAX_VOLUME)


func _footer_text() -> String:
	var tree := get_tree()
	var choose := MenuInput.button(tree, "Up/Down", "D-pad")
	var ok := MenuInput.button(tree, "E", "A")
	var back := MenuInput.button(tree, "Esc", "B")
	match _page:
		Page.SETTINGS:
			return "[%s] Choose   [%s] Change   [%s] Back" % [choose, MenuInput.button(tree, "Left/Right", "D-pad L/R"), back]
		Page.CONTROLS:
			if _listening >= 0:
				return "Press any key   [Esc] Cancel"
			return "[%s] Choose   [%s] Change key   [%s] Back" % [MenuInput.button(tree, "Arrows", "D-pad"), ok, back]
		Page.SLOTS:
			return "[%s] Choose   [%s] %s   [%s] Back" % [choose, ok, ["Save here", "Load", "Start here"][_slot_mode], back]
	return "[%s] Choose   [%s] Select   [%s] Resume" % [choose, ok, back]


## A menu line: an arrow, gold and a highlight bar when chosen, so it shows without the color too.
func _set_choice(label: Label, text: String, chosen: bool) -> void:
	label.text = "   " + text
	MenuInput.mark(label, chosen)
	label.add_theme_color_override("font_color", HEADING if chosen else Color.WHITE)
	label.add_theme_stylebox_override("normal", _select_style if chosen else _plain_style)


func _label(text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _player() -> Player:
	var world := get_tree().get_first_node_in_group("world")
	return world.player if world else null


func _player_can_act() -> bool:
	var player := _player()
	return player != null and player.can_act


func _set_player_can_act(value: bool) -> void:
	var player := _player()
	if player:
		player.can_act = value
