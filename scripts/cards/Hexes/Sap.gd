extends HexCard
class_name Sap

const ART_PATH := "res://images/card_art/hexes/Sap_web.jpg"

func _init() -> void:
	super._init()
	card_name = "Sap"
	level = 3
	mana_cost = 0
	speed = 3
	culture = "Neutral"
	card_types = ["Destruction", "Front Line"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "When one or more cards are placed on the front line, destroy them."
	flavor_text = ""
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	targets = true

func can_respond_to_action(action: CardAction) -> bool:
	return action != null \
		and action.type == CardAction.Type.EVENT \
		and action.event_name == "frontline_entry"

func can_respond_to_frontline_entry(action: CardAction) -> bool:
	return can_respond_to_action(action)

func get_priority_targets(game_manager: GameManager, action: CardAction) -> Array[Card]:
	if action == null:
		return []
	var entered_card := action.card
	if not is_valid_target(game_manager, entered_card):
		return []
	return [entered_card]

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var target := action.target as Card
	if not is_valid_target(game_manager, target):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: target is no longer on the frontline." % card_name)
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var target_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
	if game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback("%s triggered, but %s was immune to hexes." % [card_name, target_name])
		on_immune_activate(game_manager, target, target)
	elif game_manager.request_send_to_graveyard(target, Callable(), false, true):
		game_manager.note_player_feedback("%s destroyed %s." % [card_name, target_name])
	else:
		game_manager.note_player_feedback("%s triggered, but %s could not be destroyed." % [card_name, target_name])

	if current_zone != null and card_owner != null:
		card_owner.move_card(self, card_owner.graveyard_zone)

func is_valid_target(game_manager: GameManager, target: Card) -> bool:
	if game_manager == null or target == null:
		return false
	if target.current_zone == null or target.current_zone.zone_type != Zone.ZoneType.FRONTLINE:
		return false
	if game_manager.is_immune_to_source(target, self):
		return false
	return true
