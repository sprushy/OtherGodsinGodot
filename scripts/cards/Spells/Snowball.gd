extends SpellCard
class_name Snowball

const ART_PATH := "res://images/card_art/spells/snowball.png"
const STRENGTH_REDUCTION := 2
const DEBUFF_EFFECT_TYPE := "snowball_debuff"

func _init() -> void:
	super._init()
	card_name = "Snowball"
	culture = "Neutral"
	card_types = ["Targeting"]
	level = 1
	mana_cost = 0
	speed = 1
	is_single_player_card = true
	targets = true
	artist = "User provided"
	art_path = ART_PATH
	ability_text = "Reduce a creature's Str by 2 until the end of the turn."

func resolve(game_manager: GameManager, target = null) -> void:
	var creature := target as Card
	if not is_valid_target(game_manager, creature):
		if game_manager != null:
			game_manager.note_player_feedback("Snowball fizzles: choose a creature on the field.")
		return
	creature.add_buff(
		card_name,
		-STRENGTH_REDUCTION,
		0,
		0,
		self,
		card_owner,
		DEBUFF_EFFECT_TYPE,
		{"expires_turn": game_manager.turn_number}
	)
	var target_name := creature.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.note_player_feedback(
		"Snowball reduced %s's Str by %d until end of turn." % [target_name, STRENGTH_REDUCTION]
	)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if get_valid_targets(game_manager).is_empty():
		return "Snowball has no valid targets."
	return ""

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
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

func is_valid_target(game_manager: GameManager, target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and not game_manager.is_immune_to_source(target, self)
