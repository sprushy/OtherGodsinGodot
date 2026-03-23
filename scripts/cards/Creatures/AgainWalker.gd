extends CreatureCard
class_name AgainWalker

func _init() -> void:
	super._init()
	card_name = "Again-Walker"
	card_types = ["Undead", "Draug", "Warrior", "Norse Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 10
	strength = 15
	flavor_text = "Death is never the end for those who walk again."
	ability_text = "Return: When destroyed, at end of turn you may pay 1 mana to resurrect this card in your back line in face-up attack mode."
	culture = "Norse"
	art_path = "res://images/card_art/Again-Walker(web).jpg"

func on_death(game_manager: GameManager) -> void:
	game_manager.pending_resurrections.append(self)
