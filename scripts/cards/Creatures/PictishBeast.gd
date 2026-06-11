extends CreatureCard
class_name PictishBeast

const MANA_PER_BEAST := 2

func _init() -> void:
	super._init()
	card_name = "Pictish Beast"
	card_types = ["Animal", "Cryptid", "Aqueous", "Triskelion Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 11
	strength = 10
	ability_text = "Mana Boon ([b]Reveal[/b]): Gain 2 mana for every \"Pictish Beast\" on your field or in your graveyard."
	flavor_text = ""
	culture = "Triskelion"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/PictishBeastEdit.png"

func on_reveal(game_manager: GameManager) -> void:
	if game_manager == null or abilities_suppressed():
		return
	var controller := get_controller()
	if controller == null:
		return
	if _count_mana_boon_targets(controller) <= 0:
		return
	game_manager.decision_requested.emit(controller, "reveal_effect", {
		"source_uid": uid,
		"queue_with_priority": true,
		"event_name": "pictish_beast_reveal",
		"resolve_method": "resolve_mana_boon",
	})

func resolve_mana_boon(game_manager: GameManager) -> String:
	if game_manager == null or abilities_suppressed():
		return ""
	var controller := get_controller()
	if controller == null:
		return ""
	var beast_count := _count_mana_boon_targets(controller)
	if beast_count <= 0:
		return ""

	var mana_before := controller.mana
	controller.gain_mana(beast_count * MANA_PER_BEAST)
	var mana_gained := controller.mana - mana_before
	if mana_gained > 0:
		return "%s reveals and gains %d mana from Mana Boon." % [card_name, mana_gained]
	return ""

func _count_mana_boon_targets(controller: Player) -> int:
	var total := 0
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if _is_pictish_beast(card):
				total += 1
	for card in controller.graveyard_zone.cards:
		if _is_pictish_beast(card):
			total += 1
	return total

func _is_pictish_beast(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.card_name == card_name
