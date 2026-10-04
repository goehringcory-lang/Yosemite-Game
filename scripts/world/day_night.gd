extends CanvasModulate
## Tints the world based on the time of day. Edit the gradient in the
## Inspector: its left edge is midnight, the middle is noon.

@export var gradient: Gradient


func _process(_delta: float) -> void:
	if gradient:
		color = gradient.sample(GameClock.get_day_progress())
