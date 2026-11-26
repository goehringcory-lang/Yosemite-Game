# Climbing v2: contracts

Climbing v2 is the new climbing game: per-action pace (the wall waits for you),
an auto-picked next hand you aim at holds with a ghost-pose preview, one body
button for the hips, pump + gas with food as fuel, rope pulled up an arm-length
at a time to clip, cams offered and read by their lobes, nuts that need a
constriction, soft real falls, cruxes as sequence puzzles, a hi-res full-body
climber and a living camera. No timing bars, no arrow minigames, no hand
close-ups. The direction doc is "Skill-based climbing: direction"
(https://claude.ai/artifact/FCWqEQ9Wb5Eey21yMtTUrD).

It is built beside the old climbing (`climb_state.gd`, `climb_minigame.gd`,
untouched until the cutover) and runs only when switched on:

- `VALLEY_CLIMB_V2=1` (every route) or `VALLEY_CLIMB_V2=swan_slab,nutcracker`
  (those routes), or the project setting `valley/climb_v2`, or
  `ClimbV2.force = true` from code. `ClimbStart.climb()` then opens
  `scenes/climb/climb_screen_v2.tscn`. Boulders and rescues stay on the old one.

## Who owns what

Ten threads build v2. Each owns one folder and writes only there; they talk
only through these contracts, the systems' pure queries and the event bus.
Contract changes are additive and go through thread 1 (bump
`ClimbV2.CONTRACT_VERSION`).

| # | Thread | Folder (real system path) | Interface | Supplies phases |
|---|--------|---------------------------|-----------|-----------------|
| 1 | Foundation | `contracts/`, `core/`, `screen/`, `climb_v2.gd` | all of them, `ClimbDirector`, `ClimbScreenV2` | read, result |
| 2 | Wall and routes | `wall/wall.gd` | `WallSource` | |
| 3 | Controls and body | `body/body.gd` | `BodySystem` | climb |
| 4 | Pump, gas, food | `effort/effort.gd` | `EffortSystem` | |
| 5 | Rope and clipping | `rope/rope.gd` | `RopeSystem` | clip |
| 6 | Trad gear | `gear/gear.gd` | `GearSystem` | place |
| 7 | Falls and partner | `falls/falls.gd` | `FallSystem` | fall, belay |
| 8 | Cruxes, big wall | `cruxes/cruxes.gd` | `CruxSystem` | special |
| 9 | Climber art | `art/climber.gd` | `ClimberView` (a Node2D) | |
| 10 | Look, camera, sound, cutover | `look/look.gd` | `ClimbLook` (a Node2D) | (read, with thread 1) |

`ClimbSystems` (core/climb_systems.gd) loads the real script at that path when
it exists, else the permanent stub in `contracts/stubs/`. So you plug in by
creating your file; nobody edits the registry. The stubs stay forever: your
tests call `ClimbSystems.pin_stubs_except([&"rope"])` (your own system real,
everything else a stub) so another thread's merge can't change your results.
Your script must extend your interface. Bots, tuning and test files are
per-thread too (one tuning file and one test scene each, in your folder or
`tests/climb_v2_<name>_test`). The frozen fixture is
`data/climb/v2/fixture_pitch.json`: don't edit it; add your own fixtures.

## Field writers

Every session field has one writer. Everyone else reads.

| Field | Writer |
|-------|--------|
| `session.wall` (holds, cracks, zones, fixed pieces' placement) | wall (built once per pitch) |
| `session.pose` | body (`commit`, `swap_hand`, `settle`, `tag_pose`, `use_hand`/`return_hand`) |
| `session.effort` | effort (`apply`, `rest`, `eat`) |
| `session.rope`, `V2Piece.clipped/back_clipped/sling_m` | rope |
| placed `V2Piece`s (`session.pieces`, their placement fields) | gear |
| `V2Piece.popped/loaded` | falls |
| `session.rack` | only via `take()`/`give_back()`: rope (draws, slings), gear (cams, nuts), falls (cleaning at the belay) |
| `session.minutes`, `session.result`, `session.pitch`, `session.phase` | director |
| `session.mods` | director (from Gear, Settings, Perks, WallWeather) |
| `session.notes[<system id>]` | that system (scratch state; kept in snapshots) |
| `V2Move` fields | body (geometry), cruxes (`crux_id`, `in_sequence`, `crux_cost`, `crux_risk`, tags), effort (`cost`), falls (`risk`) |
| `V2Fall` fields | rope (geometry: chain, slack, length), falls (outcome) |

Mutators that cross systems are called only by the director: e.g. a fall is
`rope.fall_geometry -> falls.resolve -> rope.remove(popped) -> body.settle ->
director.spend(cost)`. A phase changes state through its own system or a
director intent (`commit`, `spend`, `take_fall`, `rest`, `eat`, `use_hand`,
`return_hand`, `hang_at`, `count_aid`, `go`, `next_pitch`). A belay-time
special (hauling) comes from `cruxes.belay_special()`: after the pitch is led
the director opens the special phase with `{"kind", "belay": true}` and that
phase goes on to the belay.

## The move pipeline

`ClimbDirector.preview(hold_id, hip_shift)`:
`body.preview -> cruxes.constrain -> effort.price -> falls.risk`.
Cruxes may set `move.crux_cost` (effort multiplies pump and gas by it) and
`move.crux_risk` (falls adds it to the fall chance). Previews run on every aim change and in bot searches, so they are **pure**: no
session changes, no random draws. `ClimbDirector.commit(move)` spends the
cost, `body.commit`, `cruxes.committed`, then rolls `falls.falls_now` once.
Random numbers come only from `session.rng_for(<system id>)`, drawn only in
mutators; the same seed climbs the same way. No wall-clock time in rules;
views animate, but nothing waits on them, and every system runs headless.

## Phases and verbs

Phases: `read -> climb <-> clip / place / fall / special -> belay -> (next
pitch) ... -> result`. The director owns the table (`ClimbDirector.PHASES`)
and passes input verbs to the current phase (`ClimbPhase.handle`). In the
climb phase the director answers `rope`, `rack`, `rest`, `eat` and `cancel`
itself (clip the nearest piece, open the rack when `gear.can_rack()`, shake out, eat, a
double cancel retreats) and passes the rest (`aim_*`, `commit`, `body`,
`swap`) to body's climb phase.

Verbs (`core/climb_input.gd`) map to rebindable input actions: aim = arrows,
commit = Space / C / pad X (`use_tool`), body = Shift / pad B (`run`, held),
swap = Z / LB (`climb_swap`), rope = R / RB (`climb_rope`), rack = T / d-pad
down (`climb_rack`), rest = V / d-pad up (`climb_rest`), eat = E / pad A
(`interact`), cancel = Esc (`ui_cancel`). Adding these to the Controls page is
for the cutover (thread 10).

## Units

Metres, x right, y **up**, (0, 0) at the pitch's lower belay. `ClimbV2.PX_PER_M`
(60) and `ClimberView.px()` / `ClimbV2.to_screen()` turn metres into pixels.
The body's size is shared: `HEIGHT_M`, `TORSO_M`, `ARM_M`, `LEG_M`,
`ARM_PULL_M` (one pull of rope), so reach, rope pulls and the drawn skeleton
agree. Crack widths are floats on the Camalot scale (`ClimbRack.WIDTHS`,
`GearData.width_min/max`: 0 = #0.3 ... 4 = #1 ... 7 = #4). Minutes are ints.

## The bus

`ClimbEvents` (one per climb) has a typed signal per fact, grouped by owner.
Only the owner sends an event (`bus.send(&"clipped", [id, false])`);
listeners (views, HUD, sound, counters) never change the session. There are no
camera or sound events: look (thread 10) derives presentation from gameplay
events. `bus.trace` keeps every event for tests.

## Snapshots

`session.snapshot()` / `restore()` hold everything that changes in a pitch as
plain data (ids, not object references), for undo, ghost previews and bot
search. There is no saving mid-climb (the climb is modal and the clock is
paused).

## The result

`V2Result` uses the same member names Achievements, Perks and medals read from
`ClimbState` (`falls`, `aid_moves`, `perfect_cruxes`, `slipped_cruxes`,
`nights_spent`, `minutes`, `route`), so the cutover can hand it over. Until
then the v2 path ticks the route and tops out, but doesn't award perks,
achievements or medals.

## Tests

`tests/climb_v2_test` runs the switch, the registry, the fixture, pure
previews, a scripted climber up the fixture through every stub (golden event
order), a fall, snapshots, determinism, the verbs, the screen and a real
route on the stub ladder wall. It pins all stubs; keep it passing.
