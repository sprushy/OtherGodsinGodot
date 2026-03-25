extends PowerCard
class_name AdvancedBuildingTechniques

const UNLOCK_COST := 4
const RESILIENCE_PER_MANA := 6
const ART_PATH := "res://images/card_art/powers/lighting_toned.png"

func _init() -> void:
	super._init()
	card_name = "Advanced Building Techniques"
	mana_cost = UNLOCK_COST
	card_types = ["Ward", "Followers"]
	culture = "Neutral"
	ability_text = "[b]Unlock[/b] (4): Ward - Followers - When you play a structure, you may pay mana to give it +6 Res per mana."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func can_offer_structure_bonus(structure: Card, game_manager: GameManager) -> bool:
	if is_face_down or structure == null:
		return false
	if card_owner != game_manager.current_player:
		return false
	if structure.card_owner != card_owner:
		return false
	return card_owner.mana > 0

func get_max_structure_bonus_mana(structure: Card, game_manager: GameManager) -> int:
	if not can_offer_structure_bonus(structure, game_manager):
		return 0
	return card_owner.mana

func apply_structure_bonus(structure: Card, mana_to_spend: int, game_manager: GameManager) -> int:
	var max_mana := get_max_structure_bonus_mana(structure, game_manager)
	mana_to_spend = clampi(mana_to_spend, 0, max_mana)
	if mana_to_spend <= 0:
		return 0

	card_owner.spend_mana(mana_to_spend)
	var resilience_gain := mana_to_spend * RESILIENCE_PER_MANA
	structure.add_buff(card_name, 0, resilience_gain, 0, self, card_owner, "power_buff")

	print("%s: Increased %s Res by %d (spent %d mana)." % [
		card_name,
		structure.card_name,
		resilience_gain,
		mana_to_spend,
	])
	return resilience_gain
