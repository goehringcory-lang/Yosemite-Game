class_name RiverFlow
extends RefCounted
## Where a region's running river (assets/shaders/river_flow.gdshaderinc,
## drawn by the ground's seasonal_ground shader) runs some other way than the
## region's "water_flow", or doesn't run at all, and where its banks lie.
## Rects are in the ground texture's pixels.

const RIVERS := {
	"tuolumne_meadows": {
		# the river and its gravel bars, across the meadow
		"box": Rect2(0, 760, 4480, 540),
		"zones": [
			# the Lyell Fork, coming down from the southeast over cobbles
			[Rect2(3740, 968, 740, 320), Vector3(-8.0, -4.5, 0.45)],
			# where the forks meet under the road bridge: white water
			[Rect2(3560, 820, 300, 150), Vector3(-9.0, 0.0, 0.5)],
			# the pond up in the northeast corner lies still
			[Rect2(3950, 100, 480, 220), Vector3.ZERO],
		],
	},
}


## Sets [param mat]'s river uniforms for [param region_id] (none: no zones).
static func apply(mat: ShaderMaterial, region_id: String) -> void:
	var river: Dictionary = RIVERS.get(region_id, {})
	var rects := PackedVector4Array()
	var dirs := PackedVector4Array()
	for zone: Array in river.get("zones", []):
		var r: Rect2 = zone[0]
		var f: Vector3 = zone[1]
		rects.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		dirs.append(Vector4(f.x, f.y, f.z, 0.0))
	while rects.size() < 4:
		rects.append(Vector4.ZERO)
		dirs.append(Vector4.ZERO)
	mat.set_shader_parameter("flow_zone", rects)
	mat.set_shader_parameter("flow_zone_dir", dirs)
	var box: Rect2 = river.get("box", Rect2())
	mat.set_shader_parameter("river_box", Vector4(box.position.x, box.position.y, box.size.x, box.size.y))
