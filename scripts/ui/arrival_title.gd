class_name ArrivalTitle
extends Control
## A Breath-of-the-Wild style region title card: the region's name big across
## the upper screen with a thin gold rule growing out under it and a subtitle
## below, no panel. Fades in, holds, fades out. The HUD adds one and calls
## show_title() the first time you arrive somewhere (see HUD.show_arrival).
## Drawn in the HUD's 480x270 UI pixels (see UiScale). Never takes input.

const TOP := 58.0
const MAX_WIDTH := 440.0
const TITLE_SIZES := [16, 14, 12, 10]
const SUBTITLE_SIZE := 8
const CREAM := Color("f5eee0")
const SUB := Color("e4ddcc")
const DARK := Color("2a1b14")
const GOLD := Color("f1cf6a")
const FADE_IN := 0.4
const HOLD := 2.2
const FADE_OUT := 0.6

var _title := ""
var _subtitle := ""
var _title_size := 16
var _rule := 0.0 # 0..1 how far the gold rule has grown
var _tween: Tween
var _showing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = UiScale.SCREEN
	visible = false
	modulate.a = 0.0


## True while a card is on screen.
func is_showing() -> bool:
	return _showing


## Hides the card without ending it while a menu or conversation covers the HUD.
func set_covered(covered: bool) -> void:
	self_modulate.a = 0.0 if covered else 1.0


func show_title(title: String, subtitle: String) -> void:
	if _tween:
		_tween.kill()
	_title = title
	_subtitle = subtitle
	var font := get_theme_default_font()
	_title_size = TITLE_SIZES[-1]
	for s: int in TITLE_SIZES:
		if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= MAX_WIDTH:
			_title_size = s
			break
	_rule = 0.0
	_showing = true
	visible = true
	modulate.a = 0.0
	queue_redraw()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.parallel().tween_property(self, "_rule", 1.0, FADE_IN + 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(_finish)


func _finish() -> void:
	_showing = false
	visible = false


func _process(_delta: float) -> void:
	if _showing:
		queue_redraw()


func _draw_centered(font: Font, text: String, y: float, fsize: int, color: Color) -> float:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var x := floorf((UiScale.SCREEN.x - w) / 2.0)
	var base := floorf(y + font.get_ascent(fsize))
	draw_string_outline(font, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 2, DARK)
	draw_string(font, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)
	return w


func _draw() -> void:
	if not _showing:
		return
	var font := get_theme_default_font()
	# a soft dark band behind the words, stepped out at the ends, so they read
	# over snow and sunlit granite as well as over shade
	var title_w := font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_size).x
	var band_h := font.get_height(_title_size) + (font.get_height(SUBTITLE_SIZE) + 6.0 if _subtitle != "" else 2.0) + 10.0
	var band_w := minf(title_w + 64.0, UiScale.SCREEN.x)
	for step in 3:
		var inset := float(step) * 10.0
		var band := Rect2(floorf((UiScale.SCREEN.x - band_w) / 2.0) + inset, TOP - 5.0, band_w - inset * 2.0, band_h)
		draw_rect(band, Color(DARK, 0.2))
	var w := _draw_centered(font, _title, TOP, _title_size, CREAM)
	var rule_y := floorf(TOP + font.get_height(_title_size) + 3.0)
	var half := floorf(clampf(w, 40.0, MAX_WIDTH) / 2.0 * _rule)
	var cx := floorf(UiScale.SCREEN.x / 2.0)
	if half >= 1.0:
		draw_rect(Rect2(cx - half - 1.0, rule_y - 1.0, half * 2.0 + 2.0, 3.0), DARK)
		draw_rect(Rect2(cx - half, rule_y, half * 2.0, 1.0), GOLD)
	if _subtitle != "":
		_draw_centered(font, _subtitle, rule_y + 4.0, SUBTITLE_SIZE, SUB)
