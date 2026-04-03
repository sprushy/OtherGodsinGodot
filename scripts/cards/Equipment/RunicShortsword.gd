extends EquipmentCard
class_name RunicShortsword

const ART_PATH := "res://images/card_art/equipment/NorseShortswordEdit.png"

func _init() -> void:
	super._init()
	card_name = "Runic Shortsword"
	culture = "Norse"
	card_types = ["Weapon", "Sword", "Runic"]
	level = 1
	mana_cost = 0
	strength_modifier = 8
	ability_text = "Gain 8 Str. When this card is unequipped on the field, Norse Humans have +1 Reach when intercepting for it and may steal and attack in the same action."
	flavor_text = ""
	artist = "Lorinda Tomko"
	art_path = ART_PATH
