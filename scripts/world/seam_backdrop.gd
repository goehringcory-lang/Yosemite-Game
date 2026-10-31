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
## Where the maps' cliff paintings meet the sky along their tops (see
## [method skies_of]): above those stretches the sky goes on up, not woods.
var _skies: Array = []

## Painting -> where its top row is sky, written by tools/seams/wall_skies.py
## (reading the paintings here would fetch them back from the graphics card,
## which stalls a frame).
const SKIES_PATH := "res://data/park/wall_skies.json"
static var _wall_skies = null


func _ready() -> void:
	name = "SeamBackdrop"
	z_index = Z
	z_as_relative = false


## Fills [param rect] (and a little around it) with woods, or nothing when
## it's empty. Trees go only where none of [param maps] cover the ground.
func cover(rect: Rect2, maps: Array[Rect2] = [], skies: Array = []) -> void:
	if rect == _rect and maps == _maps and skies == _skies:
		return
	_rect = rect
	_maps = maps
	_skies = skies
	queue_redraw()


## The stretches of sky along the top of [param region]'s cliff wall
## painting (a Sprite2D named "...Wall" drawn from its top-left corner), with
## the region's map at [param bounds]: [x from, x to, color] each, in the
## same coordinates as bounds. Empty if its top isn't sky.
static func skies_of(region: Region, bounds: Rect2) -> Array:
	if _wall_skies == null:
		_wall_skies = {}
		if FileAccess.file_exists(SKIES_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(SKIES_PATH))
			if parsed is Dictionary:
				_wall_skies = parsed
	var found := []
	var shift := bounds.position - region.get_bounds().position
	for child in region.get_children():
		var wall := child as Sprite2D
		if wall == null or wall.texture == null or wall.centered or not String(wall.name).ends_with("Wall") or wall.position.y > 0.5:
			continue
		var sky: Dictionary = _wall_skies.get(wall.texture.resource_path, {})
		for span in sky.get("spans", []):
			var x0: float = wall.position.x + float(span[0]) * wall.scale.x + shift.x
			var x1: float = wall.position.x + float(span[1]) * wall.scale.x + shift.x
			found.append([maxf(x0, bounds.position.x), minf(x1, bounds.end.x), Color.html(sky.get("color", "#4a80a5"))])
		break
	return found


func _draw() -> void:
	if not _rect.has_area():
		return
	var area := _rect.grow(SPACING * 4.0)
	draw_rect(area, FLOOR)
	# the sky going on up above a map whose cliffs stand against it
	var skies: Array[Rect2] = []
	for i in mini(_maps.size(), _skies.size()):
		for span: Array in _skies[i]:
			var above := Rect2(span[0], area.position.y, span[1] - span[0], _maps[i].position.y - area.position.y)
			if above.has_area():
				draw_rect(above, span[2])
				skies.append(above)
	# Back rows first, so nearer trees overlap the ones behind them.
	var rows := int(area.size.y / SPACING) + 1
	var cols := int(area.size.x / SPACING) + 1
	var first := Vector2i((area.position / SPACING).floor())
	for row in rows:
		for col in cols:
			var cell := first + Vector2i(col, row)
			var noise := _hash(cell)
			var foot := (Vector2(cell) + Vector2(0.2 + 0.6 * fmod(noise * 7.0, 1.0), 0.2 + 0.6 * fmod(noise * 13.0, 1.0))) * SPACING
			if _maps.any(func(m: Rect2) -> bool: return m.has_point(foot)) \
					or skies.any(func(m: Rect2) -> bool: return m.grow(SPACING).has_point(foot)):
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
