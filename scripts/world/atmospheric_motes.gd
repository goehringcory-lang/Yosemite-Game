class_name AtmosphericMotes
extends Node2D
## Floating sunlit dust motes, golden-hour pollen, and gentle indoor sunbeam
## specks on High graphics (LitSprites.active()). Drawn procedurally in a
## camera-relative wrapping field at z_index 17 (above ValleyAir), with zero
## particle allocations.

const COUNT := 44
const FIELD := Vector2(1040.0, 620.0)

var _time := 0.0
var _indoors := false
var _seeds: PackedVector4Array = PackedVector4Array()


func _ready() -> void:
	name = "AtmosphericMotes"
	z_index = 17
	z_as_relative = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = 48151623
	for i in COUNT:
		# (base_x, base_y, speed_scale, phase)
		_seeds.append(Vector4(
			rng.randf() * FIELD.x,
			rng.randf() * FIELD.y,
			rng.randf_range(0.55, 1.35),
			rng.randf() * TAU,
		))
	var world := get_parent()
	if world and world.has_signal("region_changed"):
		world.region_changed.connect(_on_region_changed)


func _on_region_changed(region: Region) -> void:
	_indoors = region != null and region.indoors


func _process(delta: float) -> void:
	if not LitSprites.active():
		visible = false
		return
	var weather := Weather.today()
	var wet: float = maxf(float(weather.rain), float(weather.snow))
	if not _indoors and wet > 0.4:
		visible = false
		return
	visible = true
	_time += delta
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := size * 0.5
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	var origin := center - FIELD * 0.5

	var daylight := Sun.daylight()
	var golden := Sun.golden()
	var night := Sun.night()

	var base_col: Color
	var alpha_scale: float
	if _indoors:
		# Soft warm dust motes drifting in indoor sunbeams / hearth air.
		base_col = Color(1.0, 0.92, 0.74)
		alpha_scale = lerpf(0.24, 0.42, maxf(daylight, RoomLight.level))
	elif night > 0.4:
		# Subtle cool moonlight / night air specks.
		base_col = Color(0.75, 0.88, 1.0)
		alpha_scale = 0.22 * night
	else:
		# Sunlit pollen & golden-hour motes catching the valley light.
		base_col = Color(1.0, 0.96, 0.82).lerp(Color(1.0, 0.82, 0.48), golden)
		alpha_scale = (0.20 + 0.34 * golden) * daylight

	if alpha_scale <= 0.02:
		return

	var wind_x: float = 8.0 if _indoors else 18.0
	for s in _seeds:
		var spd := s.z
		var ph := s.w
		var wx := fposmod(s.x + _time * wind_x * spd - origin.x, FIELD.x) + origin.x
		var wy := fposmod(s.y + sin(_time * 0.7 * spd + ph) * 14.0 - _time * 4.5 * spd - origin.y, FIELD.y) + origin.y
		var pulse := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * (1.1 + spd) + ph * 2.0))
		var a := alpha_scale * pulse
		var sz := 2.0 if spd > 1.05 else 1.5
		# Soft outer glow + crisp center speck.
		draw_rect(Rect2(Vector2(wx - sz, wy - sz), Vector2(sz * 2.0, sz * 2.0)), Color(base_col.r, base_col.g, base_col.b, a * 0.35))
		draw_rect(Rect2(Vector2(wx - 0.5, wy - 0.5), Vector2(1.5, 1.5)), Color(base_col.r, base_col.g, base_col.b, a))
