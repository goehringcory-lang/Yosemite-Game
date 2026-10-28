class_name FishingMinigame
extends CanvasLayer
## Playing a fish in, as in Stardew Valley: a tall bar of river beside you,
## the fish darting up and down it, and your rod's green band, which rises
## while you hold use and sinks when you let go. Keep the fish in the band
## and the line fills; let it slip and the line runs out. Fill it and the
## fish is yours; run it dry and it's gone. Cancel gives up.
##
## First you wait for a bite: the fly sits on the water a few seconds, then
## a "!" and the fish is on. The rules are in [method step], so tests can
## play it without the keyboard. Fishing opens one and waits for finished.

signal finished(caught: bool)

enum Phase { WAIT, REEL, DONE }

## Seconds before a fish takes the fly.
const BITE_WAIT := Vector2(1.2, 3.2)
## The band's height, as a share of the bar.
const BAND := 0.3
## How fast holding lifts the band, and how fast it falls.
const LIFT := 2.6
const GRAVITY := 2.0
## The line fills this much a second with the fish in the band, and runs out
## this much a second without.
const GAIN := 0.32
const LOSS := 0.22
const START_LINE := 0.35
## The bar on screen, in UI pixels.
const BAR := Rect2(372, 66, 22, 136)
const FRAME := Color("47301f")
const WOOD := Color("8a6a44")
const WATER_TOP := Color("4f8fa8")
const WATER_DEEP := Color("1f4a63")
const BAND_COLOR := Color(0.55, 0.85, 0.4, 0.75)
const LINE_COLOR := Color("f5d36a")
const FISH_COLOR := Color("d8c9a8")
const TEXT := Color("f5eee0")

var phase := Phase.WAIT
## The fish on the line (a Fishing.FISH entry).
var fish: Dictionary = {}
## Positions from 0 (bottom) to 1 (top): the band's bottom edge, the fish.
var band := 0.0
var band_speed := 0.0
var fish_at := 0.5
var line := START_LINE

var _wait := 2.0
var _target := 0.5
var _retarget := 0.0
var _rng := RandomNumberGenerator.new()
var _canvas: Control
var _label: Label


func _ready() -> void:
	layer = 18
	UiScale.layer(self)
	_canvas = Control.new()
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_bar)
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


## Casts for [param caught_fish]. [param seed] fixes the fish's moves.
func start(caught_fish: Dictionary, seed := -1) -> void:
	fish = caught_fish
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	phase = Phase.WAIT
	_wait = _rng.randf_range(BITE_WAIT.x, BITE_WAIT.y)
	band = 0.0
	band_speed = 0.0
	fish_at = 0.3
	_target = 0.5
	line = START_LINE
	if _label:
		_label.text = "Waiting for a bite..."
	Sound.play("slack_twang", -8.0, 0.1)


## Moves everything on by [param delta] seconds, with the use button held
## or not. Returns the phase it ends in.
func step(delta: float, holding: bool) -> Phase:
	match phase:
		Phase.WAIT:
			_wait -= delta
			if _wait <= 0.0:
				phase = Phase.REEL
				_label.text = "!  Hold %s to reel" % _use_button()
				Sound.play("climb_clip", 0.0, 0.1)
		Phase.REEL:
			_move_band(delta, holding)
			_move_fish(delta)
			var inside := fish_at >= band and fish_at <= band + BAND
			line = clampf(line + (GAIN if inside else -LOSS) * delta, 0.0, 1.0)
			if line >= 1.0 or line <= 0.0:
				phase = Phase.DONE
				finished.emit(line >= 1.0)
	if _canvas:
		_canvas.queue_redraw()
	return phase


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
		# held for the reel, not passed on to the world
		get_viewport().set_input_as_handled()


func give_up() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	finished.emit(false)


func _use_button() -> String:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud.interact_button() if hud and hud.has_method("interact_button") else "E"


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
		ci.draw_rect(Rect2(BAR.position.x + BAR.size.x / 2 - 2, BAR.position.y + 4 + bob, 4, 3), Color("c8502e"))
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
