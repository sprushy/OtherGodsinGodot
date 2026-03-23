extends CreatureCard
class_name Alu

func _init() -> void:
	super._init()
	card_name = "Alû"
	card_types = ["Demon", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 16
	strength = 19
	ability_text = "Stupefy: May use its action to put a creature of equal or lower level to [b]Sleep[/b] for as long as Alû remains on the field."
	flavor_text = ""
	culture = "Ancient"
	art_path = "res://images/card_art/alu.jpg"
	targets = true

func stupefy(target: Card) -> void:
	target.is_sleeping = true
	target.sleeping_from = self
	has_acted_this_turn = true
	print(card_name + " stupefies " + target.card_name + "! It falls asleep.")

func on_removed(game_manager: GameManager) -> void:
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card.sleeping_from == self:
					card.is_sleeping = false
					card.sleeping_from = null
					print(card.card_name + " wakes up — " + card_name + " left the field.")
