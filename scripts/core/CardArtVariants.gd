extends RefCounted
class_name CardArtVariants

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")
const SPECIAL_SETUP_KEY := "art_variants"

static func get_selections_from_setup(special_setup) -> Dictionary:
	if not (special_setup is Dictionary):
		return {}
	var raw_selections = (special_setup as Dictionary).get(SPECIAL_SETUP_KEY, {})
	if not (raw_selections is Dictionary):
		return {}
	var selections: Dictionary = {}
	for raw_card_name in (raw_selections as Dictionary).keys():
		var template = CardCatalogScript.instantiate_card_by_name(str(raw_card_name))
		if template == null or not template.has_method("get_art_variant_paths"):
			continue
		var variants: Array[String] = template.get_art_variant_paths()
		var variant_index := int((raw_selections as Dictionary)[raw_card_name])
		if variants.size() <= 1 or variant_index <= 0 or variant_index >= variants.size():
			continue
		selections[str(template.card_name)] = variant_index
	return selections

static func build_special_setup(tiamat_slots: Array, selections: Dictionary) -> Dictionary:
	var setup := TiamatScript.build_special_setup(tiamat_slots)
	var sanitized_selections := get_selections_from_setup({SPECIAL_SETUP_KEY: selections})
	if not sanitized_selections.is_empty():
		setup[SPECIAL_SETUP_KEY] = sanitized_selections
	return setup

static func sanitize_special_setup(special_setup) -> Dictionary:
	if not (special_setup is Dictionary):
		return {}
	return build_special_setup(
		TiamatScript.get_slot_card_names_from_setup(special_setup),
		get_selections_from_setup(special_setup)
	)

static func apply_to_card(card: Card, special_setup) -> void:
	if card == null:
		return
	var selections := get_selections_from_setup(special_setup)
	var variant_index := int(selections.get(card.card_name, 0))
	if card.has_method("set_art_variant"):
		card.set_art_variant(variant_index)
