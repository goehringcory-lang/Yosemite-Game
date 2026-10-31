extends SceneTree
## Draws the Camp 4 rescue site's sprites (sar_site_art.gd) and lays them out
## on camp dirt in docs/sar_site_preview.png, with a dusk strip showing the
## cabins' and the cache's lamplight.
##   godot --headless --path . -s res://tools/hubs/preview_sar_site_art.gd
## (then `python3 tools/art32/upgrade.py --fresh` on the camp4_sar_* files)
const SarArt = preload("res://tools/hubs/sar_site_art.gd")


func _init() -> void:
	SarArt.new().save_sar()
	var load_sprite := func(sprite_name: String) -> Image:
		return Image.load_from_file(ProjectSettings.globalize_path(SarArt.OUT + sprite_name + ".png"))
	var sheet := Image.create_empty(380, 130, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("a4824e"))
	var x := 6
	for sprite_name: String in ["camp4_sar_cabin_0", "camp4_sar_cabin_1", "camp4_sar_cabin_2", "camp4_sar_cache", "camp4_sar_litter", "camp4_sar_shirts", "camp4_sar_sign"]:
		var im: Image = load_sprite.call(sprite_name)
		sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, 56 - im.get_height()))
		x += im.get_width() + 4
	# Dusk: the cabins and the cache darkened, with their glow added.
	x = 6
	for sprite_name: String in ["camp4_sar_cabin_0", "camp4_sar_cabin_1", "camp4_sar_cache"]:
		var im: Image = load_sprite.call(sprite_name)
		var dusk := Image.create_empty(im.get_width() + 8, im.get_height() + 8, false, Image.FORMAT_RGBA8)
		dusk.fill(Color("2a2a40"))
		dusk.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(4, 4))
		for py in dusk.get_height():
			for px in dusk.get_width():
				var c := dusk.get_pixel(px, py)
				dusk.set_pixel(px, py, Color(c.r * 0.45, c.g * 0.45, c.b * 0.6))
		var g: Image = load_sprite.call(sprite_name + "_glow")
		for py in g.get_height():
			for px in g.get_width():
				var gc := g.get_pixel(px, py)
				if gc.a > 0.0:
					var c := dusk.get_pixel(px + 4, py + 4)
					dusk.set_pixel(px + 4, py + 4, Color(minf(1.0, c.r + gc.r * gc.a * 1.6), minf(1.0, c.g + gc.g * gc.a * 1.6), minf(1.0, c.b + gc.b * gc.a * 1.6)))
		sheet.blit_rect(dusk, Rect2i(Vector2i.ZERO, dusk.get_size()), Vector2i(x, 64))
		x += dusk.get_width() + 6
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://docs/sar_site_preview.png"))
	quit()
