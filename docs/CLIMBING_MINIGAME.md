# Climbing minigame

Status: shipped. Every route in the guidebook has its own climb, set in the real place, and the gear you earn in the story changes how you climb. The browser study in [climbing-prototype.html](climbing-prototype.html) is kept as the original interaction sketch; the Godot screen is the real thing.

## Experience

A climb is a short sequence of decisions: read the wall, choose a line, decide where to shake out and where to protect, then reach the ledge with enough stamina for the next pitch. On the harder routes the cheapest hold in reach is often the wrong one: a string of crimps pumps you until every move costs double, and gear placed off a crimp costs five times what it does from a jug. Nothing is timed against you, apart from four small, forgiving skill checks at cruxes. The satisfaction is in feeling a new piece of gear change the line: cams open up a crack, quickdraws clip the old pitons on the Spire, a belay device softens a fall, ascenders jug the Nose's fixed lines, aiders get you past the Great Roof, and an ice axe stops a slide on the glacier.

## Play loop

1. **Route card.** A postcard of the view, the pitches (a `*` for each crux point), the gear you need and have, the food you carry and what's worth bringing, night meals for routes with nights, and the day's weather on the wall (wet rock until when, wind, heat, the storm and the lightning). `E` or `Space` starts, `Esc` backs out without spending time. A day climb that would still be going at 2 AM can't be started, and the card says so.
2. **Pitch banner.** Each pitch announces its name and a line of beta ("Chalk up before the bulge").
3. **Read.** Every hold is a jug (drawn big), an edge, or a crimp (small). Rings mark the holds within reach with what each move costs now (shoes, chalk, pump, chimney rhythm, weather and slush included). Jugs, crimps, rests and cruxes are labelled.
4. **Move.** Up, up-left, up-right. A move costs stamina and six game minutes. Run out and you fall.
5. **Pump.** Crimps (+3), edges on pitches above grade 2 (+1) and cruxes (+1) pump your forearms; a jug takes 1 off. Each point of pump (0 to 6, the meter beside the stamina bar) adds 1 to every move and takes 0.02 off the crux meter's green. `E` on a jug (or a stance) shakes out: pump -5, 3 minutes, once a hold. A stance, a belay, a fall and a perfect crux all ease it.
6. **Protect.** `Space` clips a bolt (or an old piton) with a quickdraw, or places a cam in a crack. It costs 1 stamina from a jug or a stance, 2 from an edge, and 5 (and a point of pump) off a crimp. The hold beside every bolt and piton is never a crimp. The rope runs through every piece; runouts of four moves or more end the climb safely. Every pitch's guaranteed line has a crack or a fixed piece at least every three moves, so there's always a safe way up.
7. **Crux.** A hard move asks for a short skill check. Perfect gives stamina back and takes 2 off the pump. Miss it and you're spent: it costs stamina, and you eat from the pack (`E`) before you can try again. With nothing to eat (or only the meals the nights need) you fall.
8. **Belay.** At a ledge you recover 10 stamina (16 with a belay device), can eat (`E`, not at full stamina, smaller foods first, never the real meals a night still needs), and the next pitch starts. Rope and gear are recovered by your partner.
9. **Nights.** On a wall, a night needs a real meal (30+ energy; the smallest is eaten); the night scene plays, and you wake rested at 6:30 the next morning. Each night is a new day on the calendar (fresh food keeps spoiling), and a night falls where the route's profile says (`bivy`), not at a fixed time.
10. **Top out or retreat.** The result card shows time, falls, style (onsight, hard-won, aided), how the cruxes went and a fact about the route. Retreating keeps your gear; the tick only comes with the top. The caller records the tick once and applies the elapsed time once.

## Gear and what it does

| Gear | When you get it | In the climb |
|---|---|---|
| Climbing shoes | Marty's kit | -1 stamina on every move (not on ice); wider crux windows |
| Chalk bag | Marty's kit | Once a pitch: next 2 moves -3; wider crux windows while chalked |
| Harness, rope | Marty's kit; Leonard | Lead climbing; top-rope practice on Swan Slab |
| Quickdraws | Marty's kit, then Eichorn, Robbins... | Clip bolts, and fixed pitons on cam routes |
| Cams | Leonard onward | Place in cracks; the rack refills each pitch |
| Belay device | Robbins (Nutcracker) | Soft catches (+10 stamina after a fall), restful belays (+6), rappel retreat |
| Aiders | Harding | Pull through a hard move on a wall pitch for a cam and 12 minutes (costs the free ascent) |
| Ascenders | Johnson (Astroman) | Jug fixed ropes: 3 stamina, 8 minutes, you can't fall |
| Haul bag, portaledge | Harding, Johnson | The bag swings below you (+10 minutes a pitch); a hanging night in a portaledge is a full night |
| Ice axe, crampons | Muir | Snow and ice moves cost less; the axe stops a slide (self-arrest) |

## Pitch styles

| Style | Rules | Where |
|---|---|---|
| slab | Friction; bolts every 2 moves on bolted routes | Firefall Slab, Swan Slab, the Apron's friction |
| crack, flake | Cracks take cams; flakes are long cracks | The Grack, Nutcracker, Spire, Astroman, Nose |
| chimney | A narrow slot: alternate sides (-1 stamina) or lose the rhythm (+2); big back-and-foot cracks | Steck-Salathé, Harding Slot, Rotten Chimney |
| roof | The picture runs sideways under a ceiling, cams all along the crack, the lip is the crux | Separate Reality, the Great Roof |
| dike | Stay on the dike (cheap); off it it's blank; bolts are 3 moves apart | Snake Dike |
| knobs | Big holds everywhere, a few cracks | Cathedral Peak |
| snow, ice | Kicked steps and chipped holds; crevasses with snow bridges; slush after noon (it doesn't stack with the afternoon storm); no chalk; a fall slides 2 to 3 moves | Lyell Glacier |

## Weather on the wall

`WallWeather.today(route_id)` turns the day's weather (`Weather.today()`, and yesterday's from `Weather.on_day`) into one Dictionary of conditions, which the screen gives `ClimbState.conditions`. Tests and bots climb in `WallWeather.CALM` (dry, still, the old 2:30 PM storm on high-country routes, no lightning), so the tuning above doesn't move with the calendar.

| Weather | When | In the climb |
|---|---|---|
| Rain | A rainy day (or snow, melting down the face) | Rain all day: the storm's +1 a move (`STORM_PENALTY`), and wet rock |
| Wet rock | Rain, a storm, or the morning after rain until the face has had 2.5 hours of sun (`sun` in the profile; a face that never sees it is dry at 3 PM; between 9:30 AM and 4 PM) | Crux green 0.04 narrower (`WET_WINDOW`); slab, dike and knob moves +1 (`WET_FRICTION`, not on top of the storm's); the wall drawn dark with water streaks, and drips |
| Wind | 30 % of spring and fall days, 15 % in summer, 45 % in winter | From pitch 3 of routes with 4 or more pitches, and on every high-country pitch: crux green 0.03 narrower (`WIND_WINDOW`), the marker gusts (same speed on average), the climber and rope sway |
| Heat | Summer, noon to 4 PM, while the face is in the sun | +1 a move (`HEAT_PENALTY`); a warm glare and heat rising off the rock |
| High-country storm | 75 % of summer afternoons, 35 % in spring, 25 % in fall, at 1:30 to 3:30 PM on the half hour | From the storm hour: rain, +1 a move, wet rock, thunder and a warning. An hour later (`LIGHTNING_AFTER`) the lightning sends you down: the climb ends as a retreat, wherever you are |

The route card lists the forecast (`WallWeather.forecast`) beside the pitches, the sign at the foot of a route adds it to the line it reads out, and the guidebook's tick list opens with the day's conditions in the Valley and the high country.

## The 32px finish

The painters in `scripts/climb/art/` draw on the 480 x 270 menu grid. `ClimbHiRes` doubles each picture on its way to the screen (Scale2x, in bands on the worker threads), and the wall gets its granite back at full resolution: dark flecks and light specks per formation (`ClimbHiRes.GRAIN`: El Capitan's salt and pepper, smooth polished slab, Cathedral Peak's weathering crystals, glints in the ice) and, on a wet day, darker rock with water streaks. The textures report their menu-grid size (`ImageTexture.set_size_override`), so layout and drawing code is unchanged while each texel is one screen pixel. The rope, the climber's sway, rain, drips and other small effects are placed on half-pixel steps, which are screen pixels.

## Boulder problems

`RouteData.boulder` makes a route a boulder problem. Midnight Lightning (V8, Columbia Boulder, Camp 4) is the only one so far.

- **No rope.** There are no cams or quickdraws and nothing to protect with. The spotter (Chongo) stands under you with their hands up, over two crash pads.
- **Real holds.** The pitch spec's `problem` lists every row's holds (grip and cost) lowest first, so the wall is the same every visit. `crux_points` names each hard move with its own kind, extra cost, narrower green (`narrow`) and mash taps (`need`). Midnight Lightning goes polished start, sidepull, **the lightning bolt** (timing), the ledge (the one jug, so shake out here), **the swing** to a fingertip hold (timing, 0.03 narrower), a move to the lip, and **the mantel** (mash, 13 taps).
- **Falls.** Miss a crux and you come off, with no eating to try again. Running out of stamina does the same. You land on the pad and start again from the ground, `BOULDER_FATIGUE` (8) short of full for each fall so far, and 6 more after a fall off the top two moves. After `BOULDER_TRIES` (5) tries the session is over. You can eat on the pad, and chalk up there once a try.
- **Tuning.** A careful climber who shakes out on the ledge reaches the top with 7 stamina to spare (perfect cruxes give some back). The greedy bot takes the cheap jug out right, never shakes out and comes off the mantel every try. `test_boulder` checks both, along with the rules above.
- **Style.** *Flash* on the first try, otherwise *Sent on try N*.

## Crux checks

| Kind | How | Where |
|---|---|---|
| timing | A marker sweeps a bar; `Space` in the green (center is perfect). The green is wider with shoes, chalk, and on a top rope | Firefall Slab's bulge, Swan Slab's polished wave, Separate Reality's lip, Astroman's Boulder Problem... |
| mash | Tap Up quickly | Nutcracker's mantel |
| rhythm | Alternate Left and Right to the beat | The Narrows, Harding Slot, the King Swing, the Pendulum |
| dyno | Hold `Space` (or Up) to sink onto the move; a fill rises (0.7 of the timing marker's speed) and only goes up. Let go in the green (center is perfect); hold to the end and you peel off. You have the mash check's time to start | Astroman's chicken wing dyno, in the flare below the Harding Slot |

**How many.** A pitch's authored crux always counts. On top of it a grade 3 pitch has at least 1 crux point, a grade 4 pitch 2 and a grade 5 pitch 3 (`ClimbProfiles.CRUXES_BY_DIFF`), spread out and kept off the stances and fixed ropes. The added ones are timing checks named for the pitch's style, and add only 2 to their holds, so they test timing more than stamina. Swan Slab and Firefall Slab have 1 crux; the Nose has 20.

**How fast.** The timing marker's speed is `0.85 + 0.12 x pitch grade + 0.06 x the route's hardest grade` bar lengths a second (`ClimbState.crux_speed`), from about 1.0 on Swan Slab to 1.7 on the Nose. It's capped so the marker never crosses the green in less than 0.1 seconds. The green is `0.30 - 0.025 x grade`, wider with shoes, chalk and a top rope, and narrower by 0.02 for each point of pump: arrive fresh. Rhythm and mash checks lose 0.2 seconds a grade.

**A miss.** Outside the green (or waiting out nine sweeps) costs `3 + 2 x grade` stamina and leaves you spent on the move. `E` eats the next food in the pack and brings the meter back, with the green 0.03 wider and the marker 10% slower for each miss so far (up to 4). The route card's food advice includes a spare snack for every 4 crux points.

Bots and tests resolve cruxes as an average move; the screen sets `ClimbState.interactive`.

## Economy

With `base = 2 + grade` (grade is the pitch's 1-5 difficulty), a jug costs `base - 2 + 0..1` (at least 2), an edge `base - 1 + 0..1` and a crimp `base + 1 + 0..1`, before shoes, chalk and pump. How many of each depends on the style (`ClimbState.GRIPS`: knobs are mostly jugs, slabs and roofs have more crimps). A pitch is 7 to 12 moves. Stamina is 100; belays give +10; a wall night restores it all. So short early routes cost nothing to eat for, and the long ones (Steck-Salathé, Astroman, the Nose) need real provisions: `food` in each route's profile is what a careful climber needs, and the route card says so.

`tests/climb_test.tscn` plays every route with two bots and exactly that food. The careful one (`tests/climb_bot.gd`) reads the whole pitch and plans the cheapest safe line, with its shake-outs and placements, and eats at the belay for the pitch ahead; it must top out 85 % of the time. The greedy one takes the cheapest hold in reach, places gear whenever it can, chalks straight away and never shakes out. It must still top out 85 % of the first slabs (grade 2 or under), but on the routes with grade 4 pitches it must top out at least 15 points less often than the careful one (about 75 % against 97 % now). `CLIMB_STATS=1` prints both rates for each route.

## Real places

`scripts/climb/climb_profiles.gd` holds each route's place, the rock, the skyline you see (Half Dome, El Capitan, the Three Brothers, Bridalveil, Sentinel Rock, Glacier Point, the Cockscomb, Mount Lyell...), the ground at its foot, its summit, its belayer, descent, facts for the result card, and the real names of its pitches where known (the Grack, Bathtub, Wilson Overhang, the Narrows, Boulder Problem, Enduro Corner, Harding Slot, Sickle Ledge, El Cap Tower, King Swing, Great Roof, Changing Corners...). Where a guidebook disagrees or I could not verify, the text stays general.

## Verification

- `tests/climb_test.tscn`: every route has a profile and authored pitches, every pitch has a line (and one you can protect all the way), a careful bot tops every route and a greedy one does clearly worse on the hard ones, pump and shaking out, each piece of gear does its job, cruxes (the spent rule, crux points and meter speed by grade), weather, wall weather (wet rock, wind, heat, the storm's warning and the lightning, the forecast), nights.
- `tests/climb_screen_test.tscn` (needs a window): plays every route on the real screen, through crux checks, nights and the result card, and draws a stormy, windy day (the lightning ending the climb) and a hot, drying one.
- Screenshots: see the README.

## Not done yet

Rappel and descent scenes (the profiles record each descent), save-in-the-middle, gamepad glyphs on the hints, sound, and tribal review of anything on these routes that touches Native places (none of the current text does).
