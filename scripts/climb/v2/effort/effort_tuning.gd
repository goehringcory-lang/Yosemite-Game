class_name EffortTuning
extends RefCounted
## Every number the v2 effort system (pump, gas, water, food) runs on, in one
## place for balancing. Starting points from arithmetic (with Fable's advice),
## not yet playtested:
##   - a 5.9 pitch of ~25 moves gets to about half pump with one shake-out;
##   - a 5.11 pitch is ~1.4 pump gross, so you have to find two or three rests.
## Pump scale: 0 fresh .. 1 can't hold on. Gas scale: 1.0 = 100 food energy.

# ------------------------------------------------------------------ moves

## The pump of one move onto an edge (size 0.6, half the weight on the hands,
## no strain) is about BASE * GRIP.edge * (1.4 - 0.8 * 0.6) * 0.6.
const BASE := 0.04
## How hard each hold kind is to hang on to (stances need no hands).
const GRIP := {
	&"jug": 0.5, &"horn": 0.5, &"jam": 0.7, &"edge": 1.0, &"sidepull": 1.0,
	&"undercling": 1.1, &"pocket": 1.2, &"pinch": 1.3, &"gaston": 1.3,
	&"crimp": 1.4, &"sloper": 1.4, &"stance": 0.0,
}
## Size scaling: SIZE_A - SIZE_B * size (a bucket is a third of a crimp's cost).
const SIZE_A := 1.4
const SIZE_B := 0.8
## The hold you move to weighs this much against the one the other hand stays on.
const NEW_HOLD_SHARE := 0.75
## Strain multiplier: STRAIN_A + STRAIN_B * strain.
const STRAIN_A := 0.6
const STRAIN_B := 0.8
## Pulling a hold the wrong way (against its pull) costs up to this many times more.
const WRONG_WAY := 1.5
## Body positions that put weight on the feet (move.to.tags) and what they do to pump.
const POSE := {&"flag": 0.8, &"dropknee": 0.8, &"stem": 0.75, &"heelhook": 0.8,
	&"kneebar": 0.7, &"jam": 0.9, &"layback": 1.2, &"mantle": 0.7}
## The cheapest the pose tags can make a move, as a multiplier.
const POSE_FLOOR := 0.55
## Move tags (body/cruxes).
const MOVE_TAG := {&"dyno": 1.5, &"lunge": 1.3, &"cross": 1.1, &"match": 0.9, &"mantle": 0.6}
## No single move costs more pump than this.
const MOVE_CAP := 0.15
## Easy ground: hands carrying less than this share of the weight on a good
## hold (size at least EASY_SIZE) let the arms recover a little each move.
const EASY_HANDS := 0.35
const EASY_SIZE := 0.6
const EASY_BACK := 0.015

## Gas of a move: GAS_MOVE + GAS_STRAIN * strain; mantles and dynos burn more.
const GAS_MOVE := 0.003
const GAS_STRAIN := 0.006
const GAS_TAG := {&"mantle": 2.0, &"dyno": 1.5, &"lunge": 1.3}
## Gas burned per minute on the wall (resting isn't free: it costs daylight and food).
const GAS_PER_MINUTE := 0.001

# ------------------------------------------------------------------ other actions

## Hanging on while you do something else: this share of the pump the held
## holds would cost a move. Clipping off a jug is nearly free; fiddling a nut
## off a crimp is a choice you pay for.
const HANG_TAX := 0.4
## kind -> [pump, gas, minutes] before the hang tax.
const ACTIONS := {
	&"rope_pull": [0.008, 0.0005, 0], &"clip": [0.006, 0.0, 1], &"offer": [0.012, 0.0005, 1],
	&"place": [0.008, 0.002, 1], &"chalk": [-0.02, 0.0, 0], &"fall": [0.05, 0.02, 3],
	&"eat": [0.0, 0.0, 2], &"rest": [0.0, 0.0, 1], &"special": [0.05, 0.01, 5],
}
## Actions that keep you hanging (the hang tax applies).
const TAXED := [&"rope_pull", &"clip", &"offer", &"place", &"eat"]
## An overhead clip (more than this many arm-lengths) pulls harder.
const OVERHEAD_ARMS := 2
const OVERHEAD_MULT := 1.4
## Each metre of a fall adds this much gas (the scare and the climb back).
const FALL_GAS_PER_M := 0.002

# ------------------------------------------------------------------ deep pump and bands

## Deep pump: this share of every bit of pump gained while already over
## DEEP_FROM sticks as a floor that shake-outs can't clear.
const DEEP_FROM := 0.6
const DEEP_SHARE := 0.3
## Bands (deterministic, read off the body): fresh < WORKING <= working <
## PUMPED <= pumped < BOXED <= boxed. Pumped: small holds get unreliable.
## Boxed: a straining move or any move off a jug will fail.
const WORKING := 0.5
const PUMPED := 0.75
const BOXED := 0.9
## Boxed means a move this strained, or onto a hold this small, fails.
const BOXED_STRAIN := 0.5
const BOXED_SIZE := 0.8

# ------------------------------------------------------------------ rests

## Each rest press shakes out one arm: kind -> [share of the gap to the floor
## won back, a floor of its own]. Belay is a full reset (deep halved).
const RESTS := {
	&"jug": [0.25, 0.25], &"horn": [0.3, 0.2], &"jam": [0.3, 0.2],
	&"stem": [0.45, 0.0], &"kneebar": [0.5, 0.0], &"stance": [0.6, 0.0],
	&"hang": [0.6, 0.0],
}
## The arm still hanging on a jug pays this much each press, so jugs stall out.
const JUG_HOLD_COST := 0.005
## A no-hands stance clears this much deep pump each press.
const STANCE_DEEP := 0.05
## Minutes per rest press, and at the belay.
const REST_MINUTES := 1
const BELAY_MINUTES := 5
## Below this much gas (share of the cap), shake-outs win back only
## LOW_GAS_REST as much and the floor rises by LOW_GAS_FLOOR.
const LOW_GAS := 0.4
const LOW_GAS_REST := 0.6
const LOW_GAS_FLOOR := 0.1
## Out of gas (bonked): pump can't come down below this.
const BONK_FLOOR := 0.5
## Less pump than this to win back and a rest isn't worth taking.
const REST_MIN := 0.01

# ------------------------------------------------------------------ food

## Food classes from the energy number alone.
## Nibble (energy <= NIBBLE): instant, one-handed off a jug or better, and it
## steadies the arms a little.
const NIBBLE := 12
const NIBBLE_STEADY := 0.05
## Trail food (up to MEAL - 1): needs a real rest; half now, half over
## TRAIL_MINUTES. Meal (>= MEAL): two hands (a stance, the rope or the belay),
## arrives over MEAL_MINUTES and makes shake-outs MEAL_REST better for the pitch.
const MEAL := 35
const TRAIL_NOW := 0.5
const TRAIL_MINUTES := 10
const MEAL_MINUTES := 20
const MEAL_REST := 1.2
## A hand needs a hold this good to let go and eat (nibbles).
const EAT_HOLD := 0.8
## Rests good enough for trail food / for a meal.
const TRAIL_RESTS := [&"horn", &"jam", &"stem", &"kneebar", &"stance", &"hang", &"belay"]
const MEAL_RESTS := [&"stance", &"hang", &"belay"]
## Not worth eating unless at least this much of the cap is empty.
const EAT_GAP := 0.08

# ------------------------------------------------------------------ the day

## Each new pitch takes this off the gas cap; after DAY_MINUTES on the wall
## every hour takes HOUR_CAP more. Only camp and sleep put it back.
const PITCH_CAP := 0.01
const DAY_MINUTES := 480
const HOUR_CAP := 0.02
## The cap never goes under this.
const CAP_MIN := 0.5

# ------------------------------------------------------------------ water and weather

## Water drunk per minute in full sun (and a little in the shade).
const WATER_SUN := 0.004
const WATER_SHADE := 0.0008
## Dry: pump costs up to this many times more as water goes from DRY_FROM to 0.
const DRY_MULT := 1.25
const DRY_FROM := 0.5
## Wet rock on small holds, no chalk on sweaty slopers and crimps, cold on jams and crimps.
const WET_MULT := 0.4
const NO_CHALK_MULT := 1.15
const COLD_MULT := 0.2
## Assists: "relaxed" (Settings timing) makes every pump cost this much.
const RELAXED := 0.75
