extends HexCard
class_name SepLemutti

const ART_PATH := "res://images/card_art/hexes/sep_lemutti.png"
const RETURNABLE_TYPES := ["Spirit", "Monster", "Undead", "Demon"]

func _init() -> void:
	super._init()
	card_name = "Sep Lemutti"
	level = 2
	mana_cost = 1
	speed = 4
	culture = "Ancient"
	card_types = ["Hex"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "Activate when a Spirit, Monster, Undead, or Demon is summoned; return it to the deck."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	targets = true

func can_respond_to_action(action: CardAction) -> bool:
	return action != null \
		and action.type == CardAction.Type.EVENT \
		and action.event_name == "summon"

func get_priority_targets(game_manager: GameManager, action: CardAction) -> Array[Card]:
	if action == null:
		return []
	var summoned_card := action.card
	if not is_valid_target(game_manager, summoned_card):
		return []
	return [summoned_card]

func requires_priority_target_selection() -> bool:
	return false

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var target := action.target as Card
	if not is_valid_target(game_manager, target):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: target is no longer a valid summoned creature." % card_name)
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	var target_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback("%s triggered, but %s was immune to hexes." % [card_name, target_name])
		on_immune_activate(game_manager, target, target)
		return

	game_manager.send_to_deck_bottom_with_hook(target)
	game_manager.note_player_feedback("%s returned %s to its owner's deck." % [card_name, target_name])
	if card_owner != null:
		card_owner.move_card(self, card_owner.graveyard_zone)

func is_valid_target(game_manager: GameManager, target: Card) -> bool:
	if game_manager == null or target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	for required_type in RETURNABLE_TYPES:
		if target.has_type(required_type):
			return true
	return false
