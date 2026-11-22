extends SpellCard
class_name Metamorphosis

var chosen_subtypes: Array[String] = []
var aura_order: int = -1

func _init() -> void:
	super._init()
	card_name = "Metamorphosis"
	culture = "Olympic"
	card_types = ["Transformation", "Aura", "Permanent"]
	level = 2
	mana_cost = 0
	artist = "User-provided"
	art_path = "res://images/card_art/spells/Metamorphosis.png"
	ability_text = "Choose a creature typing from your starting deck; while Metamorphosis is face-up all face-up creatures have that typing."

func should_go_to_graveyard() -> bool:
	return false

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	return player != null and not player.starting_creature_typings.is_empty() and super.can_be_played(game_manager, player)

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var reason := super.get_play_failure_reason(game_manager, player)
	if not reason.is_empty():
		return reason
	if player.starting_creature_typings.is_empty():
		return "Metamorphosis needs a creature in your starting decklist or Reinforcements."
	if current_zone == player.hand_zone:
		for zone in player.frontline_zones + player.reserve_zones:
			if zone.cards.is_empty():
				return ""
		return "Metamorphosis needs an empty friendly lane."
	if aura_order >= 0:
		return "Metamorphosis is already on the field."
	return ""

func is_aura_live() -> bool:
	return aura_order >= 0 \
		and current_zone != null and current_zone.is_board_zone() \
		and not is_face_down and not is_stealth and not is_prepared \
		and not abilities_suppressed()

func on_removed(game_manager: GameManager) -> void:
	if game_manager != null:
		game_manager.remove_metamorphosis_aura(self)
	chosen_subtypes.clear()
	aura_order = -1

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	var lines: Array[String] = []
	if aura_order >= 0:
		lines.append(CardSubtypes.format_typing(chosen_subtypes))
	return lines

func get_serialized_state() -> Dictionary:
	if aura_order < 0:
		return {}
	return {"chosen_subtypes": chosen_subtypes.duplicate(), "aura_order": aura_order}

func apply_serialized_state(state: Dictionary) -> void:
	if state.has("chosen_subtypes"):
		chosen_subtypes = CardSubtypes.get_transferable_subtypes(state["chosen_subtypes"])
	else:
		var old_subtype := str(state.get("named_subtype", ""))
		chosen_subtypes = CardSubtypes.get_transferable_subtypes([old_subtype] if not old_subtype.is_empty() else [])
	aura_order = int(state.get("aura_order", -1))

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	resolve(game_manager, command.get("creature_typing", ""))

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	if not target is String or card_owner == null or not card_owner.starting_creature_typings.has(target):
		game_manager.note_player_feedback("Choose a creature typing from your starting decklist or Reinforcements for Metamorphosis.")
		return
	if current_zone == null or not current_zone.is_board_zone():
		game_manager.note_player_feedback("Metamorphosis fizzles because it has no open lane.")
		if card_owner != null and current_zone == card_owner.hand_zone:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var previous_types: Dictionary[Card, Array] = {}
	for creature in game_manager.get_field_cards():
		if creature.is_creature_card() and not creature.is_face_down and not creature.is_stealth:
			previous_types[creature] = creature.get_subtypes()
	chosen_subtypes.assign(card_owner.starting_creature_typings[target])
	game_manager.add_metamorphosis_aura(self)
	for creature: Card in previous_types:
		if creature.get_subtypes() != previous_types[creature]:
			game_manager.notify_creature_shapeshifted(creature, self)
	game_manager.note_player_feedback("Metamorphosis applies %s." % CardSubtypes.format_typing(chosen_subtypes))
