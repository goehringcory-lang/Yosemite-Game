extends Sprite2D
## A warm additive glow (lit windows, lanterns) that fades in at dusk and out
## at dawn. The world's night tint would dim it with everything else, so it
## is drawn extra bright to stay visible.

@export var strength := 1.0


func _ready() -> void:
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	modulate = Color(3, 3, 3, 0)


func _process(_delta: float) -> void:
	var t := Sun.gradient_progress()
	var evening := smoothstep(0.66, 0.84, t)
	var morning := 1.0 - smoothstep(0.2, 0.3, t)
	var night := maxf(evening, morning)
	modulate = Color(3, 3, 3, night * 0.9 * strength)
	visible = night > 0.01
