extends SpellCard
class_name Absence

const MUTE_DURATION := 3
const ART_PATH := "res://images/card_art/spells/absence_center_art_crop.png"

func _init() -> void:
	super._init()
	card_name = "Absence"
	culture = "Neutral"
	card_types = ["Silence", "God"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	targets = true
	# flavor_text = "Silence the divine, if only for a while."
	flavor_text = ""
	art_path = ART_PATH
	ability_text = "[b]Relock[/b] a power, or [b]Mute[/b] a power for 3 of its owner's turns. Face-down powers are revealed first."

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	var target_uid: String = command.get("target_uid", "")
	var target: Card = null
	if target_uid != "":
		target = game_manager.get_card_by_uid(target_uid)
	var mode: String = command.get("mode", "mute")
	if not _is_valid_power_target(target):
		if game_manager != null:
			game_manager.note_player_feedback("Absence fizzles: choose a power or god ability.")
		return
	if mode == "relock" and not (target is PowerCard):
		mode = "mute"
	apply_to_power(target, mode, game_manager)

func resolve(game_manager: GameManager, target = null) -> void:
	if not _is_valid_power_target(target):
		print("Absence can only target a power or god ability.")
		return

	apply_to_power(target, "relock" if target is PowerCard and not target.is_face_down else "mute", game_manager)

func _is_valid_power_target(card: Card) -> bool:
	return card is PowerCard or (card != null and card.is_god)

func apply_to_power(power: Card, mode: String, game_manager: GameManager = null) -> void:
	if power == null:
		return
	if mode == "relock" and power is PowerCard:
		power.relock()
		print("Absence relocked a power.")
	else:
		if power is PowerCard and power.is_face_down:
			power.reveal_while_face_down()
			if game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
				game_manager.notify_card_revealed_by_effect(power, self)
		power.mute_for_turns(MUTE_DURATION, game_manager)
		print("Absence muted a power for " + str(MUTE_DURATION) + " of its owner's turns.")
