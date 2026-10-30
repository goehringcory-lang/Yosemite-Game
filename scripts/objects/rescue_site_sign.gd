class_name RescueSiteSign
extends InfoSign
## The sign at the Camp 4 rescue site. Under its usual text it says whether
## the radio has a call on it today, or one is underway (Rescues).


func current_text() -> String:
	var out := super.current_text()
	var call := Rescues.active_call()
	if not call.is_empty():
		out += "\n\nOn the board by the radio: %s. %s" % [call.title, Rescues.objective()]
	elif QuestLog.is_completed(Rescues.FIRST_QUEST) and Rescues.call_waiting():
		out += "\n\nThe radio is crackling. Talk to Jo."
	return out
