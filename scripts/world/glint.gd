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


## True while it twinkles, for tests.
func shining() -> bool:
	return _age >= 0.0


func _draw() -> void:
	if _age < 0.0:
		return
	# grows to a cross of light and shrinks back
	var t := _age / LENGTH
	var reach := roundf(sin(t * PI) * 3.0)
	var c := Color(1.0, 0.98, 0.88, 0.9)
	draw_rect(Rect2(-1, -1, 2, 2), c)
	if reach >= 1.0:
		draw_rect(Rect2(-1, -1 - reach, 2, reach), Color(c, 0.7))
		draw_rect(Rect2(-1, 1, 2, reach), Color(c, 0.7))
		draw_rect(Rect2(-1 - reach, -1, reach, 2), Color(c, 0.7))
		draw_rect(Rect2(1, -1, reach, 2), Color(c, 0.7))
