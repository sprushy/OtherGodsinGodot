extends HexCard
class_name VoidShield

func _init() -> void:
	super._init()
	card_name = "Void Shield"
	speed = 3
	mana_cost = 0
	ability_text = "When an opponent's creature attacks one of yours, [b]Void[/b] it."
	flavor_text = "What reaches for the living may be swallowed by the void."
	culture = "Ancient"
	card_types = ["Targeting"]
	art_path = "res://images/card_art/hexes/VoidShield.jpg"
	artist = "Ricarrdo Zoppello"
	targets = true

# Activates when an enemy creature attacks one of the hex owner's creatures,
# and the attacker's speed is no greater than this card's speed (3).
func can_activate(attacker: Card, defender: Card) -> bool:
	if attacker == null or defender == null:
		return false
	if attacker.card_type != Card.CardType.CREATURE:
		return false
	if defender.card_type != Card.CardType.CREATURE:
		return false
	if attacker.get_controller() == card_owner:
		return false
	if defender.get_controller() != card_owner:
		return false
	return attacker.get_effective_speed() <= get_effective_speed()

func get_affected_cards(attacker: Card, _defender: Card) -> Array[Card]:
	var affected: Array[Card] = []
	if attacker != null:
		affected.append(attacker)
	return affected

func on_activate(game_manager: GameManager, attacker: Card, _defender: Card) -> void:
	print("Void Shield activates! Voiding " + attacker.card_name + "!")
	game_manager.banish_card_with_hook(attacker)
	card_owner.move_card(self, card_owner.graveyard_zone)
