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
## How bright the soft halo in the air round the lamp itself is (0 for none),
## like light caught in the night air. Its size follows [member radius].
## Only on Low graphics: on High, AirGlow makes real glow instead.
@export var halo := 1.0

static var _glow: GradientTexture2D
static var _halo_tex: GradientTexture2D

var _tint: CanvasModulate
var _phase := 0.0
var _halo: Sprite2D


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
	# how high the lamp hangs over the ground, for sprites with normal maps
	# (LitSprites): the sides of things facing it catch its light
	height = 24.0
	_phase = randf() * TAU
	energy = 0.0
	if halo > 0.0:
		_add_halo()


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
	if _halo:
		# On High graphics the real glow (AirGlow) does this instead.
		_halo.visible = not AirGlow.active()
		# Drawn bright, since the night tint dims it with everything else.
		_halo.modulate = Color(color.r, color.g, color.b, 1.0) * Color(2.2, 2.2, 2.2, minf(level * halo * 0.5, 1.0))


## A soft additive glow round the lamp head, over everything near it.
func _add_halo() -> void:
	if _halo_tex == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.4, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = gradient
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 64
		_halo_tex.height = 64
	_halo = Sprite2D.new()
	_halo.name = "Halo"
	_halo.texture = _halo_tex
	_halo.scale = Vector2.ONE * clampf(radius * 0.4, 10.0, 34.0) / 32.0
	_halo.z_index = 18
	_halo.z_as_relative = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = add
	add_child(_halo)
