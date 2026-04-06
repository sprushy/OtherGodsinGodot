extends EquipmentCard
class_name SevenLeagueBoots

const ART_PATH := "res://images/card_art/equipment/seven_league_boots.png"
const SPEED_OVERRIDE := 7

func _init() -> void:
	super._init()
	card_name = "Seven-League Boots"
	culture = "Neutral"
	card_types = ["Armour", "Boots"]
	level = 3
	mana_cost = 2
	ability_text = "The equipped creature's speed becomes 7."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func get_speed_override_for_equipped_creature(_creature: Card) -> Variant:
	if not _is_actively_equipped() or abilities_suppressed():
		return null
	return SPEED_OVERRIDE

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	if _is_actively_equipped() and not abilities_suppressed():
		lines.append("Equipped creature's speed becomes %d" % SPEED_OVERRIDE)
	return lines

func _is_actively_equipped() -> bool:
	return equipped_on != null \
		and current_zone != null \
		and equipped_on.current_zone == current_zone
