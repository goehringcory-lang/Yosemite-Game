extends RefCounted
## Downloads OpenStreetMap data through the Overpass API and caches it.
## Map data (c) OpenStreetMap contributors, available under the ODbL.

const ENDPOINT := "https://overpass-api.de/api/interpreter"
const USER_AGENT := "YosemiteGame-mapgen/1.0 (Godot map generator)"


## Returns the parsed Overpass response for [param query], downloading it
## into [param path] the first time.
static func fetch(query: String, path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		print("  querying Overpass for %s" % path.get_file())
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var query_path := path + ".query"
		var file := FileAccess.open(query_path, FileAccess.WRITE)
		file.store_string(query)
		file.close()
		var output := []
		var code := OS.execute("curl", ["-sf", "--retry", "3", "--max-time", "300",
			"-A", USER_AGENT, "-H", "Accept: application/json",
			"--data-urlencode", "data@" + query_path, "-o", path, ENDPOINT], output, true)
		DirAccess.remove_absolute(query_path)
		if code != 0:
			push_error("Overpass query for %s failed (curl exit %d)" % [path.get_file(), code])
			return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not parse %s; delete it to download again." % path)
		return {}
	return data


## Everything the region maps use, inside one bounding box.
static func region_query(south: float, west: float, north: float, east: float) -> String:
	var bbox := "(%f,%f,%f,%f)" % [south, west, north, east]
	var parts := PackedStringArray()
	for filter in ["highway", "waterway", "natural", "landuse", "leisure", "amenity",
			"building", "tourism", "railway", "water", "historic", "man_made"]:
		parts.append('way["%s"]%s;' % [filter, bbox])
	for filter in ["natural", "landuse", "leisure", "water", "building", "amenity", "tourism"]:
		parts.append('relation["%s"]["type"="multipolygon"]%s;' % [filter, bbox])
	parts.append('node["name"]%s;' % bbox)
	parts.append('node["natural"]%s;' % bbox)
	parts.append('node["waterway"]%s;' % bbox)
	return "[out:json][timeout:240];(%s);out geom;" % "".join(parts)


## Roads, rivers, lakes, glaciers, peaks, and the park boundary for the
## whole-park map and the travel routes.
static func park_query(south: float, west: float, north: float, east: float) -> String:
	var bbox := "(%f,%f,%f,%f)" % [south, west, north, east]
	return ("[out:json][timeout:300];("
		+ 'way["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|primary_link|secondary_link|tertiary_link)$"]%s;' % bbox
		+ 'way["waterway"="river"]%s;' % bbox
		+ 'way["waterway"="stream"]["name"]%s;' % bbox
		+ 'way["natural"="water"]%s;' % bbox
		+ 'relation["natural"="water"]%s;' % bbox
		+ 'way["natural"="glacier"]%s;' % bbox
		+ 'relation["natural"="glacier"]%s;' % bbox
		+ 'node["natural"="peak"]["name"]%s;' % bbox
		+ 'way["highway"="path"]["name"="Four Mile Trail"]%s;' % bbox
		+ ");out geom;")


## The park boundary (OpenStreetMap tags it boundary=protected_area).
static func boundary_query() -> String:
	return '[out:json][timeout:120];relation["boundary"="protected_area"]["name"="Yosemite National Park"];out geom;'
