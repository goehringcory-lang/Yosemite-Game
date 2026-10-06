# Climbing minigame

Status: shipped. Every route in the guidebook has its own climb, set in the real place, and the gear you earn in the story changes how you climb. The browser study in [climbing-prototype.html](climbing-prototype.html) is kept as the original interaction sketch; the Godot screen is the real thing.

## Experience

A climb is a short sequence of decisions: read the wall, choose a hold, decide where to protect, then reach the ledge with enough stamina for the next pitch. Nothing is timed against you, apart from three small, forgiving skill checks at cruxes. The satisfaction is in feeling a new piece of gear change the line: cams open up a crack, quickdraws clip the old pitons on the Spire, a belay device softens a fall, ascenders jug the Nose's fixed lines, aiders get you past the Great Roof, and an ice axe stops a slide on the glacier.

## Play loop

1. **Route card.** A postcard of the view, the pitches (a `*` marks a crux), the gear you need and have, the food you carry and what's worth bringing. `E` starts, `Esc` backs out without spending time.
2. **Pitch banner.** Each pitch announces its name and a line of beta ("Chalk up before the bulge").
3. **Read.** Rings mark the holds within reach with what each move costs now (shoes, chalk, chimney rhythm, weather and slush included). Rests and cruxes are labelled.
4. **Move.** Up, up-left, up-right. A move costs stamina and six game minutes. Run out and you fall.
5. **Protect.** `Space` clips a bolt (or an old piton) with a quickdraw, or places a cam in a crack. The rope runs through every piece; runouts of four moves or more end the climb safely.
6. **Crux.** One hard move on some pitches asks for a short skill check. Perfect gives stamina back; a slip costs some.
7. **Belay.** At a ledge you recover 10 stamina (16 with a belay device), can eat (`E`), and the next pitch starts. Rope and gear are recovered by your partner.
8. **Nights.** On a wall, a night needs a real meal (30+ energy); the night scene plays, and you wake rested.
9. **Top out or retreat.** The result card shows time, falls, style (onsight, hard-won, aided), how the cruxes went and a fact about the route. Retreating keeps your gear; the tick only comes with the top. The caller records the tick once and applies the elapsed time once.

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
| snow, ice | Kicked steps and chipped holds; crevasses with snow bridges; slush after noon; a fall slides 2 to 3 moves | Lyell Glacier |

## Crux checks

| Kind | How | Where |
|---|---|---|
| timing | A marker sweeps a bar; `Space` in the green (center is perfect). The green is wider with shoes, chalk, and on a top rope | Firefall Slab's bulge, Swan Slab's polished wave, Separate Reality's lip, Astroman's Boulder Problem... |
| mash | Tap Up quickly | Nutcracker's mantel |
| rhythm | Alternate Left and Right to the beat | The Narrows, Harding Slot, the King Swing, the Pendulum |

Bots and tests resolve cruxes as an average move; the screen sets `ClimbState.interactive`.

## Economy

Each hold costs `2 + round(grade * 1.2) + 0..2` (grade is the pitch's 1-5 difficulty), reduced by shoes and chalk. A pitch is 7 to 12 moves. Stamina is 100; belays give +10; a wall night restores it all. So short early routes cost nothing to eat for, and the long ones (Steck-Salathé, Astroman, the Nose) need real provisions: `food` in each route's profile is what a careful climber needs, and the route card says so. `tests/climb_test.tscn` plays every route with a bot and exactly that food and checks 85 % tops out.

## Real places

`scripts/climb/climb_profiles.gd` holds each route's place, the rock, the skyline you see (Half Dome, El Capitan, the Three Brothers, Bridalveil, Sentinel Rock, Glacier Point, the Cockscomb, Mount Lyell...), the ground at its foot, its summit, its belayer, descent, facts for the result card, and the real names of its pitches where known (the Grack, Bathtub, Wilson Overhang, the Narrows, Boulder Problem, Enduro Corner, Harding Slot, Sickle Ledge, El Cap Tower, King Swing, Great Roof, Changing Corners...). Where a guidebook disagrees or I could not verify, the text stays general.

## Verification

- `tests/climb_test.tscn`: every route has a profile and authored pitches, every pitch has a line, a careful bot tops every route, each piece of gear does its job, cruxes, weather, nights.
- `tests/climb_screen_test.tscn` (needs a window): plays every route on the real screen, through crux checks, nights and the result card.
- Screenshots: see the README.

## Not done yet

Rappel and descent scenes (the profiles record each descent), save-in-the-middle, gamepad glyphs on the hints, sound, and tribal review of anything on these routes that touches Native places (none of the current text does).
