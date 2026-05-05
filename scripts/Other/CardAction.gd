# CardAction.gd
extends RefCounted
class_name CardAction

enum Type { ATTACK, SPELL, ABILITY, EVENT, CHARM }

var type: Type
var source_player: Player
var initial_priority_player: Player = null

# Common fields
var card: Card
var target              # Card or Player or Zone
var resolve_callback: Callable = Callable()
var resolution_text: String = ""

# ATTACK specific
var attacker: Card
var united_front_partner: Card = null
var attack_speed_override: int = -1
var interceptor: Card   # may be null
var halve_follower_damage: bool = false

# SPELL / ABILITY / EVENT specific
var display_zone: Zone = null
var response_to: CardAction = null
var event_name: String = ""
var event_speed: int = 0
var event_data: Dictionary = {}

func get_timing_speed() -> int:
	match type:
		Type.ATTACK:
			if attack_speed_override > 0:
				return attack_speed_override
			return attacker.get_effective_speed() if attacker != null else 0
		Type.SPELL, Type.ABILITY, Type.CHARM, Type.EVENT:
			if event_speed > 0:
				return event_speed
			return card.get_effective_speed() if card != null else 0
	return 0

func can_respond_with(response_card: Card) -> bool:
	return response_card.can_respond_to(card)

func to_dict(game_manager: GameManager) -> Dictionary:
	var dict := {
		"type": type,
		"source_player_index": -1,
		"initial_priority_player_index": -1,
		"card_uid": card.get("uid") if card != null else "",
		"target_data": _serialize_target_value(target, game_manager),
		"target_uid": "",
		"target_player_index": -1,
		"target_is_player": false,
		"resolution_text": resolution_text,
		# Attack specific
		"attacker_uid": attacker.get("uid") if attacker != null else "",
		"united_front_partner_uid": united_front_partner.get("uid") if united_front_partner != null else "",
		"attack_speed_override": attack_speed_override,
		"interceptor_uid": interceptor.get("uid") if interceptor != null else "",
		"halve_follower_damage": halve_follower_damage,
		# Event specific
		"event_name": event_name,
		"event_speed": event_speed,
		"event_data": GameState.sanitize_network_value(event_data, game_manager),
		"display_zone": _zone_to_dict(display_zone, game_manager)
	}
	
	if source_player != null:
		dict["source_player_index"] = source_player.get_index(game_manager)
	if initial_priority_player != null:
		dict["initial_priority_player_index"] = initial_priority_player.get_index(game_manager)
		
	if target != null:
		if target is Card:
			dict["target_uid"] = target.get("uid")
		elif target is Player:
			dict["target_player_index"] = target.get_index(game_manager)
			dict["target_is_player"] = true
			
	return dict

static func from_dict(dict: Dictionary, game_manager: GameManager) -> CardAction:
	var action = CardAction.new()
	action.type = int(dict.get("type", Type.EVENT)) as Type
	
	var src_idx = dict.get("source_player_index", -1)
	if src_idx >= 0 and src_idx < game_manager.players.size():
		action.source_player = game_manager.players[src_idx]
		
	var prio_idx = dict.get("initial_priority_player_index", -1)
	if prio_idx >= 0 and prio_idx < game_manager.players.size():
		action.initial_priority_player = game_manager.players[prio_idx]
		
	action.card = game_manager.get_card_by_uid(dict.get("card_uid", ""))
	action.resolution_text = dict.get("resolution_text", "")
	
	# Resolve target
	action.target = _deserialize_target_value(dict.get("target_data", null), game_manager)
	if action.target != null:
		pass
	elif dict.get("target_is_player", false):
		var target_idx = dict.get("target_player_index", -1)
		if target_idx >= 0 and target_idx < game_manager.players.size():
			action.target = game_manager.players[target_idx]
	else:
		action.target = game_manager.get_card_by_uid(dict.get("target_uid", ""))
		
	# Attack specific
	action.attacker = game_manager.get_card_by_uid(dict.get("attacker_uid", ""))
	action.united_front_partner = game_manager.get_card_by_uid(dict.get("united_front_partner_uid", ""))
	action.attack_speed_override = dict.get("attack_speed_override", -1)
	action.interceptor = game_manager.get_card_by_uid(dict.get("interceptor_uid", ""))
	action.halve_follower_damage = bool(dict.get("halve_follower_damage", false))
	
	# Event specific
	action.event_name = dict.get("event_name", "")
	action.event_speed = dict.get("event_speed", 0)
	action.event_data = dict.get("event_data", {})
	action.display_zone = _dict_to_zone(dict.get("display_zone", {}), game_manager)
	
	return action

static func _zone_to_dict(zone: Zone, game_manager: GameManager) -> Dictionary:
	if zone == null or zone.zone_owner == null or game_manager == null:
		return {}
	return {
		"player_index": game_manager.players.find(zone.zone_owner),
		"zone_type": zone.zone_type,
		"zone_index": zone.zone_index,
	}

static func _dict_to_zone(zone_dict: Dictionary, game_manager: GameManager) -> Zone:
	if zone_dict.is_empty() or game_manager == null:
		return null
	var player_idx := int(zone_dict.get("player_index", -1))
	if player_idx < 0 or player_idx >= game_manager.players.size():
		return null
	var player := game_manager.players[player_idx]
	var zone_idx := int(zone_dict.get("zone_index", 0))
	match int(zone_dict.get("zone_type", -1)):
		Zone.ZoneType.HAND:
			return player.hand_zone
		Zone.ZoneType.DECK:
			return player.deck_zone
		Zone.ZoneType.GRAVEYARD:
			return player.graveyard_zone
		Zone.ZoneType.ABYSS:
			return player.abyss_zone
		Zone.ZoneType.GOD_SLOT:
			return player.god_zone
		Zone.ZoneType.POWER_SLOT:
			return player.power_zones[zone_idx] if zone_idx >= 0 and zone_idx < player.power_zones.size() else null
		Zone.ZoneType.FRONTLINE:
			return player.frontline_zones[zone_idx] if zone_idx >= 0 and zone_idx < player.frontline_zones.size() else null
		Zone.ZoneType.RESERVE:
			return player.reserve_zones[zone_idx] if zone_idx >= 0 and zone_idx < player.reserve_zones.size() else null
	return null

static func _serialize_target_value(value, game_manager: GameManager):
	if value == null:
		return null
	if value is Card:
		return {
			"kind": "card",
			"uid": value.get("uid") if "uid" in value else "",
		}
	if value is Player:
		return {
			"kind": "player",
			"player_index": value.get_index(game_manager),
		}
	if value is Zone:
		return {
			"kind": "zone",
			"zone": _zone_to_dict(value as Zone, game_manager),
		}
	if value is Array:
		var items: Array = []
		for entry in value:
			items.append(_serialize_target_value(entry, game_manager))
		return {
			"kind": "array",
			"items": items,
		}
	if value is Dictionary:
		var values := {}
		for key in value.keys():
			values[key] = _serialize_target_value(value[key], game_manager)
		return {
			"kind": "dictionary",
			"values": values,
		}
	if value is Object:
		return null
	return {
		"kind": "scalar",
		"value": value,
	}

static func _deserialize_target_value(data, game_manager: GameManager):
	if data == null:
		return null
	if data is Dictionary:
		var kind := str(data.get("kind", "")).strip_edges()
		match kind:
			"card":
				return game_manager.get_card_by_uid(str(data.get("uid", ""))) if game_manager != null else null
			"player":
				var player_idx := int(data.get("player_index", -1))
				if game_manager != null and player_idx >= 0 and player_idx < game_manager.players.size():
					return game_manager.players[player_idx]
				return null
			"zone":
				return _dict_to_zone(data.get("zone", {}), game_manager)
			"array":
				var items: Array = []
				for entry in data.get("items", []):
					items.append(_deserialize_target_value(entry, game_manager))
				return items
			"dictionary":
				var values: Dictionary = {}
				var raw_values: Dictionary = data.get("values", {})
				for key in raw_values.keys():
					values[key] = _deserialize_target_value(raw_values[key], game_manager)
				return values
			"scalar":
				return data.get("value", null)
	return data

# New virtual method for Phase 2
func resolve(_match_manager: MatchManager) -> void:
	# To be overridden by subclasses
	if resolve_callback.is_valid():
		resolve_callback.call()
