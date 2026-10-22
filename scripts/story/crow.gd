class_name Crow
extends NPC
## Crow, who camps under the overhang up Tenaya Creek (Crow's Camp, a secret
## reached from the cairn at Mirror Lake). Not in the Register and gives no
## quests: the first time you find him he hands you a little piece of paper
## (TripEffect.play), and when you come back down he sparks a joint with you
## (smoke, and TripEffect.haze). After that he's happy to do either again:
## the paper once a day, the joint whenever.
##
## Whether you've met is kept with the heard story beats (QuestLog.heard_beats),
## so it's saved with the game.

const MET := "crow:met"
const SPEAKER := "Crow"

## The day ("year-season-day") Crow last gave you a paper.
static var paper_day := ""


## Crow never goes home: this is home.
func is_out() -> bool:
	return true


static func has_met() -> bool:
	return MET in QuestLog.heard_beats


func interact(player: Player) -> void:
	_talking = true
	velocity = Vector2.ZERO
	_face(player.global_position - global_position)
	_update_frame(false)
	_hop()
	player.can_act = false
	if has_met():
		await _hang_out(player)
	else:
		await _first_meeting(player)
	player.can_act = true
	_talking = false


func _first_meeting(player: Player) -> void:
	var box := DialogueBox.open(player)
	await box.say(_lines([
		["Whoa. Easy there. Nobody comes up here.", "surprised"],
		["You followed the cairn, huh? Then I guess you're supposed to be here. I'm Crow."],
		["Been camped under this rock a while. Bear box, a fire, the creek talking all night. What else do you need?", "happy"],
		["Here. Got something for you. A little piece of paper. Goes on your tongue. Tenaya Creek has a lot to say if you let it."],
	]))
	QuestLog.heard_beats.append(MET)
	var pick := await box.choose("Take the little piece of paper?", ["Put it on your tongue", "Maybe another time"], SPEAKER)
	if pick != 0:
		await box.say(_lines([["No pressure. It'll be here. So will I.", "happy"]]))
		box.close()
		return
	box.close()
	await _trip(player)
	await _joint(player, true)


## Later visits: another paper (once a day), a joint, or just sitting.
func _hang_out(player: Player) -> void:
	var box := DialogueBox.open(player)
	var pick := await box.choose(_greeting(), ["Got any more of that paper?", "Spark one up", "Just sitting a while"], SPEAKER)
	match pick:
		0:
			if paper_day == _today():
				await box.say(_lines([["One a day, friend. The creek needs time to think up new stuff.", "happy"]]))
				box.close()
			else:
				await box.say(_lines([["Right on. Sit by the fire. Give it a minute..."]]))
				box.close()
				await _trip(player)
		1:
			box.close()
			await _joint(player, false)
		_:
			await box.say(_lines([[_idle_line()]]))
			box.close()


static func _today() -> String:
	return "%d-%d-%d" % [GameClock.year, GameClock.season, GameClock.day]


func _greeting() -> String:
	var hour := GameClock.minutes / 60.0
	if hour >= 21.0 or hour < 5.0:
		return "Hey, night owl. Fire's still going."
	if hour < 10.0:
		return "Morning. Coffee's cowboy style: chew the grounds."
	return "Look who found their way back up the boulders."


func _idle_line() -> String:
	if character and not character.idle_lines.is_empty():
		return character.idle_lines[_rng.randi() % character.idle_lines.size()]
	return "..."


## Ten seconds somewhere else, then back by the fire.
func _trip(player: Player) -> void:
	paper_day = _today()
	Sound.play("item_get")
	await TripEffect.play(self)
	if not is_inside_tree():
		return
	await box_say(player, [["...and you're back. Welcome back, space cadet.", "happy"]])


## Passing a joint: smoke from both of you, a cough, and a haze that fades.
func _joint(player: Player, after_trip: bool) -> void:
	var box := DialogueBox.open(player)
	var offer := "Here. Spark this with me. It takes the edge off the landing." if after_trip else "Say no more."
	await box.say(_lines([[offer, "happy"]]))
	var pick := await box.choose("Take the joint?", ["Take a hit", "Pass"], SPEAKER)
	if pick != 0:
		await box.say(_lines([["More for the creek spirits.", "happy"]]))
		box.close()
		return
	box.close()
	_puff(self, Vector2(6, -30))
	_puff(player, Vector2(0, -30))
	TripEffect.haze(self)
	await get_tree().create_timer(1.6).timeout
	await box_say(player, [
		["*cough* ...*cough cough*", "surprised", "You"],
		["Easy. Little puffs. It's not a race.", "happy"],
		["Half Dome's been watching us this whole time, you know. Doesn't judge. Just watches."],
		["Come back whenever. Follow the stones."],
	])


## A few seconds of smoke over [param who]'s head.
func _puff(who: Node2D, at: Vector2) -> void:
	var smoke := AmbientFx.new()
	smoke.effect = "smoke"
	smoke.area = Vector2(2, 1)
	smoke.position = at
	smoke.z_index = 6
	who.add_child(smoke)
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
		if is_instance_valid(smoke):
			smoke.emitting = false
			get_tree().create_timer(4.5).timeout.connect(smoke.queue_free))


## [[text, mood?, speaker?], ...] as dialogue lines (Crow speaks by default).
func _lines(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r: Array in raw:
		var line := {"speaker": r[2] if r.size() > 2 else SPEAKER, "text": r[0]}
		if r.size() > 1:
			line.mood = r[1]
		result.append(line)
	return result


func box_say(player: Player, raw: Array) -> void:
	var box := DialogueBox.open(player)
	await box.say(_lines(raw))
	box.close()
