extends CreatureCard
class_name Asakku

func _init() -> void:
	super._init()
	card_name = "Asakku"
	card_types = ["Demon", "Ancient Creature"]
	level = 2
	mana_cost = 1
	sacrifice_cost = 0
	speed = 1
	resilience = 13
	strength = 15
	ability_text = "Offering (passive): When you destroy an enemy creature in combat, gain 2 mana."
	flavor_text = ""
	culture = "Ancient"
	art_path = "res://images/card_art/creatures/asakku.jpg"

func on_ally_kill(game_manager: GameManager, killer: Card, victim: Card) -> void:
	if victim.card_type == Card.CardType.CREATURE:
		card_owner.gain_mana(2)
		print("Offering! " + killer.card_name + " destroyed " + victim.card_name + " â€” " + card_owner.player_name + " gains 2 mana.")
