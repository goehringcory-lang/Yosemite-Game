extends SceneTree
## Draws the Yosemite Village sprites (valley_art.gd) and lays them out on
## grass in docs/valley_art_preview.png, with a dusk strip under the
## buildings showing their window glow.
##   godot --headless --path . -s res://tools/hubs/preview_valley_art.gd
const ValleyArt = preload("res://tools/hubs/valley_art.gd")


func _init() -> void:
	ValleyArt.new().save_all()
	var load_sprite := func(sprite_name: String) -> Image:
		return Image.load_from_file(ProjectSettings.globalize_path(ValleyArt.OUT + sprite_name + ".png"))
	var sheet := Image.create_empty(560, 250, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("4c7a3a"))
	var x := 6
	var y := 6
	var row_h := 0
	for sprite_name: String in ["village_store", "welcome_center", "museum", "bests_studio", "degnans", "wilderness_center", "valley_lodge"]:
		var im: Image = load_sprite.call(sprite_name)
		if x + im.get_width() > sheet.get_width() - 6:
			x = 6
			y += row_h + 6
			row_h = 0
		sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
		# dusk copy right under the day one is too tall; draw the glow on the day sprite instead
		x += im.get_width() + 8
		row_h = maxi(row_h, im.get_height())
	x = 6
	y += row_h + 8
	for sprite_name: String in ["umacha", "chuckah", "bear_box", "shuttle_stop"]:
		var im: Image = load_sprite.call(sprite_name)
		sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
		x += im.get_width() + 8
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://docs/valley_art_preview.png"))
	quit()
