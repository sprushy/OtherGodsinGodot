extends CreatureCard
class_name WolfAdolescent

const ART_PATH := "res://images/card_art/creatures/WolfAdolescent.jpg"
const MATURATION_READY_STATUS := "wolf_adolescent_maturation_ready"

var _maturation_ready: bool = false

func _init() -> void:
	super._init()
	card_name = "Wolf Adolescent"
	card_types = ["Animal", "Lupine", "Norse Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 7
	strength = 20
	ability_text = "[b]Maturation[/b] ([b]Upkeep[/b]): If this creature destroyed another creature in combat since your last turn began, you may send it to the graveyard to summon a level 5 or lower Lupine from your deck to the field."
	flavor_text = ""
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_kill(_game_manager: GameManager, victim: Card) -> void:
	if victim == null or victim == self:
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if abilities_suppressed() or is_face_down or is_stealth:
		return
	_set_maturation_ready(true)

func on_turn_start(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	_sync_maturation_ready_state()
	if not can_offer_maturation(game_manager):
		if _maturation_ready and (abilities_suppressed() or is_face_down or is_stealth \
				or current_zone == null or not current_zone.is_board_zone()):
			_set_maturation_ready(false)
		return

	var valid_targets := get_valid_maturation_targets()
	if valid_targets.is_empty():
		_set_maturation_ready(false)
		game_manager.note_player_feedback("%s matured, but found no level 5 or lower Lupine in the deck." % card_name)
		return

	var controller := get_controller()
	if controller != null:
		var target_uids: Array[String] = []
		for target in valid_targets:
			if target != null:
				target_uids.append(target.uid)
		game_manager.decision_requested.emit(controller, "wolf_adolescent_maturation", {
			"source_uid": uid,
			"target_uids": target_uids,
		})
		return

	# Fallback when no UI host is available — handle inline.
	_set_maturation_ready(false)
	game_manager.note_player_feedback("%s is ready to mature, but no selection UI was available." % card_name)

func can_offer_maturation(game_manager: GameManager) -> bool:
	_sync_maturation_ready_state()
	if game_manager == null or not _maturation_ready:
		return false
	var controller := get_controller()
	if controller == null or controller != game_manager.current_player:
		return false
	if abilities_suppressed() or is_face_down or is_stealth:
		return false
	return current_zone != null and current_zone.is_board_zone()

func resolve_maturation_choice(game_manager: GameManager, target: Card) -> String:
	if game_manager == null or not can_offer_maturation(game_manager):
		_set_maturation_ready(false)
		return card_name + " cannot mature right now."

	if target == null:
		_set_maturation_ready(false)
		return card_name + " stays a Wolf Adolescent."

	var controller := get_controller()
	if controller == null:
		_set_maturation_ready(false)
		return card_name + " has no controller for Maturation."

	var target_zone := current_zone
	var result := ""
	_set_maturation_ready(false)
	game_manager.request_send_to_graveyard(self, func() -> void:
		if target_zone == null or not target_zone.cards.is_empty():
			result = "%s matured, but there was no open lane for %s." % [
				card_name,
				target.card_name
			]
			return
		var summoned := game_manager.summon_creature_without_cost(
			controller,
			target,
			target_zone,
			Card.CreatureMode.AGGRESSIVE
		)
		if summoned:
			result = "%s matures into %s from the deck." % [
				card_name,
				target.card_name
			]
		else:
			result = "%s matured, but %s could not be summoned." % [
				card_name,
				target.card_name
			]
	, false, false)
	return result if result.strip_edges() != "" else "%s could not mature." % card_name

func get_valid_maturation_targets() -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_maturation_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func on_removed(_game_manager: GameManager) -> void:
	_set_maturation_ready(false)

func _is_valid_maturation_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Lupine") \
		and card.get_effective_level() <= 5

func _set_maturation_ready(value: bool) -> void:
	_maturation_ready = value
	remove_status_effects_by_name(MATURATION_READY_STATUS)
	if value:
		add_status_effect(MATURATION_READY_STATUS, "Maturation", self, get_controller())

func _sync_maturation_ready_state() -> void:
	_maturation_ready = _maturation_ready or has_status_effect(MATURATION_READY_STATUS)
