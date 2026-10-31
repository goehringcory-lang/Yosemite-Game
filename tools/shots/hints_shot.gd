extends Node
## Saves a sheet of every button the hints draw, with the keyboard's keys
## and then the pad's, on the menu panel's paper. Needs a window:
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/hints_shot.tscn

const HINTS := [
	"[Up/Down] Choose   [E] OK   [Esc] Cancel",
	"[Arrows] Choose   [Tab] Next tab   [B/Esc] Close",
	"[Left/Right] Change   [M] Close   [J] Journal",
	"[D-pad] Choose   [A] OK   [B] Cancel",
	"[Stick] Scroll   [LB/RB] Next tab   [Y/B] Close",
	"[D-pad L/R] Change   [X] Use   [Back] Close",
]


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	UiScale.layer(layer)
	var paper := ColorRect.new()
	paper.color = Color(37 / 255.0, 27 / 255.0, 20 / 255.0)
	paper.size = UiScale.SCREEN
	layer.add_child(paper)
	for i in HINTS.size():
		var hint := ButtonHints.new()
		hint.text = HINTS[i]
		hint.position = Vector2(12, 12 + i * 20)
		hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
		Settings.prompts = Settings.Prompts.GAMEPAD if i >= 3 else Settings.Prompts.KEYBOARD
		layer.add_child(hint)
		await get_tree().process_frame
		await get_tree().process_frame
	Settings.prompts = Settings.Prompts.AUTO
	for i in 4:
		await get_tree().process_frame
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	get_viewport().get_texture().get_image().save_png("%s/hints.png" % dir)
	get_tree().quit()
