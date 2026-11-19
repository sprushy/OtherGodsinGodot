extends RefCounted

const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const LISTS_PER_GOD := 7
const EARLY_RETIREMENT_GAMES := 60
const EXPLORATION_CHANCE := 0.25
# How many of the worst bots per god are kept as quarantined bad bots for
# forced matchmaking (Iron V and post-loss Iron/Bronze pairing).
const QUARANTINED_PER_GOD := 1
# Opponents are drawn from the target league and the leagues directly above and
# below it (e.g. Iron, Bronze, or Silver for a Bronze player). When the band has
# no candidates, pairing falls back to the closest available league.
const MATCHMAKING_LEAGUE_TIER_WINDOW := 1
const NAME_POOLS := {
	"Thor": ["Bloodaxe", "Moon", "Stormbreaker", "Thunderhead", "Iron Ram", "Cloudsplitter", "Red Hammer", "Mjolnir's Wake"],
	"Odin": ["Ravenwatch", "Runeweaver", "Grey Wanderer", "Gallows Tree", "Spear of Oaths", "Winter King", "Last Wisdom", "Hanged One"],
	"Baldr": ["Daystar", "Goldbranch", "White Flame", "Dream of Dawn", "Summer Shield", "Bright Oath", "Sunwake", "Mistletoe Oath"],
	"Freyja": ["Amber Tears", "Falcon Mantle", "Goldweaver", "Battlefield Rose", "Witchlight", "Boar's Charge", "Hall of the Slain", "Brisingamen"],
	"Dellingr": ["First Light", "Sunrise Gate", "Crimson Sky", "Dawn Watch", "Horizon", "Daybreak", "Eastern Flame", "Morning Star"],
	"Cernunnos": ["Black Stag", "Briar Crown", "Green Hunt", "Antler Throne", "Hollow Oak", "Wildwood", "Winter Herd", "Horned Guardian"],
	"Guan Yu": ["Jade Dragon", "Red Hare", "Green Crescent", "Iron Oath", "Peach Garden", "Long March", "Banner of Shu", "Five Passes"],
	"Aphrodite Areia": ["Rose of War", "Crimson Kiss", "Seafoam", "Gilded Spear", "Thorn Crown", "Velvet Blade", "Bronze Mirror", "Spartan Grace"],
	"Hermes": ["Winged Sandal", "Crossroads", "Golden Road", "Quickstep", "Night Courier", "Herald", "Thief's Star", "Caduceus Run"],
	"Manannán mac Lir": ["Sea Mist", "Silver Bough", "Wave Rider", "Tidewalker", "Hidden Isle", "White Sail", "Deepwater", "Land of Youth"],
	"Nusku": ["Emberguard", "Night Lantern", "Red Hearth", "Kindling", "Cinder Crown", "Watchfire", "Dawn Torch", "Everflame"],
	"Mummu": ["First Whisper", "Black Water", "Still Depths", "Entropy", "Sunken Word", "Deep Counsel", "Silent Tide", "Apsu's Dream"],
	"Tezcatlipoca": ["Obsidian", "Night Jaguar", "Smoking Glass", "Black Wind", "Starless Sky", "Shadow Step", "Broken Reflection", "Tezcatl's Mirror"],
	"Tiamat": ["Salt Tide", "Deep Coil", "First Sea", "Abyssal Crown", "Chaos Brood", "Black Current", "World Serpent", "Primordial Surge"],
}
const DEFAULT_NAMES := ["Bloodaxe", "Moon", "Iron Crown", "Ember", "Oathkeeper", "Nightfall", "Stormcall", "Northwind"]
const NAME_EPITHETS := [
	"of the First Dawn", "of the Hidden Road", "of the Long Winter", "of the Silver Oath",
	"of the Far Shore", "of the Quiet Flame", "of the Last Star", "of the Deep Rune",
	"of the Red Horizon", "of the Hollow Crown", "of the High Branch", "of the Still Sea",
]

var _by_god: Dictionary = {}
var _replayed_match_count := -1
var _last_replayed_id := ""
var _deck_auditor: Callable
var _eliminated_bot_match_ids: Dictionary = {}
# League (bot tournament) state. While league_mode is active, seeded bot lists
# are exempt from early retirement so they can finish their round-robin.
var _league_mode: bool = false
var _league_list_ids: Array = []

func set_deck_auditor(auditor: Callable) -> void:
	_deck_auditor = auditor

func invalidate_replay() -> void:
	_replayed_match_count = -1
	_last_replayed_id = ""

func refresh(results: Array[Dictionary]) -> void:
	if _replayed_match_count == results.size():
		_ensure_unique_deck_names()
		return
	var start := _replayed_match_count
	if start <= 0 or start > results.size() or str(results[start - 1]["match_id"]) != _last_replayed_id:
		# Out-of-order worker results need a full replay in finish order.
		start = 0
		_by_god.clear()
		_eliminated_bot_match_ids.clear()
	for index in range(start, results.size()):
		results[index].erase("bot_eliminated")
	for index in range(start, results.size()):
		_apply_result(results[index])
	_ensure_unique_deck_names()
	_replayed_match_count = results.size()
	_last_replayed_id = str(results.back()["match_id"]) if not results.is_empty() else ""

func get_eliminated_bot_match_ids() -> Dictionary:
	return _eliminated_bot_match_ids.duplicate()

func _ensure_unique_deck_names() -> void:
	var decks: Array[Dictionary] = []
	for god_name in _by_god:
		var pool: Dictionary = _by_god[god_name]
		for list: Dictionary in pool["lists"]:
			decks.append({"god_name": str(god_name), "deck": list})
		var challenger: Dictionary = pool["challenger"]
		if not challenger.is_empty():
			decks.append({"god_name": str(god_name), "deck": challenger})
	decks.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_deck: Dictionary = first["deck"]
		var second_deck: Dictionary = second["deck"]
		if str(first["god_name"]) != str(second["god_name"]):
			return str(first["god_name"]) < str(second["god_name"])
		var first_id := str(first_deck.get("list_id", first_deck.get("fingerprint", "")))
		var second_id := str(second_deck.get("list_id", second_deck.get("fingerprint", "")))
		if first_id != second_id:
			return first_id < second_id
		return str(first_deck.get("fingerprint", "")) < str(second_deck.get("fingerprint", ""))
	)
	var used_names := {}
	var needs_name: Array[Dictionary] = []
	for entry: Dictionary in decks:
		var deck: Dictionary = entry["deck"]
		var base_name := str(deck.get("deck_name", "")).strip_edges()
		if _is_generic_bot_name(base_name) or used_names.has(base_name.to_lower()):
			needs_name.append(entry)
			continue
		used_names[base_name.to_lower()] = true
	for entry: Dictionary in needs_name:
		var deck: Dictionary = entry["deck"]
		var deck_god := display_god_name(str(entry["god_name"]))
		var base_name := _make_unique_bot_name(deck_god, deck, used_names)
		deck["deck_name"] = base_name
		used_names[base_name.to_lower()] = true

func _is_generic_bot_name(name: String) -> bool:
	var normalized := name.strip_edges().to_lower()
	return normalized.is_empty() or normalized.contains("challenger")

func _make_unique_bot_name(god_name: String, deck: Dictionary, used_names: Dictionary) -> String:
	var names: Array = NAME_POOLS.get(god_name, DEFAULT_NAMES)
	var candidate := ""
	for name_part in names:
		candidate = "%s: %s" % [god_name, str(name_part)]
		if not used_names.has(candidate.to_lower()):
			return candidate
	for name_part in names:
		for epithet in NAME_EPITHETS:
			candidate = "%s: %s %s" % [god_name, str(name_part), str(epithet)]
			if not used_names.has(candidate.to_lower()):
				return candidate
	var identity := str(deck.get("list_id", deck.get("fingerprint", "bot"))).sha256_text().substr(0, 8)
	candidate = "%s: %s · %s" % [god_name, str(names[0]) if not names.is_empty() else "Wanderer", identity]
	var suffix := 1
	while used_names.has(candidate.to_lower()):
		candidate = "%s: %s · %s-%d" % [god_name, str(names[0]) if not names.is_empty() else "Wanderer", identity, suffix]
		suffix += 1
	return candidate

func get_ladder_summary() -> Dictionary:
	var gods: Array[Dictionary] = []
	var god_names := _by_god.keys()
	god_names.sort()
	for god_name in god_names:
		var pool: Dictionary = _by_god[god_name]
		var lists: Array[Dictionary] = []
		for list: Dictionary in pool["lists"]:
			var summary := _summarize_list(list)
			summary["quarantined"] = _is_quarantined_list(pool, list["list_id"])
			lists.append(summary)
		if lists.is_empty():
			continue
		var challenger: Dictionary = pool["challenger"]
		var trial := {}
		if not challenger.is_empty():
			trial = _summarize_list(challenger)
			trial["matches_played"] = _get_played_match_count(challenger)
			trial["trial_length"] = int(challenger["trial_target_games"])
		gods.append({"god_name": god_name, "lists": lists, "challenger": trial})
	return {"gods": gods, "list_capacity": LISTS_PER_GOD}

func set_league_mode(enabled: bool) -> void:
	_league_mode = bool(enabled)
	if not _league_mode:
		_league_list_ids.clear()

func _league_next_index(god_name: String) -> int:
	var count := 0
	for key in _by_god.keys():
		if str(key) != str(god_name):
			continue
		for list: Dictionary in _by_god[key].get("lists", []):
			if bool(list.get("league_list", false)):
				count += 1
	return count

# Registers a pre-built tournament bot list under a stable id. Match results are
# matched to these lists by fingerprint during pool replay, so their records
# accumulate here instead of spawning throwaway challengers. Exempt from early
# retirement so the round-robin can complete.
# If `explicit_list_id` is provided, that id is used instead of generating one —
# used by rebuild_league_records to preserve ids that match history references.
func register_league_list(god_name: String, deck: Dictionary, explicit_list_id: String = "") -> String:
	if deck.is_empty() or deck.get("cards", {}).is_empty():
		return ""
	var list_id := explicit_list_id
	if list_id.is_empty():
		list_id = "league_%s_%03d" % [str(god_name), _league_next_index(str(god_name))]
	var pool: Dictionary = _by_god.get_or_add(str(god_name), {"lists": [], "challenger": {}, "pending": [], "quarantined_id": "", "quarantined_ids": [], "quarantined_lists": []})
	for existing: Dictionary in pool.get("lists", []):
		if existing.get("list_id", "") == list_id:
			return list_id
	var new_list := {
		"list_id": list_id,
		"fingerprint": _fingerprint(deck),
		"god_name": str(god_name),
		"deck_name": str(deck.get("deck_name", "%s Bot" % str(god_name))),
		"cards": deck.get("cards", {}).duplicate(true),
		"reinforcements": deck.get("reinforcements", {}).duplicate(true),
		"special_setup": deck.get("special_setup", {}).duplicate(true),
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"stars": 0,
		"win_streak": 0,
		"self_play_name": "",
		"owner_name": "",
		"league_list": true,
	}
	pool.get("lists", []).append(new_list)
	_league_list_ids.append(list_id)
	_league_mode = true
	return list_id

func finalize_league(god_names: Array[String]) -> Dictionary:
	# Keeps every seeded bot on the ladder (pre-existing ranked bots plus all
	# new tournament bots), clears their tournament flags, and marks the weakest
	# seeded bot of each god as quarantined for forced matchmaking (Iron V and
	# post-loss Iron/Bronze pairing). Nothing is removed.
	var summary: Dictionary = {}
	for god_name in god_names:
		var pool: Dictionary = _by_god.get(str(god_name), {})
		if pool.is_empty():
			continue
		var all_lists: Array = pool.get("lists", []) as Array
		if all_lists.is_empty():
			continue
		var league_lists: Array = []
		for list: Dictionary in all_lists:
			if bool(list.get("league_list", false)):
				league_lists.append(list)
		if league_lists.is_empty():
			continue
		league_lists.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			return _is_stronger_record(second, first)
		)
		var best: Dictionary = league_lists[0]
		var worst: Dictionary = league_lists.back()
		var best_list_id := str(best.get("list_id", ""))
		var worst_list_id := str(worst.get("list_id", ""))
		# Clear the tournament flag on every seeded bot so they are normal
		# ladder-eligible bots going forward.
		for list: Dictionary in league_lists:
			list.erase("league_list")
			_league_list_ids.erase(str(list.get("list_id", "")))
		# Mark the weakest seeded bot as quarantined for forced matchmaking.
		pool["quarantined_lists"] = [worst.duplicate(true)]
		pool["quarantined_ids"] = [worst_list_id] if not worst_list_id.is_empty() else []
		pool["quarantined_id"] = worst_list_id
		# All lists (regular + seeded) stay in the pool and appear on the ladder.
		pool["lists"] = all_lists
		var challenger: Dictionary = pool.get("challenger", {})
		if not challenger.is_empty() and str(challenger.get("list_id", "")) == worst_list_id:
			pool["challenger"] = {}
		if _league_list_ids.is_empty():
			_league_mode = false
		summary[str(god_name)] = {
			"kept": str(best.get("deck_name", "")),
			"kept_list_id": best_list_id,
			"kept_wins": int(best.get("wins", 0)),
			"kept_losses": int(best.get("losses", 0)),
			"kept_stars": int(best.get("stars", 0)),
			"quarantined": str(worst.get("deck_name", "")),
			"quarantined_list_id": worst_list_id,
			"quarantined_stars": int(worst.get("stars", 0)),
			"seeded_count": league_lists.size(),
			"total_lists": all_lists.size(),
		}
	return summary

# Removes all seeded league bots (identified by list_id starting with "league_").
# Used to clear out 0-0-0 bots left over from an accidental or premature finalize.
func clear_league_bots() -> Dictionary:
	var removed_by_god: Dictionary = {}
	var total_removed := 0
	for god_name in _by_god.keys():
		var pool: Dictionary = _by_god[god_name]
		if pool.is_empty():
			continue
		var lists: Array = pool.get("lists", []) as Array
		var surviving: Array = []
		for list: Dictionary in lists:
			var list_id := str(list.get("list_id", ""))
			if list_id.begins_with("league_"):
				if str(pool.get("quarantined_id", "")) == list_id:
					pool["quarantined_id"] = ""
				if list_id in pool.get("quarantined_ids", []):
					var qids: Array = pool.get("quarantined_ids", []) as Array
					qids.erase(list_id)
					pool["quarantined_ids"] = qids
				var qlists: Array = pool.get("quarantined_lists", []) as Array
				var q_found := -1
				for i in range(qlists.size()):
					if str(qlists[i].get("list_id", "")) == list_id:
						q_found = i
						break
				if q_found >= 0:
					qlists.remove_at(q_found)
					pool["quarantined_lists"] = qlists
				total_removed += 1
				var removed_list: Array = removed_by_god.get(god_name, [])
				if not (removed_list is Array):
					removed_list = []
				removed_list.append(str(list.get("deck_name", "")))
				removed_by_god[god_name] = removed_list
			else:
				surviving.append(list)
		pool["lists"] = surviving
		var challenger: Dictionary = pool.get("challenger", {})
		if not challenger.is_empty() and str(challenger.get("list_id", "")).begins_with("league_"):
			pool["challenger"] = {}
	# Clear any remaining league list ids that pointed to removed bots.
	var cleaned_ids: Array = []
	for id in _league_list_ids:
		var id_str := str(id)
		var still_exists := false
		for pool: Dictionary in _by_god.values():
			for list: Dictionary in pool.get("lists", []):
				if str(list.get("list_id", "")) == id_str:
					still_exists = true
					break
			if still_exists:
				break
		if still_exists:
			cleaned_ids.append(id)
	_league_list_ids = cleaned_ids
	return {"success": true, "removed": total_removed, "removed_by_god": removed_by_god}

# Dumps all bot deck results from match history for debugging. Shows list_ids,
# gods, and outcomes so you can verify results are being stored.
func dump_bot_deck_results(results: Array[Dictionary]) -> Dictionary:
	var league_count := 0
	var non_league_count := 0
	for result in results:
		var list_id := str(result.get("list_id", ""))
		if _is_league_bot_list_id(list_id):
			league_count += 1
			print("[Bot League Debug] RESULT: %s | %s | %s | %s" % [
				list_id, str(result.get("god_name", "")), str(result.get("result", "")), str(result.get("bot_name", ""))])
		else:
			non_league_count += 1
	print("[Bot League Debug] dump: %d total results, %d league, %d non-league" % [results.size(), league_count, non_league_count])
	return {"success": true, "total": results.size(), "league_count": league_count, "non_league_count": non_league_count}

# Replays all bot match results into league bots, re-registering any league
# bots that were culled (e.g. by a premature destructive finalize) but still
# have results in match history. Returns how many were re-registered and how
# many results were replayed.
#
# Clears _by_god and rebuilds from scratch (like refresh()), but re-registers
# league bots with their original league_ list_ids before replaying results.
# _apply_result then finds them by list_id and updates their records. This is
# idempotent: calling it multiple times produces the same ladder state.
# _apply_result finds existing bots by list_id or fingerprint and updates them,
# or creates new entries as needed. This preserves league_ list_ids.
func rebuild_league_records(results: Array[Dictionary]) -> Dictionary:
	_by_god.clear()
	_eliminated_bot_match_ids.clear()
	# Group results by list_id for the re-registration pass.
	var results_by_list: Dictionary = {}
	for result in results:
		var list_id := str(result.get("list_id", ""))
		if not list_id.is_empty():
			var bucket: Array = results_by_list.get(list_id, [])
			bucket.append(result)
			results_by_list[list_id] = bucket
	# Count league results.
	var league_result_count := 0
	for list_id in results_by_list.keys():
		if _is_league_bot_list_id(list_id):
			league_result_count += results_by_list[list_id].size()
	print("[Bot League Debug] rebuild_league_records: %d total results, %d with league list_ids" % [results.size(), league_result_count])
	# First pass: re-register any league bots that have results but are missing from the pool.
	var re_registered := 0
	for list_id in results_by_list.keys():
		if not _is_league_bot_list_id(list_id):
			continue
		var found := false
		for pool: Dictionary in _by_god.values():
			for list: Dictionary in pool.get("lists", []):
				if str(list.get("list_id", "")) == list_id:
					found = true
					break
			if found:
				break
			if str(pool.get("quarantined_id", "")) == list_id:
				found = true
				break
		if not found:
			var result: Dictionary = results_by_list[list_id][0]
			var god_name := str(result.get("god_name", ""))
			var deck: Dictionary = {
				"deck_name": str(result.get("bot_name", "")),
				"cards": result.get("cards", {}),
				"reinforcements": result.get("reinforcements", {}),
				"special_setup": result.get("special_setup", {}),
				"god_name": god_name,
			}
			var new_list_id := register_league_list(god_name, deck, list_id)
			if not new_list_id.is_empty():
				re_registered += 1
				print("[Bot League Debug] re-registered %s as %s (%s)" % [str(result.get("bot_name", "")), list_id, god_name])
	# Second pass: apply all results via _apply_result, which finds existing
	# bots by list_id/fingerprint and updates them (or creates new entries).
	# Does NOT clear _by_god, so league_ list_ids are preserved.
	var applied := 0
	for result: Dictionary in results:
		_apply_result(result)
		applied += 1
	# Diagnostic: show what each league bot looks like after applying results.
	for pool: Dictionary in _by_god.values():
		for list: Dictionary in pool.get("lists", []):
			var lid := str(list.get("list_id", ""))
			if _is_league_bot_list_id(lid):
				print("[Bot League Debug] after rebuild: %s (%s) - %d-%d-%d, %d ★" % [
					str(list.get("deck_name", "")), lid,
					int(list.get("wins", 0)), int(list.get("losses", 0)), int(list.get("draws", 0)),
					int(list.get("stars", 0))])
	return {"success": true, "re_registered": re_registered, "replayed": applied, "league_result_count": league_result_count}

func _is_league_bot_list_id(list_id: String) -> bool:
	return str(list_id).begins_with("league_")

static func _played_matches(list: Dictionary) -> int:
	return int(list.get("wins", 0)) + int(list.get("losses", 0)) + int(list.get("draws", 0))

func _league_bot_summary(list: Dictionary) -> Dictionary:
	return {
		"deck_name": str(list.get("deck_name", "")),
		"list_id": str(list.get("list_id", "")),
		"wins": int(list.get("wins", 0)),
		"losses": int(list.get("losses", 0)),
		"draws": int(list.get("draws", 0)),
		"stars": int(list.get("stars", 0)),
		"matches": _played_matches(list),
	}

func get_league_status() -> Dictionary:
	# Reports only seeded league bots (list ids starting with "league_") and how
	# many matches each has played. Pre-existing ranked bots are not reported.
	var gods: Array = []
	var total_bots := 0
	var total_matches := 0
	for god_name in _by_god.keys():
		var pool: Dictionary = _by_god[god_name]
		var league_bots: Array = []
		for list: Dictionary in pool.get("lists", []):
			if _is_league_bot_list_id(str(list.get("list_id", ""))):
				league_bots.append(_league_bot_summary(list))
		for list: Dictionary in pool.get("quarantined_lists", []):
			if _is_league_bot_list_id(str(list.get("list_id", ""))):
				league_bots.append(_league_bot_summary(list))
		league_bots.sort_custom(func(first, second): return _is_stronger_record(second, first))
		var god_matches := 0
		for bot in league_bots:
			god_matches += int(bot["matches"])
		total_bots += league_bots.size()
		total_matches += god_matches
		var best := {}
		if not league_bots.is_empty():
			best = league_bots[0]
		gods.append({
			"god_name": str(god_name),
			"league_bots": league_bots,
			"bot_count": league_bots.size(),
			"matches_played": god_matches,
			"best": best,
		})
	return {"league_mode": _league_mode, "gods": gods, "total_bots": total_bots, "total_matches": total_matches}

static func _is_stronger_record(first: Dictionary, second: Dictionary) -> bool:
	if int(first.get("stars", 0)) != int(second.get("stars", 0)):
		return int(first.get("stars", 0)) > int(second.get("stars", 0))
	var first_games := int(first.get("wins", 0)) + int(first.get("losses", 0))
	var second_games := int(second.get("wins", 0)) + int(second.get("losses", 0))
	var first_score := int(first.get("wins", 0)) * second_games
	var second_score := int(second.get("wins", 0)) * first_games
	if first_score != second_score:
		return first_score > second_score
	return str(first.get("deck_name", "")).nocasecmp_to(str(second.get("deck_name", ""))) < 0

func _summarize_list(list: Dictionary) -> Dictionary:
	return {
		"list_id": list["list_id"],
		"name": list["deck_name"],
		"owner_name": str(list.get("owner_name", "")),
		"stars": list["stars"],
		"wins": list["wins"],
		"losses": list["losses"],
		"draws": list["draws"],
	}

func get_deck_details(list_id: String) -> Dictionary:
	if list_id.is_empty():
		return {}
	for pool: Dictionary in _by_god.values():
		var challenger: Dictionary = pool["challenger"]
		if challenger.get("list_id", "") == list_id:
			return _deck_details(challenger)
		for list: Dictionary in pool["lists"]:
			if list["list_id"] == list_id:
				return _deck_details(list)
	return {}

func _deck_details(list: Dictionary) -> Dictionary:
	return {
		"list_id": list["list_id"],
		"name": list["deck_name"],
		"deck_name": list["deck_name"],
		"owner_name": str(list.get("owner_name", "")),
		"god_name": list["god_name"],
		"wins": int(list.get("wins", 0)),
		"losses": int(list.get("losses", 0)),
		"draws": int(list.get("draws", 0)),
		"stars": int(list.get("stars", 0)),
		"win_streak": int(list.get("win_streak", 0)),
		"cards": list["cards"].duplicate(),
		"reinforcements": list["reinforcements"].duplicate(),
		"special_setup": list["special_setup"].duplicate(true),
	}

func select_deck(busy_list_ids: Dictionary, rng: RandomNumberGenerator, target_stars: int, force_quarantined: bool = false) -> Dictionary:
	var target_rank := RankedProgressionScript.summarize_bot_stars(target_stars)
	var target_league := int(target_rank["league"])
	if force_quarantined:
		# Pair against a quarantined bad bot only, preferring the target's
		# league band so the match is winnable but not trivial.
		return _select_quarantined_deck(busy_list_ids, rng, target_league)
	var band_candidates: Array = []
	var candidates_by_gap: Dictionary = {}
	for pool: Dictionary in _by_god.values():
		var challenger: Dictionary = pool["challenger"]
		var lists: Array = pool["lists"].duplicate()
		if not challenger.is_empty():
			lists.append(challenger)
		for list: Dictionary in lists:
			if bool(list.get("league_list", false)) or _is_quarantined_list(pool, list["list_id"]) or busy_list_ids.has(list["list_id"]):
				continue
			var gap := absi(_league_for_stars(int(list["stars"])) - target_league)
			if gap <= MATCHMAKING_LEAGUE_TIER_WINDOW:
				band_candidates.append(list)
				continue
			var bucket: Array = candidates_by_gap.get(gap, [])
			bucket.append(list)
			candidates_by_gap[gap] = bucket
	var candidates: Array = band_candidates
	if candidates.is_empty() and not candidates_by_gap.is_empty():
		candidates = candidates_by_gap[_closest_gap(candidates_by_gap)]
	if candidates.is_empty():
		return {}
	# Every opponent in the band is an equally likely pick, regardless of league.
	return (candidates[rng.randi_range(0, candidates.size() - 1)] as Dictionary).duplicate(true)

func _select_quarantined_deck(busy_list_ids: Dictionary, rng: RandomNumberGenerator, target_league: int) -> Dictionary:
	var band_candidates: Array = []
	var candidates_by_gap: Dictionary = {}
	for pool: Dictionary in _by_god.values():
		for list: Dictionary in pool.get("quarantined_lists", []):
			var list_id := str(list.get("list_id", ""))
			if busy_list_ids.has(list_id):
				continue
			var gap := absi(_league_for_stars(int(list["stars"])) - target_league)
			if gap <= MATCHMAKING_LEAGUE_TIER_WINDOW:
				band_candidates.append(list)
				continue
			var bucket: Array = candidates_by_gap.get(gap, [])
			bucket.append(list)
			candidates_by_gap[gap] = bucket
	var candidates: Array = band_candidates
	if candidates.is_empty() and not candidates_by_gap.is_empty():
		candidates = candidates_by_gap[_closest_gap(candidates_by_gap)]
	if candidates.is_empty():
		return {}
	return (candidates[rng.randi_range(0, candidates.size() - 1)] as Dictionary).duplicate(true)

func _is_quarantined_list(pool: Dictionary, list_id: String) -> bool:
	if list_id == pool.get("quarantined_id", ""):
		return true
	return list_id in pool.get("quarantined_ids", [])

func _find_list_by_id(pool: Dictionary, list_id: String) -> Dictionary:
	var challenger: Dictionary = pool.get("challenger", {})
	if not challenger.is_empty() and challenger.get("list_id", "") == list_id:
		return challenger
	for list: Dictionary in pool.get("lists", []):
		if list.get("list_id", "") == list_id:
			return list
	for pending: Dictionary in pool.get("pending", []):
		if pending.get("list_id", "") == list_id:
			return pending
	return {}

func select_self_play_pair(busy_list_ids: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for pool: Dictionary in _by_god.values():
		var lists: Array = pool["lists"].duplicate()
		if not pool["challenger"].is_empty():
			lists.append(pool["challenger"])
		for list: Dictionary in lists:
			if not _is_quarantined_list(pool, list["list_id"]) and not busy_list_ids.has(list["list_id"]):
				available.append(list)
	var pairs_by_gap: Dictionary = {}
	var trials_by_gap: Dictionary = {}
	for i in available.size():
		for j in range(i + 1, available.size()):
			var first := available[i]
			var second := available[j]
			var first_id := str(first.get("list_id", ""))
			if not first_id.is_empty() and first_id == str(second.get("list_id", "")):
				continue
			var gap := absi(_league_for_stars(int(first["stars"])) - _league_for_stars(int(second["stars"])))
			var pair := [first, second]
			_append_to_gap_bucket(pairs_by_gap, gap, pair)
			if _by_god[first["god_name"]]["challenger"] == first or _by_god[second["god_name"]]["challenger"] == second:
				_append_to_gap_bucket(trials_by_gap, gap, pair)
	# Prefer pairs inside the league band, then the closest available gap.
	var selected_gaps: Array = []
	for gap in range(0, MATCHMAKING_LEAGUE_TIER_WINDOW + 1):
		if pairs_by_gap.has(gap):
			selected_gaps.append(gap)
	if selected_gaps.is_empty() and not pairs_by_gap.is_empty():
		selected_gaps.append(_closest_gap(pairs_by_gap))
	if selected_gaps.is_empty():
		return []
	var candidates: Array = []
	var trials: Array = []
	for gap in selected_gaps:
		candidates.append_array(pairs_by_gap[gap])
		if trials_by_gap.has(gap):
			trials.append_array(trials_by_gap[gap])
	if candidates.is_empty() or (trials.is_empty() and rng.randf() < EXPLORATION_CHANCE):
		return []
	var total_weight := 0.0
	var pair_weights: Array[float] = []
	for pair in candidates:
		var first_games := _get_played_match_count(pair[0])
		var second_games := _get_played_match_count(pair[1])
		var weight := 1.0 / sqrt(float((first_games + 1) * (second_games + 1)))
		pair_weights.append(weight)
		total_weight += weight
	var selection := rng.randf() * total_weight
	var selected_pair: Array = candidates.back()
	for index in range(candidates.size()):
		selection -= pair_weights[index]
		if selection <= 0.0:
			selected_pair = candidates[index]
			break
	var selected: Array[Dictionary] = []
	selected.assign(selected_pair.duplicate(true))
	if rng.randi_range(0, 1) == 1:
		selected.reverse()
	return selected

func _append_to_gap_bucket(buckets: Dictionary, gap: int, pair: Array) -> void:
	var bucket: Array = buckets.get(gap, [])
	bucket.append(pair)
	buckets[gap] = bucket

func _closest_gap(buckets: Dictionary) -> int:
	var closest_gap := -1
	for raw_gap in buckets.keys():
		var gap := int(raw_gap)
		if closest_gap < 0 or gap < closest_gap:
			closest_gap = gap
	return closest_gap

static func _league_for_stars(stars: int) -> int:
	return int(RankedProgressionScript.summarize_bot_stars(stars)["league"])

func _get_played_match_count(list: Dictionary) -> int:
	return int(list.get("wins", 0)) + int(list.get("losses", 0)) + int(list.get("draws", 0))

func rank_underrepresented_gods(god_names: Array[String], rng: RandomNumberGenerator, reserved: Dictionary = {}) -> Array[String]:
	var candidates: Array[Dictionary] = []
	for god_name in god_names:
		var pool: Dictionary = _by_god.get(god_name, {})
		var count := (pool.get("lists", []) as Array).size() + int(reserved.get(god_name, 0))
		if count >= LISTS_PER_GOD:
			continue
		candidates.append({"name": god_name, "count": count, "tie": rng.randf()})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first["count"]) != int(second["count"]):
			return int(first["count"]) < int(second["count"])
		return float(first["tie"]) < float(second["tie"])
	)
	var ranked: Array[String] = []
	for candidate in candidates:
		ranked.append(str(candidate["name"]))
	return ranked

static func can_self_play_pair(first: Dictionary, second: Dictionary) -> bool:
	if absi(_league_for_stars(int(first.get("stars", 0))) - _league_for_stars(int(second.get("stars", 0)))) > MATCHMAKING_LEAGUE_TIER_WINDOW:
		return false
	var first_id := str(first.get("list_id", ""))
	return first_id.is_empty() or first_id != str(second.get("list_id", ""))

static func display_god_name(god_name: String) -> String:
	return god_name.get_slice(",", 0)

func can_play_list(god_name: String, list_id: String) -> bool:
	if list_id.is_empty():
		return true
	var pool: Dictionary = _by_god.get(god_name, {})
	if pool.is_empty() or _is_quarantined_list(pool, list_id):
		return false
	if pool["challenger"].get("list_id", "") == list_id:
		return true
	for list: Dictionary in pool["lists"]:
		if list["list_id"] == list_id:
			return true
	return false

func _apply_result(result: Dictionary) -> void:
	var god_name: String = result["god_name"]
	var list_id: String = result["list_id"]
	var outcome: String = result["result"]
	# Losses to human players do not count toward bot evaluation: only self-play
	# results and wins against players shape records, stars, retirement, and
	# trials. Records are rebuilt by replaying history, so this applies
	# retroactively on the next full replay.
	if outcome == "loss" and not bool(result.get("is_self_play", false)):
		return
	var pool: Dictionary = _by_god.get_or_add(god_name, {"lists": [], "challenger": {}, "pending": [], "quarantined_id": "", "quarantined_ids": [], "quarantined_lists": []})
	var lists: Array = pool["lists"]
	var challenger: Dictionary = pool["challenger"]
	var is_community_bot := bool(result.get("is_community_bot", false))
	if not list_id.is_empty():
		if not challenger.is_empty() and list_id == challenger["list_id"]:
			_update_record(challenger, outcome)
			if _get_played_match_count(challenger) >= int(challenger["trial_target_games"]):
				_resolve_trial(pool)
			return
		for list: Dictionary in lists:
			if list["list_id"] == list_id:
				_update_record(list, outcome)
				if list_id == pool["quarantined_id"] and not challenger.is_empty():
					challenger["trial_target_games"] = _get_played_match_count(list)
					return
				if _should_retire_early(list):
					_eliminated_bot_match_ids[str(result.get("match_id", ""))] = true
					result["bot_eliminated"] = true
					_retire_list(pool, list)
				return
		if not is_community_bot:
			# A match already in flight can finish after its list was retired.
			return
		# A community bot's first ladder result adopts its submitting bot id, so
		# later results and recent-match lookups resolve the same ladder entry.
	elif outcome != "win" and not bool(result.get("is_self_play", false)):
		return

	var audited_result := result.duplicate(true)
	if _deck_auditor.is_valid():
		var audited_deck: Dictionary = _deck_auditor.call({
			"list_id": str(result.get("match_id", "")),
			"deck_name": str(result.get("bot_name", "")),
			"god_name": god_name,
			"cards": result.get("cards", {}).duplicate(true),
			"reinforcements": result.get("reinforcements", {}).duplicate(true),
			"special_setup": result.get("special_setup", {}).duplicate(true),
		})
		if audited_deck.is_empty():
			return
		audited_result["cards"] = audited_deck.get("cards", {}).duplicate(true)
		audited_result["reinforcements"] = audited_deck.get("reinforcements", {}).duplicate(true)
		audited_result["special_setup"] = audited_deck.get("special_setup", {}).duplicate(true)
	var fingerprint := _fingerprint(audited_result)
	for list: Dictionary in lists:
		if list["fingerprint"] == fingerprint:
			_update_record(list, outcome)
			if list["list_id"] == pool["quarantined_id"] and not challenger.is_empty():
				challenger["trial_target_games"] = _get_played_match_count(list)
				return
			if _should_retire_early(list):
				_eliminated_bot_match_ids[str(result.get("match_id", ""))] = true
				result["bot_eliminated"] = true
				_retire_list(pool, list)
			return
	if challenger.get("fingerprint", "") == fingerprint:
		_update_record(challenger, outcome)
		if _get_played_match_count(challenger) >= int(challenger["trial_target_games"]):
			_resolve_trial(pool)
		return
	for pending: Dictionary in pool["pending"]:
		if pending["fingerprint"] == fingerprint:
			_update_record(pending, outcome)
			if _should_retire_early(pending):
				pool["pending"].erase(pending)
			return
	var bot_name := str(result.get("bot_name", "")).strip_edges()
	var owner_name := str(result.get("owner_name", "")).strip_edges()
	if owner_name.is_empty():
		# Community results recorded before explicit owner attribution stored
		# the creator inside the deck name ("Owner's Bot").
		var separator := bot_name.find("'s ")
		if separator > 0:
			owner_name = bot_name.substr(0, separator).strip_edges()
			bot_name = bot_name.substr(separator + 3).strip_edges()
	var self_play_name := ""
	if bool(result.get("is_self_play", false)) and not bot_name.is_empty():
		self_play_name = bot_name
		if not self_play_name.begins_with("%s: " % display_god_name(god_name)):
			self_play_name = "%s: %s" % [display_god_name(god_name), self_play_name]
	var adopted_list_id := str(result["match_id"])
	if is_community_bot and not list_id.is_empty():
		adopted_list_id = list_id
	var new_list := {
		"list_id": adopted_list_id,
		"fingerprint": fingerprint,
		"god_name": god_name,
		"deck_name": "%s: Challenger" % display_god_name(god_name),
		"cards": audited_result["cards"],
		"reinforcements": audited_result["reinforcements"],
		"special_setup": audited_result["special_setup"],
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"stars": 0,
		"win_streak": 0,
		"self_play_name": self_play_name,
		"owner_name": owner_name,
	}
	_update_record(new_list, outcome)
	if _should_retire_early(new_list):
		return
	if lists.size() < LISTS_PER_GOD:
		_name_list(new_list, lists)
		lists.append(new_list)
		return
	if not challenger.is_empty():
		if outcome == "win":
			pool["pending"].append(new_list)
		return
	if outcome == "win":
		_start_trial(pool, new_list)

func _start_trial(pool: Dictionary, challenger: Dictionary) -> void:
	var lists: Array = pool["lists"]
	_name_list(challenger, lists)
	var weakest: Dictionary = {}
	# Challenge the lowest-ranked incumbent of this god.
	for list: Dictionary in lists:
		if weakest.is_empty() or _is_higher_ranked(weakest, list):
			weakest = list
	pool["quarantined_id"] = weakest["list_id"]
	challenger["trial_target_games"] = _get_played_match_count(weakest)
	pool["challenger"] = challenger
	if _get_played_match_count(challenger) >= int(challenger["trial_target_games"]):
		_resolve_trial(pool)

func _update_record(list: Dictionary, outcome: String) -> void:
	# Records are rebuilt by replaying the full stored result history in finish
	# order, so rule changes here apply retroactively on the next full replay.
	RankedProgressionScript.apply_bot_result(list, outcome)

func _should_retire_early(list: Dictionary) -> bool:
	# Seeded tournament bots must finish their round-robin, so they are never
	# retired early while league mode is active.
	if str(list.get("list_id", "")) in _league_list_ids:
		return false
	var games_played := _get_played_match_count(list)
	if games_played <= 0 or games_played > EARLY_RETIREMENT_GAMES:
		return false
	return 3 * int(list["losses"]) >= 2 * games_played

func _retire_list(pool: Dictionary, list: Dictionary) -> void:
	var list_id := str(list.get("list_id", ""))
	if list_id.is_empty():
		return
	if pool["challenger"].get("list_id", "") == list_id:
		pool["challenger"] = {}
		pool["quarantined_id"] = ""
		if not pool["pending"].is_empty():
			_start_trial(pool, pool["pending"].pop_front())
		return
	var lists: Array = pool["lists"]
	var was_quarantined := str(pool["quarantined_id"]) == list_id
	lists.erase(list)
	if was_quarantined:
		pool["quarantined_id"] = ""
		var challenger: Dictionary = pool["challenger"]
		if not challenger.is_empty():
			lists.append(challenger)
			pool["challenger"] = {}
	if pool["challenger"].is_empty() and not pool["pending"].is_empty():
		if lists.size() < LISTS_PER_GOD:
			var pending: Dictionary = pool["pending"].pop_front()
			_name_list(pending, lists)
			lists.append(pending)
		elif was_quarantined:
			_start_trial(pool, pool["pending"].pop_front())

func _resolve_trial(pool: Dictionary) -> void:
	var lists: Array = pool["lists"]
	var challenger: Dictionary = pool["challenger"]
	var incumbent_index := 0
	for i in range(lists.size()):
		if lists[i]["list_id"] == pool["quarantined_id"]:
			incumbent_index = i
			break
	var incumbent: Dictionary = lists[incumbent_index]
	if _has_stronger_record(challenger, incumbent):
		lists[incumbent_index] = challenger
	pool["quarantined_id"] = ""
	pool["challenger"] = {}
	if not pool["pending"].is_empty():
		_start_trial(pool, pool["pending"].pop_front())

func _is_higher_ranked(first: Dictionary, second: Dictionary) -> bool:
	if int(first["stars"]) != int(second["stars"]):
		return int(first["stars"]) > int(second["stars"])
	var first_games := int(first["wins"]) + int(first["losses"])
	var second_games := int(second["wins"]) + int(second["losses"])
	var first_record_score := int(first["wins"]) * second_games
	var second_record_score := int(second["wins"]) * first_games
	if first_record_score != second_record_score:
		return first_record_score > second_record_score
	return str(first["deck_name"]).nocasecmp_to(str(second["deck_name"])) < 0

func _has_stronger_record(first: Dictionary, second: Dictionary) -> bool:
	var first_games := int(first["wins"]) + int(first["losses"]) + int(first["draws"])
	var second_games := int(second["wins"]) + int(second["losses"]) + int(second["draws"])
	var first_score := (2 * int(first["wins"]) + int(first["draws"])) * second_games
	var second_score := (2 * int(second["wins"]) + int(second["draws"])) * first_games
	return first_score > second_score

func _fingerprint(deck: Dictionary) -> String:
	return JSON.stringify([deck["cards"], deck["reinforcements"], deck["special_setup"]]).sha256_text()

func _name_list(list: Dictionary, other_lists: Array) -> void:
	var self_play_name := str(list.get("self_play_name", ""))
	var god := display_god_name(list["god_name"])
	var names: Array = NAME_POOLS.get(god, DEFAULT_NAMES)
	var used_names := {}
	for other: Dictionary in other_lists:
		used_names[str(other["deck_name"]).to_lower()] = true
	if not _is_generic_bot_name(self_play_name) and not used_names.has(self_play_name.to_lower()):
		list["deck_name"] = self_play_name
		return
	for suffix in names:
		var name := "%s: %s" % [god, suffix]
		if not used_names.has(name.to_lower()):
			list["deck_name"] = name
			return
