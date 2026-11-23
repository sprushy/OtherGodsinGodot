extends RefCounted

# Matchup taxonomy and swap planning for bot Reinforcements (sideboards) in
# best-of-three series.
#
# Two sides share one tag set:
# - Observation: publicly visible opponent cards (board, powers, god, grave,
#   abyss — never the hand) accumulate threat tags such as MAGICAL when the
#   opponent leans on spells, hexes, and charms.
# - Hate: answer cards carry the tags of the profiles they beat, so a bot that
#   observed a MAGICAL-heavy opponent brings Runic Spellbreaker in, and one
#   that observed no magical cards leaves it out.
#
# Cut ordering uses BotSideboardRatings (survey "Δ field" data). A positive
# hate-need score protects a main-deck card from being cut; survey ratings
# only order the unprotected leftovers. All swaps are validated through
# DeckValidator.validate_reinforcement_swap, so legality (40-card minimum,
# powers, copy/legendary caps, support requirements) is enforced by the same
# rules humans follow.
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const BotSideboardRatingsScript = preload("res://scripts/bots/BotSideboardRatings.gd")

enum Tag {
	NONE = 0,
	MAGICAL = 1,
	STRUCTURE_MACHINE = 2,
	NAMED_SUMMON = 3,
	CREATURE = 4,
	AERIAL_WEATHER = 5,
	POWER_GOD = 6,
	MECHANIC = 7,
	RUNIC = 8,
}

const TAG_NAMES := {
	Tag.MAGICAL: "anti-magical",
	Tag.STRUCTURE_MACHINE: "anti-structure/Stone/machine",
	Tag.NAMED_SUMMON: "anti-named-summon",
	Tag.CREATURE: "anti-physical/creature",
	Tag.AERIAL_WEATHER: "aerial/weather/tempo",
	Tag.POWER_GOD: "anti-power/god",
	Tag.MECHANIC: "anti-mechanic",
	Tag.RUNIC: "anti-runic/Odin",
}

# Curated hate classification: card name -> opponent profiles it answers.
# Grounded in the current card scripts; keep in sync when effects change.
const CARD_HATE_TAGS := {
	# Anti-magical: answers to spells, hexes, charms, and magical cards.
	"Runic Spellbreaker": [Tag.MAGICAL],
	"Spell Demolition": [Tag.MAGICAL],
	"Banishment": [Tag.MAGICAL],
	"Divine Lightning": [Tag.MAGICAL],
	"Occult Singularity": [Tag.MAGICAL],
	"Drought": [Tag.MAGICAL, Tag.MECHANIC],
	"Exorcism": [Tag.MAGICAL, Tag.MECHANIC],
	# Anti-structure / Stone / machine.
	"Earthquake": [Tag.STRUCTURE_MACHINE, Tag.AERIAL_WEATHER],
	"Fires of Judgment": [Tag.STRUCTURE_MACHINE, Tag.CREATURE],
	"The Deluge": [Tag.STRUCTURE_MACHINE, Tag.CREATURE],
	"Deucalion's Infants": [Tag.STRUCTURE_MACHINE],
	# Anti-named-summon: single-target answers for big named threats.
	"Gleipnir": [Tag.NAMED_SUMMON, Tag.CREATURE],
	"Dromi": [Tag.NAMED_SUMMON, Tag.CREATURE],
	"Wheel of Fire": [Tag.NAMED_SUMMON, Tag.CREATURE],
	"Siren's Song": [Tag.NAMED_SUMMON],
	"The Changeling Exchange": [Tag.NAMED_SUMMON],
	"BitMeseri": [Tag.NAMED_SUMMON, Tag.CREATURE],
	"Gungnir, the Spear of Odin": [Tag.NAMED_SUMMON, Tag.CREATURE],
	"Smite": [Tag.NAMED_SUMMON, Tag.CREATURE],
	# Anti-physical / creature.
	"Fall of the Mighty": [Tag.CREATURE, Tag.NAMED_SUMMON],
	"Famine": [Tag.CREATURE],
	"The Inferno": [Tag.CREATURE],
	"Sap": [Tag.CREATURE],
	"Void Shield": [Tag.CREATURE],
	"Snowball": [Tag.CREATURE],
	"Fairy Blast": [Tag.CREATURE],
	"Sap Strength": [Tag.CREATURE],
	"Shroud of the Ancients": [Tag.CREATURE],
	"Sleep of the Duat": [Tag.CREATURE, Tag.MECHANIC],
	# Aerial / weather / tempo.
	"Storm": [Tag.AERIAL_WEATHER],
	"Heavy Snow": [Tag.AERIAL_WEATHER, Tag.MECHANIC],
	"Warding Stone": [Tag.AERIAL_WEATHER, Tag.MECHANIC],
	# Anti-power / god.
	"Absence": [Tag.POWER_GOD],
	# Anti-runic/Odin: strips Runic Knowledge fuel (Runic and "of Odin" cards)
	# from the Odin player's hand.
	"Compelled by the Secret Name": [Tag.RUNIC],
	# Anti-mechanic: hidden cards, status, stances, followers, protection.
	"Watchtower": [Tag.MECHANIC],
	"Light of Morning's Doors": [Tag.MECHANIC],
	"Anointing Statue": [Tag.MECHANIC],
	"Namburbi Apotropaeon": [Tag.MECHANIC],
	"Glitnir the Peaceful": [Tag.MECHANIC],
	"Foolish Optimism": [Tag.MECHANIC],
}

# Text markers that mark an observed opponent card as mechanic-reliant, which
# the reveal/status/protection answers above want to see before coming in.
const MECHANIC_TEXT_MARKERS := [
	"stealth", "sleep", "status", "followers", "hidden", "face-down", "prepared",
]

# A tag with this much hate already in the main deck counts as covered, and
# extra sideboard copies for it are only brought in at a strongly reduced need.
const MAIN_DECK_COVERED_THRESHOLD := 2
# Swaps per between-game window. Keeps pivots meaningful without gutting the
# registered 40-card shell that the validator must keep legal.
const MAX_SWAPS_PER_WINDOW := 4
# Observed tag counts saturate here so a long, grindy game cannot make one
# tag dominate the whole plan.
const TAG_OBSERVATION_CAP := 12
# Covered tags still contribute a sliver of need (divided by this) so a bot
# can top up hate it already runs main-deck copies of.
const COVERED_TAG_NEED_DIVISOR := 4

static var _cards_by_name: Dictionary = {}


static func get_card(card_name: Variant) -> Card:
	if _cards_by_name.is_empty():
		_cards_by_name = DeckValidatorScript.get_shared_cards_by_name()
	return _cards_by_name.get(str(card_name).strip_edges(), null)


## Threat tags an observed opponent card contributes to.
static func threat_tags_for_card(card: Card) -> Array[int]:
	var tags: Array[int] = []
	if card == null or card.is_token:
		return tags
	var subtypes := card.get_subtypes()
	var is_magical := card.is_magical_card() \
			or card.card_type in [Card.CardType.SPELL, Card.CardType.HEX, Card.CardType.CHARM]
	if is_magical:
		tags.append(Tag.MAGICAL)
	var is_machine := false
	for subtype in subtypes:
		if str(subtype) in ["Machine", "Mech"]:
			is_machine = true
			break
	if card.card_type == Card.CardType.STRUCTURE or is_machine:
		tags.append(Tag.STRUCTURE_MACHINE)
	if card.card_type == Card.CardType.CREATURE:
		tags.append(Tag.CREATURE)
		if card.is_legendary or card.level >= 4:
			tags.append(Tag.NAMED_SUMMON)
	var is_aerial := false
	for subtype in subtypes:
		if str(subtype) in ["Aerial", "Avian", "Weather"]:
			is_aerial = true
			break
	if is_aerial:
		tags.append(Tag.AERIAL_WEATHER)
	if card.card_type == Card.CardType.POWER or card.is_power or card.is_god:
		tags.append(Tag.POWER_GOD)
	var ability := str(card.ability_text).to_lower()
	for marker in MECHANIC_TEXT_MARKERS:
		if ability.find(marker) != -1:
			tags.append(Tag.MECHANIC)
			break
	# Odin and every card that fuels Runic Knowledge (a Runic or an
	# "of Odin" card) mark the matchup where hand hate pays.
	if card.has_type("Runic") or card.card_name.to_lower().contains("odin"):
		tags.append(Tag.RUNIC)
	return tags


# Cards whose effects expose the opponent's hand contents (Mopsus's Seer
# reveals, Dellingr's Radiate). Two or more sources make Compelled by the
# Secret Name's guaranteed-hit mode reliable, so sideboard planning treats it
# as on-plan even without Odin observations.
const HAND_KNOWLEDGE_SOURCE_NAMES := ["Mopsus", "Dellingr, Active God"]

static func count_hand_knowledge_sources(cards: Dictionary) -> int:
	var count := 0
	for card_name in HAND_KNOWLEDGE_SOURCE_NAMES:
		count += int(cards.get(str(card_name), 0))
	return count


## Hate tags a sideboard-eligible card answers, curated first with a typed
## fallback for cards the curated table does not name.
static func hate_tags_for_card(card: Card) -> Array[int]:
	if card == null:
		return []
	var curated: Array = CARD_HATE_TAGS.get(str(card.card_name).strip_edges(), [])
	if not curated.is_empty():
		var resolved: Array[int] = []
		for tag in curated:
			resolved.append(int(tag))
		return resolved
	return threat_tags_for_card(card)


## Record one observed opponent card into an observation profile
## ({"cards": {name: count}, "tags": {tag: count}}).
static func observe_card(observed: Dictionary, card: Card) -> void:
	if card == null or observed == null:
		return
	var name := str(card.card_name).strip_edges()
	if name.is_empty() or card.is_token:
		return
	if not (observed.get("cards", {}) is Dictionary):
		observed["cards"] = {}
	if not (observed.get("tags", {}) is Dictionary):
		observed["tags"] = {}
	var cards: Dictionary = observed["cards"]
	var tags: Dictionary = observed["tags"]
	cards[name] = int(cards.get(name, 0)) + 1
	for tag in threat_tags_for_card(card):
		tags[tag] = mini(int(tags.get(tag, 0)) + 1, TAG_OBSERVATION_CAP)


## Merge two observation profiles (accumulates across series games).
static func merge_observations(base: Dictionary, addition: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	merged["cards"] = (merged.get("cards", {}) as Dictionary).duplicate(true)
	merged["tags"] = (merged.get("tags", {}) as Dictionary).duplicate(true)
	var add_cards: Dictionary = addition.get("cards", {})
	var add_tags: Dictionary = addition.get("tags", {})
	for name in add_cards:
		merged["cards"][name] = int(merged["cards"].get(name, 0)) + int(add_cards[name])
	for tag in add_tags:
		merged["tags"][tag] = mini(int(merged["tags"].get(tag, 0)) + int(add_tags[tag]), TAG_OBSERVATION_CAP)
	return merged


## Scan the opponent's publicly visible zones at game end. The hand and deck
## stay private; the god, powers, board (with equipment), grave, and abyss are
## all public information a human would sideboard against.
static func summarize_opponent(game_manager, opponent_index: int) -> Dictionary:
	var observed := {"cards": {}, "tags": {}}
	if game_manager == null or opponent_index < 0 or opponent_index >= game_manager.players.size():
		return observed
	var opponent = game_manager.players[opponent_index]
	if opponent == null:
		return observed
	var zones: Array = []
	zones.append(opponent.god_zone)
	zones.append_array(opponent.power_zones)
	zones.append_array(opponent.frontline_zones)
	zones.append_array(opponent.reserve_zones)
	zones.append(opponent.graveyard_zone)
	zones.append(opponent.abyss_zone)
	for zone in zones:
		if zone == null:
			continue
		for card in zone.cards:
			observe_card(observed, card)
	return observed


## Copies-weighted hate coverage of a card pool, used both to steer sideboard
## generation toward tags the main deck does not answer and to reduce the need
## of hate the bot already plays main-deck.
static func main_deck_tag_coverage(cards: Dictionary) -> Dictionary:
	var coverage := {}
	for name in cards:
		var card := get_card(name)
		if card == null:
			continue
		var copies := maxi(1, int(cards.get(name, 1)))
		for tag in hate_tags_for_card(card):
			coverage[tag] = int(coverage.get(tag, 0)) + copies
	return coverage


## How badly this card is wanted against the observed opponent. Zero means the
## matchup profile does not call for it (or nothing of its tags was seen).
static func hate_need(card: Card, observed: Dictionary, coverage: Dictionary = {}, knowledge_sources: int = 0) -> int:
	if card == null:
		return 0
	var tags := hate_tags_for_card(card)
	if tags.is_empty():
		return 0
	var tag_counts: Dictionary = observed.get("tags", {})
	var need := 0
	for tag in tags:
		var seen := int(tag_counts.get(tag, 0))
		if seen <= 0:
			continue
		if int(coverage.get(tag, 0)) >= MAIN_DECK_COVERED_THRESHOLD:
			@warning_ignore("integer_division")
			var covered_need := maxi(1, int(seen / COVERED_TAG_NEED_DIVISOR))
			need += covered_need
		else:
			need += seen
	# Hand hate with multiple own-deck knowledge engines guarantees
	# declarations, so it stays on-plan even without Odin observations.
	if need <= 0 and knowledge_sources >= 2 \
			and str(card.card_name).strip_edges() == "Compelled by the Secret Name":
		need = 1
	return need


## Names that must never leave the main deck during a swap window.
static func _is_protected_main_deck_card(card: Card, special_setup: Dictionary) -> bool:
	if card == null:
		return true
	if card.is_god or card.is_power or card.card_type in [Card.CardType.GOD, Card.CardType.POWER]:
		return true
	# Special setup slots (e.g. Tiamat brood mothers) are fixed at registration
	# and live outside the swappable pool; walk the setup generically so any
	# nested slot shape is protected.
	var slot_names := {}
	_collect_setup_card_names(special_setup, slot_names)
	return slot_names.has(str(card.card_name).strip_edges())


static func _collect_setup_card_names(value: Variant, names: Dictionary) -> void:
	if value is Dictionary:
		for entry in value.values():
			_collect_setup_card_names(entry, names)
	elif value is Array:
		for entry in value:
			_collect_setup_card_names(entry, names)
	elif value is String:
		var clean := str(value).strip_edges()
		if not clean.is_empty():
			names[clean] = true


## Plan one Reinforcement window for a bot seat. Returns the new
## {"cards", "reinforcements"} plus a human-readable audit log; the returned
## decks are always validator-legal or unchanged.
static func plan_swap(
	registered_cards: Dictionary,
	registered_side: Dictionary,
	special_setup: Dictionary,
	observed: Dictionary,
	rng: RandomNumberGenerator,
	validator
) -> Dictionary:
	var result := {
		"cards": registered_cards.duplicate(true),
		"reinforcements": registered_side.duplicate(true),
		"changed": false,
		"log": [],
	}
	if observed.is_empty() or not (validator is DeckValidator):
		return result
	var coverage := main_deck_tag_coverage(registered_cards)
	var knowledge_sources := count_hand_knowledge_sources(registered_cards)

	# Bring-in candidates: sideboard hate the observed opponent invites.
	var bring_candidates: Array[Dictionary] = []
	for name in registered_side:
		var card := get_card(name)
		if card == null:
			continue
		var need := hate_need(card, observed, coverage, knowledge_sources)
		if need <= 0:
			continue
		bring_candidates.append({
			"name": str(name),
			"copies": maxi(1, int(registered_side.get(name, 1))),
			"need": need,
			"rating": BotSideboardRatingsScript.rating_for(str(name)),
			"jitter": rng.randf(),
		})
	bring_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["need"] != b["need"]:
			return int(a["need"]) > int(b["need"])
		if a["rating"] != b["rating"]:
			return int(a["rating"]) > int(b["rating"])
		return float(a["jitter"]) > float(b["jitter"]))

	# Cut candidates: main-deck regulars with zero hate need, worst survey
	# rating first. Extra copies of a card are trimmed before lone copies of a
	# similarly-rated card, and jitter keeps repeated series from mirroring.
	var cut_candidates: Array[Dictionary] = []
	for name in registered_cards:
		var card := get_card(name)
		if _is_protected_main_deck_card(card, special_setup):
			continue
		if hate_need(card, observed, coverage, knowledge_sources) > 0:
			continue
		cut_candidates.append({
			"name": str(name),
			"copies": maxi(1, int(registered_cards.get(name, 1))),
			"rating": BotSideboardRatingsScript.rating_for(str(name)),
			"jitter": rng.randf(),
		})
	cut_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["rating"] != b["rating"]:
			return int(a["rating"]) < int(b["rating"])
		if a["copies"] != b["copies"]:
			return int(a["copies"]) > int(b["copies"])
		return float(a["jitter"]) > float(b["jitter"]))

	var cards: Dictionary = result["cards"]
	var side: Dictionary = result["reinforcements"]
	var swaps_done := 0
	var cut_index := 0
	for bring in bring_candidates:
		if swaps_done >= MAX_SWAPS_PER_WINDOW or cut_index >= cut_candidates.size():
			break
		var bring_name := str(bring["name"])
		var bring_copies := mini(int(bring["copies"]), MAX_SWAPS_PER_WINDOW - swaps_done)
		for _copy in range(bring_copies):
			if swaps_done >= MAX_SWAPS_PER_WINDOW or cut_index >= cut_candidates.size():
				break
			var placed := false
			while cut_index < cut_candidates.size():
				var cut: Dictionary = cut_candidates[cut_index]
				cut_index += 1
				var cut_name := str(cut["name"])
				var proposed_cards: Dictionary = cards.duplicate(true)
				var proposed_side: Dictionary = side.duplicate(true)
				# A swap moves cards between the main deck and the registered
				# sideboard: the bring-in leaves the sideboard for the main
				# deck, and the cut takes its place on the sideboard. The
				# combined pool stays identical, which is exactly what
				# validate_reinforcement_swap enforces.
				proposed_side[bring_name] = int(proposed_side.get(bring_name, 0)) - 1
				if int(proposed_side[bring_name]) <= 0:
					proposed_side.erase(bring_name)
				proposed_cards[bring_name] = int(proposed_cards.get(bring_name, 0)) + 1
				proposed_cards[cut_name] = int(proposed_cards.get(cut_name, 1)) - 1
				if int(proposed_cards[cut_name]) <= 0:
					proposed_cards.erase(cut_name)
				proposed_side[cut_name] = int(proposed_side.get(cut_name, 0)) + 1
				var validation: Dictionary = validator.validate_reinforcement_swap(
					proposed_cards, proposed_side, proposed_cards, proposed_side, special_setup
				)
				if not bool(validation.get("is_valid", false)):
					# Cutting that card broke legality (support requirements,
					# minimum counts). Restore and try the next candidate.
					continue
				cards = proposed_cards
				side = proposed_side
				swaps_done += 1
				placed = true
				result["log"].append({
					"in": bring_name,
					"out": cut_name,
					"rating_out": int(cut["rating"]),
					"need_in": int(bring["need"]),
				})
				break
			if not placed:
				# No legal cut remained for this bring-in; stop planning.
				break
	result["cards"] = cards
	result["reinforcements"] = side
	result["changed"] = swaps_done > 0
	return result


## Records one series game's public-card observation for a bot seat, merging
## into the session so observations survive bot detach/rebuild between games.
static func record_series_observation(match_session, game_manager, bot_player_index: int) -> void:
	if match_session == null or game_manager == null:
		return
	if bot_player_index < 0 or bot_player_index >= match_session.player_session_ids.size():
		return
	var session_id := str(match_session.player_session_ids[bot_player_index]).strip_edges()
	if session_id.is_empty():
		return
	var observation := summarize_opponent(game_manager, 1 - bot_player_index)
	var existing: Dictionary = match_session.bot_opponent_observations_by_session.get(session_id, {})
	match_session.bot_opponent_observations_by_session[session_id] = \
		merge_observations(existing, observation)


## Plans and applies one bot's between-games Reinforcement pivot against
## everything observed so far in the series. Returns the plan (with "changed"
## and a swap log); the swap only lands when the shared DeckValidator accepts
## it, exactly like a human submission.
static func apply_bot_series_swap(match_session, session_id: String, validator) -> Dictionary:
	if match_session == null:
		return {"changed": false, "log": []}
	var registered: Dictionary = match_session.registered_player_decks_by_session.get(session_id, {})
	var current: Dictionary = match_session.player_decks_by_session.get(session_id, registered)
	if registered.is_empty() or current.is_empty():
		return {"changed": false, "log": []}
	var observed: Dictionary = match_session.bot_opponent_observations_by_session.get(session_id, {})
	if observed.is_empty():
		return {"changed": false, "log": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(session_id + "|" + str(match_session.series_game_number)))
	var special_setup = registered.get("special_setup", {})
	var plan := plan_swap(
		current.get("cards", {}),
		current.get("reinforcements", {}),
		special_setup if special_setup is Dictionary else {},
		observed,
		rng,
		validator
	)
	if bool(plan.get("changed", false)):
		var updated: Dictionary = current.duplicate(true)
		updated["cards"] = plan.get("cards", current.get("cards", {}))
		updated["reinforcements"] = plan.get("reinforcements", current.get("reinforcements", {}))
		match_session.player_decks_by_session[session_id] = updated
	return plan


static func describe_tags(tags: Array[int]) -> String:
	var names := PackedStringArray()
	for tag in tags:
		names.append(str(TAG_NAMES.get(int(tag), "?")))
	return ", ".join(names)
