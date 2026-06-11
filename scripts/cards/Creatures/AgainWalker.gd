extends CreatureCard
class_name AgainWalker

const RESURRECTION_COST := 1

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
	# flavor_text = "Death is never the end for those who walk again."
	flavor_text = ""
	ability_text = "[b]Again[/b] (end of turn): If [b]Slain[/b] this turn, you may pay %d mana to resurrect this card to your reserve line face-up in aggressive stance." % RESURRECTION_COST
	culture = "Norse"
	art_path = "res://images/card_art/creatures/Again-Walker(web) - Copy.jpg"

func on_death(game_manager: GameManager) -> void:
	game_manager.pending_resurrections.append(self)
