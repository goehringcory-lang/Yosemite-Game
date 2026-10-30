class_name TiltShift
extends CanvasLayer
## A gentle tilt-shift over the outdoor picture on High graphics
## (assets/shaders/tilt_shift.gdshader): the top and bottom of the screen go
## softly out of focus, like a camera looking down on a model, which is what
## makes a lit pixel-art world read as a diorama. It sits over the world and
## the atmosphere pass (both on layer 1, drawn before it) and under the HUD.
## Off indoors, where rooms are small enough to take in at a glance, and on
## Low graphics, whose renderer can't blur the screen.

const SHADER := preload("res://assets/shaders/tilt_shift.gdshader")

var _rect: ColorRect


func _ready() -> void:
	name = "TiltShift"
	layer = 1
	# a fresh copy of the screen, with the atmosphere pass in it
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = ShaderMaterial.new()
	(_rect.material as ShaderMaterial).shader = SHADER
	add_child(_rect)
	visible = false
	var world := get_parent()
	if world.has_signal("region_changed"):
		world.region_changed.connect(_on_region_changed)


func _on_region_changed(region: Region) -> void:
	visible = LitSprites.active() and not region.indoors
