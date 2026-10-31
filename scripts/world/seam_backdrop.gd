class_name SeamBackdrop
extends Node2D
## The forest past the edges of the maps, drawn behind them. Each region is
## its own rectangle, so where two are laid side by side at a seam (see
## Seam) and one is wider than the other, the camera can look past both
## into the corner between them: it sees deep woods there, not the void.

## Under everything the regions draw (their lowest is -12).
const Z := -40
const FLOOR := Color(0.13, 0.17, 0.1)
## Trees stand on a jittered grid this many pixels apart.
const SPACING := 44.0
const TREES: Array[Texture2D] = [
	preload("res://assets/sprites/ahwahnee/tree_white_fir.png"),
	preload("res://assets/sprites/ahwahnee/tree_incense_cedar_a.png"),
	preload("res://assets/sprites/ahwahnee/tree_incense_cedar_b.png"),
	preload("res://assets/sprites/ahwahnee/tree_sugar_pine_a.png"),
	preload("res://assets/sprites/ahwahnee/tree_sugar_pine_b.png"),
	preload("res://assets/sprites/ahwahnee/tree_ponderosa_a.png"),
]

var _rect := Rect2()
## The maps themselves, which hide whatever is drawn under them.
var _maps: Array[Rect2] = []


func _ready() -> void:
	name = "SeamBackdrop"
	z_index = Z
	z_as_relative = false


## Fills [param rect] (and a little around it) with woods, or nothing when
## it's empty. Trees go only where none of [param maps] cover the ground.
func cover(rect: Rect2, maps: Array[Rect2] = []) -> void:
	if rect == _rect and maps == _maps:
		return
	_rect = rect
	_maps = maps
	queue_redraw()


func _draw() -> void:
	if not _rect.has_area():
		return
	var area := _rect.grow(SPACING * 4.0)
	draw_rect(area, FLOOR)
	# Back rows first, so nearer trees overlap the ones behind them.
	var rows := int(area.size.y / SPACING) + 1
	var cols := int(area.size.x / SPACING) + 1
	var first := Vector2i((area.position / SPACING).floor())
	for row in rows:
		for col in cols:
			var cell := first + Vector2i(col, row)
			var noise := _hash(cell)
			var foot := (Vector2(cell) + Vector2(0.2 + 0.6 * fmod(noise * 7.0, 1.0), 0.2 + 0.6 * fmod(noise * 13.0, 1.0))) * SPACING
			if _maps.any(func(m: Rect2) -> bool: return m.has_point(foot)):
				continue
			var tree: Texture2D = TREES[int(noise * TREES.size()) % TREES.size()]
			var size := tree.get_size()
			draw_texture(tree, foot - Vector2(size.x * 0.5, size.y - 8.0), Color(0.82, 0.86, 0.8))


## A steady pseudo-random number in [0, 1) for a grid cell, so the woods
## look the same every time.
static func _hash(cell: Vector2i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10007) / 10007.0
