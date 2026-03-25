extends CreatureCard
class_name Aurboda

func _init() -> void:
	super._init()
	card_name = "AurboÃ°a"
	card_types = ["Giant", "Warrior", "Norse Creature"]
	level = 3
	mana_cost = 1
	sacrifice_cost = 0
	speed = 1
	resilience = 3
	strength = 21
	ability_text = "Pierce: Every time this card destroys a creature in battle, [b]Convert[/b] 7 of your opponent's followers."
	flavor_text = ""
	culture = "Norse"
	art_path = "res://images/card_art/creatures/AurbodaAI.jpg"

func on_kill(game_manager: GameManager, victim: Card) -> void:
	var opponent := game_manager.get_opponent(card_owner)
	game_manager.convert_followers(opponent, card_owner, 7)
	print("Pierce! " + card_name + " destroyed " + victim.card_name + " â€” 7 followers converted.")
