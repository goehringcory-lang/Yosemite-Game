class_name V2Rope
extends RefCounted
## The lead rope (the RopeState). Written only by rope (thread 5). Falls
## (thread 7) reads it and asks rope for fall geometry; the director asks rope
## to unclip pieces that popped.

## Clipped piece ids, lowest first (the order the rope runs through them).
var clipped := PackedStringArray()
## Extra rope out beyond what reaches the climber tight: metres. Pulling up
## rope to clip adds it; clipping takes it back.
var slack_m := 0.0
## While pulling up rope to clip: the piece, and arm-lengths pulled so far.
var pulling_for := ""
var arms_pulled := 0
## Rope drag, 0 none to 1 can barely pull (zig-zags, short slings).
var drag := 0.0
var length_m := ClimbV2.ROPE_M


func top_piece() -> String:
	return clipped[clipped.size() - 1] if clipped.size() > 0 else ""


func copy() -> V2Rope:
	return from_dict(to_dict())


func to_dict() -> Dictionary:
	return {"clipped": Array(clipped), "slack_m": slack_m, "pulling_for": pulling_for,
		"arms_pulled": arms_pulled, "drag": drag, "length_m": length_m}


static func from_dict(d: Dictionary) -> V2Rope:
	var r := V2Rope.new()
	r.clipped = PackedStringArray(d.get("clipped", []))
	r.slack_m = float(d.get("slack_m", 0.0))
	r.pulling_for = str(d.get("pulling_for", ""))
	r.arms_pulled = int(d.get("arms_pulled", 0))
	r.drag = float(d.get("drag", 0.0))
	r.length_m = float(d.get("length_m", ClimbV2.ROPE_M))
	return r
