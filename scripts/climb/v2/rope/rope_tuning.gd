class_name RopeTuning
extends RefCounted
## Rope and clipping numbers (thread 5). Fable reviewed the first set
## (2026-11-26). Metres unless said otherwise.

## A carabiner is clippable when it hangs within this of the tie-in. A long
## sling hangs lower, so a high bolt can be in reach with a sling but not a
## short draw.
const REACH_M := 1.25
## Sling lengths: a quickdraw, a cam's or nut's own sling, a long (alpine)
## sling.
const DRAW_M := 0.12
const OWN_SLING_M := 0.15
const LONG_M := 0.6
## Most pulls a clip takes (a draw at full stretch overhead). Rope a clip
## needs beyond this is paid as extra pump on the last pull, not given free.
const MAX_PULLS := 3
## A pull that would fetch only this much of an arm-length isn't needed.
const PULL_SLOP := 0.15
## Rope drag: 1 - exp(-(MU * bend + PER_BINER * carabiners + PER_M * rope
## out)), bends under MIN_BEND_DEG ignored. Drag shrinks the rope one pull
## fetches by up to FETCH_LOSS.
const DRAG_MU := 0.25
const DRAG_MIN_BEND_DEG := 6.0
const DRAG_PER_BINER := 0.01
const DRAG_PER_M := 0.002
const DRAG_FETCH_LOSS := 0.3
## A carabiner whose gate faces the climber rolls the rope out in a fall
## when the tie-in is above it and more than this to the gate side.
const ROLL_SIDE_M := 0.3
## Most pieces the rope rolls out of in one fall.
const MAX_ROLLS := 1
## The line above a piece counts as straight up when it drifts sideways
## less than this fraction of the height (and less than LINE_MAX_DX).
const LINE_DEADBAND := 0.35
const LINE_MAX_DX := 0.6
## Stretch in a catch: rope out * (BASE + FF * fall factor), softened less
## by drag, plus the belayer's give.
const STRETCH_BASE := 0.05
const STRETCH_FF := 0.10
const BELAYER_GIVE_M := 0.4
## After each move the belayer takes in this share of any slack left out;
## less than SLACK_GONE_M is taken in completely.
const BELAYER_TAKE := 0.5
const SLACK_GONE_M := 0.1
## Story routes start with the first bolt stick-clipped if it's this low.
const STICK_CLIP_MAX_Y := 3.5
