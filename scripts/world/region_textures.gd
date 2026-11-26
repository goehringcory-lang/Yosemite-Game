class_name RegionTextures
extends RefCounted
## Lets a region World keeps (every region visited stays in memory, as it
## was, see World._regions) give back its biggest pictures while it is out
## of the world, and takes them back before it is laid out again.
##
## Only the painted ground goes, and its normal map: on an outdoor region
## those two are most of its video memory (Yosemite Village's are 30 MB
## each), and they belong to that region alone. The nodes stay just as they
## were, so the region comes back the same, pixel for pixel; only the
## picture is loaded again (in the background, when it's a way on from where
## the player is, see World._preload_neighbors).

const GROUNDS := ["GroundArt", "GroundPainting"]
const META := "released_textures"


## Gives back [param region]'s ground pictures. It must be out of the tree.
## Does nothing if they're already given back or it has none.
static func release(region: Node) -> void:
	if region.has_meta(META) or region.is_inside_tree():
		return
	var kept := {}
	for ground_name in GROUNDS:
		var ground := region.get_node_or_null(ground_name) as Sprite2D
		if ground == null or ground.texture == null or ground.texture.resource_path == "":
			continue
		var entry := {"texture": ground.texture.resource_path, "normal": ""}
		var mat := ground.material as ShaderMaterial
		if mat:
			var normal = mat.get_shader_parameter("normal_map")
			if normal is Texture2D and (normal as Texture2D).resource_path != "":
				entry.normal = (normal as Texture2D).resource_path
				mat.set_shader_parameter("normal_map", null)
		ground.texture = null
		kept[ground_name] = entry
	if not kept.is_empty():
		region.set_meta(META, kept)


## Takes the pictures back (loaded already if World loaded them ahead;
## otherwise now). Call before [param region] goes back into the tree.
static func restore(region: Node) -> void:
	if not region.has_meta(META):
		return
	var kept: Dictionary = region.get_meta(META)
	region.remove_meta(META)
	for ground_name: String in kept:
		var ground := region.get_node_or_null(ground_name) as Sprite2D
		if ground == null:
			continue
		var entry: Dictionary = kept[ground_name]
		ground.texture = load(entry.texture) as Texture2D
		var mat := ground.material as ShaderMaterial
		if mat and entry.normal != "":
			mat.set_shader_parameter("normal_map", load(entry.normal) as Texture2D)


static func is_released(region: Node) -> bool:
	return region.has_meta(META)


## The pictures [param region] would load again, to load them ahead.
static func paths(region: Node) -> Array[String]:
	var found: Array[String] = []
	if not region.has_meta(META):
		return found
	var kept: Dictionary = region.get_meta(META)
	for entry: Dictionary in kept.values():
		found.append(entry.texture)
		if entry.normal != "":
			found.append(entry.normal)
	return found
