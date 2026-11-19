extends SpellCard
class_name FairyBlast

const ART_PATH := "res://images/card_art/spells/FairyBlast.png"
const DEBUFF_EFFECT_TYPE := "fairy_blast_debuff"

func _init() -> void:
	super._init()
	card_name = "Fairy Blast"
	culture = "Triskelion"
	card_types = ["Fairy", "Targeting", "Paralytic"]
	level = 3
	mana_cost = 0
	speed = 1
	targets = true
	artist = "User provided"
	art_path = ART_PATH
	ability_text = "Halve a creature's Str and SPD and Paralyze it."

func resolve(game_manager: GameManager, target = null) -> void:
	var creature := target as Card
	if not is_valid_target(game_manager, creature):
		if game_manager != null:
			game_manager.note_player_feedback("Fairy Blast fizzles: choose a creature on the field.")
		return
	var current_strength := creature.get_effective_strength()
	var strength_reduction := int(current_strength / 2.0)
	var current_speed := creature.get_effective_speed()
	var speed_reduction := int(current_speed / 2.0)
	if strength_reduction > 0 or speed_reduction > 0:
		creature.add_buff(
			card_name,
			-strength_reduction,
			0,
			-speed_reduction,
			self,
			card_owner,
			DEBUFF_EFFECT_TYPE
		)
	creature.add_status_effect(
		Card.PARALYZED_STATUS,
		card_name,
		self,
		card_owner
	)
	var target_name := creature.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.note_player_feedback(
		"Fairy Blast halved %s's Str and SPD and paralyzed it." % target_name
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
		return "Fairy Blast has no valid targets."
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