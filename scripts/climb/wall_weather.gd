class_name WallWeather
extends RefCounted
## The weather on the wall for a day's climb, from the day's weather (see
## Weather.today) and the route's place in the park.
##
## - **Wet rock.** It rains on the wall on a rainy day (or snows, and the snow
##   melts down the face). The morning after rain the rock stays wet until the
##   sun has been on it a couple of hours; a face that never sees the sun stays
##   wet until mid-afternoon. Wet rock narrows the crux meter's green, and
##   friction (slab, dike, knobs) costs more.
## - **Wind.** Some days are windy. It blows on the upper pitches of the long
##   routes and on the high-country routes: the climber sways and the crux
##   meter's green narrows.
## - **Heat.** In summer a face in the midday sun is hot: greasy holds, sweaty
##   hands, a little more each move.
## - **High-country storms.** Most summer afternoons thunderheads build over
##   Tuolumne. When the storm comes the rock is wet and every move costs more;
##   an hour later the lightning sends you down, wherever you are.
##
## The conditions are one Dictionary a day (same answer after a reload);
## ClimbState asks it the hour-by-hour questions. Tests use [constant CALM].

## A still, dry day. High-country routes still storm at the old
## ClimbState.STORM_HOUR, but the lightning never sends you down.
const CALM := {"rain": 0.0, "snow": 0.0, "dry_hour": 0.0, "wet_why": "", "wind": false, "hot": false, "storm_hour": 14.5, "lightning": false}
## Chance of a windy day, by season (spring, summer, fall, winter).
const WIND_CHANCE := [0.3, 0.15, 0.3, 0.45]
## Chance of an afternoon storm in the high country, by season.
const STORM_CHANCE := [0.35, 0.75, 0.25, 0.0]
## How long the sun takes to dry the rock after rain, and when a face that
## never sees the sun is dry anyway.
const DRY_SUN_HOURS := 2.5
const DRY_SHADE_HOUR := 15.0
## Rock wet from the night's rain is dry by this hour at the latest, and no
## earlier than this.
const DRY_LATEST := 16.0
const DRY_EARLIEST := 9.5


## The conditions on [param route_id] today.
static func today(route_id: String) -> Dictionary:
	return on_day(route_id, GameClock.year, GameClock.season, GameClock.day)


## The conditions on [param route_id] on a date.
static func on_day(route_id: String, year: int, season: int, day: int) -> Dictionary:
	var profile := ClimbProfiles.get_profile(route_id)
	var alpine: bool = profile.get("weather", "valley") == "alpine"
	var sun: Array = profile.get("sun", [10, 16])
	var w := Weather.on_day(year, season, day)
	if year == GameClock.year and season == GameClock.season and day == GameClock.day:
		w = Weather.today()
	var before := _yesterday(year, season, day)
	var y := Weather.on_day(before.x, before.y, before.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wall:%s:%d:%d:%d" % ["alpine" if alpine else "valley", year, season, day])
	var out := CALM.duplicate()
	out["rain"] = float(w.rain)
	out["snow"] = float(w.snow)
	if w.rain > 0.0 or w.snow > 0.0:
		out["dry_hour"] = 24.0
		out["wet_why"] = "rain" if w.rain > 0.0 else "snow"
	elif y.rain > 0.0 or y.snow > 0.0:
		var dry := DRY_SHADE_HOUR
		if sun.size() >= 2 and int(sun[1]) > int(sun[0]):
			dry = float(sun[0]) + DRY_SUN_HOURS
		out["dry_hour"] = clampf(dry, DRY_EARLIEST, DRY_LATEST)
		out["wet_why"] = "yesterday"
	out["wind"] = rng.randf() < WIND_CHANCE[season]
	out["hot"] = season == GameClock.Season.SUMMER
	out["storm_hour"] = -1.0
	if alpine and rng.randf() < STORM_CHANCE[season]:
		# Between 1:30 and 3:30 in the afternoon, on the half hour.
		out["storm_hour"] = 13.5 + 0.5 * rng.randi_range(0, 4)
	out["lightning"] = true
	return out


## The day before (year, season, day), as Vector3i(year, season, day).
static func _yesterday(year: int, season: int, day: int) -> Vector3i:
	if day > 1:
		return Vector3i(year, season, day - 1)
	if season > 0:
		return Vector3i(year, season - 1, GameClock.DAYS_PER_SEASON)
	return Vector3i(maxi(year - 1, 1), 3, GameClock.DAYS_PER_SEASON)


## "2:30 PM" for an hour like 14.5.
static func clock_text(hour: float) -> String:
	var h := int(hour) % 24
	var m := roundi((hour - int(hour)) * 60.0)
	var clock := "%d" % (h % 12 if h % 12 != 0 else 12)
	if m > 0:
		clock += ":%02d" % m
	return "%s %s" % [clock, "AM" if h < 12 else "PM"]


## The forecast lines for the route card and the guidebook: [text, warn]
## pairs, short enough for the route card's facts column. [param conditions]
## as from [method today].
static func forecast(route: RouteData, conditions: Dictionary) -> Array:
	var profile := ClimbProfiles.get_profile(route.id)
	var alpine: bool = profile.get("weather", "valley") == "alpine"
	var sun: Array = profile.get("sun", [10, 16])
	var lines := []
	if float(conditions.get("rain", 0.0)) > 0.0:
		lines.append(["Raining: wet rock all day", true])
	elif float(conditions.get("snow", 0.0)) > 0.0:
		lines.append(["Snowing: wet rock all day", true])
	elif float(conditions.get("dry_hour", 0.0)) > 0.0 and not _all_snow(profile):
		lines.append(["Wet rock until %s" % clock_text(conditions.dry_hour), true])
	if alpine:
		var storm := float(conditions.get("storm_hour", -1.0))
		if storm >= 0.0:
			lines.append(["Storms after %s" % clock_text(storm), true])
			if conditions.get("lightning", false):
				lines.append(["Lightning by %s: go down" % clock_text(storm + ClimbState.LIGHTNING_AFTER), true])
		else:
			lines.append(["Clear skies up high today", false])
	if conditions.get("wind", false) and not route.boulder and (alpine or route.pitches.size() >= ClimbState.WIND_MIN_PITCHES):
		lines.append(["Windy up high", true])
	if conditions.get("hot", false) and sun.size() >= 2 and float(sun[1]) > ClimbState.HEAT_FROM \
			and float(sun[0]) < ClimbState.HEAT_TO and not _all_snow(profile):
		lines.append(["Hot in the sun %s-%s" % [clock_text(maxf(float(sun[0]), ClimbState.HEAT_FROM)), clock_text(minf(float(sun[1]), ClimbState.HEAT_TO))], true])
	if lines.is_empty():
		lines.append(["Dry rock, light winds", false])
	return lines


## Today's conditions on the walls, for the guidebook: one line for the
## Valley and one for the high country.
static func guidebook_lines() -> Array[String]:
	var valley := today("the_nose")
	var parts: Array[String] = []
	if valley.rain > 0.0 or valley.snow > 0.0:
		parts.append("%s in the Valley: wet rock everywhere" % ("Raining" if valley.rain > 0.0 else "Snowing"))
	elif valley.dry_hour > 0.0:
		parts.append("Wet rock this morning after yesterday's rain (sunny faces dry first)")
	else:
		parts.append("Dry rock in the Valley")
	if valley.wind:
		parts.append("windy on the big walls")
	if valley.hot:
		parts.append("hot in the midday sun")
	var high := today("cathedral_peak")
	var tuolumne := "High country: "
	if high.rain > 0.0 or high.snow > 0.0:
		tuolumne += "wet all day."
	elif float(high.storm_hour) >= 0.0:
		tuolumne += "storms after %s, lightning an hour later. Start early." % clock_text(high.storm_hour)
	else:
		tuolumne += "clear all day."
	var lines: Array[String] = ["Today: " + ", ".join(parts) + ".", tuolumne]
	return lines


## True for a route that's all snow and ice: the sun makes slush there, not heat.
static func _all_snow(profile: Dictionary) -> bool:
	for spec: Dictionary in profile.get("pitches", []):
		if spec.get("style", "") not in ["snow", "ice"]:
			return false
	return true
