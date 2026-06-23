extends CharmCard
class_name Storm

const STORM_AERIAL_STATUS := "storm_aerial_loss"

func _init() -> void:
	super._init()
	card_name = "Storm"
	culture = "Neutral"
	card_types = ["Charm", "Weather", "Permanent"]
	level = 2
	mana_cost = 0
	speed = 3
	sacrifice_cost = 0
	flavor_text = ""
	artist = "CC0"
	art_path = "res://images/card_art/charms/StormEdit.png"
	ability_text = "Destroy any face-up [b]Weather[/b] charms. All [b]Aerial[/b] creatures lose that classification and get -7 STR and -2 SPD. All non-passive creature abilities are silenced while this remains face-up."

func goes_to_graveyard_after_use() -> bool:
	return false

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return
	_destroy_face_up_weather_charms(game_manager)
	_refresh_storm_field(game_manager)
	game_manager.note_player_feedback(card_name + " lashes the battlefield with violent winds.")

func on_any_card_moved(game_manager: GameManager, moved_card: Card, from_zone: Zone, to_zone: Zone) -> void:
	if game_manager == null:
		return
	if moved_card == null or moved_card.card_type != Card.CardType.CREATURE:
		return
	if from_zone != null and from_zone.is_board_zone() and (to_zone == null or not to_zone.is_board_zone()):
		_remove_storm_effects(moved_card)
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if not _is_active():
		return
	if to_zone != null and to_zone.is_board_zone():
		_refresh_storm_field(game_manager)

func on_removed(game_manager: GameManager) -> void:
	_clear_storm_field(game_manager)

func on_muted(game_manager: GameManager) -> void:
	_clear_storm_field(game_manager)

func on_unmuted(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	if _is_active():
		_refresh_storm_field(game_manager)

func _destroy_face_up_weather_charms(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var doomed_cards: Array[Card] = []
	for player in game_manager.players:
		for card in game_manager.get_field_cards(player):
			if card == null or card == self:
				continue
			if not (card is CharmCard):
				continue
			if card.is_face_down or not card.has_type("Weather"):
				continue
			doomed_cards.append(card)
	game_manager.request_send_cards_to_graveyard(doomed_cards)

func _refresh_storm_field(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for creature in game_manager.get_field_cards():
		if creature == null or creature.card_type != Card.CardType.CREATURE:
			continue
		if _is_active():
			if _weather_effect_is_blocked(creature):
				_remove_storm_effects(creature)
				continue
			_apply_storm_silence(creature)
			if _is_aerial_under_storm(creature):
				_apply_storm_aerial_loss(creature)
			else:
				_remove_storm_aerial_loss(creature)
		else:
			_remove_storm_effects(creature)

func _clear_storm_field(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for creature in game_manager.get_field_cards():
		if creature == null or creature.card_type != Card.CardType.CREATURE:
			continue
		_remove_storm_effects(creature)

func _apply_storm_silence(creature: Card) -> void:
	if creature == null:
		return
	creature.remove_status_effects_from_source_card(self, Card.ABILITY_NEGATED_STATUS)
	if not _has_non_passive_creature_ability(creature):
		return
	creature.add_status_effect(Card.ABILITY_NEGATED_STATUS, card_name, self, card_owner)

func _apply_storm_aerial_loss(creature: Card) -> void:
	if creature == null:
		return
	creature.remove_buffs_from_source_card(self, "storm_aerial")
	creature.remove_status_effects_from_source_card(self, STORM_AERIAL_STATUS)
	creature.add_buff(card_name, -7, 0, -2, self, card_owner, "storm_aerial")
	creature.add_status_effect(
		STORM_AERIAL_STATUS,
		card_name,
		self,
		card_owner,
		{"suppressed_types": ["Aerial"]}
	)

func _remove_storm_aerial_loss(creature: Card) -> void:
	if creature == null:
		return
	creature.remove_buffs_from_source_card(self, "storm_aerial")
	creature.remove_status_effects_from_source_card(self, STORM_AERIAL_STATUS)

func _remove_storm_effects(creature: Card) -> void:
	if creature == null:
		return
	creature.remove_status_effects_from_source_card(self, Card.ABILITY_NEGATED_STATUS)
	_remove_storm_aerial_loss(creature)

func _has_non_passive_creature_ability(creature: Card) -> bool:
	if creature == null or creature.card_type != Card.CardType.CREATURE:
		return false
	var text := str(creature.ability_text).strip_edges()
	if text == "":
		return false
	for raw_line in text.split("\n", false):
		var line := str(raw_line).strip_edges().to_lower()
		if line == "":
			continue
		if line.contains("passive") or line.contains("incorporeal"):
			continue
		return true
	return false

func _is_active() -> bool:
	return current_zone != null and current_zone.is_board_zone() and not is_face_down and not abilities_suppressed()

func _is_aerial_under_storm(creature: Card) -> bool:
	if creature == null:
		return false
	return creature.has_type("Aerial") or creature.has_status_effect(STORM_AERIAL_STATUS)

func _weather_effect_is_blocked(creature: Card) -> bool:
	return creature != null \
		and creature.has_method("blocks_weather_effect") \
		and creature.blocks_weather_effect(self, -7, 0, -2)
