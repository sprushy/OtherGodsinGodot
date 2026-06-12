extends PowerCard
class_name TakeTheField

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const ART_PATH := "res://images/card_art/powers/Take the Field(web).jpg"

func _init() -> void:
	super._init()
	card_name = "Take the Field"
	culture = "Neutral"
	level = 0
	mana_cost = 0
	card_types = ["Power", "Summon - God", "Manifestation"]
	flavor_text = ""
	ability_text = "[b]Unlock[/b]: Pay the summon requirements of a matching [b]Active God[/b] and summon it. When you do, your normal god leaves the field.\n[b]God Death[/b] ([b]Passive[/b]): If you control no face-up, awake God on the field, you gain 1 less upkeep mana, cannot use powers, and lose 7 followers at upkeep."
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func can_unlock(game_manager: GameManager) -> bool:
	if not super.can_unlock(game_manager):
		return false
	var manifestation := _peek_manifestation_candidate()
	if manifestation == null:
		return false
	if _find_open_summon_zone() == null:
		return false
	return game_manager != null and game_manager.can_pay_creature_summon_cost(card_owner, manifestation, self, true)

func get_unlock_failure_reason(game_manager: GameManager) -> String:
	var base_reason := super.get_unlock_failure_reason(game_manager)
	if base_reason != card_name + " cannot unlock right now.":
		return base_reason
	if _get_manifest_god_name().is_empty():
		return card_name + " needs your normal god to identify which Active God to summon."
	if _peek_manifestation_candidate() == null:
		return card_name + " found no matching Active God to summon."
	if _find_open_summon_zone() == null:
		return card_name + " needs an open lane for your Active God."
	return card_name + " cannot pay that Active God's summon cost right now."

func get_unlock_display_mana_cost(game_manager: GameManager = null) -> int:
	var manifestation := _peek_manifestation_candidate()
	if manifestation == null:
		return super.get_unlock_display_mana_cost(game_manager)
	if game_manager == null or card_owner == null:
		return manifestation.mana_cost
	return game_manager.get_creature_summon_mana_cost(card_owner, manifestation, self, false)

func get_unlock_display_cost_shorthand(
	game_manager: GameManager = null,
	force_show_mana: bool = false
) -> String:
	var manifestation := _peek_manifestation_candidate()
	if manifestation == null:
		return super.get_unlock_display_cost_shorthand(game_manager, force_show_mana)
	var display_mana_cost := get_unlock_display_mana_cost(game_manager)
	var should_force_show_mana := force_show_mana and display_mana_cost > 0
	return manifestation.get_cost_shorthand(display_mana_cost, should_force_show_mana)

func get_unlock_display_cost_lines(game_manager: GameManager = null) -> Array[String]:
	var manifestation := _peek_manifestation_candidate()
	if manifestation == null:
		return super.get_unlock_display_cost_lines(game_manager)

	var lines: Array[String] = []
	var unlock_cost_text := get_unlock_display_cost_shorthand(game_manager)
	if unlock_cost_text.is_empty():
		unlock_cost_text = "Free"
	lines.append("Unlock Cost: %s" % unlock_cost_text)

	if game_manager != null and card_owner != null:
		for breakdown_line in manifestation.get_cost_adjustment_lines(
			manifestation.mana_cost,
			Card.COST_KIND_CREATURE_SUMMON,
			game_manager,
			{"player": card_owner, "summon_source": self}
		):
			lines.append(breakdown_line)

	return lines

func get_hover_summoned_active_gods(_viewer: Player = null) -> Array[Card]:
	var manifestation := _peek_manifestation_candidate()
	return [manifestation] if manifestation != null else []

func get_hover_summoned_active_gods_title(_viewer: Player = null) -> String:
	return "Take the Field summons"

func on_unlock(game_manager: GameManager) -> void:
	if game_manager == null or card_owner == null:
		relock()
		return

	var normal_god := _get_current_normal_god()
	var manifestation := _resolve_manifestation_candidate()
	var summon_zone := _find_open_summon_zone()
	if manifestation == null or summon_zone == null:
		relock()
		game_manager.note_player_feedback(card_name + " fizzles: no Active God can take the field.")
		return

	var active_god := manifestation as ActiveGodCard
	if active_god != null:
		active_god.set_stored_normal_god(normal_god)

	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		manifestation,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		true,
		false,
		true
	)
	if not summoned:
		relock()
		game_manager.note_player_feedback(card_name + " fizzles: the Active God could not be summoned.")
		return

	if normal_god != null and normal_god.current_zone == card_owner.god_zone:
		game_manager.remove_card_from_game_with_hook(normal_god)
		game_manager.note_player_feedback("%s summons %s and %s leaves the game." % [
			card_name,
			manifestation.card_name,
			normal_god.card_name
		])
	else:
		game_manager.note_player_feedback("%s summons %s." % [card_name, manifestation.card_name])

func _get_current_normal_god() -> Card:
	if card_owner == null or card_owner.god_zone == null or card_owner.god_zone.cards.is_empty():
		return null
	return card_owner.god_zone.cards[0]

func _get_current_normal_god_card() -> GodCard:
	return _get_current_normal_god() as GodCard

func _get_manifest_god_name() -> String:
	var normal_god := _get_current_normal_god()
	if normal_god != null:
		return str(normal_god.card_name).strip_edges()
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			var active_god := card as ActiveGodCard
			if active_god == null:
				continue
			if active_god.get_controller() != card_owner:
				continue
			return active_god.get_linked_god_name()
	return ""

func _peek_manifestation_candidate() -> Card:
	return _find_manifestation_candidate(true)

func _resolve_manifestation_candidate() -> Card:
	return _find_manifestation_candidate(true)

func _find_manifestation_candidate(allow_fallback: bool) -> Card:
	var god_name := _get_manifest_god_name()
	if god_name.is_empty():
		return null

	var reserved_manifestation := _get_reserved_manifestation_candidate(god_name)
	if reserved_manifestation != null:
		return reserved_manifestation

	for zone in _get_manifest_search_zones():
		for card in zone.cards:
			if not _matches_manifestation(card, god_name):
				continue
			if card.current_zone != null and card.current_zone.is_board_zone():
				return null
			return card

	if allow_fallback and _can_autofill_manifestation():
		return _build_manifestation_fallback(god_name)
	return null

func _get_manifest_search_zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	if card_owner == null:
		return zones
	for zone in [
		card_owner.hand_zone,
		card_owner.deck_zone,
		card_owner.graveyard_zone,
		card_owner.abyss_zone,
	]:
		if zone != null:
			zones.append(zone)
	for zone in card_owner.frontline_zones:
		if zone != null:
			zones.append(zone)
	for zone in card_owner.reserve_zones:
		if zone != null:
			zones.append(zone)
	return zones

func _matches_manifestation(card: Card, god_name: String) -> bool:
	var active_god := card as ActiveGodCard
	return active_god != null and active_god.get_linked_god_name() == god_name

func _get_reserved_manifestation_candidate(god_name: String) -> Card:
	var normal_god := _get_current_normal_god_card()
	if normal_god == null:
		return null
	var reserved_manifestation := normal_god.get_reserved_active_god_candidate()
	if reserved_manifestation == null or reserved_manifestation.get_linked_god_name() != god_name:
		return null
	return reserved_manifestation

func _can_autofill_manifestation() -> bool:
	var normal_god := _get_current_normal_god_card()
	if normal_god == null:
		return true
	return normal_god.can_autofill_take_the_field()

func _build_manifestation_fallback(god_name: String) -> Card:
	if god_name.is_empty():
		return null
	for template in CardCatalogScript.make_all_cards():
		var active_god := template as ActiveGodCard
		if active_god == null or active_god.get_linked_god_name() != god_name:
			continue
		active_god.card_owner = card_owner
		return active_god
	return null

func _find_open_summon_zone() -> Zone:
	if card_owner == null:
		return null
	var preferred_frontline := [2, 1, 3, 0, 4]
	for index in preferred_frontline:
		if index >= 0 and index < card_owner.frontline_zones.size():
			var zone := card_owner.frontline_zones[index]
			if zone.cards.is_empty():
				return zone
	for index in preferred_frontline:
		if index >= 0 and index < card_owner.reserve_zones.size():
			var zone := card_owner.reserve_zones[index]
			if zone.cards.is_empty():
				return zone
	return null
