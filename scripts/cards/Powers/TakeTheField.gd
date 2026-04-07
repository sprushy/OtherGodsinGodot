extends PowerCard
class_name TakeTheField

const ART_PATH := "res://scripts/cards/Gods/Take the Field(web).jpg"
const THOR_ACTIVE_SCRIPT := preload("res://scripts/cards/ActiveGods/ThorActive.gd")

func _init() -> void:
	super._init()
	card_name = "Take the Field"
	culture = "Neutral"
	level = 0
	mana_cost = 0
	card_types = ["Power", "Summon - God", "Manifestation"]
	flavor_text = ""
	ability_text = "[b]Unlock[/b]: Pay the summon requirements of a matching [b]Active God[/b] and summon it. When it enters the field, your normal god goes away.\n[b]God Death[/b] ([b]Passive[/b]): If you have no normal god and your Active God is not face-up, awake, and on the field, you gain no mana at upkeep, cannot use powers, and lose 7 followers at upkeep."
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
	return _find_manifestation_candidate(false)

func _resolve_manifestation_candidate() -> Card:
	return _find_manifestation_candidate(true)

func _find_manifestation_candidate(allow_fallback: bool) -> Card:
	var god_name := _get_manifest_god_name()
	if god_name.is_empty():
		return null

	for zone in _get_manifest_search_zones():
		for card in zone.cards:
			if not _matches_manifestation(card, god_name):
				continue
			if card.current_zone != null and card.current_zone.is_board_zone():
				return null
			return card

	if allow_fallback and god_name == "Thor":
		var manifestation := THOR_ACTIVE_SCRIPT.new()
		manifestation.card_owner = card_owner
		return manifestation
	return null

func _get_manifest_search_zones() -> Array[Zone]:
	if card_owner == null:
		return []
	return [
		card_owner.hand_zone,
		card_owner.deck_zone,
		card_owner.graveyard_zone,
		card_owner.abyss_zone,
	] + card_owner.frontline_zones + card_owner.reserve_zones

func _matches_manifestation(card: Card, god_name: String) -> bool:
	var active_god := card as ActiveGodCard
	return active_god != null and active_god.get_linked_god_name() == god_name

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
