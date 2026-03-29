extends GodCard
class_name Thor

const PASSIVE_SOURCE := "Thor's Patron of Midguard"

func _init() -> void:
	super._init()
	card_name = "Thor"
	card_types = ["God", "Divine Manifestation", "Human", "Warrior"]
	mana_cost = 0
	culture = "Norse"
	flavor_text = "Thunder echoes across Midgard wherever he walks."
	ability_text = "Patron of Midguard (Passive): Friendly Human Warriors gain +3 STR and +3 RES."
	art_path = "res://images/card_art/gods/ThorAIedit.png"
	name_at_bottom = true
	artist = "Ricarrdo Zoppello"
func applies_to(card: Card) -> bool:
	return (
		not is_muted
		and
		card.card_type == Card.CardType.CREATURE
		and card != self
		and card.card_owner == card_owner
		and card.has_type("Human")
		and card.has_type("Warrior")
	)

func apply_passive_to_board() -> void:
	if card_owner == null:
		return
	remove_passive_from_board()
	if is_muted:
		return
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if applies_to(card):
				card.add_buff(PASSIVE_SOURCE, 3, 3, 0, self, card_owner, "passive")

func remove_passive_from_board() -> void:
	if card_owner == null:
		return
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			card.clear_buffs_from(PASSIVE_SOURCE)

func on_summon(_game_manager: GameManager) -> void:
	apply_passive_to_board()

func on_turn_start(_game_manager: GameManager) -> void:
	apply_passive_to_board()

func on_removed(_game_manager: GameManager) -> void:
	remove_passive_from_board()

func on_muted(_game_manager: GameManager) -> void:
	remove_passive_from_board()

func on_unmuted(_game_manager: GameManager) -> void:
	apply_passive_to_board()

func on_any_card_moved(_game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	apply_passive_to_board()
