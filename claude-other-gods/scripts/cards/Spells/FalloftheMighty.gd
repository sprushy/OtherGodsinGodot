# cards/spells/FallOfTheMighty.gd
extends SpellCard
class_name FallOfTheMighty

func _init() -> void:
	super._init()
	card_name = "Fall of the Mighty"
	
	var types: Array[String] = ["Destruction"]
	card_types = types
	
	level = 2
	mana_cost = 1
	speed = 1
	is_legendary = false
	
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	
	flavor_text = "Destroy the strongest creature(s) on the field."
	culture = "Neutral"

func resolve(game_manager: GameManager, target = null) -> void:
	print("Fall of the Mighty - The strong shall fall!")
	
	var all_creatures: Array[Card] = []
	
	# Collect all creatures from both players
	for player in [game_manager.current_player, game_manager.other_player]:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card.card_type == Card.CardType.CREATURE:
					all_creatures.append(card)
	
	if all_creatures.size() == 0:
		print("No creatures on the field to destroy!")
		return
	
	# Find the highest strength
	var max_strength = 0
	for creature in all_creatures:
		var str_val = creature.get_effective_strength()
		if str_val > max_strength:
			max_strength = str_val
	
	print("Maximum strength found: " + str(max_strength))
	
	# Destroy all creatures with that strength
	var destroyed_count = 0
	for creature in all_creatures:
		if creature.get_effective_strength() == max_strength:
			print("Destroying " + creature.card_name + " (STR: " + str(max_strength) + ")")
			creature.card_owner.move_card(creature, creature.card_owner.graveyard_zone)
			destroyed_count += 1
	
	print("Fall of the Mighty destroyed " + str(destroyed_count) + " mighty creature(s)!")
