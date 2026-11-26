class_name FallsTuning
extends RefCounted
## The numbers behind falls and the partner (thread 7). One place to tune.
## Fable advised the shape of every rule here (2026-11-26).

# --- move risk: a floor-gated sum of named causes, multiplied by pump
## Weights of the base causes (each squared or powered so small flaws stay small).
const W_SECURITY := 0.55
const W_STRAIN := 0.25
const W_HOLD := 0.15
## Pump multiplies the base, never adds: x PUMP_FRESH when fresh, up to
## x (PUMP_FRESH + PUMP_GAIN) near pumped out. Pump below PUMP_FROM barely counts.
const PUMP_FRESH := 0.25
const PUMP_GAIN := 2.65
const PUMP_FROM := 0.45
## Flat adds.
const WET := 0.12
const WET_SMALL := 0.20
const OUT_OF_SEQUENCE := 0.15
const DYNO := 0.10
const DYNO_OVERSHOOT := 0.25
## Below this a move is solid: it never fails (a 2% fall on a jug reads as a bug).
const DEAD_ZONE := 0.08
## The highest risk short of being pumped out.
const RISK_CAP := 0.85
## The "relaxed" assist scales risk by this.
const RELAXED := 0.6

# --- the hidden meter (no streaks of bad luck): each risky move adds its
# risk; you come off when the meter passes a threshold drawn after each fall.
const THRESHOLD_MIN := 0.35
const THRESHOLD_MAX := 1.65
## A solid move calms you: the meter is multiplied by this.
const CALM := 0.6

# --- does a piece hold?
## severity = BASE + FF_WEIGHT * fall factor + DROP_WEIGHT * drop metres
const SEVERITY_BASE := 0.35
const SEVERITY_FF := 0.5
const SEVERITY_DROP := 0.02
## A belay device gives a soft catch; no device is a hard one.
const SOFT_CATCH := 0.85
const HARD_CATCH := 1.1
## Sideways load (a swing over a metre) is harder on a piece.
const SIDEWAYS := 1.1
const SIDEWAYS_FROM_M := 1.0
## Each pop takes energy out of the fall: the next piece sees this much.
const ZIPPER_DAMP := 0.75
## Quality - severity above +BAND holds, below -BAND pops, between is a coin
## weighted by the margin.
const BAND := 0.10
## Pieces that pop (or unclip) before one must hold: story, and other routes.
const MAX_POPS_STORY := 2
const MAX_POPS := 3
## A back-clipped draw lets the rope out in a fall this often when the fall
## pulls across the gate (sideways), else this often.
const BACK_CLIP_ACROSS := 0.35
const BACK_CLIP_STRAIGHT := 0.10
const ACROSS_DX := 0.3
## A cam that held a fall walks (its quality as the partner sees it drops);
## a nut that held gets welded in (better, but slow to clean).
const CAM_WALK := 0.12
const NUT_WELD := 0.05

# --- where you end up
## The rope stretches by this share of the drop, then you bounce back up half.
const STRETCH := 0.06
## How far below a ledge's top you stop (your feet hit it).
const LEDGE_STOP_M := 0.2
## On a story route a would-be ground fall: the partner runs back and takes
## in up to this much rope; you stop at least FLOOR_M off the ground.
const TAKE_IN_M := 3.0
const FLOOR_M := 0.6
## Hanging below the catching piece, you swing toward it; this share of the
## sideways distance stays.
const SWING_LEFT := 0.15
## A fall this long (metres) gets the "big one" line.
const BIG_FALL_M := 6.0

# --- the partner during the lead
## At most one line every this many moves (safety lines may come sooner).
const CHATTER_GAP := 7
## A runout warning when the fall from here would be this long, metres.
const RUNOUT_M := 8.0
## A placement under this (as the partner sees it) gets one "...you sure?".
const JUNK := 0.2
## Chance of a flavour line when the partner has nothing else to say.
const FLAVOUR := 0.08

# --- cleaning at the belay
const CLEAN_MINUTES := 1
const STUCK_MINUTES := 4
const WELDED_MINUTES := 2
## Grade bands, by quality as the partner sees it.
const BOMBER := 0.8
const GOOD := 0.6
const WALKED := 0.4
const MARGINAL := 0.2
