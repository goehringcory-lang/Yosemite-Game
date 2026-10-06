class_name ClimbLayout
extends RefCounted
## Where things sit on the 480 x 270 climbing screen, shared by the painters
## and the screen itself.

const SCREEN := Vector2(480, 270)
## Size of one hold cell on screen.
const COL_W := 30.0
const ROW_H := 24.0
## Left edge of the hold grid.
const GRID_X := 118.0
## Width of the wall picture. Its right edge is ragged against the sky.
const WALL_W := 322
## Where a hold row sits on screen when the view is centered on the climber
## (the climber's torso hangs about 20 px below the hold).
const ANCHOR_Y := 158.0
## Rows of wall painted under the belay ledge and over the top ledge.
const ROWS_BELOW := 6
const ROWS_ABOVE := 9


## A chimney's slot is just wide enough for a person: its center and half width.
const CHIMNEY_X := GRID_X + 2.5 * COL_W
const CHIMNEY_HALF := 12


static func wall_height(top_row: int) -> int:
	return int((top_row + ROWS_ABOVE + ROWS_BELOW) * ROW_H)


## Pixel position of hold (r, c) inside the wall picture.
static func wall_px(top_row: int, r: int, c: int) -> Vector2:
	return Vector2(GRID_X + (c + 0.5) * COL_W, (top_row + ROWS_ABOVE - r - 0.5) * ROW_H)


# ---- Roof pitches run sideways: the climber hangs under a ceiling and moves
# ---- right along its crack. Rows run left to right across the picture.
const ROOF_ROW_W := 28.0
## Where the climber hangs on screen when the view is centered on them.
const ROOF_X := 190.0
## The y of the roof crack on screen.
const ROOF_Y := 96.0
const ROOF_BEFORE := 7
const ROOF_AFTER := 8
## How far above the crack the final ledge sits.
const ROOF_TOP_LIFT := 46.0


static func roof_width(top_row: int) -> int:
	return int((top_row + 1 + ROOF_BEFORE + ROOF_AFTER) * ROOF_ROW_W)


## How far up (in pixels) hold row [param r] is lifted: the last two rows turn
## the lip and climb onto the ledge above.
static func roof_lift(top_row: int, r: float) -> float:
	return clampf((r - (top_row - 2)) / 2.0, 0.0, 1.0) * ROOF_TOP_LIFT


## Pixel position of hold (r, c) inside the roof picture.
static func roof_px(top_row: int, r: float, c: float) -> Vector2:
	return Vector2((r + ROOF_BEFORE + 0.5) * ROOF_ROW_W, ROOF_Y + (c - 2.0) * 4.0 - roof_lift(top_row, r))
