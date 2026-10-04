extends Node
## In-game calendar and clock.
##
## Time only advances while [member paused] is false. Other systems react to
## the signals below instead of polling every frame.

signal time_changed(hour: int, minute: int)
signal day_started(day: int, season: int, year: int)
## Emitted when the clock reaches [constant PASS_OUT_HOUR]. The player must sleep.
signal curfew_reached

enum Season { SPRING, SUMMER, FALL, WINTER }

const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]
const WEEKDAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const DAYS_PER_SEASON := 28
const DAY_START_HOUR := 6
const PASS_OUT_HOUR := 26 # 2:00 AM the following morning
const MINUTES_PER_TICK := 10

## Real seconds per clock tick. Stardew Valley uses about 7 seconds per 10 minutes.
var seconds_per_tick := 7.0

var day := 1
var season: int = Season.SPRING
var year := 1
## Minutes since midnight at the start of the current day. Goes past 1440
## after midnight so the day doesn't roll over until the player sleeps.
var minutes := DAY_START_HOUR * 60
var paused := false

var hour: int:
	get:
		return floori(minutes / 60.0) % 24
var minute: int:
	get:
		return minutes % 60

var _elapsed := 0.0


func _process(delta: float) -> void:
	if paused or minutes >= PASS_OUT_HOUR * 60:
		return
	_elapsed += delta
	while _elapsed >= seconds_per_tick:
		_elapsed -= seconds_per_tick
		advance_minutes(MINUTES_PER_TICK)


func advance_minutes(amount: int) -> void:
	minutes = mini(minutes + amount, PASS_OUT_HOUR * 60)
	time_changed.emit(hour, minute)
	if minutes >= PASS_OUT_HOUR * 60:
		curfew_reached.emit()


func start_new_day() -> void:
	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		season += 1
		if season > Season.WINTER:
			season = Season.SPRING
			year += 1
	minutes = DAY_START_HOUR * 60
	_elapsed = 0.0
	day_started.emit(day, season, year)
	time_changed.emit(hour, minute)


## 0.0 at midnight, 0.5 at noon. Smooth between ticks, for lighting.
func get_day_progress() -> float:
	var smooth_minutes := minutes + _elapsed / seconds_per_tick * MINUTES_PER_TICK
	return fposmod(smooth_minutes, 1440.0) / 1440.0


func get_time_string() -> String:
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minute, "AM" if hour < 12 else "PM"]


func get_date_string() -> String:
	return "%s %d (%s)" % [SEASON_NAMES[season], day, WEEKDAY_NAMES[(day - 1) % 7]]


func save_data() -> Dictionary:
	return {"day": day, "season": season, "year": year, "minutes": minutes}


func load_data(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	season = int(data.get("season", Season.SPRING))
	year = int(data.get("year", 1))
	minutes = int(data.get("minutes", DAY_START_HOUR * 60))
	_elapsed = 0.0
