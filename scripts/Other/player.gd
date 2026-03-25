# Player.gd
extends Node
class_name Player

const MAX_HAND_SIZE := 7

signal mana_changed(new_mana: int)
signal followers_changed(new_followers: int)
signal card_moved(card: Card, from_zone: Zone, to_zone: Zone)

@export var player_name: String
var mana: int = 0
var followers: int = 100
var is_turn_player: bool = false
var has_summoned_this_turn: bool = false
var attack_restriction_turns: int = 0

var card_collection: Array[Card] = []
var current_deck: Array[Card] = []

var hand_zone: Zone
var deck_zone: Zone
var graveyard_zone: Zone
var abyss_zone: Zone
var god_zone: Zone
var power_zones: Array[Zone] = []
var frontline_zones: Array[Zone] = []
var reserve_zones: Array[Zone] = []

func _ready() -> void:
	_initialize_zones()

func _initialize_zones() -> void:
	hand_zone = Zone.new()
	hand_zone.zone_type = Zone.ZoneType.HAND
	hand_zone.zone_owner = self
	add_child(hand_zone)
	
	deck_zone = Zone.new()
	deck_zone.zone_type = Zone.ZoneType.DECK
	deck_zone.zone_owner = self
	add_child(deck_zone)
	
	graveyard_zone = Zone.new()
	graveyard_zone.zone_type = Zone.ZoneType.GRAVEYARD
	graveyard_zone.zone_owner = self
	add_child(graveyard_zone)
	
	abyss_zone = Zone.new()
	abyss_zone.zone_type = Zone.ZoneType.ABYSS
	abyss_zone.zone_owner = self
	add_child(abyss_zone)
	
	god_zone = Zone.new()
	god_zone.zone_type = Zone.ZoneType.GOD_SLOT
	god_zone.zone_owner = self
	add_child(god_zone)
	
	for i in range(3):
		var power_zone = Zone.new()
		power_zone.zone_type = Zone.ZoneType.POWER_SLOT
		power_zone.zone_index = i
		power_zone.zone_owner = self
		power_zones.append(power_zone)
		add_child(power_zone)
	
	for i in range(7):
		var frontline = Zone.new()
		frontline.zone_type = Zone.ZoneType.FRONTLINE
		frontline.zone_index = i
		frontline.zone_owner = self
		frontline_zones.append(frontline)
		add_child(frontline)
	
	for i in range(7):
		var reserve = Zone.new()
		reserve.zone_type = Zone.ZoneType.RESERVE
		reserve.zone_index = i
		reserve.zone_owner = self
		reserve_zones.append(reserve)
		add_child(reserve)

func validate_deck(deck: Array[Card]) -> bool:
	var legendary_count = 0
	var god_count = 0
	var power_count = 0
	var regular_card_count = 0
	
	for card in deck:
		if card.is_god:
			god_count += 1
		elif card.is_power:
			power_count += 1
		else:
			regular_card_count += 1
			if card.is_legendary:
				legendary_count += 1
	
	if god_count != 1:
		return false
	if power_count > 3:
		return false
	
	var max_legendaries = int(regular_card_count / 10.0)
	if legendary_count > max_legendaries:
		return false
	
	return true

func gain_mana(amount: int) -> void:
	mana += amount
	mana_changed.emit(mana)

func spend_mana(amount: int) -> bool:
	if mana >= amount:
		mana -= amount
		mana_changed.emit(mana)
		return true
	return false

func gain_followers(amount: int) -> void:
	followers += amount
	followers_changed.emit(followers)

func lose_followers(amount: int) -> void:
	followers = max(0, followers - amount)
	followers_changed.emit(followers)
	if followers <= 0:
		game_over()

func game_over() -> void:
	print(player_name + " has lost!")

func move_card(card: Card, to_zone: Zone) -> void:
	var from_zone = card.current_zone
	var destination_zone := _resolve_destination_zone(card, from_zone, to_zone)
	
	if card.card_type == Card.CardType.CREATURE and from_zone and from_zone.is_board_zone():
		if card.equipment.size() > 0 and destination_zone and not destination_zone.is_board_zone():
			for equip in card.equipment.duplicate():
				equip.unequip()
	
	if from_zone:
		from_zone.remove_card(card)
	destination_zone.add_card(card)
	card_moved.emit(card, from_zone, destination_zone)

func draw_card() -> Card:
	if deck_zone.get_card_count() > 0:
		var card = deck_zone.cards[0]
		move_card(card, hand_zone)
		return card
	return null

func discard_card(card: Card) -> void:
	move_card(card, graveyard_zone)

func banish_card(card: Card) -> void:
	move_card(card, abyss_zone)

func shelve_card(card: Card) -> void:
	if card.current_zone == hand_zone:
		move_card(card, deck_zone)

func _resolve_destination_zone(card: Card, from_zone: Zone, to_zone: Zone) -> Zone:
	if card == null or to_zone == null:
		return to_zone
	if card.card_type != Card.CardType.CREATURE:
		return to_zone
	if from_zone == null or not from_zone.is_board_zone():
		return to_zone
	if to_zone.is_board_zone():
		return to_zone
	if not card.is_enslaved():
		return to_zone
	var owner := card.card_owner
	if owner == null:
		return to_zone
	match to_zone.zone_type:
		Zone.ZoneType.HAND:
			return owner.hand_zone
		Zone.ZoneType.DECK:
			return owner.deck_zone
		Zone.ZoneType.GRAVEYARD:
			return owner.graveyard_zone
		Zone.ZoneType.ABYSS:
			return owner.abyss_zone
		_:
			return to_zone

func sacrifice_followers(amount: int) -> bool:
	if followers >= amount:
		lose_followers(amount)
		return true
	return false

func get_adjacent_zones(zone: Zone) -> Array[Zone]:
	var adjacent: Array[Zone] = []
	if zone.zone_type == Zone.ZoneType.FRONTLINE:
		var idx = zone.zone_index
		if idx > 0:
			adjacent.append(frontline_zones[idx - 1])
		if idx < 6:
			adjacent.append(frontline_zones[idx + 1])
		# Same column and diagonals in reserve row
		for di in [-1, 0, 1]:
			var ri = idx + di
			if ri >= 0 and ri <= 6:
				adjacent.append(reserve_zones[ri])
	elif zone.zone_type == Zone.ZoneType.RESERVE:
		var idx = zone.zone_index
		if idx > 0:
			adjacent.append(reserve_zones[idx - 1])
		if idx < 6:
			adjacent.append(reserve_zones[idx + 1])
		# Same column and diagonals in frontline row
		for di in [-1, 0, 1]:
			var fi = idx + di
			if fi >= 0 and fi <= 6:
				adjacent.append(frontline_zones[fi])

	return adjacent

func reset_creature_actions() -> void:
	has_summoned_this_turn = false
	for zone in frontline_zones + reserve_zones:
		for card in zone.cards:
			if card.card_type == Card.CardType.CREATURE:
				card.reset_creature_action_state()
