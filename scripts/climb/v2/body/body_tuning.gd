class_name BodyTuning
extends RefCounted
## Every number the v2 body (thread 3) uses, in one place. Distances are wall
## metres; strain and security are 0..1 (see V2Move).
##
## The strain tiers are shared on purpose: art trembles the ghost by them and
## effort can price by them, so what the ghost shows is what the move costs.

## Strain below CALM reads solid; CALM..BREAKING trembles; above BREAKING the
## limb is visibly failing.
const STRAIN_CALM := 0.35
const STRAIN_BREAKING := 0.7

# ---- the body
## Shoulders sit this far either side of the spine.
const SHOULDER_HALF := 0.18
## Shoulder to fingertips with the shoulder blade and a little lean: reach 1.0.
const REACH_M := ClimbV2.ARM_M + 0.2
## Hip to sole, with the knee straight and the hip rolled in.
const LEG_REACH_M := ClimbV2.LEG_M + 0.05
## A natural hang: shoulders this far under the middle of the hands.
const HANG_DROP := 0.5
## Standing up for a move: the staying hand sits this far above its shoulder.
const STAY_ABOVE := 0.25

# ---- reach bands (reach is shoulder-to-hold / REACH_M)
## Above 1.0 on a good hold is a lunge (a deadpoint); above LUNGE_MAX it has
## to be a dyno, thrown from low hips; above DYNO_MAX nothing gets there.
const LUNGE_MAX := 1.15
const DYNO_MAX := 1.45
const LUNGE_MIN_SIZE := 0.5
const DYNO_MIN_SIZE := 0.55
## How low the hips must be sitting (hip shift y) to throw a dyno.
const DYNO_PRELOAD := -0.3
## Holds below the hips by more than this aren't hand holds (except a mantle).
const BELOW_HIP := 0.2
## Holds this far beyond reach still show in the aim (as "can't").
const SHOW_MAX := DYNO_MAX + 0.1

# ---- the hip button: a lattice in wall space
const HIP_STEP := 0.15
const HIP_MIN := Vector2(-0.3, -0.45)
const HIP_MAX := Vector2(0.3, 0.3)

# ---- techniques
## Turning the hips toward the target lends the reaching shoulder this much.
const TURN_REACH := 0.12
const BACKSTEP_REACH := 0.07
## A foothold at or above hip - this is a high step.
const HIGH_STEP := 0.35
## Knee height under the hip (a drop-knee wants the outside foot above it).
const KNEE_DROP := 0.5
## Feet this far apart around the hips are a stem.
const STEM_SPAN := 1.15
## A hold pulls sideways when |pull.x| is at least this (laybacks).
const SIDE_PULL := 0.6
## A hand holds the body from swinging only if its pull lines up this well.
const ANCHOR_ALIGN := 0.35
## The centre of mass may sit this far outside the support before it swings.
const BALANCE_SLACK := 0.08
## A flag pulls the centre of mass back by up to this.
const FLAG_COUNTER := 0.1
## The reaching arm and lean move the centre of mass this share of the way
## toward the target hold.
const REACH_LEAN := 0.2
## A smear on vertical rock (better on slab, nothing on overhangs).
const SMEAR_VERTICAL := 0.25
## A kept foot scores this much over a new one (feet persist between moves).
const FOOT_KEEP := 0.25
## Matching needs a hold at least this big.
const MATCH_SIZE := 0.45

# ---- strain terms
const STRAIN_REACH_FROM := 0.75
const STRAIN_REACH := 1.2
const STRAIN_LOCKOFF := 0.6
const STRAIN_CROSS := 0.2
const STRAIN_HIGH_STEP := 0.06
## A high step takes this share of the lock-off off the staying arm.
const HIGH_STEP_LOCKOFF := 0.35
const STRAIN_BARN := 1.2
const STRAIN_FEET_CUT := 0.3
const STRAIN_DROPKNEE := 0.05
const STRAIN_BACKSTEP := 0.04
## The staying arm starts to lock off when its hand is less than LOCKOFF_FROM
## above its shoulder, and is fully locked LOCKOFF_SPAN lower.
const LOCKOFF_FROM := 0.35
const LOCKOFF_SPAN := 0.45
const STRAIN_STEEP := 0.15

# ---- security weights
const SEC_HOLD_ON := 0.4
const SEC_FEET := 0.3
const SEC_TARGET := 0.3
const SEC_BARN := 1.5

## Share of the body's weight the feet take, by wall angle (degrees past
## vertical; negative is slab): [angle, share].
const FEET_SHARE := [[-30.0, 0.75], [0.0, 0.55], [30.0, 0.35], [60.0, 0.18], [90.0, 0.1]]

## How well a hand jams by crack width (Camalot scale): [width, quality].
const JAM := [[0.0, 0.1], [0.6, 0.3], [1.2, 0.7], [2.0, 0.75], [2.7, 0.45], [3.2, 0.6],
	[3.8, 0.95], [4.8, 0.95], [5.3, 0.7], [6.0, 0.7], [6.6, 0.35], [7.5, 0.25]]
## And a foot (toes jam best in hand-size and wider; fingers barely take a toe).
const FOOT_JAM := [[0.0, 0.0], [1.5, 0.1], [2.5, 0.35], [3.5, 0.7], [4.5, 0.9], [6.0, 0.85], [7.5, 0.6]]


## Piecewise-linear lookup in a [[x, y], ...] table.
static func curve(table: Array, x: float) -> float:
	if x <= float(table[0][0]):
		return float(table[0][1])
	for i in range(1, table.size()):
		var a: Array = table[i - 1]
		var b: Array = table[i]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(table[table.size() - 1][1])


## "finger", "hand", "fist" or "offwidth" for a jam at [param width].
static func jam_kind(width: float) -> StringName:
	if width <= 2.6:
		return &"finger"
	if width <= 5.2:
		return &"hand"
	if width <= 6.3:
		return &"fist"
	return &"offwidth"
