class_name HeartScenes
extends RefCounted
## What a friend shares with you, once each, as you come to know them: a
## scene at 3 hearts and another at 5 (Friendship). They tell you something
## about their life, ask you something (what you say is up to you, and they
## answer it), and give you a little something. After the 5-heart scene,
## they save you something every SAVE_EVERY days, given the next time you
## talk (SmallTalk).
##
## A heart in their bubble (QuestMarker) says a scene is waiting. They share
## it the next time you talk with them and there's nothing else to say: no
## quest, no news of the story (NPC, Vendor).
##
## For historical people the scenes keep to what's on the record of their
## lives and work, as the rest of their lines do; the invented staff's are
## freer. The Native characters' scenes wait on the tribes' next review
## (SmallTalk.AWAITING_REVIEW), so they have none yet.

## The hearts each scene comes at, in order.
const LEVELS := [3, 5]
## Days between the things a close friend saves for you.
const SAVE_EVERY := 7

## Each person's scenes by hearts: "lines" (theirs), "ask" (their question)
## and "options" (what you can say), "replies" (theirs, one per option),
## "end" (their last word), and what they give you: "gift" (item id ->
## count) and "gear" (gear id -> count). A 5-heart scene also has "saves"
## (the item ids they take turns saving for you) and "saved" (what they say
## when they hand one over).
const SCENES := {
	"galen_clark": {
		3: {
			"lines": [
				"Sit a moment, if you've time. Do you know what a guardian does all day?",
				"Mostly it's fences, roads and complaints. Somebody's cows in the meadow. Somebody's hotel in the wrong place.",
				"But now and then someone stops at the gate just to say the valley looks fine today. Those are the days I remember.",
			],
			"ask": "If it were up to you, what would you look after first?",
			"options": ["The big trees", "The meadows", "The people here"],
			"replies": [
				"The Grove, then. They've stood for thousands of years. All they need from us is to be let be.",
				"Good. The meadows fed people here long before the hotels came. Mind them, and they'll mind you.",
				"Ha! That's the hardest one, and the one nobody writes into the job. You'd do well at it.",
			],
			"end": "Here, take some of my tea for the road. It grows down by the creek.",
			"gift": {"yerba_buena_tea": 2},
		},
		5: {
			"lines": [
				"I'll tell you something I don't tell the visitors. When I came to these mountains, the doctors had given me a few months.",
				"Bad lungs, they said. I came up here expecting to be buried under the pines.",
				"Instead I walked. Every day a little farther, and every year a little longer. That was a long time ago now.",
			],
			"ask": "What keeps you walking?",
			"options": ["The view from the top", "The people on the way", "Just the walking"],
			"replies": [
				"A fine reason. But you'll find the best views are halfway up, when you stop to catch your breath.",
				"Yes. You meet the valley's whole history on its trails, if you stop and listen.",
				"Then you've found the secret already. It took me a few months and a doctor's verdict to learn it.",
			],
			"end": "You've been a true friend to an old man. I'll keep something by the gate for you now and then.",
			"gift": {"roasted_morels": 1},
			"saves": ["yerba_buena_tea", "roasted_morels"],
			"saved": "I put this by for you. Don't argue, it's done.",
		},
	},
	"james_lamon": {
		3: {
			"lines": [
				"My first winter here, I was the only one in the valley who stayed. Me and the apple trees.",
				"I got so lonesome I took to talking to them. Told them the news, such as it was.",
				"Come spring, the first fellow up the trail asked if I'd gone mad. I said no, but the trees had some opinions.",
			],
			"ask": "Do you ever talk to trees?",
			"options": ["Every day", "Only when nobody's looking", "Not yet"],
			"replies": [
				"Good. They're fine listeners, and they never interrupt.",
				"That's how it starts. Next thing you know, you're asking their advice on the weather.",
				"Give it a winter. You'll come round.",
			],
			"end": "Take some of last year's apples. I dried them myself.",
			"gift": {"dried_apples": 2},
		},
		5: {
			"lines": [
				"You've been a good neighbor. Better than the deer, anyway.",
				"People ask why I stayed when everybody else went down the mountain for the winter. I never had a good answer.",
				"I think it's that the valley's different when it's empty. Quieter. It sounds like it's breathing.",
			],
			"ask": "Would you ever stay a winter?",
			"options": ["In a heartbeat", "With enough apples", "I'd miss people"],
			"replies": [
				"Then you're as stubborn as me. Bring a good coat.",
				"Ha! That's the right answer. Never winter without a full cellar.",
				"That's honest. I missed them too. But a winter here teaches you to be glad of every face come spring.",
			],
			"end": "I'll set some apples aside for you from now on. Neighbors do that.",
			"gift": {"bread_pudding": 1},
			"saves": ["dried_apples", "bread_pudding"],
			"saved": "Put some aside for you, like I said I would.",
		},
	},
	"bridget_degnan": {
		3: {
			"lines": [
				"Do you know how all this started? John and I came with not much more than a stove.",
				"I baked a few loaves in our own kitchen for the workmen, and the next morning there were twice as many at the door.",
				"That's the whole secret of a bakery. Feed one person well, and they'll bring you the rest.",
			],
			"ask": "What's the best thing you ever ate?",
			"options": ["Fresh bread, warm", "Something off a campfire", "Anything after a long climb"],
			"replies": [
				"Someone after my own heart. There's nothing finer, and anyone who says different hasn't had it hot.",
				"Ah, smoke and a bit of ash. Some of the best meals I've had were cooked on a stick.",
				"Ha! Hunger's the best cook there is. I just help it along.",
			],
			"end": "Here, a bit of pudding from the apples Mr. Lamon sends down. Don't tell him mine's better than his.",
			"gift": {"bread_pudding": 1},
		},
		5: {
			"lines": [
				"My mother baked for our whole lane, back in Ireland. Anybody hungry knew which door to knock on.",
				"I suppose I'm still trying to be that door.",
				"You've helped me be it, too, bringing folks round and bringing me news. I'm grateful.",
			],
			"ask": "What do you think the Valley needs most?",
			"options": ["More bakeries", "Good neighbors", "Fewer crowds"],
			"replies": [
				"Bite your tongue! One's plenty, and it's mine.",
				"That's it exactly. A valley's only as good as the people in it who look out for each other.",
				"Maybe so. But every one of those crowds is somebody's family on holiday. I'd rather feed them.",
			],
			"end": "Pilot bread for your pack. It keeps forever, which is more than you can say for me. From now on I'll keep something back for you.",
			"gift": {"pilot_bread": 3},
			"saves": ["pilot_bread", "bread_pudding"],
			"saved": "I kept this back for you. Go on, take it before John eats it.",
		},
	},
	"dick_leonard": {
		3: {
			"lines": [
				"Can I tell you the thing I'm proudest of? It isn't a summit.",
				"It's the belay. In the early days a falling climber got stopped short, and a stop like that can break a rope, or a back.",
				"We taught people to let the rope run a little and catch the fall gently, like catching an egg. A lot of climbers are still climbing because of it.",
			],
			"ask": "What makes a good climbing partner?",
			"options": ["Someone who never falls", "Someone who catches you", "Someone who makes you laugh"],
			"replies": [
				"Ha! Nobody never falls. The ones who say so just haven't yet.",
				"Exactly right. The summit's the reward. The partner's the reason you got there.",
				"That too. A long day on rock goes better with a good laugh at the belay.",
			],
			"end": "Here, something for your pack. Climbers run on the stuff.",
			"gift": {"trail_mix": 2},
		},
		5: {
			"lines": [
				"I've spent a good part of my life arguing for wild places, in meetings and in courtrooms.",
				"Climbing taught me the rock doesn't care about any of that. It only asks whether you're paying attention.",
				"You pay attention: to the rock, and to the person on the other end of the rope. Don't ever stop.",
			],
			"ask": "Why do you climb?",
			"options": ["For the view", "For the friends", "To see if I can"],
			"replies": [
				"A good reason. The view from a ledge you worked for beats any postcard.",
				"The best reason, if you ask me. Mountains last, and so do the friendships you make on them.",
				"That's how it starts for most of us. Then one day you find you'd go up anyway, just to be there.",
			],
			"end": "I'll keep a bag of something for you at Swan Slab from now on. Holler when you're by.",
			"gift": {"beef_jerky": 2},
			"saves": ["trail_mix", "beef_jerky"],
			"saved": "Here, I put this aside for you. A climber's lunch.",
		},
	},
	"jules_eichorn": {
		3: {
			"lines": [
				"When I was a boy, Ansel taught me the piano. He was a fine pianist before he was ever a photographer.",
				"He'd tell me not to rush the rests. The silence between the notes is part of the music.",
				"I think about that on every climb. The ledges between the hard parts are part of the climb, too.",
			],
			"ask": "Do you play anything?",
			"options": ["A little", "Not a note", "Only the radio"],
			"replies": [
				"Then keep at it. A little every day is how you learn anything, piano or rock.",
				"That's all right. You climb with rhythm anyway. I've seen it.",
				"Ha! That counts. Music's music, however it gets to you.",
			],
			"end": "Here, share my lunch. Ansel says I never pack enough. He's wrong: I pack exactly enough for two.",
			"gift": {"chocolate_bar": 1},
		},
		5: {
			"lines": [
				"The summer we climbed the Spire, I was twenty-two. I thought it was the hardest thing I'd ever do.",
				"Then I spent my life teaching music to children, and found out that was harder, and better.",
				"Climbing and teaching are the same thing, really. You show someone a way up, and then you let them go first.",
			],
			"ask": "Who taught you the most?",
			"options": ["A teacher", "A friend", "The mountains"],
			"replies": [
				"Then you were lucky, the way I was with Ansel. Go and thank them, if you can.",
				"Friends are the best teachers. They don't know they're teaching, so they never stop.",
				"They're patient, and they never lie to you. The best teachers I know.",
			],
			"end": "From now on I'll save a share of my lunch for you. Teachers always pack extra.",
			"gift": {"trail_mix": 2},
			"saves": ["chocolate_bar", "trail_mix"],
			"saved": "I packed extra again. This half is yours.",
		},
	},
	"bestor_robinson": {
		3: {
			"lines": [
				"Would you like to see my notebook? Every climb since the early thirties, and everything we carried.",
				"Here's the Spire: every piton we took, every one we used, and a note at the bottom that says more water next time.",
				"People laugh at the lists. Nobody laughs when the list is what gets them home.",
			],
			"ask": "Are you a planner?",
			"options": ["Always", "Sometimes", "I just go"],
			"replies": [
				"Splendid! We'll get along famously. Bring your lists, and I'll bring mine.",
				"That's honest. Plan the big days, and let the small ones surprise you.",
				"Then you'd better have friends who plan. Fortunately, you have one now.",
			],
			"end": "Take some cheese for the trail. It's on the list.",
			"gift": {"cheddar_wedge": 1},
		},
		5: {
			"lines": [
				"When we planned the Spire, I wrote everything down: ropes, pitons, food, water, the hour we'd turn back.",
				"There was one thing I couldn't put on a list, and it mattered most: who was on the other end of the rope.",
				"Dick and Jules were the best plan I ever made. You'd have made the list too.",
			],
			"ask": "What's the most important thing to bring on a climb?",
			"options": ["Enough water", "A good partner", "A way down"],
			"replies": [
				"Ha! Spoken like someone who's been thirsty on a wall. Quite right.",
				"That took me twenty years to learn, and you have it already.",
				"The most overlooked thing on any list. A planner after my own heart.",
			],
			"end": "I've put you on my list at the trailhead. There'll be something for you there now and then.",
			"gift": {"pilot_bread": 3},
			"saves": ["cheddar_wedge", "pilot_bread"],
			"saved": "It was on the list: something for you. Here.",
		},
	},
	"jennie_curry": {
		3: {
			"lines": [
				"When David and I opened the camp, we had a handful of tents and a dining fly. People said we'd be broke by August.",
				"We kept the price low, meals and all, so working families could come. Nobody thought it would last.",
				"It's still here. And so am I.",
			],
			"ask": "What makes a good camp?",
			"options": ["A good bed", "Good food", "Good company"],
			"replies": [
				"A clean bed after a long day. You'd be amazed what people will forgive for that.",
				"Now you sound like David. He'd have kept the kitchen open all night if I'd let him.",
				"That's the real secret. The tents are only canvas. It's the people that make it a camp.",
			],
			"end": "Take some greens from the kitchen. They're good for you, so don't make a face.",
			"gift": {"spring_greens": 1},
		},
		5: {
			"lines": [
				"After David died, everybody expected me to sell. A widow running a place this size? Unthinkable, they said.",
				"I ran it for years more. They started calling me Mother Curry, and I decided I liked it.",
				"You've been a great help to this camp. Consider yourself family. Family always eats.",
			],
			"ask": "What would you have done?",
			"options": ["Kept the camp", "Sold it and rested", "Asked for help"],
			"replies": [
				"Of course you would. I could tell the first time you walked onto my porch.",
				"And missed all this? No. Resting's for after.",
				"Ha! The smart answer, and the one I learned last. I had good help, in the end.",
			],
			"end": "I'll keep a plate back for you from now on. Family always eats at Camp Curry.",
			"gift": {"bread_pudding": 1},
			"saves": ["spring_greens", "bread_pudding"],
			"saved": "I kept a plate back for you, like I promised.",
		},
	},
	"george_anderson": {
		3: {
			"lines": [
				"Want to hear how I got up the Dome? Everybody does, so I've got it polished.",
				"I drilled a hole in the granite and drove in an iron eyebolt. Stood on it, drilled the next. A few feet at a time.",
				"It took days. Folks down in the valley thought I'd gone mad. Maybe I had, but I got to the top.",
			],
			"ask": "Would you have tried it?",
			"options": ["Absolutely", "With your iron, maybe", "Not a chance"],
			"replies": [
				"Ha! That's the spirit. A bit of mad in you, like me.",
				"Smart. Never climb a mountain without good iron and a good blacksmith.",
				"Honest, at least. Most folks say yes and then go white at the first bolt.",
			],
			"end": "Here's something to chew on the trail. Iron for the belly.",
			"gift": {"beef_jerky": 2},
		},
		5: {
			"lines": [
				"I'll tell you the part I don't tell the tourists. When I got to the top of the Dome, there was nobody to tell.",
				"Just me and the wind and a long way down. I stood there and laughed like a fool.",
				"Then I thought: I'll put a rope on it, so others can come up. That's the bit I'm proud of. Not the top. The rope.",
			],
			"ask": "Which is better: getting there first, or showing others the way?",
			"options": ["Getting there first", "Showing the way", "Going together"],
			"replies": [
				"It's a fine feeling, I'll not lie. But it only lasts the one afternoon.",
				"Aye. The top was mine for a day. The rope's been everybody's ever since.",
				"Best answer of all. I'd have liked some company up there.",
			],
			"end": "I'll keep some trail food at the forge for you from now on. A friend of the Dome's a friend of mine.",
			"gift": {"pilot_bread": 3},
			"saves": ["beef_jerky", "pilot_bread"],
			"saved": "Kept this by the anvil for you. Still warm from the forge, nearly.",
		},
	},
	"clare_hodges": {
		3: {
			"lines": [
				"Do you know how I got this job? It was 1918, and half the young men had gone to the war.",
				"I walked into the superintendent's office and asked for it. He looked at me a long while, then gave me a horse.",
				"I've had a horse and a hat ever since, and a lot of people surprised to be taking directions from me.",
			],
			"ask": "Would you wear the hat?",
			"options": ["In a heartbeat", "If I got the horse too", "It's not my style"],
			"replies": [
				"Good. The hat's the easy part. It's the listening that makes a ranger.",
				"Ha! Fair enough. The horse is the best part of the job.",
				"That's fine. You do the work anyway, hat or no hat.",
			],
			"end": "Here, some tea from the station garden. It's good on patrol.",
			"gift": {"yerba_buena_tea": 1},
		},
		5: {
			"lines": [
				"Some people still stop me on the trail to ask where the real ranger is. I tell them they're looking at her.",
				"I don't mind. Every one of them goes home knowing a woman can do this job. That's worth a few odd looks.",
				"Someday there'll be women rangers in every park in the country. I hope they'll know somebody went first.",
			],
			"ask": "What should a ranger care about most?",
			"options": ["The animals", "The visitors", "The land itself"],
			"replies": [
				"They can't speak up for themselves, so somebody has to. Good answer.",
				"They're why the park exists, and they're the ones most likely to get lost. Good answer.",
				"Look after the land and the rest follows. That's the best answer I know.",
			],
			"end": "I'll leave something for you at the station from time to time. Rangers look after their own.",
			"gift": {"spring_greens": 1},
			"saves": ["yerba_buena_tea", "spring_greens"],
			"saved": "Left this at the station for you. Rangers look after their own.",
		},
	},
	"ansel_adams": {
		3: {
			"lines": [
				"Do you want to know a secret about the Monolith picture? I almost didn't get it.",
				"I'd hauled the heavy camera up to the Diving Board and had two plates left. I spent one on the ordinary view.",
				"For the last plate I put on a red filter, to darken the sky the way it felt to me. That was the one. I had to see it before I could take it.",
			],
			"ask": "What would you photograph?",
			"options": ["Half Dome", "The people here", "Something small"],
			"replies": [
				"A good choice, but be warned, it's been done. Find your own way of seeing it.",
				"More people should. I mostly leave them out, and I'm starting to think that's a mistake.",
				"The small things are the hardest. A leaf, a stone. You have to really look.",
			],
			"end": "Here, take a chocolate bar. Darkroom rations. Don't tell Virginia I keep a stash in the studio.",
			"gift": {"chocolate_bar": 1},
		},
		5: {
			"lines": [
				"I've been thinking about what I'll leave behind. Not the prints, though I've worked hard on them.",
				"What I want is for people to come here a hundred years from now and find it as wild as it is today.",
				"The photographs are only a way of asking people to care. You don't need a camera for that. You already do it.",
			],
			"ask": "How should the Valley be remembered?",
			"options": ["Exactly as it is", "Through its people", "By coming back"],
			"replies": [
				"Then help keep it that way. That's a bigger job than any photograph.",
				"Yes. I've spent my life leaving people out of the frame, and they were the story all along.",
				"The best answer. A place is remembered by the people who keep coming home to it.",
			],
			"end": "I'll set something aside at the studio for you now and then. A thank-you, from one looker to another.",
			"gift": {"dried_apricots": 2},
			"saves": ["chocolate_bar", "dried_apricots"],
			"saved": "I put this aside at the studio for you. Darkroom rations.",
		},
	},
	"james_mccauley": {
		3: {
			"lines": [
				"Do you know what folks said when I started cutting the Four Mile Trail? That I'd never get a mule up it, let alone a lady in a long skirt.",
				"Well, I got both up it, and charged them a toll for the privilege.",
				"The mules didn't think much of the toll. The ladies didn't either, but they paid it, for that view.",
			],
			"ask": "Is a view worth paying for?",
			"options": ["Every penny", "It should be free", "Depends on the view"],
			"replies": [
				"A sensible person! I knew I liked you.",
				"You and half the valley. Maybe you're right. Don't tell the toll box.",
				"Fair. This one's worth it, I promise you.",
			],
			"end": "Here, a bit of cheese from the Mountain House kitchen. Paid for with tolls, so it's half yours.",
			"gift": {"cheddar_wedge": 1},
		},
		5: {
			"lines": [
				"About the Firefall. You've heard folks tell it different ways, and I let them.",
				"The way I tell it, it started with a campfire and a bit of showing off, and it grew into something people cross the country to see.",
				"That's most good things, I think. Somebody does something small, and other folks love it into something bigger.",
			],
			"ask": "What small thing would you start?",
			"options": ["A trail", "A tradition", "A good story"],
			"replies": [
				"Ha! Mind the switchbacks, and charge a fair toll.",
				"Then start it, and let other folks carry it on. That's how the Firefall did it.",
				"The best kind. A story costs nothing, and it never wears out.",
			],
			"end": "I'll keep something by for you at the Mountain House from now on. Toll-free, for a friend.",
			"gift": {"bread_pudding": 1},
			"saves": ["cheddar_wedge", "bread_pudding"],
			"saved": "Kept this by for you at the Mountain House. Toll-free.",
		},
	},
	"enid_michael": {
		3: {
			"lines": [
				"When I started as a naturalist, some of the men thought I'd stick to pressing pretty flowers.",
				"So I learned every bird song, every grass and every lichen I could find, and I wrote it all down, week after week.",
				"Nobody asks me if I'm sure anymore. They just ask me what it is.",
			],
			"ask": "What's your favorite plant in the park?",
			"options": ["Something with flowers", "Something you can eat", "The big trees"],
			"replies": [
				"A fine choice. Just remember the bees saw them first.",
				"A forager! Know it before you pick it, and never take the last one.",
				"Everyone's favorite. Next time, look at the little things growing round their feet, too.",
			],
			"end": "Here, miner's lettuce from the garden. I grow it so nobody's tempted to pick the wild patch bare.",
			"gift": {"miners_lettuce": 2},
		},
		5: {
			"lines": [
				"I've written hundreds of nature notes for this park. Most people read one once and throw it away.",
				"That's all right. A note isn't meant to last. It's meant to make someone look up, just once, and see the bird.",
				"You look up. You always do. That's the best thing anyone has ever done with my notes.",
			],
			"ask": "What should everyone learn about the park?",
			"options": ["The names of things", "How to leave things be", "How to look closely"],
			"replies": [
				"Names are a start. Every plant here had a name long before mine, remember.",
				"The hardest lesson, and the most important. Leave some behind.",
				"That's the whole of natural history, really. The rest is only writing it down.",
			],
			"end": "I'll keep something from the garden for you now and then. A botanist's thank-you.",
			"gift": {"sierra_onion": 2},
			"saves": ["miners_lettuce", "yampah", "sierra_onion"],
			"saved": "From the garden, for you. I picked it carefully.",
		},
	},
	"royal_robbins": {
		3: {
			"lines": [
				"When we climbed the face of Half Dome in '57, we drove pitons the whole way. That was how it was done.",
				"Years later you could see the scars all over the Valley, in every crack where pitons had gone in and out. I didn't like it.",
				"So now I climb with nuts, and I take everything out behind me. The rock should look as if nobody passed.",
			],
			"ask": "How do you like to climb?",
			"options": ["Fast", "Clean", "Any way I can"],
			"replies": [
				"Fast is fine, if you're careful. Just don't let speed make your choices for you.",
				"Good. Then the next party gets the same climb you had.",
				"Honest. Someday you'll care how. Everyone who keeps climbing does.",
			],
			"end": "Here. Dried apricots, the best wall food there is. Don't let Warren tell you it's wine.",
			"gift": {"dried_apricots": 2},
		},
		5: {
			"lines": [
				"I wrote a little book about rockcraft a while ago. People expected rules. Mostly it's about judgment.",
				"Every climb asks you questions. Can I protect this? Should I go on? Is it worth the mark it leaves?",
				"You ask those questions well. I'd trust you on a rope, and I don't say that lightly.",
			],
			"ask": "What's the most important thing a climber carries?",
			"options": ["Good judgment", "The right gear", "A sense of humor"],
			"replies": [
				"That's the whole book in two words. You could have saved me the writing.",
				"Gear matters. But the best rack in the world won't think for you.",
				"Ha. Yes. Especially on a wall with Warren Harding.",
			],
			"end": "I'll leave something at the desk for you now and then. Wall food, for a friend.",
			"gift": {"trail_mix": 2},
			"saves": ["dried_apricots", "trail_mix"],
			"saved": "I left this at the desk for you. Wall food.",
		},
	},
	"john_salathe": {
		3: {
			"lines": [
				"You want to know how I make the pitons? Ja, it is no secret.",
				"The soft iron ones from Europe bent in these hard cracks. So I took the steel from an old Ford axle and forged it.",
				"Hard steel rings when you drive it, like a bell. You hear it, and you know it is good.",
			],
			"ask": "Do you make things with your hands?",
			"options": ["Whenever I can", "I'd like to learn", "I mostly break them"],
			"replies": [
				"Good. A thing you make yourself, you trust.",
				"Then come to the forge sometime and I will show you. It is hot, but it is honest.",
				"Ha! Ja, me too, when I started. Breaking is the first lesson.",
			],
			"end": "Here, cheese. A blacksmith needs his strength.",
			"gift": {"cheddar_wedge": 1},
		},
		5: {
			"lines": [
				"When I came to this Valley, I was almost fifty. Everybody said I was too old to start climbing.",
				"But the rock does not ask how old you are. It asks only if you are honest with it.",
				"You are honest with the rock, and with people. This is rare. I am glad to know you.",
			],
			"ask": "Is it ever too late to start something?",
			"options": ["Never", "Sometimes", "Ask me in fifty years"],
			"replies": [
				"Ja! Never. I am the proof.",
				"Maybe sometimes. But not for climbing, and not for friends.",
				"Ha! Good answer. In fifty years, I will ask.",
			],
			"end": "From now on I keep something for you at the forge. A friend's share.",
			"gift": {"miners_lettuce": 2},
			"saves": ["cheddar_wedge", "miners_lettuce"],
			"saved": "From the forge, for you. A friend's share, ja.",
		},
	},
	"warren_harding": {
		3: {
			"lines": [
				"You want to hear about the Nose? Everybody does. Forty-seven days on the wall, spread out over a year and a half.",
				"We'd fix ropes, go down, come back, push a little higher. The rangers hated it: traffic jams in the meadow every weekend.",
				"The last night we drilled bolts up the final headwall in the dark, and topped out at dawn. I wasn't sure if I'd beaten El Cap or it had beaten me.",
			],
			"ask": "Would you spend a year and a half on one climb?",
			"options": ["If it was the right climb", "No, I'd go fast", "Only with good company"],
			"replies": [
				"Then you understand. Some walls you don't climb, you court.",
				"Ha! That's what the young ones all say. Then they meet El Cap.",
				"That's the real secret. You can stand anything with the right crew.",
			],
			"end": "Here, have some cider. To the Nose.",
			"gift": {"manzanita_cider": 1},
		},
		5: {
			"lines": [
				"People call me a lot of things. Reckless. A clown. A vandal, Royal says, on a bad day.",
				"Maybe. But I climbed what I wanted, the way I wanted, and I never once pretended to be somebody else.",
				"You're like that too, I think. Don't let anybody talk you out of it.",
			],
			"ask": "What do you want people to say about you?",
			"options": ["That I was brave", "That I was kind", "That I had fun"],
			"replies": [
				"Brave's good. Brave and a bit foolish is better. More stories.",
				"Kind. Huh. That's a better answer than mine. Don't tell anybody I said so.",
				"Now that's the right answer. If it isn't fun, why are you on the wall?",
			],
			"end": "I'll keep a bottle back for you now and then. Cider, don't worry.",
			"gift": {"chocolate_bar": 1},
			"saves": ["manzanita_cider", "chocolate_bar"],
			"saved": "Kept this back for you. To the Nose, and whatever's next.",
		},
	},
	"beverly_johnson": {
		3: {
			"lines": [
				"When Sibylle and I climbed El Cap together in '73, people kept asking where the men were.",
				"We'd say, we're the climbers. They'd look at us as if we'd said we were the moon.",
				"We topped out anyway. After that, they had to find a new question.",
			],
			"ask": "What would you say to them?",
			"options": ["Nothing, just climb", "Come and see", "We're the climbers"],
			"replies": [
				"That's what we did, mostly. The climb said it for us.",
				"Ha! A few of them did, through binoculars. They changed their tune.",
				"Exactly that. Say it plain, and then go do it.",
			],
			"end": "Here, have some apricots. Wall food. You'll want it.",
			"gift": {"dried_apricots": 2},
		},
		5: {
			"lines": [
				"When I soloed the Dihedral Wall, ten days alone, I had a lot of time to think.",
				"Mostly I thought about the next move. But at night on the portaledge, I'd think about everyone down in the meadow.",
				"It made me want to come down safe. Having people to come down to is everything.",
			],
			"ask": "Who would you come down for?",
			"options": ["My friends", "My family", "Everyone in this valley"],
			"replies": [
				"Good. Hang on to them.",
				"Good. Call them when you get down. They worry.",
				"Ha! That's a lot of people waiting in the meadow. You'd better not dawdle.",
			],
			"end": "I'll keep some wall food for you now and then. Friends share their rations.",
			"gift": {"chocolate_bar": 1},
			"saves": ["dried_apricots", "chocolate_bar"],
			"saved": "Saved you some of my rations. Count them twice.",
		},
	},
	"john_muir": {
		3: {
			"lines": [
				"Did I ever tell you how I first came to these mountains? I walked, of course, most of the way from San Francisco.",
				"I asked a man the quickest way out of town. He asked where I wanted to go. Anywhere that is wild, I said.",
				"That was the best direction anyone ever gave me.",
			],
			"ask": "Where would you go, if you could go anywhere wild?",
			"options": ["Up the highest peak", "Down to the sea", "Right here"],
			"replies": [
				"Then go, and take a crust of bread. The peaks will feed the rest of you.",
				"The sea's wild in its own way. I'm fonder of glaciers, which are only rivers that took their time.",
				"A wise choice. You could spend a whole life in this one range and never see it all. I mean to try.",
			],
			"end": "Here, share my tea. It's good for long walks and long talks.",
			"gift": {"yerba_buena_tea": 2},
		},
		5: {
			"lines": [
				"People think I came to the mountains to get away from people. That isn't so.",
				"I came to learn, and the best of what I learned I wanted to give away. That's why I write.",
				"But you can't give away a mountain in a book. You have to bring people here one at a time and let them see. You've done that.",
			],
			"ask": "What would you tell someone seeing the mountains for the first time?",
			"options": ["Look up", "Slow down", "Keep a notebook"],
			"replies": [
				"Yes! And then look down, at the flowers. The mountains are in both places.",
				"Yes. The mountains are in no hurry, and neither should we be.",
				"Good. Write down what you see, and what you feel. The second fades faster.",
			],
			"end": "I'll leave something at the trailhead for you now and then: a crust for the trail, from one walker to another.",
			"gift": {"dry_crusts": 3},
			"saves": ["dry_crusts", "yerba_buena_tea"],
			"saved": "I left this at the trailhead for you. Bread and tea, the mountaineer's whole kitchen.",
		},
	},
	"wren_alvarez": {
		3: {
			"lines": [
				"Can I tell you something embarrassing? My first week here, I almost quit.",
				"I didn't know anybody, Marty kept giving me the worst rental shoes to clean, and every climber I met had done ten routes I'd never heard of.",
				"Then you showed up looking for a partner. Now I've got a friend and a belay partner. Best week ever, after that.",
			],
			"ask": "Did you ever feel like that here?",
			"options": ["Totally", "A little", "Never, I love it here"],
			"replies": [
				"Right?! It's so big here. Everybody looks like they've been here forever.",
				"It gets better. Especially if you have someone to climb with. Hint, hint.",
				"Show-off. ...No, that's great. I'm glad.",
			],
			"end": "Here, have some of my trail mix. I picked out the raisins, but there are still some in there.",
			"gift": {"trail_mix": 2},
		},
		5: {
			"lines": [
				"So, I applied to guide for the climbing school next season. Like, actually applied. With a form.",
				"I wouldn't have even tried if you hadn't kept dragging me up stuff. You make me braver.",
				"If I get it, you're my first client. Free of charge. Forever.",
			],
			"ask": "Do you think I'll get it?",
			"options": ["Definitely", "They'd be crazy not to", "Only if you're back by one"],
			"replies": [
				"You're just saying that. ...Say it again.",
				"That's what I said! Marty said that too. Well, he said probably. Same thing.",
				"Ha! Okay, rude. Correct, but rude.",
			],
			"end": "From now on, if I've got extra snacks, they're yours. That's the partner rule.",
			"gift": {"chocolate_bar": 1},
			"saves": ["trail_mix", "chocolate_bar"],
			"saved": "Partner rule: extra snacks are yours. Here!",
		},
	},
	"ahwahnee_chef": {
		3: {
			"lines": [
				"Do you know why I left San Francisco? A man sent back my trout because it was too fresh.",
				"Too fresh! I put down my knife and walked out. A week later I was here, where the trout come out of the river in front of the hotel.",
				"The guests here can send back whatever they like. The river always sends more.",
			],
			"ask": "How do you like your trout?",
			"options": ["Pan-fried", "Over a campfire", "Back in the river"],
			"replies": [
				"Butter, a little salt, three minutes. Anything more is showing off.",
				"Ah, the oldest kitchen of all. I approve.",
				"Ha! That's Greg talking. The rainbows thank you.",
			],
			"end": "Take these. Morels from my secret place. If you follow me there, I'll deny it.",
			"gift": {"roasted_morels": 1},
		},
		5: {
			"lines": [
				"I've cooked for senators, film stars and one very rude duke. None of them knew what they were eating.",
				"You do. You walk the meadows, you pick carefully, and you bring me things that grew here. That's real cooking.",
				"If I ever write a cookbook, you'll be in the front of it. Probably as a warning about mushrooms. But in it.",
			],
			"ask": "What should go in the cookbook?",
			"options": ["Trout from the Merced", "Something foraged", "The bread pudding"],
			"replies": [
				"Of course. Chapter one, the river.",
				"Yes. The meadow is my real kitchen.",
				"Mrs. Degnan's? Ha! I'd have to ask her permission, and she'd say no.",
			],
			"end": "From now on I'll keep something from the kitchen for you. A cook takes care of the people who feed him.",
			"gift": {"elderberry_sauce": 1},
			"saves": ["roasted_morels", "elderberry_sauce"],
			"saved": "From the kitchen, for you. Don't tell the dining room.",
		},
	},
	"mountain_shop": {
		3: {
			"lines": [
				"Want to know a shop secret? Every piece of gear in here, somebody's going to trust their life to it.",
				"So I check every rope that comes in, every carabiner, every sling. Twice.",
				"People think I'm a clerk. I'm the last person who looks at your gear before the mountain does.",
			],
			"ask": "Do you check your own gear?",
			"options": ["Every time", "When I remember", "That's what you're for"],
			"replies": [
				"Good. You can come again.",
				"Remember more. Please. I'd like to keep my customers.",
				"Ha! Flattering, but no. Check your own gear.",
			],
			"end": "Here's some jerky. It's the one thing in the shop I don't check.",
			"gift": {"beef_jerky": 2},
		},
		5: {
			"lines": [
				"I've worked this counter a long time. You see a lot of climbers come through, and most of them you never see again.",
				"Not because anything happens. They just move on: other valleys, other walls, other lives.",
				"You stuck around. You come in and tell me what you climbed. That means a lot to a guy behind a counter.",
			],
			"ask": "Will you stick around?",
			"options": ["As long as I can", "Ask me next season", "Where else would I go?"],
			"replies": [
				"Good. I'll keep the coffee on.",
				"Fair. I'll keep the coffee on anyway.",
				"Exactly what I said, twenty years ago. Look at me now.",
			],
			"end": "From now on there'll be something behind the counter for you now and then. Don't tell the other customers.",
			"gift": {"pilot_bread": 3},
			"saves": ["beef_jerky", "pilot_bread"],
			"saved": "Kept this behind the counter for you. Not for sale.",
		},
	},
	"greg": {
		3: {
			"lines": [
				"You know why I guide? It's not the money. There is no money.",
				"It's the look on somebody's face when their first trout comes up out of the water. Every time, like they've seen a ghost.",
				"I've seen that face a thousand times, and I'd drive across the country to see it again.",
			],
			"ask": "Remember your first fish?",
			"options": ["Like it was yesterday", "Barely", "Still waiting"],
			"replies": [
				"That's the face I mean. You've got it right now, just remembering.",
				"Ha! Then it's time for a new first. Try a new river.",
				"It's coming. Dawn or dusk, a light line, and patience. It's coming.",
			],
			"end": "Here, take a couple of my flies. I tie them by the stove in winter.",
			"gear": {"royal_wulff": 1, "elk_hair_caddis": 1},
		},
		5: {
			"lines": [
				"So, about that big brown under the Stoneman Bridge. The one that got away in '71.",
				"I went back last week. Same pool, same fly. It came up, and I let it go on purpose.",
				"Some fish you don't need to catch. You just need to know they're still down there. Same with friends, I guess.",
			],
			"ask": "Would you have kept it?",
			"options": ["For the story", "Never", "Depends how hungry I was"],
			"replies": [
				"The story's better if it gets away. Trust me, I've had years of practice.",
				"Good. Then it's down there for both of us.",
				"Ha! Honest. Browns are for eating, after all. But not that one.",
			],
			"end": "I'll keep a fish back for you now and then. Brown trout, for the pot. A guide's promise.",
			"gift": {"brown_trout": 1},
			"saves": ["brown_trout", "beef_jerky"],
			"saved": "Kept one back for you. Fresh this morning.",
		},
	},
	"jo_tolliver": {
		3: {
			"lines": [
				"I'll tell you about my first search. A kid in the high country, lost overnight. We looked for two days.",
				"Found him under a fallen log, dry as toast, eating a candy bar he'd been saving. He asked what took us so long.",
				"I've been doing this ever since. Everybody gets found. That's the only rule.",
			],
			"ask": "What would you do if you got lost?",
			"options": ["Stay put", "Find water", "Keep walking"],
			"replies": [
				"Right answer. Stay put and let us find you. We will.",
				"Not bad. Water first, then shelter, then stay put.",
				"No! That's how a small search turns into a big one. Stay put.",
			],
			"end": "Here, rescue rations. Keep them in your pack for the bad days.",
			"gift": {"pilot_bread": 3},
		},
		5: {
			"lines": [
				"There's a call I don't talk about much. A storm on the Cathedral Range, and two climbers who'd stopped moving.",
				"We got them down, both of them. But for a few hours on that ridge, I didn't know if we would.",
				"I think about it when I'm scared. It reminds me we've done hard things and come home. You've done them with me.",
			],
			"ask": "What gets you through the hard calls?",
			"options": ["The team", "The training", "Knowing they're waiting"],
			"replies": [
				"Same. Nobody carries a litter alone.",
				"Good. When you're scared, your hands still know what to do.",
				"Yeah. Someone out there is waiting to hear footsteps. That's why we go.",
			],
			"end": "From now on I'll leave something at the site for you now and then. Rations, for a teammate.",
			"gift": {"chocolate_bar": 1},
			"saves": ["chocolate_bar", "pilot_bread"],
			"saved": "Left these at the site for you. A teammate's rations.",
		},
	},
	"mateo_reyes": {
		3: {
			"lines": [
				"Want to see the cache log? Every rope we've got has its own page: every rescue, every fall, every wash.",
				"When a rope's caught enough falls, it retires. I write thank you on its last page before I cut it up for tie-offs.",
				"Sounds silly. But that rope held somebody's life. It deserves a thank-you.",
			],
			"ask": "Do you name your gear?",
			"options": ["Of course", "That's weird", "Only my rope"],
			"replies": [
				"Ha! I knew it. Mine's called Lupe. She's held eleven falls.",
				"Maybe. But it's the good kind of weird.",
				"The rope's the one that matters most. Good choice.",
			],
			"end": "Here, some jerky from the cache. We always keep extra.",
			"gift": {"beef_jerky": 2},
		},
		5: {
			"lines": [
				"Five years at the site, and I still haven't been up El Cap. My friends back home think that's hilarious.",
				"But every time I'm about to go, the radio goes off. And honestly, I'd rather be on the litter than on the wall.",
				"You're the first person who's never asked me why. You just get it. Thanks for that.",
			],
			"ask": "Will you ever climb it?",
			"options": ["Someday, for sure", "You don't need to", "I'll climb it with you"],
			"replies": [
				"Someday. When the radio's quiet. So, never.",
				"Thanks. I really don't, do I?",
				"...Okay. You're on. I'll bring the yellow shirts.",
			],
			"end": "From now on there'll be something in the cache for you now and then. Don't tell Jo, she counts everything.",
			"gift": {"trail_mix": 2},
			"saves": ["beef_jerky", "trail_mix"],
			"saved": "Found this in the cache with your name on it. Weird, huh?",
		},
	},
}


## The hearts of the scene [param character_id] has waiting for you (3 or
## 5), or 0 if none.
static func ready_for(character_id: String) -> int:
	var scenes: Dictionary = SCENES.get(character_id, {})
	if scenes.is_empty() or character_id in SmallTalk.AWAITING_REVIEW:
		return 0
	var character := QuestLog.get_character(character_id)
	if character and character.needs_tribal_review:
		return 0
	var seen := int(Friendship.scenes.get(character_id, 0))
	var hearts := Friendship.hearts(character_id)
	for level: int in LEVELS:
		if level > seen and hearts >= level and scenes.has(level):
			return level
	return 0


## True once [param character_id] has shared their last scene with you.
static func close(character_id: String) -> bool:
	return int(Friendship.scenes.get(character_id, 0)) >= LEVELS.back()


## Plays the scene [param character_id] has waiting in [param box], as
## [param speaker], with a heart over [param anchor] at the end. Seen from
## the start, so walking off halfway doesn't bring it round again.
static func play(box: DialogueBox, character_id: String, speaker: String, anchor: Node2D = null) -> void:
	var level := ready_for(character_id)
	if level == 0:
		return
	var scene: Dictionary = SCENES[character_id][level]
	Friendship.scenes[character_id] = level
	if level == LEVELS.back():
		# the first thing they save for you comes a week from now
		Friendship.saved_for_you[character_id] = Friendship.today()
	Friendship.changed.emit()
	await box.say(_lines(speaker, scene.get("lines", [])))
	var options: Array = scene.get("options", [])
	if not options.is_empty():
		var pick := await box.choose(scene.get("ask", ""), options, speaker)
		var replies: Array = scene.get("replies", [])
		if pick >= 0 and pick < replies.size():
			await box.say(_lines(speaker, [replies[pick]]))
	var after := _lines(speaker, [scene.get("end", "")])
	var got := give(scene)
	if got != "":
		after.append({"speaker": "", "text": got})
	if anchor and anchor.is_inside_tree():
		Hearts.pop(anchor)
	Sound.play("heart", 0.0, 0.0)
	await box.say(after)


## Hands over what [param scene] gives you and returns "Received ..." (or "").
static func give(scene: Dictionary) -> String:
	var got := PackedStringArray()
	var items: Dictionary = scene.get("gift", {})
	for id: String in items:
		Inventory.add(id, int(items[id]))
		got.append(ItemDB.count_name(int(items[id]), ItemDB.get_item(id).display_name))
	var gear: Dictionary = scene.get("gear", {})
	for id: String in gear:
		Gear.add(id, int(gear[id]))
		var gear_name := Gear.get_gear(id).display_name
		got.append(gear_name if int(gear[id]) == 1 else ItemDB.count_name(int(gear[id]), gear_name))
	return "Received %s." % ", ".join(got) if not got.is_empty() else ""


## What a close friend has saved for you, handed over now if it's been
## SAVE_EVERY days since the last: their line and "Received ...", or [].
static func saved_gift(character_id: String, speaker: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not close(character_id):
		return lines
	var scene: Dictionary = SCENES.get(character_id, {}).get(LEVELS.back(), {})
	var saves: Array = scene.get("saves", [])
	var last := int(Friendship.saved_for_you.get(character_id, -SAVE_EVERY))
	if saves.is_empty() or Friendship.today() - last < SAVE_EVERY:
		return lines
	Friendship.saved_for_you[character_id] = Friendship.today()
	var id: String = saves[(Friendship.today() / SAVE_EVERY) % saves.size()]
	Inventory.add(id)
	lines.append({"speaker": speaker, "text": scene.get("saved", "")})
	lines.append({"speaker": "", "text": "Received %s." % ItemDB.count_name(1, ItemDB.get_item(id).display_name)})
	return lines


## Every line of [param character_id]'s scenes, for checking them over.
static func all_lines(character_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var scenes: Dictionary = SCENES.get(character_id, {})
	for level: int in scenes:
		var scene: Dictionary = scenes[level]
		out.append_array(PackedStringArray(scene.get("lines", [])))
		out.append_array(PackedStringArray(scene.get("replies", [])))
		for key: String in ["ask", "end", "saved"]:
			if scene.get(key, "") != "":
				out.append(scene[key])
	return out


static func _lines(speaker: String, texts: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for text: String in texts:
		if text != "":
			out.append({"speaker": speaker, "text": text})
	return out
