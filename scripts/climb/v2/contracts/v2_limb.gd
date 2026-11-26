class_name V2Limb
extends RefCounted
## What one hand or foot is doing. Poses are fully resolved: art (thread 9)
## draws from these contacts and never guesses.

## hold: on [member id] (a V2Hold). smear: a foot on blank rock at [member pos].
## free: off the rock (a flag, or a hand hanging). rope: a hand pulling up
## rope or clipping. gear: a hand placing a piece ([member id] = rack item).
## chalk: a hand in the chalk bag. food: a hand eating.
const KINDS: Array[StringName] = [&"hold", &"smear", &"free", &"rope", &"gear", &"chalk", &"food"]

var kind: StringName = &"free"
var id := ""
## Where the hand or foot is, wall metres (for a hold, the hold's spot).
var pos := Vector2.ZERO


static func make(p_kind: StringName, p_pos: Vector2, p_id := "") -> V2Limb:
	var l := V2Limb.new()
	l.kind = p_kind
	l.pos = p_pos
	l.id = p_id
	return l


func on_rock() -> bool:
	return kind == &"hold" or kind == &"smear"


func copy() -> V2Limb:
	return make(kind, pos, id)


func to_dict() -> Dictionary:
	return {"kind": String(kind), "id": id, "pos": [pos.x, pos.y]}


static func from_dict(d: Dictionary) -> V2Limb:
	return make(StringName(str(d.get("kind", "free"))), V2Data.vec(d.get("pos", [0, 0])), str(d.get("id", "")))
