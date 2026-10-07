extends RefCounted
## Seasonal looks for the Ahwahnee-style trees and plants, written to
## assets/sprites/ahwahnee/seasons/<sprite>_<season>.png. scripts/world/
## seasonal_dressing.gd swaps them in when the season changes, so the hand-
## built regions need no rebuild.
##
## The black oaks and dogwoods are redrawn by ahwahnee_flora_art.gd's own
## season argument (same trunk and limbs, new leaves, or bare). Everything
## else is a recolor of the finished sprite: each leaf pixel keeps its light
## or shadow and is mapped onto a new tone ramp, so the dithering and the
## dark rim survive. Run with
##   godot --headless --path . -s res://tools/hubs/build_seasonal_art.gd
##
## ## Contract
## Each file is the same size and anchor as its summer sprite (the one the
## scene uses), so the sprite swaps texture and nothing else.

const K = preload("res://tools/hubs/pixel_kit.gd")
const FloraArt = preload("res://tools/hubs/ahwahnee_flora_art.gd")
const OUT := FloraArt.DIR + "seasons/"

# Tone ramps, dark to light.
const STRAW := ["4a3a1e", "6b5530", "8c7440", "ad9450", "c9b266", "ddc982", "efe0a6"]
const BLEACHED := ["4a4438", "675f4e", "857b66", "a39983", "bdb39c", "d6ccb4", "e8e0cc"]
const SEED_HEAD := ["5a4228", "775a38", "957548", "b09258", "c8ae72"]
const GOLD_LEAF := ["3a3014", "574a1c", "7a6626", "9a8530", "b8a040", "d0b858", "e4d078"]
const RUST := ["3a1c12", "5a2a16", "7c3c1c", "9c5224", "b86c2c", "d08c3c", "e8b05c"]
const DORMANT := ["34302c", "4a443c", "625a4e", "7c7262", "978b78", "b2a690"]
const FALL_BLOOM := ["4a1a20", "7a2a22", "a8442a", "d0702e", "e8a038", "f6d060"]
const SNOW := ["8ea2b0", "b4c4d0", "d6e2ea", "eef4f8", "fbfdfe"]

## sprite name -> { season index: how to make it }. Seasons not listed use the
## sprite the scene already has. "hide" is handled by seasonal_dressing.gd.
const RECOLORS := {
	"plant_lupine": {2: "dry"},
	"plant_paintbrush": {2: "dry"},
	"plant_wildflowers_a": {2: "dry"},
	"plant_wildflowers_b": {2: "dry"},
	"plant_wildflowers_c": {2: "dry"},
	"plant_cornlily": {2: "dry"},
	"garden_flowerbed_a": {2: "bed_fall", 3: "bed_winter"},
	"garden_flowerbed_b": {2: "bed_fall", 3: "bed_winter"},
	"garden_flowerbed_c": {2: "bed_fall", 3: "bed_winter"},
	"garden_arbor": {2: "bed_fall", 3: "bare"},
	"plant_tall_grass_a": {2: "dry", 3: "bleached"},
	"plant_tall_grass_b": {2: "dry", 3: "bleached"},
	"plant_bracken": {2: "rust", 3: "dormant"},
	"plant_fern_a": {2: "gold", 3: "dormant"},
	"plant_fern_b": {2: "gold", 3: "dormant"},
	"plant_shrub_a": {2: "gold", 3: "bare"},
	"plant_shrub_b": {2: "gold", 3: "bare"},
	"plant_cattails": {2: "dry", 3: "bleached"},
	"tree_apple_old": {2: "gold_fruit", 3: "bare"},
	"tree_ponderosa_a": {3: "snow"},
	"tree_ponderosa_b": {3: "snow"},
	"tree_ponderosa_c": {3: "snow"},
	"tree_incense_cedar_a": {3: "snow"},
	"tree_incense_cedar_b": {3: "snow"},
	"tree_white_fir": {3: "snow"},
}

const SEASON_NAMES := ["spring", "summer", "fall", "winter"]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var flora := FloraArt.new()
	# oaks: new spring growth, gold and rust, bare
	for v in 3:
		for s in [0, 2, 3]:
			_save("tree_black_oak_%s_%s" % ["abc"[v], SEASON_NAMES[s]], flora.tree_oak(v, s))
	# dogwoods: the scenes show the spring bloom
	for v in 2:
		for s in [1, 2, 3]:
			_save("tree_dogwood_bloom_%s_%s" % ["ab"[v], SEASON_NAMES[s]], flora.tree_dogwood(v, s))
	for sprite_name: String in RECOLORS:
		var src := Image.load_from_file(ProjectSettings.globalize_path(FloraArt.DIR + sprite_name + ".png"))
		src.convert(Image.FORMAT_RGBA8)
		var looks: Dictionary = RECOLORS[sprite_name]
		for s: int in looks:
			_save("%s_%s" % [sprite_name, SEASON_NAMES[s]], recolor(src, looks[s], hash(sprite_name)))


func _save(file_name: String, im: Image) -> void:
	im.save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))


static func ramp(hexes: Array) -> Array[Color]:
	return FloraArt.ramp(hexes)


static func _t(col: Color) -> float:
	return clampf((col.get_luminance() - 0.08) / 0.62, 0.0, 1.0)


static func _pick(r: Array[Color], t: float, x: int, y: int) -> Color:
	return FloraArt.shade(r, t, x, y)


## Recolors [param src] for [param mode]. Green pixels are leaves and take the
## mode's leaf ramp by how lit they were; saturated non-green pixels are
## flowers or fruit; gray, brown and shadow pixels (stone, bark, pots, the
## ground shadow) stay.
static func recolor(src: Image, mode: String, seed_value: int) -> Image:
	var im := src.duplicate() as Image
	var leaf: Array[Color] = ramp(STRAW)
	var bloom: Array[Color] = []
	var bloom_to_leaf := false
	var thin := 0.0
	var keep_fruit := false
	var whites_are_flowers := true
	match mode:
		"dry":
			bloom = ramp(SEED_HEAD)
		"bleached":
			leaf = ramp(BLEACHED)
			bloom = ramp(SEED_HEAD)
		"rust":
			leaf = ramp(RUST)
		"gold":
			leaf = ramp(GOLD_LEAF)
		"gold_fruit":
			leaf = ramp(GOLD_LEAF)
			keep_fruit = true
		"dormant":
			leaf = ramp(DORMANT)
			thin = 0.25
		"bare":
			leaf = ramp(DORMANT)
			thin = 0.6
			bloom_to_leaf = true
		"bed_fall":
			leaf = ramp(GOLD_LEAF)
			bloom = ramp(FALL_BLOOM)
			whites_are_flowers = false
		"bed_winter":
			leaf = ramp(DORMANT)
			bloom_to_leaf = true
			thin = 0.2
			whites_are_flowers = false
		"snow":
			leaf = ramp(SNOW)
	var w := im.get_width()
	var h := im.get_height()
	for y in h:
		for x in w:
			var col := src.get_pixel(x, y)
			if col.a < 0.95:
				continue
			var kind := _kind(col, whites_are_flowers)
			if kind == "other":
				continue
			var t := _t(col)
			if mode == "snow":
				# snow settles on the lit side of the boughs
				if kind == "leaf" and t > 0.48 and K.hash2(x, y, seed_value) < (t - 0.4) * 1.1:
					im.set_pixel(x, y, _pick(leaf, (t - 0.4) * 1.4, x, y))
				continue
			if kind == "leaf":
				if thin > 0.0 and t > 0.12 and K.hash2(x, y, seed_value) < thin:
					im.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					im.set_pixel(x, y, _pick(leaf, t, x, y))
			elif kind == "flower":
				if keep_fruit:
					continue
				if bloom_to_leaf:
					if thin > 0.0 and K.hash2(x, y, seed_value) < thin:
						im.set_pixel(x, y, Color(0, 0, 0, 0))
					else:
						im.set_pixel(x, y, _pick(leaf, t * 0.8, x, y))
				else:
					im.set_pixel(x, y, _pick(bloom if not bloom.is_empty() else leaf, t, x, y))
	return im


static func _kind(col: Color, whites_are_flowers: bool) -> String:
	var s := col.s
	var hue := col.h
	var lum := col.get_luminance()
	if s < 0.2:
		return "flower" if whites_are_flowers and lum > 0.8 else "other"
	if hue >= 0.16 and hue <= 0.5:
		return "leaf"
	if hue >= 0.07 and hue < 0.16 and s < 0.55 and lum < 0.55:
		return "other" # bark, soil, pots
	if hue < 0.07 and s < 0.5 and lum < 0.5:
		return "other"
	return "flower"
