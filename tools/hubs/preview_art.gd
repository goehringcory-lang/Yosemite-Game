extends SceneTree
## Draws Curry Village's sprites and lays them out on grass in
## docs/curry_art_preview.png (for looking at the art in one place).
##   godot --headless --path . -s res://tools/hubs/preview_art.gd
const CurryArt = preload("res://tools/hubs/curry_art.gd")


func _init() -> void:
	CurryArt.new().save_all()
	var dir := CurryArt.DIR
	var rows := [
		["registration", "store", "mountain_shop"],
		["pavilion", "pizza_deck", "amphitheater"],
		["tent_cabin_0", "tent_cabin_1", "tent_cabin_2", "tent_cabin_3", "tent_cabin_4", "tent_cabin_5", "cabin_a", "cabin_b", "entrance_sign"],
		["car_0", "car_1", "car_2", "car_3", "car_4", "car_5", "car_7", "car_9", "apple_tree", "firefall_board", "gear_rack", "flagpole"],
		["lamp_post", "bike_rack", "woodpile", "clothesline", "bench", "planter", "patio_table", "cooler", "fountain", "stump", "chair_0", "chair_1", "chair_2", "chair_3", "trail_post_apron", "trail_post_closed"],
		["pool", "ice_rink", "fence_h", "fence_v", "rope_fence"],
	]
	var sheet := Image.create_empty(600, 480, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("73aa52"))
	var y := 4
	for row: Array in rows:
		var x := 4
		var row_h := 0
		for sprite_name: String in row:
			var im := Image.load_from_file(ProjectSettings.globalize_path(dir + sprite_name + ".png"))
			sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))
			x += im.get_width() + 6
			row_h = maxi(row_h, im.get_height())
		y += row_h + 6
	sheet.crop(600, mini(y, 480))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://docs/curry_art_preview.png"))
	quit()
