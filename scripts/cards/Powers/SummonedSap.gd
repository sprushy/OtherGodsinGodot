extends PowerCard
class_name SummonedSap

const UNLOCK_COST := 6
const PASSIVE_SOURCE := "Summoned Sap"
const SPEED_DEBUFF_EFFECT_TYPE := "summoned_sap_speed"
const ART_PATH := "res://images/card_art/powers/SummonedSapArt.jpg"

func _init() -> void:
	super._init()
	card_name = "Summoned Sap"
	culture = "Triskelion"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Aura"]
	ability_text = "[b]Aura[/b]: While you have a [b]Plant[/b], [b]Animal[/b], or [b]Hybrid[/b] on the field, other creatures get -1 SPD and use up their turn action if they switch stance."
	artist = "Mike Capprotti"
	art_path = ART_PATH

func on_unlock(game_manager: GameManager) -> void:
	_refresh_aura(game_manager)

func on_any_card_moved(game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	_refresh_aura(game_manager)

func on_global_turn_start(game_manager: GameManager, _starting_player: Player) -> void:
	_refresh_aura(game_manager)

func on_global_turn_end(game_manager: GameManager, _ending_player: Player) -> void:
	_refresh_aura(game_manager)

func on_removed(game_manager: GameManager) -> void:
	_clear_aura(game_manager)

func on_muted(game_manager: GameManager) -> void:
	_clear_aura(game_manager)

func on_unmuted(game_manager: GameManager) -> void:
	_refresh_aura(game_manager)

func on_any_creature_mode_changed(game_manager: GameManager, creature: Card, old_mode: Card.CreatureMode) -> void:
	if game_manager == null or creature == null:
		return
	if old_mode == creature.creature_mode:
		return
	if not _is_aura_live():
		return
	if not _is_affected_creature(creature):
		return
	creature.spend_major_creature_action()
	game_manager.note_player_feedback(
		"%s forces %s to use up its turn action after switching stance." % [
			card_name,
			creature.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	)

func _refresh_aura(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	_clear_aura(game_manager)
	if not _is_aura_live():
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_affected_creature(card):
					card.add_buff(PASSIVE_SOURCE, 0, 0, -1, self, card_owner, SPEED_DEBUFF_EFFECT_TYPE)

func _clear_aura(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card == null or card.card_type != Card.CardType.CREATURE:
					continue
				card.remove_buffs_from_source_card(self, SPEED_DEBUFF_EFFECT_TYPE)

func _is_aura_live() -> bool:
	return is_effectively_active() and _controller_has_nature_creature()

func _controller_has_nature_creature() -> bool:
	if card_owner == null:
		return false
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _is_nature_creature(card):
				return true
	return false

func _is_affected_creature(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and not _is_nature_creature(card)

func _is_nature_creature(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and (card.has_type("Plant") or card.has_type("Animal") or card.has_type("Hybrid"))
