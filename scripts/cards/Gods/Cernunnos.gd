extends GodCard
class_name Cernunnos

const PASSIVE_SOURCE := "Cernunnos Master of the Deep Wood"
const BUFF_STRENGTH := 2
const BUFF_SPEED := 2

func _init() -> void:
	super._init()
	card_name = "Cernunnos"
	card_types = ["Nature", "Sex", "Hunt"]
	mana_cost = 0
	culture = "Triskelion"
	flavor_text = ""
	ability_text = "Master of the Deep Wood ([b]Passive[/b]): Animals level 5 and above gain +2 SPD and +2 STR. Triskelion Animals cannot be [b]Enslaved[/b]."
	art_path = "res://scripts/cards/Gods/CernunnosEdit2.png"
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func applies_to(card: Card) -> bool:
	return (
		not is_muted
		and card != null
		and card.card_type == Card.CardType.CREATURE
		and card.has_type("Animal")
		and card.get_effective_level() >= 5
		and card.current_zone != null
		and card.current_zone.is_board_zone()
	)

func prevents_enslave(creature: Card) -> bool:
	return (
		not is_muted
		and creature != null
		and creature.card_type == Card.CardType.CREATURE
		and creature.has_type("Animal")
		and creature.culture == "Triskelion"
		and creature.current_zone != null
		and creature.current_zone.is_board_zone()
	)

func apply_passive_to_board(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	remove_passive_from_board(game_manager)
	if is_muted:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if applies_to(card):
					card.add_buff(PASSIVE_SOURCE, BUFF_STRENGTH, 0, BUFF_SPEED, self, card_owner, "passive")

func remove_passive_from_board(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				card.clear_buffs_from(PASSIVE_SOURCE)

func on_summon(game_manager: GameManager) -> void:
	apply_passive_to_board(game_manager)

func on_turn_start(game_manager: GameManager) -> void:
	apply_passive_to_board(game_manager)

func on_removed(game_manager: GameManager) -> void:
	remove_passive_from_board(game_manager)

func on_muted(game_manager: GameManager) -> void:
	remove_passive_from_board(game_manager)

func on_unmuted(game_manager: GameManager) -> void:
	apply_passive_to_board(game_manager)

func on_any_card_moved(game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	apply_passive_to_board(game_manager)
