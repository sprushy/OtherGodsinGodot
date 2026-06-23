extends PowerCard
class_name ImmortalTechniques

const ART_PATH := "res://images/card_art/powers/ImmortalTechniqueEdit.png"

func _init() -> void:
	super._init()
	card_name = "Immortal Techniques"
	culture = "Ancient"
	card_types = ["Power", "Cost Reduction"]
	mana_cost = 0
	discard_cost = 1
	ability_text = "Reduce the cost of spells and Ancient hexes by 1 mana whenever there is a friendly Mage on the field."
	art_path = ART_PATH

func on_unlock(_game_manager: GameManager) -> void:
	print(card_name + " unlocked.")

func get_cost_adjustment_entries(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	game_manager: GameManager,
	_metadata: Dictionary = {}
) -> Array[Dictionary]:
	if not _can_reduce_card(target_card, base_cost, cost_kind, game_manager):
		return []
	return [{
		"source": card_name,
		"source_card": self,
		"delta": -1,
	}]

func _can_reduce_card(
	target_card: Card,
	base_cost: int,
	cost_kind: String,
	_game_manager: GameManager
) -> bool:
	if not is_effectively_active():
		return false
	if target_card == null or base_cost <= 0:
		return false
	if cost_kind != Card.COST_KIND_HAND_PLAY:
		return false
	if target_card.card_owner != card_owner:
		return false
	if target_card.card_type == Card.CardType.SPELL:
		return _has_friendly_mage_on_field(_game_manager)
	if target_card.card_type == Card.CardType.HEX and target_card.culture == "Ancient":
		return _has_friendly_mage_on_field(_game_manager)
	return false

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var details := super.get_hover_detail_lines(viewer)
	if viewer != null and viewer != card_owner:
		return details
	details.append("Discount active." if _has_friendly_mage_on_field(_get_game_manager()) else "Needs a friendly Mage on the field.")
	return details

func _has_friendly_mage_on_field(game_manager: GameManager = null) -> bool:
	if card_owner == null:
		return false
	var resolved_game_manager := game_manager if game_manager != null else _get_game_manager()
	if resolved_game_manager != null:
		for card in resolved_game_manager.get_field_cards(card_owner):
			if _is_friendly_mage(card):
				return true
		return false
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _is_friendly_mage(card):
				return true
	return false

func _is_friendly_mage(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.has_type("Mage") \
		and card.get_controller() == card_owner

func _get_game_manager() -> GameManager:
	if card_owner == null:
		return null
	return card_owner.game_manager
