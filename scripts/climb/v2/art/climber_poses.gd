class_name ClimberPoses
extends RefCounted
## A library of body positions for the climber art: the pose sheet
## (tools/shots/climber_v2_sheet.tscn) draws them, and the art test checks
## every one keeps its hands and feet on their holds. Each is a V2Pose built
## the way a body system would (fully resolved contacts) plus the holds under
## it, so the art can be judged without any other thread's system.
##
## Positions are metres from the hips at (0, 0).

## Name -> [hips, {limb: [kind, x, y, hold kind]}, facing, tags, pump].
const POSES := {
	"rest on jugs": [Vector2(0, 0), {
		"lh": ["hold", -0.24, 1.18, "jug"], "rh": ["hold", 0.26, 1.14, "jug"],
		"lf": ["hold", -0.22, -0.74, "edge"], "rf": ["hold", 0.24, -0.66, "edge"]}, 0, [], 0.1],
	"big reach": [Vector2(0.05, 0.1), {
		"lh": ["hold", -0.22, 0.86, "edge"], "rh": ["hold", 0.34, 1.42, "crimp"],
		"lf": ["hold", -0.24, -0.62, "edge"], "rf": ["hold", 0.3, -0.24, "edge"]}, 0, [], 0.3],
	"flag": [Vector2(-0.05, 0), {
		"lh": ["hold", -0.12, 1.2, "crimp"], "rh": ["hold", 0.22, 0.98, "sidepull"],
		"lf": ["free", -0.72, -0.5, ""], "rf": ["hold", 0.08, -0.76, "edge"]}, 1, ["flag"], 0.35],
	"stem": [Vector2(0, -0.05), {
		"lh": ["hold", -0.38, 0.9, "sidepull"], "rh": ["hold", 0.38, 0.86, "gaston"],
		"lf": ["smear", -0.62, -0.38, ""], "rf": ["smear", 0.62, -0.42, ""]}, 0, ["stem", "rest"], 0.2],
	"layback": [Vector2(-0.22, 0), {
		"lh": ["hold", 0.28, 1.0, "sidepull"], "rh": ["hold", 0.3, 0.62, "sidepull"],
		"lf": ["smear", 0.16, -0.62, ""], "rf": ["smear", 0.3, -0.36, ""]}, 1, ["layback"], 0.55],
	"drop knee": [Vector2(0.05, 0), {
		"lh": ["hold", -0.3, 1.16, "edge"], "rh": ["hold", 0.12, 1.3, "pinch"],
		"lf": ["hold", -0.42, -0.22, "edge"], "rf": ["hold", 0.3, -0.6, "edge"]}, -1, ["dropknee"], 0.3],
	"heel hook": [Vector2(-0.1, 0.05), {
		"lh": ["hold", -0.24, 1.12, "jug"], "rh": ["hold", 0.3, 1.0, "edge"],
		"lf": ["hold", -0.26, -0.66, "edge"], "rf": ["hold", 0.58, 0.34, "jug"]}, 0, ["heelhook"], 0.4],
	"mantle": [Vector2(0, 0.25), {
		"lh": ["hold", -0.22, 0.42, "stance"], "rh": ["hold", 0.22, 0.4, "stance"],
		"lf": ["smear", -0.2, -0.62, ""], "rf": ["hold", 0.3, -0.08, "edge"]}, 0, ["mantle"], 0.4],
	"hand jams": [Vector2(0.02, 0), {
		"lh": ["hold", 0.02, 0.9, "jam"], "rh": ["hold", 0.04, 1.28, "jam"],
		"lf": ["hold", -0.02, -0.46, "jam"], "rf": ["hold", 0.06, -0.8, "jam"]}, 0, ["jam"], 0.3],
	"clipping": [Vector2(0, 0), {
		"lh": ["hold", -0.22, 1.18, "jug"], "rh": ["rope", 0.14, 1.32, ""],
		"lf": ["hold", -0.22, -0.72, "edge"], "rf": ["hold", 0.22, -0.66, "edge"]}, 0, [], 0.3],
	"placing a cam": [Vector2(0, 0), {
		"lh": ["hold", -0.26, 1.12, "jug"], "rh": ["gear", 0.3, 1.02, ""],
		"lf": ["hold", -0.2, -0.72, "edge"], "rf": ["hold", 0.24, -0.62, "edge"]}, 0, [], 0.35],
	"chalking": [Vector2(0, 0), {
		"lh": ["hold", -0.2, 1.2, "jug"], "rh": ["chalk", 0.0, -0.06, ""],
		"lf": ["hold", -0.22, -0.72, "edge"], "rf": ["hold", 0.22, -0.68, "edge"]}, 0, [], 0.2],
	"pumped": [Vector2(0, -0.08), {
		"lh": ["hold", -0.26, 1.08, "crimp"], "rh": ["hold", 0.24, 1.04, "sloper"],
		"lf": ["smear", -0.24, -0.72, ""], "rf": ["hold", 0.22, -0.68, "edge"]}, 0, [], 0.95],
	"hanging on the rope": [Vector2(0, 0), {
		"lh": ["free", 0, 0, ""], "rh": ["free", 0, 0, ""],
		"lf": ["free", 0, 0, ""], "rf": ["free", 0, 0, ""]}, 0, ["hang"], 0.5],
}


## The names, in sheet order.
static func names() -> Array:
	return POSES.keys()


## Pose [param pose_name] with its hips at [param at] (wall metres).
static func pose(pose_name: String, at := Vector2(3, 2)) -> V2Pose:
	var spec: Array = POSES[pose_name]
	var p := V2Pose.new()
	p.hip = at + (spec[0] as Vector2)
	var limbs: Dictionary = spec[1]
	for l in V2Pose.LIMBS:
		var d: Array = limbs[String(l)]
		var kind := StringName(d[0])
		var pos := at + Vector2(d[1], d[2])
		if kind == &"free" and Vector2(d[1], d[2]) == Vector2.ZERO:
			pos = p.hip
		p.set_limb(l, V2Limb.make(kind, pos, _hold_id(pose_name, l) if kind == &"hold" else ""))
	p.facing = int(spec[2])
	p.tags = PackedStringArray(spec[3])
	p.next_hand = &"rh"
	return p


## The holds pose [param pose_name] stands on, as V2Hold dicts.
static func holds(pose_name: String, at := Vector2(3, 2)) -> Array[Dictionary]:
	var spec: Array = POSES[pose_name]
	var out: Array[Dictionary] = []
	var limbs: Dictionary = spec[1]
	for l in V2Pose.LIMBS:
		var d: Array = limbs[String(l)]
		if d[0] == "hold":
			var hand := l == &"lh" or l == &"rh"
			out.append({"id": _hold_id(pose_name, l), "pos": [at.x + d[1], at.y + d[2]], "kind": d[3],
				"size": 0.6, "hand": hand, "foot": not hand})
	return out


static func pump(pose_name: String) -> float:
	return float((POSES[pose_name] as Array)[4])


static func _hold_id(pose_name: String, l: StringName) -> String:
	return "%s_%s" % [pose_name.replace(" ", "_"), l]


## A session holding every pose's holds on one wall, for the sheet and tests.
static func session_for(pose_names: Array, spacing := 2.6, y := 2.0) -> ClimbSession:
	var s := ClimbSession.new()
	var holds_all: Array = []
	for i in pose_names.size():
		holds_all.append_array(holds(pose_names[i], Vector2(1.5 + i * spacing, y)))
	s.wall = V2Wall.from_dict({"size": [pose_names.size() * spacing + 3.0, 6.0], "start": [1.5, 0.0], "holds": holds_all})
	s.wall._index()
	s.rack.items.assign([
		{"id": "cam_075", "kind": "cam", "width_min": 3, "width_max": 3, "count": 1},
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 1},
		{"id": "cam_2", "kind": "cam", "width_min": 5, "width_max": 5, "count": 1},
		{"id": "cam_3", "kind": "cam", "width_min": 6, "width_max": 6, "count": 1},
		{"id": "nuts", "kind": "nut", "width_min": 1, "width_max": 3, "count": 4},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 6},
		{"id": "sling", "kind": "sling", "width_min": -1, "width_max": -1, "count": 2},
	])
	return s
