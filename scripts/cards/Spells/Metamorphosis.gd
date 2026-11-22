extends SpellCard
class_name Metamorphosis

static var _subtype_options: Array[String] = []

func _init() -> void:
	super._init()
	card_name = "Metamorphosis"
	culture = "Olympic"
	card_types = ["Transformation"]
	level = 2
	mana_cost = 0
	artist = "User-provided"
	art_path = "res://images/card_art/spells/Metamorphosis.png"
	ability_text = "Name a subtype. Replace the subtypes of every card on the field with that subtype for as long as each card remains in play."

static func get_subtype_options() -> Array[String]:
	if _subtype_options.is_empty():
		var types := {}
		for template in CardCatalog.get_cached_card_templates():
			for type_name in template.card_types:
				for subtype in CardSubtypes.expand(type_name):
					if subtype not in CardSubtypes.FIXED_TYPES:
						types[subtype] = true
		for type_name: String in CardSubtypes.PARENTS:
			for subtype in CardSubtypes.expand(type_name):
				types[subtype] = true
		_subtype_options.assign(types.keys())
		_subtype_options.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return _subtype_options.duplicate()

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	resolve(game_manager, command.get("subtype", ""))

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	if not target is String or target not in get_subtype_options():
		game_manager.note_player_feedback("Metamorphosis needs a valid subtype.")
		return

	var new_types := CardSubtypes.expand(target)
	var field_cards := game_manager.get_field_cards(null, true, true).filter(func(card: Card) -> bool:
		return card != self and not game_manager.is_immune_to_source(card, self)
	)

	var transformed_creatures: Array[Card] = []
	for card: Card in field_cards:
		var previous_types := card.get_subtypes()
		var replacement := new_types.duplicate()
		for type_name in previous_types:
			if type_name in CardSubtypes.FIXED_TYPES:
				replacement.append(type_name)
		var changed := previous_types.size() != replacement.size() \
			or previous_types.any(func(type_name: String) -> bool: return type_name not in replacement)
		if changed and card.is_creature_card():
			transformed_creatures.append(card)
		card.replace_field_subtypes(replacement)

	for creature in transformed_creatures:
		game_manager.notify_creature_shapeshifted(creature, self)
	game_manager.note_player_feedback("Metamorphosis changed the field's subtypes to %s." % target)
