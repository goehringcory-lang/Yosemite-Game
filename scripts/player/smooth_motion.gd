class_name SmoothMotion
extends Node
## Draws its parent (a walker that moves on the physics tick: the player, the
## townsfolk) between where it was on the last two ticks, so it glides every
## frame instead of stepping 60 times a second. Most screens draw faster than
## the tick, and the camera moves every frame, so a walker drawn where the
## tick left it stood still on some frames and jumped on others: the judder
## of walking about. Only the drawing moves; the body, its collisions and the
## doorways it walks into stay on the tick. A camera under the parent follows
## the drawn walker, not the ticked one.
##
## Moving the parent off the tick (a spawn, a door, a test) puts it straight
## there, with no glide.

var _parent: Node2D
var _camera: Camera2D
var _prev := Vector2.ZERO
var _cur := Vector2.ZERO


func _ready() -> void:
	name = "SmoothMotion"
	_parent = get_parent() as Node2D
	_camera = _parent.get_node_or_null("Camera") as Camera2D
	_prev = _parent.position
	_cur = _parent.position
	# draw before the camera looks for where to be this frame
	process_priority = -100


## The parent moved by [param by] along with everything around it (the world
## shifted under it, as across a seam between regions): it keeps gliding.
func shift(by: Vector2) -> void:
	_prev += by
	_cur += by


## Runs after the parent's own tick (a child ticks after its parent).
func _physics_process(_delta: float) -> void:
	_prev = _cur
	_cur = _parent.position


func _process(_delta: float) -> void:
	if _parent.position != _cur:
		# moved off the tick: no glide from where it was
		_prev = _parent.position
		_cur = _parent.position
	var drawn := _prev.lerp(_cur, Engine.get_physics_interpolation_fraction())
	RenderingServer.canvas_item_set_transform(_parent.get_canvas_item(),
			Transform2D(_parent.rotation, _parent.scale, _parent.skew, drawn))
	if _camera:
		_camera.position = drawn - _parent.position
