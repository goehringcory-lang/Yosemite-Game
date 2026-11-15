class_name SeamBackdrop
extends Node2D
## The forest past the edges of the maps. Each region is its own rectangle,
## so where two are laid side by side at a seam (see Seam) and one is wider
## than the other, the camera can look past both into the corner between
## them: it sees deep woods there, not the void.
##
## The woods are drawn in two layers. Under the maps (Z): the forest floor in
## deep shade, with trees and understory standing on a jittered grid, darker
## and bluer the further they stand from a map, so the forest falls away into
## shadow. Over everything standing on the maps (FRINGE_Z): the brush along
## each map's edge and the trees whose crowns reach just over it. And on the
## maps' ground (SHADE_Z): the woods' shade, lying a few ragged pixels onto
## it. So a map's ground darkens into ferns and treetops and doesn't end along
## a ruled line.

const SeasonalDressing = preload("res://scripts/world/seasonal_dressing.gd")

## Under everything the regions draw (their lowest is -12).
const Z := -40
## Over the people, trees and props on the maps (and the birds, sparkles and
## spray above them), under the water's reflections, the cloud shadows and
## the weather.
const FRINGE_Z := 8
## On the maps' painted ground and cliffs, under everything standing on them.
const SHADE_Z := -6
const FLOOR := Color(0.13, 0.17, 0.1)
## The floor's tones in deep shade: needle duff, darker hollows, lighter
## patches and the odd dry fleck; and the same under snow.
const FLOOR_TONES: Array[Color] = [FLOOR, Color(0.112, 0.148, 0.092), Color(0.15, 0.188, 0.11), Color(0.19, 0.17, 0.115)]
const SNOW_TONES: Array[Color] = [Color(0.6, 0.67, 0.78), Color(0.55, 0.62, 0.745), Color(0.66, 0.725, 0.82), Color(0.47, 0.54, 0.67)]
## Lying snow (Seasons.snow_cover) past this whitens the floor.
const SNOW_FLOOR := 0.25
## Trees stand on a jittered grid this many pixels apart.
const SPACING := 44.0
## The tallest tree: one standing this far below the view still reaches
## into it.
const TALLEST := 320.0
## One cell in five has no tree, so the rows behind show through.
const CLEARINGS := 0.2
## And about half have a fern or a shrub.
const UNDERSTORY := 0.55
const SPRITE_DIR := "res://assets/sprites/ahwahnee/"
const TREES: Array[String] = [
	"tree_white_fir", "tree_incense_cedar_a", "tree_incense_cedar_b",
	"tree_sugar_pine_a", "tree_sugar_pine_b", "tree_ponderosa_a",
]
## The brush: [picture, clear rows above its art, clear rows below it, clear
## columns either side]. The manzanita keeps its leaves through the winter,
## when the rest is bare twigs.
const BRUSH: Array = [
	["plant_fern_a", 8, 0, 4], ["plant_fern_b", 14, 0, 4], ["plant_shrub_a", 2, 4, 2],
	["plant_shrub_b", 2, 4, 2], ["plant_bracken", 8, 2, 0], ["plant_manzanita", 2, 2, 0],
]
## Brush stands about this far apart along a map's top and bottom edges and
## along its sides (it is wider than it is tall), with gaps: one spot in
## four is bare.
const BRUSH_STEP := 44.0
const BRUSH_STEP_SIDE := 30.0
const BRUSH_GAPS := 0.25
## How far a treetop below a map, a crown beside one, and the brush along
## one may reach over its edge (pixels). Kept small: what stands there hides
## the last of the map.
const TIP_OVER := 56.0
const CROWN_OVER := 24.0
const BRUSH_OVER := 14.0
## The woods' shade on a map's ground along its edge: two flat steps of it,
## each a few pixels deep and ragged, in columns this wide. On snow it is
## the blue of a drift's shadow, and fainter.
const SHADOW := Color(0.04, 0.08, 0.07)
const SHADOW_ON_SNOW := Color(0.33, 0.43, 0.6)
const SHADE_DEEP := 0.5
const SHADE_PALE := 0.24
const SHADE_ON_SNOW := 0.6
const SHADE_COLUMN := 4.0
## The light on what stands at a map's edge, and deep in the woods; the
## woods are as dark as they get this far (pixels) from the nearest map.
const NEAR := Color(0.93, 0.96, 0.91)
const FAR := Color(0.36, 0.45, 0.5)
## The brush along a map's edge stands in the trees' shade.
const BRUSH_LIGHT := Color(0.62, 0.73, 0.61)
const DEEP := 280.0
const SHADES := 5.0

var _rect := Rect2()
## The maps themselves, which hide whatever is drawn under them.
var _maps: Array[Rect2] = []
## Where the maps' cliff paintings meet the sky along their tops (see
## [method skies_of]): above those stretches the sky goes on up, not woods.
var _skies: Array = []
## What stands in the woods, back to front: [texture, top-left, tint] each.
## Under the maps, and over them.
var _under: Array = []
var _fringe: Array = []
## The shade on the maps' ground along their edges: [rect, alpha] each.
var _shade_rects: Array = []
var _snowy := false
## The stretches of sky drawn above the maps: [rect, color] each.
var _sky_rects: Array = []
var _area := Rect2()
## The season and snow the woods were last laid out for.
var _look := ""
## The layers besides this node's own (the trees and understory under the
## maps): the floor and sky behind them, what stands over the maps, and the
## shade on the maps' ground.
var _behind := Node2D.new()
var _over := Node2D.new()
var _shadow := Node2D.new()
var _floor: Texture2D

## Painting -> where its top row is sky, written by tools/seams/wall_skies.py
## (reading the paintings here would fetch them back from the graphics card,
## which stalls a frame).
const SKIES_PATH := "res://data/park/wall_skies.json"
static var _wall_skies = null
static var _floors := {}


func _ready() -> void:
	name = "SeamBackdrop"
	z_index = Z
	z_as_relative = false
	# the floor is one small picture, tiled (only its layer repeats: a
	# tree's picture must never wrap round at its edges)
	_behind.name = "Floor"
	_behind.show_behind_parent = true
	_behind.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_behind.draw.connect(_draw_floor)
	add_child(_behind)
	_over.name = "Fringe"
	_over.z_index = FRINGE_Z
	_over.z_as_relative = false
	_over.draw.connect(_draw_fringe)
	add_child(_over)
	_shadow.name = "Shade"
	_shadow.z_index = SHADE_Z
	_shadow.z_as_relative = false
	_shadow.draw.connect(_draw_shade)
	add_child(_shadow)
	set_process(_rect.has_area())


func _notification(what: int) -> void:
	# one that never entered the tree still owns its layers
	if what == NOTIFICATION_PREDELETE:
		for layer: Node2D in [_behind, _over, _shadow]:
			if is_instance_valid(layer) and layer.get_parent() == null:
				layer.free()


## Fills [param rect] (all the camera can see: it stops at rect's edges) with
## woods, or nothing when it's empty. Trees go only where none of
## [param maps] cover the ground.
func cover(rect: Rect2, maps: Array[Rect2] = [], skies: Array = []) -> void:
	if rect == _rect and maps == _maps and skies == _skies:
		return
	_rect = rect
	_maps = maps
	_skies = skies
	set_process(rect.has_area())
	_lay_out()


## The woods turn with the year: the firs and cedars carry snow in winter,
## the ferns go gold in fall, and the floor whitens while snow lies.
func _process(_delta: float) -> void:
	if _look_key() != _look:
		_lay_out()


func _look_key() -> String:
	return "%d:%s" % [clampi(GameClock.season, 0, 3), Seasons.snow_cover() > SNOW_FLOOR]


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



## Works out what stands where: the trees and understory on their grid, each
## under the maps or over them, and the brush along the maps' edges.
func _lay_out() -> void:
	_under.clear()
	_fringe.clear()
	_shade_rects.clear()
	_sky_rects.clear()
	_look = _look_key()
	queue_redraw()
	_behind.queue_redraw()
	_over.queue_redraw()
	_shadow.queue_redraw()
	if not _rect.has_area():
		return
	var season := clampi(GameClock.season, 0, 3)
	_snowy = Seasons.snow_cover() > SNOW_FLOOR
	_floor = _floor_texture(_snowy)
	# What the camera can see (it stops at the edges of rect), on the art's
	# two-pixel grain like everything standing on the maps.
	_area = Rect2((_rect.position / 2.0).floor() * 2.0, (_rect.size / 2.0).ceil() * 2.0 + Vector2(2, 2))
	# the sky going on up above a map whose cliffs stand against it
	for i in mini(_maps.size(), _skies.size()):
		for span: Array in _skies[i]:
			var above := Rect2(span[0], _area.position.y, span[1] - span[0], _maps[i].position.y - _area.position.y)
			if above.has_area():
				_sky_rects.append([above, span[2]])
	var trees: Array[Texture2D] = []
	for tree_name in TREES:
		trees.append(_picture(tree_name, season))
	var brush: Array[Texture2D] = []
	for plant: Array in BRUSH:
		brush.append(_picture(plant[0], season))
	# [foot y, texture, top-left, tint] each
	var under := []
	var over := []
	# The grid: a column past the view either side, and down to where the
	# tallest tree standing below the view still reaches into it. Most of it
	# lies under a map: only the cells off them are looked at.
	var first := Vector2i(floori(_area.position.x / SPACING) - 1, floori(_area.position.y / SPACING))
	var last := Vector2i(floori(_area.end.x / SPACING) + 1, floori((_area.end.y + TALLEST) / SPACING))
	var below := _below_view(first.x, last.x + 1)
	for row in range(first.y, last.y + 1):
		var runs := _open_cells(first.x, row, last.x + 1 - first.x)
		if row * SPACING >= _rect.end.y:
			runs = _both(runs, below)
		for run: Vector2i in runs:
			for col in range(run.x, run.y):
				var cell := Vector2i(col, row)
				var noise := _hash(cell)
				var foot := _snap((Vector2(cell) + Vector2(0.2 + 0.6 * fmod(noise * 7.0, 1.0), 0.2 + 0.6 * fmod(noise * 13.0, 1.0))) * SPACING)
				if _hash(cell + Vector2i(91, 7)) >= CLEARINGS and _in_woods(foot):
					var tree: Texture2D = trees[int(noise * trees.size()) % trees.size()]
					var size := tree.get_size()
					var at := foot - Vector2(size.x * 0.5, size.y - 8.0)
					if at.y >= _rect.end.y:
						# too short to reach up into the view from there
						continue
					var item := [foot.y, tree, at, _shade(_gap(foot))]
					var layer := _standing(foot, Rect2(at, size))
					# one standing past the view is never drawn over a map:
					# the camera can't look past that edge, and with no seam
					# open nothing stands there
					if layer == 2 and not _rect.has_point(foot):
						layer = 1
					match layer:
						1: under.append(item)
						2: over.append(item)
				var pick := _hash(cell + Vector2i(13, 57))
				if pick < UNDERSTORY:
					var kind := int(pick / UNDERSTORY * BRUSH.size()) % BRUSH.size()
					var root := _snap((Vector2(cell) + Vector2(fmod(pick * 31.0, 1.0), fmod(pick * 17.0, 1.0))) * SPACING)
					var plant: Texture2D = brush[kind]
					if root.y - plant.get_height() < _rect.end.y and _in_woods(root):
						under.append([root.y, plant, root - Vector2(plant.get_width() * 0.5, plant.get_height() - float(BRUSH[kind][2])), _shade(_gap(root))])
	for i in _maps.size():
		_line_edges(_maps[i], brush, over)
	_under = _back_to_front(under)
	_fringe = _back_to_front(over)


## The grid cells of row [param row], from column [param from] for
## [param count], that no map wholly covers, as runs of columns [first,
## past the last].
func _open_cells(from: int, row: int, count: int) -> Array[Vector2i]:
	var runs: Array[Vector2i] = [Vector2i(from, from + count)]
	var top := row * SPACING
	for map in _maps:
		if top < map.position.y or top + SPACING > map.end.y:
			continue
		# the columns whose whole cell lies on this map
		runs = _without(runs, Vector2i(ceili(map.position.x / SPACING), floori(map.end.x / SPACING)))
	return runs


## The columns from [param from] to [param to] (not included) under which
## the woods come up to the bottom of the view, as runs: trees standing
## below it show there and nowhere else (a map hides the rest).
func _below_view(from: int, to: int) -> Array[Vector2i]:
	var runs: Array[Vector2i] = [Vector2i(from, to)]
	for map in _maps:
		if map.end.y < _rect.end.y - 1.0:
			continue
		# a tree's crown reaches a column and a half either side of its foot
		runs = _without(runs, Vector2i(ceili((map.position.x + SPACING * 1.5) / SPACING), floori((map.end.x - SPACING * 1.5) / SPACING)))
	return runs


## [param runs] without the columns of [param gone].
static func _without(runs: Array[Vector2i], gone: Vector2i) -> Array[Vector2i]:
	var left: Array[Vector2i] = []
	for run in runs:
		if gone.y <= run.x or gone.x >= run.y:
			left.append(run)
			continue
		if gone.x > run.x:
			left.append(Vector2i(run.x, gone.x))
		if gone.y < run.y:
			left.append(Vector2i(gone.y, run.y))
	return left


## The columns in both [param a] and [param b].
static func _both(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var shared: Array[Vector2i] = []
	for run in a:
		for other in b:
			var from := maxi(run.x, other.x)
			var to := mini(run.y, other.y)
			if to > from:
				shared.append(Vector2i(from, to))
	return shared


## [param items] ([foot y, texture, top-left, tint] each) as [texture,
## top-left, tint], sorted by foot so nearer ones overlap the ones behind
## them. Each sorts as one number: its foot, then its place in the list.
static func _back_to_front(items: Array) -> Array:
	var keys: Array[float] = []
	for i in items.size():
		keys.append((float(items[i][0]) + 1000000.0) * 65536.0 + i)
	keys.sort()
	var sorted := []
	for key in keys:
		var item: Array = items[int(fmod(key, 65536.0))]
		sorted.append([item[1], item[2], item[3]])
	return sorted


## Dresses the edges of [param map] that face the woods: the woods' shade
## lying a few ragged pixels onto its ground, and a fern or a shrub every
## so often (BRUSH_STEP), standing just off the map and reaching a few pixels over
## its edge. None where the next map or the sky is, or along an edge the
## camera can't look past.
func _line_edges(map: Rect2, brush: Array[Texture2D], out: Array) -> void:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var across := side.y != 0
		var length := map.size.x if across else map.size.y
		var from := map.position.x if across else map.position.y
		var key := side.x * 3 + side.y * 5 + 1000 + roundi((map.position.y if across else map.position.x) / 7.0)
		# The shade, along each stretch that faces the woods: the deep step
		# changes every other column and the pale one every third, so the
		# columns between changes are one strip.
		for stretch: Vector2 in _facing_woods(map, side):
			var columns := int((stretch.y - stretch.x) / SHADE_COLUMN)
			var run_from := 0
			var deep := 0.0
			var pale := 0.0
			for i in columns + 1:
				var along := stretch.x + i * SHADE_COLUMN
				var now_deep := 4.0 + 2.0 * floorf(4.0 * _hash(Vector2i(floori(along / 8.0), key)))
				var now_pale := 4.0 + 2.0 * floorf(5.0 * _hash(Vector2i(floori(along / 12.0), key + 7)))
				if i == 0:
					deep = now_deep
					pale = now_pale
				if now_deep == deep and now_pale == pale and i < columns:
					continue
				var start := stretch.x + run_from * SHADE_COLUMN
				_shade_rects.append([_strip(map, side, start, along - start, 0.0, deep), SHADE_DEEP])
				_shade_rects.append([_strip(map, side, start, along - start, deep, pale), SHADE_PALE])
				run_from = i
				deep = now_deep
				pale = now_pale
		# and the brush
		var apart := BRUSH_STEP if across else BRUSH_STEP_SIDE
		for step in int(length / apart) + 1:
			var noise := _hash(Vector2i(roundi(from / apart) + step, key))
			var along := from + (step + 0.6 * fmod(noise * 11.0, 1.0)) * apart
			if along > from + length or fmod(noise * 23.0, 1.0) < BRUSH_GAPS or not _faces_woods(map, side, along):
				continue
			var kind := int(noise * BRUSH.size()) % BRUSH.size()
			var plant: Texture2D = brush[kind]
			var size := plant.get_size()
			var clear_top := float(BRUSH[kind][1])
			var clear_bottom := float(BRUSH[kind][2])
			var clear_side := float(BRUSH[kind][3])
			var over := 2.0 + (BRUSH_OVER - 2.0) * fmod(noise * 5.0, 1.0)
			var at := Vector2.ZERO
			match side:
				Vector2i.UP:
					# behind the map: its foot a few pixels onto the map's top
					at = Vector2(along - size.x * 0.5, map.position.y + minf(over, 8.0) - (size.y - clear_bottom))
				Vector2i.DOWN:
					at = Vector2(along - size.x * 0.5, map.end.y - over - clear_top)
				Vector2i.LEFT:
					at = Vector2(map.position.x + over - (size.x - clear_side), along - size.y * 0.5)
				Vector2i.RIGHT:
					at = Vector2(map.end.x - over - clear_side, along - size.y * 0.5)
			at = _snap(at)
			out.append([at.y + size.y - clear_bottom, plant, at, BRUSH_LIGHT])


## True if the woods stand just past [param map]'s [param side] at
## [param along] it (x along its top and bottom, y along its sides), where
## the camera can see them.
func _faces_woods(map: Rect2, side: Vector2i, along: float) -> bool:
	for stretch: Vector2 in _facing_woods(map, side):
		if along >= stretch.x and along < stretch.y:
			return true
	return false


## The stretches of [param map]'s [param side] that face the woods, from x
## to y along it each: all of it the camera can look past, less where the
## other maps and the sky stand against it.
func _facing_woods(map: Rect2, side: Vector2i) -> Array[Vector2]:
	var across := side.y != 0
	# the line just past the edge
	var past := map.position.y - 6.0
	match side:
		Vector2i.DOWN: past = map.end.y + 6.0
		Vector2i.LEFT: past = map.position.x - 6.0
		Vector2i.RIGHT: past = map.end.x + 6.0
	var stretches: Array[Vector2] = []
	var view_from := _rect.position.y if across else _rect.position.x
	var view_to := _rect.end.y if across else _rect.end.x
	if past < view_from or past >= view_to:
		return stretches
	stretches.append(Vector2(maxf(map.position.x, _rect.position.x), minf(map.end.x, _rect.end.x)) if across
			else Vector2(maxf(map.position.y, _rect.position.y), minf(map.end.y, _rect.end.y)))
	var taken: Array[Rect2] = []
	for other in _maps:
		if other != map:
			taken.append(other)
	for sky: Array in _sky_rects:
		taken.append(sky[0])
	for rect in taken:
		var from := rect.position.y if across else rect.position.x
		var to := rect.end.y if across else rect.end.x
		if past < from or past >= to:
			continue
		var gone := Vector2(rect.position.x, rect.end.x) if across else Vector2(rect.position.y, rect.end.y)
		var left: Array[Vector2] = []
		for stretch in stretches:
			if gone.y <= stretch.x or gone.x >= stretch.y:
				left.append(stretch)
				continue
			if gone.x > stretch.x:
				left.append(Vector2(stretch.x, gone.x))
			if gone.y < stretch.y:
				left.append(Vector2(gone.y, stretch.y))
		stretches = left
	return stretches


## A strip of [param map]'s ground from [param along] its [param side] for
## [param length], from [param near] pixels in from the edge and
## [param depth] deep.
func _strip(map: Rect2, side: Vector2i, along: float, length: float, near: float, depth: float) -> Rect2:
	match side:
		Vector2i.UP: return Rect2(along, map.position.y + near, length, depth)
		Vector2i.DOWN: return Rect2(along, map.end.y - near - depth, length, depth)
		Vector2i.LEFT: return Rect2(map.position.x + near, along, depth, length)
	return Rect2(map.end.x - near - depth, along, depth, length)


## True if a tree may stand at [param foot]: off every map, and not up in
## the sky above one (nor within [param clear] of it).
func _in_woods(foot: Vector2, clear := SPACING) -> bool:
	for map in _maps:
		if map.has_point(foot):
			return false
	for sky: Array in _sky_rects:
		if (sky[0] as Rect2).grow(clear).has_point(foot):
			return false
	return true


## How far [param foot] is from the nearest map.
func _gap(foot: Vector2) -> float:
	var nearest := INF
	for map in _maps:
		var off := Vector2(maxf(maxf(map.position.x - foot.x, foot.x - map.end.x), 0.0), maxf(maxf(map.position.y - foot.y, foot.y - map.end.y), 0.0))
		nearest = minf(nearest, off.length())
	return nearest


## The light on something that far from the nearest map, in a few flat steps.
func _shade(gap: float) -> Color:
	if gap == INF:
		return NEAR
	var t := clampf((gap - 24.0) / DEEP, 0.0, 1.0)
	return NEAR.lerp(FAR, floorf(t * SHADES + 0.5) / SHADES)


## Where a tree at [param foot], drawn over [param rect], belongs: 1 under
## the maps (they hide what reaches onto them: its top, standing below a
## map, or its roots, standing above one), 2 over them (its top reaches no
## more than TIP_OVER onto the map above it, or its crown CROWN_OVER onto the
## map beside it), or 0 nowhere (it stands so close beside a map that the
## map's edge would slice its crown).
func _standing(foot: Vector2, rect: Rect2) -> int:
	var layer := 1
	var over := false
	for map in _maps:
		if not map.intersects(rect):
			continue
		if foot.y >= map.end.y:
			if map.end.y - rect.position.y <= TIP_OVER:
				over = true
			else:
				return 1
		elif foot.y > map.position.y:
			var reach := map.end.x - rect.position.x if foot.x >= map.end.x else rect.end.x - map.position.x
			if reach > CROWN_OVER:
				return 0
			over = true
	if over:
		layer = 2
	return layer


static func _snap(at: Vector2) -> Vector2:
	return (at / 2.0).round() * 2.0


## [param tex_name]'s picture for [param season] (the conifers' winter
## drawings carry snow, the brush turns in fall).
static func _picture(tex_name: String, season: int) -> Texture2D:
	var look: Array = SeasonalDressing._look_for(tex_name)
	if not look.is_empty() and look[season] != null:
		return look[season]
	return load(SPRITE_DIR + tex_name + ".png")


## The forest floor in deep shade, as a tile: flat tones in small clusters on
## the art's two-pixel grain, bare or under snow.
static func _floor_texture(snowy: bool) -> Texture2D:
	if _floors.has(snowy):
		return _floors[snowy]
	var tones := SNOW_TONES if snowy else FLOOR_TONES
	var cells := 48
	var image := Image.create(cells * 2, cells * 2, false, Image.FORMAT_RGB8)
	for y in cells:
		for x in cells:
			# a few hollows and lighter patches some art pixels across,
			# wrapping at the tile's edge, and the odd fleck
			var band := int(y / 4.0)
			var patch := _hash(Vector2i(int((x + band % 2 * 3) / 6.0) % int(cells / 6.0), band % int(cells / 4.0)) + Vector2i(301, 77))
			var tone: Color = tones[0]
			if patch < 0.16:
				tone = tones[1]
			elif patch > 0.9:
				tone = tones[2]
			if _hash(Vector2i(x, y) + Vector2i(977, 131)) > 0.988:
				tone = tones[3]
			image.fill_rect(Rect2i(x * 2, y * 2, 2, 2), tone)
	_floors[snowy] = ImageTexture.create_from_image(image)
	return _floors[snowy]


func _draw_floor() -> void:
	if not _rect.has_area():
		return
	_behind.draw_texture_rect(_floor, _area, true)
	for sky: Array in _sky_rects:
		_behind.draw_rect(sky[0], sky[1])


func _draw() -> void:
	for item: Array in _under:
		draw_texture(item[0], item[1], item[2])


func _draw_fringe() -> void:
	for item: Array in _fringe:
		_over.draw_texture(item[0], item[1], item[2])


func _draw_shade() -> void:
	var shade := SHADOW_ON_SNOW if _snowy else SHADOW
	var strength := SHADE_ON_SNOW if _snowy else 1.0
	for item: Array in _shade_rects:
		_shadow.draw_rect(item[0], Color(shade, item[1] * strength))


## A steady pseudo-random number in [0, 1) for a grid cell, so the woods
## look the same every time.
static func _hash(cell: Vector2i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 10007) / 10007.0
