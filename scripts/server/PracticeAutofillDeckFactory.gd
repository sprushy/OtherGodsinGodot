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
}

var _validator := DeckValidatorScript.new()
var _all_cards: Array[Card] = []
var _gods: Array[GodCard] = []
var _cards_by_name: Dictionary = {}
var _prompt_heavy_lookup: Dictionary = {}
var _safe_non_creature_lookup: Dictionary = {}

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
			var brood_count := TiamatThePrimordial.POWER_SLOT_COUNT
			if ranked and rng.randi_range(0, 2) == 0:
				deck_cards["Take the Field"] = 1
				brood_count -= 1
			special_setup = _build_tiamat_brood_setup(rng, brood_count)
		else:
			if not _fill_safe_powers_for_god(deck_cards, god, rng, ranked):
				continue
		var validation := _validator.validate_deck(deck_cards, special_setup)
		if bool(validation.get("is_valid", false)):
			return {
				"name": "%s Autofill %d" % [god.card_name, seed_value],
				"deck_name": "%s Autofill %d" % [god.card_name, seed_value],
				"cards": (validation.get("cards", {}) as Dictionary).duplicate(true),
				"special_setup": validation.get("special_setup", {}),
				"seed": deck_seed,
				"god_name": god.card_name,
			}
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

func _fill_safe_powers_for_god(deck_cards: Dictionary, god: GodCard, rng: RandomNumberGenerator, ranked: bool = false) -> bool:
	var desired_powers := rng.randi_range(0, MAX_POWERS)
	if ranked:
		# Ranked bot decks use every available power slot. The old minimum of two
		# made half of generated ranked decks stop at exactly two powers.
		desired_powers = MAX_POWERS
	for _power_index in range(desired_powers):
		var candidates := _get_power_candidates(god, deck_cards, ranked)
		if candidates.is_empty():
			return not ranked
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1
	return true

func complete_ranked_power_slots(deck: Dictionary) -> Dictionary:
	if deck.is_empty():
		return deck.duplicate(true)
	var completed := deck.duplicate(true)
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
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
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
		if ranked and BotCardStrategyScript.PASSIVE_TYPES.has(BotCardStrategyScript.key(template)):
			var matches := 0
			for name in deck_cards:
				var candidate: Card = _cards_by_name.get(name)
				if candidate == null or candidate.card_type != Card.CardType.CREATURE:
					continue
				for type in BotCardStrategyScript.PASSIVE_TYPES[BotCardStrategyScript.key(template)]:
					if candidate.has_type(type):
						matches += int(deck_cards[name])
						break
			if matches < 6:
				continue
		candidates.append(template)
	return candidates

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
		if card.card_type != Card.CardType.CREATURE and not BotCardStrategyScript.supports_ranked_deck_card(card):
			return false
		return _is_card_compatible_with_god(card, god)
	if _prompt_heavy_lookup.has(CardCatalogScript.to_lookup_key(str(card.card_name))):
		return false
	if card.card_type != Card.CardType.CREATURE and not _safe_non_creature_lookup.has(CardCatalogScript.to_lookup_key(str(card.card_name))):
		return false
	return _is_card_compatible_with_god(card, god)

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
