# CardAction.gd
extends RefCounted
class_name CardAction

enum Type { ATTACK, SPELL, ABILITY, EVENT, CHARM }

var type: Type
var source_player: Player
var initial_priority_player: Player = null

# ATTACK fields
var attacker: Card
var united_front_partner: Card = null
var attack_speed_override: int = -1
var interceptor: Card   # may be null
var target              # Card or Player (original attack target)

# SPELL / ABILITY fields
var card: Card
var display_zone: Zone = null
var response_to: CardAction = null
var resolve_callback: Callable = Callable()
var event_name: String = ""
var event_speed: int = 0
var event_data: Dictionary = {}
var resolution_text: String = ""

func get_timing_speed() -> int:
	match type:
		Type.ATTACK:
			if attack_speed_override > 0:
				return attack_speed_override
			return attacker.get_effective_speed() if attacker != null else 0
		Type.SPELL, Type.ABILITY, Type.CHARM:
			if event_speed > 0:
				return event_speed
			return card.get_effective_speed() if card != null else 0
		Type.EVENT:
			if event_speed > 0:
				return event_speed
			return card.get_effective_speed() if card != null else 0
	return 0

func can_respond_with(response_card: Card) -> bool:
	return response_card.can_respond_to(card)

func resolve() -> void:
	pass
