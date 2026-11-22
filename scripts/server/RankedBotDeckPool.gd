extends RefCounted

const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const LISTS_PER_GOD := 14
const EARLY_RETIREMENT_GAMES := 60
const EXPLORATION_CHANCE := 0.20
# How many of the worst bots per god are kept as quarantined bad bots for
# forced matchmaking (Iron V and post-loss Iron/Bronze pairing).
const QUARANTINED_PER_GOD := 1
# Opponents are drawn from the target league and the leagues directly above and
# below it (e.g. Iron, Bronze, or Silver for a Bronze player). When the band has
# no candidates, pairing falls back to the closest available league.
const MATCHMAKING_LEAGUE_TIER_WINDOW := 1
const NAME_POOLS := {
	"Thor": [
		"Bloodaxe", "Moon", "Stormbreaker", "Thunderhead",
		"Iron Ram", "Cloudsplitter", "Red Hammer", "Mjolnir's Wake",
		"Goatstorm", "Oakbreaker", "Thunder Road", "Giant's Bane",
		"Copper Lightning", "Mountainfall", "Storm Belt", "Ashen Hammer",
		"Sky Anvil", "Fjord Thunder", "Battering Rain", "Midgard's Ward",
	],
	"Odin": [
		"Ravenwatch", "Runeweaver", "Grey Wanderer", "Gallows Tree",
		"Spear of Oaths", "Winter King", "Last Wisdom", "Hanged One",
		"One-Eyed Guest", "Well of Memory", "Raven's Counsel", "Spear Cast",
		"Nine Nights", "Ashen Gallows", "Wolf Throne", "Gungnir's Mark",
		"Eight Hooves", "The Hooded King", "Mead of Runes", "Valhalla's Call",
	],
	"Baldr": [
		"Daystar", "Goldbranch", "White Flame", "Dream of Dawn",
		"Summer Shield", "Bright Oath", "Sunwake", "Mistletoe Oath",
		"Ivory Gleam", "Fair Radiance", "Hall of Light", "Unbroken Vow",
		"Sunlit Ashes", "Bright Funeral", "Quiet Gleam", "Golden Pyre",
		"Light of Breidablik", "White Garland", "Softest Arrow", "Light Returned",
	],
	"Freyja": [
		"Amber Tears", "Falcon Mantle", "Goldweaver", "Battlefield Rose",
		"Witchlight", "Boar's Charge", "Hall of the Slain", "Brisingamen",
		"Falconflight", "Seer's Gold", "Amber Chariot", "Boar of Battle",
		"Golden Tresses", "Field of the Fallen", "Seidr's Call", "Cat's Grace",
		"Battle Honey", "Gold on the Snow", "Falcon's Descent", "Half the Slain",
	],
	"Dellingr": [
		"First Light", "Sunrise Gate", "Crimson Sky", "Dawn Watch",
		"Horizon", "Daybreak", "Eastern Flame", "Morning Star",
		"Rosy Threshold", "Edge of Morning", "Night's End", "Copper Dawn",
		"Sunrise Herald", "Early Ember", "Break of Gold", "Eastern Gleam",
		"Dewfire", "Waking Sky", "Morning's Promise", "Dawnward",
	],
	"Cernunnos": [
		"Black Stag", "Briar Crown", "Green Hunt", "Antler Throne",
		"Hollow Oak", "Wildwood", "Winter Herd", "Horned Guardian",
		"Moss Crown", "Horn and Torc", "Hart of the Glade", "Fernhide",
		"Rootbound", "Oakshadow", "Silver Antler", "Bramble Hart",
		"Deep Grove", "Serpent's Torc", "Green Hollow", "Forest's Tithe",
	],
	"Guan Yu": [
		"Jade Dragon", "Red Hare", "Green Crescent", "Iron Oath",
		"Peach Garden", "Long March", "Banner of Shu", "Five Passes",
		"Jade General", "Oath of Brotherhood", "Crescent Blade", "Peach Blossom Banner",
		"Swift Red Hooves", "Night Watch of Shu", "Green Robe", "Passbreaker",
		"Warrior's Seal", "Han Loyalist", "Blade Across the Pass", "Three Brothers",
	],
	"Aphrodite Areia": [
		"Rose of War", "Crimson Kiss", "Seafoam", "Gilded Spear",
		"Thorn Crown", "Velvet Blade", "Bronze Mirror", "Spartan Grace",
		"Foam and Steel", "Rosepoint", "Myrtle Shield", "Bronze Embrace",
		"Spear of Desire", "Crimson Myrtle", "Spartan Rose", "War Bride",
		"Thorn Kiss", "Beauty in Bronze", "Silken Aegis", "Rose Standard",
	],
	"Hermes": [
		"Winged Sandal", "Crossroads", "Golden Road", "Quickstep",
		"Night Courier", "Herald", "Thief's Star", "Caduceus Run",
		"Silver Tongue", "Fleetfoot", "The Crooked Mile", "Dawn Dispatch",
		"Swift Coin", "Wayfarer's Luck", "Stolen Herd", "Hidden Milestone",
		"Border Runner", "Winged Cap", "The Kindly Guide", "Lyre of Shell",
	],
	"Hermes Psychopompus": [
		"The Last Passage", "Shepherd of Shades", "The Golden Threshold", "Beyond the Styx",
		"The Souls' Crossing", "Warden of the Veil", "The Final Escort", "Whispers of Asphodel",
		"The Road to Hades", "The Psychopomp's Procession", "Between Two Worlds", "The Wand of Slumber",
		"The Unseen Path", "The Herald of Hades", "Where Shadows Wander", "The Ferryman's Herald",
		"The Gates of No Return", "The Golden Caduceus", "The Gathering of Ghosts", "The Road Beyond Death",
	],
	"Manannán mac Lir": [
		"Sea Mist", "Silver Bough", "Wave Rider", "Tidewalker",
		"Hidden Isle", "White Sail", "Deepwater", "Land of Youth",
		"Wave Sweeper", "Mist Cloak", "Sea Chariot", "Foam Horse",
		"The Far Strand", "Silver Apples", "Isle Behind the Mist", "Grey Current",
		"Orchard Beyond the Sea", "Oarless Voyage", "Keeper of the Veil", "Tide of Silver",
	],
	"Nusku": [
		"Emberguard", "Night Lantern", "Red Hearth", "Kindling",
		"Cinder Crown", "Watchfire", "Dawn Torch", "Everflame",
		"Night Warden", "Temple Lamp", "Ashen Wick", "Sacred Brazier",
		"Firekeeper", "Lantern of Ur", "Ember at the Gate", "Flame of the Vigil",
		"Hearthward", "Cinder Lantern", "Red Wick", "Smoke of Incense",
	],
	"Mummu": [
		"First Whisper", "Black Water", "Still Depths", "Entropy",
		"Sunken Word", "Deep Counsel", "Silent Tide", "Apsu's Dream",
		"Whisper Below", "Abyssal Scribe", "Oldest Counsel", "Veiled Design",
		"Voice in the Deep", "Drowned Thought", "The Unshaped", "Hidden Advisor",
		"Murmur Under Stone", "Thought Before Light", "Depths Awoken", "The Quiet Plot",
	],
	"Tezcatlipoca": [
		"Obsidian", "Night Jaguar", "Smoking Glass", "Black Wind",
		"Starless Sky", "Shadow Step", "Broken Reflection", "Tezcatl's Mirror",
		"Jaguar's Prowl", "Mirror of Night", "Obsidian Claw", "Midnight Pelt",
		"Jaguar Throne", "Smoke Without Flame", "Mirror in Shadow", "The Unseen Wind",
		"Obsidian Eclipse", "The Hidden Footstep", "Smoke and Fangs", "Lord of Near and Far",
	],
	"Tiamat": [
		"Salt Tide", "Deep Coil", "First Sea", "Abyssal Crown",
		"Chaos Brood", "Black Current", "World Serpent", "Primordial Surge",
		"Mother of Monsters", "Saltwater Maw", "Coil Beneath Creation", "Bitter Deep",
		"Broodmother's Wake", "The Sea Unbound", "Salt and Scales", "Mother of the First Waters",
		"Dragon's Undertow", "Teeth of the Deep", "Abyssal Spawn", "Sea Before the Sky",
	],
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
var _assigned_names_by_list_id: Dictionary = {}
var _community_bots_by_id: Dictionary = {}
# Older matches may keep the submission ID after losing the community flag.
var _community_bot_id_pattern := RegEx.create_from_string("^[0-9a-f]{12}_[A-HJ-NP-Z2-9]{12}$")

func set_deck_auditor(auditor: Callable) -> void:
	_deck_auditor = auditor

func refresh(results: Array[Dictionary]) -> void:
	var last_result_id := str(results.back()["match_id"]) if not results.is_empty() else ""
	if _replayed_match_count == results.size() and _last_replayed_id == last_result_id:
		_ensure_unique_deck_names()
		return
	var start := _replayed_match_count
	if start <= 0 or start > results.size() or str(results[start - 1]["match_id"]) != _last_replayed_id:
		# Out-of-order worker results need a full replay in finish order.
		start = 0
		_by_god.clear()
		_eliminated_bot_match_ids.clear()
	for index in range(start, results.size()):
		_apply_result(results[index])
	_ensure_unique_deck_names()
	_replayed_match_count = results.size()
	_last_replayed_id = last_result_id

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

	var used_names := {}
	var needs_name: Array[Dictionary] = []

	# Reserve community display names without changing submission IDs or records.
	for entry: Dictionary in decks:
		var deck: Dictionary = entry["deck"]
		if bool(deck.get("is_community_bot", false)):
			used_names[str(deck["deck_name"]).to_lower()] = true

	# Pass 2: Previously assigned names from _assigned_names_by_list_id
	for entry: Dictionary in decks:
		var deck: Dictionary = entry["deck"]
		if bool(deck.get("is_community_bot", false)):
			continue
		var list_id := str(deck.get("list_id", "")).strip_edges()
		if not list_id.is_empty() and _assigned_names_by_list_id.has(list_id):
			var assigned := str(_assigned_names_by_list_id[list_id]).strip_edges()
			if not _is_generic_bot_name(assigned) and not used_names.has(assigned.to_lower()):
				deck["deck_name"] = assigned
				used_names[assigned.to_lower()] = true

	# Pass 3: Established bots with non-generic names that don't collide
	var non_community: Array[Dictionary] = []
	for entry: Dictionary in decks:
		var deck: Dictionary = entry["deck"]
		var list_id := str(deck.get("list_id", "")).strip_edges()
		if str(deck.get("owner_name", "")).strip_edges().is_empty() and not (not list_id.is_empty() and _assigned_names_by_list_id.has(list_id)):
			non_community.append(entry)

	non_community.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_deck: Dictionary = first["deck"]
		var second_deck: Dictionary = second["deck"]
		if str(first["god_name"]) != str(second["god_name"]):
			return str(first["god_name"]) < str(second["god_name"])
		var first_priority := _bot_name_priority(first_deck)
		var second_priority := _bot_name_priority(second_deck)
		if first_priority != second_priority:
			return first_priority > second_priority
		var first_id := str(first_deck.get("list_id", first_deck.get("fingerprint", "")))
		var second_id := str(second_deck.get("list_id", second_deck.get("fingerprint", "")))
		if first_id != second_id:
			return first_id < second_id
		return str(first_deck.get("fingerprint", "")) < str(second_deck.get("fingerprint", ""))
	)

	for entry: Dictionary in non_community:
		var deck: Dictionary = entry["deck"]
		var list_id := str(deck.get("list_id", "")).strip_edges()
		var base_name := str(deck.get("deck_name", "")).strip_edges()
		if _is_generic_bot_name(base_name) or used_names.has(base_name.to_lower()):
			needs_name.append(entry)
			continue
		used_names[base_name.to_lower()] = true
		if not list_id.is_empty():
			_assigned_names_by_list_id[list_id] = base_name

	# Replace saved numeric fallback names after reserving established names.
	for entry: Dictionary in decks:
		var deck: Dictionary = entry["deck"]
		if not str(deck.get("owner_name", "")).strip_edges().is_empty():
			continue
		var god := display_god_name(str(entry["god_name"]))
		var name := str(deck.get("deck_name", "")).strip_edges()
		if _is_numbered_fallback_name(name, god) and entry not in needs_name:
			needs_name.append(entry)

	# Pass 4: Assign unique names to the bots that need one.
	for entry: Dictionary in needs_name:
		var deck: Dictionary = entry["deck"]
		var list_id := str(deck.get("list_id", "")).strip_edges()
		var deck_god := display_god_name(str(entry["god_name"]))
		var base_name := _make_unique_bot_name(deck_god, deck, used_names)
		deck["deck_name"] = base_name
		used_names[base_name.to_lower()] = true
		if not list_id.is_empty():
			_assigned_names_by_list_id[list_id] = base_name

func _bot_name_priority(deck: Dictionary) -> int:
	if str(deck.get("owner_name", "")).strip_edges() != "":
		return 1000000
	return _get_played_match_count(deck) * 1000

func _is_generic_bot_name(name: String) -> bool:
	var normalized := name.strip_edges().to_lower()
	return normalized.is_empty() or normalized.contains("challenger") or normalized.contains("autofill") or normalized.contains("autofill bot")

func _is_numbered_fallback_name(name: String, god_name: String) -> bool:
	var prefix := "%s: " % god_name
	if not name.begins_with(prefix):
		return false
	var separator := name.rfind(" ")
	if separator < prefix.length():
		return false
	var suffix := name.substr(separator + 1)
	if not suffix.is_valid_int():
		return false
	var number := suffix.to_int()
	if number < 2 or number >= 100 or suffix != str(number):
		return false
	var names: Array = NAME_POOLS.get(god_name, DEFAULT_NAMES)
	return name.substr(prefix.length(), separator - prefix.length()) in names

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

func get_quarantined_ladder_summary() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for god_name in _by_god:
		var pool: Dictionary = _by_god[god_name]
		var held_by_id := {}
		for list: Dictionary in pool.get("quarantined_lists", []):
			held_by_id[list["list_id"]] = list
		var lists_by_id := held_by_id.duplicate()
		for list: Dictionary in pool["lists"]:
			if _is_quarantined_list(pool, list["list_id"]):
				lists_by_id[list["list_id"]] = list
		for list_id in lists_by_id:
			var entry := _summarize_list(lists_by_id[list_id])
			entry["god_name"] = god_name
			entry["quarantine_status"] = "Matchmaking pool" if held_by_id.has(list_id) else "Challenger trial"
			entries.append(entry)
	return entries

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
	_assigned_names_by_list_id[list_id] = new_list["deck_name"]
	_ensure_unique_deck_names()
	return list_id

func sync_community_bots(community_bots_by_id: Dictionary) -> void:
	_community_bots_by_id = community_bots_by_id
	var removed_ids := {}
	var keep := func(list: Dictionary) -> bool:
		var list_id := str(list["list_id"])
		if _is_inactive_community_bot(list, list_id):
			removed_ids[list_id] = true
			_assigned_names_by_list_id.erase(list_id)
			return false
		var submission: Dictionary = _community_bots_by_id.get(list_id, {})
		if not submission.is_empty():
			_apply_community_metadata(list, submission)
		return true
	for god_name in _by_god.keys():
		var pool: Dictionary = _by_god[god_name]
		for key in ["lists", "pending", "quarantined_lists"]:
			pool[key] = (pool.get(key, []) as Array).filter(keep)
		var challenger: Dictionary = pool["challenger"]
		var incumbent_id := str(pool.get("quarantined_id", ""))
		if not challenger.is_empty() and not keep.call(challenger):
			pool["challenger"] = {}
			pool["quarantined_id"] = ""
		elif removed_ids.has(incumbent_id) or _is_inactive_community_bot({}, incumbent_id):
			pool["quarantined_id"] = ""
			if not challenger.is_empty():
				pool["lists"].append(challenger)
				pool["challenger"] = {}
		pool["quarantined_ids"] = (pool.get("quarantined_ids", []) as Array).filter(
			func(id: String) -> bool: return not removed_ids.has(id) and not _is_inactive_community_bot({}, id)
		)

func _is_inactive_community_bot(deck: Dictionary, list_id: String) -> bool:
	return not _community_bots_by_id.has(list_id) and (
		bool(deck.get("is_community_bot", false)) or _community_bot_id_pattern.search(list_id) != null
	)

func _apply_community_metadata(deck: Dictionary, submission: Dictionary) -> void:
	deck["is_community_bot"] = true
	deck["owner_name"] = str(submission.get("owner_name", submission.get("account_id", ""))).strip_edges()
	deck["deck_name"] = str(submission["deck_name"])
	# A submitter can quarantine their own bot. Unlike the system's weak-bot
	# quarantine, this bot must never be paired — not even in forced matchmaking.
	deck["excluded_from_matchmaking"] = bool(submission.get("quarantined", false))
	_assigned_names_by_list_id[deck["list_id"]] = deck["deck_name"]

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

# Dumps the current pool state (all gods, lists, records) to a JSON file for
# offline inspection. Path: server_data/league_pool_dump.json
func dump_pool_state() -> Dictionary:
	var out: Dictionary = {}
	for god_name in _by_god.keys():
		var pool: Dictionary = _by_god[god_name]
		var lists_out: Array = []
		for list in pool.get("lists", []):
			lists_out.append({
				"list_id": str(list.get("list_id", "")),
				"deck_name": str(list.get("deck_name", "")),
				"god_name": str(list.get("god_name", "")),
				"wins": int(list.get("wins", 0)),
				"losses": int(list.get("losses", 0)),
				"draws": int(list.get("draws", 0)),
				"stars": int(list.get("stars", 0)),
				"league_list": bool(list.get("league_list", false)),
			})
		out[str(god_name)] = lists_out
	var path := ServerPathsScript.get_server_data_file_path("league_pool_dump.json")
	var ok := JsonStoreScript.save_json(path, out, "RankedBotDeckPool")
	print("[Bot League Debug] pool state dumped to %s (ok=%s)" % [path, str(ok)])
	return {"success": ok, "path": path, "god_count": out.size()}

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
	# Single pass: apply all results via _apply_result. Historical list ids are
	# preserved by _apply_result's adopted_list_id logic, so league and normal
	# bots compete for ladder slots in chronological order.
	var re_registered := 0
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
	print("[Bot League Debug] get_league_status: _by_god has %d gods" % _by_god.size())
	for god_name in _by_god.keys():
		var pool: Dictionary = _by_god[god_name]
		var all_lists = pool.get("lists", [])
		var all_ids_text := ""
		var first := true
		for list in all_lists:
			if not first:
				all_ids_text += ", "
			all_ids_text += str(list.get("list_id", ""))
			first = false
		print("[Bot League Debug]   %s: %d lists (%s)" % [god_name, all_lists.size(), all_ids_text])
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
		"matchmaking_excluded": bool(list.get("excluded_from_matchmaking", false)),
	}

func get_deck_details(list_id: String, quarantined_only: bool = false) -> Dictionary:
	if list_id.is_empty():
		return {}
	for pool: Dictionary in _by_god.values():
		var challenger: Dictionary = pool["challenger"]
		if not quarantined_only and challenger.get("list_id", "") == list_id:
			return _deck_details(challenger)
		for list: Dictionary in pool["lists"]:
			if list["list_id"] == list_id and (not quarantined_only or _is_quarantined_list(pool, list_id)):
				return _deck_details(list)
		if quarantined_only:
			for list: Dictionary in pool.get("quarantined_lists", []):
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
			if _is_quarantined_list(pool, list["list_id"]) or bool(list.get("excluded_from_matchmaking", false)) \
					or busy_list_ids.has(list["list_id"]):
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
			if bool(list.get("excluded_from_matchmaking", false)) or busy_list_ids.has(list_id):
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

## With a first-bot restriction, a single returned deck needs a fresh opponent.
func select_self_play_pair(busy_list_ids: Dictionary, rng: RandomNumberGenerator, first_list_ids: Dictionary = {}) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	var eligible_first: Array[Dictionary] = []
	for pool: Dictionary in _by_god.values():
		var lists: Array = pool["lists"].duplicate()
		if not pool["challenger"].is_empty():
			lists.append(pool["challenger"])
		for list: Dictionary in lists:
			if not _is_quarantined_list(pool, list["list_id"]) \
					and not bool(list.get("excluded_from_matchmaking", false)) \
					and not busy_list_ids.has(list["list_id"]):
				available.append(list)
				if first_list_ids.has(list["list_id"]):
					eligible_first.append(list)
	var restrict_first := not first_list_ids.is_empty()
	if restrict_first and eligible_first.is_empty():
		return []
	var pairs_by_gap: Dictionary = {}
	for i in available.size():
		var first := available[i]
		var first_id := str(first["list_id"])
		var first_eligible := first_list_ids.has(first_id)
		for j in range(i + 1, available.size()):
			var second := available[j]
			var second_id := str(second["list_id"])
			if not first_id.is_empty() and first_id == second_id:
				continue
			if restrict_first and not first_eligible and not first_list_ids.has(second_id):
				continue
			var gap := absi(_league_for_stars(int(first["stars"])) - _league_for_stars(int(second["stars"])))
			var pair := [first, second]
			_append_to_gap_bucket(pairs_by_gap, gap, pair)
	# Prefer pairs inside the league band, then the closest available gap.
	var selected_gaps: Array = []
	for gap in range(0, MATCHMAKING_LEAGUE_TIER_WINDOW + 1):
		if pairs_by_gap.has(gap):
			selected_gaps.append(gap)
	if selected_gaps.is_empty() and not pairs_by_gap.is_empty():
		selected_gaps.append(_closest_gap(pairs_by_gap))
	var candidates: Array = []
	for gap in selected_gaps:
		candidates.append_array(pairs_by_gap[gap])
	if candidates.is_empty() or rng.randf() < EXPLORATION_CHANCE:
		if restrict_first:
			return [eligible_first[rng.randi_range(0, eligible_first.size() - 1)].duplicate(true)]
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
	if restrict_first and not first_list_ids.has(selected[0]["list_id"]):
		selected.reverse()
	elif (not restrict_first or first_list_ids.has(selected[1]["list_id"])) and rng.randi_range(0, 1) == 1:
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

func save_state(path: String, result_count: int = 0) -> bool:
	var data := {
		"by_god": _by_god,
		"eliminated": _eliminated_bot_match_ids,
		"replayed_match_count": _replayed_match_count,
		"last_replayed_id": _last_replayed_id,
		"result_count": result_count,
		"assigned_names": _assigned_names_by_list_id,
	}
	return JsonStoreScript.save_json(path, data, "RankedBotDeckPool")

func load_state(path: String) -> bool:
	var loaded := JsonStoreScript.load_dictionary(path, {}, "RankedBotDeckPool")
	if loaded.is_empty() or not loaded.has("by_god"):
		return false
	_by_god = (loaded.get("by_god", {}) as Dictionary).duplicate(true)
	_eliminated_bot_match_ids = (loaded.get("eliminated", {}) as Dictionary).duplicate(true)
	_replayed_match_count = int(loaded.get("replayed_match_count", -1))
	_last_replayed_id = str(loaded.get("last_replayed_id", ""))
	_assigned_names_by_list_id = (loaded.get("assigned_names", {}) as Dictionary).duplicate(true)
	return true

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
	var list_id := str(result["list_id"]).strip_edges()
	if _is_inactive_community_bot(result, list_id):
		return
	var submission: Dictionary = _community_bots_by_id.get(list_id, {})
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
	if not list_id.is_empty():
		if not challenger.is_empty() and list_id == challenger["list_id"]:
			_update_record(challenger, outcome)
			if _get_played_match_count(challenger) >= int(challenger["trial_target_games"]):
				_resolve_trial(pool)
			return
		for list: Dictionary in lists:
			if list["list_id"] == list_id:
				# A bot is identified by its list_id, not its deck. If the deck
				# changed, update the fingerprint so future results still match.
				var new_fingerprint := _fingerprint(result)
				if list.get("fingerprint", "") != new_fingerprint:
					list["fingerprint"] = new_fingerprint
				_update_record(list, outcome)
				if list_id == pool["quarantined_id"] and not challenger.is_empty():
					challenger["trial_target_games"] = _get_played_match_count(list)
					return
				if _should_retire_early(list):
					_eliminated_bot_match_ids[str(result.get("match_id", ""))] = true
					_retire_list(pool, list)
				return
		if submission.is_empty() and _eliminated_bot_match_ids.has(str(result.get("match_id", ""))):
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
	var bot_name := str(result.get("bot_name", "")).strip_edges()
	var fingerprint := _fingerprint(audited_result)
	# Only anonymous generated decks can be identified by composition.
	if list_id.is_empty():
		for list: Dictionary in lists:
			if not bool(list.get("is_community_bot", false)) and list.get("fingerprint", "") == fingerprint:
				_update_record(list, outcome)
				if list["list_id"] == pool["quarantined_id"] and not challenger.is_empty():
					challenger["trial_target_games"] = _get_played_match_count(list)
					return
				if _should_retire_early(list):
					_eliminated_bot_match_ids[str(result.get("match_id", ""))] = true
					_retire_list(pool, list)
				return
		if not bool(challenger.get("is_community_bot", false)) and challenger.get("fingerprint", "") == fingerprint:
			_update_record(challenger, outcome)
			if _get_played_match_count(challenger) >= int(challenger["trial_target_games"]):
				_resolve_trial(pool)
			return
		for pending: Dictionary in pool["pending"]:
			if not bool(pending.get("is_community_bot", false)) and pending.get("fingerprint", "") == fingerprint:
				_update_record(pending, outcome)
				if _should_retire_early(pending):
					pool["pending"].erase(pending)
				return

	var self_play_name := ""
	# Self-play results and historical ladder results carry the bot's original
	# display name; preserve it instead of replacing it with an autofill name.
	if (bool(result.get("is_self_play", false)) or not list_id.is_empty()) and not bot_name.is_empty():
		self_play_name = bot_name
		if not self_play_name.begins_with("%s: " % display_god_name(god_name)):
			self_play_name = "%s: %s" % [display_god_name(god_name), self_play_name]
	var adopted_list_id := str(result["match_id"])
	if not list_id.is_empty():
		# Preserve the bot's original ladder id (e.g. volunteer/league list ids)
		# so later results resolve to the same entry instead of creating a new bot.
		adopted_list_id = list_id
	var initial_deck_name := "%s: Challenger" % display_god_name(god_name)
	if not adopted_list_id.is_empty() and _assigned_names_by_list_id.has(adopted_list_id):
		initial_deck_name = str(_assigned_names_by_list_id[adopted_list_id])
	elif not _is_generic_bot_name(self_play_name):
		initial_deck_name = self_play_name
	elif not _is_generic_bot_name(bot_name):
		initial_deck_name = "%s: %s" % [display_god_name(god_name), bot_name] if not bot_name.begins_with("%s: " % display_god_name(god_name)) else bot_name

	var new_list := {
		"list_id": adopted_list_id,
		"fingerprint": fingerprint,
		"god_name": god_name,
		"deck_name": initial_deck_name,
		"cards": audited_result["cards"],
		"reinforcements": audited_result["reinforcements"],
		"special_setup": audited_result["special_setup"],
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"stars": 0,
		"win_streak": 0,
		"self_play_name": self_play_name,
		"owner_name": "",
	}
	if not submission.is_empty():
		_apply_community_metadata(new_list, submission)
	elif not _is_generic_bot_name(initial_deck_name) and not adopted_list_id.is_empty():
		_assigned_names_by_list_id[adopted_list_id] = initial_deck_name
	_update_record(new_list, outcome)
	# A historical result carrying an existing ladder id is restoring an
	# established bot, so don't let a single early loss discard it. New
	# challengers (no stable list id) still use the early-retirement rule.
	if _should_retire_early(new_list) and list_id.is_empty():
		return
	# Historical/established bots (stable ladder ids) take priority over fresh
	# league bots: make room for them instead of dropping them when full.
	if not list_id.is_empty() and lists.size() >= LISTS_PER_GOD:
		var victim_index := 0
		for i in range(1, lists.size()):
			var current: Dictionary = lists[i]
			var victim: Dictionary = lists[victim_index]
			var current_is_league := str(current.get("list_id", "")).begins_with("league_")
			var victim_is_league := str(victim.get("list_id", "")).begins_with("league_")
			if current_is_league and not victim_is_league:
				victim_index = i
				continue
			if victim_is_league and not current_is_league:
				continue
			var current_priority := _bot_name_priority(current)
			var victim_priority := _bot_name_priority(victim)
			if current_priority < victim_priority:
				victim_index = i
			elif current_priority == victim_priority and _get_played_match_count(current) < _get_played_match_count(victim):
				victim_index = i
		lists.remove_at(victim_index)
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
	var games_played := _get_played_match_count(list)
	if games_played <= 0 or games_played > EARLY_RETIREMENT_GAMES:
		return false
	return 10 * int(list["losses"]) >= 7 * games_played

func _retire_list(pool: Dictionary, list: Dictionary) -> void:
	var list_id := str(list.get("list_id", ""))
	if list_id.is_empty():
		return
	# Quarantine retired weak bots but hold onto them for forced matchmaking
	# (Iron V and post-loss Iron/Bronze pairing) instead of discarding them.
	var qids: Array = pool.get("quarantined_ids", []).duplicate()
	if not (list_id in qids):
		qids.append(list_id)
		pool["quarantined_ids"] = qids
	var qlists: Array = pool.get("quarantined_lists", []).duplicate()
	var already_held := false
	for held in qlists:
		if str(held.get("list_id", "")) == list_id:
			already_held = true
			break
	if not already_held:
		qlists.append(list.duplicate(true))
		pool["quarantined_lists"] = qlists
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
	if bool(list.get("is_community_bot", false)):
		return
	var list_id := str(list.get("list_id", "")).strip_edges()
	if not list_id.is_empty() and _assigned_names_by_list_id.has(list_id):
		var assigned := str(_assigned_names_by_list_id[list_id]).strip_edges()
		if not _is_generic_bot_name(assigned):
			list["deck_name"] = assigned
			return

	var used_names := {}
	for name_val in _assigned_names_by_list_id.values():
		var n_str := str(name_val).strip_edges().to_lower()
		if not n_str.is_empty():
			used_names[n_str] = true
	for other: Dictionary in other_lists:
		var other_name := str(other.get("deck_name", "")).strip_edges().to_lower()
		if not other_name.is_empty():
			used_names[other_name] = true

	var current_name := str(list.get("deck_name", "")).strip_edges()
	var self_play_name := str(list.get("self_play_name", "")).strip_edges()
	var owner_name := str(list.get("owner_name", "")).strip_edges()

	# Community bots keep their author name unconditionally
	if not owner_name.is_empty():
		var author_name := current_name if not _is_generic_bot_name(current_name) else self_play_name
		if not _is_generic_bot_name(author_name):
			list["deck_name"] = author_name
			if not list_id.is_empty():
				_assigned_names_by_list_id[list_id] = author_name
			return

	# Established non-generic name that doesn't collide
	if not _is_generic_bot_name(current_name) and not used_names.has(current_name.to_lower()):
		if not list_id.is_empty():
			_assigned_names_by_list_id[list_id] = current_name
		return

	# Non-generic self_play_name that doesn't collide
	if not _is_generic_bot_name(self_play_name) and not used_names.has(self_play_name.to_lower()):
		list["deck_name"] = self_play_name
		if not list_id.is_empty():
			_assigned_names_by_list_id[list_id] = self_play_name
		return

	# Transition from Challenger to a new permanent unique name
	var god := display_god_name(str(list.get("god_name", "")))
	var chosen_name := _make_unique_bot_name(god, list, used_names)
	list["deck_name"] = chosen_name
	if not list_id.is_empty():
		_assigned_names_by_list_id[list_id] = chosen_name
