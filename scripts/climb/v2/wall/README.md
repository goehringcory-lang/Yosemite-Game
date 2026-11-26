# Climbing v2: wall and routes (thread 2)

Every route is real rock on the v2 wall. `wall.gd` (`RouteWall`, the real
`WallSource`) builds each pitch from the route's plan in
`data/climb/v2/routes/<route id>.json`.

| File | What |
|------|------|
| `wall.gd` | `RouteWall`: pitch count and `build_pitch` for the director; `RouteWall.build(route, pitch)` without a session |
| `wall_plan.gd` | `WallPlan`: loads (and caches) a route's plan; an automatic plan from the old `ClimbProfiles` spec for a route with no file |
| `wall_builder.gd` | `WallBuilder`: a pitch plan to a `V2Wall` (holds, cracks, fixed gear, zones) |
| `wall_check.gd` | `WallCheck`: proves a wall is sound; `plan()` gives a bot the fewest moves up |
| `tools/climb_v2/convert_routes.tscn` | `-- draft` writes automatic plans for routes with no file; `-- dump <dir>` builds every pitch and a report |
| `tools/climb_v2/topo.py` | draws dumped walls as topo sheets (one PNG per route) |
| `tests/climb_v2_wall_test` | the checker on every pitch, determinism, constrictions, cruxes, a bot up every route |

The wall is the same every time for a route and pitch: random numbers come
from the route id and pitch, never the session seed, so a route can be
learned and a mentor can tell you about it.

## A pitch plan

Metres, x right, y up from the lower belay (as in CONTRACTS.md). All keys but
`name` and `height` are optional.

| Key | What |
|-----|------|
| `name`, `beta` | Shown at the pitch start. Beta describes the rock, never the controls |
| `style` | slab, crack, flake, chimney, roof, dike, knobs, face, snow, ice: picks hold kinds and spacing |
| `diff` | 1-5 (the route's old pitch difficulty): smaller holds, longer moves, fewer shake-outs |
| `height`, `width` | The pitch, metres (default width 8) |
| `angle` | Degrees past vertical (negative = slab). `sections` `[{from, to, style?, angle?}]` change style/angle by height |
| `line` | `[[x, y], ...]` the way up, belay to anchor. Holds follow it; a traverse or roof is a sideways stretch |
| `belay` | ledge, tree, hanging or top (top of the climb). A ledge/tree belay gets a ledge zone |
| `bivy`, `fixed_rope`, `aid`, `top_rope`, `boulder` | Passed into `info` for other systems |
| `cracks` | `[{id, kind, points, widths, constrictions, flare?, tags?}]` (V2Crack). Widths on the Camalot scale 0-7. A constriction is a point index where the crack is narrower just below: a nut slid down seats there. Tag `no_jams` on a chimney's outer crack |
| `flakes` | `[{id, side, points, widths}]`: a crack you layback (`side` = the side the edge faces). Hand holds on it are sidepulls tagged `layback` |
| `bolts` | Heights of bolts on the line |
| `pins` | `[{y, x?, kind?, quality?, tags?}]`: old pitons (kind pin, quality 0.7) or bolts |
| `horns` | Heights, or `{y, x?, tags?}`: slingable horns; tag `chockstone` for one wedged in a chimney |
| `rests` | `[{y, kind?, x?, name?}]`: a stance and a jug, and a rest zone |
| `ledges` | `[{y, x0?, x1?, name?, bivy?}]`: a ledge zone and stance holds across it |
| `cruxes` | See below |
| `zones` | Extra `V2Zone`s: `{kind (wet, sun, loose...), rect, data}` |
| `holds` | Extra `V2Hold`s, as written |
| `runout` | The longest unprotected stretch WallCheck allows (default 4 m; Snake Dike's are 7-8.5) |
| `unprotected` | No protection expected (the Lyell Glacier: the rope is for crevasses) |

## Cruxes

`{id, name, from, to}` (heights) or `{id, name, d0, d1}` (metres along the
line, for roofs and traverses), with:

- `sequence`: the hands in order, `["rh", "lh", "lh", ...]`. Holds are laid
  out from it: a left-hand hold left of the line, the same hand twice steps
  further out, so the sequence can be read in the rock. Each crux hold is
  tagged `crux:<id>` and `seq:<n>:<hand>`; there's one tempting `decoy`, and
  a jug at the exit (`crux_exit`). A long crux repeats its sequence so no
  move is longer than 0.6 m.
- `hip`: layback, mantel, lunge, chimney, offwidth, flag, drop_knee, stem,
  high_step, heel, smear, undercling. Tagged `hip:<x>` on the holds.
- `read`: one line on how to do it (what a mentor tells you). Also the
  zone's `beta`.
- `special`: `swing`/`pendulum` (a jug to swing from, `swing_from`, tagged
  `special:swing`, and the landing in the far crack, `swing_to`, with a line
  of tiny `free_variation` holds under it: the hard way round), or nail,
  chimney, offwidth. Left out, it comes from `aid` (nail) or `hip` (chimney,
  offwidth).
- `kind`: dyno, layback, mantel, slab, roof; left out, it comes from `hip`
  and the rock. A dyno's last hold is tagged `dyno`.
- `holds`: authored holds instead of the laid-out ones.

The crux zone's data is the crux system's format (cruxes/CRUXES.md, "Wall
data"): `name, beta, kind, special, sequence, target` (a swing's landing),
plus `hip`, `read`, `aid`, and for a swing `from`/`to` hold ids.

## What the builder adds

Hand holds alternate either side of the line an arm's spacing apart (jams in
a crack within 0.75 m of it, sized by width: hands are the best jams, thin
fingers and offwidth the worst), an option further out every few moves, feet
between, a shake-out jug every 2.2 m plus 0.6 m a grade, and the anchor. Then
it bridges any move the body can't make, until WallCheck finds a way up both
with and without swinging.

## What WallCheck proves

Every pitch: holds and gear on the wall, unique ids, no overlapping holds;
cracks run upward with widths 0-7 and real constrictions; a way from the belay
to the anchor for the body stub's reach (a search over both hands), and
without swinging too; the first protection is low and no runout is longer
than the plan allows (counting bolts, pins, every crack width the rack fits,
and slingable horns near the line); every crux has a hold for each move.
