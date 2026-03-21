# CardAction.gd
extends RefCounted
class_name CardAction

enum Type { ATTACK, SPELL, ABILITY }

var type: Type
var source_player: Player

# ATTACK fields
var attacker: Card
var interceptor: Card   # may be null
var target              # Card or Player (original attack target)

# SPELL / ABILITY fields
var card: Card

func can_respond_with(response_card: Card) -> bool:
	return response_card.can_respond_to(card)

func resolve() -> void:
	pass
