extends CreatureCard
class_name Alu

func _init() -> void:
	super._init()
	card_name = "Alu"
	card_types = ["Demon", "Ancient Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 16
	strength = 19
	ability_text = "Stupefy: Use this card's action to put an equal- or lower-level creature to [b]Sleep[/b] while Alu remains on the field."
	flavor_text = ""
	culture = "Ancient"
	art_path = "res://images/card_art/creatures/alu.jpg"
	targets = true

func stupefy(target: Card) -> void:
	target.apply_sleep(self)
	spend_major_creature_action()
	print(card_name + " stupefies " + target.card_name + "! It falls asleep.")

func on_removed(game_manager: GameManager) -> void:
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card.sleeping_from == self:
					card.remove_status_effects_from_source_card(self, "sleep")
					print(card.card_name + " wakes up - " + card_name + " left the field.")
