class_name ClimbProfiles
extends RefCounted
## What each real route looks and plays like on the climbing screen: where it
## is, what you see from it, what the rock is, and what every pitch asks of
## you. The rules read the pitch specs (climb_state.gd); the painters read the
## rest (climb_rock.gd, climb_landscape.gd, climb_props.gd, climb_sprites.gd).
##
## Facts are kept to what is well documented. Anything a guidebook disagrees
## about is left out of the blurbs; pitch names are the route's real features
## where I know them, and plain descriptions where I don't.
##
## Pitch spec keys (all optional):
##   name        shown when the pitch starts
##   style       slab | crack | flake | chimney | roof | dike | knobs | snow | ice
##   rows        moves on this pitch (default RouteData.moves_per_pitch)
##   cols        columns that have holds (default all five)
##   cracks      chance a hold is a crack (default by style)
##   bolts       "line" (a bolt every bolt_gap rows on your line) or "pins"
##   bolt_gap    rows between bolts on a bolted line (default 2)
##   pins        rows with an old fixed piece (piton or bolt) to clip
##   pin_kind    "pin" (rusty piton) or "bolt" (default "pin")
##   crux        row of the hard move
##   crux_kind   timing | rhythm | mash  (default timing)
##   crux_name   the move's name, shown on the meter
##   rest        rows with a good stance (a bit of stamina back)
##   fixed       rows with a fixed rope (ascenders make them easy)
##   hard_aid    true: hard holds can be aided with aiders on this pitch
##   bivy        "ledge" or "hanging": where you sleep if the night falls here
##   deco        decoration hints for the painter
##   beta        one line of advice, shown at the pitch start
##
## Route keys: food (energy worth bringing; tests check a careful climber
## tops out with it), place, rock, ground, finish, weather, belayer, descent,
## view (skyline landmarks), facts, pitches.

const BELAYERS := {
	"wren_alvarez": {"name": "Wren", "skin": "c8905e", "hair": "3a2418", "hat": "e8b040", "hat_kind": "headband", "top": "4a8a8a", "bottom": "7a6a52", "pack": "8a5a3a"},
	"dick_leonard": {"name": "Dick Leonard", "skin": "e0ac7e", "hair": "3a2a1a", "hat": "", "top": "5a738f", "bottom": "a89870", "socks": "7a6a5a"},
	"jules_eichorn": {"name": "Jules Eichorn", "skin": "e0ac7e", "hair": "8a6a3a", "hat": "", "top": "7a7a72", "bottom": "b0a078", "socks": "8a3a2a"},
	"royal_robbins": {"name": "Royal Robbins", "skin": "e0ac7e", "hair": "4a3a2a", "hat": "e8e8e0", "hat_kind": "cap", "top": "5a7aa0", "bottom": "d8d0b8", "glasses": true},
	"bestor_robinson": {"name": "Bestor Robinson", "skin": "e0ac7e", "hair": "4a3a2a", "hat": "6a5a48", "hat_kind": "fedora", "top": "b09a70", "bottom": "6a5a48", "glasses": true},
	"john_salathe": {"name": "John Salathé", "skin": "e0ac7e", "hair": "a8a098", "bald": true, "hat": "", "top": "8a8a7a", "bottom": "4a4a48", "apron": "5a3a22"},
	"beverly_johnson": {"name": "Beverly Johnson", "skin": "f0c8a0", "hair": "d8b060", "long": true, "hat": "3a6a9a", "hat_kind": "bandana", "top": "c84a3a", "bottom": "3a4a6a"},
	"warren_harding": {"name": "Warren Harding", "skin": "e0ac7e", "hair": "2a2018", "hat": "", "top": "a83a2a", "bottom": "4a5068", "beard": "2a2018", "pack": "5a6a3a"},
	"george_anderson": {"name": "George Anderson", "skin": "e0ac7e", "hair": "8a5a2a", "hat": "2a3040", "hat_kind": "cap", "top": "7a2a2a", "bottom": "3a3a48", "beard": "8a5a2a"},
	"john_muir": {"name": "John Muir", "skin": "e0ac7e", "hair": "8a6040", "hat": "", "top": "6a5a48", "bottom": "5a5040", "beard": "9a7050", "long_beard": true},
}

## What a belayer says now and then. Keys are the events ClimbState reports.
const BANTER := {
	"wren_alvarez": {"start": "On belay! Smear with your feet, not your hands.", "clip": "Nice clip!", "fall": "Got you! Breathe.", "crux": "You've got this!", "top": "Off belay! That's a tick!", "rest": "Shake it out."},
	"dick_leonard": {"start": "I have you from above. You can't fall far.", "clip": "", "fall": "Rope's tight. Take your time.", "crux": "Trust your feet.", "top": "Well climbed. Come on down.", "rest": "Rest on the rope if you need to."},
	"jules_eichorn": {"start": "On belay. Watch your feet.", "clip": "Good piece.", "fall": "Caught you. Easy, now.", "crux": "Steady, steady.", "top": "That's it! Off belay.", "rest": "Plenty of time."},
	"royal_robbins": {"start": "Climb clean. Every piece comes out again.", "clip": "That one's solid.", "fall": "Caught. Clean climbers fall gracefully.", "crux": "Commit to it.", "top": "Clean. Not a scar on the rock.", "rest": "Breathe."},
	"bestor_robinson": {"start": "Ready when you are. It's a long way up.", "clip": "Sound.", "fall": "Held. Try that again.", "crux": "Easy does it.", "top": "A fine lead.", "rest": "Plenty of daylight yet."},
	"john_salathe": {"start": "Slow and steady. The rock will wait.", "clip": "Good iron.", "fall": "The rope held. Good.", "crux": "Squeeze. Breathe out.", "top": "Hm. Not bad.", "rest": "Eat something."},
	"beverly_johnson": {"start": "On belay. Climb like you're alone up there.", "clip": "Good.", "fall": "I've got you. Get back on it.", "crux": "Be bold!", "top": "That's the way.", "rest": "Rest, then go."},
	"warren_harding": {"start": "Belay's on. Sure you don't want a drink first?", "clip": "Bolt? Beautiful.", "fall": "Whoa, got you! Hang there.", "crux": "Send it, you crazy kid!", "top": "You freed it. I'll be damned.", "rest": "Hang in there. Literally."},
	"george_anderson": {"start": "I've drilled holes steeper than this. Go on.", "clip": "Solid.", "fall": "Held. Mind the runout.", "crux": "One move at a time.", "top": "Top of the dome, near enough.", "rest": "Take a breath."},
	"john_muir": {"start": "Go up, and the mountains will show you things.", "clip": "", "fall": "Steady! The mountain isn't going anywhere.", "crux": "Mind your feet.", "top": "Ah! What a temple.", "rest": "Look around. Look!"},
}

const PROFILES := {
	"firefall_slab": {
		"food": 30,
		"place": "Camp Curry, lower Glacier Point Apron",
		"rock": "apron",
		"ground": "curry",
		"finish": "tree_ledge",
		"weather": "valley",
		"belayer": "wren_alvarez",
		"view": [
			{"k": "half_dome", "x": 430, "s": 1.25, "l": 0},
			{"k": "washington_column", "x": 352, "s": 0.8, "l": 0},
			{"k": "north_dome", "x": 285, "s": 1.0, "l": 1},
			{"k": "royal_arches", "x": 330, "s": 1.0, "l": 1},
			{"k": "sierra_crest", "x": 240, "s": 1.0, "l": 2},
		],
		"facts": [
			"The Firefall: embers pushed off Glacier Point every summer night until 1968.",
			"Glacier Point stands about 3,200 feet above Curry Village.",
			"The Apron is smooth, glacier-polished granite. It's all friction.",
		],
		"pitches": [
			{"name": "Cabin Row Friction", "style": "slab", "bolts": "line", "deco": ["lichen", "streaks"], "beta": "Bolted friction. Press your soles flat and trust them."},
			{"name": "The Bulge", "style": "slab", "bolts": "line", "crux": 8, "crux_name": "The bulge", "deco": ["streaks", "manzanita"], "beta": "Chalk up before the bulge, then smear through."},
		],
	},
	"swan_slab": {
		"food": 0,
		"place": "Swan Slab Gully, below Yosemite Falls",
		"rock": "polished",
		"ground": "camp4",
		"finish": "anchor",
		"weather": "valley",
		"belayer": "dick_leonard",
		"view": [
			{"k": "glacier_point", "x": 410, "s": 1.3, "l": 0},
			{"k": "sentinel_rock", "x": 340, "s": 1.0, "l": 1},
			{"k": "cathedral_rocks", "x": 255, "s": 1.0, "l": 1},
			{"k": "sierra_crest", "x": 300, "s": 1.0, "l": 2},
		],
		"facts": [
			"Camp 4, just below, is on the National Register of Historic Places.",
			"The Sierra Club's Rock Climbing Section began teaching roped climbing in 1932.",
			"A top rope means a fall only ever drops you to the rope. It's how everyone learns.",
		],
		"pitches": [
			{"name": "Swan Slab Gully", "style": "slab", "crux": 4, "crux_name": "The polished wave", "deco": ["streaks", "moss"], "beta": "A safe place to learn. Stop the meter in the green on the polished wave."},
		],
	},
	"glacier_point_apron": {
		"food": 30,
		"place": "Glacier Point Apron, above Curry Village",
		"rock": "apron",
		"ground": "curry",
		"finish": "rim",
		"weather": "valley",
		"belayer": "jules_eichorn",
		"view": [
			{"k": "half_dome", "x": 405, "s": 1.5, "l": 0},
			{"k": "liberty_cap", "x": 455, "s": 0.8, "l": 1},
			{"k": "north_dome", "x": 285, "s": 1.1, "l": 1},
			{"k": "royal_arches", "x": 350, "s": 1.0, "l": 1},
			{"k": "washington_column", "x": 330, "s": 0.9, "l": 2},
		],
		"facts": [
			"Half Dome rises nearly 4,800 feet above the valley floor.",
			"The Four Mile Trail has linked Glacier Point to the valley since 1872.",
			"The Apron's smooth granite was polished by glaciers.",
		],
		"pitches": [
			{"name": "The Grack", "style": "flake", "cracks": 0.55, "deco": ["flake", "manzanita"], "beta": "A long flake crack. Cams love it: place them often."},
			{"name": "Apron Friction", "style": "slab", "cracks": 0.2, "crux": 6, "crux_name": "Thin smears", "deco": ["streaks", "lichen"], "beta": "Blank for a stretch. Pick your cracks and rest between them."},
			{"name": "To the Rim", "style": "crack", "cracks": 0.35, "rest": [4], "deco": ["manzanita", "flowers"], "beta": "Crack and ledge up to the rail. Tourists will wave."},
		],
	},
	"nutcracker": {
		"food": 60,
		"place": "Manure Pile Buttress, above the Church Bowl",
		"rock": "golden",
		"ground": "valley_forest",
		"finish": "tree_ledge",
		"weather": "valley",
		"belayer": "royal_robbins",
		"view": [
			{"k": "glacier_point", "x": 425, "s": 1.35, "l": 0},
			{"k": "sentinel_rock", "x": 340, "s": 1.0, "l": 1},
			{"k": "half_dome", "x": 470, "s": 0.7, "l": 0},
			{"k": "cathedral_rocks", "x": 260, "s": 0.9, "l": 2},
			{"k": "sierra_crest", "x": 300, "s": 1.0, "l": 2},
		],
		"facts": [
			"Royal and Liz Robbins climbed it in 1967, protecting it only with nuts.",
			"It's one of the Valley's most popular climbs: in summer there is often a queue.",
			"Clean climbing leaves no marks: whatever you place, you take back out.",
		],
		"pitches": [
			{"name": "Flakes to the Tree", "style": "crack", "cracks": 0.4, "deco": ["flake", "tree"], "beta": "Broken flakes up to a tree belay."},
			{"name": "The Finger Crack", "style": "crack", "cracks": 0.55, "deco": ["lichen"], "beta": "A thin crack that takes cams all the way."},
			{"name": "Hand-Crack Corner", "style": "crack", "cracks": 0.5, "rest": [5], "deco": ["streaks"], "beta": "A corner crack. Jam and layback."},
			{"name": "The Traverse", "style": "crack", "cracks": 0.4, "deco": ["manzanita"], "beta": "Move left and keep your feet high."},
			{"name": "The Mantel", "style": "crack", "cracks": 0.4, "crux": 6, "crux_kind": "mash", "crux_name": "The mantel", "deco": ["flake"], "beta": "Press down on the shelf, then stand up: tap Up quickly."},
		],
	},
	"higher_cathedral_spire": {
		"food": 60,
		"place": "Higher Cathedral Spire, Cathedral Rocks",
		"rock": "orange",
		"ground": "bridalveil_talus",
		"finish": "spire_top",
		"weather": "valley",
		"belayer": "jules_eichorn",
		"descent": "rappel",
		"view": [
			{"k": "el_capitan", "x": 395, "s": 1.5, "l": 0},
			{"k": "three_brothers", "x": 320, "s": 1.0, "l": 1},
			{"k": "half_dome", "x": 470, "s": 0.55, "l": 0},
			{"k": "sierra_crest", "x": 250, "s": 1.0, "l": 2},
		],
		"facts": [
			"In April 1934 three Sierra Club climbers made the first ascent, hauling a rack of pitons.",
			"It was the Sierra's first big climb to use aid: pitons, and ropes to hang from.",
			"A famous Dulfersitz rappel brought them down to well-wishers on the ground.",
		],
		"pitches": [
			{"name": "First Base", "style": "crack", "cracks": 0.4, "pins": [4], "deco": ["tree", "lichen"], "beta": "A corner crack to a tree. Their old pitons are still in the rock: clip them."},
			{"name": "The Bulge", "style": "crack", "cracks": 0.35, "pins": [3, 6], "crux": 5, "crux_name": "5.9 bulge", "deco": ["lichen"], "beta": "Two ways to the next tree, both 5.9. The old pins save cams."},
			{"name": "Tree Belay", "style": "crack", "cracks": 0.4, "pins": [5], "deco": ["tree"], "beta": "Steady cracks between trees."},
			{"name": "The Bathtub", "style": "crack", "cracks": 0.4, "rest": [4], "pins": [2], "deco": ["streaks"], "beta": "A deep scoop in the granite: rest here before the top."},
			{"name": "Friction and Crack", "style": "slab", "cracks": 0.3, "deco": ["streaks"], "beta": "A slabby stretch with just enough cracks."},
			{"name": "Summit Pinnacle", "style": "crack", "cracks": 0.35, "pins": [4], "deco": ["lichen"], "beta": "A few last moves to the summit. Then rappel."},
		],
	},
	"steck_salathe": {
		"food": 150,
		"place": "Sentinel Rock, above the Four Mile Trail",
		"rock": "dark",
		"ground": "valley_forest",
		"finish": "chimney_top",
		"weather": "valley",
		"belayer": "john_salathe",
		"descent": "rappel",
		"view": [
			{"k": "yosemite_falls", "x": 355, "s": 1.3, "l": 0},
			{"k": "half_dome", "x": 445, "s": 0.9, "l": 0},
			{"k": "three_brothers", "x": 285, "s": 1.0, "l": 1},
			{"k": "north_dome", "x": 400, "s": 0.9, "l": 1},
			{"k": "sierra_crest", "x": 260, "s": 1.0, "l": 2},
		],
		"facts": [
			"In 1950, Allen Steck and John Salathé climbed it over several days, rationing their water.",
			"Salathé forged his hard steel pitons from old Model A axles.",
			"The Wilson Overhang and the Narrows are the route's famous cruxes.",
		],
		"pitches": [
			{"name": "Flake System", "style": "crack", "cracks": 0.45, "pins": [5], "deco": ["flake", "tree"], "beta": "Start up big flakes."},
			{"name": "Chockstone Chimney", "style": "chimney", "cols": [1, 2, 3], "cracks": 0.5, "deco": ["chimney"], "beta": "Chimneying: alternate Left and Right, back and feet."},
			{"name": "Wilson Overhang", "style": "crack", "cracks": 0.5, "crux": 5, "crux_name": "Wilson Overhang", "pins": [3], "deco": ["streaks"], "beta": "A wide crack steepens into an overhang that pushes you out."},
			{"name": "Flake Traverse", "style": "crack", "cracks": 0.4, "rest": [4], "deco": ["flake"], "beta": "A traverse on flakes. Rest at the stance."},
			{"name": "Wide Cracks", "style": "crack", "cracks": 0.55, "pins": [2, 6], "deco": ["lichen"], "beta": "Wide cracks eat your rack. Use the fixed pins."},
			{"name": "The Narrows", "style": "chimney", "cols": [1, 2, 3], "cracks": 0.4, "crux": 5, "crux_kind": "rhythm", "crux_name": "The Narrows", "deco": ["chimney"], "beta": "Squeeze up the narrow chimney: alternate Left and Right to the beat."},
			{"name": "Summit Chimney", "style": "chimney", "cols": [1, 2, 3], "cracks": 0.4, "deco": ["chimney"], "beta": "A last chimney to the summit."},
		],
	},
	"astroman": {
		"food": 180,
		"place": "Washington Column, east face",
		"rock": "pale",
		"ground": "valley_forest",
		"finish": "column_top",
		"weather": "valley",
		"belayer": "beverly_johnson",
		"descent": "rappel",
		"view": [
			{"k": "half_dome", "x": 395, "s": 1.7, "l": 0},
			{"k": "basket_dome", "x": 462, "s": 0.8, "l": 1},
			{"k": "north_dome", "x": 280, "s": 1.0, "l": 1},
			{"k": "clouds_rest", "x": 340, "s": 0.9, "l": 0},
			{"k": "sierra_crest", "x": 300, "s": 1.0, "l": 2},
		],
		"facts": [
			"Its first free ascent in 1975 made it one of the Valley's hardest long free climbs.",
			"The Harding Slot is a body-width flue where you can't even turn your head.",
			"The Boulder Problem and the Enduro Corner are two of the Valley's famous pitches.",
		],
		"pitches": [
			{"name": "Fingertip Start", "style": "crack", "cracks": 0.45, "pins": [4], "deco": ["lichen"], "beta": "Thin cracks from the start. Chalk up."},
			{"name": "The Boulder Problem", "style": "crack", "cracks": 0.4, "crux": 5, "crux_name": "Boulder Problem", "deco": ["streaks"], "beta": "A short, hard traverse into a fingertip crack. Small pieces."},
			{"name": "Enduro Corner", "style": "crack", "cracks": 0.55, "pins": [6], "deco": ["corner"], "beta": "A long, sustained corner. Pace yourself."},
			{"name": "Changing Corners", "style": "crack", "cracks": 0.45, "crux": 6, "crux_name": "Changing corners", "deco": ["corner"], "beta": "Switch from one wall of the corner to the other on thin holds."},
			{"name": "The Sidewalk", "style": "slab", "cracks": 0.3, "rest": [3, 6], "deco": ["streaks"], "beta": "A ramp of easier ground. Eat and shake out."},
			{"name": "Harding Slot", "style": "chimney", "cols": [1, 2, 3], "cracks": 0.35, "crux": 5, "crux_kind": "rhythm", "crux_name": "Harding Slot", "deco": ["chimney"], "beta": "A body-width flue. Don't stop: alternate Left and Right."},
			{"name": "The Headwall", "style": "crack", "cracks": 0.45, "pins": [3, 7], "deco": ["lichen"], "beta": "Steep to the very top."},
		],
	},
	"separate_reality": {
		"food": 30,
		"place": "Mist Wall, west end of the Valley",
		"rock": "roof",
		"ground": "mist_wall",
		"finish": "roof_lip",
		"weather": "valley",
		"belayer": "royal_robbins",
		"view": [
			{"k": "el_capitan", "x": 360, "s": 1.7, "l": 0},
			{"k": "three_brothers", "x": 290, "s": 1.0, "l": 1},
			{"k": "sierra_crest", "x": 440, "s": 1.0, "l": 2},
		],
		"facts": [
			"Ron Kauk made the first free ascent in 1978.",
			"The roof crack is about 20 feet long and 150 feet over the ground.",
			"In 1986 Wolfgang Güllich free-soloed it, a first.",
		],
		"pitches": [
			{"name": "The Roof", "style": "roof", "rows": 11, "cracks": 0.9, "crux": 9, "crux_name": "The lip", "deco": ["roof"], "beta": "Hang under the roof and jam out. Don't look down until you've turned the lip."},
		],
	},
	"the_nose": {
		"food": 300,
		"place": "The Nose of El Capitan",
		"rock": "elcap",
		"ground": "el_cap_meadow",
		"finish": "el_cap_top",
		"weather": "valley",
		"belayer": "warren_harding",
		"descent": "walk",
		"view": [
			{"k": "cathedral_rocks", "x": 345, "s": 1.5, "l": 0},
			{"k": "bridalveil", "x": 380, "s": 1.0, "l": 0},
			{"k": "half_dome", "x": 458, "s": 0.55, "l": 0},
			{"k": "sierra_crest", "x": 260, "s": 1.0, "l": 2},
		],
		"facts": [
			"Warren Harding's team took 47 days over 18 months in 1957-58.",
			"The first free ascent came in 1993.",
			"Everyone goes by the Great Roof and the Changing Corners; both are famous cruxes.",
		],
		"pitches": [
			{"name": "Sickle Ledge", "style": "crack", "cracks": 0.5, "fixed": [1, 2, 3, 4, 5, 6], "rest": [8], "deco": ["tree"], "beta": "Fixed lines lead up to Sickle Ledge: hold Shift to jug them."},
			{"name": "Stoveleg Cracks", "style": "crack", "cracks": 0.55, "fixed": [2, 3, 4], "pins": [5], "deco": ["lichen"], "beta": "Thin cracks. Fixed lines help on the lower half."},
			{"name": "El Cap Tower", "style": "crack", "cracks": 0.5, "rest": [7], "bivy": "ledge", "deco": ["tree"], "beta": "A big ledge. A good place to eat and sleep."},
			{"name": "Texas and Boot Flakes", "style": "flake", "cracks": 0.6, "pins": [3], "deco": ["flake"], "beta": "Big flakes, then a crack in the boot."},
			{"name": "The King Swing", "style": "crack", "cracks": 0.45, "crux": 5, "crux_kind": "rhythm", "crux_name": "King Swing", "deco": ["streaks"], "beta": "Swing across the wall to the next crack: alternate Left and Right to build momentum."},
			{"name": "Camp IV", "style": "crack", "cracks": 0.5, "rest": [3], "bivy": "ledge", "deco": ["tree"], "beta": "Eagle Ledge and Camp IV: a big ledge, and the night."},
			{"name": "The Great Roof", "style": "roof", "cols": [0, 1, 2, 3, 4], "cracks": 0.85, "crux": 6, "crux_name": "Great Roof", "hard_aid": true, "bivy": "hanging", "deco": ["roof"], "beta": "A huge roof. Hold Shift to aid a hard move with your aiders."},
			{"name": "Pancake Flake", "style": "flake", "cracks": 0.55, "rest": [5], "pins": [3], "deco": ["flake"], "beta": "A huge flake. The rest is mostly climbing."},
			{"name": "Changing Corners", "style": "crack", "cracks": 0.5, "crux": 5, "crux_name": "Changing Corners", "hard_aid": true, "deco": ["corner"], "beta": "Switch corner walls on tiny holds. Then it's only the headwall."},
		],
	},
	"royal_arches": {
		"food": 90,
		"place": "Royal Arches, behind the Ahwahnee",
		"rock": "arches",
		"ground": "ahwahnee",
		"finish": "arches_top",
		"weather": "valley",
		"belayer": "bestor_robinson",
		"descent": "rappel",
		"view": [
			{"k": "glacier_point", "x": 345, "s": 1.5, "l": 0},
			{"k": "half_dome", "x": 440, "s": 1.3, "l": 0},
			{"k": "washington_column", "x": 280, "s": 1.0, "l": 1},
			{"k": "sierra_crest", "x": 390, "s": 1.0, "l": 2},
		],
		"facts": [
			"The first ascent was in 1936.",
			"Climbers typically descend a long series of bolted rappels.",
			"The Ahwahnee below was built in 1927 as a grand lodge.",
		],
		"pitches": [
			{"name": "The Dihedral", "style": "crack", "cracks": 0.5, "pins": [5], "deco": ["corner"], "beta": "A big corner climbs the first stretch."},
			{"name": "Arch Cracks", "style": "crack", "cracks": 0.45, "deco": ["lichen"], "beta": "Cracks up the arch face."},
			{"name": "Rotten Chimney", "style": "chimney", "cols": [1, 2, 3], "cracks": 0.4, "rest": [6], "deco": ["chimney"], "beta": "A loose chimney. Alternate Left and Right."},
			{"name": "The Pendulum", "style": "crack", "cracks": 0.4, "crux": 5, "crux_kind": "rhythm", "crux_name": "Pendulum", "fixed": [4, 5, 6], "deco": ["streaks"], "beta": "Swing across on the rope: alternate Left and Right."},
			{"name": "Upper Arches", "style": "crack", "cracks": 0.4, "rest": [4], "deco": ["manzanita"], "beta": "More cracks and ledges to the top."},
			{"name": "The Friction Traverse", "style": "slab", "bolts": "line", "bolt_gap": 2, "crux": 6, "crux_name": "Friction traverse", "deco": ["streaks"], "beta": "A long slab traverse. Clip the bolts and don't rush."},
		],
	},
	"snake_dike": {
		"food": 60,
		"place": "Half Dome, southwest face",
		"rock": "dome",
		"ground": "half_dome_forest",
		"finish": "dome_top",
		"weather": "valley",
		"belayer": "george_anderson",
		"descent": "cables",
		"view": [
			{"k": "liberty_cap", "x": 385, "s": 1.3, "l": 0},
			{"k": "mt_broderick", "x": 330, "s": 1.0, "l": 1},
			{"k": "nevada_fall", "x": 350, "s": 1.0, "l": 1},
			{"k": "clouds_rest", "x": 455, "s": 1.3, "l": 0},
			{"k": "sierra_crest", "x": 260, "s": 1.0, "l": 2},
		],
		"facts": [
			"First climbed in 1965; it was later bolted at the first party's request.",
			"Half Dome is a granodiorite monolith 8,839 feet above the sea.",
			"Climbers walk down the cables on the dome's back side.",
		],
		"pitches": [
			{"name": "Slab Start", "style": "slab", "bolts": "line", "bolt_gap": 3, "deco": ["lichen"], "beta": "Friction slabs to reach the dike."},
			{"name": "The Dike Begins", "style": "dike", "bolts": "line", "bolt_gap": 3, "deco": ["dike"], "beta": "Stay on the dike: it's the easy way."},
			{"name": "The First Runout", "style": "dike", "bolts": "line", "bolt_gap": 3, "crux": 6, "crux_name": "Runout", "deco": ["dike"], "beta": "Bolts are far apart. Clip every one."},
			{"name": "The Long Runout", "style": "dike", "bolts": "line", "bolt_gap": 3, "rest": [4], "deco": ["dike"], "beta": "Pitch after pitch of dike. Don't hurry."},
			{"name": "Ramp to the Gully", "style": "slab", "bolts": "line", "bolt_gap": 3, "deco": ["streaks"], "beta": "Easier ground to the gully."},
		],
	},
	"cathedral_peak": {
		"food": 30,
		"place": "Cathedral Peak, Tuolumne Meadows",
		"rock": "knobby",
		"ground": "tuolumne",
		"finish": "peak_summit",
		"weather": "alpine",
		"belayer": "john_muir",
		"descent": "walk",
		"view": [
			{"k": "cockscomb", "x": 395, "s": 1.2, "l": 0},
			{"k": "unicorn_peak", "x": 330, "s": 1.0, "l": 0},
			{"k": "echo_peaks", "x": 445, "s": 1.0, "l": 1},
			{"k": "matthes_crest", "x": 270, "s": 1.0, "l": 1},
			{"k": "sierra_crest", "x": 300, "s": 1.0, "l": 2},
		],
		"facts": [
			"John Muir climbed Cathedral Peak in 1869 and called it a temple.",
			"Its summit stands about 10,900 feet above the sea.",
			"Afternoon thunderstorms build over the high country: climb early.",
		],
		"pitches": [
			{"name": "Approach Slabs", "style": "knobs", "cracks": 0.15, "deco": ["lichen", "krummholz"], "beta": "Low-angle slabs with big knobs."},
			{"name": "Lower Buttress", "style": "knobs", "cracks": 0.2, "deco": ["krummholz"], "beta": "Knobby granite: easy and fun."},
			{"name": "The Chimney", "style": "knobs", "cracks": 0.3, "crux": 5, "crux_name": "Chimney", "rest": [3], "deco": ["lichen"], "beta": "A short chimney: the buttress's one bottleneck."},
			{"name": "Upper Knobs", "style": "knobs", "cracks": 0.2, "deco": ["lichen"], "beta": "More knobs. The view starts to open up."},
			{"name": "Summit Block", "style": "knobs", "cracks": 0.2, "deco": ["summit"], "beta": "A tiny summit, as big as a kitchen table. Hold on."},
		],
	},
	"lyell_glacier": {
		"food": 60,
		"place": "Lyell Glacier, Mount Lyell",
		"rock": "ice",
		"ground": "moraine",
		"finish": "glacier_ridge",
		"weather": "alpine",
		"belayer": "john_muir",
		"descent": "walk",
		"view": [
			{"k": "mt_lyell", "x": 400, "s": 1.6, "l": 0},
			{"k": "mt_maclure", "x": 330, "s": 1.2, "l": 0},
			{"k": "donohue_pass", "x": 455, "s": 1.0, "l": 1},
			{"k": "sierra_crest", "x": 270, "s": 1.0, "l": 2},
		],
		"facts": [
			"At 13,114 feet, Mount Lyell is Yosemite's highest peak.",
			"In 1872 Muir drove stakes into the neighboring Maclure Glacier to prove glaciers move.",
			"The Lyell Glacier has shrunk dramatically since Muir's day.",
		],
		"pitches": [
			{"name": "Moraine and Snowfield", "style": "snow", "deco": ["moraine"], "beta": "Easy snow. Kick steps with your crampons."},
			{"name": "Sun Cups", "style": "snow", "deco": ["suncups"], "beta": "Bumpy snow. In the afternoon it turns to slush."},
			{"name": "The Crevasse Field", "style": "ice", "crux": 5, "crux_name": "Crevasse bridge", "deco": ["crevasse"], "beta": "Blue ice and crevasses. Mind the gaps and swing your axe."},
			{"name": "The Bergschrund", "style": "ice", "crux": 4, "crux_name": "The bergschrund", "deco": ["crevasse"], "beta": "The gap between glacier and rock. Step across."},
		],
	},
}


static func get_profile(route_id: String) -> Dictionary:
	return PROFILES.get(route_id, {})


## The spec for pitch [param index] of [param route_id], with defaults filled.
static func pitch_spec(route: RouteData, index: int) -> Dictionary:
	var profile: Dictionary = PROFILES.get(route.id, {})
	var list: Array = profile.get("pitches", [])
	var spec: Dictionary = (list[index] if index < list.size() else {}).duplicate(true)
	var default_style := "slab" if route.protection == "bolts" else "crack"
	spec["style"] = spec.get("style", default_style)
	spec["rows"] = int(spec.get("rows", route.moves_per_pitch))
	if route.protection == "bolts" and not spec.has("bolts"):
		spec["bolts"] = "line"
	spec["diff"] = route.pitches[mini(index, route.pitches.size() - 1)]
	spec["name"] = spec.get("name", "Pitch %d" % (index + 1))
	return spec


static func belayer_look(route: RouteData) -> Dictionary:
	var id: String = get_profile(route.id).get("belayer", "")
	var look: Dictionary = BELAYERS.get(id, {"name": "", "skin": "e0ac7e", "hair": "5a3a22", "hat": "", "top": "8a4a6a", "bottom": "4a4a58"}).duplicate()
	look["id"] = id
	return look


static func banter(route: RouteData, event: String) -> String:
	var id: String = get_profile(route.id).get("belayer", "")
	return BANTER.get(id, {}).get(event, "")
