class_name HuffSign
extends InfoSign
## The wooden post at the entrance to HUFF, Curry Village's seasonal employee
## tent community. After 10 PM it carries a pinned scrap hinting which Valley
## woods and boulders the crew hauled the speakers out to tonight.


func extra_active() -> bool:
	return HuffParty.is_party_hours()


func current_text() -> String:
	if extra_active():
		var area := HuffParty.region_label(HuffParty.tonight_region())
		var note := "Past ten. Half the tents are empty — somebody pinned a scrap to the post: \"Speakers and lights are off-trail in the heavy woods and boulders around %s tonight. Follow the bass.\"" % area
		return "%s\n\n%s" % [text, note]
	return text
