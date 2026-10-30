class_name BulletinBoard
extends InfoSign
## The Camp 4 bulletin board. Reading it shows its usual notes for partners
## and rides, and takes down any notes pinned up for you today
## (BoardRequests), and any thank-you notes from people you've rescued
## (Rescues).


func get_prompt() -> String:
	return "Read: %s" % title


func interact(_player: Player) -> void:
	var thanks := Rescues.read_thanks()
	get_tree().call_group("hud", "show_info", title, current_text() + "\n\n" + BoardRequests.read() + ("\n\n" + thanks if thanks != "" else ""))
