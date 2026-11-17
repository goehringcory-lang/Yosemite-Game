extends Node
## Checks that every hand-made outdoor area shows the ground painted for the
## 32px game (tools/art32/ground32/paint.py) and not a 16px builder's ground
## doubled up. A builder leaves its own ground behind whenever an area is
## rebuilt (blotchy grass, brown roads with no lines, pale flat water), until
## tools/hubs/finish_valley_floor.sh paints it again.
##
## The two are told apart by their colors: a builder's ground is snapped to
## the game's 42-color palette (tools/art32/valley_days.gpl), while the native
## painter works in ramps with steps between the palette's, so nearly every
## pixel of its ground is off the palette.
## Run: godot --headless --path . res://tests/ground_art_test.tscn
## Exit code is the number of failed checks.

const PALETTE_PATH := "res://tools/art32/valley_days.gpl"
## Areas that keep a ground of their own (see paint.py's SKIP).
const OWN_GROUND := ["tuolumne_meadows", "tenaya_lake"]
## Every this many pixels across and down is looked at.
const STEP := 16
## A native ground is off the palette nearly everywhere; a builder's nowhere.
const LEAST_OFF_PALETTE := 0.5

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	var palette := _palette()
	check(palette.size() == 42, "the palette has its 42 colors (%d)" % palette.size())
	var looked := 0
	for file in DirAccess.get_files_at("res://scenes/regions/"):
		if not file.ends_with(".tscn"):
			continue
		var region := (load("res://scenes/regions/" + file) as PackedScene).instantiate() as Region
		var art: Sprite2D = region.get_node_or_null("GroundArt") if region else null
		if region == null or region.indoors or art == null or art.texture == null or region.region_id in OWN_GROUND:
			if region:
				region.free()
			continue
		var path := art.texture.resource_path
		var image := Image.new()
		var read := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		if read != OK:
			check(false, "%s: its ground picture %s can be read" % [region.region_id, path])
			region.free()
			continue
		var off := 0
		var seen := 0
		for y in range(STEP / 2, image.get_height(), STEP):
			for x in range(STEP / 2, image.get_width(), STEP):
				seen += 1
				if not palette.has(image.get_pixel(x, y).to_rgba32() >> 8):
					off += 1
		var share := float(off) / maxi(seen, 1)
		check(share >= LEAST_OFF_PALETTE, "%s: its ground is the native 32px painting, not a builder's (%d%% of %s is off the 16px palette; run tools/hubs/finish_valley_floor.sh %s)"
				% [region.region_id, roundi(share * 100.0), path.get_file(), region.region_id])
		looked += 1
		region.free()
	check(looked >= 20, "every hand-made outdoor area was looked at (%d)" % looked)
	print("%d failure(s)" % failures)
	get_tree().quit(failures)


## The palette's colors as 0xRRGGBB -> true.
func _palette() -> Dictionary:
	var colors := {}
	for line in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var parts := line.strip_edges().replace("\t", " ").split(" ", false)
		if parts.size() >= 3 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int():
			colors[(int(parts[0]) << 16) | (int(parts[1]) << 8) | int(parts[2])] = true
	return colors
