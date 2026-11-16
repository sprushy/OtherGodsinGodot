extends RefCounted
class_name PracticeAutofillDeckFactory

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const BotCardStrategyScript = preload("res://scripts/bots/BotCardStrategy.gd")

const DEFAULT_REGULAR_CARD_COUNT := 40
const MAX_POWERS := 3
const MAX_BUILD_ATTEMPTS := 32
const MAX_RANDOM_PICK_ATTEMPTS := 256
const PROMPT_HEAVY_CARD_NAMES := {
	"Aphrodite Areia": true,
	"Blessed Knights": true,
	"Tezcatlipoca, Active God": true,
	"Nusku, Active God": true,
	"Mummu, Active God": true,
	"First Sage Adapa": true,
	"Third Sage Enmedugga": true,
	"Fourth Sage Enmegalamma": true,
	"Sixth Sage An Enlilda": true,
	"Lailoken": true,
	"Masmassu Priest": true,
	"Rally the Troops": true,
	"Terror": true,
	"Huginn": true,
	"Muninn": true,
	"Fenrir": true,
	"Harii Jarl": true,
	"Durinn, Secondborn": true,
	"Kur Jara": true,
	"Hunting Tactics": true,
	"Foolish Optimism": true,
	"Gugalanna, Bull of Heaven": true,
	"Freyja, Active God": true,
	"Giant Master Architect": true,
	"Pai Long, Autumn King": true,
	"Nergal Lion": true,
	"Gala Tura": true,
	"Gawain": true,
	"Tatzelwurm": true,
	"Byggvir": true,
	"Humbaba the Terrible": true,
	"Ragnarok": true,
	"Apollyon's Demiurge": true,
	"Wolf Adolescent": true,
	"Advanced Building Techniques": true,
}
const SAFE_NON_CREATURE_CARD_NAMES := {
	"Accelerated Fate": true,
	"Call of the Valkyrie": true,
	"Void Shield": true,
	"Mead of Poetry": true,
	"Divine Lightning": true,
	"Fall of the Mighty": true,
	"Tonal Extraction": true,
}

var _validator := DeckValidatorScript.new()
var _all_cards: Array[Card] = []
var _gods: Array[GodCard] = []
var _cards_by_name: Dictionary = {}
var _prompt_heavy_lookup: Dictionary = {}
var _safe_non_creature_lookup: Dictionary = {}
var _restricted_equipment_lookup: Dictionary = {}

func _init() -> void:
	for prompt_name in PROMPT_HEAVY_CARD_NAMES.keys():
		_prompt_heavy_lookup[CardCatalogScript.to_lookup_key(str(prompt_name))] = true
	for safe_name in SAFE_NON_CREATURE_CARD_NAMES.keys():
		_safe_non_creature_lookup[CardCatalogScript.to_lookup_key(str(safe_name))] = true
	_all_cards = CardCatalogScript.make_all_cards()
	for card in _all_cards:
		if card == null:
			continue
		_cards_by_name[str(card.card_name)] = card
		if card is GodCard:
			_gods.append(card as GodCard)
	_build_restricted_equipment_lookup()

func get_ranked_god_names() -> Array[String]:
	var names: Array[String] = []
	for god in _gods:
		if not names.has(god.card_name):
			names.append(god.card_name)
	return names

func build_random_deck(seed_value: int, forced_god_name: String = "", ranked: bool = false) -> Dictionary:
	if _gods.is_empty():
		return {}
	for attempt in range(MAX_BUILD_ATTEMPTS):
		var deck_seed := seed_value + attempt
		var rng := RandomNumberGenerator.new()
		rng.seed = deck_seed
		var god := _choose_god_template(rng, forced_god_name, ranked)
		if god == null:
			continue
		var deck_cards: Dictionary = {}
		deck_cards[god.card_name] = 1
		if not _fill_regular_cards_for_god(deck_cards, god, rng, ranked):
			continue
		var special_setup := {}
		if TiamatThePrimordial.is_tiamat_god(god):
			var brood_count := rng.randi_range(1, TiamatThePrimordial.POWER_SLOT_COUNT)
			special_setup = _build_tiamat_brood_setup(rng, brood_count)
			if not _fill_safe_powers_for_god(
				deck_cards, god, rng, ranked,
				TiamatThePrimordial.POWER_SLOT_COUNT - brood_count
			):
				continue
		else:
			if not _fill_safe_powers_for_god(deck_cards, god, rng, ranked):
				continue
		var validation := _validator.validate_deck(deck_cards, special_setup)
		if bool(validation.get("is_valid", false)):
			var built := {
				"name": "%s Autofill %d" % [god.card_name, seed_value],
				"deck_name": "%s Autofill %d" % [god.card_name, seed_value],
				"cards": (validation.get("cards", {}) as Dictionary).duplicate(true),
				"special_setup": validation.get("special_setup", {}),
				"seed": deck_seed,
				"god_name": god.card_name,
			}
			return audit_ranked_bot_deck(built) if ranked else built
	return {}

# Builds a deterministic, deck-validator-legal Thor deck that contains the
# pieces needed to exercise the Hunting Tactics power: the power itself, a
# Norse Human Warrior attacker (Harii Warrior), and a Raven supporter (Huginn).
# Used by the two-process hunting_tactics smoke roles.
const HUNTING_TACTICS_DECK_FORCED_CARDS := {
	"Hunting Tactics": 1,
	"Harii Warrior": 3,
	"Huginn": 3,
}
const HUNTING_TACTICS_DECK_GOD := "Thor"

func build_hunting_tactics_deck() -> Dictionary:
	var god := _cards_by_name.get(HUNTING_TACTICS_DECK_GOD, null) as GodCard
	if god == null:
		return {}
	for attempt in range(MAX_BUILD_ATTEMPTS):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + attempt
		var deck_cards: Dictionary = {}
		deck_cards[god.card_name] = 1
		# Seed the deck with the forced cards first so the filler never starves
		# the regular-card count below the minimum, then top up as usual.
		for forced_name in HUNTING_TACTICS_DECK_FORCED_CARDS.keys():
			deck_cards[forced_name] = int(HUNTING_TACTICS_DECK_FORCED_CARDS[forced_name])
		if not _fill_regular_cards_for_god(deck_cards, god, rng):
			continue
		# Guarantee Hunting Tactics occupies a power slot even though it is in
		# the prompt-heavy exclusion list for the normal autofill path.
		var validation := _validator.validate_deck(deck_cards)
		if bool(validation.get("is_valid", false)):
			return {
				"name": "Hunting Tactics Smoke",
				"deck_name": "Hunting Tactics Smoke",
				"cards": (validation.get("cards", {}) as Dictionary).duplicate(true),
				"special_setup": validation.get("special_setup", {}),
				"god_name": god.card_name,
			}
	return {}

# Builds a PURPOSE deck that is allowed to violate normal construction rules
# (1 god not required, copy limits ignored, below the 35-card minimum, all the
# same card, etc.). Intended for campaign scenarios, scripted tests, and smoke
# runs that need a guaranteed board state - never for normal bot matchmaking.
#
# `god_name` selects the god slot (may be empty for a godless deck).
# `card_counts` is a {card_name: count} dict of exactly what to include; counts
# are not clamped to copy/legendary limits. The deck is NOT run through the
# validator, so callers must ensure the cards exist in the catalog.
func build_purpose_deck(deck_name: String, god_name: String, card_counts: Dictionary) -> Dictionary:
	var resolved_cards: Dictionary = {}
	for card_name in card_counts.keys():
		var resolved_name := str(card_name).strip_edges()
		if resolved_name.is_empty():
			continue
		var count := int(card_counts[card_name])
		if count <= 0:
			continue
		if _cards_by_name.get(resolved_name, null) == null:
			push_warning("[PracticeAutofillDeckFactory] purpose deck references unknown card: %s" % resolved_name)
			continue
		resolved_cards[resolved_name] = count
	var god_card = null
	var resolved_god := str(god_name).strip_edges()
	if not resolved_god.is_empty():
		god_card = _cards_by_name.get(resolved_god, null) as GodCard
	var result := {
		"name": deck_name,
		"deck_name": deck_name,
		"cards": resolved_cards.duplicate(true),
		"special_setup": {},
		"god_name": god_card.card_name if god_card != null else "",
		"is_purpose_deck": true,
	}
	return result

func _choose_god_template(rng: RandomNumberGenerator, forced_god_name: String, ranked: bool) -> GodCard:
	var resolved_forced_name := forced_god_name.strip_edges()
	if not resolved_forced_name.is_empty():
		var forced_card = _cards_by_name.get(resolved_forced_name, null)
		return forced_card as GodCard
	var candidates := _gods if ranked else _gods.filter(func(god: GodCard) -> bool:
		return not TiamatThePrimordial.is_tiamat_god(god)
	)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _fill_regular_cards_for_god(deck_cards: Dictionary, god: GodCard, rng: RandomNumberGenerator, ranked: bool = false) -> bool:
	var regular_count := 0
	var legendary_count := 0
	var preferred_added := 0
	var support_added := 0
	while regular_count < DEFAULT_REGULAR_CARD_COUNT:
		var only_legendary := legendary_count < mini(3, int(DEFAULT_REGULAR_CARD_COUNT / 10.0)) and rng.randf() < 0.12
		var candidates := _get_regular_candidates(god, deck_cards, only_legendary, ranked)
		if candidates.is_empty():
			if only_legendary:
				candidates = _get_regular_candidates(god, deck_cards, false, ranked)
			if candidates.is_empty():
				return false
		var preferred_candidates := _get_preferred_regular_candidates(god, deck_cards, ranked)
		if ranked and support_added < 10 and (support_added < 4 or rng.randf() < 0.25):
			var support := candidates.filter(func(card: Card) -> bool: return card.card_type != Card.CardType.CREATURE)
			if not support.is_empty():
				candidates = support
		elif ranked:
			candidates = candidates.filter(func(card: Card) -> bool: return card.card_type == Card.CardType.CREATURE)
			if candidates.is_empty():
				candidates = _get_regular_candidates(god, deck_cards, false, ranked)
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
		if preferred_added < 7 and not preferred_candidates.is_empty() and rng.randf() < 0.35:
			chosen = preferred_candidates[rng.randi_range(0, preferred_candidates.size() - 1)]
			preferred_added += 1
		var copies_to_add := _get_copy_count_to_add(chosen, deck_cards)
		if copies_to_add <= 0:
			return false
		if chosen.is_legendary:
			copies_to_add = 1
		if ranked and chosen.card_type != Card.CardType.CREATURE:
			copies_to_add = mini(copies_to_add, 10 - support_added)
		copies_to_add = mini(copies_to_add, DEFAULT_REGULAR_CARD_COUNT - regular_count)
		if chosen.is_legendary and legendary_count + copies_to_add > int(DEFAULT_REGULAR_CARD_COUNT / 10.0):
			continue
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + copies_to_add
		regular_count += copies_to_add
		if chosen.card_type != Card.CardType.CREATURE:
			support_added += copies_to_add
		if chosen.is_legendary:
			legendary_count += copies_to_add
	return true

func _build_tiamat_brood_setup(rng: RandomNumberGenerator, brood_count: int) -> Dictionary:
	var candidates := _all_cards.filter(func(card: Card) -> bool:
		return TiamatThePrimordial.is_valid_slot_creature(card) and not card.is_single_player_card
	)
	var opening_creatures := candidates.filter(func(card: Card) -> bool:
		return card.level <= TiamatThePrimordial.MAX_SLOT_LEVEL_TOTAL and card.mana_cost == 0 \
			and card.sacrifice_cost == 0 and card.discard_cost == 0 and card.shelve_cost == 0 and card.banish_cost == 0
	)
	var slots: Array = []
	for slot_index in range(brood_count):
		var slot: Array[String] = []
		var remaining_levels := TiamatThePrimordial.MAX_SLOT_LEVEL_TOTAL
		# Give Tiamat at least one creature she can take and summon at zero mana.
		if slot_index == 0 and not opening_creatures.is_empty():
			var opener: Card = opening_creatures[rng.randi_range(0, opening_creatures.size() - 1)]
			candidates.erase(opener)
			slot.append(opener.card_name)
			remaining_levels -= opener.level
		while remaining_levels > 0:
			var fitting := candidates.filter(func(card: Card) -> bool: return card.level <= remaining_levels)
			if fitting.is_empty():
				break
			var chosen: Card = fitting[rng.randi_range(0, fitting.size() - 1)]
			candidates.erase(chosen)
			slot.append(chosen.card_name)
			remaining_levels -= chosen.level
		slots.append(slot)
	return TiamatThePrimordial.build_special_setup(slots)

func _fill_safe_powers_for_god(
	deck_cards: Dictionary,
	god: GodCard,
	rng: RandomNumberGenerator,
	ranked: bool = false,
	requested_power_count: int = -1
) -> bool:
	var desired_powers := rng.randi_range(0, MAX_POWERS) if requested_power_count < 0 else requested_power_count
	if ranked and requested_power_count < 0:
		# Ranked bot decks use every available power slot. The old minimum of two
		# made half of generated ranked decks stop at exactly two powers.
		desired_powers = MAX_POWERS
	desired_powers = clampi(desired_powers, 0, MAX_POWERS)
	var power_count := _count_power_cards(deck_cards)
	while power_count < desired_powers:
		var candidates := _get_power_candidates(god, deck_cards, ranked)
		if candidates.is_empty():
			return not ranked
		var chosen := _choose_power_for_god(candidates, god, rng)
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1
		power_count += 1
	return true

func complete_ranked_power_slots(deck: Dictionary) -> Dictionary:
	if deck.is_empty():
		return deck.duplicate(true)
	var completed := audit_ranked_bot_deck(deck)
	if completed.is_empty():
		return {}
	var deck_cards: Dictionary = completed.get("cards", {}).duplicate(true)
	var god := _cards_by_name.get(str(completed.get("god_name", "")), null) as GodCard
	if god == null:
		return {}
	if TiamatThePrimordial.is_tiamat_god(god):
		return completed
	var power_count := 0
	for card_name in deck_cards:
		var template: Card = _cards_by_name.get(str(card_name), null)
		if template != null and template.is_power and not template.is_god:
			power_count += int(deck_cards[card_name])
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(str(completed.get("list_id", "")) + JSON.stringify(deck_cards)))
	while power_count < MAX_POWERS:
		var candidates := _get_power_candidates(god, deck_cards, true)
		if candidates.is_empty():
			return {}
		var chosen := _choose_power_for_god(candidates, god, rng)
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1
		power_count += 1
	var validation := _validator.validate_deck(
		deck_cards,
		completed.get("special_setup", {}),
		completed.get("reinforcements", {})
	)
	if not bool(validation.get("is_valid", false)):
		return {}
	completed["cards"] = validation.get("cards", {}).duplicate(true)
	completed["special_setup"] = validation.get("special_setup", {}).duplicate(true)
	completed["reinforcements"] = validation.get("reinforcements", {}).duplicate(true)
	return completed

# Repairs historical ranked lists as well as newly built ranked decks. The
# method is deterministic for a given list/deck identity, so replaying match
# history produces the same audited list every time.
func audit_ranked_bot_deck(deck: Dictionary) -> Dictionary:
	if deck.is_empty():
		return {}
	var audited := deck.duplicate(true)
	var god := _cards_by_name.get(str(audited.get("god_name", "")), null) as GodCard
	if god == null:
		return {}
	var cards: Dictionary = audited.get("cards", {}).duplicate(true)
	if cards.is_empty():
		return {}
	# Remove ineligible cards until the remaining deck no longer has dangling
	# support relationships (e.g. a payoff removed with its last enabler).
	for _pass in range(6):
		var removed := false
		for raw_name in cards.keys():
			var card_name := str(raw_name)
			var template: Card = _cards_by_name.get(card_name, null)
			if template == null or card_name == god.card_name:
				continue
			if not _has_deckbuilding_requirements(template, cards, god):
				cards.erase(card_name)
				removed = true
		if not removed:
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(str(audited.get("god_name", "")) + JSON.stringify(audited.get("cards", {}))))
	# Restore the standard forty-card non-power portion after pruning.
	var regular_count := _count_regular_cards(cards)
	var legendary_count := _count_legendary_cards(cards)
	var attempts := 0
	while regular_count < DEFAULT_REGULAR_CARD_COUNT and attempts < MAX_RANDOM_PICK_ATTEMPTS:
		attempts += 1
		var candidates: Array[Card] = []
		for candidate in _get_regular_candidates(god, cards, false, true):
			if _has_deckbuilding_requirements(candidate, cards, god):
				candidates.append(candidate)
		if candidates.is_empty() and legendary_count < int(DEFAULT_REGULAR_CARD_COUNT / 10.0):
			for candidate in _get_regular_candidates(god, cards, true, true):
				if _has_deckbuilding_requirements(candidate, cards, god):
					candidates.append(candidate)
		if candidates.is_empty():
			return {}
		var chosen: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
		var added := mini(_get_copy_count_to_add(chosen, cards), DEFAULT_REGULAR_CARD_COUNT - regular_count)
		if chosen.is_legendary:
			added = 1
			if legendary_count + added > int(DEFAULT_REGULAR_CARD_COUNT / 10.0):
				continue
		cards[chosen.card_name] = int(cards.get(chosen.card_name, 0)) + added
		regular_count += added
		if chosen.is_legendary:
			legendary_count += added
	# Tiamat shares the three power slots between powers and brood slots. Repair
	# historical lists to that combined limit before filling any remaining slots.
	var power_slot_capacity := MAX_POWERS
	if TiamatThePrimordial.is_tiamat_god(god):
		power_slot_capacity -= _get_tiamat_occupied_slot_count(audited.get("special_setup", {}))
	var power_count := _count_power_cards(cards)
	var excess_power_names: Array[String] = []
	for raw_name in cards.keys():
		var template: Card = _cards_by_name.get(str(raw_name), null)
		if template != null and template.is_power and not template.is_god:
			excess_power_names.append(str(raw_name))
	while power_count > power_slot_capacity and not excess_power_names.is_empty():
		var remove_index := rng.randi_range(0, excess_power_names.size() - 1)
		var remove_name := excess_power_names[remove_index]
		var remove_count := int(cards.get(remove_name, 0))
		if remove_count <= 1:
			cards.erase(remove_name)
			excess_power_names.remove_at(remove_index)
		else:
			cards[remove_name] = remove_count - 1
		power_count -= 1
	while power_count < power_slot_capacity:
		var power_candidates := _get_power_candidates(god, cards, true)
		if power_candidates.is_empty():
			break
		var chosen_power: Card = power_candidates[rng.randi_range(0, power_candidates.size() - 1)]
		cards[chosen_power.card_name] = 1
		power_count += 1
	var validation := _validator.validate_deck(
		cards,
		audited.get("special_setup", {}),
		audited.get("reinforcements", {})
	)
	if not bool(validation.get("is_valid", false)):
		return {}
	audited["cards"] = (validation.get("cards", {}) as Dictionary).duplicate(true)
	audited["special_setup"] = (validation.get("special_setup", {}) as Dictionary).duplicate(true)
	audited["reinforcements"] = (validation.get("reinforcements", {}) as Dictionary).duplicate(true)
	return audited

func _get_tiamat_occupied_slot_count(special_setup) -> int:
	var occupied := 0
	for slot_cards in TiamatThePrimordial.get_slot_card_names_from_setup(special_setup):
		if slot_cards is Array and not slot_cards.is_empty():
			occupied += 1
	return occupied

func _count_regular_cards(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var card: Card = _cards_by_name.get(str(name), null)
		if card != null and not card.is_god and not card.is_power:
			total += int(cards[name])
	return total

func _count_legendary_cards(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var card: Card = _cards_by_name.get(str(name), null)
		if card != null and card.is_legendary and not card.is_god:
			total += int(cards[name])
	return total

func _count_power_cards(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var card: Card = _cards_by_name.get(str(name), null)
		if card != null and card.is_power and not card.is_god:
			total += int(cards[name])
	return total

func _has_deckbuilding_requirements(card: Card, cards: Dictionary, god: GodCard) -> bool:
	if card == null:
		return false
	var name := card.card_name
	match name:
		"Durinn Secondborn":
			return _count_card_type(cards, Card.CardType.EQUIPMENT) >= 3
		"Circle of Rebirth":
			return _count_matching_any(cards, ["Animal", "Plant"]) >= 5
		"Sixth Sage An-Enlilda":
			return _count_ancient_dwelling_targets(cards) >= 2
		"Robotic Footsoldier":
			return _count_other_matching(cards, card, ["Machine"]) >= 2
		"Isimud":
			return _count_other_matching(cards, card, ["Divine Manifestation"]) >= 3
		"Fourth Sage Enmegalamma":
			return _count_other_matching(cards, card, ["Mer", "Sage"]) >= 3
		"Beyla":
			return _count_named(cards, ["Berserker", "Gidim Ensi"]) >= 3 or int(cards.get("Berserker Mead", 0)) > 0
		"Byggvir":
			return _count_tagged(cards, "Mead") > 0
		"Tatzelwurm":
			return _count_other_matching(cards, card, ["Dragon"]) > 0
		"Caleuche, the Ghost Ship":
			return _count_other_matching(cards, card, ["Spirit"]) >= 2 or (god.card_name == "Freyja" and _count_matching(cards, ["Norse", "Warrior"]) >= 2)
		"E2-abzu":
			return _count_matching(cards, ["Mer"]) >= 2
		"Walk of the Sage":
			return _walk_of_the_sage_has_payoff(cards)
		"Huginn": return _count_tagged(cards, "Hex") > 0
		"Muninn": return _count_tagged(cards, "Charm") > 0
		"Wild Magic":
			return _count_card_type(cards, Card.CardType.SPELL) + _count_card_type(cards, Card.CardType.HEX) \
				+ _count_card_type(cards, Card.CardType.CHARM) > int(cards.get(name, 0))
		"Apollyon's Demiurge": return _count_matching(cards, ["Demon"]) >= 3
		"Eridu, City of Sages": return _count_matching(cards, ["Mage"]) >= 3
		"Advanced Building Techniques": return _count_card_type(cards, Card.CardType.STRUCTURE) >= 2
		"Immortal Techniques":
			return _count_matching(cards, ["Mage"]) > 0 \
				and _count_card_type(cards, Card.CardType.SPELL) + _count_card_type(cards, Card.CardType.HEX) > 0
		"A Cost to Walk the Worlds":
			return _count_named(cards, ["Bit Meseri", "Void Shield", "Wheel of Fire", "Asag the Destroyer"]) > 0
		"Allfather's Sacrifice": return _count_tagged(cards, "Spell") > 0
		"Giant Master Architect": return _count_tagged(cards, "Structure") > 0
		"Wolf Cub": return _count_other_matching(cards, card, ["Lupine"], 4) > 0
		"Wolf Adolescent": return _count_other_matching(cards, card, ["Lupine"], 5) > 0
		"Hringhorni": return _count_other_matching(cards, card, ["Norse", "Warrior"]) > 0
		"Harii Jarl": return _count_other_matching(cards, card, ["Harii"]) > 0
		"Harii Shaman": return _count_matching(cards, ["Norse", "Warrior"]) + _count_matching(cards, ["Animal"]) > 0
		"Gungnir, the Spear of Odin": return _count_matching(cards, ["Norse", "Warrior"]) > 0
		"Gambanteinn": return _restricted_equipment_has_bearers(card, cards)
		"Breidablik": return _count_matching(cards, ["Priest"]) > 0
		"Tonal Extraction":
			for name_in_deck in cards:
				var target := _cards_by_name.get(name_in_deck) as Card
				if int(cards[name_in_deck]) > 0 and target != null and target.card_type == Card.CardType.CREATURE \
						and not target.is_god and target.has_type("Shapeshifter") \
						and not target.get_tonal_extraction_spirit_profile().is_empty():
					return true
			return false
		"Fire and Gold": return _count_matching(cards, ["Tian", "Dragon"]) > 0
		"Call of the Valkyrie": return _count_matching(cards, ["Norse", "Warrior"]) > 0
		"Myrkwood": return _count_matching(cards, ["Animal"]) >= 2
		"Hunting Tactics": return _has_hunting_tactics_pair(cards)
		"Norse Bloodlust": return _count_matching(cards, ["Norse", "Warrior"]) > 0 and _count_matching(cards, ["Lupine"]) > 0
		"Rally the Troops": return _count_matching(cards, ["Warrior"]) >= 6 and _count_matching(cards, ["Warrior"], 5) > 0
		"Raven Storm": return _count_matching(cards, ["Norse", "Warrior"]) + _count_matching(cards, ["Lupine"]) > 0
		"Fifa the Magical Arrow": return _count_matching(cards, ["Warrior"]) > 0
	# Equipment that restricts which creatures can bear it (e.g. Gambanteinn,
	# Sharur) is only worth adding with enough legal bearers in the deck.
	if not _restricted_equipment_has_bearers(card, cards):
		return false
	if card.is_power and BotCardStrategyScript.PASSIVE_TYPES.has(BotCardStrategyScript.key(card)) \
			and name not in ["Rally the Troops", "Norse Bloodlust", "Hunting Tactics", "Myrkwood"]:
		var matching_creatures := 0
		for candidate_name in cards:
			var candidate: Card = _cards_by_name.get(str(candidate_name), null)
			if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
				continue
			for type in BotCardStrategyScript.PASSIVE_TYPES[BotCardStrategyScript.key(card)]:
				if candidate.has_type(str(type)):
					matching_creatures += int(cards[candidate_name])
					break
		if matching_creatures < 6:
			return false
	return true

func _count_tagged(cards: Dictionary, tag: String) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate != null and not candidate.is_god and candidate.has_type(tag):
			total += int(cards[name])
	return total

func _count_card_type(cards: Dictionary, card_type: Card.CardType) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate != null and not candidate.is_god and candidate.card_type == card_type:
			total += int(cards[name])
	return total

func _count_named(cards: Dictionary, names: Array) -> int:
	var total := 0
	for name in names:
		total += int(cards.get(name, 0))
	return total

func _count_matching(cards: Dictionary, tags: Array, minimum_level: int = 0) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god or candidate.level < minimum_level:
			continue
		var matches := true
		for tag in tags:
			if not candidate.has_type(str(tag)):
				matches = false
				break
		if matches:
			total += int(cards[name])
	return total

func _count_other_matching(cards: Dictionary, source: Card, tags: Array, maximum_level: int = 0) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god or candidate == source:
			continue
		if maximum_level > 0 and candidate.level > maximum_level:
			continue
		var matches := true
		for tag in tags:
			if not candidate.has_type(str(tag)):
				matches = false
				break
		if matches:
			total += int(cards[name])
	return total

func _count_matching_any(cards: Dictionary, tags: Array) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
			continue
		for tag in tags:
			if candidate.has_type(str(tag)):
				total += int(cards[name])
				break
	return total

# Mirrors SixthSageAnEnlilda's Ancient Dwelling target rule for deck templates.
func _count_ancient_dwelling_targets(cards: Dictionary) -> int:
	var total := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.STRUCTURE or not candidate.has_type("Dwelling"):
			continue
		if candidate.has_type("Ancient Structure") or candidate.has_type("Ancient") \
				or str(candidate.culture).strip_edges() == "Ancient":
			total += int(cards[name])
	return total

# Equipment counts as bearer-restricted when it refuses at least one creature
# that could otherwise receive equipment. Template can_equip_to calls are pure
# type checks, so this is safe to run once against the catalog at init.
func _build_restricted_equipment_lookup() -> void:
	for equipment in _all_cards:
		if equipment == null or equipment.card_type != Card.CardType.EQUIPMENT:
			continue
		for candidate in _all_cards:
			if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
				continue
			if not candidate.can_receive_equipment():
				continue
			if not equipment.can_equip_to(candidate):
				_restricted_equipment_lookup[equipment.card_name] = true
				break

func _restricted_equipment_has_bearers(card: Card, cards: Dictionary) -> bool:
	if card == null or card.card_type != Card.CardType.EQUIPMENT:
		return true
	if not _restricted_equipment_lookup.has(card.card_name):
		return true
	var bearers := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
			continue
		if card.can_equip_to(candidate):
			bearers += int(cards[name])
	return bearers >= 4

func _walk_of_the_sage_has_payoff(cards: Dictionary) -> bool:
	var has_mage := _count_matching(cards, ["Mage"]) > 0
	if not has_mage:
		return false
	var has_abzu_payoff := int(cards.get("E2-abzu", 0)) > 0 and _deck_has_mer_mage(cards)
	var has_sage_payoff := int(cards.get("Seventh Sage Utuabzu", 0)) > 0 and _count_matching(cards, ["Ancient", "Mage", "Sage"]) > 1
	var has_vision_payoff := int(cards.get("Vision of Tartarus", 0)) > 0 and _count_matching(cards, ["Mage"]) > 0
	return has_abzu_payoff or has_sage_payoff or has_vision_payoff

func _has_hunting_tactics_pair(cards: Dictionary) -> bool:
	var attackers := 0
	var supporters := 0
	for name in cards:
		var candidate: Card = _cards_by_name.get(str(name), null)
		if candidate == null or candidate.card_type != Card.CardType.CREATURE or candidate.is_god:
			continue
		var count := int(cards[name])
		if candidate.has_type("Lupine") or (candidate.has_type("Norse") and candidate.has_type("Human") and candidate.has_type("Warrior")):
			attackers += count
		if candidate.card_name == "Huginn" or candidate.card_name == "Muninn" or candidate.has_type("Lupine"):
			supporters += count
	return attackers > 0 and supporters > 0 and (attackers > 1 or supporters > 1)

func _get_regular_candidates(god: GodCard, deck_cards: Dictionary, legendary_only: bool, ranked: bool = false) -> Array[Card]:
	var candidates: Array[Card] = []
	for template in _all_cards:
		if not _is_safe_regular_card(template, god, deck_cards, legendary_only, ranked):
			continue
		candidates.append(template)
	return candidates

func _get_preferred_regular_candidates(god: GodCard, deck_cards: Dictionary, ranked: bool = false) -> Array[Card]:
	var candidates: Array[Card] = []
	if god == null:
		return candidates
	for template in _all_cards:
		if not _is_safe_regular_card(template, god, deck_cards, false, ranked):
			continue
		if _is_preferred_card_for_god(template, god):
			candidates.append(template)
	return candidates

func _get_power_candidates(god: GodCard, deck_cards: Dictionary, ranked: bool = false) -> Array[Card]:
	var candidates: Array[Card] = []
	for template in _all_cards:
		if template == null or not template.is_power or template.is_god:
			continue
		if ranked and not BotCardStrategyScript.supports_ranked_deck_card(template):
			continue
		if not ranked and not _safe_non_creature_lookup.has(CardCatalogScript.to_lookup_key(str(template.card_name))):
			continue
		if int(deck_cards.get(template.card_name, 0)) >= 1:
			continue
		if not _is_card_compatible_with_god(template, god):
			continue
		if template is TakeTheField and not _can_use_take_the_field(god):
			continue
		if (ranked or template is TonalExtraction) and not _has_deckbuilding_requirements(template, deck_cards, god):
			continue
		candidates.append(template)
	return candidates

func _choose_power_for_god(candidates: Array[Card], god: GodCard, rng: RandomNumberGenerator) -> Card:
	if god is TezcatlipocaTheSmokingMirror:
		for power in candidates:
			if power is TonalExtraction:
				return power
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _is_safe_regular_card(card: Card, god: GodCard, deck_cards: Dictionary, legendary_only: bool, ranked: bool = false) -> bool:
	if card == null or card.is_god or card.is_power or card.is_single_player_card:
		return false
	if card is ActiveGodCard and not ranked:
		return false
	if legendary_only and not card.is_legendary:
		return false
	if not legendary_only and card.is_legendary:
		return false
	if int(deck_cards.get(card.card_name, 0)) >= _max_copies(card):
		return false
	if ranked:
		if not BotCardStrategyScript.supports_ranked_deck_card(card):
			return false
		if not _has_deckbuilding_requirements(card, deck_cards, god):
			return false
		return _is_card_compatible_with_god(card, god)
	if _prompt_heavy_lookup.has(CardCatalogScript.to_lookup_key(str(card.card_name))):
		return false
	if card.card_type != Card.CardType.CREATURE and not _safe_non_creature_lookup.has(CardCatalogScript.to_lookup_key(str(card.card_name))):
		return false
	return _is_card_compatible_with_god(card, god)

func _deck_has_mer_mage(deck_cards: Dictionary) -> bool:
	for card_name in deck_cards:
		if int(deck_cards[card_name]) <= 0:
			continue
		var card: Card = _cards_by_name.get(str(card_name))
		if card != null and card.card_type == Card.CardType.CREATURE \
				and card.has_type("Mer") and card.has_type("Mage"):
			return true
	return false

func _is_card_compatible_with_god(card: Card, god: GodCard) -> bool:
	if card == null or god == null or card.is_god:
		return true
	if card is ActiveGodCard:
		return god.get_active_god_deck_role(card as ActiveGodCard) == GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED
	if god.uses_culture_locked_deckbuilding():
		return god.can_include_card_in_culture_locked_deck(card)
	if card.is_power and not card.is_god:
		return str(card.culture).strip_edges() == "Neutral" or str(card.culture).strip_edges() == str(god.culture).strip_edges()
	return true

func _can_use_take_the_field(god: GodCard) -> bool:
	# Tezcatlipoca's own summon also transfers the sacrifices to Titlacauan.
	if god is TezcatlipocaTheSmokingMirror or not god.can_autofill_take_the_field():
		return false
	return _all_cards.any(func(card: Card) -> bool:
		return card is ActiveGodCard and god.is_own_active_god_card(card)
	)

func _is_preferred_card_for_god(card: Card, god: GodCard) -> bool:
	if card == null or god == null:
		return false
	match god.card_name:
		"Thor", "Freyja":
			return card.has_type("Warrior") and card.culture == "Norse"
		"Tezcatlipoca, the Smoking Mirror":
			return card.has_type("Shapeshifter")
		_:
			return false

func _get_copy_count_to_add(card: Card, deck_cards: Dictionary) -> int:
	if card == null:
		return 0
	var current_count := int(deck_cards.get(card.card_name, 0))
	var remaining_copies := maxi(0, _max_copies(card) - current_count)
	if remaining_copies <= 0:
		return 0
	if card.card_name == "Hyena Pack":
		return remaining_copies
	return 1

func _max_copies(card: Card) -> int:
	if card == null:
		return 0
	if card.is_god or card.is_power or card is ActiveGodCard or card.is_legendary:
		return 1
	return 3
