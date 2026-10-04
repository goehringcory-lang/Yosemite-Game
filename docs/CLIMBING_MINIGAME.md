# Climbing minigame: first design

Status: standalone interaction prototype and proposed rules. The existing Godot minigame remains the live implementation. Open [climbing-prototype.html](climbing-prototype.html) in a browser to play this study; it uses sample inventory and never touches game saves.

## Experience

Climbing is a short sequence of deliberate decisions: read the wall, choose a hold, decide where to protect, then reach a ledge with enough energy for the next pitch. The satisfaction comes from recognizing how a new piece of story-earned equipment changes the available line.

Use a side-on granite wall with a visible climber, rope, equipment placements, and ledges. Decisions have no real-time deadline. A move plays a short animation after confirmation. Target roughly one to three minutes of player time per pitch, to be tuned through playtesting. Game time advances only when an action succeeds.

The prototype is an interaction study with browser controls and simplified geometry. Its terrain layouts are invented for testing the mechanic; they are not reconstructions of real routes. Godot's final screen must be composed for the existing 480 × 270 viewport, with a scrolling wall and a collapsible equipment panel rather than a shrunken browser layout.

## Play loop

1. **At the base:** show route identity, pitch count, required gear, expected food, night requirements, and the destination unlocked. Display missing equipment by name. Start with a snapshot of owned equipment and the food selected for the climb.
2. **Read:** highlight reachable holds. Focus previews effort, stamina afterward, terrain, compatible equipment, and the consequence of exhaustion. Readability cannot depend on color alone.
3. **Move:** choose up-left, up, or up-right. Ordinary moves cost stamina and six game minutes. Terrain can require a specific equipment action.
4. **Protect:** stop at cracks or bolts and place a piece. The rack count falls and the rope visibly runs through the placement. Equipment remains on the pitch until recovered.
5. **Belay:** recover ten stamina, recover the rack when changing pitches, choose food, and explicitly continue. Big walls can require a haul or overnight stop.
6. **Finish or retreat:** show elapsed time, food eaten, and the outcome. Return control to the caller, which updates the story and map once.

Do not require a timing challenge for every handhold. A later optional timing mode should not alter whether story destinations are accessible.

## Equipment and story progression

| Existing gear ID | Proposed use during a climb | First teaching moment |
| --- | --- | --- |
| `approach_shoes` | Passive: ordinary rock moves cost one less stamina, reflected in the preview. | Starting kit at Swan Slab. |
| `chalk_bag` | Active: spend two game minutes; next two ordinary rock/crack/bolt moves cost three less. One use per pitch in this study; no new consumable inventory. | Before the practice crux. |
| `rope` | Enables leading with a harness. Show rope through placements and catches. Pitch-length variants are deferred because current gear resources have no length property. | Leonard's existing reward. |
| `harness` | Enables roped movement with the rope; represented on the character, without a repeated equip prompt. | Leonard's existing reward. |
| `cam` | Place at a crack for one stamina and two minutes. One piece leaves the rack until the next pitch. | Two cams awarded by Leonard; Apron teaches placement spacing. |
| `quickdraw` | Clip a marked bolt for one stamina and two minutes. Shares the protection system with cams, with separate remaining counts. | Proposed later slab chapter; no such reward quest exists yet. |
| `belay_device` | Enables authored rappel exits and later route requirements. The browser study lists it but does not simulate a rappel branch. | Proposed multi-pitch chapter. Earlier climbs retain their existing partner-assisted retreat. |
| `aiders` | Select aid mode for an authored aid section. Spend one cam and five stamina, take twelve minutes, and create protection at the new position. Reuse the ladders. | Proposed big-wall chapter. |
| `ascenders` | Select ascender mode on an authored fixed-rope section: four stamina and eight minutes. A secured section has zero local runout. | Proposed big-wall chapter. |
| `haul_bag` | Enables extra provisions on expedition routes. Between pitches, hauling costs ten minutes; the study models that time but has no capacity system yet. | Proposed supply-planning quest. |
| `portaledge` | At a marked hanging bivy, consume a chosen substantial meal and spend the night; restore stamina. Prototype night costs one meal and 600 minutes. | Proposed overnight wall chapter. |
| `ice_axe` | Select axe mode for authored snow sections; six stamina per move when combined with crampons. | Proposed high-country chapter. |
| `crampons` | Passive requirement for those snow footholds, visibly equipped. | Proposed high-country chapter. |

Only starting shoes/chalk and Leonard's rope/harness/two-cam reward are currently available through the implemented progression. Later sample kits deliberately demonstrate the design without claiming those quests already exist. The alpine pack mentioned in the older design is not an existing gear resource and is not required here.

The first lead route must remain playable with Leonard's exact reward. Do not retroactively require quickdraws or a belay device for it. Top-rope practice uses the instructor's equipment even though the player does not yet own a rope and harness.

## Rules for the first playable version

- Maximum stamina: 100. Every destination hold displays its final cost after equipment effects; clamp non-ledge costs to at least one.
- A player decision that is unavailable spends nothing. Pausing, inspecting, and selecting tools spend nothing.
- No random slips in the initial version. Stamina reaching zero triggers a fall, including after a placement. Warn before committing a move that exhausts the player.
- A short fall costs twenty game minutes and restores stamina to thirty. Keep placements and remaining rack counts; do not duplicate gear after a fall.
- Use the existing simplified runout model initially: four or more rows above protection, or three falls on a pitch, ends the attempt safely. A short lead fall returns to `max(0, protection_row - runout)`. A top-rope fall leaves the player at the same hold. These are game abstractions.
- Runout is never negative when the climber is below placed protection. Recovery movements beneath the highest placement do not require another piece.
- A retreat keeps all owned equipment. Spent food and game time remain spent. The study uses fifteen minutes for a voluntary retreat; the game should author descent time per route.
- Food is chosen at ledges; display its energy and remaining supply. Preserve a meal for mandatory nights. The prototype uses three +25 snacks and two +40 meals as fixtures; production uses `FoodDB` values and actual inventory quantities.
- The study requires a portaledge night after pitch two of the three-pitch big wall. Without a meal, the next pitch stays unavailable and retreat remains available. Production should prevent an obviously under-supplied departure at the route preview and explain the required meal reserve.
- Racks refill only at pitch transitions, representing the partner recovering protection. Gear is never removed from the player's permanent ownership merely because it is placed.
- Whole-route success requires the final ledge. Intermediate pitches and failed attempts never award route completion or unlock destinations.

## Authored opening lesson

**Swan Slab:** borrowed top rope; one short pitch. Teach destination cost, chalk, and the belay. After the climb, the existing `leonard_belay` quest still requires carrying thirty food energy before granting equipment.

**Apron study:** three pitches, with cracks on the center line at rows two and five. The outer left line is less tiring but bypasses the cracks. A player must return toward the center to protect the next stretch. The right line costs more and serves as a preview comparison. Later production layouts should vary between pitches; repeated layouts in the browser are intentional control samples.

Example center-line pitch using the browser study's costs:

| Decision | Stamina afterward | Cams left |
| --- | --- | --- |
| Start | 100 | 2 |
| Row 1: ordinary rock, cost 8 | 92 | 2 |
| Row 2: crack, cost 9; place cam, cost 1 | 82 | 1 |
| Row 3: rock, cost 8 | 74 | 1 |
| Row 4: rock, cost 8 | 66 | 1 |
| Row 5: crack, cost 9; place cam, cost 1 | 56 | 0 |
| Chalk, then row 6 crux: cost 9 | 47 | 0 |
| Row 7: chalked rock, cost 5 | 42 | 0 |
| Row 8: rock, cost 8 | 34 | 0 |
| Reach intermediate ledge, recover 10 | 44 | Rack recovered on continue |

This demonstrates a complete pitch with the starter rack and no fall. Meals and snacks support the later pitches. Extra cams enable additional protection on routes with more placement opportunities; they are not a generic stamina upgrade.

## Screen and controls

The wall is the primary view. Show the next several moves and the last protection; scroll as the player climbs. Keep stamina, rack, pitch, and current tool visible. Preview details appear near the selected hold. Show a clear exhaustion warning and an explicit retreat confirmation in the production UI.

| Intent | Browser study | Proposed Godot mapping |
| --- | --- | --- |
| Choose next hold | Click/tap, or left/up/right arrows | Existing movement actions; D-pad/left stick with discrete selection |
| Preview | Hover or keyboard focus | Focus a hold before confirm; pointer hover |
| Place or clip | Space or button | `use_tool`, based on selected equipment |
| Select equipment | Buttons; C/A/U/I shortcuts | Compact equipment selector; bind a dedicated cycle action after reviewing existing controller bindings |
| Eat | Snack/meal buttons at ledges | `interact` opens food choices |
| Next pitch | E or button | `interact` in the belay menu |
| Retreat | Esc or button, immediate in study | `ui_cancel` opens retreat confirmation |

The prototype supports keyboard and pointer interaction. It has no gamepad input or animation polish. Production should use semantic Control nodes for HUD/buttons, preserve keyboard focus after actions, support input remapping, and avoid repeating a climb action when a key is held.

## Integration plan for later

Keep the public `ClimbMinigame.setup(route, seed)` and `finished(success, minutes)` contract for the initial single-day implementation. `ClimbStart` already pauses world actions and time, receives the result, records success in `QuestLog`, and unlocks/transports to the destination. The design prototype does not change those call sites.

Extend `ClimbState` to receive an equipment-count snapshot instead of only a cam count. Keep rules independent of drawing. Represent holds with terrain type, cost, and allowed actions; represent placements with gear type and cell. Preserve the current `cam` count and `required_gear` IDs rather than creating another permanent gear inventory. Add a pitch-belayed phase so food, recovery, and continuing are explicit.

Add optional authored pitch resources to `RouteData`, with hold layout, supported gear, belay type, fixed sections, and night stops. Keep existing `pitches`, `moves_per_pitch`, and `top_rope` working as defaults during migration. Use authored layouts for the opening lessons before extending procedural generation.

The present generator guarantees a geometric line but its crack check only finds a crack somewhere in each band. That does not prove a continuous, protectable line using the actual rack. Later generation must validate reachability, equipment consumption, energy/rest budget, and protection spacing together; retry generation or use an authored fallback if no viable line exists.

Single-day food transactions can initially follow the existing inventory consumption path. Before expeditions, introduce a reserved expedition food bag with an ordered action record and one owner for commit/return, so inventory cannot be consumed both by the screen and by its caller. Keep item age consistent across bivys; calculate spoilage before offering the next day's food.

Multi-day integration needs a separate clock change: `GameClock.advance_minutes()` currently clamps at 2 AM and emits the world's pass-out event. Returning an aggregated 600-minute bivy duration cannot represent nights correctly. Process expedition days explicitly, advance `day_started` once per day, suppress the ordinary world rescue while on the wall, and coordinate food aging with the expedition bag. Store the settled world date/time in the expedition result or apply time incrementally; never also apply the old total-minutes update. Single-day and expedition callers must share an explicit ownership rule for time.

If mid-route saving is added, save route ID/layout seed, pitch, position, stamina, placements, rack, food reservation, tool effects, night state, and applied time. Until then, clearly make climbs complete attempts; the standalone study resets on reload.

## Implementation order and acceptance criteria

1. Port the practice and starter-lead interaction into an isolated Godot scene. Preserve existing scene entry/exit contracts. Demonstrate completion with starting gear and Leonard's reward respectively.
2. Add contextual cam/quickdraw actions, chalk, explicit belays, food choices, and short-fall recovery. Check that invalid actions spend nothing, gear does not duplicate after falling, and reaching the last ledge while exhausted cannot award success.
3. Wire the isolated scene into the route caller. Confirm one quest event per success, no event on retreat, one application of elapsed time, restored movement/pause state on exit, and correct destination spawn. Re-run the existing story and world-story checks when making that integration.
4. Add authored aid/fixed-rope sections and their equipment. Confirm all required pieces are available before entry and that safe retreat is always possible.
5. Implement expedition time, provisions, nights, save policy, and high-country terrain. Confirm midnight does not invoke the normal pass-out rescue or apply time/food twice.

Review the study for whether tool choices feel useful, whether two cams create understandable choices, and whether three pitches remain enjoyable. Numerical tuning, final art, later reward quests, and actual route layouts remain future work.

## Prototype verification

The embedded JavaScript was executed in Node with a minimal document stub. All five sample chapters completed using their fixture kits; checks also passed for unavailable aid actions spending nothing, protected falls preserving placement/rack counts, long runouts ending without success, and missing night meals blocking progression while allowing retreat. These check game rules, not browser rendering or Godot integration. A browser preview was attempted but blocked by the browser's local-file URL security policy, so visual review remains outstanding.
