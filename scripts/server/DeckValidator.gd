extends RefCounted
class_name DeckValidator

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const CardArtVariantsScript = preload("res://scripts/core/CardArtVariants.gd")
const MIN_REGULAR_CARDS := 40
const MAX_POWERS := 3
const REINFORCEMENT_DIVISOR := 3

static var _shared_cards_by_name: Dictionary = {}

var _cards_by_name: Dictionary = {}

func _init() -> void:
	_cards_by_name = _get_shared_cards_by_name()

static func _get_shared_cards_by_name() -> Dictionary:
	if _shared_cards_by_name.is_empty():
		_shared_cards_by_name = _build_cards_by_name()
	return _shared_cards_by_name

static func _build_cards_by_name() -> Dictionary:
	var cards_by_name: Dictionary = {}
	for card in CardCatalogScript.make_all_cards():
		if card == null:
			continue
		var aliases: Array[String] = [
			str(card.card_name),
			CardCatalogScript.to_lookup_key(str(card.card_name)),
		]
		if card.has_method("get_normalized_card_name"):
			aliases.append(str(card.get_normalized_card_name()))
			aliases.append(CardCatalogScript.to_lookup_key(str(card.get_normalized_card_name())))
		if card.has_method("get_ascii_card_name"):
			aliases.append(str(card.get_ascii_card_name()))
			aliases.append(CardCatalogScript.to_lookup_key(str(card.get_ascii_card_name())))
		for alias in aliases:
			var clean_alias: String = str(alias).strip_edges()
			if clean_alias.is_empty():
				continue
			cards_by_name[clean_alias] = card
	return cards_by_name

func validate_deck(
	deck_cards: Dictionary,
	special_setup: Dictionary = {},
	reinforcements: Dictionary = {}
) -> Dictionary:
	var sanitized_cards: Dictionary = {}
	var sanitized_reinforcements: Dictionary = {}
	var god_count := 0
	var power_count := 0
	var regular_count := 0
	var legendary_count := 0
	var reinforcement_count := 0
	var god_culture := ""
	var invalid_culture_cards: PackedStringArray = []
	var god_template = null

	for raw_card_name in deck_cards.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(deck_cards[raw_card_name])
		if card_name.is_empty() or count <= 0:
			continue
		var card_lookup_key: String = CardCatalogScript.to_lookup_key(card_name)
		var resolved_key: String = card_name
		if not _cards_by_name.has(resolved_key) and _cards_by_name.has(card_lookup_key):
			resolved_key = card_lookup_key
		if not _cards_by_name.has(resolved_key):
			return _result(false, "Unknown card: %s." % card_name, sanitized_cards)
		var card = _cards_by_name[resolved_key]
		var max_copies := _max_copies(card)
		if count > max_copies:
			return _result(false, "%s exceeds the copy limit (%d)." % [card_name, max_copies], sanitized_cards)
		sanitized_cards[str(card.card_name)] = count
		if bool(card.is_god):
			god_count += count
			if god_culture.is_empty():
				god_culture = str(card.culture)
			if god_template == null:
				god_template = card
		elif bool(card.is_power):
			power_count += count
		else:
			regular_count += count
			if bool(card.is_legendary):
				legendary_count += count

	if god_count != 1:
		return _result(false, "Deck must contain exactly 1 God.", sanitized_cards)
	if power_count > MAX_POWERS:
		return _result(false, "Deck can contain at most %d Powers." % MAX_POWERS, sanitized_cards)
	var illegal_active_gods := _get_illegal_active_gods_for_deck(sanitized_cards, god_template)
	if not illegal_active_gods.is_empty():
		return _result(false, "Active Gods cannot be included this way: %s." % ", ".join(illegal_active_gods), sanitized_cards)
	if regular_count < MIN_REGULAR_CARDS:
		return _result(false, "Deck must contain at least %d non-God, non-Power cards." % MIN_REGULAR_CARDS, sanitized_cards)

	for raw_card_name in reinforcements.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(reinforcements[raw_card_name])
		if card_name.is_empty() or count <= 0:
			continue
		var card_lookup_key: String = CardCatalogScript.to_lookup_key(card_name)
		var resolved_key: String = card_name
		if not _cards_by_name.has(resolved_key) and _cards_by_name.has(card_lookup_key):
			resolved_key = card_lookup_key
		if not _cards_by_name.has(resolved_key):
			return _result(
				false,
				"Unknown Reinforcement card: %s." % card_name,
				sanitized_cards,
				{"reinforcements": sanitized_reinforcements}
			)
		var card = _cards_by_name[resolved_key]
		if bool(card.is_god):
			return _result(
				false,
				"Reinforcements cannot contain Gods.",
				sanitized_cards,
				{"reinforcements": sanitized_reinforcements}
			)
		var max_copies := _max_copies(card)
		if count > max_copies:
			return _result(
				false,
				"%s exceeds the combined deck and Reinforcements copy limit (%d)." % [card_name, max_copies],
				sanitized_cards,
				{"reinforcements": sanitized_reinforcements}
			)
		sanitized_reinforcements[str(card.card_name)] = count
		reinforcement_count += count

	for card_name in sanitized_reinforcements.keys():
		var card = _cards_by_name[card_name]
		var combined_count := int(sanitized_cards.get(card_name, 0)) + int(sanitized_reinforcements[card_name])
		var max_copies := _max_copies(card)
		if combined_count > max_copies:
			return _result(
				false,
				"%s exceeds the combined deck and Reinforcements copy limit (%d)." % [card_name, max_copies],
				sanitized_cards,
				{"reinforcements": sanitized_reinforcements}
			)

	var reinforcement_limit := get_reinforcement_limit(regular_count, power_count)
	if reinforcement_count > reinforcement_limit:
		return _result(
			false,
			"Reinforcements contain %d cards, but this deck allows at most %d." % [
				reinforcement_count,
				reinforcement_limit
			],
			sanitized_cards,
			{"reinforcements": sanitized_reinforcements}
		)

	var all_deckbuilding_cards := sanitized_cards.duplicate(true)
	for card_name in sanitized_reinforcements.keys():
		all_deckbuilding_cards[card_name] = int(all_deckbuilding_cards.get(card_name, 0)) + int(sanitized_reinforcements[card_name])

	for card_name in all_deckbuilding_cards.keys():
		var card = _cards_by_name[card_name]
		if card == null or bool(card.is_god) or god_template == null:
			continue
		var is_invalid := false
		if god_template is GodCard and (god_template as GodCard).uses_culture_locked_deckbuilding():
			is_invalid = not (god_template as GodCard).can_include_card_in_culture_locked_deck(card)
		elif bool(card.is_power):
			var culture := str(card.culture)
			is_invalid = not god_culture.is_empty() and culture != "Neutral" and culture != god_culture
		if is_invalid:
			invalid_culture_cards.append(card_name)

	if not invalid_culture_cards.is_empty():
		var rule_label := "Deck culture mismatch" if god_template is GodCard and (god_template as GodCard).uses_culture_locked_deckbuilding() else "Power culture mismatch"
		return _result(false, "%s: %s." % [rule_label, ", ".join(invalid_culture_cards)], sanitized_cards)

	var illegal_reinforcement_active_gods := _get_illegal_active_gods_for_deck(sanitized_reinforcements, god_template)
	if not illegal_reinforcement_active_gods.is_empty():
		return _result(
			false,
			"Active Gods cannot be included in Reinforcements this way: %s." % ", ".join(illegal_reinforcement_active_gods),
			sanitized_cards,
			{"reinforcements": sanitized_reinforcements}
		)

	var max_legendaries := int(floor(regular_count / 10.0))
	if legendary_count > max_legendaries:
		return _result(false, "Deck has too many legendary cards (%d / %d)." % [legendary_count, max_legendaries], sanitized_cards)

	var validated_special_setup := _validate_special_setup(special_setup, god_template, power_count)
	if not bool(validated_special_setup.get("is_valid", false)):
		return _result(
			false,
			str(validated_special_setup.get("error", "Invalid special setup.")),
			sanitized_cards,
			{
				"special_setup": validated_special_setup.get("special_setup", {}),
			}
		)

	return _result(true, "", sanitized_cards, {
		"total_cards": regular_count + god_count + power_count,
		"god_count": god_count,
		"power_count": power_count,
		"regular_count": regular_count,
		"legendary_count": legendary_count,
		"reinforcements": sanitized_reinforcements,
		"reinforcement_count": reinforcement_count,
		"reinforcement_limit": reinforcement_limit,
		"god_culture": god_culture,
		"special_setup": validated_special_setup.get("special_setup", {}),
	})

func validate_reinforcement_swap(
	original_cards: Dictionary,
	original_reinforcements: Dictionary,
	proposed_cards: Dictionary,
	proposed_reinforcements: Dictionary,
	special_setup: Dictionary = {}
) -> Dictionary:
	var original_validation := validate_deck(original_cards, special_setup, original_reinforcements)
	if not bool(original_validation.get("is_valid", false)):
		return original_validation
	var proposed_validation := validate_deck(proposed_cards, special_setup, proposed_reinforcements)
	if not bool(proposed_validation.get("is_valid", false)):
		return proposed_validation

	var original_main: Dictionary = original_validation.get("cards", {})
	var original_side: Dictionary = original_validation.get("reinforcements", {})
	var proposed_main: Dictionary = proposed_validation.get("cards", {})
	var proposed_side: Dictionary = proposed_validation.get("reinforcements", {})
	if _combined_counts(original_main, original_side) != _combined_counts(proposed_main, proposed_side):
		return _result(
			false,
			"Reinforcement changes must use the same registered card pool.",
			proposed_main,
			{"reinforcements": proposed_side}
		)
	return proposed_validation

static func get_reinforcement_limit(regular_count: int, power_count: int) -> int:
	return maxi(0, int((regular_count + power_count) / REINFORCEMENT_DIVISOR))

func validate_card_array(deck: Array[Card], special_setup: Dictionary = {}) -> Dictionary:
	return validate_deck(cards_to_counts(deck), special_setup)

static func cards_to_counts(deck: Array[Card]) -> Dictionary:
	var counts: Dictionary = {}
	for card in deck:
		if card == null:
			continue
		var card_name := str(card.card_name).strip_edges()
		if card_name.is_empty():
			continue
		counts[card_name] = int(counts.get(card_name, 0)) + 1
	return counts

func _validate_special_setup(special_setup: Dictionary, god_template, power_count: int) -> Dictionary:
	var sanitized_slots := TiamatScript.get_slot_card_names_from_setup(special_setup)
	var canonical_slots: Array = []
	var occupied_slot_count := 0
	var seen_card_names: Dictionary = {}

	for slot_index in range(sanitized_slots.size()):
		var slot_cards: Array = sanitized_slots[slot_index]
		var canonical_slot: Array[String] = []
		var slot_level_total := 0
		if not slot_cards.is_empty():
			occupied_slot_count += 1
		for raw_card_name in slot_cards:
			var requested_name := str(raw_card_name).strip_edges()
			if requested_name.is_empty():
				continue
			var card_lookup_key: String = CardCatalogScript.to_lookup_key(requested_name)
			var resolved_key: String = requested_name
			if not _cards_by_name.has(resolved_key) and _cards_by_name.has(card_lookup_key):
				resolved_key = card_lookup_key
			if not _cards_by_name.has(resolved_key):
				return {
					"is_valid": false,
					"error": "Unknown Tiamat slot card: %s." % requested_name,
					"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
				}
			var card = _cards_by_name[resolved_key]
			if not TiamatScript.is_valid_slot_creature(card):
				return {
					"is_valid": false,
					"error": "%s is not a valid Tiamat slot creature." % str(card.card_name),
					"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
				}
			var canonical_name := str(card.card_name)
			if seen_card_names.has(canonical_name):
				return {
					"is_valid": false,
					"error": "Tiamat slot creatures must all be different. %s was chosen more than once." % canonical_name,
					"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
				}
			seen_card_names[canonical_name] = true
			slot_level_total += int(card.level)
			canonical_slot.append(canonical_name)
		if slot_level_total > TiamatScript.MAX_SLOT_LEVEL_TOTAL:
			return {
				"is_valid": false,
				"error": "Tiamat slot %d exceeds %d total levels." % [slot_index + 1, TiamatScript.MAX_SLOT_LEVEL_TOTAL],
				"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
			}
		canonical_slots.append(canonical_slot)
		if canonical_slots.size() >= TiamatScript.POWER_SLOT_COUNT:
			break

	if occupied_slot_count <= 0:
		return {
			"is_valid": true,
			"error": "",
			"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
		}
	if not TiamatScript.is_tiamat_god(god_template):
		return {
			"is_valid": false,
			"error": "Only Tiamat can use Matriarch Rule slot creatures.",
			"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
		}
	if power_count + occupied_slot_count > MAX_POWERS:
		return {
			"is_valid": false,
			"error": "Tiamat deck uses %d total power slots (powers + Matriarch slots), but only %d are allowed." % [
				power_count + occupied_slot_count,
				MAX_POWERS
			],
			"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
		}
	return {
		"is_valid": true,
		"error": "",
		"special_setup": _build_validated_special_setup(canonical_slots, special_setup),
	}

func _build_validated_special_setup(tiamat_slots: Array, raw_special_setup: Dictionary) -> Dictionary:
	return CardArtVariantsScript.build_special_setup(
		tiamat_slots,
		CardArtVariantsScript.get_selections_from_setup(raw_special_setup)
	)

func _result(is_valid: bool, error_message: String, sanitized_cards: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var output := {
		"is_valid": is_valid,
		"error": error_message,
		"cards": sanitized_cards.duplicate(true),
	}
	output.merge(extra, true)
	return output

func _count_cards(cards: Dictionary) -> int:
	var total := 0
	for count in cards.values():
		total += int(count)
	return total

func _combined_counts(first: Dictionary, second: Dictionary) -> Dictionary:
	var combined := first.duplicate(true)
	for card_name in second.keys():
		combined[card_name] = int(combined.get(card_name, 0)) + int(second[card_name])
	return combined

func _max_copies(card) -> int:
	if bool(card.is_god):
		return 1
	if bool(card.is_power):
		return 1
	if card is ActiveGodCard:
		return 1
	if bool(card.is_legendary):
		return 1
	return 3

func _get_illegal_active_gods_for_deck(sanitized_cards: Dictionary, god_template) -> PackedStringArray:
	var illegal_active_gods: PackedStringArray = []
	var god_card := god_template as GodCard
	for card_name in sanitized_cards.keys():
		var card = _cards_by_name.get(card_name, null)
		var active_god := card as ActiveGodCard
		if active_god == null:
			continue
		if god_card == null or god_card.get_active_god_deck_role(active_god) != GodCard.ACTIVE_GOD_DECK_ROLE_ALLOWED:
			illegal_active_gods.append(str(active_god.card_name))
	return illegal_active_gods
