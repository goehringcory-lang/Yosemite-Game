class_name V2Zone
extends RefCounted
## An area of a v2 wall with a meaning: a rest, a crux, a ledge, a wet streak.
## Written by the wall source (thread 2). Crux zones carry their puzzle in
## [member data] (thread 8 reads it), e.g. {"sequence": [...], "special": "swing"}.

var id := ""
## rest | crux | ledge | wet | sun | loose | bivy
var kind: StringName = &"rest"
var rect := Rect2()
var data := {}


func has_point(pos: Vector2) -> bool:
	return rect.has_point(pos)


func to_dict() -> Dictionary:
	return {"id": id, "kind": String(kind), "rect": V2Data.rect_arr(rect), "data": data.duplicate(true)}


static func from_dict(d: Dictionary) -> V2Zone:
	var z := V2Zone.new()
	z.id = str(d.get("id", ""))
	z.kind = StringName(str(d.get("kind", "rest")))
	z.rect = V2Data.rect(d.get("rect", [0, 0, 0, 0]))
	z.data = (d.get("data", {}) as Dictionary).duplicate(true)
	return z
