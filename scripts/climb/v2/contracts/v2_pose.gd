class_name V2Pose
extends RefCounted
## The climber's body on the wall (the BodyPose). Written by body (thread 3);
## the director applies a settled pose after a fall through body's
## [method BodySystem.settle]. Art (thread 9) draws it as given.

const LIMBS: Array[StringName] = [&"lh", &"rh", &"lf", &"rf"]

## lh, rh, lf, rf -> V2Limb.
var limbs := {}
## The hips, wall metres. The body button moves these.
var hip := Vector2(3, 0.9)
## The hand that moves next: &"lh" or &"rh".
var next_hand: StringName = &"rh"
## -1 facing left (side-on), 0 square to the wall, 1 facing right.
var facing := 0
## Body positions the pose is in: flag, dropknee, stem, layback, jam, rest,
## heelhook, kneebar, hang (on the rope), mantle...
var tags := PackedStringArray()


func _init() -> void:
	for l in LIMBS:
		limbs[l] = V2Limb.make(&"free", hip)


func limb(which: StringName) -> V2Limb:
	return limbs[which]


func set_limb(which: StringName, l: V2Limb) -> void:
	limbs[which] = l


## The hand that isn't [member next_hand].
func other_hand() -> StringName:
	return &"lh" if next_hand == &"rh" else &"rh"


## Limbs on the rock (hold or smear).
func contacts() -> int:
	var n := 0
	for l in LIMBS:
		if (limbs[l] as V2Limb).on_rock():
			n += 1
	return n


## The highest hand's height: how far up the pitch you are.
func high_point() -> float:
	return maxf((limbs[&"lh"] as V2Limb).pos.y, (limbs[&"rh"] as V2Limb).pos.y)


## Where the rope ties in (the harness), just above the hips.
func tie_in() -> Vector2:
	return hip + Vector2(0, 0.1)


func copy() -> V2Pose:
	var p := V2Pose.new()
	for l in LIMBS:
		p.limbs[l] = (limbs[l] as V2Limb).copy()
	p.hip = hip
	p.next_hand = next_hand
	p.facing = facing
	p.tags = tags.duplicate()
	return p


func to_dict() -> Dictionary:
	var d := {"hip": [hip.x, hip.y], "next_hand": String(next_hand), "facing": facing, "tags": Array(tags)}
	for l in LIMBS:
		d[String(l)] = (limbs[l] as V2Limb).to_dict()
	return d


static func from_dict(d: Dictionary) -> V2Pose:
	var p := V2Pose.new()
	p.hip = V2Data.vec(d.get("hip", [3, 0.9]))
	p.next_hand = StringName(str(d.get("next_hand", "rh")))
	p.facing = int(d.get("facing", 0))
	p.tags = PackedStringArray(d.get("tags", []))
	for l in LIMBS:
		if d.has(String(l)):
			p.limbs[l] = V2Limb.from_dict(d[String(l)])
	return p
