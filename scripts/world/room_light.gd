class_name RoomLight
extends CanvasModulate
## Evening indoors, on High graphics: as the day outside fades the room dims
## to a warm low light, and its lamps, stoves and hearths (NightLights, from
## LampLights) come up and light the floor and the furniture round them, with
## real glow (AirGlow) in the air. By day the window light (SunLight) falls
## from the back of the room. Outdoors DayNight tints the world instead, and
## on Low graphics rooms stay evenly lit as painted.

## The room's light at full night, before its lamps.
const NIGHT := Color(0.62, 0.56, 0.52)

## 0 by day and outdoors, up to 1 at night indoors: how far the lamps inside
## are up (NightLight and AirGlow read it).
static var level := 0.0

var _tint: CanvasModulate


func _ready() -> void:
	name = "RoomLight"
	visible = false


func _process(_delta: float) -> void:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
	var indoors := _tint != null and not _tint.visible
	level = 1.0 - Sun.daylight() if indoors and LitSprites.active() else 0.0
	visible = level > 0.01
	color = Color.WHITE.lerp(NIGHT, level)


func _exit_tree() -> void:
	level = 0.0
