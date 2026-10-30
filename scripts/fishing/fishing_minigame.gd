class_name FishingMinigame
extends CanvasLayer
## Fly fishing, in two parts: the cast, then the fish.
##
## The cast is two stops on a timing meter, like a crux on the climbing
## screen: a marker sweeps a bar and you stop it in the green, once for the
## back cast and once for the forward cast. Each stop is perfect (the green's
## bright middle), good (the rest of the green) or a miss. A missed back cast
## hangs the fly in the willows behind you; a missed forward cast slaps the
## line down in a heap and spooks the pool. Otherwise the two stops decide
## whether anything rises: two perfect casts always bring a fish up, and set
## the hook hard, so the line starts well along; two good ones only
## sometimes do (BITE_CHANCE). The fly you have tied on (Fishing.FLIES)
## widens the green, brings fish up more often and sets the hook harder.
##
## Then, if a fish takes the fly, you play it in as in Stardew Valley: a tall
## bar of river beside you, the fish darting up and down it, and your rod's
## green band, which rises while you hold use and sinks when you let go. Keep
## the fish in the band and the line fills; let it slip and the line runs
## out. Fill it and the fish is yours; run it dry and it's gone. Cancel gives
## up at any point.
##
## The rules are in [method step] and [method press], so tests can play it
## without the keyboard. Fishing opens one and waits for finished, then reads
## [member outcome] to say what happened.

signal finished(caught: bool)

enum Phase { BACK_CAST, FORWARD_CAST, WAIT, REEL, DONE }

## The cast meter: the green's width (a share of the bar), the share of the
## green in the middle that's perfect, and how fast the marker sweeps (bar
## lengths a second) on the back cast and on the quicker forward cast.
const WINDOW := 0.26
const PERFECT_SHARE := 0.4
const BACK_SPEED := 1.05
const FORWARD_SPEED := 1.35
## Sweeps across the bar before the line drops, which counts as a miss.
const MAX_PASSES := 6
## Seconds the meter waits when it opens, and while the line unrolls behind
## you before the forward cast, so one press can't spend two stops.
const GRACE := 0.3
const UNROLL := 0.45
## Points for a stop.
const POINTS := {"perfect": 2, "good": 1, "miss": 0}
## The chance something rises, by the two casts' points added up (0 to 4).
## A missed stop never gets this far.
const BITE_CHANCE := [0.0, 0.0, 0.4, 0.7, 1.0]
## How much line is out when the hook sets, by the casts' points: a clean
## cast sets it hard and the reel starts well along.
const HOOK_SET := [0.3, 0.3, 0.3, 0.42, 0.55]
## Seconds before a fish takes the fly (a perfect pair of casts, sooner), and
## how long the fly drifts before you give up on a cast nothing rose to.
const BITE_WAIT := Vector2(1.2, 3.2)
const DRIFT := 2.4
## The band's height, as a share of the bar.
const BAND := 0.3
## How fast holding lifts the band, and how fast it falls.
const LIFT := 2.6
const GRAVITY := 2.0
## The line fills this much a second with the fish in the band, and runs out
## this much a second without.
const GAIN := 0.32
const LOSS := 0.22
## The reel's bar on screen, in UI pixels, and the cast meter's card.
const BAR := Rect2(372, 66, 22, 136)
const CARD := Rect2(130, 52, 220, 78)
const FRAME := Color("47301f")
const WOOD := Color("8a6a44")
const WATER_TOP := Color("4f8fa8")
const WATER_DEEP := Color("1f4a63")
const BAND_COLOR := Color(0.55, 0.85, 0.4, 0.75)
const LINE_COLOR := Color("f5d36a")
const FISH_COLOR := Color("d8c9a8")
const FLY_COLOR := Color("c8502e")
const TEXT := Color("f5eee0")

var phase := Phase.BACK_CAST
## The fish that will rise to a good cast (a Fishing.FISH entry), and the fly
## tied on (a Fishing.FLIES entry, or {} for the rod's plain fly).
var fish: Dictionary = {}
var fly: Dictionary = {}
## How the two stops went: "perfect", "good" or "miss" ("" until made).
var back_cast := ""
var forward_cast := ""
## Whether a fish rises to this cast (decided on the forward cast).
var rises := false
## How it ended: "caught", "lost" (it threw the hook), "snagged" (a missed
## back cast), "spooked" (a missed forward cast), "no_rise" or "gave_up".
var outcome := ""
## The cast meter: where the marker is (0 to 1), which way it's going, the
## middle of the green, and how many times it has crossed the bar.
var meter_pos := 0.0
var meter_dir := 1.0
var meter_center := 0.5
var meter_passes := 0
## Positions from 0 (bottom) to 1 (top): the band's bottom edge, the fish.
var band := 0.0
var band_speed := 0.0
var fish_at := 0.5
var line := 0.3

var _grace := 0.0
var _wait := 2.0
var _target := 0.5
var _retarget := 0.0
## The word that pops up over the meter after a stop ("PERFECT!"), and its age.
var _flash := ""
var _flash_age := 9.0
var _rng := RandomNumberGenerator.new()
var _canvas: Control
var _label: Label


func _ready() -> void:
	layer = 18
	UiScale.layer(self)
	_canvas = Control.new()
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw)
	add_child(_canvas)
	_label = Label.new()
	_label.position = Vector2(BAR.position.x - 70, BAR.end.y + 8)
	_label.custom_minimum_size = Vector2(162, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", TEXT)
	var card := StyleBoxFlat.new()
	card.bg_color = Color(FRAME, 0.85)
	card.set_content_margin_all(2)
	_label.add_theme_stylebox_override("normal", card)
	_canvas.add_child(_label)
	_show_label()


## Casts for [param caught_fish] with [param tied_fly] on. [param seed] fixes
## the meter, the rise and the fish's moves.
func start(caught_fish: Dictionary, seed := -1, tied_fly := {}) -> void:
	fish = caught_fish
	fly = tied_fly
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	back_cast = ""
	forward_cast = ""
	rises = false
	outcome = ""
	band = 0.0
	band_speed = 0.0
	fish_at = 0.3
	_target = 0.5
	_begin_cast(Phase.BACK_CAST)
	Sound.play("slack_twang", -8.0, 0.1)


## The green's width with the fly tied on.
func window() -> float:
	return WINDOW + float(fly.get("window", 0.0))


## Points for the two casts so far (0 to 4).
func cast_points() -> int:
	return int(POINTS.get(back_cast, 0)) + int(POINTS.get(forward_cast, 0))


## The chance something rises to a cast worth [param points], with the fly.
func bite_chance(points: int) -> float:
	var chance: float = BITE_CHANCE[clampi(points, 0, 4)]
	if chance <= 0.0:
		return 0.0
	return minf(1.0, chance + float(fly.get("bite", 0.0)))


## What a stop at [param pos] is: "perfect", "good" or "miss".
func judge(pos: float) -> String:
	var off := absf(pos - meter_center)
	var half := window() / 2.0
	if off <= half * PERFECT_SHARE:
		return "perfect"
	return "good" if off <= half else "miss"


## Stops the cast meter where the marker is now. Does nothing outside the
## cast, or while the meter is still opening.
func press() -> void:
	if (phase != Phase.BACK_CAST and phase != Phase.FORWARD_CAST) or _grace > 0.0:
		return
	_stop(judge(meter_pos))


## Moves everything on by [param delta] seconds, with the use button held
## or not. Returns the phase it ends in.
func step(delta: float, holding: bool) -> Phase:
	_flash_age += delta
	match phase:
		Phase.BACK_CAST, Phase.FORWARD_CAST:
			if _grace > 0.0:
				_grace -= delta
			else:
				_sweep(delta)
		Phase.WAIT:
			_wait -= delta
			if _wait <= 0.0:
				if rises:
					phase = Phase.REEL
					line = minf(0.9, HOOK_SET[cast_points()] + float(fly.get("hook", 0.0)))
					Sound.play("climb_clip", 0.0, 0.1)
				else:
					_end("no_rise", false)
			_show_label()
		Phase.REEL:
			_move_band(delta, holding)
			_move_fish(delta)
			var inside := fish_at >= band and fish_at <= band + BAND
			line = clampf(line + (GAIN if inside else -LOSS) * delta, 0.0, 1.0)
			if line >= 1.0 or line <= 0.0:
				_end("caught" if line >= 1.0 else "lost", line >= 1.0)
	if _canvas:
		_canvas.queue_redraw()
	return phase


func _begin_cast(which: Phase) -> void:
	phase = which
	_grace = GRACE if which == Phase.BACK_CAST else UNROLL
	meter_pos = 0.0
	meter_dir = 1.0
	meter_passes = 0
	# the green sits somewhere new each time, never hard against an end
	var half := window() / 2.0
	meter_center = _rng.randf_range(0.2 + half, 0.8 - half) if half < 0.3 else 0.5
	_show_label()


func _sweep(delta: float) -> void:
	var speed := BACK_SPEED if phase == Phase.BACK_CAST else FORWARD_SPEED
	meter_pos += meter_dir * speed * delta
	if meter_pos >= 1.0 or meter_pos <= 0.0:
		meter_pos = clampf(meter_pos, 0.0, 1.0)
		meter_dir = -meter_dir
		meter_passes += 1
		# you can't hold a loop of line in the air all day
		if meter_passes >= MAX_PASSES:
			_stop("miss")


func _stop(result: String) -> void:
	_flash = {"perfect": "PERFECT!", "good": "Good", "miss": "Missed!"}[result]
	_flash_age = 0.0
	Sound.play("item_get" if result == "perfect" else ("climb_move" if result == "good" else "ui_back"), -4.0, 0.08)
	if phase == Phase.BACK_CAST:
		back_cast = result
		if result == "miss":
			_end("snagged", false)
		else:
			_begin_cast(Phase.FORWARD_CAST)
		return
	forward_cast = result
	if result == "miss":
		_end("spooked", false)
		return
	var points := cast_points()
	rises = _rng.randf() < bite_chance(points)
	phase = Phase.WAIT
	if rises:
		# a fish already looking up takes a clean cast quickly
		_wait = _rng.randf_range(BITE_WAIT.x, BITE_WAIT.y) * (0.5 if points >= 4 else 1.0)
	else:
		_wait = DRIFT
	Sound.play("slack_twang", -8.0, 0.1)
	_show_label()


func _end(how: String, caught: bool) -> void:
	outcome = how
	phase = Phase.DONE
	finished.emit(caught)


func _move_band(delta: float, holding: bool) -> void:
	band_speed += (LIFT if holding else -GRAVITY) * delta
	band_speed = clampf(band_speed, -1.2, 1.2)
	band += band_speed * delta
	if band <= 0.0 or band >= 1.0 - BAND:
		band = clampf(band, 0.0, 1.0 - BAND)
		band_speed *= -0.3


## The fish heads for a new depth every so often; a fighter picks farther
## ones, more often, and gets there faster. Feeling the rod, it pulls away
## from the band, so letting the band rest on the bottom won't land it.
func _move_fish(delta: float) -> void:
	var fight: float = fish.get("fight", 0.5)
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = _rng.randf_range(0.5, 1.6) * (1.3 - fight)
		var reach := 0.15 + 0.6 * fight
		var step := _rng.randf_range(-reach, reach)
		if fish_at >= band and fish_at <= band + BAND:
			step = absf(step) * (1.0 if fish_at >= band + BAND / 2.0 else -1.0)
			if band <= 0.01:
				step = absf(step) + 0.2
		_target = clampf(fish_at + step, 0.05, 0.95)
	fish_at = move_toward(fish_at, _target, (0.25 + 0.9 * fight) * delta)


func _process(delta: float) -> void:
	if phase != Phase.DONE:
		step(delta, Input.is_action_pressed("interact") or Input.is_action_pressed("use_tool"))


func _input(event: InputEvent) -> void:
	if phase == Phase.DONE:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		give_up()
	elif event.is_action("interact") or event.is_action("use_tool"):
		# a stop on the meter, or held for the reel; not passed on to the world
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("interact") or event.is_action_pressed("use_tool"):
			press()


func give_up() -> void:
	if phase == Phase.DONE:
		return
	_end("gave_up", false)


func _show_label() -> void:
	if _label == null:
		return
	_label.visible = phase == Phase.WAIT or phase == Phase.REEL
	if phase == Phase.WAIT:
		_label.text = "The fly drifts..." if forward_cast != "" else "Waiting for a bite..."
	elif phase == Phase.REEL:
		_label.text = "!  Hold %s to reel" % _use_button()


func _use_button() -> String:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud.interact_button() if hud and hud.has_method("interact_button") else "E"


func _draw() -> void:
	if phase == Phase.BACK_CAST or phase == Phase.FORWARD_CAST:
		_draw_meter()
	elif phase == Phase.WAIT or phase == Phase.REEL:
		_draw_bar()
	_draw_flash()


## The cast card: which cast it is, a little angler with the line laid out
## behind or ahead, and the meter with its green and bright perfect middle.
func _draw_meter() -> void:
	var ci := _canvas
	ClimbUI.panel(ci, CARD)
	var back := phase == Phase.BACK_CAST
	var title := "BACK CAST" if back else "FORWARD CAST"
	ClimbUI.ink(ci, Vector2(CARD.position.x + CARD.size.x / 2, CARD.position.y + 16), title, ClimbUI.GOLD, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if not back:
		ClimbUI.ink(ci, Vector2(CARD.end.x - 10, CARD.position.y + 16), "back: " + back_cast, ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_caster(Vector2(CARD.position.x + 22, CARD.position.y + 44), back)
	var bar := Rect2(CARD.position.x + 44, CARD.position.y + 30, CARD.size.x - 58, 12)
	ci.draw_rect(bar.grow(1), ClimbUI.WOOD_DARK)
	ci.draw_rect(bar, Color("5e4a38"))
	var win := window()
	var good := Rect2(bar.position.x + bar.size.x * (meter_center - win / 2.0), bar.position.y, bar.size.x * win, bar.size.y)
	ci.draw_rect(good, ClimbUI.GOOD_DARK)
	var perfect_w := win * PERFECT_SHARE
	var perfect := Rect2(bar.position.x + bar.size.x * (meter_center - perfect_w / 2.0), bar.position.y, bar.size.x * perfect_w, bar.size.y)
	ci.draw_rect(perfect, ClimbUI.GOOD)
	ci.draw_rect(Rect2(perfect.position.x, perfect.position.y, perfect.size.x, 2), ClimbUI.GOOD.lightened(0.4))
	var mx := bar.position.x + bar.size.x * meter_pos
	ci.draw_rect(Rect2(mx - 1, bar.position.y - 4, 3, bar.size.y + 8), ClimbUI.WOOD_DARK)
	ci.draw_rect(Rect2(mx, bar.position.y - 3, 1, bar.size.y + 6), ClimbUI.CREAM)
	var hint := "%s: stop in the green" % _use_button()
	if fly.has("name"):
		hint += "  ·  %s" % fly.name
	ClimbUI.ink(ci, Vector2(bar.position.x + bar.size.x / 2, CARD.end.y - 14), hint, ClimbUI.INK_SOFT, 9, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


## A stick of an angler with the rod up: the line loops out behind on the
## back cast and ahead on the forward cast, unrolling as the marker sweeps.
func _draw_caster(feet: Vector2, back: bool) -> void:
	var ci := _canvas
	ci.draw_rect(Rect2(feet.x - 2, feet.y - 12, 4, 8), Color("6a7a4a"))
	ci.draw_rect(Rect2(feet.x - 2, feet.y - 4, 4, 4), Color("4a4038"))
	ci.draw_rect(Rect2(feet.x - 2, feet.y - 16, 4, 4), Color("e0ac7e"))
	ci.draw_rect(Rect2(feet.x - 3, feet.y - 17, 6, 2), Color("7a7a5a"))
	var hand := feet + Vector2(2, -10)
	var tip := hand + (Vector2(-7, -12) if back else Vector2(9, -10))
	ci.draw_line(hand, tip, Color("8a5a2e"), 1.0)
	var reach := 6.0 + 10.0 * (meter_pos if meter_dir > 0.0 else 1.0 - meter_pos)
	var end := tip + Vector2(-reach if back else reach, 2.0)
	ci.draw_line(tip, end, LINE_COLOR, 1.0)
	ci.draw_rect(Rect2(end - Vector2(1, 1), Vector2(2, 2)), FLY_COLOR)


## "PERFECT!", "Good" or "Missed!" rising over the card after a stop.
func _draw_flash() -> void:
	if _flash_age > 1.1 or _flash == "":
		return
	var col: Color = {"PERFECT!": ClimbUI.GOLD, "Good": ClimbUI.CREAM}.get(_flash, ClimbUI.WARN)
	ClimbUI.outlined(_canvas, Vector2(CARD.position.x + CARD.size.x / 2, CARD.end.y + 18 - _flash_age * 12.0), _flash, col, 14, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_bar() -> void:
	var ci := _canvas
	var frame := BAR.grow(3)
	ci.draw_rect(frame.grow(1), FRAME)
	ci.draw_rect(frame, WOOD)
	# the river, lighter at the top
	var steps := 10
	for i in steps:
		var y := BAR.position.y + BAR.size.y * i / steps
		ci.draw_rect(Rect2(BAR.position.x, y, BAR.size.x, ceilf(BAR.size.y / steps)), WATER_TOP.lerp(WATER_DEEP, float(i) / (steps - 1)))
	if phase == Phase.WAIT:
		# the fly on the surface, bobbing
		var bob := sin(Time.get_ticks_msec() / 220.0) * 1.5
		ci.draw_rect(Rect2(BAR.position.x + BAR.size.x / 2 - 2, BAR.position.y + 4 + bob, 4, 3), FLY_COLOR)
		return
	var band_rect := Rect2(BAR.position.x + 1, _y(band + BAND), BAR.size.x - 2, BAR.size.y * BAND)
	ci.draw_rect(band_rect, BAND_COLOR)
	ci.draw_rect(Rect2(band_rect.position, Vector2(band_rect.size.x, 1)), Color(1, 1, 1, 0.5))
	# the fish: a little body and tail
	var fy := _y(fish_at)
	var fx := BAR.position.x + BAR.size.x / 2
	ci.draw_rect(Rect2(fx - 5, fy - 2, 8, 4), FISH_COLOR)
	ci.draw_rect(Rect2(fx + 3, fy - 3, 3, 6), FISH_COLOR)
	ci.draw_rect(Rect2(fx - 4, fy - 1, 1, 1), Color("15141c"))
	# how much line is left, beside the bar
	var meter := Rect2(BAR.end.x + 6, BAR.position.y, 5, BAR.size.y)
	ci.draw_rect(meter.grow(1), FRAME)
	ci.draw_rect(meter, Color("2a1f1a"))
	ci.draw_rect(Rect2(meter.position.x, meter.end.y - meter.size.y * line, meter.size.x, meter.size.y * line), LINE_COLOR)


## Screen y for a position up the bar.
func _y(at: float) -> float:
	return BAR.end.y - BAR.size.y * at
