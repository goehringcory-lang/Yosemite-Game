class_name SmallTalk
extends RefCounted
## Everyday talk: what people say when they have no quest for you, no news
## of the story and no hint (QuestLog.talk_to). Each person has a line for
## each season, for rain and for snow, for the morning and the evening, for
## where they're standing ("places": a spot, a timetable stop or a region),
## and more as they get to know you (FRIEND_HEARTS, CLOSE_HEARTS). Their
## usual lines (CharacterData.idle_lines) stay in the mix, and they never say
## the same line twice running. Lines that fit right now are weighted
## (WEIGHTS), so a wet day mostly gets talk about the rain.
##
## They also pass on what you've been up to (Friendship.news): a first
## ascent, a rescue, a big fish, a bear. Each person mentions the latest
## thing once, if they have something to say about that kind of news, in
## the few days after.
##
## The Native characters (AWAITING_REVIEW) aren't here: they keep the lines
## the tribes have reviewed, and new ones wait for the next review.

## The Native characters. Their words have been reviewed by the tribes
## traditionally associated with Yosemite, so new everyday lines and heart
## scenes for them wait until the tribes have read those too.
const AWAITING_REVIEW := ["tenaya", "maggie_howard", "lucy_telles", "maria_lebrado", "carrie_bethel"]
## Hearts for "friend" lines, and for "close" ones.
const FRIEND_HEARTS := 2
const CLOSE_HEARTS := 4
## How many days old news stays worth mentioning.
const NEWS_DAYS := 2
## "morning" lines before this hour; "evening" ones from EVENING_FROM until NIGHT_FROM.
const MORNING_UNTIL := 10
const EVENING_FROM := 18
const NIGHT_FROM := 22
const SEASON_KEYS := ["spring", "summer", "fall", "winter"]
## How likely each kind of line is to be picked, against the others that fit.
const WEIGHTS := {"snow": 4, "rain": 4, "places": 3, "morning": 2, "evening": 2, "season": 2, "friend": 2, "close": 2, "usual": 1}
## What news each person can pass on is in their "news": climb (a first
## ascent), rescue (who you found), fish (a first of its kind or a trophy) and
## sighting (Friendship.SIGHTINGS), each with a %s for the thing itself.
const NEWS_KINDS := ["climb", "rescue", "fish", "sighting"]

## Everyone's everyday lines, by character id. "loved" is their thanks for a
## gift they love (Friendship.give).
const LINES := {
	"galen_clark": {
		"spring": "The Merced's running high and loud. Every spring it sounds like it has somewhere important to be.",
		"summer": "The stages bring visitors in by the dozen this time of year. Half of them stand at this gate with their mouths open. I don't blame them.",
		"fall": "The black oaks are dropping their acorns. That harvest was gathered here long before any of us came, and I hope long after.",
		"winter": "Snow on the meadow and nobody on the road. Winter's when the valley gets to be itself again.",
		"rain": "A soft rain like this is good for the meadows. And it gives an old man a fine excuse to sit.",
		"snow": "I'd like to see the Grove in this snow. The big trees wear it as if they've done it for three thousand winters, because they have.",
		"morning": "Up early? Good. The best hours in the valley are the ones before the stages come in.",
		"evening": "Watch the light climb the walls in the evening. It goes up slow, like a tide going out.",
		"friend": "You've become a regular face at this gate. In my notes I've written you down as reliable. That's my highest mark.",
		"close": "I've kept a lot of notes in my years here. The ones about the people who stopped to talk are the ones I read again.",
		"news": {
			"climb": "Lamon tells me you were up %s. I've written it down, with your name beside it. The who matters.",
			"rescue": "Jo says you brought %s home safe. That's the part of guarding the valley nobody puts in a report.",
			"sighting": "You saw %s? Where, exactly? I like to know who else is keeping an eye on the place.",
		},
		"loved": "Now there's a gift with some thought in it. You know how to cheer an old man. Thank you.",
	},
	"james_lamon": {
		"spring": "Apple blossom week! If the frost stays off a few more nights, it'll be a good year.",
		"summer": "Summer's for weeding and watering. The trees do the rest, if the deer let them.",
		"fall": "Picking time. Every tree's heavy, and the bears have noticed too.",
		"winter": "Cellar's full and the snow's deep. A man could do worse than a winter here with a barrel of apples.",
		"rain": "Rain's good for the orchard and bad for my roof. I'll get up there and fix it one of these years.",
		"snow": "Snow up past the fence posts. My first winter here, I thought it'd never stop. It did, about April.",
		"morning": "The deer have been at my windfalls since before light. They're earlier risers than I am.",
		"evening": "Evenings I sit on the step and count the trees. Same number every night, but I like the counting.",
		"friend": "You're welcome at this cabin any time. Mind the third step, it's loose.",
		"close": "Some nights it's so quiet I can hear the river from my bed. I came for a season and stayed for that sound.",
		"news": {
			"climb": "Heard you were up %s. I get dizzy on the apple ladder, myself.",
			"sighting": "You saw %s? Long as it stays out of my orchard, it's welcome in the valley.",
		},
		"loved": "Apples! Now you're speaking my language. Thank you kindly.",
	},
	"bridget_degnan": {
		"spring": "Spring, and the climbers come back hungry. I double the loaves and they're still gone by noon.",
		"summer": "It's hot as an oven in the bakery by ten. Mind you, it is an oven.",
		"fall": "The last visitors of the year always buy two loaves: one for now and one for the long road home.",
		"winter": "Winter's quiet. I bake for the folks who stay, and by Christmas we all know each other's names.",
		"rain": "Rain on the window and bread in the oven. There's no better sound or smell on this earth.",
		"snow": "Snowed in again! John's out with the shovel and I'm in with the oven. I got the better job.",
		"morning": "You're up with the bakers! The first loaves are just out. Go on, breathe that in.",
		"evening": "Evening already? I've been up since three. Don't tell the dough I'm tired.",
		"places": {
			"cooks_meadow": "I come out to the meadow every evening to cool off. After a day by the oven, this breeze is better than a holiday.",
		},
		"friend": "You've a good face for a bakery. Folks see you in here and think the bread must be good.",
		"close": "Back in Ireland I never dreamed of a kitchen under a waterfall. Some mornings I still can't believe my luck.",
		"news": {
			"climb": "A climber in for bread said you went up %s. I said, sure, but did they have their breakfast first?",
			"rescue": "Jo says you found %s! I'm sending a loaf up to the rescue site to celebrate.",
			"fish": "Somebody saw you land %s. Bring the next one by and I'll bake it in a crust.",
		},
		"loved": "Oh, you darling! That's just what I'd have picked for myself.",
	},
	"dick_leonard": {
		"spring": "Spring rock's still cold in the mornings. Warm up on Swan Slab before you try anything steep.",
		"summer": "In summer the granite gets hot enough to fry an egg on. Climb early, or climb in the shade.",
		"fall": "Fall's the best climbing in the Valley: cool rock, long dry spells, and everybody's fit by now.",
		"winter": "Winter's for mending ropes and reading the old Bulletins. And for planning next year, of course.",
		"rain": "Wet granite's slick as glass. Today's a day for knots and stories, not for leading.",
		"snow": "Snow on the ledges. Back in Berkeley we'd practice belays on days like this. No climbing, just catching.",
		"morning": "Morning! First thing I do every day is check my knots. Second thing is coffee.",
		"places": {
			"camp_4_fire": "Pull up a log. The Camp 4 fire's the best place in the Valley to hear who climbed what, and who's exaggerating.",
			"village_store": "Picking up supplies. A climber's shopping list: oats, raisins, and more tape than seems reasonable.",
		},
		"friend": "You hold a rope like you mean it. That's rarer than you'd think.",
		"close": "A good belay is a promise. You've kept every one you've made to me.",
		"news": {
			"climb": "%s? Well done! Did you thank your belayer? Always thank your belayer.",
			"rescue": "Jo says you brought %s home. Good. That's what the rope's really for.",
		},
		"loved": "Now that's a climber's gift. Thank you!",
	},
	"jules_eichorn": {
		"spring": "Spring melt makes the whole Valley sing. Every waterfall's in a different key.",
		"summer": "In summer I head up to the high peaks. There are summits up there that hardly anyone has stood on.",
		"fall": "Fall light on the Spires. Ansel would tell you to wait for it, and he'd be right.",
		"winter": "Winter's for piano. My students think scales are hard. They should try a chimney.",
		"rain": "Rain on a tent sounds like brushes on a snare drum. I've written whole tunes in my head waiting out a storm.",
		"snow": "The Spires in snow look like something out of a fairy tale. An unclimbable one, today.",
		"morning": "Morning practice: fingers first. It's the same for the piano as for the rock.",
		"evening": "Evenings I hum the day's climb back to myself, pitch by pitch. It's how I remember the moves.",
		"places": {
			"amphitheater": "Staying for the evening program? I like to sit at the back and listen to the crowd go quiet when the stars come out.",
		},
		"friend": "You climb with rhythm now. I can hear it in your feet on the rock.",
		"close": "Some of my best days on rock were with friends I met right here. You're on that list now.",
		"news": {
			"climb": "You climbed %s! Bestor owes me another dollar. I'm going to be a rich man.",
		},
		"loved": "Oh, perfect! That's exactly what I'd have packed.",
	},
	"bestor_robinson": {
		"spring": "Spring is for planning. I've three routes drawn out already, with every piton they'll need.",
		"summer": "A summer day gives you fourteen hours of light. I plan for twelve. Always leave yourself two.",
		"fall": "Fall's when I tally up the season: every climb in the notebook, with what went right and what didn't.",
		"winter": "Winter is committee season: meetings in the city and minutes to write. I'd rather be on the Spire.",
		"rain": "Rain's on the plan too. I always pencil in a day of it.",
		"snow": "Snow changes every route. Whatever you planned, plan it again.",
		"morning": "Early start? Good. Every hour you save in the morning is an hour of daylight at the top.",
		"evening": "Evening's for checking tomorrow's gear. Count it twice. It's cheaper than finding out on the wall.",
		"friend": "You've started planning your climbs, I can tell. You come back with daylight to spare.",
		"close": "I've written a great many things in my life: briefs, minutes, route notes. Our talks would make a good chapter.",
		"news": {
			"climb": "So you've done %s. Tell me everything: how long it took, what you carried, and what you'd change.",
			"rescue": "I hear you found %s. A careful search is a planned search. Well done.",
		},
		"loved": "Perfect. That's what I'd have packed for myself. Thank you.",
	},
	"jennie_curry": {
		"spring": "We're airing out the tents for the season. Every one of them still smells of last summer's campfires.",
		"summer": "A full camp tonight! Every tent's taken and three families are asking about the porch.",
		"fall": "The camp goes quiet in the fall. I miss the noise for about a day, and then I love the quiet.",
		"winter": "In winter we mend the canvas and count the cots. Next summer always comes sooner than you think.",
		"rain": "Rain on canvas. Half my guests think it's romantic and the other half want their money back.",
		"snow": "Snow on the tent roofs. Somebody has to knock it off before they sag, and somebody is usually me.",
		"morning": "Good morning! Breakfast is on, and there's coffee for anybody who smiles.",
		"places": {
			"pavilion_door": "Lunch at the pavilion! Every day I count the soup bowls and the pie plates, and every day the pie wins.",
			"amphitheater": "The evening program's starting. David used to call it out so loud they heard him at Glacier Point.",
		},
		"friend": "You're practically one of the family. You'd better start calling me Mother Curry, like everybody else.",
		"close": "David and I opened this camp so working families could see Yosemite. You'd have been one of our favorite guests.",
		"news": {
			"climb": "One of my guests came back from the meadow saying you'd climbed %s. I told her I know you.",
			"rescue": "I hear you found %s. That family will be telling the story for years. Well done.",
		},
		"loved": "Oh, my! That's just the thing. You're a dear.",
	},
	"george_anderson": {
		"spring": "The river's up over the stepping stones. Mind your feet at the Happy Isles this time of year.",
		"summer": "Drilling's hot work in summer. The granite holds the sun like a forge.",
		"fall": "October's the month for the Dome: dry rock and cool air. That's when I made the top.",
		"winter": "Snow on the Dome. Nobody's going up there till spring. Not even me.",
		"rain": "Rain rusts the iron. I'll be up the trail with the oil can tomorrow.",
		"snow": "Snow on the Dome's back. You'd need more than iron to get up it today.",
		"morning": "Morning. I've been at the anvil an hour already. Iron doesn't sleep in, so neither do I.",
		"evening": "Evening's when I sharpen the drills for tomorrow. A dull drill makes for a long day.",
		"friend": "You've a good grip and a level head. I'd let you hold the drill.",
		"close": "Back in Scotland I shod horses. I never thought I'd end up shoeing a mountain.",
		"news": {
			"climb": "I hear you went up %s. Good. Every climb puts a little iron in the blood.",
		},
		"loved": "That'll keep a man going up the Dome. Thank you kindly.",
	},
	"clare_hodges": {
		"spring": "Bear season's starting. They come out of the dens hungry, and they remember every campsite.",
		"summer": "Summer means a full valley and a full logbook: lost children, lost hats and lost tempers.",
		"fall": "Fall's my favorite patrol. Golden oaks, quiet roads, and the bears too busy with acorns to bother anybody.",
		"winter": "Winter patrol is mostly checking on the folks who stay, and breaking the ice on the horse trough.",
		"rain": "Rain on patrol. My hat's seen worse, and so have I.",
		"snow": "Fresh snow, good tracking. You'd be surprised what walks through the valley at night.",
		"morning": "Morning patrol's done: two bears, one lost camper, and a deer in the station garden.",
		"evening": "Evening's when the bears come calling. Keep your food packed away tonight.",
		"places": {
			"camp_4": "Just checking the campground. Climbers are good people, but they keep food in their tents like it's a bank vault.",
			"lower_yosemite_fall": "I walk out to the fall most afternoons. Somebody always needs directions, and somebody's always about to climb the wet rocks.",
			"camp_4_fire": "Off duty, mostly. A ranger by a campfire hears more news than a ranger in a station.",
		},
		"friend": "You'd make a fine ranger, you know. You notice things.",
		"close": "When I started, some folks wouldn't take directions from me. You never once doubted me. I noticed that too.",
		"news": {
			"climb": "%s? Good for you. Next time, sign out at the station before the big ones. That's not a suggestion.",
			"rescue": "I read Jo's report on %s. Clear notes and a happy ending. I couldn't ask for more.",
			"sighting": "You saw %s? Log it with the date and the place. That's how we learn what's out there.",
		},
		"loved": "Well! That's kind of you. Thank you.",
	},
	"ansel_adams": {
		"spring": "Spring storms clearing over the Valley make the best skies. I wait all year for one good one.",
		"summer": "Summer light is flat at midday. I spend the middle of the day in the darkroom and come out at five.",
		"fall": "The cottonwoods are gold and the falls are a trickle. Fall is quieter, and quieter makes better pictures.",
		"winter": "Snow on the Valley floor makes everything simple: white, gray and black. That's all a photograph needs.",
		"rain": "A storm's coming through. If it clears by evening, I'll be at the turnout with the camera, praying.",
		"snow": "Snow and clearing cloud. If anyone took orders for weather, this is what I'd order.",
		"morning": "I was out before dawn. The first light on Half Dome lasts about four minutes, and I got two of them.",
		"evening": "Evening light on El Capitan turns the granite the color of a ripe apricot.",
		"places": {
			"cooks_meadow": "Cook's Meadow is the best foreground in the Valley. I've photographed it a hundred times, and I'm not done.",
		},
		"friend": "You've got an eye, you know. You stop and look at things. Most people walk right past.",
		"close": "I used to think a photograph was about the mountain. More and more, I think it's about who's standing there looking.",
		"news": {
			"climb": "You climbed %s? If I'd known, I'd have had the long lens on you.",
			"sighting": "You saw %s! I never have the right lens when it matters. Did you get a good look?",
		},
		"loved": "Oh, splendid! You know my weaknesses. Thank you.",
	},
	"james_mccauley": {
		"spring": "Spring's when I fix the trail. Every winter the mountain tries to take back a switchback or two.",
		"summer": "A busy summer at the Mountain House! Guests on the porch, guests in the hall, and one asleep in my chair.",
		"fall": "Fall's slow at the top. Just me, the ravens and the best view in the world.",
		"winter": "Snow up to the eaves of the Mountain House. A sensible man would go down the hill for the winter.",
		"rain": "Rain on the trail means washouts. I'll be out with the shovel tomorrow, and the toll box will be empty.",
		"snow": "Snowed in! Nobody's paying a toll today, and nobody's climbing four miles of snow either.",
		"morning": "Morning! The sun comes over the high country and lights the whole Valley below us. Worth the toll, I always say.",
		"evening": "Staying for the Firefall tonight? There's no finer show in California, and I'll argue that with anybody.",
		"friend": "You've walked my trail so often I've stopped charging you. Don't tell the others.",
		"close": "I built that trail for the tolls, I'll admit it. These days I'd keep it up for nothing, just for the company it brings.",
		"news": {
			"climb": "%s, eh? I can see half the routes in the Valley from my porch. Next time, give us a wave.",
		},
		"loved": "Now there's a fine thing! Consider your toll paid for a year.",
	},
	"enid_michael": {
		"spring": "The dogwood's out along the river. I write it up in the Nature Notes every spring, and every spring it surprises me.",
		"summer": "Summer's when the high meadows finally wake. The flowers up there get about six weeks to do a year's work.",
		"fall": "Most people think the flowers are done by fall. Look closer: the seeds are the second show.",
		"winter": "Winter's for writing up the year's notes: page after page of birds and blooms, and still not everything.",
		"rain": "Rain! The ferns will be beside themselves tomorrow.",
		"snow": "Under all that snow the seeds are waiting. They're better at winter than we are.",
		"morning": "Up early! The birds are loudest in the first hour. I count every one I can hear.",
		"evening": "Evening's when the moths come to the flowers. Half the pollinating in this park happens after supper.",
		"places": {
			"yosemite_village": "Every plant in this garden has a label. Visitors read the label, then look at the plant. I'd like it the other way round.",
			"glacier_point": "From Sentinel Dome you can see it all at once: oaks on the Valley floor, pines on the rim, and the high country beyond.",
		},
		"friend": "You've started noticing the small flowers, the ones by the trail that nobody stops for. I can tell.",
		"close": "For twenty years I've written about this park's plants, and hardly anyone asks me a question back. You do.",
		"news": {
			"climb": "You climbed %s? Did you see what grows in the cracks up there? Next time, look.",
			"sighting": "You saw %s! Write down the time and the place, please. One good record is worth ten good stories.",
		},
		"loved": "Oh, you've been foraging carefully, I can tell. Thank you!",
	},
	"royal_robbins": {
		"spring": "Spring's when everybody's eager and nobody's fit. Climb something easy, and climb it well.",
		"summer": "Midsummer's too hot for the walls. I'll be up in the high country, or reading in the shade.",
		"fall": "Fall is wall season: cool rock and long dry weeks. That's when the big ones go.",
		"winter": "Winter's good for thinking. What you climb matters less than how you climb it.",
		"rain": "A rain day. Good for reading, and for arguing about ethics over coffee.",
		"snow": "Snow on the walls means wet rock for days. Patience is part of style, too.",
		"morning": "The best climbing is done before anyone else is awake.",
		"evening": "I like to look up at the walls at dusk and trace the lines I haven't climbed yet.",
		"friend": "You climb with care. You place, you test, you clean. I've noticed.",
		"close": "Most of what I know about climbing I learned from the people I climbed with. Thanks for listening.",
		"news": {
			"climb": "%s. How did you climb it? That's always my first question.",
		},
		"loved": "Thank you. That's a thoughtful choice.",
	},
	"john_salathe": {
		"spring": "Spring, the cracks run with water. Wait a week, ja? The rock will thank you.",
		"summer": "Summer on the Sentinel is an oven. In '50 we had almost no water. Bring more than you think.",
		"fall": "Good season for steel. Cool air, and the forge burns clean.",
		"winter": "In winter I forge. A hundred pitons for the spring, and I test every one.",
		"rain": "Rain! A good day for the forge, not for the rock.",
		"snow": "Snow on the walls. The steel doesn't mind the cold. The fingers mind.",
		"places": {
			"degnans_bakery": "Every morning, Mrs. Degnan's bread. A man can live on good bread and good steel, ja.",
			"camp_4_fire": "The young ones tell big stories at the fire. I listen. Sometimes the stories are even true.",
		},
		"friend": "You drive a piton like you're listening to it. Good. Steel tells you when it's right.",
		"close": "In Switzerland I was a blacksmith. Here I am a blacksmith who climbs. This is better, I think.",
		"news": {
			"climb": "%s! Ja, good. Did the steel hold? Of course it held.",
		},
		"loved": "Ah, very good. Thank you, my friend.",
	},
	"warren_harding": {
		"spring": "Spring. Time to look at El Cap and pretend I'm not already planning something foolish.",
		"summer": "Too hot for the big walls. Summer's for lying in the meadow and staring up at them.",
		"fall": "We finished the Nose in November: freezing cold, drilling bolts up the last headwall all night long.",
		"winter": "Winter's for telling the El Cap story to anybody who'll pour the wine.",
		"rain": "Rain? Good. Nobody's climbing anything I haven't climbed.",
		"snow": "Snow on El Cap. Some fool will try it anyway. I'd lend them a rope.",
		"morning": "Morning's overrated. The wall will still be there at noon.",
		"evening": "Evening in the meadow, watching the climbers' lights come on up the wall. Best show in the Valley.",
		"friend": "You're all right, you know that? Most people think I'm crazy. You only think I'm a little crazy.",
		"close": "People say siege climbing like it's an insult. We were just stubborn. You're stubborn too. I like that.",
		"news": {
			"climb": "Heard you got up %s. Good for you. Go celebrate, you've earned it.",
		},
		"loved": "Now we're talking! You're a friend for life.",
	},
	"beverly_johnson": {
		"spring": "Spring storms can still roll in. Watch the sky before you commit to a wall.",
		"summer": "Summer on a big wall means hauling water. A gallon a day, and you'll still be thirsty.",
		"fall": "Fall's the season for the big walls: cool nights, dry rock, and the crowds have gone home.",
		"winter": "Winter I work, save up and plan. The wall is patient, so I try to be.",
		"rain": "Rain on a portaledge fly. You lie there and listen, and you learn a lot about yourself.",
		"snow": "Snow up high, and nobody on the wall. It's the only day El Cap is really quiet.",
		"morning": "On a wall I wake at first light, check my anchors, then check them again. Old habits.",
		"evening": "Evening's the best hour on a wall. The rock warms up, the swifts come out and the Valley goes blue.",
		"friend": "You're one of the steady ones. I'd share a wall with you.",
		"close": "Being alone up there taught me what I can do. Being down here with friends reminds me why I bother.",
		"news": {
			"climb": "%s? Nice. Did you count your food and water twice, like I told you?",
		},
		"loved": "Oh, perfect wall food! Thank you.",
	},
	"john_muir": {
		"spring": "The snow's going off the meadows and every rill is singing. It's the best music in the Sierra.",
		"summer": "Summer in the high country! Every meadow is a garden. I could botanize here for a hundred years.",
		"fall": "The aspens are turning gold on the slopes. The year is gathering its harvest home.",
		"winter": "In winter the high country belongs to the snow and the nutcrackers. We're only visitors here.",
		"rain": "A storm! Come out and see it. You never really see a storm from inside a house.",
		"snow": "Snow on the domes! I'd climb a tree to watch it come down, if you'd hold my tea.",
		"morning": "Up with the sun! The light on Cathedral Peak this morning would make a stone sing.",
		"evening": "The alpenglow on the peaks. I've seen it a thousand times, and I'd walk a thousand miles for one more.",
		"friend": "You walk like a mountaineer now: slow and steady, and looking at everything.",
		"close": "Most people come to the mountains to get something. You come to see them. That's the best reason there is.",
		"news": {
			"climb": "%s! And what did you see from the top? That's the part that matters.",
			"sighting": "You saw %s! Wonderful. Every creature up here is a word in the mountains' book.",
		},
		"loved": "Ah, mountaineer's fare! You've been listening. Thank you.",
	},
	"wren_alvarez": {
		"spring": "Spring on the Apron! The slabs are dry, the dogwoods are out, and I'm late back from lunch again.",
		"summer": "Too hot for slab after ten. The rubber gets greasy and my shoes turn into frying pans.",
		"fall": "Fall friction! Cool rock and sticky rubber. I'd climb all day if Marty let me.",
		"winter": "Winter in the shop is all re-soling shoes and untangling rental ropes. I dream about slab.",
		"rain": "Rain day. Marty says I can reorganize the carabiners. By color. Again.",
		"snow": "Snow on the Apron. I keep staring at it like it'll melt faster if I really concentrate.",
		"morning": "Morning! I already did two laps on Firefall Slab. Don't tell Marty, I'm supposed to be opening.",
		"places": {
			"shop_door": "Lunch break! Officially it's an hour. Unofficially it's however long the next slab takes.",
			"plaza": "Evenings on the plaza are the best. Everybody's back from somewhere and everybody's got a story.",
		},
		"friend": "When I came here I didn't know anybody. Now I know you. That's a pretty good start.",
		"close": "If I ever climb El Cap, I want you on the other end of the rope. Just so you know.",
		"news": {
			"climb": "You sent %s?! I'm telling everyone I taught you. I'm going to keep doing that forever.",
			"rescue": "Jo says you found %s! That's so cool. Way cooler than selling chalk bags.",
			"fish": "Somebody said you landed %s! Is fishing just slab climbing for people who like water?",
			"sighting": "You saw %s? Where? I've been here a whole season and the best I've seen is a really big squirrel.",
		},
		"loved": "Oh my gosh, yes! That's my favorite! Thank you!",
	},
	"ahwahnee_chef": {
		"spring": "Morels come up in spring where the ground burned the year before. I pay well for a basket, and I ask no questions.",
		"summer": "In summer the guests want everything cold: cold soup, cold trout, cold wine. I sweat over a hot stove to make it.",
		"fall": "Fall is the best season for a cook: mushrooms, berries, and the last apples from the old orchard.",
		"winter": "A fire in every hearth and soup in every bowl. Winter at the Ahwahnee is when I'm happiest.",
		"rain": "Rain! The mushrooms will be up by the weekend.",
		"snow": "Snow outside and ninety degrees in my kitchen. I'm the only man in the Valley who's warm.",
		"morning": "I've already walked the meadow, scolded the baker and burned my thumb. A normal morning.",
		"evening": "Dinner service in an hour. The dining room is beautiful and the kitchen is chaos. That's the way it should be.",
		"friend": "You eat well, and you notice what you eat. You'd make a decent cook.",
		"close": "In San Francisco I cooked for people who wanted to be seen. Here I cook for people who've walked all day. It's better.",
		"news": {
			"climb": "%s, I hear! You must be starving. Climbers always are.",
			"fish": "You caught %s? Bring me the next one, and I'll show you what a trout is for.",
		},
		"loved": "Ah! Now this is an ingredient. Thank you, truly.",
	},
	"mountain_shop": {
		"spring": "Spring rush. Everybody wants new shoes, and nobody wants to break them in.",
		"summer": "Summer's busy. Half my customers want rope, half want directions, and one wants to know where the bears are.",
		"fall": "Fall's for the serious climbers. They don't browse. They come in with a list.",
		"winter": "Winter's slow. I count the cams, then I count them again, then I re-tape the price tags.",
		"rain": "Rainy day. Everybody comes in to stay dry, so I might as well sell them something.",
		"snow": "Snow day. Wren's at the window staring at the Apron like it owes her money.",
		"morning": "Morning. Coffee's on in the back. It's not for sale. It's for friends.",
		"evening": "Closing up soon. After six I'm a climber, not a clerk.",
		"friend": "You're a regular now. Regulars get the good advice for free.",
		"close": "I took this job so I'd never have to leave the Valley. Customers like you make it the right call.",
		"news": {
			"climb": "Heard you ticked %s. Your guidebook's going to need more pages.",
			"rescue": "The rescue team came in for tape. They said you found %s. Nice work.",
		},
		"loved": "Hey, now. That's better than a sale. Thanks.",
	},
	"greg": {
		"spring": "Spring runoff's got the Merced high and muddy. Fish the edges, where the water's slow.",
		"summer": "In summer the river runs low and clear. The trout can see you coming a mile off, so sneak.",
		"fall": "Fall's the best. The browns get hungry and a little careless. My favorite kind of fish.",
		"winter": "In winter the fish go deep and slow, and so do I. I tie flies by the stove.",
		"rain": "A little rain puts the bugs on the water and the fish on the bugs. Grab your rod.",
		"snow": "Snow on the river. Too cold for the fish to bother, and too cold for me.",
		"places": {
			"river_bank": "Shh. See that ring on the water by the boulder? That's a trout eating. Watch for the next one.",
			"pool_side": "I come by the pool to dry my waders. The lifeguard hates it. The waders love it.",
		},
		"friend": "You're getting a nice drift on your fly. I can tell from here.",
		"close": "I've fished a lot of rivers. If I could only keep one, it'd be the Merced. Glad you're on it with me.",
		"news": {
			"climb": "%s, huh? You climbers. All that work to get up high, and the fish are all down low.",
			"fish": "%s! Nice. How'd you hook it? No, let me guess: right at dusk.",
		},
		"loved": "Oh, now that's a guide's tip! Thanks, partner.",
	},
	"jo_tolliver": {
		"spring": "Spring's when the snow bridges give way and people go through them. We'll be busy.",
		"summer": "Summer's our busiest season: heat, crowds, and people who think a water bottle is optional.",
		"fall": "Fall's quieter, but the short days catch people out. Carry a light.",
		"winter": "Winter calls are cold and slow. Everybody gets found, but everybody's freezing.",
		"rain": "Rain makes the trails slick and the rock worse. Somebody's going to call today. Stay close.",
		"snow": "Snow holds prints for days. It's the best tracking weather there is.",
		"morning": "Morning. Radio check's done, litters are checked, and my coffee's half gone.",
		"evening": "Evening's when the late calls come in. Somebody's always an hour from the trailhead with no light.",
		"friend": "You're good on a search. You stay calm and you look properly.",
		"close": "Some calls I still think about at night. It helps to know who I'd want beside me. You're on that list.",
		"news": {
			"climb": "%s, eh? Good. Now I know who to call if somebody gets stuck up there.",
			"sighting": "You saw %s? Keep your distance and keep your food packed. That's the whole lecture.",
		},
		"loved": "Rescue rations! Ha. Thank you, really.",
	},
	"mateo_reyes": {
		"spring": "Spring cleaning at the cache: every rope inspected and every litter strap checked.",
		"summer": "In summer we go through first-aid kits faster than the store can stock them. Blisters, mostly.",
		"fall": "Fall's when we retire the tired ropes. Every rope here has its own page in the log.",
		"winter": "In winter the site's half empty. It's just us, the radio, and a lot of snow to shovel.",
		"rain": "Rain day. I'm drying ropes in the tent cabin, and it smells like a wet dog in here.",
		"snow": "Snow's stacking up on the cache roof. I'll shovel it off before it caves in.",
		"morning": "Morning. Coffee's on the stove and the radio's quiet. Let's keep it that way.",
		"evening": "Evening's the hour for stories around the stove. Everybody's got one, and most of them are true.",
		"friend": "You're practically part of the site now. We've started saving you a seat by the stove.",
		"close": "I came here to climb El Cap and stayed for the people. You're one of the reasons.",
		"news": {
			"climb": "Heard you sent %s. Next time, take a yellow shirt so we can find you if you need us.",
			"rescue": "Jo told me about %s. I'll restock everything you used. Good work.",
		},
		"loved": "That's going straight in my pack. Thanks!",
	},
}


## The everyday talk with [param character], for [param speaker]: something
## a close friend saved for you (HeartScenes), news of what you've been up to
## (once), a rare story (CharacterData.rare_lines), or a line that fits the
## day. [param places] are where they're standing (QuestLog.talk_to). Each
## line is marked "everyday". Empty while a heart scene waits: whoever's
## talking plays that instead (NPC, Vendor).
static func talk(character: CharacterData, speaker: String, places := PackedStringArray()) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if character == null or HeartScenes.ready_for(character.id) > 0:
		return lines
	var id := character.id
	var saved := HeartScenes.saved_gift(id, speaker)
	if not saved.is_empty():
		return _everyday(saved)
	var own: Dictionary = {} if id in AWAITING_REVIEW else LINES.get(id, {})
	var news := Friendship.news_for(id, own.get("news", {}).keys())
	if not news.is_empty():
		Friendship.hear_news(id)
		var text: String = own.news[news.kind] % news.what
		return _everyday([{"speaker": speaker, "text": text.left(1).to_upper() + text.substr(1)}])
	var rare_open := character.rare_after_quest == "" or QuestLog.is_completed(character.rare_after_quest)
	var usual := character.idle_lines_for(rare_open)
	var told_last: bool = not character.rare_lines.is_empty() and Friendship.said.get(id, "") == character.rare_lines[-1]
	if not character.rare_lines.is_empty() and usual == character.rare_lines and not told_last:
		for text: String in usual:
			lines.append({"speaker": speaker, "text": text})
		Friendship.said[id] = usual[-1]
		return _everyday(lines)
	var text := pick(character, places)
	if text != "":
		Friendship.said[id] = text
		lines.append({"speaker": speaker, "text": text})
	return _everyday(lines)


## One line from what fits now for [param character] (see [method choices]),
## weighted, and not the line they said last if there's another. [param roll]
## is a random 0 to 1.
static func pick(character: CharacterData, places := PackedStringArray(), roll := randf()) -> String:
	var options := choices(character, places)
	var last: String = Friendship.said.get(character.id, "")
	if options.size() > 1:
		options = options.filter(func(option: Array) -> bool: return option[0] != last)
	var total := 0.0
	for option: Array in options:
		total += float(option[1])
	var at := roll * total
	for option: Array in options:
		at -= float(option[1])
		if at < 0.0:
			return option[0]
	return options.back()[0] if not options.is_empty() else ""


## Every line [param character] might say now, as [text, weight]: theirs
## for the season, today's weather, the hour, [param places] and your
## hearts, and their usual lines.
static func choices(character: CharacterData, places := PackedStringArray()) -> Array:
	var own: Dictionary = {} if character.id in AWAITING_REVIEW else LINES.get(character.id, {})
	var out := []
	var keys := [SEASON_KEYS[GameClock.season]]
	var weather := Weather.today()
	if weather.snow > 0.0:
		keys.append("snow")
	elif weather.rain > 0.0:
		keys.append("rain")
	var hour := GameClock.minutes / 60
	if hour < MORNING_UNTIL and hour >= GameClock.DAY_START_HOUR - 1:
		keys.append("morning")
	elif hour >= EVENING_FROM and hour < NIGHT_FROM:
		keys.append("evening")
	var hearts := Friendship.hearts(character.id)
	if hearts >= FRIEND_HEARTS:
		keys.append("friend")
	if hearts >= CLOSE_HEARTS:
		keys.append("close")
	for key: String in keys:
		var weight: int = WEIGHTS.get("season" if key in SEASON_KEYS else key, 1)
		for text in _texts(own.get(key)):
			out.append([text, weight])
	var at: Dictionary = own.get("places", {})
	for place: String in places:
		if at.has(place):
			out.append([at[place], WEIGHTS.places])
	for text: String in character.idle_lines:
		out.append([text, WEIGHTS.usual])
	return out


## Every line [param character_id] has in LINES, for checking them over.
static func all_lines(character_id: String) -> PackedStringArray:
	var own: Dictionary = LINES.get(character_id, {})
	var out := PackedStringArray()
	for key: String in own:
		if key == "news" or key == "places":
			for sub: String in own[key]:
				out.append(own[key][sub])
		else:
			out.append_array(_texts(own[key]))
	return out


## Their own thanks for a gift they love, or "".
static func loved_line(character_id: String) -> String:
	return "" if character_id in AWAITING_REVIEW else LINES.get(character_id, {}).get("loved", "")


## A line or a list of lines, as a list.
static func _texts(value: Variant) -> PackedStringArray:
	if value is String:
		return PackedStringArray([value])
	if value is Array or value is PackedStringArray:
		return PackedStringArray(value)
	return PackedStringArray()


static func _everyday(lines: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in lines:
		var marked := line.duplicate()
		marked["everyday"] = true
		out.append(marked)
	return out
