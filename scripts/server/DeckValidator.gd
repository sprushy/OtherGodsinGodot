extends RefCounted
class_name DeckValidator

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const MIN_REGULAR_CARDS := 35
const MAX_POWERS := 3

var _cards_by_name: Dictionary = {}

func _init() -> void:
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
			_cards_by_name[clean_alias] = card

func validate_deck(deck_cards: Dictionary, special_setup: Dictionary = {}) -> Dictionary:
	var sanitized_cards: Dictionary = {}
	var god_count := 0
	var power_count := 0
	var regular_count := 0
	var legendary_count := 0
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
	var active_god_validation := _validate_active_gods_for_deck(sanitized_cards, god_template)
	if not bool(active_god_validation.get("is_valid", false)):
		return _result(false, str(active_god_validation.get("error", "Invalid Active God setup.")), sanitized_cards)
	regular_count -= int(active_god_validation.get("reserved_active_god_count", 0))
	if regular_count < MIN_REGULAR_CARDS:
		return _result(false, "Deck must contain at least %d non-God, non-Power cards." % MIN_REGULAR_CARDS, sanitized_cards)

	for card_name in sanitized_cards.keys():
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
		"god_culture": god_culture,
		"special_setup": validated_special_setup.get("special_setup", {}),
	})

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
					"special_setup": TiamatScript.build_special_setup(canonical_slots),
				}
			var card = _cards_by_name[resolved_key]
			if not TiamatScript.is_valid_slot_creature(card):
				return {
					"is_valid": false,
					"error": "%s is not a valid Tiamat slot creature." % str(card.card_name),
					"special_setup": TiamatScript.build_special_setup(canonical_slots),
				}
			var canonical_name := str(card.card_name)
			if seen_card_names.has(canonical_name):
				return {
					"is_valid": false,
					"error": "Tiamat slot creatures must all be different. %s was chosen more than once." % canonical_name,
					"special_setup": TiamatScript.build_special_setup(canonical_slots),
				}
			seen_card_names[canonical_name] = true
			slot_level_total += int(card.level)
			canonical_slot.append(canonical_name)
		if slot_level_total > TiamatScript.MAX_SLOT_LEVEL_TOTAL:
			return {
				"is_valid": false,
				"error": "Tiamat slot %d exceeds %d total levels." % [slot_index + 1, TiamatScript.MAX_SLOT_LEVEL_TOTAL],
				"special_setup": TiamatScript.build_special_setup(canonical_slots),
			}
		canonical_slots.append(canonical_slot)
		if canonical_slots.size() >= TiamatScript.POWER_SLOT_COUNT:
			break

	if occupied_slot_count <= 0:
		return {"is_valid": true, "error": "", "special_setup": {}}
	if not TiamatScript.is_tiamat_god(god_template):
		return {
			"is_valid": false,
			"error": "Only Tiamat can use Matriarch Rule slot creatures.",
			"special_setup": TiamatScript.build_special_setup(canonical_slots),
		}
	if power_count + occupied_slot_count > MAX_POWERS:
		return {
			"is_valid": false,
			"error": "Tiamat deck uses %d total power slots (powers + Matriarch slots), but only %d are allowed." % [
				power_count + occupied_slot_count,
				MAX_POWERS
			],
			"special_setup": TiamatScript.build_special_setup(canonical_slots),
		}
	return {
		"is_valid": true,
		"error": "",
		"special_setup": TiamatScript.build_special_setup(canonical_slots),
	}

func _result(is_valid: bool, error_message: String, sanitized_cards: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var output := {
		"is_valid": is_valid,
		"error": error_message,
		"cards": sanitized_cards.duplicate(true),
	}
	output.merge(extra, true)
	return output

func _max_copies(card) -> int:
	if bool(card.is_god):
		return 1
	if bool(card.is_power):
		return 1
	if bool(card.is_legendary):
		return 1
	return 3

func _validate_active_gods_for_deck(sanitized_cards: Dictionary, god_template) -> Dictionary:
	var god_card := god_template as GodCard
	if god_card == null or god_card.uses_culture_locked_deckbuilding():
		return {
			"is_valid": true,
			"error": "",
			"reserved_active_god_count": 0,
		}
	var illegal_active_gods: PackedStringArray = []
	var reserved_active_god_count := 0
	for card_name in sanitized_cards.keys():
		var card = _cards_by_name.get(card_name, null)
		if card is not ActiveGodCard:
			continue
		var active_god := card as ActiveGodCard
		var count := int(sanitized_cards.get(card_name, 0))
		match god_card.get_active_god_deck_role(active_god):
			GodCard.ACTIVE_GOD_DECK_ROLE_RESERVED:
				if count > 1:
					return {
						"is_valid": false,
						"error": "%s can reserve at most 1 copy of its own Active God." % god_card.card_name,
						"reserved_active_god_count": reserved_active_god_count,
					}
				reserved_active_god_count += count
			_:
				illegal_active_gods.append(str(active_god.card_name))
	if illegal_active_gods.is_empty():
		return {
			"is_valid": true,
			"error": "",
			"reserved_active_god_count": reserved_active_god_count,
		}
	return {
		"is_valid": false,
		"error": "Non-Patriarch/Matriarch gods cannot include other Active God cards in their deck: %s." % ", ".join(illegal_active_gods),
		"reserved_active_god_count": reserved_active_god_count,
	}
