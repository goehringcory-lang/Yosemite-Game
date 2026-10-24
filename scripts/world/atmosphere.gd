extends CanvasLayer
## Grades the outdoor picture (assets/shaders/atmosphere.gdshader): cool
## shadows, warm lights, a little body in the midtones and soft corners. Off
## indoors, where each room is painted with its own light, and in the regions
## listed in SKIP. It sits just above the world and below every menu.

const SKIP := ["tuolumne_meadows"]

var _rect: ColorRect


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/atmosphere.gdshader")
	_rect.material = mat
	add_child(_rect)
	visible = false
	var world := get_parent()
	if world.has_signal("region_changed"):
		world.region_changed.connect(_on_region_changed)


func _on_region_changed(region: Region) -> void:
	visible = not region.indoors and region.region_id not in SKIP
