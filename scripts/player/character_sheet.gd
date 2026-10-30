class_name CharacterSheet
extends RefCounted
## How to read a person's sprite sheet (tools/npcgen): 32x48 frames, a row
## per facing (down, up, left, right) and a column per pose (Col). The first
## three columns are standing and the two walking steps; sheets drawn before
## the other poses (or drawn by hand) have only those, so every pose falls
## back to one of them (see [method column]).

const FRAME := Vector2i(32, 48)
const ROWS := {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}
## The facing of each row, top to bottom.
const FACINGS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]

## The columns, in tools/npcgen/npcgen.gd's COLUMNS order.
enum Col { STAND, STEP_A, STEP_B, BLINK, RUN_A, RUN_B, CROUCH, ARMS_UP, REACH, CARRY, CARRY_A, CARRY_B, TALK }
## What to show instead on a sheet with only the first three columns.
const FALLBACK := {
	Col.BLINK: Col.STAND, Col.RUN_A: Col.STEP_A, Col.RUN_B: Col.STEP_B,
	Col.CROUCH: Col.STAND, Col.ARMS_UP: Col.STAND, Col.REACH: Col.STAND,
	Col.CARRY: Col.STAND, Col.CARRY_A: Col.STEP_A, Col.CARRY_B: Col.STEP_B,
	Col.TALK: Col.STAND,
}

## The walk: a step, standing tall between, the other step, standing again.
const WALK := [Col.STEP_A, Col.STAND, Col.STEP_B, Col.STAND]
const RUN := [Col.RUN_A, Col.STEP_A, Col.RUN_B, Col.STEP_B]
const CARRY_WALK := [Col.CARRY_A, Col.CARRY, Col.CARRY_B, Col.CARRY]


## Columns on [param sheet].
static func columns(sheet: Texture2D) -> int:
	return maxi(1, sheet.get_width() / FRAME.x) if sheet else 1


## True if [param sheet] has every pose.
static func has_poses(sheet: Texture2D) -> bool:
	return columns(sheet) > Col.TALK


## The column to show for [param col] on [param sheet].
static func column(sheet: Texture2D, col: int) -> int:
	if col < columns(sheet):
		return col
	return FALLBACK.get(col, Col.STAND)


## The frame index (for a Sprite2D set up by [method setup]) of [param col]
## facing [param facing].
static func frame(sheet: Texture2D, facing: Vector2i, col: int) -> int:
	return ROWS.get(facing, 0) * columns(sheet) + column(sheet, col)


## Points [param sprite] at [param sheet], cut into its frames.
static func setup(sprite: Sprite2D, sheet: Texture2D) -> void:
	sprite.texture = sheet
	sprite.hframes = columns(sheet)
	sprite.vframes = 4


## The rect of [param col] facing [param facing] on [param sheet].
static func region(sheet: Texture2D, facing: Vector2i, col: int) -> Rect2:
	return Rect2(Vector2(column(sheet, col) * FRAME.x, ROWS.get(facing, 0) * FRAME.y), Vector2(FRAME))


## True while someone is blinking at [param time] (seconds): every three to
## five seconds for a moment, now and then twice, each person ([param seed])
## on their own beat.
static func blinking(time: float, seed: int) -> bool:
	var period := 3.2 + float(posmod(seed, 7)) * 0.3
	var t := fposmod(time + float(posmod(seed, 101)) * 0.37, period)
	return t < 0.13 or (posmod(seed, 3) == 0 and t > 0.3 and t < 0.43)
