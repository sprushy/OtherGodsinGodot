extends StructureCard
class_name AnointingStatue

const CLEANSE_USES_PER_TURN := 1

var cleanse_uses_this_turn := 0

func _init() -> void:
	super._init()
	card_name = "Anointing Statue"
	card_types = ["Triskelion", "Altar"]
	level = 2
	mana_cost = 0
	resilience = 25
	speed = 0
	strength = 0
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	ability_text = "Once per turn you may remove all effects your opponent has placed on a creature."
	culture = "Triskelion"
	art_path = "res://images/card_art/anointing_statue.jpg"


func can_activate(game_manager: GameManager, target: Card = null) -> bool:
	if game_manager == null:
		return false
	if card_owner != game_manager.current_player:
		return false
	if cleanse_uses_this_turn >= CLEANSE_USES_PER_TURN:
		return false
	if target == null:
		return false
	if not _is_valid_creature_target(target):
		return false

	return _has_opponent_effects(target, game_manager)


func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager, target):
		print("Anointing Statue: Cannot activate.")
		return

	cleanse_uses_this_turn += 1
	_remove_opponent_effects(target, game_manager)
	print("Anointing Statue: Removed all opposing effects from " + target.card_name + ".")


func on_turn_start(game_manager: GameManager) -> void:
	cleanse_uses_this_turn = 0


func _is_valid_creature_target(target: Card) -> bool:
	if target == null:
		return false

	if target is CreatureCard:
		return true

	if "Creature" in target.card_types:
		return true

	return false


func _has_opponent_effects(target: Card, game_manager: GameManager) -> bool:
	var opponent = game_manager.get_opponent(card_owner)

	if target.has_method("has_effects_from_player"):
		return target.has_effects_from_player(opponent)

	if "buffs" in target:
		for buff in target.buffs:
			if typeof(buff) == TYPE_DICTIONARY and buff.has("source_owner") and buff["source_owner"] == opponent:
				return true

	if "debuffs" in target:
		for debuff in target.debuffs:
			if typeof(debuff) == TYPE_DICTIONARY and debuff.has("source_owner") and debuff["source_owner"] == opponent:
				return true

	return false


func _remove_opponent_effects(target: Card, game_manager: GameManager) -> void:
	var opponent = game_manager.get_opponent(card_owner)

	if target.has_method("remove_effects_from_player"):
		target.remove_effects_from_player(opponent)
		return

	if "buffs" in target:
		for i in range(target.buffs.size() - 1, -1, -1):
			var buff = target.buffs[i]
			if typeof(buff) == TYPE_DICTIONARY and buff.has("source_owner") and buff["source_owner"] == opponent:
				target.buffs.remove_at(i)

	if "debuffs" in target:
		for i in range(target.debuffs.size() - 1, -1, -1):
			var debuff = target.debuffs[i]
			if typeof(debuff) == TYPE_DICTIONARY and debuff.has("source_owner") and debuff["source_owner"] == opponent:
				target.debuffs.remove_at(i)

	if target.has_method("recalculate_stats"):
		target.recalculate_stats()
