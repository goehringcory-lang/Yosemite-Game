class_name Climate
extends RefCounted
## How high, and so how cold, each part of the park is: the one place every
## system asks "is this the high country?" (the weather, the snow on the
## ground, your breath, the wind and the birds you hear, the squirrels you
## see).
##
## The park spans 2,000 feet at El Portal to 9,500 at Cathedral Lakes, and the
## same storm does different things across it: rain on the Valley floor is
## snow on Tuolumne Meadows in spring and late fall, a winter storm that
## whitens the Valley is only rain down the canyon at El Portal, and on many
## summer afternoons a thunderstorm breaks over the high country while the
## Valley stays dry. Up high the snow comes earlier, lies deeper, and melts
## out weeks later (Glacier Point late in spring, about when its road opens;
## Tuolumne at the start of summer, when the Tioga Road does).
##
## Everything comes from the date and the place, so it is the same after a
## reload and needs nothing saved. The Valley floor (VALLEY_FT) keeps exactly
## the weather and snow it always had: see Weather.on_day and Seasons.

## Height above sea level of each outdoor area, in feet (roughly where you
## walk, not the summits above it).
const ELEVATION := {
	"el_portal": 2000,
	"hetch_hetchy": 3900,
	"wawona": 4000,
	"crane_flat": 6200,
	"big_oak_flat_junction": 4800,
	"little_yosemite_valley": 6100,
	"glacier_point": 7200,
	"taft_point": 7500,
	"tenaya_lake": 8150,
	"tuolumne_meadows": 8600,
	"half_dome": 8000,
	"cathedral_lakes": 9500,
}
## Areas not listed: their hub's height, or the Valley floor.
const HUB_ELEVATION := {
	"el_portal": 2000,
	"wawona": 4000,
	"glacier_point": 7200,
	"tuolumne_meadows": 8600,
}
const VALLEY_FT := 4000
## Below this, a winter storm falls as rain (El Portal).
const RAIN_BELOW_FT := 3000
## From this height up, the weather and snow are the mountain's own; below it
## (down to RAIN_BELOW_FT) they are the Valley's.
const MOUNTAIN_FT := 5000
## The high country (subalpine): thin air, marmots and pikas, a summer
## afternoon storm.
const HIGH_FT := 7000
## Degrees Fahrenheit colder for every thousand feet up.
const LAPSE_F := 3.5
## A typical Valley-floor afternoon, by season (start and end of the season,
## degrees F): spring warms, fall cools.
const SEASON_F := [Vector2(52, 72), Vector2(78, 86), Vector2(80, 54), Vector2(46, 50)]
## A stormy day is this much colder than a fair one.
const STORM_CHILL_F := 8.0
## Snow falls instead of rain when a storm day is colder than this.
const SNOW_BELOW_F := 36.0
## How much deeper a storm lays the snow, per thousand feet above MOUNTAIN_FT.
const SNOW_GAIN := 0.35
## How fast the snow goes on a day without fresh snow, at the Valley floor's
## height, by season; higher up it goes slower (see melt).
const MELT := [0.2, 0.4, 0.08, 0.03]
## The summer afternoon shower over the high country: from how high it rains
## and how long it rains once the storm breaks (hours).
const SHOWER_FT := 8000
const SHOWER_HOURS := 0.75
## Thunder starts this long before it breaks (hours), and the ground stays
## wet this long after.
const SHOWER_THUNDER := 0.4
const SHOWER_WET := 2.5

## The area the player is in, and its hub, set by World as they arrive; ""
## off the map (the title screen, tests without a World), which is the
## Valley floor. A building is as high as its hub (the Tuolumne Lodge is
## Tuolumne's), so loading a game indoors needs nothing else saved.
static var place := ""
static var place_hub := ""


## Called by World on arriving anywhere (a door, a trip, a seam, a load).
static func arrive(region_id: String, hub_id: String) -> void:
	place = region_id
	place_hub = hub_id


## Feet above sea level at [param region_id] (leave out for where you are).
static func elevation(region_id := "_here", hub_id := "") -> int:
	if region_id == "_here":
		region_id = place
		hub_id = place_hub
	if ELEVATION.has(region_id):
		return ELEVATION[region_id]
	if HUB_ELEVATION.has(hub_id):
		return HUB_ELEVATION[hub_id]
	return VALLEY_FT


## True above HIGH_FT: the subalpine high country.
static func is_high(region_id := "_here", hub_id := "") -> bool:
	return elevation(region_id, hub_id) >= HIGH_FT


## True above MOUNTAIN_FT: out of the Valley's oaks, into the fir and pine.
static func is_mountain(region_id := "_here", hub_id := "") -> bool:
	return elevation(region_id, hub_id) >= MOUNTAIN_FT


## "foothill", "valley", "montane" or "subalpine".
static func zone(region_id := "_here", hub_id := "") -> String:
	var ft := elevation(region_id, hub_id)
	if ft < RAIN_BELOW_FT:
		return "foothill"
	if ft < MOUNTAIN_FT:
		return "valley"
	if ft < HIGH_FT:
		return "montane"
	return "subalpine"


## How many degrees colder than the Valley floor at [param ft].
static func chill(ft: int) -> float:
	return (ft - VALLEY_FT) / 1000.0 * LAPSE_F


## A fair afternoon's warmth on the Valley floor on a date (degrees F).
static func valley_high_f(season: int, day: int) -> float:
	var t := clampf((day - 1) / float(GameClock.DAYS_PER_SEASON - 1), 0.0, 1.0)
	var range_f: Vector2 = SEASON_F[clampi(season, 0, 3)]
	return lerpf(range_f.x, range_f.y, t)


## About how warm it is now at [param ft] (degrees F): the afternoon high
## for the date, cooler at dawn and at night, colder up high and in a storm.
static func temperature_f(ft := -1, hour := -1.0) -> float:
	if ft < 0:
		ft = elevation()
	if hour < 0.0:
		hour = GameClock.hour + GameClock.minute / 60.0
	var h := fposmod(hour, 24.0)
	# coldest at dawn (6), warmest mid-afternoon (15); thin air swings wider
	var swing := 22.0 + 6.0 * clampf((ft - VALLEY_FT) / 4000.0, 0.0, 1.0)
	var warm := 0.5 - 0.5 * cos(clampf((h - 6.0) / 9.0, 0.0, 1.0) * PI) if h >= 6.0 and h <= 15.0 \
		else 0.5 + 0.5 * cos(clampf(fposmod(h - 15.0, 24.0) / 15.0, 0.0, 1.0) * PI)
	var w: Dictionary = Weather.today()
	var stormy := 1.0 if w.snow > 0.0 or w.rain > 0.0 else 0.0
	return valley_high_f(GameClock.season, GameClock.day) - chill(ft) - swing * (1.0 - warm) - STORM_CHILL_F * stormy


## The day's weather at [param ft] feet: the park's storm for the date
## (Weather.on_day, the Valley floor's own) as it falls at that height.
static func weather_at(year: int, season: int, day: int, ft: int) -> Dictionary:
	return localize(Weather.on_day(year, season, day), season, day, ft)


## [param w] (the park's weather for a date: the Valley floor's) as it falls
## at [param ft] feet. The Valley floor's own dictionary comes back as it is.
static func localize(w: Dictionary, season: int, day: int, ft: int) -> Dictionary:
	if ft >= RAIN_BELOW_FT and ft < MOUNTAIN_FT:
		return w
	w = w.duplicate()
	if ft < RAIN_BELOW_FT:
		# down the canyon a winter storm comes as rain
		if w.snow > 0.0:
			w.rain = w.snow
			w.snow = 0.0
		return w
	var storm_f := valley_high_f(season, day) - chill(ft) - STORM_CHILL_F
	if w.rain > 0.0 and storm_f < SNOW_BELOW_F:
		w.snow = w.rain
		w.rain = 0.0
	if w.snow > 0.0:
		w.snow = minf(w.snow * (1.0 + SNOW_GAIN * 0.5 * (ft - MOUNTAIN_FT) / 1000.0), 1.0)
	return w


## How fast the snow goes at [param ft] on a day without fresh snow.
static func melt(season: int, ft: int) -> float:
	var rate: float = MELT[clampi(season, 0, 3)]
	if season == GameClock.Season.WINTER:
		return rate
	# the thin cold air up high keeps it far longer
	return rate * pow(float(VALLEY_FT) / float(maxi(ft, VALLEY_FT)), 2.5)


## The snow lying at [param ft] feet on a date, 0 (bare) to 1 (deep): built
## up by each storm from the start of fall, settling between storms, and
## melting out in spring and early summer, slower the higher it is. Only for
## the mountains (MOUNTAIN_FT up); the Valley floor's is Seasons.snow_cover.
## Year 1's spring has the winter before it, as the high country always does.
static func mountain_snow(year: int, season: int, day: int, ft: int) -> float:
	var y := year if season >= GameClock.Season.FALL else year - 1
	var depth := 0.0
	var snowed := false
	var floor_f := clampf((ft - MOUNTAIN_FT) / 3500.0, 0.2, 0.8)
	for s in [GameClock.Season.FALL, GameClock.Season.WINTER, GameClock.Season.SPRING, GameClock.Season.SUMMER]:
		var sy: int = y if s >= GameClock.Season.FALL else y + 1
		for d in range(1, GameClock.DAYS_PER_SEASON + 1):
			if sy == year and s == season and d > day:
				return depth
			var w := weather_at(sy, s, d, ft)
			if w.snow > 0.0:
				snowed = true
				depth = minf(depth + lerpf(Seasons.SNOWFALL.x, Seasons.SNOWFALL.y, w.snow) * (1.0 + SNOW_GAIN * (ft - MOUNTAIN_FT) / 1000.0), 1.0)
			else:
				var lowest := floor_f if snowed and s == GameClock.Season.WINTER else 0.0
				depth = maxf(depth - melt(s, ft), minf(lowest, depth))
			if sy == year and s == season and d == day:
				return depth
	return depth


## How hard the high country's summer afternoon thunderstorm is raining at
## [param ft] now (0 to 1). It breaks at the hour the climbs' forecast gives
## (HighCountry.storm_hour) and passes in about SHOWER_HOURS; how hard comes
## from a roll for the day, and about a third of storms only sprinkle or
## pass over dry. Only at SHOWER_FT and up: lower down (Glacier Point) you
## just hear it rumble. Not part of Weather.today, which is the day's
## weather and stays the same all day: see Weather.shower.
static func shower(ft := -1, hour := -1.0) -> float:
	if ft < 0:
		ft = elevation()
	if ft < SHOWER_FT or GameClock.season != GameClock.Season.SUMMER:
		return 0.0
	var storm := HighCountry.storm_hour()
	if storm < 0.0:
		return 0.0
	if hour < 0.0:
		hour = GameClock.hour + GameClock.minute / 60.0
	var h := fposmod(hour, 24.0)
	var on := smoothstep(storm - 0.05, storm + 0.15, h) * (1.0 - smoothstep(storm + SHOWER_HOURS - 0.25, storm + SHOWER_HOURS, h))
	return on * shower_strength()


## How hard today's afternoon storm rains when it comes (0 for one that
## passes over dry), from the date.
static func shower_strength() -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shower:%d:%d:%d" % [GameClock.year, GameClock.season, GameClock.day])
	var roll := rng.randf()
	if roll < 0.2:
		return 0.0
	if roll < 0.35:
		return 0.2
	return rng.randf_range(0.45, 0.8)


## Hours since today's high-country storm broke, while its thunder and wet
## ground last (from SHOWER_THUNDER before to SHOWER_WET after), else -1.
## Thunder rolls on every storm day, from Glacier Point up.
static func since_storm(hour := -1.0) -> float:
	if GameClock.season != GameClock.Season.SUMMER:
		return -1.0
	var storm := HighCountry.storm_hour()
	if storm < 0.0:
		return -1.0
	if hour < 0.0:
		hour = GameClock.hour + GameClock.minute / 60.0
	var since := fposmod(hour, 24.0) - storm
	return since if since >= -SHOWER_THUNDER and since <= SHOWER_WET else -1.0


## A line for the morning's wake-up message when the day's storm is
## different up high or down the canyon from where you woke, or "".
static func forecast_note() -> String:
	var park := Weather.park_today()
	if park.rain > 0.0 and localize(park, GameClock.season, GameClock.day, ELEVATION["tuolumne_meadows"]).snow > 0.0:
		if elevation() >= MOUNTAIN_FT:
			return "Snow up here today. Down in the Valley it's falling as rain."
		return "Rain in the Valley today. Up in the high country it's coming down as snow."
	if park.snow > 0.0 and elevation() >= RAIN_BELOW_FT:
		return "Snow today. Down the canyon at El Portal it's only rain."
	return ""
