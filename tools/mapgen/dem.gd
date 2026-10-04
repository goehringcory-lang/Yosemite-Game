extends RefCounted
## Elevation lookup from Terrarium-encoded terrain tiles (the AWS Open Data
## "Terrain Tiles" set; in the US the source is the USGS 3D Elevation
## Program). Tiles are downloaded once and cached.

const URL := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const SIZE := 256

var zoom: int
var cache_dir: String

var _tiles: Dictionary = {} # Vector2i -> PackedFloat32Array


func _init(tile_zoom: int, cache: String) -> void:
	zoom = tile_zoom
	cache_dir = cache
	DirAccess.make_dir_recursive_absolute(cache_dir)


## Elevation in meters at a longitude/latitude, bilinearly interpolated.
func sample(lon: float, lat: float) -> float:
	var n := float(SIZE << zoom)
	var px := (lon + 180.0) / 360.0 * n - 0.5
	var lat_rad := deg_to_rad(lat)
	var py := (1.0 - asinh(tan(lat_rad)) / PI) / 2.0 * n - 0.5
	var x0 := floori(px)
	var y0 := floori(py)
	var fx := px - x0
	var fy := py - y0
	var a := _pixel(x0, y0)
	var b := _pixel(x0 + 1, y0)
	var c := _pixel(x0, y0 + 1)
	var d := _pixel(x0 + 1, y0 + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Ground distance covered by one source pixel near [param lat], in meters.
func meters_per_pixel(lat: float) -> float:
	return 40075016.686 * cos(deg_to_rad(lat)) / float(SIZE << zoom)


func _pixel(x: int, y: int) -> float:
	var tile := _tile(Vector2i(floori(float(x) / SIZE), floori(float(y) / SIZE)))
	return tile[posmod(y, SIZE) * SIZE + posmod(x, SIZE)]


func _tile(key: Vector2i) -> PackedFloat32Array:
	if _tiles.has(key):
		return _tiles[key]
	var path := cache_dir.path_join("%d_%d_%d.png" % [zoom, key.x, key.y])
	if not FileAccess.file_exists(path):
		var url := URL % [zoom, key.x, key.y]
		print("  downloading elevation tile %s" % url)
		var output := []
		var code := OS.execute("curl", ["-sfL", "--retry", "3", "-o", path, url], output, true)
		if code != 0:
			push_error("Could not download %s (curl exit %d)" % [url, code])
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var image := Image.load_from_file(path)
	if image == null or image.get_width() != SIZE:
		push_error("Bad elevation tile %s" % path)
		_tiles[key] = heights
		return heights
	image.convert(Image.FORMAT_RGB8)
	var bytes := image.get_data()
	for i in SIZE * SIZE:
		heights[i] = bytes[i * 3] * 256.0 + bytes[i * 3 + 1] + bytes[i * 3 + 2] / 256.0 - 32768.0
	_tiles[key] = heights
	return heights
