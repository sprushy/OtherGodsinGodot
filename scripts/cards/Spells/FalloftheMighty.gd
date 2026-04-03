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
	ability_text = "Destroy all non-stealthed creatures on the field with the highest strength."

static func counts_for_strength_check(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_stealth

static func get_creatures_for_strength_check(game_manager: GameManager) -> Array[Card]:
	var creatures: Array[Card] = []
	if game_manager == null:
		return creatures
	for player: Player in game_manager.players:
		if player == null:
			continue
		for zone: Zone in player.frontline_zones + player.reserve_zones:
			for card: Card in zone.cards:
				if counts_for_strength_check(card):
					creatures.append(card)
	return creatures

static func get_strongest_creatures(game_manager: GameManager) -> Array[Card]:
	var strongest_creatures: Array[Card] = []
	var max_strength := -1
	for creature: Card in get_creatures_for_strength_check(game_manager):
		var strength_value := creature.get_effective_strength()
		if strength_value > max_strength:
			max_strength = strength_value
			strongest_creatures.clear()
			strongest_creatures.append(creature)
		elif strength_value == max_strength:
			strongest_creatures.append(creature)
	return strongest_creatures

func resolve(game_manager: GameManager, _target = null) -> void:
	print("Fall of the Mighty - The strong shall fall!")
	
	var all_creatures := get_creatures_for_strength_check(game_manager)
	
	if all_creatures.size() == 0:
		print("No non-stealthed creatures on the field to destroy!")
		return
	
	# Find the highest strength
	var max_strength := all_creatures[0].get_effective_strength()
	for creature: Card in all_creatures:
		max_strength = maxi(max_strength, creature.get_effective_strength())
	
	print("Maximum strength found: " + str(max_strength))
	
	var doomed_creatures := get_strongest_creatures(game_manager)

	var destroyed_count: int = 0
	for creature: Card in doomed_creatures:
		print("Destroying " + creature.card_name + " (STR: " + str(max_strength) + ")")
		if game_manager.request_send_to_graveyard(creature, Callable(), false, true):
			destroyed_count += 1
	print("Fall of the Mighty destroyed " + str(destroyed_count) + " mighty creature(s)!")

func would_destroy_creature_of_player(game_manager: GameManager, protected_player: Player, _chosen_target = null) -> bool:
	if game_manager == null or protected_player == null:
		return false
	for creature in get_strongest_creatures(game_manager):
		if creature != null and creature.get_controller() == protected_player:
			return true
	return false
