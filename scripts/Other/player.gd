# Player.gd
extends RefCounted
class_name Player

const MAX_HAND_SIZE := 7
const BOARD_LANE_COUNT := 5
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const ManaSoundPlayerScript = preload("res://scripts/audio/ManaSoundPlayer.gd")
const DrawCardSoundPlayerScript = preload("res://scripts/audio/DrawCardSoundPlayer.gd")

signal mana_changed(new_mana: int)
signal followers_changed(new_followers: int)
signal guard_changed(new_guard: int)
signal card_moved(card: Card, from_zone: Zone, to_zone: Zone)
signal defeated(player: Player)

var player_name: String
var mana: int = 0
var followers: int = 100
var followers_enabled: bool = true
var guard: int = 0
var is_defeated: bool = false
var is_turn_player: bool = false
var has_summoned_this_turn: bool = false
var has_summoned_structure_this_turn: bool = false
var has_had_god_in_play: bool = false
var attack_restriction_turns: int = 0

var card_collection: Array[Card] = []
var current_deck: Array[Card] = []
var game_manager: GameManager = null
var reserved_active_god: ActiveGodCard = null

var hand_zone: Zone
var deck_zone: Zone
var graveyard_zone: Zone
var abyss_zone: Zone
var god_zone: Zone
var power_zones: Array[Zone] = []
var frontline_zones: Array[Zone] = []
var reserve_zones: Array[Zone] = []

func get_index(manager: GameManager = null) -> int:
	if manager == null:
		return -1
	return manager.players.find(self)

static func create_spectator_viewer() -> Player:
	# Spectators need a distinct identity for visibility without owning zones.
	return Player.new(false)

func _init(owns_zones: bool = true) -> void:
	if owns_zones:
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

func validate_deck(deck: Array[Card], special_setup: Dictionary = {}) -> bool:
	var validation := get_deck_validation(deck, special_setup)
	return bool(validation.get("is_valid", false))

func get_deck_validation(deck: Array[Card], special_setup: Dictionary = {}) -> Dictionary:
	var validator = DeckValidatorScript.new()
	return validator.validate_card_array(deck, special_setup)

func gain_mana(amount: int, play_sound: bool = true) -> void:
	if amount > 0 and game_manager != null and not game_manager.can_player_gain_mana_now(self):
		game_manager.note_player_feedback("Laws of Civilization prevents gaining mana outside upkeep.")
		return
	mana += amount
	if amount > 0 and game_manager != null and play_sound:
		if game_manager.sfx_enabled:
			ManaSoundPlayerScript.play_gain(amount)
		game_manager.note_ui_sound_cue("mana_gain:%d" % amount)
	mana_changed.emit(mana)

func spend_mana(amount: int) -> bool:
	if mana >= amount:
		mana -= amount
		if amount > 0 and game_manager != null:
			if game_manager.sfx_enabled:
				ManaSoundPlayerScript.play_spend()
			game_manager.note_ui_sound_cue("mana_spend")
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

func gain_guard(amount: int) -> void:
	if is_defeated:
		return
	if amount <= 0:
		return
	guard += amount
	guard_changed.emit(guard)

func absorb_guard_damage(amount: int) -> int:
	if amount <= 0 or guard <= 0:
		return amount
	var absorbed := mini(amount, guard)
	guard -= absorbed
	guard_changed.emit(guard)
	return amount - absorbed

func gain_followers(amount: int) -> void:
	if not followers_enabled:
		return
	if is_defeated:
		return
	if game_manager != null:
		game_manager.record_match_follower_gain(self, amount)
	followers += amount
	followers_changed.emit(followers)

func lose_followers(amount: int, source_card: Card = null) -> void:
	if not followers_enabled:
		return
	if is_defeated:
		return
	if amount <= 0:
		return
	if game_manager != null and not game_manager.can_player_lose_followers_now(self):
		return
	if game_manager != null:
		game_manager.record_match_follower_loss(self, mini(followers, amount), source_card)
	followers = max(0, followers - amount)
	followers_changed.emit(followers)
	if followers <= 0 and not is_defeated:
		is_defeated = true
		game_over()

func game_over() -> void:
	print(player_name + " has lost!")
	defeated.emit(self)

func move_card(card: Card, to_zone: Zone, deck_placement: Zone.DeckPlacement = Zone.DeckPlacement.UNKNOWN) -> void:
	var from_zone = card.current_zone
	var destination_zone := _resolve_destination_zone(card, from_zone, to_zone)
	var detached_equipment: Array[Card] = []
	if card != null and card == reserved_active_god and destination_zone != null:
		reserved_active_god = null
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
	var leaving_play := (
		from_zone != null
		and from_zone.is_in_play_zone()
		and destination_zone != null
		and not destination_zone.is_in_play_zone()
	)

	if leaving_play:
		card.process_board_leave_hooks(game_manager)
	
	if creature_left_board:
		detached_equipment.assign(card.equipment.duplicate())
		for equip in detached_equipment:
			if equip == null:
				continue
			equip.unequip()
	if card.card_type == Card.CardType.EQUIPMENT and card.equipped_on != null:
		var equipped_creature := card.equipped_on
		var same_zone_move := destination_zone != null and equipped_creature != null and destination_zone == equipped_creature.current_zone
		if not same_zone_move:
			card.unequip()
	if leaving_play:
		if card.has_method("reset_activation_counter"):
			card.reset_activation_counter()
		card.remove_effects_expiring_after_combat()

	if card.is_token and (destination_zone == null or not destination_zone.is_board_zone()):
		card.remove_effects_expiring_after_combat()
		if from_zone:
			from_zone.remove_card(card)
		card_moved.emit(card, from_zone, null)
		if leaving_play:
			card.clear_board_leave_state()
		return
	
	var deck_identity_public: Variant = _get_deck_identity_public(card, from_zone, destination_zone, deck_placement)
	if from_zone:
		from_zone.remove_card(card)
	elif not destination_zone.is_in_play_zone():
		card.field_subtypes.clear()
	destination_zone.add_card(card, deck_placement, deck_identity_public)
	if destination_zone.is_in_play_zone():
		card.reset_board_leave_hooks()
	card_moved.emit(card, from_zone, destination_zone)
	if leaving_play \
			and destination_zone == card.card_owner.graveyard_zone \
			and card.has_method("on_perish") \
			and not card.post_field_abilities_suppressed():
		card.call("on_perish", game_manager)
	if leaving_play:
		card.clear_board_leave_state()

	if creature_left_board and from_zone != null:
		_reposition_detached_equipment(from_zone, detached_equipment)
	
	if card.is_creature_card() and destination_zone != null and destination_zone.is_board_zone():
		for equip in card.equipment.duplicate():
			if equip == null:
				continue
			var equip_zone: Zone = equip.current_zone
			if equip_zone == destination_zone:
				continue
			equip.card_owner.move_card(equip, destination_zone)

func _reposition_detached_equipment(source_zone: Zone, detached_equipment: Array[Card]) -> void:
	if source_zone == null or not source_zone.is_board_zone():
		return
	var dropped_equipment: Array[Card] = []
	for equip in detached_equipment:
		if equip == null:
			continue
		if equip.card_type != Card.CardType.EQUIPMENT:
			continue
		if equip.current_zone != source_zone:
			continue
		dropped_equipment.append(equip)
	if dropped_equipment.size() <= 1:
		return

	var available_zones := _get_nearest_available_board_zones(source_zone)
	for i in range(1, dropped_equipment.size()):
		if available_zones.is_empty():
			return
		var equip := dropped_equipment[i]
		var destination := available_zones.pop_front() as Zone
		if equip != null and destination != null:
			move_card(equip, destination)

func _get_nearest_available_board_zones(source_zone: Zone) -> Array[Zone]:
	var same_row: Array[Zone] = []
	var other_row: Array[Zone] = []
	for zone in frontline_zones + reserve_zones:
		if zone == null or zone == source_zone:
			continue
		if not zone.cards.is_empty():
			continue
		if zone.zone_type == source_zone.zone_type:
			same_row.append(zone)
		else:
			other_row.append(zone)
	_sort_board_zones_by_proximity(same_row, source_zone.zone_index)
	_sort_board_zones_by_proximity(other_row, source_zone.zone_index)
	var ordered: Array[Zone] = []
	ordered.append_array(same_row)
	ordered.append_array(other_row)
	return ordered

func _sort_board_zones_by_proximity(zones: Array[Zone], source_index: int) -> void:
	zones.sort_custom(func(a: Zone, b: Zone) -> bool:
		var a_distance = abs(a.zone_index - source_index)
		var b_distance = abs(b.zone_index - source_index)
		if a_distance == b_distance:
			return a.zone_index < b.zone_index
		return a_distance < b_distance
	)

func draw_card() -> Card:
	if deck_zone.get_card_count() > 0:
		var card = deck_zone.cards[0]
		move_card(card, hand_zone)
		if card.current_zone == hand_zone:
			if game_manager != null:
				if game_manager.sfx_enabled:
					DrawCardSoundPlayerScript.play_sound()
				game_manager.note_ui_sound_cue("draw_card")
			return card
	return null

## Decide whether opponents legitimately know a card's identity when it enters
## a deck primed or shelved. Cards taken from public information (a face-up
## board card, or a graveyard/abyss card everyone could see) stay known; cards
## taken from a hand or an unknown deck position stay hidden.
func _get_deck_identity_public(card: Card, from_zone: Zone, to_zone: Zone, deck_placement: Zone.DeckPlacement) -> Variant:
	if to_zone == null or to_zone.zone_type != Zone.ZoneType.DECK:
		return null
	if deck_placement != Zone.DeckPlacement.PRIMED and deck_placement != Zone.DeckPlacement.SHELVED:
		return null
	if from_zone == null:
		return false
	match from_zone.zone_type:
		Zone.ZoneType.GRAVEYARD, Zone.ZoneType.ABYSS:
			# Graveyard and abyss contents are public to all players.
			return true
		Zone.ZoneType.DECK:
			# Keep any identity opponents already learned (e.g. Odin revealed
			# the top card before shelving it).
			return from_zone.is_deck_card_publicly_known(card)
		Zone.ZoneType.HAND:
			return card.is_revealed_in_hand() \
				or card.is_revealed_to_all() \
				or (card is PowerCard and (card as PowerCard).is_publicly_revealed)
		Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE, Zone.ZoneType.POWER_SLOT, Zone.ZoneType.GOD_SLOT:
			var viewer := _get_opposing_viewer_of(card)
			return viewer == null or not card.is_hidden_from_viewer(viewer)
	return false

func _get_opposing_viewer_of(card: Card) -> Player:
	var owner_game_manager := game_manager
	if owner_game_manager == null and card != null and card.card_owner != null:
		owner_game_manager = card.card_owner.game_manager
	if owner_game_manager == null:
		return null
	for player in owner_game_manager.players:
		if player != null and player != self:
			return player
	return null

func discard_card(card: Card) -> void:
	move_card(card, graveyard_zone)

func banish_card(card: Card) -> void:
	move_card(card, abyss_zone)

func shelve_card(card: Card) -> void:
	if card.current_zone == hand_zone:
		move_card(card, deck_zone, Zone.DeckPlacement.SHELVED)

func shuffle_card_into_deck(card: Card) -> bool:
	if card == null:
		return false
	move_card(card, deck_zone)
	deck_zone.shuffle_deck()
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
	var owner_player := card.card_owner
	if owner_player == null:
		return to_zone
	if card.get_controller() == owner_player:
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
	has_summoned_structure_this_turn = false
	for zone in frontline_zones + reserve_zones:
		for card in zone.cards:
			if card.is_creature_card():
				card.reset_creature_action_state()
				card.summoned_after_first_attack_this_turn = false
