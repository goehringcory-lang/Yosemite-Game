class_name FrameCycle
extends Sprite2D
## Plays a sprite sheet's frames in a loop: a flag in the breeze, a stove's
## flickering fire. Set hframes on the sprite and [member fps] here.

@export var fps := 3.0

var _time := 0.0


func _ready() -> void:
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	frame = int(_time * fps) % maxi(1, hframes * vframes)
