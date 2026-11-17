class_name SunLight
extends Node2D
## The sun as a real light, for the sprites with normal maps (LitSprites): it
## comes from where Sun puts the sun, low and warm at either end of the day,
## high and white at noon, so the morning sun catches the east sides of the
## trunks, roofs and rocks and the evening sun the west. It only shapes
## (lit.gdshaderinc): the day's tint (DayNight) still sets how bright the
## world is. It fades out at dusk and in the rain. Indoors it is the daylight
## through the windows, from the back of the room. Off on Low graphics.
##
## It isn't a DirectionalLight2D: Godot runs a directional 2D light over every
## canvas item whatever its light mask, and that light pass on every sprite,
## the ground and each full-screen effect cost about a quarter of the frame on
## High. The light also added its colour to everything without a light() of
## its own (an unlit sprite stood 1 + the sun times brighter), which the art
## has been tuned under. So, for the same picture, it lifts the world canvas's
## modulate (the day's tint, DayNight) by 1 + the sun, and sets the global
## shader uniforms sun_toward and sun_light, with which the lit shaders shape
## themselves and take the lift back out (lit.gdshaderinc). DayNight.color
## stays the plain tint for everything that reads it. rotation, height,
## color, energy and enabled read as a light's would (rotation 0 shines down
## the screen).

## How much the slopes facing the sun brighten (and those facing away dim),
## as a share of the painted colour, in full clear sun.
const STRENGTH := 0.5
const NOON := Color(1.0, 0.98, 0.92)
const GOLDEN := Color(1.0, 0.78, 0.5)
## Indoors the light comes through the windows: softer, a little cool, and
## always from the back wall, at this share of the sun's strength.
const WINDOW := Color(0.95, 0.97, 1.0)
const WINDOW_SHARE := 0.6
const WINDOW_HEIGHT := 0.4

## How high the sun stands, 0 (on the horizon) to 1 (overhead).
var height := 0.0
## The light's colour as it falls, the day's tint included outdoors.
var color := Color.WHITE
var energy := 0.0
var enabled := false

var _tint: CanvasModulate


func _ready() -> void:
	name = "SunLight"
	_publish(Color.BLACK)


func _exit_tree() -> void:
	_publish(Color.BLACK)
	if _tint and _tint.is_inside_tree():
		RenderingServer.canvas_set_modulate(get_canvas(), _tint.color if _tint.visible else Color.WHITE)


func _process(_delta: float) -> void:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
	var outdoors := _tint != null and _tint.visible
	var weather := Weather.today()
	var level: float = Sun.daylight() * (1.0 - weather.clouds * 0.6) * (1.0 - maxf(weather.rain, weather.snow) * 0.7)
	enabled = LitSprites.active() and _tint != null and level > 0.01
	if not enabled:
		_publish(Color.BLACK)
		return
	if not outdoors:
		# Indoors: daylight through the windows in the back wall, falling
		# softly down the room.
		rotation = 0.0
		height = WINDOW_HEIGHT
		color = WINDOW
		energy = STRENGTH * WINDOW_SHARE * level
		_publish(WINDOW)
		return
	# travelling from the sun toward the ground; at rotation 0 a directional
	# light shines down the screen
	rotation = (-Sun.direction()).angle() - PI / 2.0
	height = clampf(sin(deg_to_rad(Sun.height())), 0.12, 0.95)
	var light := NOON.lerp(GOLDEN, Sun.golden())
	var c := light * _tint.color
	c.a = 1.0
	color = c
	energy = STRENGTH * level
	# the shaders shape the colour before the day's tint (DayNight, the
	# canvas modulate) is laid over it, so they take the light untinted
	_publish(light)


## Hands the sun to the lit shaders: the way toward it, and its colour times
## its strength ([param light] black puts it out).
func _publish(light: Color) -> void:
	var toward := -Vector2.DOWN.rotated(rotation)
	RenderingServer.global_shader_parameter_set("sun_toward", toward)
	var e := energy if light != Color.BLACK else 0.0
	var sun := Vector3(light.r, light.g, light.b) * e
	RenderingServer.global_shader_parameter_set("sun_light", sun)
	# DayNight sets the plain tint when it changes (and white while it's
	# hidden indoors); this runs after it each frame and lays the lift on.
	if not is_inside_tree() or _tint == null:
		return
	var tint := _tint.color if _tint.visible else Color.WHITE
	RenderingServer.canvas_set_modulate(get_canvas(), Color(tint.r * (1.0 + sun.x), tint.g * (1.0 + sun.y), tint.b * (1.0 + sun.z), 1.0))
