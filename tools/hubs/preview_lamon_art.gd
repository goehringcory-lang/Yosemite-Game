extends SceneTree
## Draws the Lamon Homestead's sprites and lays them out on grass in
## docs/lamon_art_preview.png (for looking at the art in one place).
##   godot --headless --path . -s res://tools/hubs/preview_lamon_art.gd
const LamonArt = preload("res://tools/hubs/lamon_art.gd")


func _init() -> void:
	LamonArt.new().save_all()
	var dir := LamonArt.DIR
	var rows := [
		["camp_tent", "chuckah_empty", "chuckah_built"],
		["campfire", "mortar_slab", "leaching_basin"],
	]
	var sheet := Image.create_empty(300, 200, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("73aa52"))
	var y := 4
	var right := 0
	for row: Array in rows:
		var x := 4
		var row_h := 0
		for sprite_name: String in row:
			var im := Image.load_from_file(ProjectSettings.globalize_path(dir + sprite_name + ".png"))
			sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
			x += im.get_width() + 6
			row_h = maxi(row_h, im.get_height())
		right = maxi(right, x)
		y += row_h + 6
	sheet.crop(mini(right, 300), mini(y, 200))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://docs/lamon_art_preview.png"))
	quit()
