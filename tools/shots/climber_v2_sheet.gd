extends Node2D
## A sheet of the v2 climber (scripts/climb/v2/art) for judging the art: every
## body position in ClimberPoses, or one position in many looks. Needs a
## window (not --headless). Environment:
##   SHEET      poses (default) | looks
##   SHOT_OUT   the PNG (default user://climber_v2_sheet.png)
## Run: SHEET=looks godot --path . res://tools/shots/climber_v2_sheet.tscn

const COLS := 7
const CELL := Vector2(960.0 / COLS, 270)


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color("7d786c")
	back.size = Vector2(960, 540)
	add_child(back)
	var sheet := OS.get_environment("SHEET") if OS.get_environment("SHEET") != "" else "poses"
	var names: Array = ClimberPoses.names()
	var count := mini(names.size(), COLS * 2)
	var looks := sheet == "looks"
	if looks:
		count = COLS * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in count:
		var pose_name: String = "flag" if looks and i % 2 == 1 else ("rest on jugs" if looks else names[i])
		var session := ClimberPoses.session_for([pose_name])
		session.pose = ClimberPoses.pose(pose_name, Vector2(1.5, 2.0))
		session.effort.pump = ClimberPoses.pump(pose_name)
		if pose_name == "clipping":
			session.rope.slack_m = 1.4
		var art: ClimberArt = load("res://scripts/climb/v2/art/climber.gd").new()
		if looks:
			if i > 0:
				PlayerLook.randomize_look(rng)
			art.painter.style = ClimberStyle.make()
			art.style_locked = true
		art.bind(session)
		var col := i % COLS
		var row := i / COLS
		var hip_local := ClimberView.px(session.pose.hip)
		art.position = Vector2(CELL.x * (col + 0.5), CELL.y * row + 150) - hip_local
		add_child(art)
		var label := Label.new()
		label.text = PlayerLook.chosen_name("top_style") + ", " + PlayerLook.chosen_name("hat") if looks else pose_name
		label.position = Vector2(CELL.x * col + 4, CELL.y * row + 250)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("f2e6c8"))
		add_child(label)
	PlayerLook.reset()
	for i in 50:
		await get_tree().process_frame
	var path := OS.get_environment("SHOT_OUT") if OS.get_environment("SHOT_OUT") != "" else "user://climber_v2_sheet.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()
