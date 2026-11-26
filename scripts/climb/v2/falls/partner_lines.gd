class_name PartnerLines
extends RefCounted
## What your belay partner says (thread 7, falls and the partner). The
## partner is a warm, dry Valley local who has seen everything and believes in
## you: never sarcastic about a fall, and never a quality readout. A grade
## line is what they saw plus why it matters, so it teaches the fix.
##
## Lines are picked with the falls random stream (only in mutators), so the
## same seed says the same things. "{piece}" is the piece's rack name,
## "{m}" a distance in metres.

const LINES := {
	# --- during the lead (safety first, then a crux, then flavour)
	&"runout": [
		"You're a long way out. Next piece when you can.",
		"That's a big one if you blow it. Find some gear.",
		"Runout! I'm watching, but get something in.",
	],
	&"deck": [
		"Careful, you're looking at the deck from there.",
		"If you come off there you're on the ground. Gear, please.",
	],
	&"ledge": [
		"There's a ledge under you. Don't fall here.",
		"Watch the ledge if you come off.",
	],
	&"back_clip": [
		"Hey, that draw's backwards. Rope's running over the gate.",
		"Your last clip's back-clipped. It could pop out if you fall.",
	],
	&"junk": [
		"...you happy with that one?",
		"Hm. You sure about that piece?",
	],
	&"crux": [
		"This is the bit. Breathe, feet first.",
		"I've got you. Trust your feet.",
		"Take your time. The rock'll wait.",
	],
	&"flavour": [
		"Swifts are out. Good sign.",
		"Rock's still cool in the shade. Sending temps.",
		"Ravens are eyeing our lunch again.",
		"You're climbing smooth today.",
		"Nice and steady. That's the way.",
	],
	# --- the catch
	&"caught": ["Got you!", "Gotcha.", "I've got you. Hang there."],
	&"caught_big": [
		"Whoa, that was a whipper! You okay?",
		"Big one! I got lifted right off my feet.",
		"That was a ride. Take a second.",
	],
	&"caught_belay": ["Caught you on the belay. That was close.", "Straight onto the anchor. I've got you."],
	&"short_rope": [
		"I ran back and took in! You're okay, you're okay.",
		"Pulled you tight just in time. Too close to the ground, that.",
	],
	&"ledge_hit": [
		"You hit the ledge. Anything hurt?",
		"Ouch, you clipped that ledge. Shake it off before you go again.",
	],
	&"ground": ["You're on the ground. Breathe. We'll try again.", "Decked. Sit a minute; you're okay."],
	&"swing": ["Big swing! Get your feet back on the rock.", "You pendulumed off the line. Work back over."],
	&"popped": [
		"Your {piece} popped! The next one held.",
		"The {piece} ripped, but you're caught.",
	],
	&"zipper": [
		"Two pieces zipped! That last one saved you.",
		"Your gear unzipped. Glad that one held.",
	],
	&"unclipped": [
		"The rope came out of that back-clipped draw.",
		"That backwards draw let the rope out. That's why we clip it right.",
	],
	# --- why you came off (the biggest cause)
	&"cause_pump": [
		"You were pumped out. Shake out sooner.",
		"Your forearms were done. Rest before the hard bit.",
	],
	&"cause_feet": [
		"Your feet cut. Get them on something before you reach.",
		"Nothing under your feet there. Look down first.",
	],
	&"cause_strain": [
		"That was a huge reach. Move your hips first.",
		"Way too stretched. Get your feet higher.",
	],
	&"cause_hold": ["That hold's tiny. Get your weight over it.", "Tough hold. Hips in, then pull."],
	&"cause_wet": ["Rock's greasy there. Chalk up and keep your weight on your feet.", "Wet streak. It's slick."],
	&"cause_sequence": [
		"Wrong hand for that one. Try the other sequence.",
		"Different hand first next time. It goes, just not like that.",
	],
	&"cause_dyno": ["Close! You were short on that throw. Lower hips, then go.", "Almost stuck it. Drive from your legs."],
	# --- back on, at the belay
	&"back_on": ["Climb when you're ready.", "Back on it. I've got you."],
	&"belay_clean": ["Clean pitch. Nice lead.", "Not a slip. Lovely."],
	&"belay_fell": ["Good fight up there.", "You stuck with it. That's the job."],
}

## Grade lines by grade word, then by the piece's kind (cam, nut, other).
## Each names what the partner saw and what it means.
const GRADE_LINES := {
	&"bomber": {
		&"cam": ["Your {piece}: bomber. All four lobes in the sweet spot.", "{piece}: perfect. Took me two seconds to clean."],
		&"nut": ["Your {piece}: bomber. Seated right in the constriction.", "{piece}: textbook. Didn't budge."],
		&"other": ["Your {piece}: bomber.", "{piece}: solid as the wall."],
	},
	&"good": {
		&"cam": ["{piece}: good. Lobes a bit wide, but it'd hold.", "Your {piece}: solid enough."],
		&"nut": ["{piece}: good. Could've used a firmer tug.", "Your {piece}: fine. A tug would've set it deeper."],
		&"other": ["{piece}: good."],
	},
	&"walked": {
		&"cam": ["{piece}: it walked a bit deeper. A sling stops that.", "Your {piece} walked in the crack. Extend it next time."],
		&"nut": ["{piece}: it shifted. The constriction was a hair lower.", "Your {piece} had slid up. Set it with a tug."],
		&"other": ["{piece}: it had moved a bit."],
	},
	&"tipped": {
		&"cam": ["{piece}: tipped out. The crack flares there, size up.", "Your {piece} was almost open. One size bigger."],
		&"nut": ["{piece}: barely in. Too small for that spot.", "Your {piece} sat on a crystal. Size up."],
		&"other": ["{piece}: marginal."],
	},
	&"marginal": {
		&"cam": ["{piece}: marginal. Two lobes were tipped. Size up.", "Your {piece}: I'm not sure that'd have held. Check the lobes."],
		&"nut": ["{piece}: marginal. No real constriction there.", "Your {piece}: it lifted when I touched it. Find the narrow bit."],
		&"other": ["{piece}: marginal."],
	},
	&"prayer": {
		&"cam": ["{piece}: that one was a prayer. The lobes were nearly flat.", "Your {piece}: it fell out when I touched it."],
		&"nut": ["{piece}: that nut was a prayer. Wrong size for the crack.", "Your {piece} fell out when I touched it."],
		&"other": ["{piece}: that one was a prayer."],
	},
	&"stuck": {
		&"cam": ["{piece}: over-cammed. Took me five minutes and a nut tool.", "Your {piece}: welded in. Size down next time."],
		&"nut": ["{piece}: welded in after that fall. Took a while with the nut tool.", "Your {piece}: really stuck. I got it, eventually."],
		&"other": ["{piece}: stuck. Got it out in the end."],
	},
	&"popped": {
		&"cam": ["{piece}: it ripped in your fall. Lobes weren't biting.", "Your {piece} pulled. Rode down the rope to you."],
		&"nut": ["{piece}: it popped. The rope lifted it out.", "Your {piece} pulled out in the fall."],
		&"other": ["{piece}: it popped."],
	},
	&"held": {
		&"cam": ["{piece}: held your fall. That's a good piece.", "Your {piece} caught you and it's still sweet."],
		&"nut": ["{piece}: caught your fall. Good nut.", "Your {piece} held the whipper."],
		&"other": ["{piece}: it held your fall."],
	},
}


## A line for [param key] ({piece}/{m} filled from [param fill]), or "".
static func pick(key: StringName, rng: RandomNumberGenerator, fill := {}) -> String:
	var options: Array = LINES.get(key, [])
	if options.is_empty():
		return ""
	return _fill(options[rng.randi() % options.size()], fill)


## A grade line for [param grade] and piece kind [param kind].
static func grade_line(grade: StringName, kind: StringName, rng: RandomNumberGenerator, fill := {}) -> String:
	var by_kind: Dictionary = GRADE_LINES.get(grade, GRADE_LINES[&"good"])
	var group: StringName = kind if by_kind.has(kind) else &"other"
	var options: Array = by_kind[group]
	return _fill(options[rng.randi() % options.size()], fill)


static func _fill(line: String, fill: Dictionary) -> String:
	for key: String in fill:
		line = line.replace("{%s}" % key, str(fill[key]))
	if line.length() > 0:
		line = line[0].to_upper() + line.substr(1)
	return line
