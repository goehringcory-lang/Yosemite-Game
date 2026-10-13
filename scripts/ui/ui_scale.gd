class_name UiScale
extends RefCounted
## The world is drawn on a 32px grid in a 960x540 view, but every menu is laid
## out on the 480x270 screen it was designed for. Each UI CanvasLayer scales
## itself by FACTOR, so its layout, fonts and the 32px art in it keep their
## proportions, and its full-screen roots are SCREEN-sized instead of
## following the (twice as big) viewport.

const FACTOR := 2
## The screen as the menus see it, in UI pixels.
const SCREEN := Vector2(480, 270)


## Scales a UI layer to the menu coordinate system.
static func layer(canvas_layer: CanvasLayer) -> void:
	canvas_layer.scale = Vector2(FACTOR, FACTOR)


## Makes [param root] cover the whole menu screen.
static func fit(root: Control) -> void:
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.size = SCREEN


## Moves a layer's existing Control children (a scene built with anchors to
## the screen edges) under one SCREEN-sized root, so those anchors mean the
## menu screen. Returns the root.
static func wrap_children(canvas_layer: CanvasLayer) -> Control:
	var root := Control.new()
	root.name = "ScreenRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit(root)
	for child in canvas_layer.get_children():
		if child is Control:
			child.reparent(root, false)
	canvas_layer.add_child(root)
	canvas_layer.move_child(root, 0)
	return root


## Where a point in the 960x540 world view lands on the menu screen.
static func from_view(point: Vector2) -> Vector2:
	return point / FACTOR
