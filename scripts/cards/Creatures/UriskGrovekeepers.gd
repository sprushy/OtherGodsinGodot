extends CreatureCard
class_name UriskGrovekeepers

const ART_PATH := "res://images/card_art/creatures/UriskGrovekeepersEdit.png"

func _init() -> void:
	super._init()
	card_name = "Urisk Grovekeepers"
	card_types = ["Hybrid", "Satyr", "Warrior"]
	level = 5
	mana_cost = 4
	sacrifice_cost = 0
	speed = 2
	resilience = 30
	strength = 28
	ability_text = "[b]Forest Ward[/b] ([b]Passive[/b]): For your Animal, Plant, or Nature cards, Urisk Grovekeepers have [b]Reach[/b] and can intercept regardless of speed."
	flavor_text = ""
	culture = "Triskelion"
	artist = "Mike Capprotti via TgcMaker"
	art_path = ART_PATH

func can_intercept_regardless_of_speed(protected_target) -> bool:
	return has_reach(protected_target) or super.can_intercept_regardless_of_speed(protected_target)

func has_reach(protected_target) -> bool:
	if not _forest_ward_is_active():
		return false
	var target_card := _resolve_forest_ward_target(protected_target)
	if target_card == null:
		return false
	if target_card.get_controller() != get_controller():
		return false
	return target_card.has_type("Animal") or target_card.has_type("Plant") or target_card.has_type("Nature")

func _resolve_forest_ward_target(protected_target) -> Card:
	var target_card := protected_target as Card
	if target_card == null:
		return null
	if target_card.card_type == Card.CardType.EQUIPMENT and target_card.equipped_on != null:
		return target_card.equipped_on
	return target_card

func _forest_ward_is_active() -> bool:
	return current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth \
		and not is_prepared \
		and not abilities_suppressed()
