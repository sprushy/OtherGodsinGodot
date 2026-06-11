extends CreatureCard
class_name Afanc

const ART_PATH := "res://images/card_art/creatures/afanc.png"

func _init() -> void:
	super._init()
	card_name = "Afanc"
	card_types = ["Animal", "Monster", "Cryptid", "Aqueous", "Triskelion Creature"]
	level = 5
	mana_cost = 0
	sacrifice_cost = 1
	speed = 2
	resilience = 40
	strength = 20
	flavor_text = ""
	ability_text = "Toxic Emergence ([b]Reveal[/b]): Poison all opposing creatures."
	culture = "Triskelion"
	artist = "User provided art"
	art_path = ART_PATH

func on_reveal(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	var controller := get_controller()
	if controller == null:
		return
	game_manager.decision_requested.emit(controller, "reveal_effect", {
		"source_uid": uid,
		"queue_with_priority": true,
		"event_name": "afanc_reveal",
		"resolve_method": "resolve_toxic_emergence",
	})

func resolve_toxic_emergence(game_manager: GameManager) -> String:
	if game_manager == null or abilities_suppressed():
		return ""
	if current_zone == null or not current_zone.is_board_zone():
		return ""

	var controller := get_controller()
	if controller == null:
		return ""
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return ""

	var poisoned_targets: Array[String] = []
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if not _can_poison_target(card, game_manager):
				continue
			card.add_status_effect(
				MalinalxochitlAcolyte.POISON_STATUS,
				MalinalxochitlAcolyte.POISON_SOURCE,
				self,
				card_owner
			)
			poisoned_targets.append(card.get_target_log_display_name(game_manager.get_feedback_viewer()))

	if poisoned_targets.is_empty():
		return "%s reveals, but finds no opposing creatures to poison." % card_name

	return "%s reveals and poisons %s." % [card_name, ", ".join(poisoned_targets)]

func _can_poison_target(card: Card, game_manager: GameManager) -> bool:
	return card != null \
		and game_manager != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and not game_manager.is_immune_to_source(card, self)
