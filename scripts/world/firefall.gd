class_name Firefall
extends Node2D
## The Firefall at Camp Curry: embers pushed off Glacier Point's rim at 9 PM on
## summer nights, falling down the granite wall as a thin orange ribbon. It
## ran from the 1870s until January 25, 1968, and in the game's timeless
## valley it still does.
##
## The node sits at the rim (the top of the fall). It draws everything itself
## as whole pixels with additive blending, so nothing is blurred: a ribbon of
## falling embers that cool from white-gold to red, a faint wash of light on
## the wall, and a glow pool on the rim. Placed by the Curry Village story
## overlay (scenes/story/content/curry_village.tscn), and shown only while
## [method GameClock.is_firefall_time] is true.

const MESSAGE := "Someone calls up to the rim: 'Let the fire fall!'"
## How far the embers fall, in pixels. The granite wall is about 110 px tall; the
## rest runs down over the talus below it.
const LENGTH := 192.0
const SPAWN_RATE := 140.0
const MAX_EMBERS := 420
## Seconds the glow takes to build once the call has gone up, and to die away.
const FADE_IN := 2.5
const FADE_OUT := 3.5
## Seconds between the call and the first embers.
const CALL_DELAY := 2.2
## Ember colors from the rim to the foot of the fall.
const PALETTE := [Color(1.0, 0.86, 0.5), Color(1.0, 0.64, 0.2), Color(0.96, 0.42, 0.1), Color(0.8, 0.22, 0.06), Color(0.5, 0.1, 0.04)]

## 0 when dark, 1 at full strength.
var level := 0.0

var _embers: Array[Dictionary] = []
var _was_active := false
var _delay := 0.0
var _spawn_acc := 0.0
var _time := 0.0
var _tint: CanvasModulate
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_rng.seed = 1968
	z_index = -5 # in front of the wall and its falls, behind the trees and people
	visible = false


func _process(delta: float) -> void:
	var active := GameClock.is_firefall_time()
	if active and not _was_active:
		_delay = CALL_DELAY
		if is_inside_tree():
			get_tree().call_group("hud", "show_message", MESSAGE)
	_was_active = active
	var target := 0.0
	if active:
		_delay = maxf(_delay - delta, 0.0)
		target = 1.0 if _delay <= 0.0 else 0.0
	level = move_toward(level, target, delta / (FADE_IN if target > level else FADE_OUT))
	if active or level > 0.0 or not _embers.is_empty():
		_time += delta
		_step_embers(delta)
	visible = active or level > 0.0 or not _embers.is_empty()
	if not visible:
		return
	modulate = Color.WHITE.lerp(Color(1.7, 1.7, 1.7), _darkness())
	queue_redraw()


func _step_embers(delta: float) -> void:
	_spawn_acc += SPAWN_RATE * level * delta
	while _spawn_acc >= 1.0 and _embers.size() < MAX_EMBERS:
		_spawn_acc -= 1.0
		_embers.append({
			"x": _rng.randf_range(-4.0, 4.0),
			"y": _rng.randf_range(0.0, 4.0),
			"v": _rng.randf_range(52.0, 88.0),
			"drift": _rng.randf_range(-3.0, 3.0),
			"tall": _rng.randf() < 0.45,
		})
	_spawn_acc = minf(_spawn_acc, 1.0)
	for i in range(_embers.size() - 1, -1, -1):
		var ember := _embers[i]
		ember.v += 28.0 * delta
		ember.y += ember.v * delta
		ember.x += ember.drift * delta
		if ember.y >= LENGTH:
			_embers.remove_at(i)


func _draw() -> void:
	var flicker := 0.85 + 0.15 * sin(_time * 13.0) * sin(_time * 5.3 + 1.0)
	var glow := level * flicker
	if glow > 0.01:
		_draw_wall_wash(glow)
		_draw_rim_pool(glow)
	for ember in _embers:
		var t: float = ember.y / LENGTH
		var scaled := t * (PALETTE.size() - 1)
		var base: int = mini(int(scaled), PALETTE.size() - 2)
		var color: Color = PALETTE[base].lerp(PALETTE[base + 1], scaled - base)
		color.a = (1.0 - smoothstep(0.55, 1.0, t)) * minf(ember.y / 6.0, 1.0)
		var pos := _ribbon_at(ember.y) + Vector2(ember.x, 0.0)
		draw_rect(Rect2(Vector2(roundf(pos.x), roundf(pos.y)), Vector2(2, 4 if ember.tall else 2)), color)


## The ribbon sways a pixel or two as it falls.
func _ribbon_at(y: float) -> Vector2:
	return Vector2(sin(y * 0.035 + _time * 0.6) * 3.2, y)


## A faint light on the granite either side of the ribbon, in 8-pixel steps.
func _draw_wall_wash(glow: float) -> void:
	for step in int(LENGTH / 8.0):
		var y := step * 8.0
		var fade := (1.0 - y / LENGTH) * glow
		var cx := roundf(_ribbon_at(y).x)
		draw_rect(Rect2(cx - 10, y, 22, 8), Color(1.0, 0.45, 0.1, 0.14 * fade))
		draw_rect(Rect2(cx - 4, y, 10, 8), Color(1.0, 0.6, 0.2, 0.24 * fade))
	# Where the embers die away at the foot of the wall.
	draw_set_transform(Vector2(0, LENGTH), 0.0, Vector2(1.0, 0.3))
	for i in 3:
		draw_circle(Vector2.ZERO, 24.0 - i * 7.0, Color(1.0, 0.4, 0.1, 0.035 * glow))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The glow pool where the fire is pushed over the edge, in flat steps.
func _draw_rim_pool(glow: float) -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.25))
	for i in 5:
		var radius := 68.0 - i * 12.0
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55 + i * 0.07, 0.15 + i * 0.1, 0.17 * glow))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _darkness() -> float:
	if _tint == null:
		_tint = get_tree().root.find_child("DayNight", true, false) as CanvasModulate
		if _tint == null:
			return 1.0
	if not _tint.visible:
		return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.95 - lum) / 0.45, 0.0, 1.0)
