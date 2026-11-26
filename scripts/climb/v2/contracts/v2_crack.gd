class_name V2Crack
extends RefCounted
## A continuous crack on a v2 wall: a line up the rock whose width changes
## along it. Written by the wall source (thread 2); read by gear (cams and
## nuts), body (jams) and art.
##
## Widths are floats on the Camalot scale the rest of the game uses
## (ClimbRack.WIDTHS, GearData.width_min/max): 0 = #0.3 thin fingers,
## 4 = #1 hands, 7 = #4 offwidth. 3.5 is between a #0.75 and a #1.

var id := ""
## Finger | hand | fist | offwidth | chimney | seam | pinscar | flake.
var kind: StringName = &"hand"
## The crack's line, bottom to top, in wall metres.
var points := PackedVector2Array()
## Width at each point (same length as [member points]).
var widths := PackedFloat32Array()
## Indices into [member points] where the crack narrows below the point, so a
## nut slid down from above seats there.
var constrictions := PackedInt32Array()
## 0 parallel-sided, 1 badly flared (cams walk, nuts don't seat).
var flare := 0.0
var tags := PackedStringArray()


## The closest spot on the crack to [param pos]: {t (0..1 along it), pos,
## width, distance, segment}.
func nearest(pos: Vector2) -> Dictionary:
	var best := {"t": 0.0, "pos": points[0] if points.size() > 0 else Vector2.ZERO, "width": widths[0] if widths.size() > 0 else 0.0, "distance": INF, "segment": 0}
	if points.size() < 2:
		if points.size() == 1:
			best.distance = pos.distance_to(points[0])
		return best
	var total := length()
	var run := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		var f := 0.0 if seg <= 0.0 else clampf((pos - a).dot(b - a) / (seg * seg), 0.0, 1.0)
		var p := a.lerp(b, f)
		var d := pos.distance_to(p)
		if d < best.distance:
			best = {"t": (run + seg * f) / total if total > 0.0 else 0.0, "pos": p,
				"width": lerpf(widths[i], widths[i + 1], f), "distance": d, "segment": i}
		run += seg
	return best


## Width at the point closest to [param pos].
func width_near(pos: Vector2) -> float:
	return float(nearest(pos).width)


func length() -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


func to_dict() -> Dictionary:
	var pts := []
	for p in points:
		pts.append([p.x, p.y])
	return {"id": id, "kind": String(kind), "points": pts, "widths": Array(widths),
		"constrictions": Array(constrictions), "flare": flare, "tags": Array(tags)}


static func from_dict(d: Dictionary) -> V2Crack:
	var c := V2Crack.new()
	c.id = str(d.get("id", ""))
	c.kind = StringName(str(d.get("kind", "hand")))
	for p: Variant in d.get("points", []):
		c.points.append(V2Data.vec(p))
	c.widths = PackedFloat32Array(d.get("widths", []))
	while c.widths.size() < c.points.size():
		c.widths.append(c.widths[c.widths.size() - 1] if c.widths.size() > 0 else 4.0)
	c.constrictions = PackedInt32Array(d.get("constrictions", []))
	c.flare = float(d.get("flare", 0.0))
	c.tags = PackedStringArray(d.get("tags", []))
	return c
