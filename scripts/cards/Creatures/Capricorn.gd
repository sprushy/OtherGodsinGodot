extends CreatureCard
class_name Capricorn

func _init() -> void:
	super._init()
	card_name = "Capricorn"
	card_types = ["Animal", "Hircine", "Ancient Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	speed = 1
	resilience = 3
	strength = 5
	ability_text = "Sacrifice: If this creature is sacrificed for another creature's summon cost, gain 2 mana and return it from your graveyard to your hand."
	flavor_text = ""
	culture = "Ancient"
	artist = "Riccardo Zoppello"
	art_path = "res://images/card_art/creatures/CapricornAIEdit.png"

func on_sacrificed_for_summon(_game_manager: GameManager, summoned_card: Card) -> void:
	if card_owner == null:
		return
	card_owner.gain_mana(2)
	if current_zone == card_owner.graveyard_zone:
		card_owner.move_card(self, card_owner.hand_zone)
	print("%s was sacrificed to summon %s, then returned to hand and refunded 2 mana." % [
		card_name,
		summoned_card.card_name if summoned_card != null else "a creature"
	])
