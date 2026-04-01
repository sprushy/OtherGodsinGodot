extends CreatureCard
class_name MalinalxochitlAcolyte

const ART_PATH := "res://images/card_art/MalinalxochitalAcolyteEdit2.png"
const POISON_STATUS := "malinalxochitl_poison"
const POISON_SOURCE := "Malinalxochitl Acolyte Poison Glands"
const POISON_EFFECT_TYPE := "malinalxochitl_poison_tick"
const POISON_RES_LOSS := 5

func _init() -> void:
	super._init()
	card_name = "Malinalxochitl Acolyte"
	card_types = ["Divine Acolyte", "Monster", "Insect", "Warrior", "Archer", "Nahuatl Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 1
	resilience = 16
	strength = 27
	flavor_text = ""
	ability_text = "[b]Poison Glands[/b] ([b]Passive[/b]): After combat with a friendly Insect, the other creature loses 5 Res at the start of each of its owner's turns. If this effect brings a creature's Res below 0, the creature dies."
	culture = "Nahuatl"
	artist = ""
	art_path = ART_PATH

func on_friendly_creature_after_combat(game_manager: GameManager, friendly_creature: Card, opposing_card: Card) -> void:
	if game_manager == null or friendly_creature == null or opposing_card == null:
		return
	if abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if friendly_creature.get_controller() != get_controller():
		return
	if friendly_creature.card_type != Card.CardType.CREATURE:
		return
	if not friendly_creature.has_type("Insect"):
		return
	if opposing_card.card_type != Card.CardType.CREATURE:
		return
	if opposing_card.get_controller() == get_controller():
		return
	if opposing_card.current_zone == null or not opposing_card.current_zone.is_board_zone():
		return
	if game_manager.is_immune_to_source(opposing_card, self):
		return

	opposing_card.add_status_effect(
		POISON_STATUS,
		POISON_SOURCE,
		self,
		card_owner
	)
	game_manager.note_player_feedback(
		"%s infects %s after combat with %s." % [
			card_name,
			opposing_card.get_target_log_display_name(game_manager.get_feedback_viewer()),
			friendly_creature.card_name
		]
	)

static func process_persistent_poison_turn_start(game_manager: GameManager, starting_player: Player) -> void:
	if game_manager == null or starting_player == null:
		return
	var poisoned_targets: Array[Card] = []
	for zone in starting_player.frontline_zones + starting_player.reserve_zones:
		for card in zone.cards:
			if _get_poison_stack_count_for_source(card).is_empty():
				continue
			poisoned_targets.append(card)
	for target in poisoned_targets:
		_apply_persistent_poison_tick(game_manager, target)

static func _get_poison_stack_count_for_source(card: Card) -> Dictionary:
	var counts: Dictionary = {}
	if card == null:
		return counts
	for status in card._get_effective_statuses():
		if status.get("name", "") != POISON_STATUS:
			continue
		var source_card := status.get("source_card", null) as Card
		var source_key := _get_poison_source_key(status)
		if source_key == "":
			continue
		if not counts.has(source_key):
			counts[source_key] = {
				"count": 0,
				"source_card": source_card,
				"source_label": _get_poison_source_label(status, source_card),
			}
		var entry: Dictionary = counts[source_key]
		entry["count"] = int(entry.get("count", 0)) + 1
		if entry.get("source_card", null) == null and source_card != null:
			entry["source_card"] = source_card
		counts[source_key] = entry
	return counts

static func _apply_persistent_poison_tick(game_manager: GameManager, target: Card) -> void:
	if game_manager == null or target == null or target.current_zone == null or not target.current_zone.is_board_zone():
		return
	var counts := _get_poison_stack_count_for_source(target)
	if counts.is_empty():
		return
	var target_name := target.get_target_log_display_name(game_manager.get_feedback_viewer())
	for source_key in counts.keys():
		var entry: Dictionary = counts[source_key]
		var stack_count := int(entry.get("count", 0))
		if stack_count <= 0:
			continue
		var poison_source_card := entry.get("source_card", null) as Card
		var source_owner := poison_source_card.card_owner if poison_source_card != null else null
		for _i in range(stack_count):
			target.add_buff(
				POISON_SOURCE,
				0,
				-POISON_RES_LOSS,
				0,
				poison_source_card,
				source_owner,
				POISON_EFFECT_TYPE
			)
		var total_loss := POISON_RES_LOSS * stack_count
		var source_label := str(entry.get("source_label", POISON_SOURCE))
		game_manager.note_player_feedback(
			"%s poisons %s for %d Res at the start of %s's turn." % [
				source_label,
				target_name,
				total_loss,
				_get_player_turn_label(target.get_controller())
			]
		)
	if target.get_effective_resilience() < 0:
		game_manager.note_player_feedback("%s dies from poison." % target_name)
		game_manager.request_send_to_graveyard(target, Callable(), false, true)

static func _get_poison_source_key(status: Dictionary) -> String:
	var source_card := status.get("source_card", null) as Card
	if source_card != null and source_card.uid != "":
		return source_card.uid
	return str(status.get("source", ""))

static func _get_poison_source_label(status: Dictionary, source_card: Card) -> String:
	if source_card != null and source_card.card_name.strip_edges() != "":
		return source_card.card_name
	return str(status.get("source", POISON_SOURCE))

static func _get_player_turn_label(player: Player) -> String:
	if player == null or player.player_name.strip_edges() == "":
		return "that player"
	return player.player_name
