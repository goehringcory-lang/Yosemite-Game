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
var _drops: CPUParticles2D
var _bow: Node2D


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


func _process(delta: float) -> void:
	var on := rainbow_time()
	level = move_toward(level, 1.0 if on else 0.0, delta / FADE_TIME)
	_bow.visible = level > 0.0
	if _bow.visible:
		_time += delta
		_bow.queue_redraw()


func _draw_bow() -> void:
	# In cell units (2px). The bow is strongest in the thick of the spray and
	# fades toward its feet and its crown; it breathes as the spray gusts.
	var r := radius * 0.5
	var reach := int(r) + 4
	var strength := level * lerpf(0.55, 1.0, flow)
	for px in range(-reach, reach + 1):
		for py in range(-reach, 2):
			var dist := Vector2(px, py).length()
			var band := int(floor(r - dist + 3.0))
			if band < 0 or band >= BANDS.size():
				continue
			var col: Color = BANDS[band]
			var alpha := 0.42
			# the outermost and innermost bands are dithered, so the edge stays crisp
			if (band == 0 or band == BANDS.size() - 1) and (px + py) % 2 == 0:
				continue
			# brightest low down, where the spray is thickest; the crown thins out
			var up := -float(py) / r
			alpha *= clampf(1.15 - up * 0.9, 0.15, 1.0) * clampf((up + 0.05) * 4.0, 0.0, 1.0)
			alpha *= 0.75 + 0.25 * sin(_time * 1.3 + px * 0.21 - py * 0.1)
			alpha *= strength
			if alpha > 0.02:
				_bow.draw_rect(Rect2(px * 2, py * 2, 2, 2), Color(col, alpha))
	# a faint bright haze inside the bow, as in a real one
	for py in range(-int(r * 0.6), 1, 2):
		for px in range(-int(r * 0.8), int(r * 0.8) + 1, 2):
			if Vector2(px, py).length() < r - 4 and (px + py) % 4 == 0:
				_bow.draw_rect(Rect2(px * 2, py * 2, 2, 2), Color(1, 1, 0.95, 0.035 * strength))
