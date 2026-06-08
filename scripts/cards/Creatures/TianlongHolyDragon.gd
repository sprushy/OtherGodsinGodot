extends CreatureCard
class_name TianlongHolyDragon

const ART_PATH := "res://images/card_art/creatures/TianLongEdit.png"
const ALT_ART_PATH := "res://images/card_art/creatures/tianlong_holy_dragon_alt.jpg"

func _init() -> void:
	super._init()
	card_name = "Tianlong, Holy Dragon"
	card_types = ["Dragon", "Long", "Aerial", "Tian Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 2
	resilience = 25
	strength = 28
	ability_text = "[b]Heaven's Guard[/b] ([b]Passive[/b]): This card can intercept any attack on your god or your higher-level Dragons regardless of stance or speed."
	flavor_text = ""
	culture = "Tian"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]

func can_special_intercept(_game_manager: GameManager, _attacker: Card, protected_target) -> bool:
	if not _heavens_guard_is_active():
		return false
	if _protects_controller_god(protected_target):
		return true
	return _protects_higher_level_dragon(protected_target)

func _heavens_guard_is_active() -> bool:
	return current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth \
		and not is_prepared \
		and not abilities_suppressed()

func _protects_controller_god(protected_target) -> bool:
	var controller := get_controller()
	if controller == null:
		return false
	if protected_target is Player:
		return protected_target == controller
	var target_card := protected_target as Card
	return target_card != null and target_card.is_god and target_card.get_controller() == controller

func _protects_higher_level_dragon(protected_target) -> bool:
	var target_card := protected_target as Card
	if target_card == null:
		return false
	if target_card.get_controller() != get_controller():
		return false
	if target_card.is_god or target_card.card_type != Card.CardType.CREATURE:
		return false
	return target_card.has_type("Dragon") and target_card.get_effective_level() > get_effective_level()
