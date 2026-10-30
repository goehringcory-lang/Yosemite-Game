class_name RescueLower
extends CanvasLayer
## Lowering someone off a climb on a rescue (Rescues): you're at the anchor
## and they hang on the rope below you, clipped in, all the way to the
## ground. Hold use to let the rope run through the brake and they go down,
## faster the longer you hold; let go to brake. The face has flakes and roofs
## on it (SNAGS): ease them past one slowly, or they bump into it and you
## have to stop and let them push off. Run the rope too fast for too long and
## the brake gets hot (HEAT) and locks until it cools.
##
## Nobody falls: a lower always reaches the ground, and how smooth it was
## ([member bumps]) is what you're told after. Cancel hands the rope to the
## team, who finish it.
##
## The rules are in [method step], so tests can lower without the keyboard.

signal finished

## How far down they are (0 at the anchor, 1 on the ground) a second, at
## most, and how quickly the speed builds while you hold and drops when you
## let go.
const MAX_SPEED := 0.16
const ACCEL := 0.22
const BRAKE := 0.5
## Over a snag, faster than this is a bump.
const SAFE_SPEED := 0.06
## Seconds stopped after a bump, while they push off the rock.
const BUMP_STOP := 0.9
## Above HOT_SPEED the brake heats up this much a second; below it, it cools.
## Full heat locks the rope for LOCK_TIME.
const HOT_SPEED := 0.12
const HEAT_RATE := 0.45
const COOL_RATE := 0.35
const LOCK_TIME := 1.4
## The face's snags, as [top, bottom] down the rope (0 to 1).
const SNAGS := [[0.22, 0.3], [0.48, 0.56], [0.74, 0.82]]
## On screen, in UI pixels: the card, and the strip of rock inside it.
const CARD := Rect2(140, 18, 200, 236)
const FACE := Rect2(156, 38, 100, 186)
const ROCK := Color("8a8478")
const ROCK_DARK := Color("5e594f")
const ROCK_LIGHT := Color("b4ad9c")
const ROPE := Color(0.702, 0.212, 0.169)
const LITTER := Color("d9772a")

## How far down they are, and how fast they're going.
var depth := 0.0
var speed := 0.0
var heat := 0.0
## Bumps into the rock so far.
var bumps := 0
var done := false
## True if you handed the rope to the team.
var handed_off := false
var route_name := ""

var _stopped := 0.0
var _locked := 0.0
## Snags already passed or bumped, so each one counts once.
var _cleared: Array[int] = []
var _flash := ""
var _flash_age := 9.0
var _canvas: Control


func _ready() -> void:
	layer = 18
	UiScale.layer(self)
	_canvas = Control.new()
	UiScale.fit(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw)
	add_child(_canvas)


func start(route: RouteData = null) -> void:
	route_name = route.display_name if route else ""
	depth = 0.0
	speed = 0.0
	heat = 0.0
	bumps = 0
	done = false
	handed_off = false
	_cleared = []
	Sound.play("climb_clip", -4.0, 0.1)


## Moves the lower on by [param delta] seconds, with use held or not.
func step(delta: float, holding: bool) -> void:
	if done:
		return
	_flash_age += delta
	_stopped = maxf(_stopped - delta, 0.0)
	_locked = maxf(_locked - delta, 0.0)
	var running := holding and _stopped <= 0.0 and _locked <= 0.0
	if running:
		speed = minf(speed + ACCEL * delta, MAX_SPEED)
	else:
		speed = maxf(speed - BRAKE * delta, 0.0)
	heat = clampf(heat + (HEAT_RATE if speed > HOT_SPEED else -COOL_RATE) * delta, 0.0, 1.0)
	if heat >= 1.0 and _locked <= 0.0:
		_locked = LOCK_TIME
		speed = 0.0
		_say("Brake's hot!")
		Sound.play("ui_back", -4.0, 0.05)
	depth = minf(depth + speed * delta, 1.0)
	var snag := snag_at(depth)
	if snag >= 0 and not snag in _cleared:
		if speed > SAFE_SPEED:
			_cleared.append(snag)
			bumps += 1
			speed = 0.0
			_stopped = BUMP_STOP
			_say("Bump!")
			Sound.play("climb_move", -2.0, 0.1)
		elif depth >= SNAGS[snag][1] - 0.02:
			_cleared.append(snag)
			_say("Clean")
			Sound.play("item_get", -8.0, 0.08)
	if depth >= 1.0:
		_end()
	if _canvas:
		_canvas.queue_redraw()


## The snag at [param at] (an index into SNAGS), or -1.
static func snag_at(at: float) -> int:
	for i in SNAGS.size():
		if at >= SNAGS[i][0] and at <= SNAGS[i][1]:
			return i
	return -1


## Hands the rope to the team, who finish the lower.
func hand_off() -> void:
	if done:
		return
	handed_off = true
	_end()


## What's said after: how it went.
func outcome_text() -> String:
	if handed_off:
		return "The team took the rope and finished the lower. Everyone's down safe."
	match bumps:
		0:
			return "A perfect lower: not one bump. Down safe on the ground."
		1:
			return "Down safe, with one bump on the way."
	return "Down safe, a little bruised from %d bumps on the way." % bumps


func _end() -> void:
	done = true
	finished.emit()


func _say(text: String) -> void:
	_flash = text
	_flash_age = 0.0


func _process(delta: float) -> void:
	step(delta, Input.is_action_pressed("interact") or Input.is_action_pressed("use_tool"))


func _input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hand_off()
	elif event.is_action("interact") or event.is_action("use_tool"):
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var ci := _canvas
	ClimbUI.glass(ci, Rect2(Vector2.ZERO, UiScale.SCREEN), 0.35)
	ClimbUI.panel(ci, CARD)
	ClimbUI.ink(ci, Vector2(CARD.position.x + CARD.size.x / 2, CARD.position.y + 14), "LOWER %s" % route_name.to_upper() if route_name != "" else "LOWER", ClimbUI.GOLD, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_face()
	_draw_gauges()
	var hint := "Hold %s: let rope run  ·  release: brake" % _use_button()
	ClimbUI.ink(ci, Vector2(CARD.position.x + CARD.size.x / 2, CARD.end.y - 8), hint, ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if _flash_age < 1.0 and _flash != "":
		var col: Color = ClimbUI.GOOD if _flash == "Clean" else ClimbUI.WARN
		ClimbUI.outlined(ci, Vector2(FACE.position.x + FACE.size.x / 2, FACE.position.y + 4 + (FACE.size.y - 26) * depth - _flash_age * 10.0), _flash, col, 12, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


## The rock: banded granite with cracks, the snags as overhanging flakes,
## the anchor and you at the top, the rope, and them on it.
func _draw_face() -> void:
	var ci := _canvas
	ci.draw_rect(FACE.grow(1), ClimbUI.WOOD_DARK)
	ci.draw_rect(FACE, ROCK)
	# granite: dark water streaks down the face, a speckle of feldspar and
	# hornblende, and a few long cracks
	var rng := RandomNumberGenerator.new()
	rng.seed = 1934
	for x: float in [10.0, 34.0, 71.0, 88.0]:
		var long := rng.randf_range(60.0, 150.0)
		ci.draw_rect(Rect2(FACE.position.x + x, FACE.position.y, rng.randi_range(3, 6), long), Color(ROCK_DARK, 0.35))
	for i in 220:
		var dot := Vector2(rng.randf_range(0.0, FACE.size.x - 1.0), rng.randf_range(0.0, FACE.size.y - 7.0)).floor()
		ci.draw_rect(Rect2(FACE.position + dot, Vector2.ONE), ROCK_LIGHT if rng.randf() < 0.55 else Color("3a3630"))
	for x: float in [18.0, 52.0, 94.0]:
		var top := FACE.position.y + fmod(x * 3.0, 40.0)
		ci.draw_line(Vector2(FACE.position.x + x, top), Vector2(FACE.position.x + x + 6, top + 60), Color("3a3630"), 1.0)
	# the ground at the foot
	ci.draw_rect(Rect2(FACE.position.x, FACE.end.y - 6, FACE.size.x, 6), Color("5a6a3a"))
	ci.draw_rect(Rect2(FACE.position.x, FACE.end.y - 6, FACE.size.x, 1), Color("84b04a"))
	var cx := FACE.position.x + FACE.size.x / 2
	for i in SNAGS.size():
		var top: float = FACE.position.y + FACE.size.y * SNAGS[i][0]
		var tall: float = FACE.size.y * (SNAGS[i][1] - SNAGS[i][0])
		var near: bool = absf(depth - SNAGS[i][0]) < 0.1 and not i in _cleared
		var flake := Rect2(cx - 4, top, 40, tall)
		ci.draw_rect(flake, ROCK_DARK)
		ci.draw_rect(Rect2(flake.position, Vector2(flake.size.x, 2)), ROCK_LIGHT)
		ci.draw_rect(Rect2(flake.position.x, flake.end.y - 2, flake.size.x, 2), Color("3a3630"))
		if near:
			ci.draw_rect(flake.grow(1), Color(ClimbUI.WARN, 0.5), false, 1.0)
	# the anchor, and you braced at it
	var anchor := Vector2(cx, FACE.position.y + 6)
	ci.draw_rect(Rect2(anchor - Vector2(3, 2), Vector2(6, 3)), Color("c8c8c8"))
	ci.draw_rect(Rect2(anchor.x - 12, anchor.y - 4, 4, 8), Color("6b7d4a"))
	ci.draw_rect(Rect2(anchor.x - 12, anchor.y - 8, 4, 4), Color("e0ac7e"))
	# the rope and them on it, swinging a little while they move
	var swing := sin(Time.get_ticks_msec() / 260.0) * 2.0 * minf(speed / MAX_SPEED, 1.0)
	var y := FACE.position.y + 10 + (FACE.size.y - 26) * depth
	var them := Vector2(cx + 20 + swing, y)
	ci.draw_line(anchor, them, ROPE, 1.0)
	ci.draw_rect(Rect2(them.x - 2, them.y, 5, 8), LITTER)
	ci.draw_rect(Rect2(them.x - 2, them.y - 4, 5, 4), Color("e0ac7e"))
	ci.draw_rect(Rect2(them.x - 3, them.y - 5, 7, 2), Color("3a86a8"))


## Beside the rock: how fast the rope's running (the safe speed over a
## flake marked) and how hot the brake is.
func _draw_gauges() -> void:
	var ci := _canvas
	var gx := FACE.end.x + 16
	var sbar := Rect2(gx, FACE.position.y + 20, 10, 120)
	ClimbUI.ink(ci, Vector2(gx + 5, sbar.position.y - 6), "speed", ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(sbar.grow(1), ClimbUI.WOOD_DARK)
	ci.draw_rect(sbar, Color("2a1b14"))
	var frac := speed / MAX_SPEED
	var fill := ClimbUI.GOOD if speed <= SAFE_SPEED else (ClimbUI.GOLD if speed <= HOT_SPEED else ClimbUI.WARN)
	ci.draw_rect(Rect2(sbar.position.x, sbar.end.y - sbar.size.y * frac, sbar.size.x, sbar.size.y * frac), fill)
	var safe_y := sbar.end.y - sbar.size.y * SAFE_SPEED / MAX_SPEED
	ci.draw_rect(Rect2(sbar.position.x - 3, safe_y, sbar.size.x + 6, 1), ClimbUI.CREAM)
	var hbar := Rect2(gx + 30, FACE.position.y + 20, 10, 120)
	ClimbUI.ink(ci, Vector2(hbar.position.x + 5, hbar.position.y - 6), "brake", ClimbUI.INK_SOFT, 8, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(hbar.grow(1), ClimbUI.WOOD_DARK)
	ci.draw_rect(hbar, Color("2a1b14"))
	ci.draw_rect(Rect2(hbar.position.x, hbar.end.y - hbar.size.y * heat, hbar.size.x, hbar.size.y * heat), Color("b3362b") if _locked > 0.0 else ClimbUI.WARN)
	ClimbUI.ink(ci, Vector2(gx + 20, sbar.end.y + 16), "bumps: %d" % bumps, ClimbUI.INK, 9, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


func _use_button() -> String:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud.interact_button() if hud and hud.has_method("interact_button") else "E"
