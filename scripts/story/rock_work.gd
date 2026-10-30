class_name RockWork
extends CanvasLayer
## Resetting a granite step with a rock bar, for the Guardian's Year trail
## crew (WorkSpot). Three stops on a timing meter, like a cast on the
## fishing screen: pry the old block out of the mud, lever it over onto its
## bed, and drop it square. Each stop is perfect (the green's bright middle),
## good (the rest of the green) or a miss, and the meter runs quicker each
## time. A miss lets the block slip back into the rut, and you start that
## step again. Three perfects make a perfect fit.
##
## The rules are in [method step] and [method press], so tests can play it
## without the keyboard. WorkSpot opens one and waits for finished, then
## reads [member outcome].

signal finished(set_it: bool)

## The three stops, in order: what the card says, and how fast the marker
## sweeps (bar lengths a second).
const STOPS := [
	{"name": "PRY IT OUT", "speed": 0.95},
	{"name": "LEVER IT OVER", "speed": 1.2},
	{"name": "DROP IT SQUARE", "speed": 1.45},
]
## The green's width (a share of the bar), and the share of it that's perfect.
const WINDOW := 0.24
const PERFECT_SHARE := 0.4
## Sweeps before your arms give out, which counts as a miss.
const MAX_PASSES := 6
## Seconds the meter waits when it opens and between stops, so one press
## can't spend two.
const GRACE := 0.35
## Game minutes a slipped block costs.
const SLIP_MINUTES := 10
## What WorkSpot adds when the step is set, by outcome.
const SET_TEXT := {
	"perfect": "A perfect fit: three clean heaves on the bar.",
	"set": "",
}
## What the HUD says when it isn't, by outcome.
const SLIP_TEXT := {
	"slipped": "The bar skids, and the block rolls back into the rut. Catch your breath and set the bar again.",
	"gave_up": "You lean the rock bar against a tree. The step can wait.",
}
const CARD_RECT := Rect2(130, 52, 220, 78)

## Which stop you're on (0 to 2), and how each went so far.
var stop := 0
var results: Array[String] = []
## "set", "perfect", "slipped" or "gave_up" once it's over; "" until then.
var outcome := ""
var meter_pos := 0.0
var meter_dir := 1.0
var meter_center := 0.5
var meter_passes := 0

var _grace := 0.0
var _flash := ""
var _flash_age := 9.0
var _rng := RandomNumberGenerator.new()
var _canvas: Control


func _ready() -> void:
	layer = 18
	UiScale.layer(self)
	_canvas = Control.new()
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw)
	add_child(_canvas)


## [param seed] fixes where the green sits.
func start(seed := -1) -> void:
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	stop = 0
	results = []
	outcome = ""
	_begin_stop()
	Sound.play("climb_move", -6.0, 0.1)


## What a stop at [param pos] is: "perfect", "good" or "miss".
func judge(pos: float) -> String:
	var off := absf(pos - meter_center)
	var half := WINDOW / 2.0
	if off <= half * PERFECT_SHARE:
		return "perfect"
	return "good" if off <= half else "miss"


func is_over() -> bool:
	return outcome != ""


## Stops the meter where the marker is now. Does nothing once it's over, or
## while the meter is still opening.
func press() -> void:
	if is_over() or _grace > 0.0:
		return
	_stop(judge(meter_pos))


## Moves the meter on by [param delta] seconds.
func step(delta: float) -> void:
	_flash_age += delta
	if is_over():
		return
	if _grace > 0.0:
		_grace -= delta
	else:
		meter_pos += meter_dir * float(STOPS[stop].speed) * delta
		if meter_pos >= 1.0 or meter_pos <= 0.0:
			meter_pos = clampf(meter_pos, 0.0, 1.0)
			meter_dir = -meter_dir
			meter_passes += 1
			if meter_passes >= MAX_PASSES:
				_stop("miss")
	if _canvas:
		_canvas.queue_redraw()


func give_up() -> void:
	if not is_over():
		_end("gave_up")


func _begin_stop() -> void:
	_grace = GRACE
	meter_pos = 0.0
	meter_dir = 1.0
	meter_passes = 0
	var half := WINDOW / 2.0
	meter_center = _rng.randf_range(0.2 + half, 0.8 - half)


func _stop(result: String) -> void:
	_flash = {"perfect": "PERFECT!", "good": "Good", "miss": "Slipped!"}[result]
	_flash_age = 0.0
	Sound.play("item_get" if result == "perfect" else ("climb_move" if result == "good" else "ui_back"), -4.0, 0.08)
	results.append(result)
	if result == "miss":
		_end("slipped")
		return
	stop += 1
	if stop >= STOPS.size():
		_end("perfect" if results.all(func(r: String) -> bool: return r == "perfect") else "set")
		return
	_begin_stop()


func _end(how: String) -> void:
	outcome = how
	finished.emit(how == "set" or how == "perfect")


func _process(delta: float) -> void:
	step(delta)


func _input(event: InputEvent) -> void:
	if is_over():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		give_up()
	elif event.is_action("interact") or event.is_action("use_tool"):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
			press()


func _use_button() -> String:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud.interact_button() if hud and hud.has_method("interact_button") else "E"


## The card: which heave it is, the bar and the block, and the meter.
func _draw() -> void:
	var ci := _canvas
	if not is_over():
		ClimbUI.panel(ci, CARD_RECT)
		var title: String = STOPS[stop].name
		ClimbUI.ink(ci, Vector2(CARD_RECT.position.x + CARD_RECT.size.x / 2, CARD_RECT.position.y + 16), title, ClimbUI.GOLD, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
		ClimbUI.ink(ci, Vector2(CARD_RECT.end.x - 10, CARD_RECT.position.y + 16), "%d/%d" % [stop + 1, STOPS.size()], ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
		_draw_block(Vector2(CARD_RECT.position.x + 22, CARD_RECT.position.y + 46))
		var bar := Rect2(CARD_RECT.position.x + 44, CARD_RECT.position.y + 30, CARD_RECT.size.x - 58, 12)
		ci.draw_rect(bar.grow(1), ClimbUI.WOOD_DARK)
		ci.draw_rect(bar, Color("5e4a38"))
		var good := Rect2(bar.position.x + bar.size.x * (meter_center - WINDOW / 2.0), bar.position.y, bar.size.x * WINDOW, bar.size.y)
		ci.draw_rect(good, ClimbUI.GOOD_DARK)
		var perfect_w := WINDOW * PERFECT_SHARE
		var perfect := Rect2(bar.position.x + bar.size.x * (meter_center - perfect_w / 2.0), bar.position.y, bar.size.x * perfect_w, bar.size.y)
		ci.draw_rect(perfect, ClimbUI.GOOD)
		var mx := bar.position.x + bar.size.x * meter_pos
		ci.draw_rect(Rect2(mx - 1, bar.position.y - 4, 3, bar.size.y + 8), ClimbUI.WOOD_DARK)
		ci.draw_rect(Rect2(mx, bar.position.y - 3, 1, bar.size.y + 6), ClimbUI.CREAM)
		ClimbUI.ink(ci, Vector2(bar.position.x + bar.size.x / 2, CARD_RECT.end.y - 14), "%s: heave in the green" % _use_button(), ClimbUI.INK_SOFT, 9, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if _flash_age <= 1.1 and _flash != "":
		var col: Color = {"PERFECT!": ClimbUI.GOLD, "Good": ClimbUI.CREAM}.get(_flash, ClimbUI.WARN)
		ClimbUI.outlined(ci, Vector2(CARD_RECT.position.x + CARD_RECT.size.x / 2, CARD_RECT.end.y + 18 - _flash_age * 12.0), _flash, col, 14, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


## The block on the bar, rising a little with each heave done.
func _draw_block(base: Vector2) -> void:
	var ci := _canvas
	var lift := 4.0 * stop
	ci.draw_rect(Rect2(base.x - 12, base.y - 2, 24, 3), Color("3f3022"))
	ci.draw_rect(Rect2(base.x - 9, base.y - 10 - lift, 14, 9), Color("5f5a52"))
	ci.draw_rect(Rect2(base.x - 8, base.y - 9 - lift, 12, 7), Color("c9c4b8"))
	ci.draw_rect(Rect2(base.x - 8, base.y - 9 - lift, 12, 2), Color("e4e0d6"))
	ci.draw_line(Vector2(base.x + 12, base.y - 18), Vector2(base.x - 2, base.y - 4 - lift), Color("8c877c"), 2.0)
