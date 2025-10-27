# CardAction.gd
extends RefCounted
class_name CardAction

var card: Card
var source_player: Player
var target

func _init(c: Card, p: Player, t = null) -> void:
	card = c
	source_player = p
	target = t

func can_respond_with(response_card: Card) -> bool:
	return response_card.can_respond_to(card)

func resolve() -> void:
	pass
