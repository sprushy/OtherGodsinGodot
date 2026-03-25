# Card.gd
extends Resource
class_name Card

enum CardType { CREATURE, SPELL, AURA, EQUIPMENT, STRUCTURE, HEX, POWER, CHARM }
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
@export var targets: bool = false  # True if this card's effect targets a specific card
@export var culture: String = ""  # e.g., "Sumerian", "Norse", "Egyptian"
@export var art_path: String = ""  # e.g., "res://images/card_art/hexes/VoidShield.jpg"
@export var artist: String = ""
@export var paragon_of_champions: String = ""  # Name of the champion type this god is patron of; empty if not a paragon
@export var name_at_bottom: bool = false  # If true, card name is rendered at the bottom instead of the top
@export var exhausted_art_path: String = ""  # Art to switch to when the card's effect is exhausted
@export var ability_immunity_tag: String = ""

signal art_updated(new_path: String)

func switch_to_exhausted_art() -> void:
	if exhausted_art_path != "":
		art_path = exhausted_art_path
		art_updated.emit(art_path)

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
# Tracks the last board position so Circle of Rebirth can auto-resurrect.
var last_board_zone_type: int = -1   # Zone.ZoneType value; -1 = never placed
var last_board_zone_index: int = 3   # default centre column
var is_face_down: bool = false
var is_stealth: bool = false
var has_acted_this_turn: bool = false
var has_moved_this_turn: bool = false
var has_attacked_this_turn: bool = false
var creature_major_action_used: bool = false
var creature_minor_actions_used: int = 0
var is_sleeping: bool = false
var sleeping_from: Card = null
var equipped_on: Card = null
var equipment: Array[Card] = []
var summoned_this_turn: bool = false
var is_used: bool = false          # for single-use activatable abilities on powers
var is_muted: bool = false
var mute_turns_remaining: int = 0
var _mute_applied_owner_turn_number: int = -1

# Runtime stat buffs: Array of {source: String, str: int, res: int, spd: int}
var active_buffs: Array[Dictionary] = []
var active_statuses: Array[Dictionary] = []
var _was_muted_last_check: bool = false

func get_controller() -> Player:
	if current_zone != null and current_zone.is_board_zone() and current_zone.zone_owner != null:
		return current_zone.zone_owner
	return card_owner

func is_enslaved() -> bool:
	var controller := get_controller()
	return controller != null and card_owner != null and controller != card_owner

func has_status_effect(status_name: String) -> bool:
	for status in active_statuses:
		if status.get("name", "") == status_name:
			return true
	return false

func is_petrified() -> bool:
	return has_status_effect("petrified")

func is_silenced() -> bool:
	return is_muted and mute_turns_remaining < 0

func abilities_suppressed() -> bool:
	return is_enslaved() or is_petrified() or is_muted

func get_effective_speed() -> int:
	var base_speed = speed
	if is_stealth:
		base_speed -= 1
	for equip in equipment:
		base_speed += equip.speed_modifier
	for buff in active_buffs:
		base_speed += buff.get("spd", 0)
	return max(1, base_speed)

func get_effective_strength() -> int:
	var total = strength
	for equip in equipment:
		total += equip.strength_modifier
	for buff in active_buffs:
		total += buff.get("str", 0)
	return total

func get_effective_resilience() -> int:
	var total = resilience
	for equip in equipment:
		total += equip.resilience_modifier
	for buff in active_buffs:
		total += buff.get("res", 0)
	return total

# Returns a human-readable breakdown of all active buffs for a stat ("str", "res", "spd")
func get_buff_tooltip(stat: String) -> String:
	var lines: Array[String] = []
	for buff in active_buffs:
		var v: int = buff.get(stat, 0)
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " from " + buff.get("source", "?"))
	return "\n".join(lines)

# Returns a full breakdown including equipment modifiers and buffs, e.g. "21 +5 Bearded Axe"
# Returns empty string if no modifiers are active.
func get_full_stat_breakdown(stat: String) -> String:
	var base: int
	match stat:
		"str": base = strength
		"res": base = resilience
		"spd": base = speed
		_: return ""
	var lines: Array[String] = []
	for equip in equipment:
		var v: int
		match stat:
			"str": v = equip.strength_modifier
			"res": v = equip.resilience_modifier
			"spd": v = equip.speed_modifier
			_: v = 0
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " " + equip.card_name)
	for buff in active_buffs:
		var v: int = buff.get(stat, 0)
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " from " + buff.get("source", "?"))
	if lines.is_empty():
		return ""
	return str(base) + " " + " ".join(lines)

func get_effect_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for buff in active_buffs:
		var parts: Array[String] = []
		var str_change: int = buff.get("str", 0)
		var res_change: int = buff.get("res", 0)
		var spd_change: int = buff.get("spd", 0)
		if str_change != 0:
			parts.append(("STR %+d" % str_change))
		if res_change != 0:
			parts.append(("RES %+d" % res_change))
		if spd_change != 0:
			parts.append(("SPD %+d" % spd_change))
		if parts.size() == 0:
			continue
		lines.append(", ".join(parts) + " from " + str(buff.get("source", "?")))

	for status in active_statuses:
		var raw_status_name := str(status.get("name", "Status"))
		if raw_status_name == "blessed_ward":
			var ward_kind := str(status.get("ward_kind", "")).replace("_", " ")
			lines.append("Blessed Ward vs " + ward_kind.capitalize() + " from " + str(status.get("source", "?")))
			continue
		var status_name := raw_status_name.capitalize()
		lines.append(status_name + " from " + str(status.get("source", "?")))

	return lines

func clear_buffs_from(source: String) -> void:
	active_buffs = active_buffs.filter(func(b): return b.get("source", "") != source)

func remove_buffs_from_source_card(source_card: Card, effect_type: String = "") -> void:
	active_buffs = active_buffs.filter(func(b):
		var same_source: bool = b.get("source_card", null) == source_card
		var same_effect_type: bool = effect_type == "" or b.get("effect_type", "") == effect_type
		return not (same_source and same_effect_type)
	)

func add_buff(
	source: String,
	str_bonus: int,
	res_bonus: int,
	spd_bonus: int,
	source_card: Card = null,
	source_owner: Player = null,
	effect_type: String = "buff",
	extra_metadata: Dictionary = {}
) -> void:
	var buff := {
		"source": source,
		"str": str_bonus,
		"res": res_bonus,
		"spd": spd_bonus,
		"source_card": source_card,
		"source_owner": source_owner,
		"effect_type": effect_type,
	}
	for key in extra_metadata.keys():
		buff[key] = extra_metadata[key]
	active_buffs.append(buff)

func add_status_effect(
	status_name: String,
	source: String,
	source_card: Card = null,
	source_owner: Player = null,
	extra_metadata: Dictionary = {}
) -> void:
	var status := {
		"name": status_name,
		"source": source,
		"source_card": source_card,
		"source_owner": source_owner,
	}
	for key in extra_metadata.keys():
		status[key] = extra_metadata[key]
	active_statuses.append(status)
	_sync_status_flags()

func remove_status_effects_by_name(status_name: String) -> void:
	active_statuses = active_statuses.filter(func(s): return s.get("name", "") != status_name)
	_sync_status_flags()

func remove_status_effects_from_source_card(source_card: Card, status_name: String = "") -> void:
	active_statuses = active_statuses.filter(func(s):
		var same_source: bool = s.get("source_card", null) == source_card
		var same_status: bool = status_name == "" or s.get("name", "") == status_name
		return not (same_source and same_status)
	)
	_sync_status_flags()

func remove_expired_statuses(current_turn: int) -> void:
	active_statuses = active_statuses.filter(func(s):
		return s.get("expires_turn", null) != current_turn
	)
	_sync_status_flags()

func has_effects_from_player(player: Player) -> bool:
	for buff in active_buffs:
		if buff.get("source_owner", null) == player:
			return true
	for status in active_statuses:
		if status.get("source_owner", null) == player:
			return true
	return false

func remove_effects_from_player(player: Player) -> void:
	active_buffs = active_buffs.filter(func(b): return b.get("source_owner", null) != player)
	active_statuses = active_statuses.filter(func(s): return s.get("source_owner", null) != player)
	_sync_status_flags()

func apply_sleep(source_card: Card) -> void:
	remove_status_effects_by_name("sleep")
	add_status_effect("sleep", source_card.card_name if source_card != null else "Sleep", source_card, source_card.card_owner if source_card != null else null)

func wake_up() -> void:
	remove_status_effects_by_name("sleep")

func clear_all_effects() -> void:
	active_buffs.clear()
	active_statuses.clear()
	_sync_status_flags()

func _sync_status_flags() -> void:
	var sleep_status: Dictionary = {}
	for status in active_statuses:
		if status.get("name", "") == "sleep":
			sleep_status = status
			break
	is_sleeping = not sleep_status.is_empty()
	sleeping_from = sleep_status.get("source_card", null) if is_sleeping else null

func can_respond_to(other_card: Card) -> bool:
	return get_effective_speed() >= 2 and get_effective_speed() >= other_card.get_effective_speed()

func is_permanent() -> bool:
	return card_type in [CardType.CREATURE, CardType.AURA, CardType.EQUIPMENT, CardType.STRUCTURE, CardType.POWER]

func goes_to_graveyard_after_use() -> bool:
	return card_type in [CardType.SPELL, CardType.HEX, CardType.CHARM]

func get_ability_immunity_tag() -> String:
	if ability_immunity_tag != "":
		return ability_immunity_tag
	if is_god:
		return "powers"
	match card_type:
		CardType.CREATURE:
			return "creature_abilities"
		CardType.POWER:
			return "powers"
		CardType.HEX:
			return "hexes"
	return ""

func mute_for_turns(turns: int, game_manager: GameManager = null) -> void:
	var was_muted := is_muted
	is_muted = turns > 0
	mute_turns_remaining = max(0, turns)
	_mute_applied_owner_turn_number = -1
	if game_manager != null and game_manager.current_player == card_owner:
		_mute_applied_owner_turn_number = game_manager.turn_number
	_process_mute_state_change(game_manager, was_muted)

func mute_permanently(game_manager: GameManager = null) -> void:
	var was_muted := is_muted
	is_muted = true
	mute_turns_remaining = -1
	_mute_applied_owner_turn_number = -1
	_process_mute_state_change(game_manager, was_muted)

func on_turn_end(game_manager: GameManager) -> void:
	var was_muted := is_muted
	if not is_muted:
		return
	if mute_turns_remaining < 0:
		return
	if game_manager != null and game_manager.current_player == card_owner and game_manager.turn_number == _mute_applied_owner_turn_number:
		return
	if mute_turns_remaining > 0:
		mute_turns_remaining -= 1
	if mute_turns_remaining <= 0:
		is_muted = false
		mute_turns_remaining = 0
		_mute_applied_owner_turn_number = -1
	_process_mute_state_change(game_manager, was_muted)

func _process_mute_state_change(game_manager: GameManager, was_muted: bool) -> void:
	if was_muted == is_muted:
		return
	_was_muted_last_check = is_muted
	if is_muted:
		on_muted(game_manager)
	else:
		on_unmuted(game_manager)

func on_muted(_game_manager: GameManager) -> void:
	pass

func on_unmuted(_game_manager: GameManager) -> void:
	pass

func on_reveal(_game_manager: GameManager) -> void:
	pass

func reveal(game_manager: GameManager = null) -> void:
	var was_hidden: bool = is_face_down or is_stealth
	is_face_down = false
	is_stealth = false
	# Reveal triggers whenever a card becomes visible from a hidden state,
	# even if that same card was revealed earlier and later became hidden again.
	if was_hidden and game_manager != null:
		on_reveal(game_manager)

func has_type(type_name: String) -> bool:
	if type_name == "Physical":
		return is_physical_card()
	if type_name == "Magic" or type_name == "Magical":
		return is_magical_card()
	return type_name in card_types

func is_physical_card() -> bool:
	return card_type in [CardType.CREATURE, CardType.STRUCTURE, CardType.EQUIPMENT]

func is_magical_card() -> bool:
	return card_type in [CardType.SPELL, CardType.HEX, CardType.CHARM] or "Charm" in card_types

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

func reveal_from_stealth(game_manager: GameManager = null) -> void:
	if is_stealth:
		reveal(game_manager)

func reset_creature_action_state() -> void:
	has_acted_this_turn = false
	has_moved_this_turn = false
	has_attacked_this_turn = false
	creature_major_action_used = false
	creature_minor_actions_used = 0

func can_take_major_creature_action() -> bool:
	return not creature_major_action_used and creature_minor_actions_used < 2

func can_take_minor_creature_action() -> bool:
	return not creature_major_action_used and creature_minor_actions_used < 2

func spend_major_creature_action() -> void:
	creature_major_action_used = true
	has_acted_this_turn = true

func spend_minor_creature_action(marked_as_move: bool = false) -> void:
	creature_minor_actions_used += 1
	if marked_as_move:
		has_moved_this_turn = true
	if creature_minor_actions_used >= 2:
		has_acted_this_turn = true

func mark_attacked_this_turn() -> void:
	has_attacked_this_turn = true

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

func pay_costs(player: Player, game_manager: GameManager = null) -> bool:
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
						if game_manager != null:
							game_manager._send_to_graveyard_with_hook(card, false, false)
						else:
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
					if game_manager != null:
						game_manager._send_to_abyss_with_hook(card_to_banish)
					else:
						player.banish_card(card_to_banish)
					break
	
	return true
