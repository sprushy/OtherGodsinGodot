extends RefCounted

const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const LISTS_PER_GOD := 7
const TRIAL_MATCHES := 7
const EXPLORATION_CHANCE := 0.25
const MATCHMAKING_LEAGUE_TIER_WINDOW := 2
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

func refresh(results: Array[Dictionary]) -> void:
	if _replayed_match_count == results.size():
		_ensure_unique_deck_names()
		return
	var start := _replayed_match_count
	if start <= 0 or start > results.size() or str(results[start - 1]["match_id"]) != _last_replayed_id:
		# Out-of-order worker results need a full replay in finish order.
		start = 0
		_by_god.clear()
	for index in range(start, results.size()):
		_apply_result(results[index])
	_ensure_unique_deck_names()
	_replayed_match_count = results.size()
	_last_replayed_id = str(results.back()["match_id"]) if not results.is_empty() else ""

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
	for entry: Dictionary in decks:
		var deck: Dictionary = entry["deck"]
		var base_name := str(deck.get("deck_name", "")).strip_edges()
		var deck_god := display_god_name(str(entry["god_name"]))
		if _is_generic_bot_name(base_name) or used_names.has(base_name.to_lower()):
			base_name = _make_unique_bot_name(deck_god, deck, used_names)
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
			summary["quarantined"] = list["list_id"] == pool["quarantined_id"]
			lists.append(summary)
		if lists.is_empty():
			continue
		var challenger: Dictionary = pool["challenger"]
		var trial := {}
		if not challenger.is_empty():
			trial = _summarize_list(challenger)
			trial["matches_played"] = challenger["trial_matches"]
		gods.append({"god_name": god_name, "lists": lists, "challenger": trial})
	return {"gods": gods, "list_capacity": LISTS_PER_GOD, "trial_length": TRIAL_MATCHES}

func _summarize_list(list: Dictionary) -> Dictionary:
	return {
		"list_id": list["list_id"],
		"name": list["deck_name"],
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
		"god_name": list["god_name"],
		"wins": int(list.get("wins", 0)),
		"losses": int(list.get("losses", 0)),
		"draws": int(list.get("draws", 0)),
		"stars": int(list.get("stars", 0)),
		"cards": list["cards"].duplicate(),
		"reinforcements": list["reinforcements"].duplicate(),
		"special_setup": list["special_setup"].duplicate(true),
	}

func select_deck(busy_list_ids: Dictionary, rng: RandomNumberGenerator, target_stars: int) -> Dictionary:
	var target_rank := RankedProgressionScript.summarize_bot_stars(target_stars)
	var target_league := int(target_rank["league"])
	var decks_by_league: Dictionary = {}
	for pool: Dictionary in _by_god.values():
		var challenger: Dictionary = pool["challenger"]
		var lists: Array = pool["lists"].duplicate()
		if not challenger.is_empty():
			lists.append(challenger)
		for list: Dictionary in lists:
			if list["list_id"] == pool["quarantined_id"] or busy_list_ids.has(list["list_id"]):
				continue
			var rank := RankedProgressionScript.summarize_bot_stars(int(list["stars"]))
			var league := int(rank["league"])
			var candidates: Array = decks_by_league.get(league, [])
			candidates.append(list)
			decks_by_league[league] = candidates
	var eligible_leagues: Array[int] = []
	for raw_league in decks_by_league.keys():
		var league := int(raw_league)
		if absi(league - target_league) <= MATCHMAKING_LEAGUE_TIER_WINDOW:
			eligible_leagues.append(league)
	if eligible_leagues.is_empty() and not decks_by_league.is_empty():
		var nearest_gap := 1 << 30
		for raw_league in decks_by_league.keys():
			var league := int(raw_league)
			var gap := absi(league - target_league)
			if gap < nearest_gap:
				eligible_leagues.clear()
				nearest_gap = gap
			if gap == nearest_gap:
				eligible_leagues.append(league)
	if eligible_leagues.is_empty():
		return {}
	var selected_league: int = eligible_leagues[rng.randi_range(0, eligible_leagues.size() - 1)]
	var candidates: Array = decks_by_league[selected_league]
	return (candidates[rng.randi_range(0, candidates.size() - 1)] as Dictionary).duplicate(true)

func select_self_play_pair(busy_list_ids: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for pool: Dictionary in _by_god.values():
		var lists: Array = pool["lists"].duplicate()
		if not pool["challenger"].is_empty():
			lists.append(pool["challenger"])
		for list: Dictionary in lists:
			if list["list_id"] != pool["quarantined_id"] and not busy_list_ids.has(list["list_id"]):
				available.append(list)
	var pairs: Array[Array] = []
	var trials: Array[Array] = []
	for i in available.size():
		for j in range(i + 1, available.size()):
			var first := available[i]
			var second := available[j]
			if not can_self_play_pair(first, second):
				continue
			var pair := [first, second]
			pairs.append(pair)
			if _by_god[first["god_name"]]["challenger"] == first or _by_god[second["god_name"]]["challenger"] == second:
				trials.append(pair)
	var candidates := trials if not trials.is_empty() else pairs
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

func _get_played_match_count(list: Dictionary) -> int:
	return int(list.get("wins", 0)) + int(list.get("losses", 0)) + int(list.get("draws", 0))

static func can_self_play_pair(first: Dictionary, second: Dictionary) -> bool:
	var first_rank := RankedProgressionScript.summarize_bot_stars(int(first.get("stars", 0)))
	var second_rank := RankedProgressionScript.summarize_bot_stars(int(second.get("stars", 0)))
	if absi(int(first_rank["league"]) - int(second_rank["league"])) > MATCHMAKING_LEAGUE_TIER_WINDOW:
		return false
	var first_id := str(first.get("list_id", ""))
	return first_id.is_empty() or first_id != str(second.get("list_id", ""))

static func display_god_name(god_name: String) -> String:
	return god_name.get_slice(",", 0)

func can_play_list(god_name: String, list_id: String) -> bool:
	if list_id.is_empty():
		return true
	var pool: Dictionary = _by_god.get(god_name, {})
	if pool.is_empty() or pool["quarantined_id"] == list_id:
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
	var pool: Dictionary = _by_god.get_or_add(god_name, {"lists": [], "challenger": {}, "pending": [], "quarantined_id": ""})
	var lists: Array = pool["lists"]
	var challenger: Dictionary = pool["challenger"]
	if not list_id.is_empty():
		if not challenger.is_empty() and list_id == challenger["list_id"]:
			_update_record(challenger, outcome)
			challenger["trial_matches"] += 1
			if int(challenger["trial_matches"]) == TRIAL_MATCHES:
				_resolve_trial(pool)
			return
		for list: Dictionary in lists:
			if list["list_id"] == list_id:
				_update_record(list, outcome)
				return
		# A match already in flight can finish after its list was retired.
		return
	if outcome != "win" and not bool(result.get("is_self_play", false)):
		return

	var fingerprint := _fingerprint(result)
	for list: Dictionary in lists:
		if list["fingerprint"] == fingerprint:
			_update_record(list, outcome)
			return
	if challenger.get("fingerprint", "") == fingerprint:
		_update_record(challenger, outcome)
		return
	for pending: Dictionary in pool["pending"]:
		if pending["fingerprint"] == fingerprint:
			_update_record(pending, outcome)
			return
	var new_list := {
		"list_id": str(result["match_id"]),
		"fingerprint": fingerprint,
		"god_name": god_name,
		"deck_name": "%s: Challenger" % display_god_name(god_name),
		"cards": result["cards"],
		"reinforcements": result["reinforcements"],
		"special_setup": result["special_setup"],
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"stars": 0,
		"trial_matches": 0,
		"self_play_name": str(result.get("bot_name", "")) if bool(result.get("is_self_play", false)) else "",
	}
	_update_record(new_list, outcome)
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
	var weakest_is_distinct := false
	# Quarantine the weakest list among those with overlapping alternatives first.
	for list: Dictionary in lists:
		var is_distinct := _is_distinct(list, challenger, lists)
		if weakest.is_empty() or (weakest_is_distinct and not is_distinct) \
				or (weakest_is_distinct == is_distinct and _is_stronger(weakest, list)):
			weakest = list
			weakest_is_distinct = is_distinct
	pool["quarantined_id"] = weakest["list_id"]
	pool["challenger"] = challenger

func _update_record(list: Dictionary, outcome: String) -> void:
	match outcome:
		"win":
			list["wins"] += 1
			list["stars"] += 1
		"loss":
			list["losses"] += 1
			var stars := int(list["stars"])
			var rank := RankedProgressionScript.summarize_bot_stars(stars)
			list["stars"] = maxi(int(rank["floor_points"]), stars - 1)
		"draw":
			list["draws"] += 1

func _resolve_trial(pool: Dictionary) -> void:
	var lists: Array = pool["lists"]
	var challenger: Dictionary = pool["challenger"]
	var incumbent_index := 0
	for i in range(lists.size()):
		if lists[i]["list_id"] == pool["quarantined_id"]:
			incumbent_index = i
			break
	var incumbent: Dictionary = lists[incumbent_index]
	var other_lists := lists.duplicate()
	other_lists.remove_at(incumbent_index)
	var challenger_unique := _is_distinct(challenger, incumbent, other_lists)
	var incumbent_unique := _is_distinct(incumbent, challenger, other_lists)
	var replace := challenger_unique if challenger_unique != incumbent_unique else _is_stronger(challenger, incumbent)
	if replace:
		lists[incumbent_index] = challenger
	pool["quarantined_id"] = ""
	pool["challenger"] = {}
	if not pool["pending"].is_empty():
		_start_trial(pool, pool["pending"].pop_front())

func _is_stronger(first: Dictionary, second: Dictionary) -> bool:
	var first_games := int(first["wins"]) + int(first["losses"]) + int(first["draws"])
	var second_games := int(second["wins"]) + int(second["losses"]) + int(second["draws"])
	var first_score := (2 * int(first["wins"]) + int(first["draws"])) * second_games
	var second_score := (2 * int(second["wins"]) + int(second["draws"])) * first_games
	if first_score != second_score:
		return first_score > second_score
	return int(first["stars"]) > int(second["stars"])

func _is_distinct(list: Dictionary, rival: Dictionary, other_lists: Array) -> bool:
	if not _is_over_75_percent_different(list, rival):
		return false
	for other: Dictionary in other_lists:
		if other["list_id"] == list["list_id"]:
			continue
		if not _is_over_75_percent_different(list, other):
			return false
	return true

func _is_over_75_percent_different(first: Dictionary, second: Dictionary) -> bool:
	var first_cards := _card_counts(first)
	var second_cards := _card_counts(second)
	var first_total := 0
	var second_total := 0
	var shared := 0
	for card in first_cards:
		var count := int(first_cards[card])
		first_total += count
		shared += mini(count, int(second_cards.get(card, 0)))
	for count in second_cards.values():
		second_total += int(count)
	return 4 * shared < maxi(first_total, second_total)

func _card_counts(list: Dictionary) -> Dictionary:
	var counts: Dictionary = list["cards"].duplicate()
	counts.erase(list["god_name"])
	for card in list["reinforcements"]:
		counts[card] = int(counts.get(card, 0)) + int(list["reinforcements"][card])
	return counts

func _fingerprint(deck: Dictionary) -> String:
	return JSON.stringify([deck["cards"], deck["reinforcements"], deck["special_setup"]]).sha256_text()

func _name_list(list: Dictionary, other_lists: Array) -> void:
	var self_play_name := str(list.get("self_play_name", ""))
	if not self_play_name.is_empty():
		list["deck_name"] = self_play_name
		return
	var god := display_god_name(list["god_name"])
	var names: Array = NAME_POOLS.get(god, DEFAULT_NAMES)
	var used_names := {}
	for other: Dictionary in other_lists:
		used_names[other["deck_name"]] = true
	for suffix in names:
		var name := "%s: %s" % [god, suffix]
		if not used_names.has(name):
			list["deck_name"] = name
			return
