extends PowerCard
class_name AltarOfDreams

const UNLOCK_COST := 7

func _init() -> void:
	super._init()
	card_name = "Altar of Dreams"
	mana_cost = UNLOCK_COST
	culture = "Ancient"
	card_types = ["Power", "Cost Modification", "Creature"]

	ability_text = "Demon and Spirit summoning costs which require creature sacrifice can be paid instead by voiding sleeping creatures from either side of the field."
	art_path = "res://images/card_art/altar_of_dreams.png"


func on_unlock(game_manager: GameManager) -> void:
	print(card_name + " unlocked.")


func can_replace_sacrifice_cost(creature_to_summon: Card) -> bool:
	if creature_to_summon == null:
		return false

	if not _is_demon_or_spirit(creature_to_summon):
		return false

	return creature_to_summon.requires_creature_sacrifice()


func get_valid_void_targets(game_manager: GameManager) -> Array:
	var valid_targets: Array = []

	for creature in game_manager.get_all_creatures_on_field():
		if creature != null and creature.is_sleeping():
			valid_targets.append(creature)

	return valid_targets


func pay_replacement_cost(creature_to_summon: Card, targets: Array, game_manager: GameManager) -> bool:
	if not can_replace_sacrifice_cost(creature_to_summon):
		return false

	var required_sacrifices: int = creature_to_summon.get_required_sacrifice_count()
	if targets.size() < required_sacrifices:
		return false

	for i in range(required_sacrifices):
		var target = targets[i]
		if target == null or not target.is_sleeping():
			return false

	for i in range(required_sacrifices):
		var target = targets[i]
		game_manager.void_card(target)
		print(card_name + ": Voided sleeping creature " + target.card_name + " instead of paying a sacrifice cost.")

	return true


func _is_demon_or_spirit(card: Card) -> bool:
	if card == null:
		return false

	return "Demon" in card.card_types or "Spirit" in card.card_types
