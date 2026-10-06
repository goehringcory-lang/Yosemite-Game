extends Node
## Redraws assets/sprites/flora.png (the generated hubs' trees, shrubs,
## boulders and buildings), the info sign, trailhead and map kiosk, and a
## zoomed preview sheet of the flora:
##   godot --headless --path . res://tools/mapgen/paint_flora.tscn
## The preview goes to docs/generated_flora_preview.png.

const Art = preload("res://tools/mapgen/art.gd")


func _ready() -> void:
	var image := Art.new().paint_flora()
	image.save_png(ProjectSettings.globalize_path(Art.FLORA_PNG))
	var sheet := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("7c9a5c"))
	sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	sheet.save_png(ProjectSettings.globalize_path("res://docs/generated_flora_preview.png"))
	var art := Art.new()
	art._save_png(art.paint_info_sign(), "res://assets/sprites/info_sign.png")
	art._save_png(art.paint_trailhead(), "res://assets/sprites/trailhead.png")
	art._save_png(art.paint_map_kiosk(), "res://assets/sprites/map_kiosk.png")
	print("flora.png, signs and kiosk painted")
	get_tree().quit()
