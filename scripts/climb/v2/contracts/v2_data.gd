class_name V2Data
extends RefCounted
## Small helpers the v2 contracts share for turning data to and from plain
## dictionaries (JSON fixtures, snapshots).


static func vec(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


static func arr(v: Vector2) -> Array:
	return [v.x, v.y]


static func rect(v: Variant) -> Rect2:
	if v is Rect2:
		return v
	if v is Array and v.size() >= 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2()


static func rect_arr(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
