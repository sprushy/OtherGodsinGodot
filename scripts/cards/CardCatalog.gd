extends RefCounted
class_name CardCatalog

const CARDS_DIR := "res://scripts/cards/"
const EXCLUDED_FILENAMES := [
	"BaseCard.gd",
	"card.gd",
	"CardCatalog.gd",
	"CharmCard.gd",
	"CreatureCard.gd",
	"Deck.gd",
	"EquipmentCard.gd",
	"GenericCreature.gd",
	"GodCard.gd",
	"HexCard.gd",
	"PermanentHexCard.gd",
	"PowerCard.gd",
	"SpellCard.gd",
	"StructureCard.gd"
]

static var _cached_all_cards: Array[Card] = []

static func make_all_cards() -> Array[Card]:
	if not _cached_all_cards.is_empty():
		var duplicates: Array[Card] = []
		for card in _cached_all_cards:
			duplicates.append(card.duplicate(true))
		return duplicates
	
	var discovered_cards: Array[Card] = []
	_discover_cards_recursive(CARDS_DIR, discovered_cards)
	
	_cached_all_cards = discovered_cards
	
	# Return duplicates so the caller doesn't modify the cache
	var duplicates: Array[Card] = []
	for card in _cached_all_cards:
		duplicates.append(card.duplicate(true))
	return duplicates

static func _discover_cards_recursive(path: String, out_cards: Array[Card]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		print("CardCatalog: Error opening directory ", path)
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_discover_cards_recursive(path + file_name + "/", out_cards)
		else:
			if file_name.ends_with(".gd") and file_name not in EXCLUDED_FILENAMES:
				var full_path := path + file_name
				var script: GDScript = load(full_path)
				if script:
					var inst = script.new()
					if inst is Card:
						var is_valid_for_catalog := true
						# Skip tokens - check both property and card types
						if inst.is_token or inst.card_types.has("Token"):
							is_valid_for_catalog = false
						# Skip base/placeholder cards
						elif inst.card_name == "" or inst.card_name == "Unnamed" or inst.card_name == "Card":
							is_valid_for_catalog = false
						
						if is_valid_for_catalog:
							out_cards.append(inst)
						else:
							if inst is Object and not inst is RefCounted:
								inst.free()
					else:
						# If it's not a Card instance, we should free it if it's an Object
						if inst is Object and not inst is RefCounted:
							inst.free()
		file_name = dir.get_next()
	dir.list_dir_end()

static func instantiate_card_by_name(card_name: String) -> Card:
	var requested_name := str(card_name).strip_edges()
	if requested_name.is_empty():
		return null
	
	# Ensure cache is populated
	if _cached_all_cards.is_empty():
		make_all_cards()
		
	var requested_lookup_key: String = to_lookup_key(requested_name)
	for template in _cached_all_cards:
		if template == null:
			continue
		if _matches_card_name(template, requested_name):
			return template.duplicate(true)
		if requested_lookup_key == to_lookup_key(str(template.card_name)):
			return template.duplicate(true)
		if template.has_method("get_normalized_card_name") and requested_lookup_key == to_lookup_key(str(template.get_normalized_card_name())):
			return template.duplicate(true)
		if template.has_method("get_ascii_card_name") and requested_lookup_key == to_lookup_key(str(template.get_ascii_card_name())):
			return template.duplicate(true)
	return null

static func make_cards_from_counts(card_counts: Dictionary) -> Array[Card]:
	var cards: Array[Card] = []
	for raw_card_name in card_counts.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(card_counts[raw_card_name])
		if card_name.is_empty() or count <= 0:
			continue
		for _copy_index in range(count):
			var card := instantiate_card_by_name(card_name)
			if card != null:
				cards.append(card)
	return cards

static func _matches_card_name(card: Card, requested_name: String) -> bool:
	if card == null:
		return false
	if str(card.card_name) == requested_name:
		return true
	if card.has_method("get_normalized_card_name") and str(card.get_normalized_card_name()) == requested_name:
		return true
	if card.has_method("get_ascii_card_name") and str(card.get_ascii_card_name()) == requested_name:
		return true
	return false

static func to_lookup_key(card_name: String) -> String:
	var normalized_name: String = str(card_name).strip_edges().to_lower()
	var output := ""
	for char_index in range(normalized_name.length()):
		var codepoint := normalized_name.unicode_at(char_index)
		var is_digit := codepoint >= 48 and codepoint <= 57
		var is_upper := codepoint >= 65 and codepoint <= 90
		var is_lower := codepoint >= 97 and codepoint <= 122
		if is_digit or is_upper or is_lower:
			output += normalized_name[char_index]
	return output
