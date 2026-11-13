class_name NewGame
## Puts every part of the game that lives in an autoload (the clock, the
## backpack, quests, gear, food, perks, friends, the press book, and the rest)
## back where a new game starts.


## What World resets for a new game. (The clock is left alone: a game that
## just started has it at the first morning already, and tests set it first.)
static func reset() -> void:
	Inventory.start_new_game()
	Park.start_new_game()
	Gear.start_new_game()
	Granary.start_new_game()
	Recipes.start_new_game()
	Cooking.start_new_game()
	QuestLog.start_new_game()
	Perks.start_new_game()
	Friendship.start_new_game()
	Herbarium.start_new_game()
	BoardRequests.start_new_game()
	Rescues.start_new_game()
	FieldLog.start_new_game()
	Discoveries.start_new_game()
	Festivals.start_new_game()
	Stewardship.start_new_game()
	Achievements.start_new_game()
	Camp.start_new_game()
	Photos.start_new_game()
	Crow.paper_day = ""


## Everything, the clock and the larder too: for the pause menu's Quit to
## title, so a game loaded afterwards (or a new one) never carries anything
## over from the one you left.
static func reset_all() -> void:
	GameClock.load_data({})
	GameClock.paused = false
	Larder.load_data({})
	PlayerLook.reset()
	reset()
	# As at launch, so a save from before the logbook, loaded next, has its
	# achievements rebuilt quietly (Achievements.settle) and not all announced.
	Achievements._fresh_state = false
