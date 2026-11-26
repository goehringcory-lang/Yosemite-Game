# Streaming the open world

Valley Days is one park you walk through, not a set of levels. Each area
(a "region": `scenes/regions/<id>.tscn`) is its own map, and World streams
them: the area the player is in sits at the world's origin, the area past a
nearby map edge is laid out beside it, and walking over that edge carries on
into it with no fade and no pause. This page is for anyone adding or joining
areas, or anything that needs to know what is laid out where.

## What makes two areas join (a seam)

A **seam** is a `RegionExit` that:

- sits on its map's edge (within 48 px),
- has a `target_region` (an outdoor area), **`minutes` 0** and no shop hours,
- and whose `target_spawn` is on the facing edge of the next map (within
  160 px), or the next map has its own minutes-0 exit back on that edge.

That's all: World finds seams itself (`Seam.candidates`, `Seam.make`). The
two maps are lined up at the exit and spawn, overlap by 64 px, blend their
painted grounds across the overlap, and the blocker rim along the whole
stretch of edge they share is opened, so you can wander over meadow or river
bank, not only the road.

If a road's painted ends don't quite meet, slide the next map along the edge
with a **nudge**: `data/park/seam_nudges/<region id>.json`,
`{"<exit name>": pixels}`. Use the per-region file (one per area, so threads
don't collide); the old shared `data/park/seam_nudges.json` still works and
the per-region file wins. `tools/seams/measure_seams.tscn` measures them.

**Check your links:** `tests/stream_test.tscn` runs `WorldStream.check_links()`
over every region scene and fails on any walking edge exit that doesn't meet
the next map edge to edge. From a script:
`WorldStream.check_links(["tuolumne_meadows"])` returns
`[{region, exit, target, ok, why}]`. An exit that should cut on purpose goes
in that test's `CUTS`, with a reason.

Exits with `minutes` > 0 (drives, long trails), shop doors, `drive_to` and
`travel_to` exits are not seams: they show the trip map or a door wipe.

## Long trails and roads: corridors

The park's areas are miles apart. To walk from one to another, build the way
between as one or more **corridor** areas (a stretch of trail or road),
joined to each end and to each other by ordinary minutes-0 seams, and give
each corridor its **`walk_minutes`** (an export on `Region`): the clock time
walking it end to end takes, on top of the clock's usual pace.

The minutes pass as the player gets further along the corridor's longer side
(the furthest reached either way), a minute at a time, so the light moves on
smoothly; wandering back over ground already walked costs nothing more, and
stepping back and forth at an edge costs nothing at all. Re-entering a
corridor counts afresh. A timed exit you turn into a corridor link should
lose its `minutes` (they move onto the corridor's `walk_minutes`).

Keep the trip map (`minutes` > 0 exits, `drive_to`) for drives: driving the
Tioga Road isn't walked.

### Building a corridor

`tools/hubs/build_corridor.gd` makes a corridor area from a spec,
`tools/hubs/corridors/<id>.json` (the format is at the top of that file): its
size, ground (forest, fir, subalpine, granite, meadow, foothill), a trail or
road winding between its ends, optional clearings and signs, and
`walk_minutes`. Each end gets a minutes-0 exit on its map edge and a marker
named for its side (`west`, `east`, `north`, `south`) just inside, so:

1. Write the spec, with each end's `target_region` and `target_spawn` (a
   spot just inside the neighbor's facing edge).
2. `tools/hubs/rebuild_corridors.sh <id>`: builds it onto the 32px grid
   with painted ground, wild dressing, normal maps and water cells.
3. In each neighbor, put a minutes-0 `RegionExit` on the facing edge with
   `target_region` = the corridor and `target_spawn` = the side's marker
   (a corridor's west end is entered from its west neighbor's east edge).
4. Run `tests/stream_test.tscn`; it says which end doesn't line up, and why.
   Nudge a painted road into line with `data/park/seam_nudges/<id>.json`.
5. Dress it by hand like any area (signs, a viewpoint, a camp): it's an
   ordinary region scene. Rebuilding rewrites it, so keep the spec current
   or stop rebuilding once you hand-edit.

## WorldStream: what's laid out, and where

`World.stream` (`scripts/world/world_stream.gd`) is the face of streaming for
everything outside World:

| Call | What it gives |
| --- | --- |
| `region_streamed_in(region)` | signal: an area was laid out (the one walked into, or one beside it) |
| `region_streamed_out(region)` | signal: an area was taken out of the world (it stays in memory as it was) |
| `loaded_regions()` | the areas laid out now, the player's first |
| `is_streamed(region)` | is it laid out now? |
| `to_current(region, local)` | a spot in that area's own coordinates, in the current area's (INF if not laid out) |
| `region_at(pos)` | the laid-out area whose ground covers a spot in the current area's coordinates |
| `player_lonlat()` | the player's real longitude/latitude, carried on across seams |
| `corridor_minutes_paid()` | corridor minutes the clock has had in this corridor so far |
| `check_links(ids)` | static: the content check above |

Rules of thumb:

- **Never keep world coordinates across frames.** The origin moves to the
  new area on every crossing. Keep positions in an area's own coordinates
  (`region.to_local`) or as lon/lat, and listen to `World.seam_crossed(shift)`
  if you hold anything in world space (birds in flight, footprints).
- `World.region_changed(region)` still fires on every change of area,
  crossings included; `region_streamed_in/out` say what is drawn.
- `World.seam` is the one neighbor laid out now (null if none). Read it, but
  prefer `loaded_regions()`, which will keep working when several
  neighbors are laid out at once.
- Every area visited stays in memory (an eviction that re-made areas was
  tried and reverted: re-made areas came back different). Don't free regions.

## Files

- `scripts/world/world.gd`: streaming itself (`_update_seam`, `_lay_seam`,
  `_cross_seam`, background loads `_preload_neighbors`/`_pump_preload`,
  staged first-time set-up `_set_up_step`).
- `scripts/world/seam.gd`: one seam: lining up, rims, ground blend, crossing.
- `scripts/world/seam_backdrop.gd`: the woods drawn past the maps' edges.
- `scripts/world/world_stream.gd`: the API above, and the corridor clock.
- Tests: `tests/stream_test`, `tests/seams_test`, `tests/transitions_test`,
  `tests/continuity_test`.
