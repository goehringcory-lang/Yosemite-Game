class_name Glint
extends Node2D
## Now and then a find on the ground catches the light: a four-point twinkle
## at its corner, a quarter of a second long, every few seconds. It tells a
## berry or an acorn worth picking up from the ground art around it without
## a marker. Forageable adds one, except in the Low graphics setting.

## Seconds between twinkles (with a little give), and how long one lasts.
const EVERY := 4.5
const LENGTH := 0.28

var _wait := 0.0
var _age := -1.0


func _ready() -> void:
	name = "Glint"
	# out of step with its neighbors
	_wait = randf() * EVERY
	z_index = 1


func _process(delta: float) -> void:
	if _age >= 0.0:
		_age += delta
		if _age >= LENGTH:
			_age = -1.0
			_wait = EVERY * (0.7 + randf() * 0.6)
		queue_redraw()
		return
	_wait -= delta
	if _wait <= 0.0:
		_age = 0.0
		queue_redraw()


func _draw() -> void:
	if _age < 0.0:
		return
	# grows to a sparkling golden-white star and shrinks back
	var t := _age / LENGTH
	var reach := roundf(sin(t * PI) * 3.0)
	var core := Color(1.0, 0.99, 0.92, 0.95)
	var gold := Color(1.0, 0.88, 0.54, 0.72)
	draw_rect(Rect2(-1, -1, 2, 2), core)
	if reach >= 1.0:
		draw_rect(Rect2(-1, -1 - reach, 2, reach), gold)
		draw_rect(Rect2(-1, 1, 2, reach), gold)
		draw_rect(Rect2(-1 - reach, -1, reach, 2), gold)
		draw_rect(Rect2(1, -1, reach, 2), gold)
	if reach >= 2.0:
		var halo := Color(1.0, 0.92, 0.62, 0.45)
		for d in [Vector2(-2, -2), Vector2(1, -2), Vector2(-2, 1), Vector2(1, 1)]:
			draw_rect(Rect2(d, Vector2(1, 1)), halo)
