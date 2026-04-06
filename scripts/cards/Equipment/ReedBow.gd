extends EquipmentCard
class_name ReedBow

const ART_PATH := "res://images/card_art/equipment/ReedBowEdit.png"

func _init() -> void:
	super._init()
	card_name = "Reed Bow"
	culture = "Ancient"
	card_types = ["Weapon", "Bow"]
	mana_cost = 0
	strength_modifier = 4
	ability_text = "The equipped creature gains 4 Str and adds Archer to its class."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func grants_type_to_equipped_creature(_creature: Card, type_name: String) -> bool:
	return type_name == "Archer" and _is_actively_equipped() and not abilities_suppressed()

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	if _is_actively_equipped() and not abilities_suppressed():
		lines.append("Equipped creature is an Archer")
	return lines

func _is_actively_equipped() -> bool:
	return equipped_on != null \
		and current_zone != null \
		and equipped_on.current_zone == current_zone
