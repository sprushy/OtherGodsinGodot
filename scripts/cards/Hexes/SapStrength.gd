extends HexCard
class_name SapStrength

const ART_PATH := "res://images/card_art/hexes/SapStrengthEdit2.png"
const STR_REDUCTION := 10
const DEBUFF_SOURCE := "Sap Strength"
const DEBUFF_EFFECT_TYPE := "sap_strength_debuff"

func _init() -> void:
	super._init()
	card_name = "Sap Strength"
	level = 3
	mana_cost = 0
	speed = 4
	culture = "Ancient"
	card_types = ["Sap"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "Reduce a creature's Str by 10 until the end of the turn."
	flavor_text = ""
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	targets = true

func can_respond_to_action(_action: CardAction) -> bool:
	return true

func get_priority_targets(game_manager: GameManager, _action: CardAction) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_target(game_manager, card):
					valid_targets.append(card)
	return valid_targets

func on_activate_action(game_manager: GameManager, action: CardAction) -> void:
	var target := action.target as Card
	if not is_valid_target(game_manager, target):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose a creature." % card_name)
		if card_owner != null:
			card_owner.move_card(self, card_owner.graveyard_zone)
		return

	target.add_buff(
		DEBUFF_SOURCE,
		-STR_REDUCTION,
		0,
		0,
		self,
		card_owner,
		DEBUFF_EFFECT_TYPE,
		{"expires_turn": game_manager.turn_number}
	)

	var target_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.note_player_feedback(
		"%s reduced %s's Str by %d until end of turn." % [
			card_name,
			target_name,
			STR_REDUCTION
		]
	)
	card_owner.move_card(self, card_owner.graveyard_zone)

func is_valid_target(game_manager: GameManager, target: Card) -> bool:
	if game_manager == null or target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	if game_manager.is_immune_to_source(target, self):
		return false
	return true
