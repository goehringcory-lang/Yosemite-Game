extends Node
## Saves screenshots of the Camp 4 slackline screen at its main moments: the
## line picker, stepping on, walking with a buck coming, a trick, a fall, the
## results card with a medal, and the long line in a gust. Needs a window
## (not --headless). Environment:
##   SHOT_HOURS   comma-separated game hours to shoot at (default 12)
##   SHOT_ONLY    comma-separated moments to shoot (default all): select,
##                ready, walk, trick, fall, result, gust
##   SHOT_DIR     folder for the PNGs (default user://)
## Run: SHOT_HOURS=12,19,23 godot --path . res://tools/shots/slackline_shot.tscn

const DT := 1.0 / 60.0


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	SaveManager.save_path = "user://slackline_shot_save.json"
	Inventory.start_new_game()
	QuestLog.start_new_game()
	Perks.start_new_game()
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1}
	GameClock.paused = true
	var only := _env("SHOT_ONLY", "select,ready,walk,trick,fall,result,gust").split(",")
	for hour in _env("SHOT_HOURS", "12").split(","):
		GameClock.minutes = int(hour) * 60
		for moment in only:
			await _shoot(moment, hour)
	get_tree().quit()


func _shoot(moment: String, hour: String) -> void:
	if moment == "gust" or moment == "select":
		QuestLog.unlocks.append(SlacklineMinigame.WON)
		Perks.record("slackline_medal_short", 3)
		Perks.record("slackline_best_short", 5240)
		Perks.record("slackline_medal_camp4", 2)
		Perks.record("slackline_best_camp4", 4410)
	var game: SlacklineMinigame = load("res://scripts/slackline/slackline_minigame.gd").new()
	game.setup(5)
	add_child(game)
	await get_tree().process_frame
	match moment:
		"select":
			game._chosen = 1
			await _frames(30)
		"ready":
			game.begin("camp4")
			await _frames(30)
		"walk", "trick", "fall":
			game.begin("camp4")
			game.go()
			_walk_to(game, 0.42)
			if moment == "walk":
				# freeze just as a buck is felt coming
				game.state._next_buck = SlacklineState.BUCK_WARN * 0.4
				game.state._buck_side = 1.0
				game.state.lean = 0.3
				game._push = -1.0
			elif moment == "trick":
				game.state.lean = 0.0
				game.state.lean_speed = 0.0
				game.state._trick_rest = 0.0
				game.state._trick_from = 0.0
				game.state.start_trick()
				game.state.trick_age = 0.5
				game._popup("Drop knee! +450", UI_GOLD, game.feet() + Vector2(0, -60), true)
			else:
				game.state.lean = 1.0
				game.state.fell_to = 1
				game.state.status = SlacklineState.Status.FELL
				game._on_event({"kind": "fell", "side": 1})
				game._fall_t = 0.55
			game.set_process(false)
			game._canvas.queue_redraw()
			await _frames(4)
		"result":
			game.begin("camp4")
			game.go()
			_walk_to(game, 1.0, true)
			game._phase_age = 4.0
			await _frames(4)
		"gust":
			game.begin("long")
			game.go()
			_walk_to(game, 0.55)
			game.state._gust_side = -1.0
			game.state._gust_left = 1.0
			for i in 60:
				game._ambient(DT)
				game._fx.update(DT)
			game.set_process(false)
			game._canvas.queue_redraw()
			await _frames(4)
	_save(_env("SHOT_DIR", "user://"), "slackline_%s_%s" % [moment, hour])
	game.queue_free()
	QuestLog.start_new_game()
	Perks.start_new_game()
	Inventory.start_new_game()
	await get_tree().process_frame


const UI_GOLD := Color("d8a63b")


## Walks [param game]'s line with a steady hand to [param to] (0..1), doing
## tricks along the way if [param tricks], and lets the screen catch up.
func _walk_to(game: SlacklineMinigame, to: float, tricks := false) -> void:
	var s := game.state
	for i in int(200.0 / DT):
		if tricks and s.can_trick():
			s.start_trick()
		s.step(DT, clampf(-(s.lean * 2.5 + s.lean_speed * 0.8), -1.0, 1.0))
		for e in s.take_events():
			game._on_event(e)
		if s.progress >= to or s.status != SlacklineState.Status.WALKING:
			break
	game._shown_score = s.score
	game._ghost = s.lean


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(dir: String, tag: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [dir, tag])
