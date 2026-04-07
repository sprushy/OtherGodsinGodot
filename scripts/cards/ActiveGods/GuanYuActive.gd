extends ActiveGodCard
class_name GuanYuActive

const LINKED_GOD_NAME := "Guan Yu"
const ART_PATH := "res://images/card_art/gods/guan_yu.png"
const IMPACT_TACTIC_COUNTERS := 7

var tactic_counters: int = 0

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Guan Yu, Active God"
	card_types = ["Active God", "Divine Manifestation", "God", "Warrior", "Hero", "Targeting"]
	level = 11
	mana_cost = 11
	speed = 2
	resilience = 27
	strength = 27
	culture = "Tian"
	targets = true
	flavor_text = "The general enters the field already armed with practiced discipline and battlefield momentum."
	ability_text = "[b]Knowledge of the General[/b] ([b]Impact[/b]): Put 7 tactic counters on this card. When a friendly warrior destroys a creature, add a tactic counter to this card.\n[b]Manoeuvre[/b] ([b]Activate[/b]): Move a tactic counter from this card to another tactic-counter card you control."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func get_activation_label() -> String:
	return "Manoeuvre"

func on_impact(game_manager: GameManager) -> void:
	tactic_counters += IMPACT_TACTIC_COUNTERS
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s enters with %d tactic counters." % [card_name, tactic_counters]
		)

func on_ally_kill(game_manager: GameManager, killer: Card, victim: Card) -> void:
	if not _passives_are_active():
		return
	if killer == null or victim == null:
		return
	if killer.get_controller() != get_controller():
		return
	if not killer.has_type("Warrior"):
		return
	tactic_counters += 1
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s gains a tactic counter from %s destroying %s (now %d)." % [
				card_name,
				killer.card_name,
				victim.card_name,
				tactic_counters
			]
		)

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_sleeping:
		return false
	if tactic_counters <= 0:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot manoeuvre right now."
	if get_controller() != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field."
	if is_face_down or is_stealth or is_prepared:
		return card_name + " must be face-up to manoeuvre."
	if abilities_suppressed():
		return card_name + " is suppressed."
	if is_activation_locked(game_manager):
		return card_name + " cannot be activated this turn."
	if is_sleeping:
		return card_name + " is asleep."
	if tactic_counters <= 0:
		return card_name + " has no tactic counters to move."
	if get_valid_targets(game_manager).is_empty():
		return "Manoeuvre has no valid target."
	return ""

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets
	for candidate in [controller.god_zone] + controller.power_zones + controller.frontline_zones + controller.reserve_zones:
		for card in candidate.cards:
			if _is_valid_manoeuvre_target(card):
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if target == null or target not in get_valid_targets(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("Manoeuvre fizzles: invalid target.")
		return
	tactic_counters -= 1
	target.tactic_counters += 1
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s moves 1 tactic counter to %s. (%d remaining)" % [
				card_name,
				target.card_name,
				tactic_counters
			]
		)

func on_removed(_game_manager: GameManager) -> void:
	tactic_counters = 0

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("Tactic counters: %d" % tactic_counters)
	return lines

func _passives_are_active() -> bool:
	return current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth \
		and not abilities_suppressed()

func _is_valid_manoeuvre_target(target: Card) -> bool:
	if target == null or target == self:
		return false
	if target.card_owner != card_owner:
		return false
	if not (target is GuanYu or target is GuanYuActive):
		return false
	if target.current_zone == null:
		return false
	if target.current_zone == card_owner.god_zone:
		return true
	if target.current_zone in card_owner.power_zones:
		return true
	return target.current_zone.is_board_zone()
