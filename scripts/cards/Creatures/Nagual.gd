extends CreatureCard
class_name Nagual

const FELINE_STR_BONUS := 4
const FELINE_SPD_BONUS := 1
const HUMAN_RES_BONUS := 5
const ART_PATH := "res://images/card_art/creatures/NagualEdit.png"

var in_feline_form: bool = false

func _init() -> void:
	super._init()
	card_name = "Nagual"
	card_types = _get_human_form_types()
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 17
	strength = 17
	ability_text = "[b]Shapeshift[/b] ([b]Activate[/b]): Switch this card between Human, Mage, Shaman, Shapeshifter and Animal, Feline, Mage, Shaman, Shapeshifter.\n[b]Tonal Strengths[/b] ([b]Passive[/b]): Gain +4 STR and +1 SPD while in Feline form. Gain +5 RES while in Human form."
	flavor_text = ""
	culture = "Nahuatl"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "Shapeshift"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed():
		return false
	if is_sleeping:
		return false
	return can_take_major_creature_action()

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	shift_forms()
	spend_major_creature_action()
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s shifts into %s form." % [card_name, "Feline" if in_feline_form else "Human"]
		)

func shift_forms() -> void:
	in_feline_form = not in_feline_form
	card_types = _get_feline_form_types() if in_feline_form else _get_human_form_types()

func get_effective_speed() -> int:
	var total := super.get_effective_speed()
	if in_feline_form:
		total += FELINE_SPD_BONUS
	return clampi(total, 1, 7)

func get_effective_strength() -> int:
	var total := super.get_effective_strength()
	if in_feline_form:
		total += FELINE_STR_BONUS
	return max(0, total)

func get_effective_resilience() -> int:
	var total := super.get_effective_resilience()
	if not in_feline_form:
		total += HUMAN_RES_BONUS
	return max(0, total)

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	return [
		"[b]Current Form[/b]: %s" % ("Feline" if in_feline_form else "Human"),
		"[b]Feline[/b]: Animal, Feline, Mage, Shaman, Shapeshifter; +4 STR and +1 SPD.",
		"[b]Human[/b]: Human, Mage, Shaman, Shapeshifter; +5 RES.",
	]

func _get_human_form_types() -> Array[String]:
	return [
		"Human",
		"Mage",
		"Shaman",
		"Shapeshifter",
		"Nahuatl Creature",
	]

func _get_feline_form_types() -> Array[String]:
	return [
		"Animal",
		"Feline",
		"Mage",
		"Shaman",
		"Shapeshifter",
		"Nahuatl Creature",
	]
