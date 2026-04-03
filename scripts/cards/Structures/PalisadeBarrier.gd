extends StructureCard
class_name PalisadeBarrier

const ART_PATH := "res://scripts/cards/Charms/PalisadeArtEdit.png"

func _init() -> void:
	super._init()
	card_name = "Palisade"
	card_types = ["Construct", "Fortification"]
	level = 3
	mana_cost = 0
	resilience = 25
	speed = 0
	strength = 0
	sacrifice_cost = 0
	is_legendary = false
	is_token = true
	flavor_text = ""
	ability_text = "Cards in the same lane behind this card cannot be attacked except by Aerial creatures."
	culture = "Neutral"
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func blocks_attack_on_target(_game_manager: GameManager, attacker: Card, defender: Card, allied_attackers: Array = []) -> bool:
	if not _is_active_frontline_barrier():
		return false
	if not _is_target_protected(defender):
		return false
	return not _all_attackers_are_aerial(attacker, allied_attackers)

func _is_active_frontline_barrier() -> bool:
	return current_zone != null \
		and current_zone.is_board_zone() \
		and current_zone.zone_type == Zone.ZoneType.FRONTLINE \
		and not is_face_down \
		and not abilities_suppressed()

func _is_target_protected(defender: Card) -> bool:
	if defender == null:
		return false
	if defender.current_zone == null or not defender.current_zone.is_board_zone():
		return false
	if defender.current_zone.zone_type != Zone.ZoneType.RESERVE:
		return false
	if defender.current_zone.zone_index != current_zone.zone_index:
		return false
	return defender.get_controller() == get_controller()

func _all_attackers_are_aerial(attacker: Card, allied_attackers: Array) -> bool:
	if attacker == null or not attacker.has_type("Aerial"):
		return false
	for ally in allied_attackers:
		var allied_attacker := ally as Card
		if allied_attacker == null:
			continue
		if allied_attacker.current_zone == null or not allied_attacker.current_zone.is_board_zone():
			continue
		if not allied_attacker.has_type("Aerial"):
			return false
	return true
