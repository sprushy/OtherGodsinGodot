extends StructureCard
class_name AnointingStatue

const CLEANSE_USES_PER_TURN := 1
const ART_PATH := "res://images/card_art/structures/anointing_statue.png"

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
	ability_text = "Once per turn, remove all status changes from a creature."
	culture = "Triskelion"
	art_path = ART_PATH

func can_activate(game_manager: GameManager, target: Card = null) -> bool:
	if game_manager == null:
		return false
	if card_owner != game_manager.current_player:
		return false
	if cleanse_uses_this_turn >= CLEANSE_USES_PER_TURN:
		return false
	if target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	return _has_any_effects(target)

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager, target):
		print("Anointing Statue: Cannot activate.")
		return
	cleanse_uses_this_turn += 1
	_remove_all_effects(target)
	print("Anointing Statue: Removed all status changes from " + target.card_name + ".")

func on_turn_upkeep(_game_manager: GameManager) -> void:
	cleanse_uses_this_turn = 0

func _has_any_effects(target: Card) -> bool:
	return not target.active_buffs.is_empty() or not target.active_statuses.is_empty()

func _remove_all_effects(target: Card) -> void:
	target.clear_all_effects()
