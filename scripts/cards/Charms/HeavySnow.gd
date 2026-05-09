extends CharmCard
class_name HeavySnow

const CANNOT_MOVE_STATUS := "cannot_move"
const FORCED_STEALTH_SOURCE_META := "heavy_snow_forced_stealth_source_uid"
const PREV_FACE_DOWN_META := "heavy_snow_prev_face_down"
const PREV_STEALTH_META := "heavy_snow_prev_stealth"
const PREV_MODE_META := "heavy_snow_prev_mode"

func _init() -> void:
	super._init()
	card_name = "Heavy Snow"
	culture = "Neutral"
	card_types = ["Charm", "Weather", "Permanent"]
	level = 3
	mana_cost = 0
	speed = 3
	sacrifice_cost = 0
	flavor_text = ""
	artist = ""
	art_path = "res://images/card_art/charms/HeavySnowArt.jpg"
	ability_text = "Destroy any face-up [b]Weather[/b] charms. All [b]Anguine[/b] and [b]Amphibious[/b] creatures are switched to stealth, gain [b]Sleep[/b], and cannot move while this remains face-up. Spells must be prepared for 1 turn before use."

func goes_to_graveyard_after_use() -> bool:
	return false

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return
	_destroy_face_up_weather_charms(game_manager)
	_refresh_weather_lock(game_manager)
	game_manager.note_player_feedback(card_name + " blankets the field in deadly winter.")

func on_any_card_moved(game_manager: GameManager, moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	if game_manager == null:
		return
	if moved_card == null or moved_card.card_type != Card.CardType.CREATURE:
		return
	if _from_zone != null and _from_zone.is_board_zone() and (_to_zone == null or not _to_zone.is_board_zone()):
		_remove_weather_lock(moved_card)
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if not _is_active():
		return
	if _to_zone != null and _to_zone.is_board_zone():
		_refresh_weather_lock(game_manager)

func on_removed(game_manager: GameManager) -> void:
	_clear_weather_lock(game_manager)

func on_muted(game_manager: GameManager) -> void:
	_clear_weather_lock(game_manager)

func on_unmuted(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	if _is_active():
		_refresh_weather_lock(game_manager)

func _destroy_face_up_weather_charms(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var doomed_cards: Array[Card] = []
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards.duplicate():
				if card == null or card == self:
					continue
				if not (card is CharmCard):
					continue
				if card.is_face_down or not card.has_type("Weather"):
					continue
				doomed_cards.append(card)
	game_manager.request_send_cards_to_graveyard(doomed_cards)

func _refresh_weather_lock(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var creature := card as Card
				if creature == null or creature.card_type != Card.CardType.CREATURE:
					continue
				if _is_active() and _is_weather_locked_creature(creature) and not _weather_effect_is_blocked(creature):
					_apply_weather_lock(creature)
				else:
					_remove_weather_lock(creature)

func _clear_weather_lock(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				var creature := card as Card
				if creature == null or creature.card_type != Card.CardType.CREATURE:
					continue
				_remove_weather_lock(creature)

func _apply_weather_lock(creature: Card) -> void:
	if creature == null:
		return
	creature.remove_status_effects_from_source_card(self, "sleep")
	creature.remove_status_effects_from_source_card(self, CANNOT_MOVE_STATUS)
	creature.add_status_effect("sleep", card_name, self, card_owner)
	creature.add_status_effect(CANNOT_MOVE_STATUS, card_name, self, card_owner)
	if str(creature.get_meta(FORCED_STEALTH_SOURCE_META, "")) != uid:
		creature.set_meta(FORCED_STEALTH_SOURCE_META, uid)
		creature.set_meta(PREV_FACE_DOWN_META, creature.is_face_down)
		creature.set_meta(PREV_STEALTH_META, creature.is_stealth)
		creature.set_meta(PREV_MODE_META, creature.creature_mode)
	creature.is_face_down = true
	creature.is_stealth = true
	creature.creature_mode = Card.CreatureMode.DEFENSIVE

func _remove_weather_lock(creature: Card) -> void:
	if creature == null:
		return
	creature.remove_status_effects_from_source_card(self, "sleep")
	creature.remove_status_effects_from_source_card(self, CANNOT_MOVE_STATUS)
	if str(creature.get_meta(FORCED_STEALTH_SOURCE_META, "")) != uid:
		return
	creature.is_face_down = bool(creature.get_meta(PREV_FACE_DOWN_META, creature.is_face_down))
	creature.is_stealth = bool(creature.get_meta(PREV_STEALTH_META, creature.is_stealth))
	var previous_mode = creature.get_meta(PREV_MODE_META, creature.creature_mode)
	if previous_mode is int:
		creature.creature_mode = int(previous_mode) as Card.CreatureMode
	creature.remove_meta(FORCED_STEALTH_SOURCE_META)
	creature.remove_meta(PREV_FACE_DOWN_META)
	creature.remove_meta(PREV_STEALTH_META)
	creature.remove_meta(PREV_MODE_META)

func _is_active() -> bool:
	return current_zone != null and current_zone.is_board_zone() and not is_face_down and not abilities_suppressed()

func _is_weather_locked_creature(card: Card) -> bool:
	return card != null and (card.has_type("Anguine") or card.has_type("Amphibious"))

func _weather_effect_is_blocked(creature: Card) -> bool:
	return creature != null \
		and creature.has_method("blocks_weather_effect") \
		and creature.blocks_weather_effect(self, 0, 0, 0)
