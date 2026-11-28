extends RefCounted

const LEAGUES := ["Iron", "Bronze", "Silver", "Gold", "Diamond", "Ascendant", "Divine"]
const STARS_PER_DIVISION := 3
const DIVISIONS := ["V", "IV", "III", "II", "I"]
const IRON_DIVISIONS := ["III", "II", "I"]
const FIRST_LEAGUE_WITH_STAR_LOSS := 2
const FIRST_LEAGUE_WITHOUT_STREAK_BONUS := 4
const WIN_STREAK_BONUS_THRESHOLD := 3
const BO3_STAR_MULTIPLIER := 2
const DIVINE := 6

static func season_for_time(unix_time: float) -> int:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time))
	return int(date["year"]) * 12 + int(date["month"]) - 1

static func advance_to_season(progress: Dictionary, season: int) -> void:
	var previous_season := int(progress.get("season", season))
	if not progress.is_empty() and previous_season >= season:
		return
	var previous_peak := _rank_at(int(progress.get("peak_points", 0)))
	var reset_league := maxi(0, int(previous_peak["league"]) - (season - previous_season))
	var reset_points := _league_start(reset_league)
	progress.merge({
		"season": season,
		"points": reset_points,
		"peak_points": reset_points,
		"win_streak": 0,
		"matches": 0,
		"last_delta": 0,
	}, true)

static func apply_result(progress: Dictionary, result: String, season: int, star_multiplier: int = 1) -> void:
	advance_to_season(progress, season)
	var previous_points: int = progress["points"]
	var current_rank := _rank_at(previous_points)
	var points := previous_points
	var streak: int = progress["win_streak"]
	var multiplier := maxi(1, star_multiplier)
	match result:
		"win":
			streak += 1
			points += win_bonus_stars(streak, previous_points) * multiplier
		"loss":
			streak = 0
			points = maxi(points - multiplier, int(current_rank["floor_points"]))
		"draw":
			streak = 0
		_:
			return
	progress["points"] = points
	progress["peak_points"] = maxi(points, int(progress["peak_points"]))
	progress["win_streak"] = streak
	progress["matches"] = int(progress["matches"]) + 1
	progress["last_delta"] = points - previous_points

# Stars earned by a win whose streak (including this win) is `streak_including_win`,
# scored at the pre-win point total. Shared by the human ladder and bot records.
static func win_bonus_stars(streak_including_win: int, current_points: int) -> int:
	var bonus := 1
	if streak_including_win >= WIN_STREAK_BONUS_THRESHOLD \
			and int(_rank_at(current_points)["league"]) < FIRST_LEAGUE_WITHOUT_STREAK_BONUS:
		bonus = 2
	return bonus

# Bo3 rated matches move stars at double the Bo1 rate in both directions.
static func star_multiplier_for_format(best_of: int) -> int:
	return BO3_STAR_MULTIPLIER if best_of == 3 else 1

# Applies a rated outcome to a bot ladder record ("wins"/"losses"/"draws",
# "stars", and "win_streak") using the same ladder rules as players. Bots never
# store season progress, so the streak lives directly on the record that
# RankedBotDeckPool replays from history.
static func apply_bot_result(record: Dictionary, outcome: String, star_multiplier: int = 1) -> void:
	var multiplier := maxi(1, star_multiplier)
	match outcome:
		"win":
			record["wins"] = int(record.get("wins", 0)) + 1
			var streak := int(record.get("win_streak", 0)) + 1
			record["win_streak"] = streak
			var stars := int(record.get("stars", 0))
			record["stars"] = stars + win_bonus_stars(streak, stars) * multiplier
		"loss":
			record["losses"] = int(record.get("losses", 0)) + 1
			record["win_streak"] = 0
			var stars := int(record.get("stars", 0))
			record["stars"] = maxi(int(_rank_at(stars)["floor_points"]), stars - multiplier)
		"draw":
			record["draws"] = int(record.get("draws", 0)) + 1
			record["win_streak"] = 0

static func summarize(progress: Dictionary, season: int) -> Dictionary:
	advance_to_season(progress, season)
	var points: int = progress["points"]
	var rank := _rank_at(points)
	var peak := _rank_at(int(progress["peak_points"]))
	var active_season: int = progress["season"]
	@warning_ignore("integer_division")
	var year := active_season / 12
	return {
		"season": "%04d-%02d" % [year, active_season % 12 + 1],
		"rank_name": rank["name"],
		"points": points,
		"stars": rank["stars"],
		"stars_required": rank["stars_required"],
		"at_floor": points == int(rank["floor_points"]),
		"peak_rank_name": peak["name"],
		"peak_stars": peak["stars"],
		"win_streak": progress["win_streak"],
		"matches": progress["matches"],
		"last_delta": progress["last_delta"],
	}

static func summarize_bot_stars(total_stars: int) -> Dictionary:
	return _rank_at(maxi(0, total_stars))

static func divisions_for_league(league: int) -> Array:
	return IRON_DIVISIONS if league == 0 else DIVISIONS

static func _rank_at(points: int) -> Dictionary:
	var bronze_start := _league_start(1)
	var league := 0
	if points >= bronze_start:
		@warning_ignore("integer_division")
		league = mini(1 + (points - bronze_start) / _stars_per_standard_league(), DIVINE)
	var league_start := _league_start(league)
	if league < DIVINE:
		var stars_in_league := points - league_start
		@warning_ignore("integer_division")
		var division := stars_in_league / STARS_PER_DIVISION
		var floor_points := league_start + (2 * STARS_PER_DIVISION if division >= 2 else 0)
		if league < FIRST_LEAGUE_WITH_STAR_LOSS:
			floor_points = points
		return {
			"name": "%s %s" % [LEAGUES[league], divisions_for_league(league)[division]],
			"league": league,
			"stars": stars_in_league % STARS_PER_DIVISION,
			"stars_required": STARS_PER_DIVISION,
			"floor_points": floor_points,
		}
	return {
		"name": LEAGUES[DIVINE],
		"league": DIVINE,
		"stars": points - league_start,
		"stars_required": 0,
		"floor_points": league_start,
	}

static func _stars_per_standard_league() -> int:
	return DIVISIONS.size() * STARS_PER_DIVISION

static func _league_start(league: int) -> int:
	if league == 0:
		return 0
	return IRON_DIVISIONS.size() * STARS_PER_DIVISION + (league - 1) * _stars_per_standard_league()
