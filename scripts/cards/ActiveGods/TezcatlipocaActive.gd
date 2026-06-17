extends ActiveGodCard
class_name TezcatlipocaActive

const LINKED_GOD_NAME := "Tezcatlipoca, the Smoking Mirror"
const DIVINE_FORM_ART_PATH := "res://images/card_art/gods/TezArt.png"
const JAGUAR_FORM_ART_PATH := "res://images/card_art/gods/TezJaguarForm.png"
const MAX_TITLACAUAN_TARGETS := 2
const NORMAL_SUMMON_SACRIFICE_COST := 4
const JAGUAR_FORM_SPEED_BONUS := 1
const JAGUAR_FORM_STRENGTH_BONUS := 10
const JAGUAR_FORM_RESILIENCE_DELTA := -13

var necoc_yaotl_sacrifices: Array[Card] = []
var in_jaguar_form: bool = true

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Tezcatlipoca, Active God"
	card_types = _get_jaguar_form_types()
	level = 7
	mana_cost = 0
	sacrifice_cost = NORMAL_SUMMON_SACRIFICE_COST
	speed = 2
	resilience = 37
	strength = 25
	culture = "Nahuatl"
	# flavor_text = "Smoke and sacrifice crown the god of night when he walks the field."
	flavor_text = ""
	ability_text = "[b]Shift[/b] ([b]Activate[/b], [b]Minor Action[/b], once per turn): Switch between Divine Manifestation, God, Shapeshifter and Divine Manifestation, God, Animal, Feline, Jaguar, Shapeshifter.\n[b]Jaguar Form[/b] ([b]Passive[/b]): While in Jaguar form, this card's stats become SPD 3 / RES 24 / STR 35.\n[b]The Smoking Mirror[/b] ([b]Passive[/b]): Instead of damaging followers, convert half of those that would have been destroyed.\n[b]Titlacauan[/b] ([b]Impact[/b]): Enslave up to 2 creatures whose total levels are less than or equal to the total levels sacrificed for Necoc Yaotl."
	artist = "Ricardo Zoppello"
	art_path = JAGUAR_FORM_ART_PATH
	name_at_bottom = true

func get_activation_label() -> String:
	return "Shift"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed():
		return false
	if is_shapeshift_locked():
		return false
	if is_sleeping:
		return false
	return can_take_minor_creature_action() and can_use_shift_ability_this_turn()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot shift right now."
	if get_controller() != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field to shift."
	if abilities_suppressed():
		return card_name + " is suppressed."
	if is_shapeshift_locked():
		return card_name + " cannot shift right now."
	if is_sleeping:
		return card_name + " is asleep."
	if not can_take_minor_creature_action():
		return card_name + " has no minor actions left."
	if not can_use_shift_ability_this_turn():
		return card_name + " has already shifted this turn."
	return ""

func get_tonal_extraction_spirit_profile() -> Dictionary:
	return {
		"card_name": card_name + " Spirit",
		"level": level,
		"speed": speed if in_jaguar_form else speed + JAGUAR_FORM_SPEED_BONUS,
		"resilience": resilience if in_jaguar_form else resilience + JAGUAR_FORM_RESILIENCE_DELTA,
		"strength": strength if in_jaguar_form else strength + JAGUAR_FORM_STRENGTH_BONUS,
		"card_types": _get_divine_form_types() if in_jaguar_form else _get_jaguar_form_types(),
		"culture": culture,
		"artist": artist,
		"art_path": art_path,
	}

func converts_follower_damage_to_conversion(_game_manager: GameManager = null) -> bool:
	return _passives_are_active()

func get_follower_damage_conversion_amount(amount: int, _game_manager: GameManager = null) -> int:
	if amount <= 0 or not _passives_are_active():
		return 0
	return GameManager.round_down_divide(amount, 2)

func activate(game_manager: GameManager, _target = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	var return_to_normal_god := false
	if _target is Dictionary:
		var option := _target as Dictionary
		return_to_normal_god = bool(option.get("return_to_normal_god", false))
	return_to_normal_god = return_to_normal_god and can_return_to_normal_god_form_after_shift()
	shift_forms()
	spend_minor_creature_action()
	spend_shift_ability_use()
	if game_manager != null:
		game_manager.notify_creature_shapeshifted(self, self)
		if return_to_normal_god and _return_to_normal_god_form(game_manager):
			var restored_name := linked_god_name if linked_god_name != "" else "its normal god form"
			game_manager.note_player_feedback(
				"%s shifts into Divine form and returns to %s." % [card_name, restored_name]
			)
			return
		game_manager.note_player_feedback(
			"%s shifts into %s form." % [card_name, "Jaguar" if in_jaguar_form else "Divine"]
		)

func shift_forms() -> void:
	in_jaguar_form = not in_jaguar_form
	_sync_form_presentation()
	art_updated.emit(art_path)
	_emit_visual_state_changed()

func receive_necoc_yaotl_sacrifices(cards: Array[Card]) -> void:
	necoc_yaotl_sacrifices.clear()
	for card in cards:
		if card != null:
			necoc_yaotl_sacrifices.append(card)
	_emit_visual_state_changed()

func get_titlacauan_level_budget() -> int:
	var total := 0
	for card in necoc_yaotl_sacrifices:
		if card != null:
			total += card.get_effective_level()
	return total

func get_hover_stored_cards(_viewer: Player = null) -> Array[Card]:
	var stored: Array[Card] = []
	for card in necoc_yaotl_sacrifices:
		if card != null:
			stored.append(card)
	return stored

func get_hover_stored_cards_title(_viewer: Player = null) -> String:
	return "Necoc Yaotl Sacrifices"

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	var stored_sacrifices: Array[Dictionary] = []
	for card in necoc_yaotl_sacrifices:
		if card == null:
			continue
		stored_sacrifices.append({
			"card": GameState.serialize_embedded_card(card),
		})
	state["necoc_yaotl_sacrifices"] = stored_sacrifices
	state["necoc_yaotl_sacrifice_count"] = stored_sacrifices.size()
	state["necoc_yaotl_total_level"] = get_titlacauan_level_budget()
	state["in_jaguar_form"] = in_jaguar_form
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	necoc_yaotl_sacrifices.clear()
	if state.is_empty():
		in_jaguar_form = card_types.has("Jaguar")
	elif state.has("in_jaguar_form"):
		in_jaguar_form = bool(state.get("in_jaguar_form"))
	else:
		in_jaguar_form = card_types.has("Jaguar")
	_sync_form_presentation()
	for entry_value in state.get("necoc_yaotl_sacrifices", []):
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var card_data = entry.get("card", {})
		if not (card_data is Dictionary):
			continue
		var stored_card := GameState.deserialize_embedded_card(card_data as Dictionary)
		if stored_card == null:
			continue
		stored_card.card_owner = card_owner
		stored_card.current_zone = null
		necoc_yaotl_sacrifices.append(stored_card)
	_emit_visual_state_changed()

func _sync_form_presentation() -> void:
	card_types = _get_jaguar_form_types() if in_jaguar_form else _get_divine_form_types()
	art_path = JAGUAR_FORM_ART_PATH if in_jaguar_form else DIVINE_FORM_ART_PATH

func get_effective_speed() -> int:
	var total := super.get_effective_speed()
	if in_jaguar_form:
		total += JAGUAR_FORM_SPEED_BONUS
	return clampi(total, 1, 7)

func get_effective_strength() -> int:
	var total := super.get_effective_strength()
	if in_jaguar_form:
		total += JAGUAR_FORM_STRENGTH_BONUS
	return max(0, total)

func get_effective_resilience() -> int:
	var total := super.get_effective_resilience()
	if in_jaguar_form:
		total += JAGUAR_FORM_RESILIENCE_DELTA
	return max(0, total)

func get_valid_titlacauan_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets
	var opponent := game_manager.get_opponent(controller)
	if opponent == null:
		return valid_targets
	for zone in opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_valid_titlacauan_target(game_manager, card):
				valid_targets.append(card)
	return valid_targets

func get_selected_titlacauan_targets(game_manager: GameManager, target_data) -> Array[Card]:
	var selected: Array[Card] = []
	var raw_choices: Array = []
	if target_data is Array:
		raw_choices = target_data
	elif target_data is Dictionary:
		raw_choices = target_data.get("target_uids", [])
	var valid_targets := get_valid_titlacauan_targets(game_manager)
	for entry in raw_choices:
		var card: Card = null
		if entry is Card:
			card = entry as Card
		elif game_manager != null:
			card = game_manager.get_card_by_uid(str(entry))
		if card == null or card in selected or card not in valid_targets:
			continue
		selected.append(card)
	return selected

func is_valid_titlacauan_selection(game_manager: GameManager, chosen_targets: Array[Card]) -> bool:
	if chosen_targets.size() > MAX_TITLACAUAN_TARGETS:
		return false
	var total_levels := 0
	var valid_targets := get_valid_titlacauan_targets(game_manager)
	for target in chosen_targets:
		if target == null or target not in valid_targets:
			return false
		total_levels += target.get_effective_level()
	return total_levels <= get_titlacauan_level_budget()

func on_impact(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var valid_targets := get_valid_titlacauan_targets(game_manager)
	if get_titlacauan_level_budget() <= 0:
		game_manager.note_player_feedback(resolve_titlacauan_choice(game_manager))
		return
	var controller := get_controller()
	if controller == null:
		game_manager.note_player_feedback(resolve_titlacauan_choice(game_manager))
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(controller, "tezcatlipoca_active_titlacauan", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "tezcatlipoca_active_titlacauan",
	})

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var option: Dictionary = command.get("option", {})
	var skip_choice := bool(option.get("skip", command.get("skip", false)))
	var chosen_targets := get_selected_titlacauan_targets(game_manager, option if not option.is_empty() else command)
	game_manager.note_player_feedback(resolve_titlacauan_choice(game_manager, chosen_targets, not skip_choice))

func resolve_titlacauan_choice(game_manager: GameManager, chosen_targets: Array[Card] = [], auto_select_if_empty: bool = true) -> String:
	if game_manager == null:
		return card_name + " cannot resolve Titlacauan right now."
	var budget := get_titlacauan_level_budget()
	if budget <= 0:
		return "%s has no Necoc Yaotl sacrifices powering Titlacauan." % card_name
	var valid_targets := get_valid_titlacauan_targets(game_manager)
	if valid_targets.is_empty():
		return "%s found no creatures it could enslave with Titlacauan." % card_name

	var resolved_targets := chosen_targets
	if resolved_targets.is_empty():
		if auto_select_if_empty:
			resolved_targets = _auto_select_titlacauan_targets(valid_targets, budget)
	elif not is_valid_titlacauan_selection(game_manager, resolved_targets):
		return "%s needs a valid Titlacauan selection." % card_name

	if resolved_targets.is_empty():
		return "%s chooses no targets for Titlacauan." % card_name

	var enslaved_names: Array[String] = []
	for target in resolved_targets:
		if target == null:
			continue
		if not game_manager.enslave_creature(target, get_controller()):
			return "%s failed to enslave %s." % [card_name, target.card_name]
		enslaved_names.append(target.get_target_log_display_name(game_manager.get_feedback_viewer()))

	return "%s uses Titlacauan to enslave %s." % [card_name, ", ".join(enslaved_names)]

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("Current form: %s" % ("Jaguar" if in_jaguar_form else "Divine"))
	lines.append("Titlacauan budget: %d" % get_titlacauan_level_budget())
	lines.append("Necoc Yaotl sacrifices: %d" % necoc_yaotl_sacrifices.size())
	return lines

func can_return_to_normal_god_form_after_shift() -> bool:
	return in_jaguar_form \
		and stored_normal_god != null \
		and card_owner != null \
		and card_owner.god_zone != null \
		and card_owner.god_zone.cards.is_empty()

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	return [
		"[b]Current Form[/b]: %s" % ("Jaguar" if in_jaguar_form else "Divine"),
		"[b]Divine[/b]: Divine Manifestation, God, Shapeshifter; SPD 2 / RES 37 / STR 25.",
		"[b]Jaguar[/b]: Divine Manifestation, God, Animal, Feline, Jaguar, Shapeshifter; SPD 3 / RES 24 / STR 35.",
		"[b]The Smoking Mirror[/b]: Follower damage converts half that amount instead.",
	]

func _is_valid_titlacauan_target(game_manager: GameManager, target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and not target.is_face_down \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() != get_controller() \
		and game_manager.can_enslave_creature(target, get_controller()) \
		and not game_manager.is_immune_to_source(target, self)

func _passives_are_active() -> bool:
	return not abilities_suppressed() \
		and current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth

func _return_to_normal_god_form(game_manager: GameManager) -> bool:
	if game_manager == null or not can_return_to_normal_god_form_after_shift():
		return false
	card_owner.reserved_active_god = self
	game_manager.remove_card_from_game_with_hook(self)
	return restore_stored_normal_god() != null

func _auto_select_titlacauan_targets(valid_targets: Array[Card], budget: int) -> Array[Card]:
	var sorted_targets := valid_targets.duplicate()
	sorted_targets.sort_custom(func(a: Card, b: Card) -> bool:
		return a.get_effective_level() < b.get_effective_level()
	)
	var chosen: Array[Card] = []
	var remaining_budget := budget
	for target in sorted_targets:
		if target == null or chosen.size() >= MAX_TITLACAUAN_TARGETS:
			break
		var target_level = target.get_effective_level()
		if target_level > remaining_budget:
			continue
		chosen.append(target)
		remaining_budget -= target_level
	return chosen

func _get_divine_form_types() -> Array[String]:
	return [
		"Active God",
		"Divine Manifestation",
		"God",
		"Shapeshifter",
		"Targeting",
	]

func _get_jaguar_form_types() -> Array[String]:
	return [
		"Active God",
		"Divine Manifestation",
		"God",
		"Animal",
		"Feline",
		"Jaguar",
		"Shapeshifter",
		"Targeting",
	]

