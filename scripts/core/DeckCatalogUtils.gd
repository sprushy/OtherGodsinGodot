extends RefCounted
class_name DeckCatalogUtils

static func semantic_signature(deck: Dictionary) -> String:
	var normalized := {
		"name": str(deck.get("name", "")).strip_edges().to_lower(),
		"cards": _normalize_variant(deck.get("cards", {})),
		"reinforcements": _normalize_variant(deck.get("reinforcements", {})),
		"special_setup": _normalize_variant(deck.get("special_setup", {})),
	}
	return JSON.stringify(normalized)

static func dedupe_exact_copies(
	decks: Array[Dictionary],
	preferred_deck_id: String = "",
	selected_deck_id: String = ""
) -> Array[Dictionary]:
	var deduped: Array[Dictionary] = []
	var deck_id_to_index: Dictionary = {}
	var signature_to_index: Dictionary = {}
	var resolved_preferred_id := preferred_deck_id.strip_edges()
	var resolved_selected_id := selected_deck_id.strip_edges()

	for entry in decks:
		var deck := entry.duplicate(true)
		var deck_id := str(deck.get("deck_id", "")).strip_edges()
		if not deck_id.is_empty() and deck_id_to_index.has(deck_id):
			var existing_by_id_index := int(deck_id_to_index[deck_id])
			if _should_replace_visible_deck(
				deduped[existing_by_id_index],
				deck,
				resolved_preferred_id,
				resolved_selected_id
			):
				deduped[existing_by_id_index] = deck
			continue

		var signature := semantic_signature(deck)
		if signature_to_index.has(signature):
			var existing_by_signature_index := int(signature_to_index[signature])
			if _should_replace_visible_deck(
				deduped[existing_by_signature_index],
				deck,
				resolved_preferred_id,
				resolved_selected_id
			):
				deduped[existing_by_signature_index] = deck
				if not deck_id.is_empty():
					deck_id_to_index[deck_id] = existing_by_signature_index
			continue

		var next_index := deduped.size()
		deduped.append(deck)
		signature_to_index[signature] = next_index
		if not deck_id.is_empty():
			deck_id_to_index[deck_id] = next_index

	return deduped

static func _should_replace_visible_deck(
	existing_deck: Dictionary,
	candidate_deck: Dictionary,
	preferred_deck_id: String,
	selected_deck_id: String
) -> bool:
	var existing_priority := _deck_priority(existing_deck, preferred_deck_id, selected_deck_id)
	var candidate_priority := _deck_priority(candidate_deck, preferred_deck_id, selected_deck_id)
	if candidate_priority != existing_priority:
		return candidate_priority > existing_priority

	var existing_updated := int(existing_deck.get("updated_unix", 0))
	var candidate_updated := int(candidate_deck.get("updated_unix", 0))
	if candidate_updated != existing_updated:
		return candidate_updated > existing_updated

	var existing_created := int(existing_deck.get("created_unix", 0))
	var candidate_created := int(candidate_deck.get("created_unix", 0))
	if candidate_created != existing_created:
		return candidate_created > existing_created

	var existing_id := str(existing_deck.get("deck_id", "")).strip_edges()
	var candidate_id := str(candidate_deck.get("deck_id", "")).strip_edges()
	if existing_id.is_empty() != candidate_id.is_empty():
		return not candidate_id.is_empty()
	return false

static func _deck_priority(deck: Dictionary, preferred_deck_id: String, selected_deck_id: String) -> int:
	var deck_id := str(deck.get("deck_id", "")).strip_edges()
	if deck_id.is_empty():
		return 0
	if deck_id == selected_deck_id:
		return 2
	if deck_id == preferred_deck_id:
		return 1
	return 0

static func _normalize_variant(value):
	if value is Dictionary:
		var normalized: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		for raw_key in keys:
			var key := str(raw_key)
			normalized[key] = _normalize_variant((value as Dictionary)[raw_key])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize_variant(item))
		return normalized_array
	if value is PackedStringArray:
		var normalized_packed: Array = []
		for item in value:
			normalized_packed.append(_normalize_variant(item))
		return normalized_packed
	return value
