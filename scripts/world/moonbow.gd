class_name Moonbow
extends Node2D
## A moonbow in the spray at the foot of Lower Yosemite Fall. On a spring night
## when the moon is full, the mist catches its light and a faint white arc
## forms. Moonbows are real here and well known, but dim: the eye sees mostly
## white, not color.
##
## Place it where the fall lands (the centre of the arc). It draws a pale arc in 2px cells (the art is drawn at 2x),
## additively, and shows only while
## [method GameClock.is_moonbow_time] is true.

## Seconds the arc takes to form and to fade.
const FADE_TIME := 4.0

## Radius of the arc in world pixels.
@export var radius := 60.0

## 0 when invisible, 1 at full strength.
var level := 0.0

var _time := 0.0
var _tint: CanvasModulate


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	z_index = 3
	visible = false


func _process(delta: float) -> void:
	var active := GameClock.is_moonbow_time()
	level = move_toward(level, 1.0 if active else 0.0, delta / FADE_TIME)
	visible = active or level > 0.0
	if not visible:
		return
	_time += delta
	modulate = Color.WHITE.lerp(Color(2.4, 2.4, 2.6), _darkness())
	queue_redraw()


func _draw() -> void:
	# The arc is laid out in 2px cells, in cell units (half the radius).
	var r := radius * 0.5
	var reach := int(r) + 5
	for px in range(-reach, reach + 1):
		for py in range(-reach, 3):
			var dist := Vector2(px, py).length()
			var off := absf(dist - r)
			if off > 3.5:
				continue
			var color := Color(0.96, 0.98, 1.0)
			var alpha := 0.0
			if off <= 1.0:
				alpha = 0.45
			elif off <= 2.2:
				if (px + py) % 2 == 0:
					continue # dithered, so the edge stays pixel art and never blurs
				alpha = 0.16
				color = Color(0.88, 0.88, 1.0) if dist < r else Color(1.0, 0.96, 0.9)
			else:
				if (px + py) % 4 != 0:
					continue
				alpha = 0.1
			# Brightest at the top of the arc, fading toward its feet.
			alpha *= 0.3 + 0.7 * smoothstep(2.0, -r * 0.45, float(py))
			alpha *= (0.82 + 0.18 * sin(_time * 1.1 + px * 0.12)) * level
			if alpha > 0.01:
				draw_rect(Rect2(px * 2, py * 2, 2, 2), Color(color.r, color.g, color.b, alpha))
	# A pale haze where the spray hangs.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	for i in 3:
		draw_circle(Vector2.ZERO, radius * 0.9 - i * 12.0, Color(0.9, 0.95, 1.0, 0.025 * level))
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
