class_name V2Piece
extends RefCounted
## One piece of protection: a bolt or old pin in the rock, or a cam, nut or
## sling the leader placed. Fixed pieces come with the wall (thread 2);
## placed ones are made by gear (thread 6).
##
## Field writers (see CONTRACTS.md): gear sets the placement fields; rope
## (thread 5) sets [member clipped]/[member back_clipped]/[member sling_m];
## falls (thread 7) sets [member popped] and [member loaded].

const KINDS: Array[StringName] = [&"bolt", &"pin", &"cam", &"nut", &"sling", &"anchor"]

var id := ""
var kind: StringName = &"bolt"
var pos := Vector2.ZERO
## The rack item it came from (GearData id), "" for fixed pieces.
var gear_id := ""
## The crack it's in and the crack's width there, for cams and nuts.
var crack_id := ""
var width := -1.0
## How well it's set, 0 (a prayer) to 1 (bomber). Hidden from the player:
## the lobes, the partner and the next fall tell you.
var quality := 1.0
## True for bolts, pins and anchors that belong to the wall.
var fixed := false
var clipped := false
var back_clipped := false
## Sling or draw length, metres (rope drag; thread 5).
var sling_m := 0.12
## True after it pulled out in a fall.
var popped := false
## Falls it has held.
var loaded := 0
## Free-form: "rusty", "offset", "walked", "overcammed", "tipped"...
var tags := PackedStringArray()


func to_dict() -> Dictionary:
	return {"id": id, "kind": String(kind), "pos": [pos.x, pos.y], "gear_id": gear_id,
		"crack_id": crack_id, "width": width, "quality": quality, "fixed": fixed,
		"clipped": clipped, "back_clipped": back_clipped, "sling_m": sling_m,
		"popped": popped, "loaded": loaded, "tags": Array(tags)}


static func from_dict(d: Dictionary) -> V2Piece:
	var p := V2Piece.new()
	p.id = str(d.get("id", ""))
	p.kind = StringName(str(d.get("kind", "bolt")))
	p.pos = V2Data.vec(d.get("pos", [0, 0]))
	p.gear_id = str(d.get("gear_id", ""))
	p.crack_id = str(d.get("crack_id", ""))
	p.width = float(d.get("width", -1.0))
	p.quality = float(d.get("quality", 1.0))
	p.fixed = bool(d.get("fixed", false))
	p.clipped = bool(d.get("clipped", false))
	p.back_clipped = bool(d.get("back_clipped", false))
	p.sling_m = float(d.get("sling_m", 0.12))
	p.popped = bool(d.get("popped", false))
	p.loaded = int(d.get("loaded", 0))
	p.tags = PackedStringArray(d.get("tags", []))
	return p
