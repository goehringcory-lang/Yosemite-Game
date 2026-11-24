extends Sprite2D
## A warm additive glow (lit windows, lanterns) that fades in at dusk and out
## at dawn. The world's night tint would dim it with everything else, so it
## is drawn extra bright to stay visible.

@export var strength := 1.0

static var _add_mat: CanvasItemMaterial
var _last_night := -1.0


func _ready() -> void:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _add_mat
	modulate = Color(3, 3, 3, 0)
	visible = false


func _process(_delta: float) -> void:
	var t := Sun.gradient_progress()
	var evening := smoothstep(0.66, 0.84, t)
	var morning := 1.0 - smoothstep(0.2, 0.3, t)
	var night := maxf(evening, morning)
	if absf(night - _last_night) < 0.0005:
		return
	_last_night = night
	var want_visible := night > 0.01
	if visible != want_visible:
		visible = want_visible
	if want_visible:
		modulate = Color(3, 3, 3, night * 0.9 * strength)
