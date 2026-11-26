extends Node
## Screenshots of climbing v2's body signs (thread 4): the climber fresh,
## pumped with the next move's ghost shaking red, shaking out (chalk), and
## eating. Each is saved full size and as a close-up around the climber.
## Needs a window (not --headless):
##   xvfb-run -a godot --path . res://tools/shots/climb_v2_effort_shot.tscn
## SHOT_DIR (default user://) is where the PNGs go.

const Base := preload("res://tests/climb_v2_test.gd")


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	Inventory.add("trail_mix", 1)
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(Base.fixture_route(2), 7, V2Modifiers.new(), Base.fixture_rack())
	add_child(screen)
	await get_tree().process_frame
	var bot := ClimbV2TestBot.new(screen.director)
	bot.rest_at = 2.0
	bot.place_from = -1.0
	while screen.session.pose.hip.y < 4.0 and bot.steps < 60:
		bot.step()
	var s := screen.session
	await _shot(screen, "effort_1_fresh")
	s.sys.effort.apply(V2Cost.make(0.88 - s.effort.pump))
	screen.director.current.refresh()
	screen.director.handle_verb(&"aim_up", true)
	await _shot(screen, "effort_2_pumped_ghost")
	s.sys.effort.rest(&"stance")
	await _shot(screen, "effort_3_shake_out", 20)
	s.pose.tags.append("hang")
	s.effort.gas = 0.3
	s.sys.effort.eat("trail_mix")
	await _shot(screen, "effort_4_eat", 25)
	get_tree().quit()


func _shot(screen: ClimbScreenV2, name: String, frames := 60) -> void:
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var dir := _env("SHOT_DIR", "user://")
	img.save_png(dir.path_join(name + ".png"))
	var k := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var at := screen.climber.get_global_transform() * ClimberView.px(screen.session.pose.hip) * k
	var r := Rect2i(Vector2i(at) - Vector2i(Vector2(110, 100) * k), Vector2i(Vector2(220, 165) * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(dir.path_join(name + "_closeup.png"))
	print("saved ", name)
