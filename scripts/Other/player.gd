# Player.gd
extends RefCounted
class_name Player

const MAX_HAND_SIZE := 7
const BOARD_LANE_COUNT := 5

signal mana_changed(new_mana: int)
signal followers_changed(new_followers: int)
signal card_moved(card: Card, from_zone: Zone, to_zone: Zone)
signal defeated(player: Player)

var player_name: String
var mana: int = 0
var followers: int = 100
var is_defeated: bool = false
var is_turn_player: bool = false
var has_summoned_this_turn: bool = false
var attack_restriction_turns: int = 0

var card_collection: Array[Card] = []
var current_deck: Array[Card] = []
var game_manager: GameManager = null

var hand_zone: Zone
var deck_zone: Zone
var graveyard_zone: Zone
var abyss_zone: Zone
var god_zone: Zone
var power_zones: Array[Zone] = []
var frontline_zones: Array[Zone] = []
var reserve_zones: Array[Zone] = []

func get_index(game_manager: GameManager = null) -> int:
	if game_manager == null:
		return -1
	return game_manager.players.find(self)

func _init() -> void:
	_initialize_zones()

func _initialize_zones() -> void:
	hand_zone = Zone.new()
	hand_zone.zone_type = Zone.ZoneType.HAND
	hand_zone.zone_owner = self
	
	deck_zone = Zone.new()
	deck_zone.zone_type = Zone.ZoneType.DECK
	deck_zone.zone_owner = self
	
	graveyard_zone = Zone.new()
	graveyard_zone.zone_type = Zone.ZoneType.GRAVEYARD
	graveyard_zone.zone_owner = self
	
	abyss_zone = Zone.new()
	abyss_zone.zone_type = Zone.ZoneType.ABYSS
	abyss_zone.zone_owner = self
	
	god_zone = Zone.new()
	god_zone.zone_type = Zone.ZoneType.GOD_SLOT
	god_zone.zone_owner = self
	
	for i in range(3):
		var power_zone = Zone.new()
		power_zone.zone_type = Zone.ZoneType.POWER_SLOT
		power_zone.zone_index = i
		power_zone.zone_owner = self
		power_zones.append(power_zone)
	
	for i in range(BOARD_LANE_COUNT):
		var frontline = Zone.new()
		frontline.zone_type = Zone.ZoneType.FRONTLINE
		frontline.zone_index = i
		frontline.zone_owner = self
		frontline_zones.append(frontline)
	
	for i in range(BOARD_LANE_COUNT):
		var reserve = Zone.new()
		reserve.zone_type = Zone.ZoneType.RESERVE
		reserve.zone_index = i
		reserve.zone_owner = self
		reserve_zones.append(reserve)

func validate_deck(deck: Array[Card]) -> bool:
	var legendary_count = 0
	var god_count = 0
	var power_count = 0
	var regular_card_count = 0
	var god_culture := ""
	var power_name_counts: Dictionary = {}
	
	for card in deck:
		if card.is_god:
			god_count += 1
			god_culture = card.culture
		elif card.is_power:
			power_count += 1
			var power_name := str(card.card_name)
			power_name_counts[power_name] = int(power_name_counts.get(power_name, 0)) + 1
		else:
			regular_card_count += 1
			if card.is_legendary:
				legendary_count += 1
	
	if god_count != 1:
		return false
	if power_count > 3:
		return false
	if regular_card_count < 35:
		return false
	for count in power_name_counts.values():
		if int(count) > 1:
			return false
	for card in deck:
		if card.is_power and not card.is_god:
			if card.culture != "Neutral" and card.culture != god_culture:
				return false
	
	var max_legendaries = int(regular_card_count / 10.0)
	if legendary_count > max_legendaries:
		return false
	
	return true

func gain_mana(amount: int) -> void:
	if amount > 0 and game_manager != null and not game_manager.can_player_gain_mana_now(self):
		game_manager.note_player_feedback("Laws of Civilization prevents gaining mana outside upkeep.")
		return
	mana += amount
	mana_changed.emit(mana)

func spend_mana(amount: int) -> bool:
	if mana >= amount:
		mana -= amount
		mana_changed.emit(mana)
		return true
	return false

func lose_mana(amount: int) -> int:
	var removed := mini(max(amount, 0), mana)
	if removed <= 0:
		return 0
	mana -= removed
	mana_changed.emit(mana)
	return removed

func gain_followers(amount: int) -> void:
	if is_defeated:
		return
	followers += amount
	followers_changed.emit(followers)

func lose_followers(amount: int) -> void:
	if is_defeated:
		return
	followers = max(0, followers - amount)
	followers_changed.emit(followers)
	if followers <= 0 and not is_defeated:
		is_defeated = true
		game_over()

func game_over() -> void:
	print(player_name + " has lost!")
	defeated.emit(self)

func move_card(card: Card, to_zone: Zone) -> void:
	var from_zone = card.current_zone
	var destination_zone := _resolve_destination_zone(card, from_zone, to_zone)
	if destination_zone == hand_zone \
			and card != null \
			and card.current_zone != hand_zone \
			and game_manager != null \
			and not game_manager.can_player_add_to_hand_now(self):
		game_manager.note_player_feedback("Laws of Civilization prevents cards from being added to hand outside upkeep.")
		return
	var creature_left_board := (
		card.is_creature_card()
		and from_zone != null
		and from_zone.is_board_zone()
		and destination_zone != null
		and not destination_zone.is_board_zone()
	)
	
	if creature_left_board:
		for equip in card.equipment.duplicate():
			if equip == null:
				continue
			equip.unequip()
	if card.card_type == Card.CardType.EQUIPMENT and card.equipped_on != null:
		var equipped_creature := card.equipped_on
		var same_zone_move := destination_zone != null and equipped_creature != null and destination_zone == equipped_creature.current_zone
		if not same_zone_move:
			card.unequip()
	if from_zone and from_zone.is_board_zone() and destination_zone and not destination_zone.is_board_zone():
		if card.has_method("reset_activation_counter"):
			card.reset_activation_counter()
		card.remove_effects_expiring_after_combat()

	if card.is_token and (destination_zone == null or not destination_zone.is_board_zone()):
		card.remove_effects_expiring_after_combat()
		if from_zone:
			from_zone.remove_card(card)
		card_moved.emit(card, from_zone, null)
		return
	
	if from_zone:
		from_zone.remove_card(card)
	destination_zone.add_card(card)
	card_moved.emit(card, from_zone, destination_zone)
	
	if card.is_creature_card() and destination_zone != null and destination_zone.is_board_zone():
		for equip in card.equipment.duplicate():
			if equip == null:
				continue
			var equip_zone: Zone = equip.current_zone
			if equip_zone == destination_zone:
				continue
			equip.card_owner.move_card(equip, destination_zone)

func draw_card() -> Card:
	if deck_zone.get_card_count() > 0:
		var card = deck_zone.cards[0]
		move_card(card, hand_zone)
		if card.current_zone == hand_zone:
			return card
	return null

func discard_card(card: Card) -> void:
	move_card(card, graveyard_zone)

func banish_card(card: Card) -> void:
	move_card(card, abyss_zone)

func shelve_card(card: Card) -> void:
	if card.current_zone == hand_zone:
		move_card(card, deck_zone)

func shuffle_card_into_deck(card: Card) -> bool:
	if card == null:
		return false
	move_card(card, deck_zone)
	deck_zone.cards.shuffle()
	return card.current_zone == deck_zone

func _resolve_destination_zone(card: Card, from_zone: Zone, to_zone: Zone) -> Zone:
	if card == null or to_zone == null:
		return to_zone
	if not card.is_creature_card():
		return to_zone
	if from_zone == null or not from_zone.is_board_zone():
		return to_zone
	if to_zone.is_board_zone():
		return to_zone
	if not card.is_enslaved():
		return to_zone
	var owner_player := card.card_owner
	if owner_player == null:
		return to_zone
	match to_zone.zone_type:
		Zone.ZoneType.HAND:
			return owner_player.hand_zone
		Zone.ZoneType.DECK:
			return owner_player.deck_zone
		Zone.ZoneType.GRAVEYARD:
			return owner_player.graveyard_zone
		Zone.ZoneType.ABYSS:
			return owner_player.abyss_zone
		_:
			return to_zone

func get_adjacent_zones(zone: Zone) -> Array[Zone]:
	var adjacent: Array[Zone] = []
	if zone.zone_type == Zone.ZoneType.FRONTLINE:
		var idx = zone.zone_index
		if idx > 0:
			adjacent.append(frontline_zones[idx - 1])
		if idx + 1 < frontline_zones.size():
			adjacent.append(frontline_zones[idx + 1])
		# Same column and diagonals in reserve row
		for di in [-1, 0, 1]:
			var ri = idx + di
			if ri >= 0 and ri < reserve_zones.size():
				adjacent.append(reserve_zones[ri])
	elif zone.zone_type == Zone.ZoneType.RESERVE:
		var idx = zone.zone_index
		if idx > 0:
			adjacent.append(reserve_zones[idx - 1])
		if idx + 1 < reserve_zones.size():
			adjacent.append(reserve_zones[idx + 1])
		# Same column and diagonals in frontline row
		for di in [-1, 0, 1]:
			var fi = idx + di
			if fi >= 0 and fi < frontline_zones.size():
				adjacent.append(frontline_zones[fi])

	return adjacent

func reset_creature_actions() -> void:
	has_summoned_this_turn = false
	for zone in frontline_zones + reserve_zones:
		for card in zone.cards:
			if card.is_creature_card():
				card.reset_creature_action_state()
