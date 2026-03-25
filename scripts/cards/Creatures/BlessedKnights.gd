extends CreatureCard
class_name BlessedKnights

const BLESSED_WARD_STATUS := "blessed_ward"

func _init() -> void:
	super._init()
	card_name = "Blessed Knights"
	card_types = ["Human", "Warrior", "Knight", "Horde"]
	level = 1
	mana_cost = 1
	speed = 1
	resilience = 13
	strength = 15
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	ability_text = "Blessed Ward (impact): This turn this card and cards which share its name are immune to your choice of hexes, creature abilities, or powers."
	flavor_text = ""
	culture = "Triskelion"
	artist = "Mike Capprotti via TgMaker"
	art_path = "res://images/card_art/creatures/blessed_knights_final.png"

func get_blessed_ward_options() -> Array[String]:
	return ["hexes", "creature_abilities", "powers"]

func get_blessed_ward_label(ward_kind: String) -> String:
	match ward_kind:
		"hexes":
			return "Hexes"
		"creature_abilities":
			return "Creature Abilities"
		"powers":
			return "Powers"
	return ward_kind.capitalize()

func apply_blessed_ward(game_manager: GameManager, ward_kind: String) -> void:
	if game_manager == null:
		return
	var controller := get_controller()
	if controller == null:
		return
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if card.card_name != card_name:
				continue
			card.remove_status_effects_from_source_card(self, BLESSED_WARD_STATUS)
			card.add_status_effect(
				BLESSED_WARD_STATUS,
				"Blessed Ward",
				self,
				controller,
				{
					"ward_kind": ward_kind,
					"expires_turn": game_manager.turn_number,
				}
			)
