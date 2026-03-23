# cards/spells/Absence.gd
extends SpellCard
class_name Absence

const MUTE_DURATION := 3

func _init() -> void:
	super._init()
	card_name = "Absence"
	culture = "Neutral"

	var types: Array[String] = ["Silence", "God"]
	card_types = types

	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = false

	sacrifice_cost = 0
	creature_sacrifice_cost = 0

	flavor_text = "Silence the divine, if only for a while."
	art_path = "res://images/card_art/absence.jpg"
	ability_text = "Flip down a power or mute one for 3 of its owner's turns."


func resolve(game_manager: GameManager, target = null) -> void:
	print("Absence - Silence falls over power.")

	if target == null:
		print("No target selected for Absence.")
		return

	if not _is_valid_power_target(target):
		print("Absence can only target a power card.")
		return

	# If the power is face up, flip it down.
	if _is_face_up(target):
		_flip_down_power(target)
		print("Absence flipped down " + target.card_name + ".")
		return

	# Otherwise mute it for 3 of its owner's turns.
	_mute_power(target, MUTE_DURATION)
	print("Absence muted " + target.card_name + " for " + str(MUTE_DURATION) + " of its owner's turns.")


func _is_valid_power_target(card: Card) -> bool:
	if card == null:
		return false

	if "Power" in card.card_types:
		return true

	if card.has_method("is_power_card"):
		return card.is_power_card()

	return false


func _is_face_up(card: Card) -> bool:
	if card == null:
		return false

	if card.has_method("is_face_up"):
		return card.is_face_up()

	if "is_face_down" in card:
		return not card.is_face_down

	if "face_down" in card:
		return not card.face_down

	return true


func _flip_down_power(card: Card) -> void:
	if card == null:
		return

	if card.has_method("flip_down"):
		card.flip_down()
		return

	if "is_face_down" in card:
		card.is_face_down = true
	elif "face_down" in card:
		card.face_down = true


func _mute_power(card: Card, duration: int) -> void:
	if card == null:
		return

	if card.has_method("mute_for_turns"):
		card.mute_for_turns(duration)
		return

	if "is_muted" in card:
		card.is_muted = true

	if "mute_turns_remaining" in card:
		card.mute_turns_remaining = duration

	if card.has_method("set_owner_turn_mute"):
		card.set_owner_turn_mute(duration)
