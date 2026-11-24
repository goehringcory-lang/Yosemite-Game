class_name FallSpray
extends Node2D
## The spray at a waterfall's foot: droplets flung out of the plunge and
## falling back, more of them the harder the fall is running, and on a sunny
## day, while the sun stands behind the viewer, a rainbow in the spray.
## Bridalveil's rainbows are famous in the late afternoon; the falls under the
## north wall (Yosemite Falls and the cascades) catch theirs in the morning.
## SeasonalFalls adds one beside each fall's mist and sets [member flow] and
## [member kind] each day. The rainbow is laid out in 2px cells and dithered at
## its edges, like the Moonbow, so it reads as pixel art.

## Seconds the rainbow takes to come and go as the sun moves or clouds pass.
const FADE_TIME := 6.0
## Hours (from, to) the sun is low enough behind you, per Seasons.FALLS kind.
const HOURS := {"steady": Vector2(15.0, 18.3), "yosemite": Vector2(9.0, 12.0), "ephemeral": Vector2(9.5, 12.5)}
## Outside to inside, one 2px band each.
const BANDS := [
	Color(0.93, 0.25, 0.22), Color(0.97, 0.56, 0.2), Color(0.98, 0.88, 0.3),
	Color(0.38, 0.8, 0.36), Color(0.3, 0.55, 0.95), Color(0.52, 0.36, 0.86),
]

## Spread of the spray (half width and height), world pixels.
@export var area := Vector2(56, 12)
## Radius of the rainbow's arc, world pixels.
@export var radius := 92.0
## Today's flow, 0 (dry) to 1 (the spring roar).
var flow := 1.0
## Which Seasons.FALLS kind the fall is, for the rainbow's hours.
var kind := "yosemite"
## 0 when the rainbow is invisible, 1 at full strength.
var level := 0.0

var _time := 0.0
var _redraw_wait := 0.0
var _drawn_level := -1.0
var _was_in_view := false
var _drops: CPUParticles2D
var _bow: Node2D
## The bow laid out in cells (see _lay_out_bow), and the radius it was for.
var _cell_pos := PackedVector2Array()
var _cell_col := PackedColorArray()
var _cell_alpha := PackedFloat32Array()
var _cell_phase := PackedFloat32Array()
var _haze := PackedVector2Array()
var _cells_for := -1.0


func _ready() -> void:
	z_index = 7
	_drops = CPUParticles2D.new()
	_drops.local_coords = false
	_drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_drops.emission_rect_extents = Vector2(area.x * 0.6, 4.0)
	_drops.amount = 40
	_drops.lifetime = 1.4
	_drops.direction = Vector2(0, -1)
	_drops.spread = 70.0
	_drops.gravity = Vector2(0, 70)
	_drops.initial_velocity_min = 26.0
	_drops.initial_velocity_max = 60.0
	_drops.scale_amount_min = 1.0
	_drops.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	fade.offsets = PackedFloat32Array([0.0, 0.6, 0.85])
	fade.colors = PackedColorArray([Color(0.95, 0.98, 1.0, 0.8), Color(0.88, 0.95, 1.0, 0.5), Color(0.88, 0.95, 1.0, 0.0)])
	_drops.color_ramp = fade
	add_child(_drops)
	_bow = Node2D.new()
	_bow.z_index = 1
	# rising out of the pool below the spray, arching over it
	_bow.position = Vector2(0, 28)
	_bow.draw.connect(_draw_bow)
	add_child(_bow)
	apply()
	# already there if you arrive while it's showing
	if rainbow_time():
		level = 1.0


## Sets the droplets for today's [member flow].
func apply() -> void:
	if _drops == null:
		return
	_drops.emitting = flow > 0.0
	var amount := int(lerpf(8.0, 48.0, clampf(flow, 0.0, 1.0)))
	if _drops.amount != amount:
		_drops.amount = amount
	_drops.initial_velocity_max = lerpf(30.0, 64.0, flow)


## True while the sun can make a rainbow here: the right hours, enough water
## coming down, and no cloud over the sun.
func rainbow_time() -> bool:
	if flow < 0.3:
		return false
	var hours: Vector2 = HOURS.get(kind, HOURS["yosemite"])
	var hour := GameClock.minutes / 60.0
	if hour < hours.x or hour > hours.y:
		return false
	var weather := Weather.today()
	return weather.rain <= 0.0 and weather.snow <= 0.0 and weather.clouds < 0.6


func _bow_in_view() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var size := vp.get_visible_rect().size
	var cam := vp.get_camera_2d()
	var center := size * 0.5
	if cam != null:
		size /= cam.zoom
		center = cam.get_screen_center_position()
	var pos := _bow.global_position
	var pad := radius + 32.0
	var half := size * 0.5
	return absf(pos.x - center.x) <= half.x + pad and absf(pos.y - center.y) <= half.y + pad


func _process(delta: float) -> void:
	var on := rainbow_time()
	level = move_toward(level, 1.0 if on else 0.0, delta / FADE_TIME)
	var was_visible := _bow.visible
	_bow.visible = level > 0.0
	if not _bow.visible:
		_was_in_view = false
		return
	_time += delta
	var in_view := _bow_in_view()
	if not in_view:
		_was_in_view = false
		return
	_redraw_wait -= delta
	if not was_visible or not _was_in_view or _redraw_wait <= 0.0 or absf(level - _drawn_level) > 0.01:
		_was_in_view = true
		_redraw_wait = 0.05
		_drawn_level = level
		_bow.queue_redraw()


## Lays the bow out once for [member radius]: its cells as packed position,
## colour, base alpha and gust phase, and the haze's cells.
## The whole square round the bow (over 5,000 cells, for some hundreds
## drawn) was scanned every frame it was up; only the gusts and the
## strength change.
func _lay_out_bow() -> void:
	_cells_for = radius
	_cell_pos.clear()
	_cell_col.clear()
	_cell_alpha.clear()
	_cell_phase.clear()
	_haze.clear()
	var r := radius * 0.5
	var reach := int(r) + 4
	var band_count := BANDS.size()
	for px in range(-reach, reach + 1):
		for py in range(-reach, 2):
			var dist := sqrt(float(px * px + py * py))
			var band := int(floor(r - dist + 3.0))
			if band < 0 or band >= band_count:
				continue
			var alpha := 0.42
			# the outermost and innermost bands are dithered, so the edge stays crisp
			if (band == 0 or band == band_count - 1) and (px + py) % 2 == 0:
				continue
			# brightest low down, where the spray is thickest; the crown thins out
			var up := -float(py) / r
			alpha *= clampf(1.15 - up * 0.9, 0.15, 1.0) * clampf((up + 0.05) * 4.0, 0.0, 1.0)
			if alpha > 0.0:
				_cell_pos.append(Vector2(px * 2, py * 2))
				_cell_col.append(BANDS[band])
				_cell_alpha.append(alpha)
				_cell_phase.append(px * 0.21 - py * 0.1)
	# a faint bright haze inside the bow, as in a real one
	var r_inner_sq := (r - 4.0) * (r - 4.0)
	for py in range(-int(r * 0.6), 1, 2):
		for px in range(-int(r * 0.8), int(r * 0.8) + 1, 2):
			if float(px * px + py * py) < r_inner_sq and (px + py) % 4 == 0:
				_haze.append(Vector2(px * 2, py * 2))


func _draw_bow() -> void:
	# In cell units (2px). The bow is strongest in the thick of the spray and
	# fades toward its feet and its crown; it breathes as the spray gusts.
	if _cells_for != radius:
		_lay_out_bow()
	var strength := level * lerpf(0.55, 1.0, flow)
	var t := _time * 1.3
	var cell_size := Vector2(2, 2)
	for i in _cell_pos.size():
		var alpha := _cell_alpha[i] * (0.75 + 0.25 * sin(t + _cell_phase[i])) * strength
		if alpha > 0.02:
			var col := _cell_col[i]
			col.a = alpha
			_bow.draw_rect(Rect2(_cell_pos[i], cell_size), col)
	var haze := Color(1, 1, 0.95, 0.035 * strength)
	for i in _haze.size():
		_bow.draw_rect(Rect2(_haze[i], cell_size), haze)
