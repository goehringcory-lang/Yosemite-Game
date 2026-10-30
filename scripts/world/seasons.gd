class_name Seasons
extends RefCounted
## What the year has done to the land on a given day: how much snow lies on
## the Valley floor and how hard each waterfall is running. Both come from the
## calendar and each day's weather (Weather.on), so they're the same after a
## reload and need nothing saved.
##
## Snow builds up through the winter, a few inches with every snowy day, and
## settles back between storms; once it has snowed, patches stay in the shade
## until spring, and the last of it melts in the first days of spring (a new
## game starts in a spring with no winter behind it, so with none).
##
## The falls follow the snowmelt: rising through spring to a roar at the end of
## May, falling away all summer, and dry through most of fall until the first
## November storms. Each fall has its own [constant FALLS] kind, since the
## small ones off the rim dry up weeks before Yosemite Falls, and Bridalveil
## never quite stops.

## How deep a snowy day lays the snow (0 to 1 covers the floor), at its
## lightest and its heaviest, and how much settles away on a dry winter day.
const SNOWFALL := Vector2(0.06, 0.2)
const WINTER_SETTLE := 0.12
## Patches left in the shade all winter, once it has snowed.
const WINTER_PATCHES := 0.2
## The spring thaw: this much melts a day, so it's gone in about five days.
const SPRING_MELT := 0.2

## Waterfall kinds. "dries": the snowmelt flow below which it stops for the
## year. "least": the least it ever runs (Bridalveil's spring-fed trickle).
const FALLS := {
	# Yosemite Falls: a roar in May, a trickle in August, dry by September.
	"yosemite": {"dries": 0.1, "least": 0.0},
	# Sentinel Fall, Staircase Falls, Royal Arch Cascade: small catchments off
	# the rim that run dry by late July.
	"ephemeral": {"dries": 0.4, "least": 0.0},
	# Bridalveil Fall runs all year, thin as a horse's tail by fall.
	"steady": {"dries": 0.0, "least": 0.18},
}

## Horsetail Fall, on El Capitan's east shoulder, runs only on winter snowmelt
## and the first weeks of spring.
const HORSETAIL_SPRING_DAYS := 14

static var _snow_key := ""
static var _snow := 0.0


## How much snow lies on the ground, 0 (bare) to 1 (the floor is white).
## Leave the date out for today.
static func snow_cover(year := -1, season := -1, day := -1) -> float:
	if year < 0:
		year = GameClock.year
		season = GameClock.season
		day = GameClock.day
	var key := "%d:%d:%d" % [year, season, day]
	if key == _snow_key:
		return _snow
	var cover := 0.0
	match season:
		GameClock.Season.WINTER:
			cover = _winter_snow(year, day)
		GameClock.Season.SPRING when year > 1:
			# Last winter's snow, melting.
			cover = maxf(_winter_snow(year - 1, GameClock.DAYS_PER_SEASON) - SPRING_MELT * day, 0.0)
	_snow_key = key
	_snow = cover
	return cover


## The snow after [param day] days of winter.
static func _winter_snow(year: int, day: int) -> float:
	var depth := 0.0
	var snowed := false
	for d in range(1, day + 1):
		var weather := Weather.on(year, GameClock.Season.WINTER, d)
		if weather.snow > 0.0:
			snowed = true
			depth = minf(depth + lerpf(SNOWFALL.x, SNOWFALL.y, weather.snow), 1.0)
		else:
			depth = maxf(depth - WINTER_SETTLE, WINTER_PATCHES if snowed else 0.0)
	return depth


## How hard the snowmelt is running, 0 to 1, before each fall's own limits.
static func snowmelt(season := -1, day := -1) -> float:
	if season < 0:
		season = GameClock.season
		day = GameClock.day
	var t := clampf((day - 1) / float(GameClock.DAYS_PER_SEASON - 1), 0.0, 1.0)
	match season:
		GameClock.Season.SPRING:
			return lerpf(0.7, 1.0, t)
		GameClock.Season.SUMMER:
			return lerpf(1.0, 0.05, t)
		GameClock.Season.FALL:
			# Dry until the first storms of November.
			return 0.0 if t < 0.7 else lerpf(0.0, 0.3, (t - 0.7) / 0.3)
	return lerpf(0.45, 0.55, t)


## How hard a waterfall of [param kind] (see [constant FALLS]) runs today:
## 1 is the May roar, 0 is dry rock.
static func waterfall_flow(kind: String, season := -1, day := -1) -> float:
	var melt := snowmelt(season, day)
	var spec: Dictionary = FALLS.get(kind, FALLS["yosemite"])
	if melt < spec["dries"]:
		return spec["least"]
	return maxf(melt, spec["least"])


## True on the days Horsetail Fall has water in it: all winter, and the first
## two weeks of spring.
static func horsetail_running(season := -1, day := -1) -> bool:
	if season < 0:
		season = GameClock.season
		day = GameClock.day
	return season == GameClock.Season.WINTER or (season == GameClock.Season.SPRING and day <= HORSETAIL_SPRING_DAYS)
