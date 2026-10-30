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

## The wall's material: the sun is worked out in its shader (a 2D
## directional light would also light the sky and the HUD on this screen).
var wall_material: ShaderMaterial
## Whether the sun lights the wall, and the way its light travels across it.
var sun_on := false
var sun_travel := Vector2.ZERO
var headlamp: PointLight2D


func _init() -> void:
	wall_material = ShaderMaterial.new()
	wall_material.shader = SHADER


func _ready() -> void:
	name = "ClimbLight"
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
	sun_on = not night and level > 0.01
	# The wall faces the valley: the sun in the east lights it from the
	# right, in the west from the left, and always a little from above.
	var toward := Sun.direction(hour)
	sun_travel = Vector2(-toward.x, 0.45).normalized()
	wall_material.set_shader_parameter("sun_travel", sun_travel)
	wall_material.set_shader_parameter("sun_color", NOON.lerp(GOLDEN, Sun.golden(hour)))
	wall_material.set_shader_parameter("sun_strength", SUN_STRENGTH * level if sun_on else 0.0)
	headlamp.enabled = night
	headlamp.position = head
	# 2D lights only reach canvas layers in their layer range, which is 0
	# unless set: the climbing screen sits well above the world.
	headlamp.range_layer_min = _layer()
	headlamp.range_layer_max = _layer()


func _layer() -> int:
	var node := get_parent()
	while node and not node is CanvasLayer:
		node = node.get_parent()
	return (node as CanvasLayer).layer if node else 0
