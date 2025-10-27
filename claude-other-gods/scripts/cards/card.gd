# Card.gd
extends Resource
class_name Card

enum CardType { CREATURE, SPELL, AURA, EQUIPMENT, STRUCTURE, HEX }
enum CreatureMode { ATTACK, DEFENSE }

@export var card_name: String
@export var card_type: CardType
@export var speed: int = 1
@export var level: int = 1
@export var is_legendary: bool = false
@export var is_god: bool = false
@export var is_power: bool = false

# Card types (warrior, mage, etc.) - can have multiple
@export var card_types: Array[String] = []

# Lore and background
@export_multiline var flavor_text: String = ""
@export_multiline var ability_text: String = ""
@export var culture: String = ""  # e.g., "Sumerian", "Norse", "Egyptian"

# Costs
@export var mana_cost: int = 0
@export var discard_cost: int = 0  # Number of cards to discard
@export var sacrifice_cost: int = 0  # Number of followers to sacrifice
@export var banish_cost: int = 0  # Number of cards to banish
@export var creature_sacrifice_cost: int = 0  # Number of creatures to sacrifice from board
@export var shelve_cost: int = 0  # Number of cards to shelve (return to bottom of deck)

# Creature stats
@export var strength: int = 0
@export var resilience: int = 0
@export var creature_mode: CreatureMode = CreatureMode.DEFENSE

# Equipment modifiers
@export var strength_modifier: int = 0
@export var resilience_modifier: int = 0
@export var speed_modifier: int = 0

# Card state - Changed "owner" to "card_owner" to avoid Godot reserved word
var card_owner: Player
var current_zone: Zone
var is_prepared: bool = false
var is_face_down: bool = false
var is_stealth: bool = false
var has_acted_this_turn: bool = false
var equipped_on: Card = null
var equipment: Array[Card] = []
var summoned_this_turn: bool = false

func get_effective_speed() -> int:
	var base_speed = speed
	if is_stealth:
		base_speed -= 1
	for equip in equipment:
		base_speed += equip.speed_modifier
	return max(1, base_speed)

func get_effective_strength() -> int:
	var total = strength
	for equip in equipment:
		total += equip.strength_modifier
	return total

func get_effective_resilience() -> int:
	var total = resilience
	for equip in equipment:
		total += equip.resilience_modifier
	return total

func can_respond_to(other_card: Card) -> bool:
	return get_effective_speed() >= 2 and get_effective_speed() >= other_card.get_effective_speed()

func is_permanent() -> bool:
	return card_type in [CardType.CREATURE, CardType.AURA, CardType.EQUIPMENT, CardType.STRUCTURE]

func goes_to_graveyard_after_use() -> bool:
	return card_type in [CardType.SPELL, CardType.HEX]

func has_type(type_name: String) -> bool:
	return type_name in card_types

func equip_to(creature: Card) -> bool:
	if card_type != CardType.EQUIPMENT or creature.card_type != CardType.CREATURE:
		return false
	
	if equipped_on:
		equipped_on.equipment.erase(self)
	
	equipped_on = creature
	creature.equipment.append(self)
	return true

func unequip() -> void:
	if equipped_on:
		equipped_on.equipment.erase(self)
		equipped_on = null

func reveal_from_stealth() -> void:
	if is_stealth:
		is_stealth = false
		is_face_down = false

func can_pay_costs(player: Player) -> bool:
	# Check if player can afford all costs
	if player.mana < mana_cost:
		return false
	if player.hand_zone.get_card_count() < discard_cost:
		return false
	if player.followers < sacrifice_cost:
		return false
	if player.hand_zone.get_card_count() < shelve_cost:
		return false
	
	# Count creatures on board for creature sacrifice
	var creature_count = 0
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if card.card_type == CardType.CREATURE:
				creature_count += 1
	if creature_count < creature_sacrifice_cost:
		return false
	
	# Check cards available to banish (hand + board)
	var banishable = player.hand_zone.get_card_count()
	for zone in player.frontline_zones + player.reserve_zones:
		banishable += zone.get_card_count()
	if banishable < banish_cost:
		return false
	
	return true

func pay_costs(player: Player) -> bool:
	if not can_pay_costs(player):
		return false
	
	# Pay mana cost
	if mana_cost > 0:
		player.spend_mana(mana_cost)
	
	# Pay discard cost
	for i in range(discard_cost):
		if player.hand_zone.get_card_count() > 0:
			var card_to_discard = player.hand_zone.cards[0]
			player.discard_card(card_to_discard)
	
	# Pay sacrifice cost (followers)
	if sacrifice_cost > 0:
		player.sacrifice_followers(sacrifice_cost)
	
	# Pay shelve cost
	for i in range(shelve_cost):
		if player.hand_zone.get_card_count() > 0:
			var card_to_shelve = player.hand_zone.cards[0]
			player.shelve_card(card_to_shelve)
	
	# Pay creature sacrifice cost
	for i in range(creature_sacrifice_cost):
		var creature_found = false
		for zone in player.frontline_zones + player.reserve_zones:
			if not creature_found:
				for card in zone.cards:
					if card.card_type == CardType.CREATURE:
						player.move_card(card, player.graveyard_zone)
						creature_found = true
						break
	
	# Pay banish cost
	for i in range(banish_cost):
		var card_found = false
		# Try hand first
		if player.hand_zone.get_card_count() > 0:
			var card_to_banish = player.hand_zone.cards[0]
			player.banish_card(card_to_banish)
			card_found = true
		# Then board
		if not card_found:
			for zone in player.frontline_zones + player.reserve_zones:
				if zone.get_card_count() > 0:
					var card_to_banish = zone.cards[0]
					player.banish_card(card_to_banish)
					break
	
	return true
