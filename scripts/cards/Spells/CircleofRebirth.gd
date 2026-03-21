# cards/spells/CircleOfRebirth.gd
extends SpellCard
class_name CircleOfRebirth

func _init() -> void:
	super._init()
	card_name = "Circle of Rebirth"
	
	var types: Array[String] = ["Resurrection", "Nature", "Life"]
	card_types = types
	
	level = 4
	mana_cost = 2
	is_legendary = true
	speed = 1
	flavor_text = "Resurrect all animals and plants which were destroyed this turn."
	culture = "Triskelion"

func resolve(game_manager: GameManager, target = null) -> void:
	print("Circle of Rebirth activates - calling back fallen creatures!")
	print("(UI will handle placement and mode selection)")
	# The actual resurrection logic is now handled by the UI
	# This spell just triggers the resurrection flow
