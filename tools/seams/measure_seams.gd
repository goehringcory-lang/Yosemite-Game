extends Node
## Measures how far the road misses itself at each seam between two Valley
## floor areas (see Seam): it finds the painted road (asphalt or a dirt
## trail) in a strip along each map's edge, nearest the exit, and slides the
## neighbor along the edge so the two roads' middles meet. Writes
## res://data/park/seam_nudges.json, which Seam reads.
## Run: godot --headless --path . res://tools/seams/measure_seams.tscn

## How far along the edge either side of the exit to look, in pixels.
const WINDOW := 200
## A slide bigger than this means it found some other road or trail.
const MOST := 64
## How deep a strip of each map's edge to look at.
const STRIP := 6

var _images := {}


func _ready() -> void:
	var nudges := {}
	var regions := {}
	for file in DirAccess.get_files_at("res://scenes/regions/"):
		if file.ends_with(".tscn"):
			var region: Region = (load("res://scenes/regions/" + file) as PackedScene).instantiate()
			if region.indoors:
				region.free()
			else:
				regions[region.region_id] = region
	# Each way over a seam is measured from its own side; the two should be
	# opposites, so each keeps the average of itself and the other negated.
	var measured := {}
	var pairs := {}
	for id in regions:
		var region: Region = regions[id]
		for exit in Seam.candidates(region):
			if not regions.has(exit.target_region):
				continue
			var seam := Seam.make(region, exit, regions[exit.target_region], false)
			if seam == null:
				continue
			var shift := _best_shift(region, seam)
			if absi(shift) > MOST:
				shift = 0 # it found some other road
			measured[[id, String(exit.name)]] = shift
			pairs[[id, exit.target_region]] = [id, String(exit.name)]
	for key in measured:
		var target: String = (regions[key[0]] as Region).find_child(key[1], true, false).target_region
		var back = pairs.get([target, key[0]])
		var shift: float = measured[key]
		if back != null:
			shift = (shift - measured[back]) * 0.5
		print("%-22s %-20s -> %-22s %+.0f px (measured %+d)" % [key[0], key[1], target, shift, measured[key]])
		if roundi(shift) != 0:
			nudges.get_or_add(key[0], {})[key[1]] = roundi(shift)
	var file := FileAccess.open(Seam.NUDGES_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(nudges, "\t", true) + "\n")
	for region: Region in regions.values():
		region.free()
	get_tree().quit()


## The slide along the edge (in pixels, added to the neighbor's offset) that
## puts the middle of the painted road (asphalt or a dirt trail) on the
## neighbor's edge where it is on this one's.
func _best_shift(region: Region, seam: Seam) -> int:
	var mine := _ground(region)
	var theirs := _ground(seam.neighbor)
	if mine == null or theirs == null:
		return 0
	var here := _road_middle(mine, region, seam.point, -Vector2(seam.side), seam.side)
	var there := _road_middle(theirs, seam.neighbor, seam.point - seam.offset, Vector2(seam.side), seam.side)
	if is_nan(here) or is_nan(there):
		return 0
	return roundi(here - there)


## Where along the edge (relative to [param point]) the road nearest it is
## at its middle, looking a strip [param inward] into the map; NAN if none.
func _road_middle(image: Image, region: Region, point: Vector2, inward: Vector2, side: Vector2i) -> float:
	var along := Vector2(absf(side.y), absf(side.x))
	var way := PackedByteArray()
	way.resize(WINDOW * 2 + 1)
	for i in WINDOW * 2 + 1:
		var hits := 0
		for depth in range(2, STRIP + 4, 2):
			if _is_way(_pixel(image, region, point + along * (i - WINDOW) + inward * depth)):
				hits += 1
		way[i] = 1 if hits >= 2 else 0
	# the run of road pixels nearest the point
	var best := NAN
	var best_gap := INF
	var start := -1
	for i in way.size() + 1:
		var on := i < way.size() and way[i] == 1
		if on and start < 0:
			start = i
		elif not on and start >= 0:
			if i - start >= 12:
				var middle := (start + i - 1) * 0.5 - WINDOW
				if absf(middle) < best_gap:
					best_gap = absf(middle)
					best = middle
			start = -1
	return best


## Asphalt (dark neutral grey, or its painted lines) or a dirt trail's tan.
static func _is_way(c: Color) -> bool:
	if c.a == 0.0:
		return false
	var r := c.r8
	var g := c.g8
	var b := c.b8
	var asphalt := absi(r - g) < 14 and absi(g - b) < 16 and maxi(r, maxi(g, b)) < 120
	var line := (r > 200 and g > 200 and b > 180) or (r > 200 and g > 150 and b < 90)
	var dirt := r > g and g > b and r - b > 40 and r >= 150 and r - g < 40
	return asphalt or line or dirt


func _ground(region: Region) -> Image:
	var sprite := region.get_node_or_null("GroundArt") as Sprite2D
	if sprite == null or sprite.texture == null:
		return null
	var path := sprite.texture.resource_path
	if not _images.has(path):
		_images[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
	return _images[path]


## The ground's colour at [param at] (region pixels), clear off the picture.
func _pixel(image: Image, region: Region, at: Vector2) -> Color:
	var sprite := region.get_node("GroundArt") as Sprite2D
	var px := Vector2i(((at - sprite.position) / sprite.scale).floor())
	if px.x < 0 or px.y < 0 or px.x >= image.get_width() or px.y >= image.get_height():
		return Color(0, 0, 0, 0)
	return image.get_pixelv(px)
