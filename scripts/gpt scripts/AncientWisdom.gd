extends PowerCard
class_name AncientWisdom

const UNLOCK_COST := 4
const MAGE_STR_BONUS := 5
const BUFF_DURATION_TURNS := 2 # Current turn + next turn

var active_buffs: Array = []

func _init() -> void:
	super._init()
	card_name = "Ancient Wisdom"
	mana_cost = UNLOCK_COST
	culture = "Ancient"
	card_types = ["Power", "Class Buff", "Mage"]

	ability_text = "Any turn a spell is played, friendly Mages gain 5 Str until the end of the next turn."
	art_path = "res://images/card_art/ancient_wisdom.png"


func on_unlock(game_manager: GameManager) -> void:
	print(card_name + " unlocked.")


func on_spell_played(player, spell_card: Card, game_manager: GameManager) -> void:
	if player == null or game_manager == null:
		return

	var friendly_mages = _get_friendly_mages(player, game_manager)

	for mage in friendly_mages:
		if mage == null:
			continue

		_apply_strength_bonus(mage, MAGE_STR_BONUS)

		active_buffs.append({
			"creature": mage,
			"remaining_turns": BUFF_DURATION_TURNS
		})

		print(card_name + ": " + mage.card_name + " gains " + str(MAGE_STR_BONUS) + " Str until the end of the next turn.")


func on_turn_end(player, game_manager: GameManager) -> void:
	if active_buffs.is_empty():
		return

	for i in range(active_buffs.size() - 1, -1, -1):
		active_buffs[i]["remaining_turns"] -= 1

		if active_buffs[i]["remaining_turns"] <= 0:
			var creature = active_buffs[i]["creature"]
			if creature != null:
				_remove_strength_bonus(creature, MAGE_STR_BONUS)
				print(card_name + ": " + creature.card_name + " loses " + str(MAGE_STR_BONUS) + " Str.")
			active_buffs.remove_at(i)


func _get_friendly_mages(player, game_manager: GameManager) -> Array:
	var result: Array = []

	for creature in game_manager.get_all_creatures_on_field():
		if creature == null:
			continue
		if creature.card_owner != player:
			continue
		if "Mage" in creature.card_types:
			result.append(creature)

	return result


func _apply_strength_bonus(creature: Card, amount: int) -> void:
	if creature.has_method("modify_strength"):
		creature.modify_strength(amount)
	elif "current_strength" in creature:
		creature.current_strength += amount
	elif "strength" in creature:
		creature.strength += amount


func _remove_strength_bonus(creature: Card, amount: int) -> void:
	if creature.has_method("modify_strength"):
		creature.modify_strength(-amount)
	elif "current_strength" in creature:
		creature.current_strength -= amount
	elif "strength" in creature:
		creature.strength -= amount
