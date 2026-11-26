# Climbing v2: pump, gas and food (thread 4)

`effort.gd` (`EffortV2`) is the real `EffortSystem`. Numbers live in
`effort_tuning.gd`; body signs in `effort_signs.gd`; the stand-in drawing of
them in `effort_overlay.gd`. Test: `tests/climb_v2_effort_test.tscn`. Pictures:
`xvfb-run -a godot --path . res://tools/shots/climb_v2_effort_shot.tscn`.

## The rules in one screen

- **Nothing drains in real time.** Moves and actions have prices; the ghost
  of a move can show what it will leave you with before you commit.
- **Pump prices how you hang on, not how many moves you make:** hold kind
  (jug 0.5 … crimp/sloper 1.4) × size × the share of weight on the hands
  (feet on is cheap, feet cut is dear) × stretch × pulling the hold the wrong
  way (up to ×1.5) × body positions (flag, drop-knee, stem, heel hook,
  kneebar take weight onto the feet) × move tags (dyno ×1.5…). Capped at
  0.15 a move. Easy ground with the weight on your feet gives a little back.
- **The hang tax:** clipping, pulling rope, offering and placing gear cost
  0.4× what the holds you're hanging on cost. Clip off the jug, not the crimp.
  Overhead pulls (3+ arm-lengths) cost ×1.4.
- **Bands, no hidden dice:** fresh < 0.5 ≤ working < 0.75 ≤ pumped (small holds
  unreliable: `hold_factor()`) < 0.9 ≤ boxed (a straining move or any move off
  a jug fails: `will_fail(move)`, which the ghost shows). Pump never makes
  moves cost more; it changes what happens.
- **Deep pump:** 30% of pump gained while over 0.6 sticks as a floor that
  shake-outs can't clear. Only a no-hands stance (−0.05 a press), the rope or
  the belay works it off.
- **Rests:** each press shakes one arm for a minute and wins back a share of
  the gap to the floor (jug 25%, horn/jam 30%, stem 45%, kneebar 50%, stance
  and the rope 60%), so returns fall off by themselves. The arm still on a
  jug pays, so jugs stall around 0.25. The belay clears everything but half
  the deep pump and tops up water.
- **Gas** (1.0 = 100 food energy) pays for moves (0.003 + 0.006 × strain),
  minutes (0.001 each, so long rests cost daylight and food) and falls. Low
  gas (under 40%) makes rests win back 60% as much and raises the floor 0.1;
  out of gas the arms can't come back below half. It never makes moves dearer.
- **Food by its energy:** nibbles (≤12: berries) are instant, one-handed off
  a hold at least jug-sized, and steady the arms (−0.05 pump). Trail food
  (13–34) needs a real rest (not a plain jug): half now, half over ten
  minutes. Meals (35+) need both hands free (stance, the rope, the belay),
  arrive over twenty minutes and make every shake-out 20% better for the
  pitch. Gas over the cap is wasted. `best_food()` picks the biggest food
  that fits the gap and can be eaten where you are.
- **The day:** the gas cap drops 0.01 each pitch and 0.02 an hour after eight
  hours on the wall (camp and sleep put it back, outside the climb).
- **Water** drains in the sun (0.004 a minute in full sun); dry arms pump up
  to ×1.25. Refilled at belays.
- **Weather and kit:** wet rock makes small holds up to ×1.4, no chalk makes
  crimps/slopers/pinches ×1.15, cold makes crimps and jams up to ×1.2. The
  "relaxed" assist makes pump ×0.75.

## For other threads

- **Signs** for art, look and sound (thread 9, 10): `session.notes.effort.signs`
  (band, tremble, chicken_wing, stiff, shake_want, rest_left, breath, hip_sag,
  sweat, chalk_want, hunger, thirst, bonked, steadied), refreshed on every
  `effort_changed`. `sys.effort.ghost_signs(move)` gives the same for a
  previewed move plus `fail` and `unreliable`. The shaking arm is
  `session.notes.effort.arm`. If the climber view has `draws_effort_signs()`
  returning true, the stand-in overlay stands down.
- **Falls** (thread 7): `will_fail(move)`, `hold_factor()`, `band()`,
  `pumped_out()` (pump at 1).
- **Bots / solver** (thread 10): `rest_gain(kind)`, `rest_left()`,
  `pump_after(move)`, `can_eat_here(food)`, `food_class(food)`.
