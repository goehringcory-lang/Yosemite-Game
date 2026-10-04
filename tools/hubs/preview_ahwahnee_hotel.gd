extends SceneTree
## Draws the Ahwahnee hotel sprites and lays them out on grass in
## docs/ahwahnee_hotel_preview.png (for looking at the art in one place).
##   godot --headless --path . -s res://tools/hubs/preview_ahwahnee_hotel.gd
const HotelArt = preload("res://tools/hubs/ahwahnee_hotel_art.gd")


func _init() -> void:
	HotelArt.new().save_all()
	var dir := HotelArt.DIR
	var load_sprite := func(sprite_name: String) -> Image:
		return Image.load_from_file(ProjectSettings.globalize_path(dir + sprite_name + ".png"))
	var sheet := Image.create_empty(464, 262, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("73aa52"))
	var hotel: Image = load_sprite.call("hotel")
	sheet.blend_rect(hotel, Rect2i(Vector2i.ZERO, hotel.get_size()), Vector2i(8, 4))
	# the glow layer, added on top of a darkened copy, on the right of the small pieces
	var x := 8
	for sprite_name in ["entrance_sign", "gate_post_a", "gate_post_b", "lamp_wrought", "lamp_wrought_glow"]:
		var im: Image = load_sprite.call(sprite_name)
		sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, 218))
		x += im.get_width() + 8
	# dusk view: hotel darkened with the glow blended over it
	var dusk := Image.create_empty(hotel.get_width(), hotel.get_height(), false, Image.FORMAT_RGBA8)
	dusk.fill(Color("2c3b4a"))
	dusk.blend_rect(hotel, Rect2i(Vector2i.ZERO, hotel.get_size()), Vector2i.ZERO)
	for yy in dusk.get_height():
		for xx in dusk.get_width():
			var p := dusk.get_pixel(xx, yy)
			if hotel.get_pixel(xx, yy).a > 0.0:
				dusk.set_pixel(xx, yy, Color(p.r * 0.5, p.g * 0.55, p.b * 0.75, 1.0))
	var glow: Image = load_sprite.call("hotel_glow")
	for yy in glow.get_height():
		for xx in glow.get_width():
			var g := glow.get_pixel(xx, yy)
			if g.a > 0.0:
				var p := dusk.get_pixel(xx, yy)
				dusk.set_pixel(xx, yy, Color(minf(p.r + g.r * g.a, 1.0), minf(p.g + g.g * g.a, 1.0), minf(p.b + g.b * g.a * 0.6, 1.0), 1.0))
	dusk.save_png(ProjectSettings.globalize_path("res://docs/ahwahnee_hotel_dusk.png"))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://docs/ahwahnee_hotel_preview.png"))
	quit()
