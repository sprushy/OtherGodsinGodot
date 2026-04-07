extends CreatureCard
class_name HariiShaman

const MAX_TRANSFORMS_PER_TURN := 2
const ANIMAL_TYPE := "Animal"
const NORSE_TYPE := "Norse Creature"
const HUMAN_TYPE := "Human"
const WARRIOR_TYPE := "Warrior"
const TARGETING_TYPE := "Targeting"
const ANIMAL_SUBTYPE_OPTIONS: Array[String] = [
	"Ursine",
	"Lupine",
	"Canine",
	"Porcine",
	"Hircine",
	"Taurine",
	"Avian",
]
const ANIMAL_RELATED_TYPES: Array[String] = [
	"Animal",
	"Ursine",
	"Lupine",
	"Canine",
	"Porcine",
	"Hircine",
	"Taurine",
	"Avian",
]
const ANIMAL_SUBTYPE_EXTRA_TYPES := {
	"Avian": ["Aerial"],
}

var _transforms_used_this_turn: int = 0

func _init() -> void:
	super._init()
	card_name = "Harii Shaman"
	card_types = ["Human", "Mage", "Shaman", "Battlemage", "Norse Creature"]
	if TARGETING_TYPE not in card_types:
		card_types.append(TARGETING_TYPE)
	level = 4
	mana_cost = 2
	speed = 1
	resilience = 25
	strength = 24
	sacrifice_cost = 0
	targets = true
	ability_text = "[b]Transform[/b] ([b]Activate[/b]): Twice per turn, choose a friendly Norse Warrior and change it to an Animal subtype, or choose a friendly Animal and change it to a Norse Human Warrior."
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/HariiShamanEdit.png"

func get_activation_label() -> String:
	return "Transform"

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
	if _transforms_used_this_turn >= MAX_TRANSFORMS_PER_TURN:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if _can_transform_target(card):
				valid_targets.append(card)
	return valid_targets

func get_animal_subtype_options(_target: Card = null) -> Array[String]:
	return ANIMAL_SUBTYPE_OPTIONS.duplicate()

func activate(game_manager: GameManager, target_data = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s cannot transform anything right now." % card_name)
		return

	var target := _resolve_target_from_activation_data(game_manager, target_data)
	var chosen_subtype := _resolve_subtype_from_activation_data(target_data)
	var result := resolve_transform(game_manager, target, chosen_subtype)
	if game_manager != null and result != "":
		game_manager.note_player_feedback(result)

func resolve_transform(game_manager: GameManager, target: Card, chosen_subtype: String = "") -> String:
	if not can_activate(game_manager):
		return card_name + " cannot transform anything right now."
	if target == null or target not in get_valid_targets(game_manager):
		return card_name + " fizzles: choose a friendly Norse Warrior or friendly Animal."
	if game_manager != null and game_manager.is_guardian_protected(target, self):
		return target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is protected by Guardian!"
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		return target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + "."

	if _can_restore_target(target):
		_restore_to_norse_human_warrior(target)
		_transforms_used_this_turn += 1
		if game_manager != null:
			game_manager.notify_creature_shapeshifted(target, self)
		return "%s transformed %s into a Norse Human Warrior." % [
			card_name,
			target.get_target_log_display_name(game_manager.get_feedback_viewer()) if game_manager != null else target.card_name,
		]

	if not _can_transform_target_to_animal(target):
		return card_name + " fizzles: invalid target."
	if chosen_subtype == "" or chosen_subtype not in ANIMAL_SUBTYPE_OPTIONS:
		return card_name + " needs an Animal subtype."

	_transform_to_animal(target, chosen_subtype)
	_transforms_used_this_turn += 1
	if game_manager != null:
		game_manager.notify_creature_shapeshifted(target, self)
	return "%s transformed %s into %s." % [
		card_name,
		target.get_target_log_display_name(game_manager.get_feedback_viewer()) if game_manager != null else target.card_name,
		chosen_subtype,
	]

func on_turn_start(_game_manager: GameManager) -> void:
	_transforms_used_this_turn = 0

func on_turn_end(_game_manager: GameManager) -> void:
	_transforms_used_this_turn = 0

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	var remaining := maxi(0, MAX_TRANSFORMS_PER_TURN - _transforms_used_this_turn)
	lines.append("Transform activations left this turn: %d" % remaining)
	return lines

func _resolve_target_from_activation_data(game_manager: GameManager, target_data) -> Card:
	if target_data is Card:
		return target_data as Card
	if target_data is Dictionary:
		var data := target_data as Dictionary
		if data.get("target", null) is Card:
			return data.get("target", null) as Card
		var target_uid := str(data.get("target_uid", ""))
		if target_uid != "" and game_manager != null:
			return game_manager.get_card_by_uid(target_uid)
	return null

func _resolve_subtype_from_activation_data(target_data) -> String:
	if target_data is Dictionary:
		return str((target_data as Dictionary).get("animal_subtype", "")).strip_edges()
	return ""

func _can_transform_target(target: Card) -> bool:
	return _can_transform_target_to_animal(target) or _can_restore_target(target)

func _can_transform_target_to_animal(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() == get_controller() \
		and target.has_type(WARRIOR_TYPE) \
		and target.has_type(NORSE_TYPE) \
		and not target.has_type(ANIMAL_TYPE)

func _can_restore_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() == get_controller() \
		and target.has_type(ANIMAL_TYPE)

func _transform_to_animal(target: Card, chosen_subtype: String) -> void:
	var next_types := _filter_transform_types(target.card_types)
	next_types.erase(HUMAN_TYPE)
	next_types.erase(WARRIOR_TYPE)
	_ensure_type(next_types, ANIMAL_TYPE)
	_ensure_type(next_types, chosen_subtype)
	for extra_type in ANIMAL_SUBTYPE_EXTRA_TYPES.get(chosen_subtype, []):
		_ensure_type(next_types, str(extra_type))
	target.card_types = next_types

func _restore_to_norse_human_warrior(target: Card) -> void:
	var next_types := _filter_transform_types(target.card_types)
	_ensure_type(next_types, HUMAN_TYPE)
	_ensure_type(next_types, WARRIOR_TYPE)
	_ensure_type(next_types, NORSE_TYPE)
	target.card_types = next_types

func _filter_transform_types(existing_types: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	for type_name in existing_types:
		if type_name == TARGETING_TYPE:
			filtered.append(type_name)
			continue
		if type_name in ANIMAL_RELATED_TYPES:
			continue
		if type_name == HUMAN_TYPE or type_name == WARRIOR_TYPE:
			continue
		filtered.append(type_name)
	return filtered

func _ensure_type(types: Array[String], type_name: String) -> void:
	if type_name == "":
		return
	if type_name not in types:
		types.append(type_name)
