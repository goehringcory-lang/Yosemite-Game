class_name ClimberRig
extends RefCounted
## The climber's skeleton, solved from where the hips are and where each hand
## and foot is (wall metres, y up). Pure: the same inputs always give the same
## joints, so the ghost, the live climber and the tests agree.
##
## Contacts are sacred: a hand or foot on the rock is drawn exactly where the
## pose puts it. If a limb can't reach, the chest leans and stretches toward
## it first (up to [constant CHEST_GIVE]) and the bones stretch up to
## [constant STRETCH]; only past that does the limb fall short.
##
## Bones follow ClimbV2's body: TORSO_M hip to shoulders, ARM_M shoulder to
## fingertips, LEG_M hip to sole.
##
## Elbows and knees bend the way [member bend] says (-1..1 per limb, chosen by
## [method bend_wanted] and eased by the animator so they never flip).

const UPPER_ARM := 0.31
const FOREARM := ClimbV2.ARM_M - UPPER_ARM
const THIGH := 0.46
const SHIN := ClimbV2.LEG_M - THIGH
const SHOULDER_HALF := 0.19
const HIP_HALF := 0.12
const NECK := 0.07
## A touch bigger than life: from behind, the head is what reads first.
const HEAD_R := 0.132
## How far bones may stretch, and how far the chest may slide, to keep a
## contact on its hold.
const STRETCH := 1.04
const CHEST_GIVE := 0.1
const SIDE := {&"lh": -1.0, &"rh": 1.0, &"lf": -1.0, &"rf": 1.0}

# --- inputs
var hip := Vector2.ZERO
## lh, rh, lf, rf -> where the hand or foot is.
var ends := {}
## -1 turned to the left, 0 square to the wall, 1 turned to the right.
var twist := 0.0
## lh, rh, lf, rf -> -1..1: which way the elbow or knee bends (see bend_wanted).
var bend := {}
## Where the head looks (wall metres).
var look := Vector2(0, 10)
## Breath, 0..1: the ribs and shoulders rise with it.
var breath := 0.0
## Shoulders up to the ears (pump), 0..1.
var hunch := 0.0
## Extra joint offsets (tremor, chicken wings): lh, rh, lf, rf -> Vector2
## added to the elbow or knee after solving.
var joint_push := {}
## Leans the torso back from upright, radians (a fall's peel, a hang).
var torso_tilt := 0.0

# --- outputs
var pelvis_l := Vector2.ZERO
var pelvis_r := Vector2.ZERO
var chest := Vector2.ZERO
var shoulder_l := Vector2.ZERO
var shoulder_r := Vector2.ZERO
var neck := Vector2.ZERO
var head := Vector2.ZERO
## The torso's up direction (unit).
var up := Vector2.UP
## lh, rh, lf, rf -> elbow or knee.
var joint := {}
## lh, rh, lf, rf -> the drawn hand or foot (the contact, or as near as the
## limb gets).
var tip := {}
## How far the head is turned (-1 left .. 1 right) and tipped (-1 down .. 1 up).
var head_yaw := 0.0
var head_pitch := 0.0


func _init() -> void:
	for l in V2Pose.LIMBS:
		ends[l] = Vector2.ZERO
		bend[l] = 1.0
		joint_push[l] = Vector2.ZERO


## A rig for [param pose] as it is, with the bends it wants (the ghost and
## the first frame of a pitch).
static func from_pose(pose: V2Pose) -> ClimberRig:
	var r := ClimberRig.new()
	r.hip = pose.hip
	for l in V2Pose.LIMBS:
		r.ends[l] = (pose.limb(l) as V2Limb).pos
	r.ends = settle_free(pose, r.ends)
	r.twist = float(pose.facing)
	for l in V2Pose.LIMBS:
		r.bend[l] = r.bend_wanted(l, pose.tags)
	r.look = r.hip + Vector2(0, 1.6)
	r.solve()
	return r


## Free limbs parked on the hips (a stub's hang) hang naturally instead:
## hands on the rope above the knot, feet dangling. Anything a body system
## places away from the hips is drawn where it is.
static func settle_free(pose: V2Pose, at: Dictionary) -> Dictionary:
	var out := at.duplicate()
	for l in V2Pose.LIMBS:
		var limb: V2Limb = pose.limb(l)
		if limb.kind != &"free" or limb.pos.distance_to(pose.hip) > 0.2:
			continue
		var side: float = SIDE[l]
		if l == &"lh" or l == &"rh":
			# Both hands on the rope above the knot, one over the other.
			out[l] = pose.hip + Vector2(side * 0.05, 0.74 + (0.1 if side > 0 else 0.0))
		else:
			out[l] = pose.hip + Vector2(side * 0.16, -0.82)
	return out


## Which way limb [param l] wants to bend, as -1 or 1: elbows down and out
## (up and back when the hand presses below the shoulder, a mantle); knees
## out like a frog, up on a high step, in and down on a drop-knee.
func bend_wanted(l: StringName, tags: PackedStringArray) -> float:
	var side: float = SIDE[l]
	var root := _root_guess(l)
	var target: Vector2 = ends[l]
	var pole: Vector2
	if l == &"lh" or l == &"rh":
		if target.y < root.y - 0.15 and not tags.has("hang"):
			pole = root + Vector2(side * 0.3, 0.25)
		else:
			pole = root + Vector2(side * 0.35, -0.3)
	else:
		var turned_in := twist != 0.0 and signf(twist) == side
		if tags.has("dropknee") and (turned_in or twist == 0.0 and target.y > hip.y - 0.55):
			pole = root + Vector2(-side * 0.25, -0.45)
		elif target.y > root.y - 0.3 or tags.has("kneebar") or tags.has("heelhook"):
			pole = root + Vector2(side * 0.3, 0.35)
		else:
			pole = root + Vector2(side * 0.4, -0.15)
	var d := target - root
	var c := d.x * (pole - root).y - d.y * (pole - root).x
	return 1.0 if c >= 0.0 else -1.0


func _root_guess(l: StringName) -> Vector2:
	var side: float = SIDE[l]
	if l == &"lh" or l == &"rh":
		return hip + Vector2(side * SHOULDER_HALF, ClimbV2.TORSO_M)
	return hip + Vector2(side * HIP_HALF, -0.04)


## Works out every joint from the inputs.
func solve() -> void:
	var hl: Vector2 = ends[&"lh"]
	var hr: Vector2 = ends[&"rh"]
	# The torso leans toward the hands, more when they're far to one side
	# (a layback or a long sidepull), never past ~35 degrees.
	var reach_to := (hl + hr) * 0.5 - hip
	var lean := 0.0
	if reach_to.y > 0.25:
		lean = clampf(atan2(reach_to.x, reach_to.y), -0.62, 0.62) * 0.55
	elif reach_to.length() > 0.05:
		lean = clampf(reach_to.x * 0.4, -0.25, 0.25)
	lean += torso_tilt
	up = Vector2(sin(lean), cos(lean))
	var across := Vector2(up.y, -up.x)
	var rib_shift := across * twist * 0.025
	var length := ClimbV2.TORSO_M * (1.0 - hunch * 0.03) + breath * 0.012
	chest = hip + up * length + rib_shift
	# Let the chest come to a hand that's out of reach.
	for hand: StringName in [&"lh", &"rh"]:
		var sh: Vector2 = chest + across * float(SIDE[hand]) * SHOULDER_HALF
		var short: float = (ends[hand] as Vector2).distance_to(sh) - ClimbV2.ARM_M * 0.98
		if short > 0.0:
			chest += ((ends[hand] as Vector2) - sh).normalized() * minf(short, CHEST_GIVE)
	up = (chest - hip).normalized() if chest.distance_to(hip) > 0.01 else Vector2.UP
	across = Vector2(up.y, -up.x)
	var wide := 1.0 - 0.32 * absf(twist)
	var lift := up * (hunch * 0.035 + breath * 0.008)
	shoulder_l = chest - across * SHOULDER_HALF * wide * (1.0 + 0.12 * maxf(twist, 0.0)) + lift
	shoulder_r = chest + across * SHOULDER_HALF * wide * (1.0 + 0.12 * maxf(-twist, 0.0)) + lift
	var hips_up := (Vector2.UP + up).normalized()
	var hips_across := Vector2(hips_up.y, -hips_up.x)
	var hip_wide := 1.0 - 0.38 * absf(twist)
	var pelvis_shift := hips_across * -twist * 0.02
	pelvis_l = hip - hips_across * HIP_HALF * hip_wide + pelvis_shift - hips_up * 0.04
	pelvis_r = hip + hips_across * HIP_HALF * hip_wide + pelvis_shift - hips_up * 0.04
	neck = chest + up * (NECK - hunch * 0.03)
	var to_look := look - neck
	head_yaw = clampf(to_look.x / 1.2, -1.0, 1.0) * 0.8 + twist * 0.25
	head_pitch = clampf(to_look.y / 1.5, -1.0, 1.0)
	head = neck + up * (HEAD_R + 0.02) + Vector2(head_yaw * 0.015, head_pitch * 0.01)
	for l in V2Pose.LIMBS:
		var root := _root(l)
		var lengths := _lengths(l)
		var solved := two_bone(root, ends[l], lengths.x, lengths.y, bend[l])
		joint[l] = solved[0] + joint_push[l]
		tip[l] = solved[1]


func _root(l: StringName) -> Vector2:
	match l:
		&"lh":
			return shoulder_l
		&"rh":
			return shoulder_r
		&"lf":
			return pelvis_l
	return pelvis_r


func _lengths(l: StringName) -> Vector2:
	if l == &"lh" or l == &"rh":
		return Vector2(UPPER_ARM, FOREARM)
	return Vector2(THIGH, SHIN)


## Two-bone reach from [param a] to [param t]: returns [joint, end]. [param
## side] -1..1 blends between the two ways the joint can bend (1 = the joint
## on the left of the line a -> t), so easing it never pops. The bones stretch
## up to STRETCH before the end falls short of the target.
static func two_bone(a: Vector2, t: Vector2, l1: float, l2: float, side: float) -> Array[Vector2]:
	var d := t - a
	var dist := d.length()
	if dist < 0.0001:
		return [a + Vector2(0, -l1), a]
	var full := (l1 + l2) * STRETCH
	var end := t
	if dist > full:
		end = a + d / dist * full
		dist = full
	var k := minf(dist / (l1 + l2), STRETCH)
	var s1 := l1 * maxf(k, 1.0)
	var s2 := l2 * maxf(k, 1.0)
	var dir := (end - a) / dist
	# Closer than the bones can fold: solve as if just far enough.
	dist = maxf(dist, absf(s1 - s2) + 0.005)
	var along := (s1 * s1 - s2 * s2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(s1 * s1 - along * along, 0.0))
	var n := Vector2(-dir.y, dir.x)
	var base := a + dir * along
	var j_left := base + n * h
	var j_right := base - n * h
	var w := clampf((side + 1.0) * 0.5, 0.0, 1.0)
	# Ease the blend so most of the turn happens in the middle.
	w = w * w * (3.0 - 2.0 * w)
	return [j_right.lerp(j_left, w), end]


## True if every limb that can reach its contact does, to [param tolerance]
## metres (for tests).
func contacts_met(tolerance := 0.002) -> bool:
	for l in V2Pose.LIMBS:
		if (tip[l] as Vector2).distance_to(ends[l]) > tolerance:
			return false
	return true


## Every bone's length now, for tests: name -> metres.
func bone_lengths() -> Dictionary:
	var out := {}
	for l in V2Pose.LIMBS:
		out[String(l) + "_upper"] = _root(l).distance_to(joint[l] - joint_push[l])
		out[String(l) + "_lower"] = (joint[l] - joint_push[l]).distance_to(tip[l])
	return out
