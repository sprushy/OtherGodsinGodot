extends SpellCard
class_name Absence

const MUTE_DURATION := 3
const ART_PATH := "res://images/card_art/absence_center_art_crop.png"

func _init() -> void:
	super._init()
	card_name = "Absence"
	culture = "Neutral"
	card_types = ["Silence", "God"]
	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = false
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	targets = true
	flavor_text = "Silence the divine, if only for a while."
	art_path = ART_PATH
	ability_text = "Relock a power or [b]Mute[/b] one for 3 of its owner's turns."

func resolve(_game_manager: GameManager, target = null) -> void:
	if not _is_valid_power_target(target):
		print("Absence can only target a power card.")
		return

	var power := target as PowerCard
	apply_to_power(power, "relock" if not power.is_face_down else "mute")

func _is_valid_power_target(card: Card) -> bool:
	return card is PowerCard

func apply_to_power(power: PowerCard, mode: String) -> void:
	if power == null:
		return
	if mode == "relock":
		power.relock()
		print("Absence relocked " + power.card_name + ".")
	else:
		power.mute_for_turns(MUTE_DURATION)
		print("Absence muted " + power.card_name + " for " + str(MUTE_DURATION) + " of its owner's turns.")
