extends HexCard
class_name SpellDemolition

const ART_PATH := "res://images/card_art/hexes/SpellDemolitionArt.jpg"

func _init() -> void:
	super._init()
	card_name = "Spell Demolition"
	level = 3
	mana_cost = 1
	speed = 3
	culture = "Neutral"
	card_types = ["Destruction", "Magical"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "Silence and destroy a spell."
	flavor_text = ""
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	targets = true

func can_respond_to_action(action: CardAction) -> bool:
	if action == null or action.card == null:
		return false
	if action.type != CardAction.Type.SPELL:
		return false
	if action.card.has_method("can_be_negated") and not action.card.can_be_negated(action):
		return false
	return action.card.card_type == Card.CardType.SPELL

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var negated_action := action.response_to
	if game_manager == null or card_owner == null:
		return
	if negated_action == null or negated_action.card == null:
		card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var target_spell := negated_action.card
	var viewer := game_manager.get_feedback_viewer()
	var target_name := target_spell.get_target_log_display_name(viewer) if target_spell is Card else target_spell.card_name

	if negated_action in game_manager.action_stack:
		game_manager.action_stack.erase(negated_action)

	if target_spell.current_zone != null and target_spell.current_zone != target_spell.card_owner.graveyard_zone:
		game_manager.request_send_to_graveyard(target_spell, func() -> void:
			if game_manager.reached_public_destroyed_destination(target_spell):
				var destroyed_name := game_manager.get_resolved_destruction_log_name(target_spell, viewer, target_name)
				game_manager.note_player_feedback("%s silenced and destroyed %s." % [card_name, destroyed_name])
			else:
				game_manager.note_player_feedback("%s silenced %s, but it was not destroyed." % [card_name, target_name])
		, false, true)
	else:
		var destroyed_name := game_manager.get_resolved_destruction_log_name(target_spell, viewer, target_name)
		game_manager.note_player_feedback("%s silenced and destroyed %s." % [card_name, destroyed_name])
	card_owner.move_card(self, card_owner.graveyard_zone)
