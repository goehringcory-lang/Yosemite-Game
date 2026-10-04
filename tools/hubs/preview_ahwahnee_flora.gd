extends SceneTree
## Draws the Ahwahnee flora and garden sprites and lays them out on grass in
## docs/ahwahnee_flora_preview.png (and _2.png), 3x, for looking at the art in
## one place.
##   godot --headless --path . -s res://tools/hubs/preview_ahwahnee_flora.gd
## Optional environment: PREVIEW_ONLY (sprite-name prefix to show alone),
## PREVIEW_SCALE (integer, default 3), PREVIEW_OUT (output path).
const FloraArt = preload("res://tools/hubs/ahwahnee_flora_art.gd")

const SHEETS := [
	["tree_", "log_"],
	["plant_", "rock_", "garden_"],
]


func _init() -> void:
	var art := FloraArt.new()
	art.save_all()
	var only := OS.get_environment("PREVIEW_ONLY")
	var scale := int(OS.get_environment("PREVIEW_SCALE")) if OS.get_environment("PREVIEW_ONLY") != "" or OS.get_environment("PREVIEW_SCALE") != "" else 3
	if scale <= 0:
		scale = 3
	var names: Array[String] = []
	for f in FloraArt.FILES:
		names.append(f)
	if names.is_empty():
		for f in DirAccess.get_files_at(ProjectSettings.globalize_path(FloraArt.DIR)):
			if f.ends_with(".png"):
				names.append(f.trim_suffix(".png"))
		names.sort()
	var sheet_i := 0
	for prefixes: Array in SHEETS:
		var picked: Array[String] = []
		for n in names:
			for p: String in prefixes:
				if n.begins_with(p) and (only == "" or n.begins_with(only)):
					picked.append(n)
					break
		if picked.is_empty():
			continue
		_sheet(picked, "res://docs/ahwahnee_flora_preview%s.png" % ("" if sheet_i == 0 else "_2") if OS.get_environment("PREVIEW_OUT") == "" else OS.get_environment("PREVIEW_OUT"), scale)
		sheet_i += 1
	quit()


func _sheet(picked: Array[String], out_path: String, scale: int) -> void:
	var max_w := int(OS.get_environment("PREVIEW_W")) if OS.get_environment("PREVIEW_W") != "" else 640
	var placed: Array = []
	var x := 4
	var y := 4
	var row_h := 0
	var total_w := 0
	for n in picked:
		var im := Image.load_from_file(ProjectSettings.globalize_path(FloraArt.DIR + n + ".png"))
		if x + im.get_width() + 4 > max_w:
			x = 4
			y += row_h + 6
			row_h = 0
		placed.append([im, x, y])
		x += im.get_width() + 8
		total_w = maxi(total_w, x)
		row_h = maxi(row_h, im.get_height())
	var sheet := Image.create_empty(mini(max_w, total_w + 4), y + row_h + 6, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("73aa52"))
	for p: Array in placed:
		var im: Image = p[0]
		sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(p[1], p[2]))
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path(out_path))
