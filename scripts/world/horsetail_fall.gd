class_name HorsetailFall
extends Node2D
## Horsetail Fall, the thin ribbon of snowmelt that pours off El Capitan's east
## shoulder in winter, and its natural "firefall". On a few clear evenings in
## February the setting sun reaches the fall at just the right angle, and for
## ten minutes or so the water glows orange and red against the darkening
## granite, like fire pouring off the rim. Galen Rowell's 1973 photograph made
## it famous.
##
## The node sits at the lip of the fall, at the top of the dark streak the
## El Capitan wall painting shows there. It draws the water itself as whole
## pixels: a pale broken ribbon while Seasons.horsetail_running is true, and
## the lit fall (additive, so it glows through the dusk) while
## [method GameClock.is_horsetail_time] is. Placed by the El Capitan Meadow
## story overlay (scenes/story/content/el_capitan_meadow.tscn).

const MESSAGE := "The sun drops low and finds Horsetail Fall. For a few minutes the thin ribbon on El Capitan's east shoulder burns orange, like fire pouring off the rim."
## How far the water falls, in pixels, down the wall painting's streak.
const LENGTH := 184.0
## Seconds the light takes to come up on the fall, and to fade off it.
const FADE_IN := 4.0
const FADE_OUT := 5.0
## Lit water from the lip to the foot: gold where the sun hits it squarely,
## deepening to red as it falls into shadow.
const PALETTE := [Color(1.0, 0.88, 0.52), Color(1.0, 0.66, 0.24), Color(0.98, 0.44, 0.14), Color(0.86, 0.24, 0.08), Color(0.56, 0.12, 0.05)]

## 0 when unlit, 1 when the sun is full on the fall.
var level := 0.0

var _was_lit := false
var _time := 0.0
var _glow: Node2D
var _tint: CanvasModulate


func _ready() -> void:
	z_index = -7 # on the wall, like the other falls, behind the trees and people
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _process(delta: float) -> void:
	var lit := GameClock.is_horsetail_time()
	if lit and not _was_lit and is_inside_tree():
		get_tree().call_group("hud", "show_message", MESSAGE)
	_was_lit = lit
	level = move_toward(level, 1.0 if lit else 0.0, delta / (FADE_IN if lit else FADE_OUT))
	visible = Seasons.horsetail_running() or level > 0.0
	if not visible:
		return
	_time += delta
	_glow.visible = level > 0.0
	_glow.modulate = Color.WHITE.lerp(Color(1.6, 1.6, 1.6), _darkness())
	queue_redraw()
	_glow.queue_redraw()


## The water: a pale, broken ribbon of falling dashes, fading as the light
## takes it over.
func _draw() -> void:
	var alpha := 0.5 * (1.0 - level)
	if alpha <= 0.01:
		return
	for i in int(LENGTH / 4.0):
		var y := fposmod(i * 4.0 + _time * 46.0, LENGTH)
		if (i * 7) % 5 == 0:
			continue # gaps, so it reads as falling water
		var x := roundf(_ribbon_at(y))
		draw_rect(Rect2(x, roundf(y), 2, 4), Color(0.92, 0.96, 1.0, alpha * (1.0 - 0.5 * y / LENGTH)))


## The lit fall: a glowing ribbon with a wash of light on the wall either side.
func _draw_glow() -> void:
	var flicker := 0.9 + 0.1 * sin(_time * 7.0) * sin(_time * 2.3 + 1.0)
	var glow := level * flicker
	for step in int(LENGTH / 8.0):
		var y := step * 8.0
		var cx := roundf(_ribbon_at(y))
		var fade := 1.0 - 0.55 * y / LENGTH
		_glow.draw_rect(Rect2(cx - 12, y, 26, 8), Color(1.0, 0.4, 0.1, 0.1 * fade * glow))
		_glow.draw_rect(Rect2(cx - 6, y, 14, 8), Color(1.0, 0.5, 0.14, 0.18 * fade * glow))
	for i in int(LENGTH / 2.0):
		var y := i * 2.0
		var t := y / LENGTH
		var scaled := t * (PALETTE.size() - 1)
		var base: int = mini(int(scaled), PALETTE.size() - 2)
		var color: Color = PALETTE[base].lerp(PALETTE[base + 1], scaled - base)
		# Brighter streaks running down the ribbon, as the water catches the sun.
		var shimmer := 0.7 + 0.3 * sin(y * 0.4 - _time * 9.0)
		color.a = glow * shimmer * (1.0 - 0.4 * t)
		_glow.draw_rect(Rect2(roundf(_ribbon_at(y)) - 2, y, 6, 2), Color(color, color.a * 0.55))
		_glow.draw_rect(Rect2(roundf(_ribbon_at(y)), y, 2, 2), color)
	# Where the light catches the spray at the foot of the fall.
	_glow.draw_set_transform(Vector2(_ribbon_at(LENGTH), LENGTH), 0.0, Vector2(1.0, 0.4))
	for i in 3:
		_glow.draw_circle(Vector2.ZERO, 16.0 - i * 5.0, Color(1.0, 0.36, 0.1, 0.05 * glow))
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The fall wavers a pixel or two down the wall, with the breeze.
func _ribbon_at(y: float) -> float:
	return sin(y * 0.05 + _time * 0.5) * 1.6 + y * 0.02


func _darkness() -> float:
	if _tint == null:
		_tint = get_tree().root.find_child("DayNight", true, false) as CanvasModulate
		if _tint == null:
			return 0.0
	if not _tint.visible:
		return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.9 - lum) / 0.45, 0.0, 1.0)
