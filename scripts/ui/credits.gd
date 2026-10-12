class_name Credits
extends CanvasLayer
## The credits, opened from the title screen. Two pages:
##   Credits: who made the game and the data, font, and engine it uses. It
##     scrolls by itself; Up/Down scroll it by hand.
##   Licenses: the full license texts the game must carry: Godot and the
##     libraries built into it (read from the engine, so they always match the
##     version the game runs on), and the font's SIL Open Font License.
## Left/Right (LB/RB) switch pages, Esc (B) or E (A) closes.
##
## The map data credit is required by the OpenStreetMap license (ODbL); keep it
## here whatever else changes. See "Map data credits" in the README.

signal closed

enum Page { CREDITS, LICENSES }

## Each entry: [heading, lines]. Headings show in gold; an empty heading is a gap.
const CREDITS := [
	["", ["A cozy pixel exploration game set in Yosemite National Park."]],
	["Made by", ["Cory Goehring"]],
	["Maps", [
		"Map data © OpenStreetMap contributors,",
		"available under the Open Database License (ODbL).",
		"openstreetmap.org/copyright",
	]],
	["Elevation", [
		"USGS 3D Elevation Program (public domain),",
		"from the AWS Terrain Tiles open dataset.",
	]],
	["Art and sound", [
		"Drawn and synthesized by the game's own generators",
		"(tools/ in the project).",
	]],
	["Fonts", [
		"Noto Sans, © 2022 The Noto Project Authors, and",
		"DotGothic16, © 2020 The DotGothic16 Project Authors",
		"(its Latin letters set proportionally for this game),",
		"both under the SIL Open Font License 1.1.",
	]],
	["Engine", [
		"Made with Godot Engine.",
		"© 2014-present Godot Engine contributors.",
		"© 2007-2014 Juan Linietsky, Ariel Manzur.",
		"Godot and its libraries' licenses are on the Licenses page.",
	]],
	["Thanks", [
		"To the people of Yosemite, past and present,",
		"whose stories this game tries to tell with care.",
	]],
	["", ["Thank you for playing."]],
]
const FONT_LICENSE := "res://assets/fonts/NotoSans-OFL.txt"
const PIXEL_FONT_LICENSE := "res://assets/fonts/DotGothic16-OFL.txt"
const HEADING := Color(1.0, 0.85, 0.5)
const DIM := Color(1, 1, 1, 0.6)
const PANEL_POS := Vector2(30, 16)
const PANEL_SIZE := Vector2(420, 238)
## Pixels a second the Credits page drifts up by itself, and how fast Up/Down
## scroll by hand.
const DRIFT_SPEED := 12.0
const SCROLL_SPEED := 120.0
## Seconds before the Credits page starts drifting, and after it reaches the end
## before it starts over.
const DRIFT_WAIT := 1.5

var _panel: PanelContainer
var _title: Label
var _text: RichTextLabel
var _fade_above: TextureRect
var _fade_below: TextureRect
var _footer: Label
var _page := Page.CREDITS
## The Credits page drifts until the player scrolls it by hand.
var _drifting := true
var _wait := DRIFT_WAIT
var _scroll := 0.0


func _ready() -> void:
	layer = 30
	add_to_group("credits")
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
	var tag := StyleBoxTexture.new()
	tag.texture = load("res://assets/ui/tag.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		tag.set_texture_margin(side, 4.0)
	tag.content_margin_left = 6.0
	tag.content_margin_right = 6.0
	tag.expand_margin_top = 5.0
	tag.expand_margin_left = 2.0
	_title.add_theme_stylebox_override("normal", tag)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false # scrolled by _process, no scroll bar
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_constant_override("line_separation", 1)
	column.add_child(_text)
	_fade_above = MenuInput.edge_fade(_text, true)
	_fade_below = MenuInput.edge_fade(_text, false)
	_footer = Label.new()
	_footer.modulate = DIM
	column.add_child(_footer)


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_panel.visible = true
	_show_page(Page.CREDITS)


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	closed.emit()


func page() -> Page:
	return _page


## The Credits page as BBCode (also used by tests to check the required lines).
static func credits_bbcode() -> String:
	var out := PackedStringArray()
	out.append("[center][font_size=20][color=#%s]%s[/color][/font_size][/center]" % [HEADING.to_html(false), ProjectSettings.get_setting("application/config/name")])
	for entry: Array in CREDITS:
		out.append("")
		var lines := PackedStringArray()
		if entry[0] != "":
			lines.append("[color=#%s]%s[/color]" % [HEADING.to_html(false), entry[0]])
		for line: String in entry[1]:
			lines.append(_escape(line))
		out.append("[center]%s[/center]" % "\n".join(lines))
	return "\n".join(out)


## Every license the shipped game has to carry, as BBCode.
static func licenses_bbcode() -> String:
	var out := PackedStringArray()
	var gold := HEADING.to_html(false)
	out.append("[color=#%s]Godot Engine[/color]" % gold)
	out.append(_escape(Engine.get_license_text()))
	out.append("[color=#%s]Noto Sans[/color]" % gold)
	out.append(_escape(FileAccess.get_file_as_string(FONT_LICENSE)) if FileAccess.file_exists(FONT_LICENSE) \
		else "Copyright 2022 The Noto Project Authors. SIL Open Font License, Version 1.1.")
	out.append("[color=#%s]DotGothic16 (as DotGothic16 Prop, its Latin letters set proportionally by tools/fonts/proportional.py)[/color]" % gold)
	out.append(_escape(FileAccess.get_file_as_string(PIXEL_FONT_LICENSE)) if FileAccess.file_exists(PIXEL_FONT_LICENSE) \
		else "Copyright 2020 The DotGothic16 Project Authors. SIL Open Font License, Version 1.1.")
	out.append("[color=#%s]Libraries in Godot Engine[/color]" % gold)
	for component: Dictionary in Engine.get_copyright_info():
		if component.name == "Godot Engine":
			continue
		var lines := PackedStringArray([str(component.name)])
		for part: Dictionary in component.parts:
			for holder: String in part.copyright:
				lines.append("  © " + holder)
			lines.append("  License: " + str(part.license))
		out.append(_escape("\n".join(lines)))
	var texts: Dictionary = Engine.get_license_info()
	var names := texts.keys()
	names.sort()
	for license_name: String in names:
		out.append("[color=#%s]License: %s[/color]" % [gold, license_name])
		out.append(_escape(str(texts[license_name])))
	return "\n\n".join(out)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _show_page(which: Page) -> void:
	_page = which
	_title.text = ["Credits", "Licenses"][which]
	_text.text = credits_bbcode() if which == Page.CREDITS else licenses_bbcode()
	_scroll = 0.0
	_drifting = which == Page.CREDITS
	_wait = DRIFT_WAIT
	_text.scroll_to_line(0)
	_footer.text = _footer_text()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or MenuInput.confirm(event):
		close()
		return
	var step := MenuInput.horizontal(event)
	if step == 0 and event.is_action_pressed("tab_next"):
		step = 1
	elif step == 0 and event.is_action_pressed("tab_previous"):
		step = -1
	if step != 0:
		_show_page(wrapi(_page + step, 0, Page.size()) as Page)
	elif MenuInput.vertical(event) != 0:
		_drifting = false


func _process(delta: float) -> void:
	if not is_open():
		return
	var bar := _text.get_v_scroll_bar()
	var end := maxf(bar.max_value - bar.page, 0.0)
	var held := Input.get_axis("move_up", "move_down")
	if held != 0.0:
		_drifting = false
		_scroll += held * SCROLL_SPEED * delta
	elif _drifting:
		if _wait > 0.0:
			_wait -= delta # a pause at the top, and at the end
			if _wait <= 0.0 and _scroll >= end:
				_scroll = 0.0 # start over
				_wait = DRIFT_WAIT
		else:
			_scroll += DRIFT_SPEED * delta
			if _scroll >= end:
				_wait = DRIFT_WAIT * 2.0
	_scroll = clampf(_scroll, 0.0, end)
	bar.value = roundf(_scroll)
	_fade_above.visible = _scroll > 0.5
	_fade_below.visible = _scroll < end - 0.5


func _footer_text() -> String:
	var tree := get_tree()
	var pages := MenuInput.button(tree, "Left/Right", "LB/RB")
	var scroll := MenuInput.button(tree, "Up/Down", "Stick")
	var back := MenuInput.button(tree, "Esc", "B")
	var other := "Licenses" if _page == Page.CREDITS else "Credits"
	return "[%s] Scroll   [%s] %s   [%s] Back" % [scroll, pages, other, back]
