extends PowerCard
class_name AltarOfDreams

const UNLOCK_COST := 7
const ART_PATH := "res://images/card_art/powers/altar_of_dreams.jpg"

func _init() -> void:
	super._init()
	card_name = "Altar of Dreams"
	mana_cost = UNLOCK_COST
	culture = "Ancient"
	card_types = ["Power", "Cost Modification", "Creature"]
	ability_text = "Demon and Spirit sacrifice summon costs may be paid by [b]Void[/b]ing sleeping creatures from either side of the field."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func can_replace_sacrifice_cost(creature_to_summon: Card, game_manager: GameManager) -> bool:
	if is_face_down or creature_to_summon == null:
		return false
	if card_owner != game_manager.current_player:
		return false
	if creature_to_summon.card_owner != card_owner:
		return false
	if creature_to_summon.creature_sacrifice_cost <= 0:
		return false
	return _is_demon_or_spirit(creature_to_summon)

func get_valid_void_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card.card_type == Card.CardType.CREATURE and card.is_sleeping:
					valid_targets.append(card)
	return valid_targets

func has_enough_valid_void_targets(creature_to_summon: Card, game_manager: GameManager) -> bool:
	if not can_replace_sacrifice_cost(creature_to_summon, game_manager):
		return false
	return get_valid_void_targets(game_manager).size() >= creature_to_summon.creature_sacrifice_cost

func pay_replacement_cost(creature_to_summon: Card, targets: Array[Card], game_manager: GameManager) -> bool:
	if not can_replace_sacrifice_cost(creature_to_summon, game_manager):
		return false

	var required := creature_to_summon.creature_sacrifice_cost
	if targets.size() < required:
		return false

	for i in range(required):
		var target := targets[i]
		if target == null or target.card_type != Card.CardType.CREATURE or not target.is_sleeping:
			return false

	for i in range(required):
		var target := targets[i]
		game_manager.banish_card_with_hook(target)
		print("%s: Voided sleeping creature %s instead of paying a creature sacrifice cost." % [card_name, target.card_name])

	return true

func _is_demon_or_spirit(card: Card) -> bool:
	return card != null and (card.has_type("Demon") or card.has_type("Spirit"))
