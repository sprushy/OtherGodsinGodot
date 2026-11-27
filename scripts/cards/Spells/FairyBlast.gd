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
	ability_text = "Halve a creature's Str and SPD and [b]Paralyze[/b] it."

func resolve(game_manager: GameManager, target = null) -> void:
	var creature := target as Card
	if not is_valid_target(game_manager, creature):
		if game_manager != null:
			game_manager.note_player_feedback("Fairy Blast fizzles: choose a creature on the field.")
		return
	var stat_changes := get_stat_changes(creature)
	if stat_changes.str != 0 or stat_changes.spd != 0:
		creature.add_buff(
			card_name,
			stat_changes.str,
			stat_changes.res,
			stat_changes.spd,
			self,
			card_owner,
			DEBUFF_EFFECT_TYPE
		)
	creature.apply_paralyze(self)
	var target_name := creature.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.note_player_feedback(
		"Fairy Blast halved %s's Str and SPD and paralyzed it." % target_name
	)

static func get_stat_changes(creature: Card) -> Dictionary:
	if creature == null:
		return {"str": 0, "res": 0, "spd": 0}
	var current_strength := creature.get_effective_strength()
	var current_speed := creature.get_effective_speed()
	var halved_strength := floori(current_strength / 2.0)
	var halved_speed := maxi(1, floori(current_speed / 2.0))
	return {"str": halved_strength - current_strength, "res": 0, "spd": halved_speed - current_speed}

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
