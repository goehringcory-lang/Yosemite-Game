# Climbing v2: trad gear (thread 6)

`gear.gd` (TradGear, a GearSystem) and `gear_overlay.gd` (TradGearOverlay).
Owner: thread 6. Test: `tests/climb_v2_gear_test`. Shot:
`tools/shots/climb_v2_gear_shot.tscn` (SHOT_PIECE, SHOT_OFFER, SHOT_SLIDE,
SHOT_KNOW, SHOT_PUMP).

## How it plays ("Feel it")

1. **Rack** at a crack opens the place phase. The free hand goes to the crack;
   Up/Down slides the spot along it (within reach), Swap changes crack,
   Left/Right walks along the harness in gear-tent order, then any old pin to
   tug and any stuck piece to work free.
2. **Before paying anything** the overlay shows the selected piece held up
   beside the crack at true size: eyeball it.
3. **Space offers it** (pump, through effort's "offer" price). A cam shows its
   lobes: upright = over-cammed, a V = good, flat on the tips = tipped, too big
   won't go in, too small rattles out. A nut slides down until the crack
   pinches it: snug in a real narrowing, "only just" in a parallel crack its
   size, or it slides through.
4. **Space again places it** (a nut is tugged to set) and opens rope's clip.
   Esc always puts it back for free.

No bar, number or colour grades a piece. Quality stays hidden on the
`V2Piece`; the next fall and the partner's words at the belay reveal it.

## Rules and why (Fable's review, 2026-11-26)

- Real Camalot C4 ranges in mm (`CAM_MM`), width scale whole numbers at each
  cam's middle (`WIDTH_MM`), so neighbouring sizes overlap like on the rock
  and a full rack has a good cam for every width (tested).
- Holding is a broad plateau (e 0.2..0.7) with soft shoulders, not a narrow
  sweet spot. Over-cammed holds (0.8) but is tagged `overcammed` (the
  partner fights to clean it); tipped past e 0.85 is tagged `tipped`.
- Flare walks cams (tag `walked`) and makes plain nuts skate; offsets
  (kind `offset`) seat in flares and fill pin scars. Flakes flex.
- Fiddling: each offer from the same stance costs `1 + 0.6 * tries` times
  the first; a new stance resets it. Re-reading the same offer is free. The
  hint warns before the try that would pump you off; if you do pump off you
  fall but lose nothing (offers never take the piece).
- At a stretch (past `STRETCH_M` from that side's shoulder) offers cost 1.4x,
  the inset is dark ("you can't quite see in") and the piece holds a little
  less (tag `stretched`): legible, not a hidden penalty.
- Mentor knowledge is information, never a green band: `lobes` makes the
  reading specific ("tips barely biting"), `constrictions` makes pinches
  glint in the inset.
- The `auto_gear` assist only starts the cursor on the best size; otherwise
  the cursor starts on the last piece you placed. No rack-depth tax.
- Booty (`WallBooty`, data/climb/wall_booty.json) appears in the nearest crack
  at its old row; working it free takes 2-4 seeded tries with spoken
  progress ("doesn't budge", "shifts", "rattles. Nearly."). Freed booty is
  yours for good (`WallBooty.take`) and goes on the harness if you rack that
  size.
- Old pins: tug-test from the place phase (half an offer's cost): "solid",
  "flexes in its eye", "shifts".

## For other threads

- **Falls (7):** `grade_for(piece)` gives `{grade, line, why}` naming the piece and
  height ("Your red #1 at 6 m: walked up the crack a bit."). Tags on placed
  pieces: `overcammed`, `tipped`, `walked`, `shallow`, `stretched`, `offset`.
  Fable suggests pops scale with fall severity near the quality threshold so
  graded readings matter, and over-cammed pieces cost belay minutes.
- **Effort (4):** `price_action("offer", {stretched, hand_hold})`. Gear applies
  the fiddle and stretch multipliers itself, so don't also scale by tries.
- **Foundation (1):** TradGear overrides `can_rack()` (contract v2, #204): the
  rack opens at a crack, an old pin or a stuck piece in reach; with no crack
  it offers only the pin or booty. `grade_for` returns `{grade, line, why}`.
- **Art/look (9, 10):** the inset is the only placement view; placed pieces
  on the wall are drawn by the look. `piece_offered` carries the reading
  (`state`, `e`, `walks`, `stop`, `murky`) for sounds and animation.
