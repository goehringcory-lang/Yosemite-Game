extends SceneTree
## Draws the Camp 4 sprites (camp4_art.gd) and lays them out on camp dirt in
## docs/camp4_art_preview.png, with a dusk strip showing the tents' lantern
## light and the fire.
##   godot --headless --path . -s res://tools/hubs/preview_camp4_art.gd
const Camp4Art = preload("res://tools/hubs/camp4_art.gd")


func _init() -> void:
	Camp4Art.new().save_all()
	var load_sprite := func(sprite_name: String) -> Image:
		return Image.load_from_file(ProjectSettings.globalize_path(Camp4Art.OUT + sprite_name + ".png"))
	var sheet := Image.create_empty(480, 300, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("a4824e"))
	var rows := [
		["camp4_columbia_boulder", "camp4_boulder", "camp4_crash_pad", "camp4_board", "camp4_sign"],
		["camp4_tent_canvas", "camp4_tent_tarp", "camp4_tent_dome_0", "camp4_tent_dome_1", "camp4_tent_dome_2", "camp4_tent_dome_3", "camp4_fire_ring", "camp4_fire_ring_cold"],
		["camp4_table", "camp4_table_cook", "camp4_table_rack", "camp4_tarp_rack", "camp4_tarp_bigwall", "camp4_van", "camp4_slackline", "camp4_duff_0", "camp4_duff_1", "camp4_duff_2"],
	]
	var y := 6
	for row: Array in rows:
		var x := 6
		var row_h := 0
		for sprite_name: String in row:
			var im: Image = load_sprite.call(sprite_name)
			if x + im.get_width() > sheet.get_width() - 6:
				x = 6
				y += row_h + 6
				row_h = 0
			sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
			x += im.get_width() + 6
			row_h = maxi(row_h, im.get_height())
		y += row_h + 8
	# Dusk: the tents and the cook table darkened, with their glow added.
	var x := 6
	for sprite_name: String in ["camp4_tent_canvas", "camp4_tent_dome_1", "camp4_table_cook", "camp4_fire_ring"]:
		var im: Image = load_sprite.call(sprite_name)
		if sprite_name == "camp4_fire_ring":
			im = im.get_region(Rect2i(0, 0, Camp4Art.FIRE_W, Camp4Art.FIRE_H))
		var dusk := Image.create_empty(im.get_width() + 8, im.get_height() + 8, false, Image.FORMAT_RGBA8)
		dusk.fill(Color("2a2a40"))
		dusk.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(4, 4))
		for py in dusk.get_height():
			for px in dusk.get_width():
				var c := dusk.get_pixel(px, py)
				dusk.set_pixel(px, py, Color(c.r * 0.45, c.g * 0.45, c.b * 0.6))
		var glow_name := sprite_name + "_glow"
		if FileAccess.file_exists(ProjectSettings.globalize_path(Camp4Art.OUT + glow_name + ".png")):
			var g: Image = load_sprite.call(glow_name)
			for py in g.get_height():
				for px in g.get_width():
					var gc := g.get_pixel(px, py)
					if gc.a > 0.0:
						var c := dusk.get_pixel(px + 4, py + 4)
						dusk.set_pixel(px + 4, py + 4, Color(minf(1.0, c.r + gc.r * gc.a * 1.6), minf(1.0, c.g + gc.g * gc.a * 1.6), minf(1.0, c.b + gc.b * gc.a * 1.6)))
		sheet.blit_rect(dusk, Rect2i(Vector2i.ZERO, dusk.get_size()), Vector2i(x, y))
		x += dusk.get_width() + 6
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://docs/camp4_art_preview.png"))
	quit()
