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
##
## A light carried by the parent (the player's Lantern) glides too. A Light2D
## hands the renderer its own place in the world rather than following its
## parent's drawing, so without this the pool of lantern light stepped on
## the tick while the player glided through it.

var _parent: Node2D
var _camera: Camera2D
var _prev := Vector2.ZERO
var _cur := Vector2.ZERO
## The parent's lights (direct children), kept as they come and go.
var _lights: Array[Light2D] = []
## The glide each light was last moved by (see _glide_lights).
var _light_offsets := {}


func _ready() -> void:
	name = "SmoothMotion"
	_parent = get_parent() as Node2D
	_camera = _parent.get_node_or_null("Camera") as Camera2D
	_prev = _parent.position
	_cur = _parent.position
	# draw before the camera looks for where to be this frame
	process_priority = -100
	for child in _parent.get_children():
		_on_child_entered(child)
	_parent.child_entered_tree.connect(_on_child_entered)
	_parent.child_exiting_tree.connect(_on_child_exiting)


func _on_child_entered(child: Node) -> void:
	if child is Light2D and not _lights.has(child):
		_lights.append(child)


func _on_child_exiting(child: Node) -> void:
	if child is Light2D:
		_lights.erase(child)
		_light_offsets.erase(child)


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
	var local := Transform2D(_parent.rotation, _parent.scale, _parent.skew, drawn)
	RenderingServer.canvas_item_set_transform(_parent.get_canvas_item(), local)
	if _camera:
		_camera.position = drawn - _parent.position
	if not _lights.is_empty():
		_glide_lights(_parent.transform.affine_inverse().basis_xform(drawn - _parent.position))


## Moves each light by [param off] (the glide, in the parent's own frame) so
## its pool of light sits on the drawn parent. Its drawing (and anything under
## it, like a lamp's halo) already follows the drawn parent, so that stays
## where the light was placed.
func _glide_lights(off: Vector2) -> void:
	for light in _lights:
		if not is_instance_valid(light):
			continue
		var base: Vector2 = light.position - (_light_offsets.get(light, Vector2.ZERO) as Vector2)
		light.position = base + off
		_light_offsets[light] = off
		RenderingServer.canvas_item_set_transform(light.get_canvas_item(),
				Transform2D(light.rotation, light.scale, light.skew, base))
