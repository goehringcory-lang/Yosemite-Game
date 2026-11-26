# Climbing v2: falls and the partner (thread 7)

`falls.gd` (`ClimbFalls`, a `FallSystem`), `falls_tuning.gd` (every number),
`partner_lines.gd` (what the partner says), `falls_overlay.gd` (the partner's
speech pill, the fall tag, the belay card). Test: `tests/climb_v2_falls_test`.
Shot: `tools/shots/climb_v2_falls_shot.tscn` (`SHOT_MODE=fall|belay`).

- **Risk** (`risk`, pure): named causes (feet, strain, hold, pump, wet,
  sequence, dyno). Pump multiplies the base. Under 0.08 a move is solid and
  never fails; pumped out always fails. `top_cause()` names the biggest.
- **The meter** (`falls_now`): risky moves fill a hidden meter; you come off
  when it passes a threshold drawn after each fall (no streaks of bad luck).
  Solid moves calm it.
- **Pieces** (`resolve`): severity from fall factor, drop, catch (belay device
  = soft) and sideways pull; a piece holds if its quality clears severity by
  0.1, pops if it misses by 0.1, and in between it's a weighted coin. Bolts and
  0.8+ pieces always hold. Each pop damps the next piece. Two pops max on story
  routes (three otherwise). Back-clipped draws can let the rope out (more often
  when the fall pulls across the gate); those ids are in `fall.popped` so the
  director unclips them, but the piece isn't marked popped (it's still in the
  rock) and `note.unclipped` lists them.
- **Wear**: a cam that held walks (-0.12 as the partner sees it); a nut that
  held welds in (stuck at the belay). Kept in `note.wear`/`note.welded`, since
  placement quality is gear's field.
- **Landing**: you swing under the catching piece, a ledge in the fall line
  stops you on it, and on a story route a would-be ground fall becomes a hard
  catch just off the ground (the partner takes in). Other routes can deck;
  the climb still goes on.
- **Fall phase**: Space back on, V hang and shake out (repeatable, costs
  minutes), E eat, Esc twice lower off.
- **Partner**: during the lead, safety calls once per top piece (back-clip,
  ledge, deck, runout over 8 m), one ambiguous "you sure?" for junk gear,
  crux encouragement, rare flavour; at most one line per 7 moves except
  safety. After a fall: what happened plus why you came off. At the belay:
  cleans bottom up, grades each piece (bomber, good, walked, tipped,
  marginal, a prayer, stuck, popped, held a fall), full lines for the worst,
  best and any that took a fall; minutes to clean (stuck ones take longer).
- Scratch state is plain data in `session.note(&"falls")`.
- Contract wishes for thread 1 (additive): `V2Fall.cause` and
  `V2Fall.unclipped`, so other threads needn't read falls' notes.
