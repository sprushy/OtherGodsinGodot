extends RefCounted
class_name PracticeAutofillDeckFactory

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")

const DEFAULT_REGULAR_CARD_COUNT := 40
const MAX_POWERS := 3
const MAX_BUILD_ATTEMPTS := 32
const MAX_RANDOM_PICK_ATTEMPTS := 256
const EXCLUDED_GOD_NAMES := {
	"Tiamat, the Primordial": true,
}
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
var _excluded_god_lookup: Dictionary = {}
var _prompt_heavy_lookup: Dictionary = {}
var _safe_non_creature_lookup: Dictionary = {}

func _init() -> void:
	for excluded_name in EXCLUDED_GOD_NAMES.keys():
		_excluded_god_lookup[CardCatalogScript.to_lookup_key(str(excluded_name))] = true
	for prompt_name in PROMPT_HEAVY_CARD_NAMES.keys():
		_prompt_heavy_lookup[CardCatalogScript.to_lookup_key(str(prompt_name))] = true
	for safe_name in SAFE_NON_CREATURE_CARD_NAMES.keys():
		_safe_non_creature_lookup[CardCatalogScript.to_lookup_key(str(safe_name))] = true
	_all_cards = CardCatalogScript.make_all_cards()
	for card in _all_cards:
		if card == null:
			continue
		_cards_by_name[str(card.card_name)] = card
		if card is GodCard and not _excluded_god_lookup.has(CardCatalogScript.to_lookup_key(str(card.card_name))):
			_gods.append(card as GodCard)

func build_random_deck(seed_value: int, forced_god_name: String = "") -> Dictionary:
	if _gods.is_empty():
		return {}
	for attempt in range(MAX_BUILD_ATTEMPTS):
		var deck_seed := seed_value + attempt
		var rng := RandomNumberGenerator.new()
		rng.seed = deck_seed
		var god := _choose_god_template(rng, forced_god_name)
		if god == null:
			continue
		var deck_cards: Dictionary = {}
		deck_cards[god.card_name] = 1
		if not _fill_regular_cards_for_god(deck_cards, god, rng):
			continue
		_fill_safe_powers_for_god(deck_cards, god, rng)
		var validation := _validator.validate_deck(deck_cards)
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

func _choose_god_template(rng: RandomNumberGenerator, forced_god_name: String) -> GodCard:
	var resolved_forced_name := forced_god_name.strip_edges()
	if not resolved_forced_name.is_empty():
		var forced_card = _cards_by_name.get(resolved_forced_name, null)
		return forced_card as GodCard
	if _gods.is_empty():
		return null
	return _gods[rng.randi_range(0, _gods.size() - 1)]

func _fill_regular_cards_for_god(deck_cards: Dictionary, god: GodCard, rng: RandomNumberGenerator) -> bool:
	var regular_count := 0
	var legendary_count := 0
	var preferred_added := 0
	while regular_count < DEFAULT_REGULAR_CARD_COUNT:
		var only_legendary := legendary_count < mini(3, int(DEFAULT_REGULAR_CARD_COUNT / 10.0)) and rng.randf() < 0.12
		var candidates := _get_regular_candidates(god, deck_cards, only_legendary)
		if candidates.is_empty():
			if only_legendary:
				candidates = _get_regular_candidates(god, deck_cards, false)
			if candidates.is_empty():
				return false
		var preferred_candidates := _get_preferred_regular_candidates(god, deck_cards)
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
		if preferred_added < 7 and not preferred_candidates.is_empty() and rng.randf() < 0.35:
			chosen = preferred_candidates[rng.randi_range(0, preferred_candidates.size() - 1)]
			preferred_added += 1
		var copies_to_add := _get_copy_count_to_add(chosen, deck_cards)
		if copies_to_add <= 0:
			return false
		if chosen.is_legendary:
			copies_to_add = 1
		copies_to_add = mini(copies_to_add, DEFAULT_REGULAR_CARD_COUNT - regular_count)
		if chosen.is_legendary and legendary_count + copies_to_add > int(DEFAULT_REGULAR_CARD_COUNT / 10.0):
			continue
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + copies_to_add
		regular_count += copies_to_add
		if chosen.is_legendary:
			legendary_count += copies_to_add
	return true

func _fill_safe_powers_for_god(deck_cards: Dictionary, god: GodCard, rng: RandomNumberGenerator) -> void:
	var desired_powers := rng.randi_range(0, MAX_POWERS)
	for _power_index in range(desired_powers):
		var candidates := _get_power_candidates(god, deck_cards)
		if candidates.is_empty():
			return
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
		deck_cards[chosen.card_name] = int(deck_cards.get(chosen.card_name, 0)) + 1

func _get_regular_candidates(god: GodCard, deck_cards: Dictionary, legendary_only: bool) -> Array[Card]:
	var candidates: Array[Card] = []
	for template in _all_cards:
		if not _is_safe_regular_card(template, god, deck_cards, legendary_only):
			continue
		candidates.append(template)
	return candidates

func _get_preferred_regular_candidates(god: GodCard, deck_cards: Dictionary) -> Array[Card]:
	var candidates: Array[Card] = []
	if god == null:
		return candidates
	for template in _all_cards:
		if not _is_safe_regular_card(template, god, deck_cards, false):
			continue
		if _is_preferred_card_for_god(template, god):
			candidates.append(template)
	return candidates

func _get_power_candidates(god: GodCard, deck_cards: Dictionary) -> Array[Card]:
	var candidates: Array[Card] = []
	for template in _all_cards:
		if template == null or not template.is_power or template.is_god:
			continue
		if not _safe_non_creature_lookup.has(CardCatalogScript.to_lookup_key(str(template.card_name))):
			continue
		if int(deck_cards.get(template.card_name, 0)) >= 1:
			continue
		if not _is_card_compatible_with_god(template, god):
			continue
		candidates.append(template)
	return candidates

func _is_safe_regular_card(card: Card, god: GodCard, deck_cards: Dictionary, legendary_only: bool) -> bool:
	if card == null or card.is_god or card.is_power:
		return false
	if card is ActiveGodCard:
		return false
	if legendary_only and not card.is_legendary:
		return false
	if not legendary_only and card.is_legendary:
		return false
	if int(deck_cards.get(card.card_name, 0)) >= _max_copies(card):
		return false
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
