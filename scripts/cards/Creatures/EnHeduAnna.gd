extends CreatureCard
class_name EnHeduAnna

const EXALTATION_SOURCE := "En-hedu-anna Exaltation"
const EXALTATION_GUARD_STATUS := "en_hedu_anna_exaltation_guard"

var _god_power_activated_while_face_up_this_turn: bool = false

func _init() -> void:
	super._init()
	card_name = "En-hedu-anna"
	card_types = ["Human", "Mage", "Priest", "Ancient Creature"]
	level = 2
	mana_cost = 2
	speed = 1
	resilience = 12
	strength = 12
	sacrifice_cost = 0
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/EnHeduAnnaAIEdit.png"
	ability_text = "Exaltation ([b]Activate[/b]): If your God's power activated this turn while En-hedu-anna was face-up, gain +7 RES, +7 STR, or +1 SPD. Until the end of the next turn, En-hedu-anna can't attack, be destroyed, or be targeted."

func on_friendly_god_power_activated(game_manager: GameManager, _god: Card, _target: Card = null) -> void:
	if not _was_face_up_on_field_when_god_power_activated(game_manager):
		return
	_god_power_activated_while_face_up_this_turn = true

func on_turn_end(_game_manager: GameManager) -> void:
	_god_power_activated_while_face_up_this_turn = false

func on_removed(_game_manager: GameManager) -> void:
	_god_power_activated_while_face_up_this_turn = false
	clear_buffs_from(EXALTATION_SOURCE)
	remove_status_effects_by_name(EXALTATION_GUARD_STATUS)
	remove_status_effects_by_name("cannot_attack")

func get_activation_label() -> String:
	return "Exaltation"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if is_sleeping:
		return false
	if creature_major_action_used:
		return false
	return _god_power_activated_while_face_up_this_turn

func get_exaltation_options() -> Array[Dictionary]:
	return [
		{"label": "+7 RES", "str": 0, "res": 7, "spd": 0},
		{"label": "+7 STR", "str": 7, "res": 0, "spd": 0},
		{"label": "+1 SPD", "str": 0, "res": 0, "spd": 1},
	]

func get_exaltation_option_label(option: Dictionary) -> String:
	return str(option.get("label", "Exaltation"))

func is_valid_exaltation_option(option: Dictionary) -> bool:
	return not _get_matching_exaltation_option(option).is_empty()

func activate(game_manager: GameManager, option = null) -> void:
	if option is Dictionary:
		var feedback := resolve_exaltation_choice(game_manager, option)
		if game_manager != null and feedback.strip_edges() != "":
			game_manager.note_player_feedback(feedback)
	elif game_manager != null:
		game_manager.note_player_feedback(card_name + " fizzles: choose an Exaltation bonus.")

func resolve_exaltation_choice(game_manager: GameManager, option: Dictionary) -> String:
	if not can_activate(game_manager):
		return card_name + " can no longer use Exaltation."
	var matched_option := _get_matching_exaltation_option(option)
	if matched_option.is_empty():
		return card_name + " fizzles: choose a valid Exaltation bonus."

	_god_power_activated_while_face_up_this_turn = false
	var expires_turn := game_manager.turn_number + 1

	clear_buffs_from(EXALTATION_SOURCE)
	remove_status_effects_by_name(EXALTATION_GUARD_STATUS)
	remove_status_effects_by_name("cannot_attack")

	add_buff(
		EXALTATION_SOURCE,
		int(matched_option.get("str", 0)),
		int(matched_option.get("res", 0)),
		int(matched_option.get("spd", 0)),
		self,
		card_owner,
		"exaltation"
	)
	add_status_effect(
		EXALTATION_GUARD_STATUS,
		EXALTATION_SOURCE,
		self,
		card_owner,
		{"expires_turn": expires_turn}
	)
	add_status_effect(
		"cannot_attack",
		EXALTATION_SOURCE,
		self,
		card_owner,
		{"expires_turn": expires_turn}
	)
	spend_major_creature_action()

	return "%s gains %s and cannot attack, be destroyed, or be targeted until the end of the next turn." % [
		card_name,
		get_exaltation_option_label(matched_option)
	]

func _get_matching_exaltation_option(option: Dictionary) -> Dictionary:
	for valid_option in get_exaltation_options():
		if int(option.get("str", 0)) != int(valid_option.get("str", 0)):
			continue
		if int(option.get("res", 0)) != int(valid_option.get("res", 0)):
			continue
		if int(option.get("spd", 0)) != int(valid_option.get("spd", 0)):
			continue
		return valid_option
	return {}

func _was_face_up_on_field_when_god_power_activated(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if get_controller() != card_owner:
		return false
	return not is_face_down and not is_stealth and not is_prepared
