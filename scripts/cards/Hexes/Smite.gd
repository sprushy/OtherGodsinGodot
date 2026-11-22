extends HexCard
class_name Smite

const ART_PATH := "res://images/card_art/hexes/SmiteArt.jpg"

func _init() -> void:
	super._init()
	card_name = "Smite"
	level = 2
	mana_cost = 0
	speed = 5
	culture = "Neutral"
	card_types = ["Destruction", "Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "When a creature declares an attack, destroy it."
	flavor_text = ""
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	targets = true

func can_activate(attacker: Card, _defender: Card) -> bool:
	if attacker == null:
		return false
	if attacker.card_type != Card.CardType.CREATURE:
		return false
	if attacker.current_zone == null or not attacker.current_zone.is_board_zone():
		return false
	return attacker.get_effective_speed() <= get_effective_speed()

func requires_priority_target_selection() -> bool:
	return false

func get_affected_cards(attacker: Card, _defender: Card) -> Array[Card]:
	var affected: Array[Card] = []
	if attacker != null:
		affected.append(attacker)
	return affected

func on_activate(game_manager: GameManager, attacker: Card, _defender: Card) -> void:
	if game_manager == null or card_owner == null:
		return
	if attacker == null or attacker.current_zone == null or not attacker.current_zone.is_board_zone():
		game_manager.note_player_feedback("%s fizzles: the attacking creature already left the field." % card_name)
		card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var viewer := game_manager.get_feedback_viewer()
	var attacker_name := attacker.get_target_log_display_name(viewer)
	game_manager.request_send_to_graveyard(attacker, func() -> void:
		if game_manager.reached_public_destroyed_destination(attacker):
			var destroyed_name := game_manager.get_resolved_destruction_log_name(attacker, viewer, attacker_name)
			game_manager.note_player_feedback("%s destroyed %s when it declared an attack." % [card_name, destroyed_name])
		else:
			game_manager.note_player_feedback("%s triggered, but %s could not be destroyed." % [card_name, attacker_name])
	, false, true)

	card_owner.move_card(self, card_owner.graveyard_zone)
