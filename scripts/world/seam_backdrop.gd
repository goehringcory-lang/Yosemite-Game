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
## Trees in each run of a row drawn as one canvas item.
const RUN := 8
const TINT := Color(0.82, 0.86, 0.8)
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
	visible = rect.has_area()
	queue_redraw()
	_rebuild()


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
	draw_rect(_rect.grow(SPACING * 4.0), FLOOR)


## Out of sight under a map while the view is all on one: the floor and the
## woods would only be painted over.
func _process(_delta: float) -> void:
	if not _rect.has_area():
		return
	var view := _view_rect()
	visible = not _maps.any(func(m: Rect2) -> bool: return m.encloses(view))


func _view_rect() -> Rect2:
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := size / 2.0
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	return Rect2(center - size / 2.0, size)


## Lays out the woods: the sky strips on one child, then the trees in short
## runs of a row, one child each, back rows first so nearer trees overlap the
## ones behind them. Each run is its own canvas item, so the renderer leaves
## out the ones off screen (one item for all of them was drawn whole, about
## 1300 trees, every frame).
func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not _rect.has_area():
		return
	var area := _rect.grow(SPACING * 4.0)
	# the sky going on up above a map whose cliffs stand against it
	var skies: Array[Rect2] = []
	var sky_colors: Array[Color] = []
	for i in mini(_maps.size(), _skies.size()):
		for span: Array in _skies[i]:
			var above := Rect2(span[0], area.position.y, span[1] - span[0], _maps[i].position.y - area.position.y)
			if above.has_area():
				skies.append(above)
				sky_colors.append(span[2])
	if not skies.is_empty():
		add_child(_Run.new(skies, sky_colors))
	var rows := int(area.size.y / SPACING) + 1
	var cols := int(area.size.x / SPACING) + 1
	var first := Vector2i((area.position / SPACING).floor())
	for row in rows:
		var run: _Run = null
		for col in cols:
			if col % RUN == 0:
				if run and not run.trees.is_empty():
					add_child(run)
				run = _Run.new()
			var cell := first + Vector2i(col, row)
			var noise := _hash(cell)
			var foot := (Vector2(cell) + Vector2(0.2 + 0.6 * fmod(noise * 7.0, 1.0), 0.2 + 0.6 * fmod(noise * 13.0, 1.0))) * SPACING
			if _maps.any(func(m: Rect2) -> bool: return m.has_point(foot)) \
					or skies.any(func(m: Rect2) -> bool: return m.grow(SPACING).has_point(foot)):
				continue
			var tree: Texture2D = TREES[int(noise * TREES.size()) % TREES.size()]
			var size := tree.get_size()
			run.trees.append(tree)
			run.at.append(foot - Vector2(size.x * 0.5, size.y - 8.0))
		if run and not run.trees.is_empty():
			add_child(run)


## Some of the backdrop: trees, or (given rects) the sky strips.
class _Run extends Node2D:
	var trees: Array[Texture2D] = []
	var at: PackedVector2Array = []
	var rects: Array[Rect2] = []
	var colors: Array[Color] = []

	func _init(sky_rects: Array[Rect2] = [], sky_colors: Array[Color] = []) -> void:
		rects = sky_rects
		colors = sky_colors

	func _draw() -> void:
		for i in rects.size():
			draw_rect(rects[i], colors[i])
		for i in trees.size():
			draw_texture(trees[i], at[i], TINT)


static func _hash(cell: Vector2i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10007) / 10007.0
