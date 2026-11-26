# Climbing v2: cruxes and big-wall moments (thread 8)

`cruxes.gd` (`CruxesV2`) is the real `CruxSystem`. No timing bars, no rhythm
or mash checks: a crux is a sequence puzzle in the normal climb controls, and
the big-wall moments are short "special" phases of plain choices.

## Files

| File | What |
|------|------|
| `cruxes.gd` | The system: crux spots per pitch, `constrain` / `committed`, `special_at`, `belay_special`, notes |
| `crux_reader.gd` | Pure reading of a pitch: spots (wall zones, `special:<kind>` hold tags, else the old profile's crux rows) and each hold's demands |
| `crux_tuning.gd` | Every number |
| `crux_special_phase.gd` | The `special` phase: arrows pick a choice, the ghost/hint show it, commit does it; rest, eat, double cancel |
| `crux_overlay.gd` | Ghost tells, crux card, what you learned, and each special drawn on the rock |
| `specials/*.gd` | `SwingSpecial`, `NailSpecial`, `InchwormSpecial` (chimney, offwidth), `HaulSpecial` |

## Crux puzzles

A move onto a hold inside a crux spot is checked against what the hold asks:

- **hand**: a sidepull or gaston wants the hand it faces (from `V2Hold.pull`);
- **hip**: the body button's shift from where body would put the hips on its
  own (cruxes calls `body.preview(hold, Vector2.ZERO)` for that): lean off a
  sidepull, toward a gaston, low under an undercling or sloper, up for a
  mantel's shelf or on a slab, away from the crack on a layback, crouched for
  a dyno;
- **foot**: feet on footholds (crimps, pockets, underclings: one; layback,
  roof, dyno: both);
- **beta**: a zone's authored `sequence` (hands, or `{hand, hip: low|high|left|right, feet, say}` steps).

Each miss has its own consequence (`crux_tuning.gd` `MISS_*`): a wrong hand
crosses you up (pump, and the next crux move costs more), wrong hips
barn-door (pump plus a little risk), a skating foot is mostly risk. They add
up in `V2Move.crux_cost` (effort multiplies pump and gas) and
`V2Move.crux_risk` (falls adds it). A dyno's risk is small from bent legs
with both feet on and grows with pump and a bad launch.

Move tags for views: `crux`, `crux:<kind>`, `dyno`, and one per miss:
`crux_miss:hand_rh|hand_lh`, `crux_miss:hip_x-1|hip_x1|hip_y-1|hip_y1`,
`crux_miss:foot_1|foot_2`, `crux_miss:beta`. Art should show them on the
ghost (barn-door, a skating foot, crossed wrists) so a wrong move reads
before it's committed; the overlay draws simple marks until then. After the
move the overlay says what you learned ("You barn-doored. Lean your hips
left off it."). A mentor's `knowledge` "beta" (or "route:<id>") shows the
guidebook beta on the crux card.

## Wall data (thread 2)

A `V2Zone` of kind `crux` with `data`:
`{"name", "beta", "kind": "dyno"|"layback"|"mantel"|"slab"|"roof", "special": "swing"|"nail"|"chimney"|"offwidth", "sequence": [...], "target": [x, y]}`.
Tag a dyno's target hold `dyno` (or `key`). A swing finds the far crack's
holds by itself (hand holds in a line across from the pivot), or takes
`target`. Haul lips: `ledge` zones or `data.lip` / `data.lip_size`
(0.6 edge, 1 flake, 2 roof). Chimneys and offwidths read the nearest crack
of kind `offwidth`/`chimney` (or width 6+) for their width profile.
Without crux zones, the old `ClimbProfiles` crux rows are used: every route
converts (timing/rhythm/mash become sequence puzzles, `hard_aid` pitches are
nailed, chimney pitches inchworm, the King Swing and Pendulum swing).

## Specials

- **King Swing**: choose how far to lower out (each choice puts a hold of
  the far crack on the arc: more rope lands lower), then kick off drawn
  spots (edge, flake, crystals, dirty, polished, wet) each swing; the ghost
  shows the next peak. Swings decay and legs tire, overshooting slams the
  corner, grabbing pumped can slip.
- **Nailing**: read each scar's width, pick a pin from the iron (more scars
  want a size than you carry), tap and listen (rising, ring, clack, ping,
  thunk), then bounce-test or step straight up. Back-clean or skyhook when
  you run short. Each step up is an aid move.
- **Chimney / offwidth**: choose which side goes in (against the crack's
  lean costs more), then aim each half at a lock spot up the crack; pinches
  lock well, a spot no lock fits slides you back. Both locked = rest.
- **Haul** (belay, big walls with a bag and more pitches): haul to the next
  lip in one go (gas = bag weight), then flick, let down and re-haul, or have
  the partner free it.

Every step sends `special_step(kind, data)` (stage, tone, peak, lock...)
for look, sound and art.

## Tests and shots

`tests/climb_v2_cruxes_test.tscn` (cruxes real, everything else stubs).
Shots: `SHOT_SPECIAL=sidepull|dyno|swing|nail|chimney|haul xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/shots/climb_v2_crux_shot.tscn`.
