extends BaseCard
class_name GodCard

const ACTIVE_GOD_DECK_ROLE_ALLOWED := "allowed"
const ACTIVE_GOD_DECK_ROLE_RESERVED := "reserved"
const ACTIVE_GOD_DECK_ROLE_ILLEGAL := "illegal"
const CHAMPIONS_CALL_SHELVE_MANA_VALUE := 4

func _init() -> void:
	super._init()
	card_type = Card.CardType.GOD
	is_god = true
	is_power = true
	ability_immunity_tag = "powers"

func is_effectively_active() -> bool:
	return not is_muted

func can_use_god_power(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if card_owner == null:
		return false
	if is_muted:
		return false
	if current_zone != card_owner.god_zone:
		return false
	if card_owner != game_manager.current_player:
		return false
	if game_manager.has_method("has_resolved_turn_upkeep") and not game_manager.has_resolved_turn_upkeep():
		return false
	var resolving_own_action := false
	for action in game_manager.resolving_stack_actions:
		if action != null \
				and action.card == self \
				and game_manager.action_stack.size() == 1 \
				and game_manager.action_stack.has(action):
			resolving_own_action = true
			break
	if not resolving_own_action and (game_manager.priority_player != null or not game_manager.action_stack.is_empty()):
		return false
	if game_manager.has_method("can_player_use_powers") and not game_manager.can_player_use_powers(card_owner):
		return false
	return true

func on_muted(_game_manager: GameManager) -> void:
	pass

func on_unmuted(_game_manager: GameManager) -> void:
	pass

func notify_power_activated(game_manager: GameManager, target: Card = null) -> void:
	if game_manager == null or card_owner == null:
		return
	game_manager.notify_god_power_activated(card_owner, self, target)

func uses_culture_locked_deckbuilding() -> bool:
	return has_type("Patriarch") or has_type("Matriarch")

func can_include_card_in_culture_locked_deck(card: Card) -> bool:
	if card == null or card.is_god:
		return true
	var card_culture := str(card.culture).strip_edges()
	if card_culture.is_empty() or card_culture == "Neutral":
		return true
	return card_culture == str(culture).strip_edges()

func is_own_active_god_card(active_god: ActiveGodCard) -> bool:
	if active_god == null:
		return false
	var stored_god := active_god.get_stored_normal_god()
	if stored_god == self:
		return true
	var linked_name := active_god.get_linked_god_name()
	if linked_name == card_name:
		return true
	if linked_name.is_empty():
		return false
	var base_name := card_name.split(",")[0].strip_edges()
	return linked_name == base_name

func get_active_god_deck_role(active_god: ActiveGodCard) -> String:
	if active_god == null:
		return ACTIVE_GOD_DECK_ROLE_ILLEGAL
	if uses_culture_locked_deckbuilding():
		if is_own_active_god_card(active_god):
			return ACTIVE_GOD_DECK_ROLE_RESERVED
		return ACTIVE_GOD_DECK_ROLE_ALLOWED if can_include_card_in_culture_locked_deck(active_god) else ACTIVE_GOD_DECK_ROLE_ILLEGAL
	return ACTIVE_GOD_DECK_ROLE_RESERVED if is_own_active_god_card(active_god) else ACTIVE_GOD_DECK_ROLE_ILLEGAL

func can_autofill_take_the_field() -> bool:
	return true

func get_champions_call_candidate(_allow_fallback: bool = true) -> Card:
	return null

func has_champions_call() -> bool:
	return ability_text.find("Champion's Call") != -1 or get_champions_call_candidate(false) != null

func should_show_activation_aura(game_manager: GameManager) -> bool:
	if not has_method("can_activate"):
		return false
	return bool(call("can_activate", game_manager))

func get_reserved_active_god_candidate() -> ActiveGodCard:
	if card_owner == null:
		return null
	var manifestation := card_owner.reserved_active_god
	if manifestation == null or not is_own_active_god_card(manifestation):
		return null
	if manifestation.current_zone != null and manifestation.current_zone.is_board_zone():
		return null
	return manifestation

func can_use_champions_call(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	var manifestation := get_champions_call_candidate(true)
	if manifestation == null:
		return false
	if get_champions_call_open_zones().is_empty():
		return false
	return _can_pay_champions_call_cost(game_manager, manifestation)

func get_champions_call_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot use Champion's Call right now."
	if not can_use_god_power(game_manager):
		if is_muted:
			return card_name + " is muted."
		if card_owner != game_manager.current_player:
			return "It is not " + card_name + "'s turn to act."
		return card_name + " cannot use Champion's Call right now."
	var manifestation := get_champions_call_candidate(true)
	if manifestation == null:
		return card_name + " found no matching Active God to summon."
	if get_champions_call_open_zones().is_empty():
		return card_name + " needs an open lane for its Active God."
	return card_name + " cannot afford that Active God's summon cost, even after shelving cards."

func get_champions_call_required_shelve_count(game_manager: GameManager) -> int:
	if game_manager == null or card_owner == null:
		return 0
	var manifestation := get_champions_call_candidate(true)
	if manifestation == null:
		return 0
	var mana_required := game_manager.get_creature_summon_mana_cost(card_owner, manifestation, self, false)
	var shortfall := maxi(0, mana_required - card_owner.mana)
	if shortfall <= 0:
		return 0
	return int(ceili(float(shortfall) / float(CHAMPIONS_CALL_SHELVE_MANA_VALUE)))

func get_champions_call_max_shelve_count(game_manager: GameManager, manifestation: Card = null) -> int:
	if game_manager == null or card_owner == null:
		return 0
	var resolved_manifestation := manifestation if manifestation != null else get_champions_call_candidate(true)
	if resolved_manifestation == null:
		return 0
	var mana_required := game_manager.get_creature_summon_mana_cost(card_owner, resolved_manifestation, self, false)
	if mana_required <= 0:
		return 0
	var available_choices := _get_champions_call_shelvable_hand_cards(resolved_manifestation).size()
	return mini(available_choices, int(ceili(float(mana_required) / float(CHAMPIONS_CALL_SHELVE_MANA_VALUE))))

func get_champions_call_shelvable_hand_cards(manifestation: Card = null) -> Array[Card]:
	var resolved_manifestation := manifestation if manifestation != null else get_champions_call_candidate(true)
	return _get_champions_call_shelvable_hand_cards(resolved_manifestation)

func get_champions_call_selected_cards_from_command(game_manager: GameManager, command: Dictionary) -> Array[Card]:
	var selected: Array[Card] = []
	if game_manager == null:
		return selected
	var raw_choices = command.get("shelve_uids", [])
	if not (raw_choices is Array):
		return selected
	for entry in raw_choices:
		if entry is Card:
			selected.append(entry)
			continue
		var chosen_uid := str(entry).strip_edges()
		if chosen_uid.is_empty():
			continue
		var chosen_card := game_manager.get_card_by_uid(chosen_uid)
		if chosen_card != null:
			selected.append(chosen_card)
	return selected

func is_champions_call_command(command: Dictionary) -> bool:
	return command.has("shelve_uids") or command.has("zone_type") or command.has("zone_index") or command.has("mode")

func resolve_champions_call_from_command(game_manager: GameManager, command: Dictionary) -> String:
	return resolve_champions_call(
		game_manager,
		get_champions_call_selected_cards_from_command(game_manager, command),
		get_champions_call_zone_from_command(command),
		get_champions_call_mode_from_command(command)
	)

func resolve_champions_call(
	game_manager: GameManager,
	chosen_shelved_cards: Array[Card] = [],
	summon_zone: Zone = null,
	summon_mode_name: String = "aggressive"
) -> String:
	if game_manager == null or card_owner == null:
		return card_name + " cannot use Champion's Call right now."
	var manifestation := get_champions_call_candidate(true)
	if manifestation == null:
		return card_name + " found no matching Active God to summon."
	if summon_zone == null:
		summon_zone = _get_champions_call_open_zone()
	if summon_zone == null:
		return card_name + " needs an open lane for its Active God."
	if summon_zone.zone_owner != card_owner:
		return card_name + " must summon its Active God to one of your own lanes."
	if summon_zone.zone_type not in [Zone.ZoneType.FRONTLINE, Zone.ZoneType.RESERVE]:
		return card_name + " must summon its Active God to the frontline or reserve line."
	if not summon_zone.cards.is_empty():
		return card_name + " needs an empty lane for its Active God."
	if not _can_pay_champions_call_cost(game_manager, manifestation):
		return card_name + " cannot afford that Active God's summon cost, even after shelving cards."

	var mana_required := game_manager.get_creature_summon_mana_cost(card_owner, manifestation, self, false)
	var shelved_cards := _get_champions_call_cards_to_shelve(mana_required, manifestation, chosen_shelved_cards)
	if shelved_cards.size() < get_champions_call_required_shelve_count(game_manager):
		return card_name + " needs a valid Champion's Call hand selection."
	var reduced_mana := maxi(0, mana_required - (shelved_cards.size() * CHAMPIONS_CALL_SHELVE_MANA_VALUE))
	for card in shelved_cards:
		game_manager.send_to_deck_bottom_with_hook(card)

	var active_god := manifestation as ActiveGodCard
	if active_god != null:
		active_god.set_stored_normal_god(self)

	var summon_mode := Card.CreatureMode.DEFENSIVE
	if summon_mode_name == "aggressive":
		summon_mode = Card.CreatureMode.AGGRESSIVE
	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		manifestation,
		summon_zone,
		summon_mode,
		false,
		false,
		self,
		false,
		false,
		true,
		true
	)
	if not summoned:
		return card_name + " could not summon its Active God."

	if reduced_mana > 0 and not manifestation.pay_costs_with_mana_cost(card_owner, reduced_mana, game_manager):
		return card_name + " could not finish paying for Champion's Call."

	game_manager.remove_card_from_game_with_hook(self)

	var feedback := "%s uses Champion's Call to summon %s." % [card_name, manifestation.card_name]
	if not shelved_cards.is_empty():
		var shelved_names: Array[String] = []
		for card in shelved_cards:
			shelved_names.append(card.card_name)
		feedback += " Shelved: %s." % ", ".join(shelved_names)
	return feedback

func _can_pay_champions_call_cost(game_manager: GameManager, manifestation: Card) -> bool:
	if game_manager == null or card_owner == null or manifestation == null:
		return false
	var mana_required := game_manager.get_creature_summon_mana_cost(card_owner, manifestation, self, false)
	var available_shelving := _get_champions_call_shelvable_hand_cards(manifestation).size() * CHAMPIONS_CALL_SHELVE_MANA_VALUE
	return card_owner.mana + available_shelving >= mana_required

func _get_champions_call_cards_to_shelve(mana_required: int, manifestation: Card = null, chosen_cards: Array[Card] = []) -> Array[Card]:
	var chosen: Array[Card] = []
	var valid_choices := _get_champions_call_shelvable_hand_cards(manifestation)
	var max_shelve_count := mini(valid_choices.size(), int(ceili(float(maxi(0, mana_required)) / float(CHAMPIONS_CALL_SHELVE_MANA_VALUE))))
	var shortfall := maxi(0, mana_required - (card_owner.mana if card_owner != null else 0))
	if not chosen_cards.is_empty():
		var unique_choices: Array[Card] = []
		for card in chosen_cards:
			if card == null or card in unique_choices or not valid_choices.has(card):
				return []
			unique_choices.append(card)
		if unique_choices.size() > max_shelve_count:
			return []
		return unique_choices
	if shortfall <= 0:
		return chosen
	for card in _get_champions_call_shelvable_hand_cards(manifestation):
		chosen.append(card)
		shortfall -= 4
		if shortfall <= 0:
			break
	return chosen

func _get_champions_call_shelvable_hand_cards(excluded_card: Card = null) -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null or card_owner.hand_zone == null:
		return cards
	for card in card_owner.hand_zone.cards:
		if card == null or card == excluded_card:
			continue
		cards.append(card)
	return cards

func _get_champions_call_open_zone() -> Zone:
	var open_zones := get_champions_call_open_zones()
	return open_zones[0] if not open_zones.is_empty() else null

func get_champions_call_open_zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	if card_owner == null:
		return zones
	var preferred_frontline := [2, 1, 3, 0, 4]
	for index in preferred_frontline:
		if index >= 0 and index < card_owner.frontline_zones.size():
			var zone := card_owner.frontline_zones[index]
			if zone.cards.is_empty():
				zones.append(zone)
	for index in preferred_frontline:
		if index >= 0 and index < card_owner.reserve_zones.size():
			var zone := card_owner.reserve_zones[index]
			if zone.cards.is_empty():
				zones.append(zone)
	return zones

func get_champions_call_zone_from_command(command: Dictionary) -> Zone:
	if command.is_empty() or card_owner == null:
		return null
	var zone_type := int(command.get("zone_type", -1))
	var zone_index := int(command.get("zone_index", -1))
	if zone_index < 0:
		return null
	match zone_type:
		Zone.ZoneType.FRONTLINE:
			if zone_index < card_owner.frontline_zones.size():
				return card_owner.frontline_zones[zone_index]
		Zone.ZoneType.RESERVE:
			if zone_index < card_owner.reserve_zones.size():
				return card_owner.reserve_zones[zone_index]
	return null

func get_champions_call_mode_from_command(command: Dictionary) -> String:
	var mode_name := str(command.get("mode", "aggressive")).to_lower()
	return "defensive" if mode_name == "defensive" else "aggressive"
