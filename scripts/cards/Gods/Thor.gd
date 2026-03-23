extends BaseCard
class_name Thor

const PASSIVE_SOURCE := "Thor's Patron of Midguard"

func _init() -> void:
	card_name = "Thor"
	card_type = Card.CardType.CREATURE
	is_god = true
	card_types = ["God", "Divine Manifestation", "Human", "Warrior"]
	mana_cost = 0
	strength = 40
	resilience = 40
	speed = 3
	culture = "Norse"
	flavor_text = "Thunder echoes across Midgard wherever he walks."
	ability_text = "Patron of Midguard (Passive): Friendly Human Warriors gain +3 STR and +3 RES."
	art_path = "res://images/card_art/Thor.jpg"
	name_at_bottom = true
	artist = "Ricarrdo Zoppello"
	var paragon: String = "Paragon of Champions"
	var championscall: String = "Champion's Call"

func applies_to(card: Card) -> bool:
	return (
		card.card_type == Card.CardType.CREATURE
		and card != self
		and card.card_owner == card_owner
		and card.has_type("Human")
		and card.has_type("Warrior")
	)

func apply_passive_to_board() -> void:
	if card_owner == null:
		return
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if applies_to(card):
				card.clear_buffs_from(PASSIVE_SOURCE)
				card.add_buff(PASSIVE_SOURCE, 3, 3, 0)

func remove_passive_from_board() -> void:
	if card_owner == null:
		return
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			card.clear_buffs_from(PASSIVE_SOURCE)

func on_summon(game_manager: GameManager) -> void:
	apply_passive_to_board()
