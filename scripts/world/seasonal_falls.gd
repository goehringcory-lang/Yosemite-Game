class_name SeasonalFalls
extends Node
## Makes a region's waterfalls follow the snowmelt (Seasons.waterfall_flow):
## full and roaring in late spring, thinner through the summer, and a dark
## stain on dry rock through most of fall. Region adds one as a child. It
## finds the falls by their drawings (an AnimatedSprite2D whose frames are
## *_fall_N.png), the spray at their feet (*_mist_N.png), and the mist
## particles and their roar (AmbientFx "mist"), and dresses them each day.
## Water painted on the ground that the falls feed dries with them (see
## [constant DRY_AREAS]): Yosemite Creek's bed below the Lower Fall turns to
## cobbles, and Mirror Lake shrinks to the sandy meadow it becomes each late
## summer. Only the drawing changes; the scenes are never rebuilt.

const FLOW_SHADER := preload("res://assets/shaders/waterfall_flow.gdshader")

## Which Seasons.FALLS kind each region's fall is. Anything not listed is
## "yosemite".
const KINDS := {
	"bridalveil_fall": "steady",
	"four_mile_trailhead": "ephemeral", # Sentinel Fall
	"curry_village": "ephemeral", # Staircase Falls
	"the_ahwahnee": "ephemeral", # Royal Arch Cascade
}

## Painted water that dries up, per region: the area (ground texture pixels),
## how it dries (0 a cobbled creek bed, 1 sand and meadow), and the flow at
## which it starts to (it is all dry at 0).
const DRY_AREAS := {
	"yosemite_village": {"rect": Rect2(1336, 0, 208, 1590), "kind": 0, "from": 0.35},
	"mirror_lake": {"rect": Rect2(790, 590, 830, 340), "kind": 1, "from": 0.5},
}

var kind := "yosemite"
var flow := 1.0

var _falls: Array[AnimatedSprite2D] = []
var _mists: Array[AnimatedSprite2D] = []
var _mist_alpha: Array[float] = []
var _spray: Array[AmbientFx] = []
## The droplets and rainbow beside each spray (FallSpray).
var _bows: Array[FallSpray] = []
var _key := ""
var _dry_area := {}
var _ground: ShaderMaterial


func _ready() -> void:
	var region := get_parent()
	if region is Region:
		kind = KINDS.get((region as Region).region_id, "yosemite")
		_dry_area = DRY_AREAS.get((region as Region).region_id, {})
	var ground := region.get_node_or_null("GroundArt") as CanvasItem
	if ground and ground.material is ShaderMaterial and not _dry_area.is_empty():
		_ground = ground.material
		var rect: Rect2 = _dry_area["rect"]
		_ground.set_shader_parameter("dry_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		_ground.set_shader_parameter("dry_kind", _dry_area["kind"])
	for node in region.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := node as AnimatedSprite2D
		var art := _art_name(sprite)
		if art.contains("_fall_"):
			var mat := ShaderMaterial.new()
			mat.shader = FLOW_SHADER
			sprite.material = mat
			_falls.append(sprite)
		elif art.contains("_mist_"):
			_mists.append(sprite)
			_mist_alpha.append(sprite.modulate.a)
	for node in region.find_children("*", "CPUParticles2D", true, false):
		if node is AmbientFx and (node as AmbientFx).effect == "mist":
			_spray.append(node)
	for spray in _spray:
		var bow := FallSpray.new()
		bow.name = "FallSpray"
		bow.area = spray.area
		bow.kind = kind
		bow.position = spray.position
		spray.add_sibling.call_deferred(bow)
		_bows.append(bow)
	apply()


func _process(_delta: float) -> void:
	if "%d:%d" % [GameClock.season, GameClock.day] != _key:
		apply()


## Takes [param sprite] as one of the region's falls, for a fall added after
## the region was set up (BackdropFall, from a story overlay).
func add_fall(sprite: AnimatedSprite2D) -> void:
	if sprite in _falls:
		return
	var mat := ShaderMaterial.new()
	mat.shader = FLOW_SHADER
	sprite.material = mat
	_falls.append(sprite)
	apply()


## Dresses the falls for today's flow.
func apply() -> void:
	_key = "%d:%d" % [GameClock.season, GameClock.day]
	flow = Seasons.waterfall_flow(kind)
	var dry := flow <= 0.0
	for fall in _falls:
		var mat := fall.material as ShaderMaterial
		mat.set_shader_parameter("flow", flow)
		mat.set_shader_parameter("dry", dry)
		# A dry stain doesn't move.
		if dry:
			fall.pause()
		elif not fall.is_playing():
			fall.play()
	for i in _mists.size():
		_mists[i].visible = not dry
		_mists[i].modulate.a = _mist_alpha[i] * lerpf(0.35, 1.0, flow)
	for spray in _spray:
		spray.emitting = not dry
		spray.modulate.a = lerpf(0.4, 1.0, flow)
		for child in spray.get_children():
			if child is SoundEmitter:
				# Heard in proportion to the water coming down.
				(child as SoundEmitter).flow_kind = kind
				(child as SoundEmitter)._refresh_level()
	for bow in _bows:
		bow.flow = flow
		bow.visible = not dry
		bow.apply()
	if _ground:
		_ground.set_shader_parameter("dry_amount", 1.0 - clampf(flow / float(_dry_area["from"]), 0.0, 1.0))


## True if the painted water at [param at] (a world position in
## [param region]) has dried up today, so there's nothing to fish in.
static func dried_up(region: Region, at: Vector2) -> bool:
	var area: Dictionary = DRY_AREAS.get(region.region_id, {})
	if area.is_empty():
		return false
	var flow := Seasons.waterfall_flow(KINDS.get(region.region_id, "yosemite"))
	var rect: Rect2 = area["rect"]
	# Within the area, away from the edges where the drying fades out.
	return rect.grow(-64.0).has_point(at - region.global_position) and flow / float(area["from"]) < 0.25


## The file name of the sprite's first frame, or "".
static func _art_name(sprite: AnimatedSprite2D) -> String:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(sprite.animation) or frames.get_frame_count(sprite.animation) == 0:
		return ""
	var tex := frames.get_frame_texture(sprite.animation, 0)
	return tex.resource_path.get_file() if tex else ""
