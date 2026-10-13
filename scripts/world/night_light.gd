class_name NightLight
extends PointLight2D
## A lamp, lantern, window or fire that glows after dark. It's off by day and
## fades up as the world's day and night tint darkens (see DayNight).

## How bright it gets at full night.
@export var strength := 1.0
## Radius in world pixels.
@export var radius := 80.0
## 0 is steady; higher flickers like a flame.
@export_range(0.0, 1.0) var flicker := 0.0
## Only lit during these hours, from (included) to (excluded), wrapping past
## midnight: (0, 4) is midnight until 4 AM. (-1, -1) means all night.
@export var lit_hours := Vector2i(-1, -1)

static var _glow: GradientTexture2D

var _tint: CanvasModulate
var _phase := 0.0


func _ready() -> void:
	if _glow == null:
		# A soft pool: bright at the lamp, then an eased fall-off with no hard rim.
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.78, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = gradient
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	texture = _glow
	texture_scale = radius / 64.0
	color = Color(1.0, 0.82, 0.5)
	shadow_enabled = false
	_phase = randf() * TAU
	energy = 0.0


func _process(delta: float) -> void:
	if _tint == null:
		_tint = get_tree().root.find_child("DayNight", true, false) as CanvasModulate
		if _tint == null:
			return
	var dark := 0.0
	if _tint.visible:
		var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
		dark = clampf((0.9 - lum) / 0.45, 0.0, 1.0)
	var level := strength * dark
	if lit_hours.x >= 0 and not GameClock.hour_in_range(lit_hours.x, lit_hours.y):
		level = 0.0
	if flicker > 0.0 and level > 0.0:
		_phase += delta * 9.0
		level *= 1.0 - flicker * (0.5 + 0.5 * sin(_phase) * sin(_phase * 0.37 + 1.0))
	# A touch over 1 so a lamp clearly lifts the blue night, not just a speck.
	energy = level * 1.25
	visible = level > 0.01
