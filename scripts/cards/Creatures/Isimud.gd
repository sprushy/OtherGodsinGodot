extends CreatureCard
class_name Isimud

const DIVINE_MANIFESTATION_DISCOUNT := 6
const REVELATION_SUMMON_TAX := 2

func _init() -> void:
	super._init()
	card_name = "Isimud"
	card_types = ["Divine Manifestation", "Priest", "Aerial", "Ancient Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 8
	strength = 5
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/Isimud(web).jpg"
	ability_text = "[b]Forerunner[/b] ([b]Passive[/b]): Reduce the summon cost of your Divine Manifestations by 6 mana.\n[b]Revelation[/b] ([b]Activate[/b]): Spend this card's major action to summon a Divine Manifestation from your hand. That summon costs 2 additional mana."

func get_cost_adjustment_entries(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	_game_manager: GameManager,
	_metadata: Dictionary = {}
) -> Array[Dictionary]:
	if not _can_reduce_divine_manifestation(target_card, base_cost, cost_kind):
		return []
	return [{
		"source": card_name,
		"source_card": self,
		"delta": -DIVINE_MANIFESTATION_DISCOUNT,
	}]

func get_activation_label() -> String:
	return "Revelation"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if is_sleeping:
		return false
	if not can_take_major_creature_action():
		return false
	if _get_open_summon_zone() == null:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.hand_zone == null or game_manager == null:
		return valid_targets
	if _get_open_summon_zone() == null:
		return valid_targets

	for card in controller.hand_zone.cards:
		if not _is_valid_revelation_target(card):
			continue
		var taxed_cost := _get_taxed_revelation_cost(game_manager, controller, card)
		if not card.can_pay_costs_with_mana_cost(controller, taxed_cost):
			continue
		valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(card_name + " cannot use Revelation right now.")
		return
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		if game_manager != null:
			game_manager.note_player_feedback("Revelation fizzles: choose a Divine Manifestation in your hand.")
		return
	var target_zone := _get_open_summon_zone()
	if target_zone == null:
		if game_manager != null:
			game_manager.note_player_feedback(card_name + " has no open zone for Revelation.")
		return

	game_manager.add_temporary_summon_cost_modifier(get_controller(), REVELATION_SUMMON_TAX, self)
	var summoned := game_manager.summon_creature_by_effect(
		get_controller(),
		target,
		target_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		true,
		false,
		true
	)
	if not summoned:
		if game_manager != null:
			game_manager.note_player_feedback(card_name + " could not summon " + target.card_name + " with Revelation.")
		return

	spend_major_creature_action()
	if game_manager != null:
		game_manager.note_player_feedback("%s summons %s with Revelation." % [card_name, target.card_name])

func _can_reduce_divine_manifestation(target_card: Card, base_cost: int, cost_kind: String) -> bool:
	if target_card == null or base_cost <= 0:
		return false
	if cost_kind != Card.COST_KIND_CREATURE_SUMMON:
		return false
	if target_card.card_owner != card_owner:
		return false
	if target_card.card_type != Card.CardType.CREATURE:
		return false
	return target_card.has_type("Divine Manifestation")

func _is_valid_revelation_target(card: Card) -> bool:
	var controller := get_controller()
	return card != null \
		and controller != null \
		and card.current_zone == controller.hand_zone \
		and card.card_type == Card.CardType.CREATURE \
		and card.has_type("Divine Manifestation")

func _get_taxed_revelation_cost(game_manager: GameManager, controller: Player, target: Card) -> int:
	if game_manager == null or controller == null or target == null:
		return REVELATION_SUMMON_TAX
	return game_manager.get_creature_summon_mana_cost(controller, target, self, false) + REVELATION_SUMMON_TAX

func _get_open_summon_zone() -> Zone:
	var controller := get_controller()
	if controller == null:
		return null
	for zone in controller.frontline_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	for zone in controller.reserve_zones:
		if zone != null and zone.cards.is_empty():
			return zone
	return null
