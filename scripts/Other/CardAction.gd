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
		"event_data": event_data
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
	if dict.get("target_is_player", false):
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
	
	return action

# New virtual method for Phase 2
func resolve(_match_manager: MatchManager) -> void:
	# To be overridden by subclasses
	if resolve_callback.is_valid():
		resolve_callback.call()
