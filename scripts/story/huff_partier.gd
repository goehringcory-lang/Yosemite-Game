class_name HuffPartier
extends NPC
## A HUFF employee dancing at the late-night forest party (HuffPartySite).
## Dances to the 120 BPM speaker beat, and when you talk to them they offer
## cold beer, weed (joint with rising smoke + TripEffect.haze), and LSD
## (little piece of paper with TripEffect.play, once a day) — working just
## like Crow up Tenaya Creek.

## Beat phase offset so the dancers aren't in mechanical lockstep.
var dance_phase := 0.0
## Center of the clearing, so the dancer faces back toward the lights/speakers.
var party_center := Vector2.ZERO
var _beat_time := 0.0


## Partygoers stay out all night until the party wraps at curfew.
func is_out() -> bool:
	return true


func _physics_process(delta: float) -> void:
	# Stay planted on the dance floor instead of wandering into the dark trees.
	velocity = Vector2.ZERO
	_beat_time += delta
	if _talking or _sprite == null:
		_idle_life(delta)
		if _sprite:
			_sprite.position.y = 0.0
		return
	var phase := _beat_time * HuffParty.BEAT_HZ + dance_phase
	var step := int(floorf(phase)) % 4
	var bounce := absf(sin(phase * PI))
	_sprite.position.y = -roundf(bounce * 4.0)
	var col: int = CharacterSheet.Col.STAND
	match step:
		0:
			col = CharacterSheet.Col.ARMS_UP
		1:
			col = CharacterSheet.Col.STEP_A
		2:
			col = CharacterSheet.Col.ARMS_UP if int(floorf(phase / 4.0)) % 2 == 0 else CharacterSheet.Col.STAND
		3:
			col = CharacterSheet.Col.STEP_B
	if CharacterSheet.blinking(_beat_time, hash(name)):
		col = CharacterSheet.Col.BLINK
	# Subtle turns toward the lights and crowd every couple of bars.
	var bar := int(floorf(phase / 4.0))
	if bar % 3 == 0:
		_face(party_center - position)
	elif bar % 3 == 1:
		facing = Vector2i.DOWN
	else:
		facing = Vector2i.LEFT if int(dance_phase * 10.0) % 2 == 0 else Vector2i.RIGHT
	_sprite.frame = CharacterSheet.frame(_sprite.texture, facing, col)
	queue_redraw()


func interact(player: Player) -> void:
	_talking = true
	velocity = Vector2.ZERO
	if _sprite:
		_sprite.position.y = 0.0
	_face(player.global_position - global_position)
	_update_frame(false)
	_hop()
	player.can_act = false
	if not HuffParty.has_met():
		await _first_meeting(player)
	await _party_menu(player)
	player.can_act = true
	_talking = false


func _speaker() -> String:
	return character.display_name if character else "Huff crew"


func _first_meeting(player: Player) -> void:
	var box := DialogueBox.open(player)
	await box.say(_lines([
		["Whoa! Hey — somebody actually tracked the bass out into the boulders!", "surprised"],
		["Relax, you're cool, right? Not a ranger? Good. Welcome to the Huff after-hours.", "happy"],
		["Half of Curry Village thinks we're asleep in our tents. After ten we haul the speakers and lights off-trail into the heavy woods somewhere new."],
		["Cooler's packed with cold beers, joint's going round, and Devon brought little pieces of paper for your tongue.", "happy"],
	]))
	QuestLog.heard_beats.append(HuffParty.MET)
	box.close()


func _party_menu(player: Player) -> void:
	var box := DialogueBox.open(player)
	var pick := await box.choose(_greeting(), [
		"Grab a cold beer",
		"Hit the joint (weed)",
		"Take a tab (LSD)",
		"Just dance a while",
	], _speaker())
	match pick:
		0:
			box.close()
			await _beer(player)
		1:
			box.close()
			await _joint(player, false)
		2:
			if HuffParty.paper_day == HuffParty.today_key():
				await box.say(_lines([["One tab a night, friend. The dance lights are already doing half the work.", "happy"]]))
				box.close()
			else:
				var take := await box.choose("Take the little piece of paper?", ["Put it on your tongue", "Maybe another time"], _speaker())
				if take != 0:
					await box.say(_lines([["No pressure. Music's good either way.", "happy"]]))
					box.close()
					return
				await box.say(_lines([["Right on. Watch the lights bounce off the pines. Give it a second..."]]))
				box.close()
				await _trip(player)
				await _joint(player, true)
		_:
			await box.say(_lines([[_dance_line(), "happy"]]))
			box.close()


func _greeting() -> String:
	match character.id if character else "":
		"huff_rico":
			return "Bass sounds crazy bouncing off these granite boulders, right? What can I get you?"
		"huff_macy":
			return "Glad you found us out here in the trees! What'll it be?"
		"huff_devon":
			return "Cooler's ice cold and the stash is open. What are you having?"
		"huff_tessa":
			return "Wait till you see these dance lights through the pines! Want anything?"
		_:
			return "Welcome to the woods! What'll it be?"


func _dance_line() -> String:
	var lines := [
		"Move your feet! Dish shift starts at six, might as well earn the hangover.",
		"Every night a different patch of woods. Keeps the rangers guessing.",
		"Look up between the pine tops — stars and dance lights, unbeatable combo.",
		"Rico's speakers have survived three Yosemite summers and one curious bear.",
	]
	return lines[_rng.randi() % lines.size()]


## Cracking a cold King Cobra from the cooler: cheers, a light tipsy buzz
## (TripEffect.buzz), and one spare cold can for your pack per night.
func _beer(player: Player) -> void:
	var box := DialogueBox.open(player)
	await box.say(_lines([["Ice-cold King Cobra straight out of the cooler. Still got snowmelt on the can.", "happy"]]))
	var pick := await box.choose("Crack a cold beer?", ["Crack it open", "Pass"], _speaker())
	if pick != 0:
		await box.say(_lines([["More for the dish crew. Cooler stays open all night.", "happy"]]))
		box.close()
		return
	box.close()
	Sound.play("climb_eat")
	Emote.pop(self, "happy")
	Emote.pop(player, "happy")
	TripEffect.buzz(self)
	var first_tonight := HuffParty.beer_day != HuffParty.today_key()
	if first_tonight:
		HuffParty.beer_day = HuffParty.today_key()
		Inventory.add("king_cobra", 1)
		Sound.play("item_get")
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	if first_tonight:
		await _box_say(player, [
			["*psssht* ...Cheers to the Valley!", "happy"],
			["Here — toss an extra cold King Cobra in your pack for the trail. Don't let Jennie see it.", "happy"],
		])
	else:
		await _box_say(player, [
			["*psssht* ...Cold as Tenaya Creek! Pace yourself on the boulders going back.", "happy"],
		])


## Passing a joint: smoke from both of you, a cough, and a haze that fades —
## just like Crow up Tenaya Creek.
func _joint(player: Player, after_trip: bool) -> void:
	var box := DialogueBox.open(player)
	var offer := "Here. Spark this with us. Takes the edge off the landing." if after_trip else "Say no more. Just rolled it behind the speakers."
	await box.say(_lines([[offer, "happy"]]))
	var pick := await box.choose("Take the joint?", ["Take a hit", "Pass"], _speaker())
	if pick != 0:
		await box.say(_lines([["All good. More for the pine spirits.", "happy"]]))
		box.close()
		return
	box.close()
	_puff(self, Vector2(6, -30))
	_puff(player, Vector2(0, -30))
	TripEffect.haze(self)
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	await _box_say(player, [
		["*cough* ...*cough cough*", "surprised", "You"],
		["Easy. Thin mountain air hits twice as hard at four thousand feet.", "happy"],
		["Stay as long as the battery holds. Follow the bass whenever you hear us out here."],
	])


## Ten seconds somewhere else with the dance lights pulsing underneath, then
## back in the forest clearing — just like Crow's paper.
func _trip(player: Player) -> void:
	HuffParty.paper_day = HuffParty.today_key()
	Sound.play("item_get")
	await TripEffect.play(self)
	if not is_inside_tree():
		return
	await _box_say(player, [["...and you're back! Whoa, those dance lights through the pines hit different, huh?", "happy"]])


## A few seconds of smoke over [param who]'s head (same pattern as Crow).
func _puff(who: Node2D, at: Vector2) -> void:
	var smoke := AmbientFx.new()
	smoke.effect = "smoke"
	smoke.area = Vector2(2, 1)
	smoke.position = at
	smoke.z_index = 6
	who.add_child(smoke)
	var tree := get_tree()
	tree.create_timer(6.0).timeout.connect(func() -> void:
		if is_instance_valid(smoke):
			smoke.emitting = false
			tree.create_timer(4.5).timeout.connect(smoke.queue_free))


func _lines(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var default_speaker := _speaker()
	for r: Array in raw:
		var line := {"speaker": r[2] if r.size() > 2 else default_speaker, "text": r[0]}
		if r.size() > 1:
			line.mood = r[1]
		result.append(line)
	return result


func _box_say(player: Player, raw: Array) -> void:
	var box := DialogueBox.open(player)
	await box.say(_lines(raw))
	box.close()
