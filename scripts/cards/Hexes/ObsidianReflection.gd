extends HexCard
class_name ObsidianReflection

const ART_PATH := "res://images/card_art/hexes/ObsidianReflection.png"

func _init() -> void:
	super._init()
	card_name = "Obsidian Reflection"
	level = 2
	mana_cost = 0
	speed = 4
	culture = "Nahuatl"
	card_types = ["Mirror", "Targeting"]
	ability_text = "When a creature attacks, reverse the follower damage from that attack."
	flavor_text = ""
	artist = "User provided"
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
	game_manager.set_temporary_combat_follower_damage_reversed(true)
	var viewer := game_manager.get_feedback_viewer()
	var attacker_name := attacker.get_target_log_display_name(viewer)
	game_manager.note_player_feedback("%s reflects %s's attack, reversing its follower damage." % [card_name, attacker_name])
	card_owner.move_card(self, card_owner.graveyard_zone)