extends CharmCard
class_name NamburbiApotropaeon

const ART_PATH := "res://images/card_art/charms/NamburbiArt.jpg"

func _init() -> void:
	super._init()
	card_name = "Namburbi Apotropaeon"
	culture = "Ancient"
	card_types = ["Charm", "Ward", "Creatures"]
	level = 2
	mana_cost = 0
	speed = 2
	flavor_text = ""
	ability_text = "Activate at the beginning of a turn. Your opponent cannot activate any effects that would destroy one of your creatures this turn."
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func can_activate_from_hand(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_from_hand(game_manager, triggering_action):
		return false
	return _is_valid_turn_start_window(triggering_action)

func can_activate_prepared(game_manager: GameManager, triggering_action: CardAction = null) -> bool:
	if not super.can_activate_prepared(game_manager, triggering_action):
		return false
	return _is_valid_turn_start_window(triggering_action)

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null or card_owner == null:
		return
	game_manager.grant_turn_destruction_ward(card_owner, self, game_manager.turn_number)
	game_manager.note_player_feedback("%s wards %s's creatures from opposing destruction effects this turn." % [
		card_name,
		card_owner.player_name
	])

func _is_valid_turn_start_window(triggering_action: CardAction) -> bool:
	return triggering_action != null \
		and triggering_action.type == CardAction.Type.EVENT \
		and triggering_action.event_name == "start_turn"
