class_name WildlifeSheet
extends RefCounted
## Where each animal is on assets/sprites/wildlife.png (painted by
## tools/npcgen/wildlife_art.gd): a row per animal of 40x32 cells, feet on
## row 30 of each cell, facing right.
##
##   squirrels:       0 sitting up nibbling, 1 sitting up alert, 2 and 3 bounding
##   birds:           0 standing, 1 pecking, 2 wings up, 3 wings down
##   peregrine:       0 gliding, 1 wings up, 2 stooping, 3 wings down, 4 perched
##   great gray owl:  0 sitting, 1 face turned, 2 wings up, 3 wings down, 4 plunging
##   bobcat:          0 step, 1 passing, 2 other step, 3 stalking, 4 looking at
##                    you, 5 pouncing, 6 sitting
##   heard birds, and the fish with no backpack icon: a single picture
##                    each, for the Wildlife journal

const PATH := "res://assets/sprites/wildlife.png"
const CELL := Vector2(40, 32)
## How far the feet are above the bottom of a cell.
const FEET := 1.0
const COLUMNS := 7
const ROWS := [
	"western_gray_squirrel",
	"california_ground_squirrel",
	"douglas_squirrel",
	"golden_mantled_ground_squirrel",
	"acorn_woodpecker",
	"clarks_nutcracker",
	"peregrine_falcon",
	"great_gray_owl",
	"bobcat",
	"mountain_chickadee",
	"great_horned_owl",
	"rainbow_trout",
	"sacramento_sucker",
]


## The sheet, loaded with the class (not by path, so the painter can run
## before it exists; and not on first use, since a texture first loaded in
## the middle of a _draw() can show as a white box).
static var _sheet: Texture2D = load(PATH) if ResourceLoader.exists(PATH) else null


static func sheet() -> Texture2D:
	if _sheet == null:
		_sheet = load(PATH)
	return _sheet


static func row(id: String) -> int:
	return ROWS.find(id)


static func has(id: String) -> bool:
	return ROWS.has(id)


## The source rectangle of [param frame] of [param id].
static func region(id: String, frame := 0) -> Rect2:
	return Rect2(frame * CELL.x, row(id) * CELL.y, CELL.x, CELL.y)


## Draws [param frame] of [param id] on [param item] with its feet on
## [param at], mirrored when [param facing] is -1.
static func draw(item: CanvasItem, id: String, frame: int, at: Vector2, facing := 1, alpha := 1.0) -> void:
	item.draw_set_transform(at.round(), 0.0, Vector2(facing, 1))
	item.draw_texture_rect_region(sheet(), Rect2(-CELL.x / 2.0, -CELL.y + FEET + 1.0, CELL.x, CELL.y), region(id, frame), Color(1, 1, 1, alpha))
	item.draw_set_transform(Vector2.ZERO)


## A picture of [param id] for the Wildlife journal.
static func icon(id: String, frame := 0) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet()
	atlas.region = region(id, frame)
	return atlas
