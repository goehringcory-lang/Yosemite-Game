extends SceneTree
## Draws the landscape sprites and lays them out in docs/ahwahnee_land_preview.png:
## the wall (half size), the cascade in place at 2x, and the bridge at 3x.
##   godot --headless --path . -s res://tools/hubs/preview_ahwahnee_land.gd
const LandArt = preload("res://tools/hubs/ahwahnee_land_art.gd")


func _load(sprite_name: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(LandArt.DIR + sprite_name + ".png"))


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	LandArt.new().save_all()
	print("drew in %d ms" % (Time.get_ticks_msec() - t0))
	var bg := Color("5b7a45")
	var wall := _load("royal_arches_wall")

	# the whole wall, half size, on forest green
	var overview := Image.create_empty(LandArt.WALL_SIZE.x, LandArt.WALL_SIZE.y, false, Image.FORMAT_RGBA8)
	overview.fill(bg)
	overview.blend_rect(wall, Rect2i(Vector2i.ZERO, wall.get_size()), Vector2i.ZERO)
	# the cascade's frame 2 and a mist puff, in place
	var cascade := _load("cascade_2")
	overview.blend_rect(cascade, Rect2i(Vector2i.ZERO, cascade.get_size()), LandArt.CASCADE_POS)
	var mist := _load("mist_1")
	overview.blend_rect(mist, Rect2i(Vector2i.ZERO, mist.get_size()), LandArt.POOL_POS - Vector2i(32, 28))
	overview.resize(overview.get_width() / 2, overview.get_height() / 2, Image.INTERPOLATE_LANCZOS)

	# the left third and the arches at 2x, with frames 0..5 side by side
	var left := Image.create_empty(360, 224, false, Image.FORMAT_RGBA8)
	left.fill(bg)
	left.blend_rect(wall, Rect2i(0, 0, 360, 224), Vector2i.ZERO)
	left.blend_rect(cascade, Rect2i(Vector2i.ZERO, cascade.get_size()), LandArt.CASCADE_POS)
	left.blend_rect(mist, Rect2i(Vector2i.ZERO, mist.get_size()), LandArt.POOL_POS - Vector2i(32, 28))
	left.resize(720, 448, Image.INTERPOLATE_NEAREST)
	var frames := Image.create_empty(6 * 70, LandArt.CASCADE_SIZE.y, false, Image.FORMAT_RGBA8)
	frames.fill(Color("30364a"))
	for i in LandArt.CASCADE_FRAMES:
		var f := _load("cascade_%d" % i)
		frames.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i(i * 70, 0))
	frames.resize(frames.get_width() * 2, frames.get_height() * 2, Image.INTERPOLATE_NEAREST)

	var bridge := Image.create_empty(LandArt.BRIDGE_SIZE.x, LandArt.BRIDGE_SIZE.y + 16, false, Image.FORMAT_RGBA8)
	bridge.fill(Color("4f9aa0"))
	# green banks either side of the river
	bridge.fill_rect(Rect2i(0, 0, LandArt.BRIDGE_RIVER_X.x, bridge.get_height()), bg)
	bridge.fill_rect(Rect2i(LandArt.BRIDGE_RIVER_X.y, 0, LandArt.BRIDGE_SIZE.x - LandArt.BRIDGE_RIVER_X.y, bridge.get_height()), bg)
	var back := _load("stoneman_bridge_back")
	bridge.blend_rect(back, Rect2i(Vector2i.ZERO, back.get_size()), Vector2i.ZERO)
	var front := _load("stoneman_bridge_front")
	bridge.blend_rect(front, Rect2i(Vector2i.ZERO, front.get_size()), Vector2i(0, LandArt.BRIDGE_FRONT_Y))
	bridge.resize(bridge.get_width() * 3, bridge.get_height() * 3, Image.INTERPOLATE_NEAREST)

	var width := maxi(overview.get_width(), maxi(left.get_width() + frames.get_width(), bridge.get_width()))
	var height := overview.get_height() + 8 + maxi(left.get_height(), frames.get_height()) + 8 + bridge.get_height()
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("20242c"))
	var y := 0
	sheet.blend_rect(overview, Rect2i(Vector2i.ZERO, overview.get_size()), Vector2i(0, y))
	y += overview.get_height() + 8
	sheet.blend_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i(0, y))
	sheet.blend_rect(frames, Rect2i(Vector2i.ZERO, frames.get_size()), Vector2i(left.get_width() + 8, y))
	y += maxi(left.get_height(), frames.get_height()) + 8
	sheet.blend_rect(bridge, Rect2i(Vector2i.ZERO, bridge.get_size()), Vector2i(0, y))
	sheet.save_png(ProjectSettings.globalize_path("res://docs/ahwahnee_land_preview.png"))
	quit()
