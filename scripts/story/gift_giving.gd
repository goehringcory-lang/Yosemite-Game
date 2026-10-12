class_name GiftGiving
extends RefCounted
## Giving someone a gift (the gift button, G or LB, while facing them): pick
## something from your pack, hear their thanks, and watch a heart rise.
## NPC and Vendor call offer().


## True if [param character_id] can take a gift now and you have something.
static func possible(character_id: String) -> bool:
	return character_id != "" and Friendship.can_gift(character_id) and not Friendship.giftable_items(character_id).is_empty()


## Runs the gift choice with [param player] for [param character_id], who is
## called [param speaker] and stands at [param anchor].
static func offer(player: Player, character_id: String, speaker: String, anchor: Node2D) -> void:
	player.can_act = false
	var box := DialogueBox.open(player)
	if not Friendship.can_gift(character_id):
		var days := Friendship.days_until_gift(character_id)
		await box.say([{"speaker": "", "text": "You've given %s something this week. Try again in %d day%s." % [speaker, days, "" if days == 1 else "s"]}])
	else:
		var items := Friendship.giftable_items(character_id)
		if items.is_empty():
			await box.say([{"speaker": "", "text": "You have no food or forage to give."}])
		else:
			var names := []
			var icons := []
			for id: String in items:
				var item := ItemDB.get_item(id)
				names.append("%s (%d)" % [item.display_name, Inventory.count(id)])
				icons.append(item.icon)
			names.append("Not now")
			icons.append(null)
			# their face beside the choices, as they wait to see what you have
			var pick := await box.choose("What will you give %s?" % speaker.split(" ")[0], names, speaker, icons)
			if pick >= 0 and pick < items.size():
				var before := Friendship.hearts(character_id)
				var thanks := Friendship.give(character_id, items[pick])
				if thanks != "":
					Hearts.pop(anchor)
					Sound.play("heart", 0.0, 0.0)
					var lines := [{"speaker": speaker, "text": thanks}]
					if Friendship.hearts(character_id) > before:
						lines.append({"speaker": "", "text": "%s likes you a little more (%d of %d hearts)." % [speaker, Friendship.hearts(character_id), Friendship.MAX_HEARTS]})
					await box.say(lines)
	box.close()
	player.can_act = true
