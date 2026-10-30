class_name ClimbLight
extends Node2D
## Real light on the climbing screen's wall, on High graphics (LitSprites):
## by day the sun rakes across the face from its side of the sky, low and
## warm early and late, so flakes, cracks and knobs stand out in relief; after
## dark the climber's headlamp throws a pool of light on the stone round them.
## The wall is drawn on its own canvas item with lit_luma.gdshader, which
## reads the relief from the painted rock as it draws; nothing else on the
## screen is on the light layer. On Low the screen keeps its painted look.

const SHADER := preload("res://assets/shaders/lit_luma.gdshader")
## How strongly the sun shapes the face in full clear sun.
const SUN_STRENGTH := 0.5
const NOON := Color(1.0, 0.98, 0.92)
const GOLDEN := Color(1.0, 0.78, 0.5)
## The headlamp: how far its light reaches on the wall (menu pixels), how
## bright it is, and how far it sits off the rock.
const LAMP_RADIUS := 70.0
const LAMP_ENERGY := 1.1
const LAMP_HEIGHT := 10.0

var sun: DirectionalLight2D
var headlamp: PointLight2D


## The material for the wall's canvas item.
static func wall_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	return mat


func _ready() -> void:
	name = "ClimbLight"
	sun = DirectionalLight2D.new()
	sun.blend_mode = Light2D.BLEND_MODE_ADD
	sun.range_item_cull_mask = LitSprites.LIT_LAYER
	sun.enabled = false
	add_child(sun)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	headlamp = PointLight2D.new()
	headlamp.texture = tex
	headlamp.texture_scale = LAMP_RADIUS / 64.0
	headlamp.height = LAMP_HEIGHT
	headlamp.color = Color(1.0, 0.86, 0.62)
	headlamp.energy = LAMP_ENERGY
	headlamp.range_item_cull_mask = LitSprites.LIT_LAYER
	headlamp.enabled = false
	add_child(headlamp)


## Sets the light for the climb's [param hour] (with [param night] as the
## screen's palette has it) and puts the headlamp at [param head].
func update(hour: float, night: bool, head: Vector2, cloud := 0.0) -> void:
	var level := Sun.daylight(hour) * (1.0 - cloud * 0.7)
	sun.enabled = not night and level > 0.01
	if sun.enabled:
		# The wall faces the valley: the sun in the east lights it from the
		# right, in the west from the left, and always a little from above.
		var toward := Sun.direction(hour)
		var travel := Vector2(-toward.x, 0.45).normalized()
		sun.rotation = travel.angle() - PI / 2.0
		sun.height = clampf(sin(deg_to_rad(Sun.height(hour))), 0.12, 0.9)
		var c := NOON.lerp(GOLDEN, Sun.golden(hour))
		c.a = 1.0
		sun.color = c
		sun.energy = SUN_STRENGTH * level
	headlamp.enabled = night
	headlamp.position = head
