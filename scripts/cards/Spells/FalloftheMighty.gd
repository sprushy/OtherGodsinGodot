# cards/spells/FallOfTheMighty.gd
extends SpellCard
class_name FallOfTheMighty

func _init() -> void:
	super._init()
	card_name = "Fall of the Mighty"
	culture = "Neutral"
	var types: Array[String] = ["Destruction"]
	card_types = types
	
	level = 2
	mana_cost = 1
	speed = 1
	is_legendary = false
	
	sacrifice_cost = 0
	
	flavor_text = "Destroy the strongest creature(s) on the field."
	culture = "Neutral"
	art_path = "res://images/card_art/spells/fall_of_the_mighty.jpg"
	ability_text = "Destroy all creatures on the field with the highest strength."

func resolve(game_manager: GameManager, _target = null) -> void:
	print("Fall of the Mighty - The strong shall fall!")
	
	var all_creatures: Array[Card] = []
	
	# Collect all creatures from both players
	for player: Player in game_manager.players:
		for zone: Zone in player.frontline_zones:
			for card: Card in zone.cards:
				if card.card_type == Card.CardType.CREATURE:
					all_creatures.append(card)
		for zone: Zone in player.reserve_zones:
			for card: Card in zone.cards:
				if card.card_type == Card.CardType.CREATURE:
					all_creatures.append(card)
	
	if all_creatures.size() == 0:
		print("No creatures on the field to destroy!")
		return
	
	# Find the highest strength
	var max_strength: int = 0
	for creature: Card in all_creatures:
		var str_val: int = creature.get_effective_strength()
		if str_val > max_strength:
			max_strength = str_val
	
	print("Maximum strength found: " + str(max_strength))
	
	var doomed_creatures: Array[Card] = []
	for creature: Card in all_creatures:
		if creature.get_effective_strength() == max_strength:
			doomed_creatures.append(creature)

	var destroyed_count: int = 0
	for creature: Card in doomed_creatures:
		print("Destroying " + creature.card_name + " (STR: " + str(max_strength) + ")")
		if game_manager.request_send_to_graveyard(creature, Callable(), false, true):
			destroyed_count += 1
	print("Fall of the Mighty destroyed " + str(destroyed_count) + " mighty creature(s)!")
