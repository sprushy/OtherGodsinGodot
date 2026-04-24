extends HexCard
class_name VisionOfTartarus

const ART_PATH := "res://images/card_art/hexes/VisionofTarturusEdit.png"
const DEBUFF_PER_VOID_CREATURE := 3
const EFFECT_SOURCE := "Vision of Tartarus"
const EFFECT_TYPE := "vision_of_tartarus_modifier"

func _init() -> void:
	super._init()
	card_name = "Vision of Tartarus"
	level = 2
	mana_cost = 0
	speed = 3
	culture = "Olympic"
	card_types = ["Sap"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	ability_text = "Choose a creature. It gets -3 Str and -3 Res until end of turn for each creature in the Void."
	flavor_text = ""
	artist = ""
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

	var viewer := game_manager.get_feedback_viewer()
	var target_name := target.get_target_log_display_name(viewer)
	var void_creature_count := _count_void_creatures(game_manager)
	var stat_reduction := void_creature_count * DEBUFF_PER_VOID_CREATURE

	if stat_reduction > 0:
		target.add_buff(
			EFFECT_SOURCE,
			-stat_reduction,
			-stat_reduction,
			0,
			self,
			card_owner,
			EFFECT_TYPE,
			{"expires_turn": game_manager.turn_number}
		)
		game_manager.note_player_feedback(
			"%s gives %s -%d Str and -%d Res until end of turn." % [
				card_name,
				target_name,
				stat_reduction,
				stat_reduction
			]
		)
	else:
		game_manager.note_player_feedback(
			"%s found no creatures in the Void, so %s was unchanged." % [
				card_name,
				target_name
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

func _count_void_creatures(game_manager: GameManager) -> int:
	if game_manager == null:
		return 0
	var total := 0
	for player in game_manager.players:
		if player == null:
			continue
		for card in player.abyss_zone.cards:
			if card != null and card.card_type == Card.CardType.CREATURE:
				total += 1
	return total
