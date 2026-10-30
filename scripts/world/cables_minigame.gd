class_name CablesMinigame
extends CanvasLayer
## Up the cables on the back of Half Dome: two steel cables strung on posts
## up 400 feet of granite at about 45 degrees, with a wooden board across
## the rock at each pair of posts. You haul yourself up from board to board.
##
## Each pull is a stop on a timing meter, like a cast or a crux: stop the
## marker in the green and you reach the next board. A perfect stop (the
## green's bright middle) is a clean pull, and you get your breath back on
## the board; a good one costs a little grip; a miss skates your boots on
## the polished rock and costs a lot, and you don't move. Run out of grip and
## you back down to the foot. Reach the last board and you're on top.
##
## How busy the cables are depends on the hour (crowd_for): at dawn you have
## them to yourself and the green is wide; on a summer afternoon there's a
## line of hikers on them, you pull when they move, and the green is narrow
## and quick.
##
## The rules are in [method step] and [method press], so tests can play it
## without the keyboard. HalfDomeCables opens one and waits for finished.

signal finished(made_it: bool)

## Pulls from the foot of the cables to the top.
const BOARDS := 10
const PERFECT_SHARE := 0.4
## The crowd on the cables: the green's width, the marker's speed (bar
## lengths a second), and the line shown on the card.
const CROWDS := {
	"dawn": {"window": 0.32, "speed": 0.9, "note": "First light, and the cables to yourself"},
	"quiet": {"window": 0.25, "speed": 1.05, "note": "A quiet hour on the cables"},
	"crowded": {"window": 0.17, "speed": 1.35, "note": "A line of hikers on the cables: pull when they move"},
}
## Grip, from 1 (fresh) to 0 (spent): what each kind of stop does to it.
const GRIP := {"perfect": 0.04, "good": -0.07, "miss": -0.3}
## Sweeps across the bar before you have to move, which counts as a miss.
const MAX_PASSES := 6
const GRACE := 0.35
## How the card sits on screen, in UI pixels.
const CARD := Rect2(110, 46, 260, 150)
const ROCK := Color("b8a890")
const ROCK_DARK := Color("6e6458")
const CABLE := Color("c8ccd4")
const BOARD_WOOD := Color("8a6a44")

## "dawn", "quiet" or "crowded".
var crowd := "quiet"
## Boards climbed so far, and grip left.
var board := 0
var grip := 1.0
## How it ended: "summit", "backed_down" or "gave_up" ("" until it does).
var outcome := ""
var meter_pos := 0.0
var meter_dir := 1.0
var meter_center := 0.5
var meter_passes := 0
var last_stop := ""

var _grace := 0.0
var _flash := ""
var _flash_age := 9.0
var _rng := RandomNumberGenerator.new()
var _canvas: Control


## How busy the cables are at [param hour] in [param season] (GameClock):
## nobody at dawn, a line on late-spring and summer middays, quiet otherwise.
static func crowd_for(hour: float, season: int) -> String:
	if hour < 8.0:
		return "dawn"
	if season in [GameClock.Season.SPRING, GameClock.Season.SUMMER] and hour >= 10.0 and hour < 15.0:
		return "crowded"
	return "quiet"


func _ready() -> void:
	layer = 18
	UiScale.layer(self)
	_canvas = Control.new()
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw)
	add_child(_canvas)


## Starts at the foot with [param how_busy] (a key of CROWDS). [param seed]
## fixes where the green falls.
func start(how_busy: String, seed := -1) -> void:
	crowd = how_busy if CROWDS.has(how_busy) else "quiet"
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	board = 0
	grip = 1.0
	outcome = ""
	_begin_pull()


func window() -> float:
	return float(CROWDS[crowd].window)


## What a stop at [param pos] is: "perfect", "good" or "miss".
func judge(pos: float) -> String:
	var off := absf(pos - meter_center)
	var half := window() / 2.0
	if off <= half * PERFECT_SHARE:
		return "perfect"
	return "good" if off <= half else "miss"


## Stops the meter where the marker is now (a pull). Does nothing once it's
## over, or while the meter is still opening.
func press() -> void:
	if outcome != "" or _grace > 0.0:
		return
	_stop(judge(meter_pos))


## Moves the meter on by [param delta] seconds.
func step(delta: float) -> void:
	_flash_age += delta
	if outcome == "":
		if _grace > 0.0:
			_grace -= delta
		else:
			meter_pos += meter_dir * float(CROWDS[crowd].speed) * delta
			if meter_pos >= 1.0 or meter_pos <= 0.0:
				meter_pos = clampf(meter_pos, 0.0, 1.0)
				meter_dir = -meter_dir
				meter_passes += 1
				if meter_passes >= MAX_PASSES:
					_stop("miss")
	if _canvas:
		_canvas.queue_redraw()


func give_up() -> void:
	if outcome == "":
		_end("gave_up")


func _begin_pull() -> void:
	_grace = GRACE
	meter_pos = 0.0
	meter_dir = 1.0
	meter_passes = 0
	var half := window() / 2.0
	meter_center = _rng.randf_range(0.2 + half, 0.8 - half)


func _stop(result: String) -> void:
	last_stop = result
	grip = clampf(grip + float(GRIP[result]), 0.0, 1.0)
	_flash = {"perfect": "Clean pull!", "good": "Up a board", "miss": "Slipped!"}[result]
	_flash_age = 0.0
	Sound.play("item_get" if result == "perfect" else ("climb_move" if result == "good" else "ui_back"), -4.0, 0.08)
	if result != "miss":
		board += 1
	if board >= BOARDS:
		_end("summit")
	elif grip <= 0.0:
		_end("backed_down")
	else:
		_begin_pull()


func _end(how: String) -> void:
	outcome = how
	if _canvas:
		_canvas.queue_redraw()
	finished.emit(how == "summit")


func _process(delta: float) -> void:
	if outcome == "":
		step(delta)


func _input(event: InputEvent) -> void:
	if outcome != "":
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


## The card: the slope of the Dome on the left with its posts, boards and
## you on them, and on the right the grip left and the meter.
func _draw() -> void:
	var ci := _canvas
	ClimbUI.panel(ci, CARD)
	ClimbUI.ink(ci, Vector2(CARD.position.x + CARD.size.x / 2, CARD.position.y + 16), "THE CABLES", ClimbUI.GOLD, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ClimbUI.ink(ci, Vector2(CARD.position.x + CARD.size.x / 2, CARD.position.y + 30), CROWDS[crowd].note, ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_slope(Rect2(CARD.position.x + 12, CARD.position.y + 38, 92, 100))
	var right := CARD.position.x + 116
	var width := CARD.end.x - right - 12
	ClimbUI.ink(ci, Vector2(right, CARD.position.y + 50), "Board %d of %d" % [board, BOARDS], ClimbUI.CREAM, 9)
	ClimbUI.ink(ci, Vector2(right, CARD.position.y + 66), "Grip", ClimbUI.INK_SOFT, 8)
	ClimbUI.bar(ci, Rect2(right + 26, CARD.position.y + 60, width - 26, 7), grip, ClimbUI.GOOD if grip > 0.35 else ClimbUI.WARN, ClimbUI.GOOD_DARK)
	var bar := Rect2(right, CARD.position.y + 84, width, 12)
	ci.draw_rect(bar.grow(1), ClimbUI.WOOD_DARK)
	ci.draw_rect(bar, Color("5e4a38"))
	var win := window()
	ci.draw_rect(Rect2(bar.position.x + bar.size.x * (meter_center - win / 2.0), bar.position.y, bar.size.x * win, bar.size.y), ClimbUI.GOOD_DARK)
	var perfect_w := win * PERFECT_SHARE
	var perfect := Rect2(bar.position.x + bar.size.x * (meter_center - perfect_w / 2.0), bar.position.y, bar.size.x * perfect_w, bar.size.y)
	ci.draw_rect(perfect, ClimbUI.GOOD)
	ci.draw_rect(Rect2(perfect.position.x, perfect.position.y, perfect.size.x, 2), ClimbUI.GOOD.lightened(0.4))
	var mx := bar.position.x + bar.size.x * meter_pos
	ci.draw_rect(Rect2(mx - 1, bar.position.y - 4, 3, bar.size.y + 8), ClimbUI.WOOD_DARK)
	ci.draw_rect(Rect2(mx, bar.position.y - 3, 1, bar.size.y + 6), ClimbUI.CREAM)
	ClimbUI.ink(ci, Vector2(bar.position.x + bar.size.x / 2, bar.end.y + 14), "%s: pull in the green" % _use_button(), ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ClimbUI.ink(ci, Vector2(bar.position.x + bar.size.x / 2, bar.end.y + 28), "Esc: climb back down", ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if _flash_age < 1.1 and _flash != "":
		var col: Color = {"Clean pull!": ClimbUI.GOLD, "Up a board": ClimbUI.CREAM}.get(_flash, ClimbUI.WARN)
		ClimbUI.outlined(ci, Vector2(CARD.position.x + CARD.size.x / 2, CARD.end.y + 18 - _flash_age * 12.0), _flash, col, 14, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


## The back of the Dome rising left to right in [param r], the two cables
## on their posts, a board at each pair, the hikers ahead if it's busy, and
## you on the board you've reached.
func _draw_slope(r: Rect2) -> void:
	var ci := _canvas
	var foot := Vector2(r.position.x + 4, r.end.y - 6)
	var top := Vector2(r.end.x - 6, r.position.y + 8)
	var rock := PackedVector2Array([Vector2(r.position.x, r.end.y), foot + Vector2(-4, 0), top + Vector2(-4, -4),
		Vector2(r.end.x, r.position.y + 2), Vector2(r.end.x, r.end.y)])
	ci.draw_colored_polygon(rock, ROCK)
	ci.draw_polyline(PackedVector2Array([foot + Vector2(-4, 0), top + Vector2(-4, -4), Vector2(r.end.x, r.position.y + 2)]), ROCK_DARK, 1.0)
	var at := func(i: float) -> Vector2: return foot.lerp(top, i / BOARDS)
	for i in BOARDS + 1:
		var p: Vector2 = at.call(float(i))
		ci.draw_rect(Rect2(p + Vector2(-1, -7), Vector2(1, 7)), ROCK_DARK)
		ci.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 1)), BOARD_WOOD)
	ci.draw_line(foot + Vector2(-1, -7), top + Vector2(-1, -7), CABLE, 1.0)
	ci.draw_line(foot + Vector2(1, -6), top + Vector2(1, -6), CABLE.darkened(0.2), 1.0)
	if crowd == "crowded":
		for i in [board + 1.5, board + 3.0, board + 4.5]:
			if i < BOARDS:
				var h: Vector2 = at.call(i)
				ci.draw_rect(Rect2(h + Vector2(-1, -6), Vector2(3, 5)), Color("3a4466"))
				ci.draw_rect(Rect2(h + Vector2(-1, -8), Vector2(3, 2)), Color("e0ac7e"))
	var you: Vector2 = at.call(float(board))
	ci.draw_rect(Rect2(you + Vector2(-2, -8), Vector2(4, 7)), Color("1e1614"))
	ci.draw_rect(Rect2(you + Vector2(-1, -7), Vector2(2, 3)), Color("6a8a4a"))
	ci.draw_rect(Rect2(you + Vector2(-1, -10), Vector2(2, 2)), Color("f0c088"))
