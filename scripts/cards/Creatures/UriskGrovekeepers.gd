extends CreatureCard
class_name UriskGrovekeepers

const ART_PATH := "res://images/card_art/creatures/UriskGrovekeepersEdit.png"
const FOREST_WARD_INTERCEPT_SPEED_BONUS := 1
const FOREST_WARD_REACH_BONUS := 1

func _init() -> void:
	super._init()
	card_name = "Urisk Grovekeepers"
	card_types = ["Hybrid", "Satyr", "Warrior", "Triskelion Creature"]
	level = 5
	mana_cost = 4
	sacrifice_cost = 0
	speed = 2
	resilience = 30
	strength = 28
	ability_text = "[b]Forest Ward[/b] ([b]Passive[/b]): Can intercept in aggressive stance for Animal, Plant, and Nature cards with reach 2, and gets +1 SPD while intercepting for those cards."
	flavor_text = ""
	culture = "Triskelion"
	artist = "Mike Capprotti via TgcMaker"
	art_path = ART_PATH

func get_intercept_reach_bonus(
	_game_manager: GameManager = null,
	_attacker: Card = null,
	protected_target = null
) -> int:
	if _forest_ward_applies_to_target(protected_target):
		return FOREST_WARD_REACH_BONUS
	return 0

func get_intercept_speed_bonus_against_attacker(
	_game_manager: GameManager,
	_attacker: Card,
	protected_target = null
) -> int:
	if _forest_ward_applies_to_target(protected_target):
		return FOREST_WARD_INTERCEPT_SPEED_BONUS
	return 0

func _forest_ward_applies_to_target(protected_target) -> bool:
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
