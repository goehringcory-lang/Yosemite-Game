class_name V2Hold
extends RefCounted
## One hold on a v2 wall: something a hand or a foot can use. Written by the
## wall source (thread 2) when a pitch is built; read-only after that.

## Hand-hold kinds. "jam" is a spot in a crack (see [member crack_id]);
## "stance" is a ledge or big foothold you can stand on and rest.
const KINDS: Array[StringName] = [&"jug", &"edge", &"crimp", &"sloper", &"pinch", &"pocket",
	&"undercling", &"sidepull", &"gaston", &"jam", &"horn", &"stance"]

var id := ""
## Where it is, in wall metres (y up from the lower belay).
var pos := Vector2.ZERO
var kind: StringName = &"edge"
## The direction it wants to be pulled (unit vector, wall space): (0, -1) is
## a plain downward pull on a jug; (1, 0) a sidepull you lean left off.
var pull := Vector2(0, -1)
## How good it is, 0 (barely there) to 1 (a bucket).
var size := 0.5
## Hands can use it / feet can use it.
var hand := true
var foot := true
## The crack it's part of, for "jam" holds; "" otherwise.
var crack_id := ""
## Free-form tags other systems read, e.g. "anchor" (the top), "polished",
## "loose", "chalked", "kneebar", "heel".
var tags := PackedStringArray()


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func to_dict() -> Dictionary:
	return {"id": id, "pos": [pos.x, pos.y], "kind": String(kind), "pull": [pull.x, pull.y],
		"size": size, "hand": hand, "foot": foot, "crack_id": crack_id, "tags": Array(tags)}


static func from_dict(d: Dictionary) -> V2Hold:
	var h := V2Hold.new()
	h.id = str(d.get("id", ""))
	h.pos = V2Data.vec(d.get("pos", [0, 0]))
	h.kind = StringName(str(d.get("kind", "edge")))
	h.pull = V2Data.vec(d.get("pull", [0, -1]))
	h.size = float(d.get("size", 0.5))
	h.hand = bool(d.get("hand", true))
	h.foot = bool(d.get("foot", true))
	h.crack_id = str(d.get("crack_id", ""))
	h.tags = PackedStringArray(d.get("tags", []))
	return h
