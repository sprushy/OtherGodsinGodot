extends RefCounted
class_name DeckValidator

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
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

func validate_deck(deck_cards: Dictionary) -> Dictionary:
	var sanitized_cards: Dictionary = {}
	var god_count := 0
	var power_count := 0
	var regular_count := 0
	var legendary_count := 0
	var god_culture := ""
	var invalid_powers: PackedStringArray = []

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
	if regular_count < MIN_REGULAR_CARDS:
		return _result(false, "Deck must contain at least %d non-God, non-Power cards." % MIN_REGULAR_CARDS, sanitized_cards)

	for card_name in sanitized_cards.keys():
		var card = _cards_by_name[card_name]
		if not bool(card.is_power) or bool(card.is_god):
			continue
		if god_culture.is_empty():
			continue
		var culture := str(card.culture)
		if culture != "Neutral" and culture != god_culture:
			invalid_powers.append(card_name)

	if not invalid_powers.is_empty():
		return _result(false, "Power culture mismatch: %s." % ", ".join(invalid_powers), sanitized_cards)

	var max_legendaries := int(floor(regular_count / 10.0))
	if legendary_count > max_legendaries:
		return _result(false, "Deck has too many legendary cards (%d / %d)." % [legendary_count, max_legendaries], sanitized_cards)

	return _result(true, "", sanitized_cards, {
		"total_cards": regular_count + god_count + power_count,
		"god_count": god_count,
		"power_count": power_count,
		"regular_count": regular_count,
		"legendary_count": legendary_count,
		"god_culture": god_culture,
	})

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
	if bool(card.is_legendary):
		return 1
	return 3
