extends CreatureCard
class_name Skoll

const ART_PATH := "res://images/card_art/creatures/skoll.jpg"
const SUMMON_TAX_AMOUNT := 2

func _init() -> void:
	super._init()
	card_name = "Skoll"
	card_types = ["Animal", "Lupine", "Aerial", "Norse Creature"]
	level = 4
	mana_cost = 0
	sacrifice_cost = 1
	speed = 2
	resilience = 29
	strength = 30
	ability_text = "Sun Hunt ([b]Upkeep[/b]): You may skip your other upkeep options to summon this from your hand without paying its cost. Until end of turn, all other summons cost 2 more."
	culture = "Norse"
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func can_use_upkeep_summon(game_manager: GameManager) -> bool:
	if game_manager == null or card_owner == null:
		return false
	if game_manager.current_player != card_owner:
		return false
	if current_zone != card_owner.hand_zone:
		return false
	if _get_open_summon_zones().is_empty():
		return false
	return true

func apply_upkeep_summon_tax(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null:
		return
	game_manager.add_temporary_summon_cost_modifier(card_owner, SUMMON_TAX_AMOUNT, self, self)

func _get_open_summon_zones() -> Array[Zone]:
	var open_zones: Array[Zone] = []
	if card_owner == null:
		return open_zones
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		if zone.cards.is_empty():
			open_zones.append(zone)
	return open_zones
