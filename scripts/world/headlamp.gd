class_name Headlamp
extends Node2D
## A climber's headlamp left on a ledge, glowing from midnight to 4 AM: a
## couple of bright pixels and a small cool-white light. Added to the Midnight
## Lightning boulder at Camp 4 by EasterEggs.

const FROM_HOUR := 0
const TO_HOUR := 4

var _light: NightLight


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_light = NightLight.new()
	_light.strength = 0.6
	_light.radius = 14.0
	_light.lit_hours = Vector2i(FROM_HOUR, TO_HOUR)
	add_child(_light)
	_light.color = Color(0.86, 0.95, 1.0) # a white LED, cooler than the lanterns
	visible = false


func _process(_delta: float) -> void:
	visible = GameClock.hour_in_range(FROM_HOUR, TO_HOUR)


func _draw() -> void:
	draw_rect(Rect2(-1, -1, 2, 1), Color(3.0, 3.0, 3.0, 1.0))
	draw_rect(Rect2(-2, 0, 4, 1), Color(1.5, 1.8, 2.1, 0.8))
