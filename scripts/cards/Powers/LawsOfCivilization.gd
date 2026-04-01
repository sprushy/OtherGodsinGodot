extends PowerCard
class_name LawsOfCivilization

const ART_PATH := "res://images/card_art/LawsArtEdit.jpg"

func _init() -> void:
	super._init()
	card_name = "Laws of Civilization"
	culture = "Ancient"
	level = 1
	mana_cost = 5
	card_types = ["Mechanic", "Stun"]
	ability_text = "[b]Passive[/b]: No one may add cards to their hand or gain mana except during their upkeep."
	artist = "Lorinda Tomko"
	art_path = ART_PATH
