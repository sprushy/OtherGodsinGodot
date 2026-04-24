extends CreatureCard
class_name Rabisu

const ART_PATH := "res://images/card_art/creatures/RabisuEdit.png"
const LIFE_DRAIN_SOURCE := "Rabisu Life Drain"
const LIFE_DRAIN_EFFECT_TYPE := "rabisu_life_drain"
const DRAIN_PER_SLEEPING_CREATURE := 3

func _init() -> void:
	super._init()
	card_name = "Rabisu"
	card_types = ["Demon", "Vampire", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 17
	strength = 17
	ability_text = "[b]Life Drain[/b] ([b]Impact[/b]): For each sleeping enemy creature on the field, it loses 3 Str and 3 Res, and this card gains 3 Str and 3 Res."
	flavor_text = ""
	culture = "Ancient"
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return

	var drained_targets: Array[String] = []
	var drained_count := 0
	var controller := get_controller()

	for player in game_manager.players:
		if player == null or player == controller:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var creature := card as Card
				if not _can_drain_creature(game_manager, creature):
					continue
				creature.add_buff(
					LIFE_DRAIN_SOURCE,
					-DRAIN_PER_SLEEPING_CREATURE,
					-DRAIN_PER_SLEEPING_CREATURE,
					0,
					self,
					controller,
					LIFE_DRAIN_EFFECT_TYPE
				)
				drained_targets.append(creature.get_target_log_display_name(game_manager.get_feedback_viewer()))
				drained_count += 1

	if drained_count <= 0:
		game_manager.note_player_feedback("%s found no sleeping enemies to drain." % card_name)
		return

	add_buff(
		LIFE_DRAIN_SOURCE,
		drained_count * DRAIN_PER_SLEEPING_CREATURE,
		drained_count * DRAIN_PER_SLEEPING_CREATURE,
		0,
		self,
		controller,
		LIFE_DRAIN_EFFECT_TYPE
	)
	game_manager.note_player_feedback(
		"%s drained %s and gained +%d Str and +%d Res." % [
			card_name,
			", ".join(drained_targets),
			drained_count * DRAIN_PER_SLEEPING_CREATURE,
			drained_count * DRAIN_PER_SLEEPING_CREATURE
		]
	)

func _can_drain_creature(game_manager: GameManager, creature: Card) -> bool:
	if creature == null:
		return false
	if creature == self:
		return false
	if creature.card_type != Card.CardType.CREATURE:
		return false
	if creature.current_zone == null or not creature.current_zone.is_board_zone():
		return false
	if not creature.is_sleeping:
		return false
	if game_manager != null and game_manager.is_immune_to_source(creature, self):
		return false
	return true
