class_name HuffResident
extends NPC
## A Curry Village employee living in HUFF (HuffCamp). They hang out around the
## HUFF tents by day and early evening, and slip out past 10 PM to throw the
## off-trail forest party (HuffPartySite) somewhere in the Valley woods.


## Out around HUFF from 7 AM until 10 PM, then off in the woods at the party.
func is_out() -> bool:
	if HuffParty.is_party_hours():
		return false
	var hour := GameClock.minutes / 60.0
	return hour >= OUT_FROM and hour < float(HuffParty.START_HOUR)


func interact(player: Player) -> void:
	var hour := GameClock.minutes / 60.0
	# After 6 PM (before 10 PM), occasionally tip the player off about tonight's
	# off-trail woods party without spoiling the exact clearing.
	if hour >= 18.0 and hour < float(HuffParty.START_HOUR) and character:
		var area := HuffParty.region_label(HuffParty.tonight_region())
		say_instead = PackedStringArray([
			"Shift's almost over. Past ten we're hauling the speakers and dance lights off-trail into the heavy forest and boulders around %s. Come find us if you're still awake." % area,
		])
	else:
		say_instead = PackedStringArray()
	await super.interact(player)
	say_instead = PackedStringArray()
