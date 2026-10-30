class_name SunLight
extends DirectionalLight2D
## The sun as a real light, for the sprites with normal maps (LitSprites): it
## comes from where Sun puts the sun, low and warm at either end of the day,
## high and white at noon, so the morning sun catches the east sides of the
## trunks, roofs and rocks and the evening sun the west. It only shapes
## (lit.gdshaderinc): the day's tint (DayNight) still sets how bright the
## world is. It fades out at dusk and in the rain, and is off indoors and on
## Low graphics.

## How much the slopes facing the sun brighten (and those facing away dim),
## as a share of the painted colour, in full clear sun.
const STRENGTH := 0.5
const NOON := Color(1.0, 0.98, 0.92)
const GOLDEN := Color(1.0, 0.78, 0.5)

var _tint: CanvasModulate


func _ready() -> void:
	name = "SunLight"
	blend_mode = Light2D.BLEND_MODE_ADD
	range_item_cull_mask = LitSprites.LIT_LAYER
	shadow_enabled = false
	energy = 0.0


func _process(_delta: float) -> void:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
	var outdoors := _tint != null and _tint.visible
	var weather := Weather.today()
	var level := Sun.daylight() * (1.0 - weather.clouds * 0.6) * (1.0 - maxf(weather.rain, weather.snow) * 0.7)
	enabled = LitSprites.active() and outdoors and level > 0.01
	if not enabled:
		return
	# travelling from the sun toward the ground; at rotation 0 a directional
	# light shines down the screen
	rotation = (-Sun.direction()).angle() - PI / 2.0
	height = clampf(sin(deg_to_rad(Sun.height())), 0.12, 0.95)
	var c := NOON.lerp(GOLDEN, Sun.golden()) * _tint.color
	c.a = 1.0
	color = c
	energy = STRENGTH * level
