class_name CruxTuning
extends RefCounted
## Every number the v2 cruxes and big-wall specials use (thread 8), in one
## place so balance passes touch one file. Metres, minutes, and pump/gas as
## shares of a full meter (effort's units).

# --- crux spots
## Half the height of a crux spot made from an old route profile's crux row.
const SPOT_HALF_M := 0.9
## A hip shift this big (metres, from where the body would put the hips by
## itself) counts as "leaning", "low" or "high". The body button moves the
## hips 0.15 m a press, so one press is enough.
const SHIFT_M := 0.12
## Legs count as bent (loaded for a dyno, high feet on an undercling) when
## the hips are this close to the lowest foot, as a share of a straight leg.
const BENT_LEG := 0.8

# --- what a miss does (each kind of mistake has its own consequence)
## Wrong hand: you're crossed up, the next hand is awkward too. Pump-heavy.
const MISS_HAND := {"cost": 0.7, "risk": 0.0, "carry": 0.35}
## Hips wrong (square to a sidepull, high under a sloper): you barn-door.
const MISS_HIP := {"cost": 0.55, "risk": 0.04, "carry": 0.0}
## No foot on a hold where the move needs one: a foot skates.
const MISS_FOOT := {"cost": 0.3, "risk": 0.08, "carry": 0.0}
## Off the authored beta (a zone's "sequence").
const MISS_BETA := {"cost": 0.45, "risk": 0.0, "carry": 0.0}
## crux_cost never goes past this, so a botched move hurts but can be paid.
const COST_CAP := 2.6
## A crux move on beta still costs a bit more than climbing below it.
const ON_BETA_COST := 1.15

# --- dynos: near-deterministic, decided by the ghost you can see
## Base chance of missing a dyno you launch well (feet on, legs bent).
const DYNO_BASE_RISK := 0.03
## Extra miss chance from pump (times pump squared) and a poor launch.
const DYNO_PUMP_RISK := 0.35
const DYNO_INSECURE_RISK := 0.25
## A dyno thrown from straight legs or a smear.
const DYNO_BAD_LAUNCH_RISK := 0.3

# --- King Swing / pendulum
## Rope you can lower out to swing from, beyond what reaches the crack.
const SWING_LOWER_OPTIONS := [0.0, 2.0, 4.0]
const SWING_LOWER_MINUTES := 4
## Each swing keeps this share of its reach, and each kick adds to it.
const SWING_DECAY := 0.72
const SWING_KICK_M := 1.6
## Legs tire: each kick is this much weaker than the one before.
const SWING_TIRE := 0.85
## You can grab a hold this far from the peak of a swing.
const SWING_GRAB_M := 0.75
## Overshooting the crack by more than this slams you into the corner.
const SWING_SLAM_M := 1.1
const SWING_KICK_COST := [0.0, 0.025, 2]
const SWING_GRAB_COST := [0.06, 0.005, 1]
const SWING_SLAM_COST := [0.12, 0.02, 3]
const SWING_MISS_COST := [0.1, 0.01, 2]
## Kick-off spots by footing: edge, flake, crystal, dirty, polished, wet.
const FOOTING := {"edge": 1.0, "flake": 0.85, "crystal": 0.75, "dirty": 0.55, "polished": 0.4, "wet": 0.2}

# --- nailing
## Iron for a hard-aid pitch (if the rack carries none): id -> [name, min, max width, count].
## Widths are on the Camalot scale (0 = #0.3): pins live below it, so they
## go negative.
const IRON := {
	"knifeblade": ["Knifeblade", -3.0, -1.6, 2],
	"lost_arrow": ["Lost Arrow", -1.8, -0.4, 2],
	"baby_angle": ["Baby angle", -0.6, 0.8, 2],
	"angle": ["Angle", 0.6, 2.2, 1],
}
## Depth a tap drives a pin: snug, too small (slides), too big (stalls).
const TAP_SNUG := 0.36
const TAP_LOOSE := 0.5
const TAP_TIGHT := 0.22
## A too-big pin stops this far in.
const TIGHT_STALL := 0.45
## A snug pin rings from this depth.
const RING_DEPTH := 0.68
const TAP_COST := [0.012, 0.002, 1]
const TEST_COST := [0.01, 0.0, 1]
const STEP_COST := [0.02, 0.006, 3]
## Stepping up on a pin that pops: you drop onto your last piece.
const POP_DROP_COST := [0.12, 0.015, 6]
## Taps before a pin can't go further in any case.
const MAX_TAPS := 4

# --- hauling (a few decisions per haul, not fifty presses)
## Gas per metre hauled for a bag of weight 1.
const HAUL_GAS_PER_M := 0.0016
const HAUL_MIN_PER_M := 0.25
const FLICK_COST := [0.06, 0.004, 1]
const BACK_OFF_COST := [0.0, 0.01, 6]
const PARTNER_FREE_MIN := 14
## A flick frees a lip if lip size * bag weight is under this.
const FLICK_LIMIT := 1.4

# --- chimneys and offwidths
## The furthest a half of you can move in one shuffle.
const WORM_REACH_M := 0.8
## Lock spots offered along the crack, this far apart.
const WORM_SPOT_M := 0.2
## Below this lock quality the move slips back.
const WORM_SLIP_BELOW := 0.3
const WORM_SLIP_M := 0.3
## Gas (legs, back) and pump per metre moved, scaled up by a poor lock.
const WORM_GAS_PER_M := 0.018
const WORM_PUMP_PER_M := 0.02
## Having the wrong side in (against the crack's lean).
const WORM_WRONG_SIDE := 1.45
## Lock techniques by crack width (Camalot scale; 7 = #4). [name, best, half-width].
## The bands overlap, so some lock always works where the crack is a
## sensible width; a flare past them, or a spot between their best widths,
## is where you slip.
const LOCKS_UPPER := [["fist jam", 5.8, 1.1], ["hand stack", 7.2, 1.2], ["arm bar", 8.6, 1.3], ["chicken wing", 9.9, 1.3], ["back and palms", 12.0, 2.2]]
const LOCKS_LOWER := [["heel-toe", 7.0, 1.4], ["knee bar", 8.8, 1.4], ["butterfly", 10.0, 1.3], ["back and foot", 12.0, 2.4]]
