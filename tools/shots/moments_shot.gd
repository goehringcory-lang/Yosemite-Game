extends Node
## Saves a screenshot of each story moment (scripts/story/story_moments.gd)
## partway through, words typed out. Needs a window (not --headless).
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/moments_shot.tscn
##   SHOT_ONLY=harding_summit ...   (one moment)


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var only := OS.get_environment("SHOT_ONLY")
	for quest_id: String in StoryMoments.MOMENTS:
		if only != "" and quest_id != only:
			continue
		var vista := StoryVista.new()
		vista.setup(StoryMoments.MOMENTS[quest_id], StoryMoments.words_for(quest_id))
		add_child(vista)
		await get_tree().create_timer(5.0).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/moment_%s.png" % [dir, quest_id])
		vista.queue_free()
		await get_tree().process_frame
	get_tree().quit()
