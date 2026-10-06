extends Node
## Times ClimbLandscape.build for every route profile. Prints ms.
func _ready() -> void:
	var pal := ClimbSky.palette(12.0)
	var worst := 0.0
	for id: String in ClimbProfiles.PROFILES.keys():
		var t := Time.get_ticks_usec()
		ClimbLandscape.build(ClimbProfiles.PROFILES[id], pal, hash(id))
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		worst = maxf(worst, ms)
		print("%s %.1f ms" % [id, ms])
	print("worst %.1f" % worst)
	get_tree().quit()
