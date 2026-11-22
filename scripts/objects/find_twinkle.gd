class_name FindTwinkle
extends Node2D
## A hidden find's tell (FindSpot): a small cool blue-white twinkle, slower and
## rarer than a forage find's gold Glint, so a sharp eye learns the
## difference.

const EVERY := 7.0
const LENGTH := 0.5

var _wait := 0.0
var _age := -1.0


func _ready() -> void:
	name = "Twinkle"
	_wait = randf() * EVERY
	z_index = 1


func _process(delta: float) -> void:
	if _age >= 0.0:
		_age += delta
		if _age >= LENGTH:
			_age = -1.0
			var base := EVERY * 0.55 if Perks.has("botanists_glint") else EVERY
			_wait = base * (0.8 + randf() * 0.5)
		queue_redraw()
		return
	_wait -= delta
	if _wait <= 0.0:
		_age = 0.0
		queue_redraw()


func _draw() -> void:
	if _age < 0.0:
		return
	var t := _age / LENGTH
	var max_reach := 3.0 if Perks.has("botanists_glint") else 2.0
	var reach := roundf(sin(t * PI) * max_reach)
	var core := Color(0.92, 0.97, 1.0, 0.9)
	var blue := Color(0.62, 0.8, 1.0, 0.6)
	draw_rect(Rect2(0, 0, 1, 1), core)
	if reach >= 1.0:
		draw_rect(Rect2(0, -reach, 1, reach), blue)
		draw_rect(Rect2(0, 1, 1, reach), blue)
		draw_rect(Rect2(-reach, 0, reach, 1), blue)
		draw_rect(Rect2(1, 0, reach, 1), blue)
