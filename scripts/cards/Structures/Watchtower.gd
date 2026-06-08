extends StructureCard
class_name Watchtower

const ART_PATH := "res://images/card_art/structures/watchtower.png"
const ALT_ART_PATH := "res://images/card_art/structures/watchtower_alt.png"

var tactic_counters: int = 0

func _init() -> void:
	super._init()
	card_name = "Watchtower"
	card_types = ["Fortification", "Targeting"]
	targets = true
	level = 2
	mana_cost = 0
	resilience = 25
	speed = 0
	strength = 0
	sacrifice_cost = 0
	culture = "Tian"
	artist = "User provided art"
	art_path = ART_PATH
	art_variants = [ART_PATH, ALT_ART_PATH]
	ability_text = "Whenever an opposing creature enters the field, put 1 tactic counter on this.\nScout ([b]Activate[/b]): Remove 1 tactic counter: reveal a target opposing hidden card on the field."

func get_activation_label() -> String:
	return "Scout"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if not _is_effectively_active():
		return false
	if is_activation_locked(game_manager):
		return false
	if tactic_counters <= 0:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if get_controller() != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if current_zone == null or not current_zone.is_board_zone():
		return card_name + " must be on the field."
	if is_face_down or is_stealth:
		return card_name + " must be face-up to scout."
	if abilities_suppressed():
		return card_name + " has no active abilities right now."
	if is_activation_locked(game_manager):
		return card_name + " cannot activate this turn."
	if tactic_counters <= 0:
		return card_name + " has no tactic counters to spend."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " found no hidden opposing card to reveal."
	return card_name + " cannot activate right now."

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets

	var opponent := game_manager.get_opponent(get_controller())
	if opponent == null:
		return valid_targets

	for card in opponent.god_zone.cards:
		if _is_revealable_hidden_card(card):
			valid_targets.append(card)
	for zone in opponent.power_zones + opponent.frontline_zones + opponent.reserve_zones:
		for card in zone.cards:
			if _is_revealable_hidden_card(card):
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if target == null or target not in get_valid_targets(game_manager):
		game_manager.note_player_feedback("%s fizzles: choose a hidden opposing board card." % card_name)
		return

	tactic_counters -= 1
	_reveal_hidden_card(target, game_manager)
	_emit_visual_state_changed()
	game_manager.note_player_feedback(
		"%s removes 1 tactic counter to reveal %s." % [
			card_name,
			target.get_target_log_display_name(game_manager.get_feedback_viewer())
		]
	)

func on_creature_summoned(
	player: Player,
	card: Card,
	_from_zone: Zone,
	_to_zone: Zone,
	_summon_source: Card,
	_face_down: bool,
	_stealth: bool,
	game_manager: GameManager
) -> void:
	if not _is_effectively_active():
		return
	if game_manager == null or player == null or card == null:
		return
	if card.card_type != Card.CardType.CREATURE:
		return

	var controller := get_controller()
	if controller == null:
		return
	if player != game_manager.get_opponent(controller):
		return

	tactic_counters += 1
	_emit_visual_state_changed()
	game_manager.note_player_feedback(
		"%s gains a tactic counter when %s enters the field (now %d)." % [
			card_name,
			card.get_target_log_display_name(game_manager.get_feedback_viewer()),
			tactic_counters
		]
	)

func on_removed(_game_manager: GameManager) -> void:
	tactic_counters = 0
	_emit_visual_state_changed()

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	state["tactic_counters"] = tactic_counters
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	tactic_counters = int(state.get("tactic_counters", 0))
	_emit_visual_state_changed()

func get_effect_summary_lines() -> Array[String]:
	var lines := super.get_effect_summary_lines()
	lines.append("Tactic counters: %d" % tactic_counters)
	return lines

func _is_effectively_active() -> bool:
	return current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth \
		and not abilities_suppressed()

func _is_revealable_hidden_card(card: Card) -> bool:
	return _is_revealable_face_down_card(card) or _is_revealable_tiamat_slot_card(card)

func _is_revealable_face_down_card(card: Card) -> bool:
	if card == null:
		return false
	if card.current_zone == null or not _is_revealable_zone(card.current_zone):
		return false
	if not (card.is_face_down or card.is_stealth):
		return false
	if card.is_temporarily_revealed():
		return false
	var power := card as PowerCard
	if power != null and power.is_publicly_revealed:
		return false
	return true

func _reveal_hidden_card(card: Card, game_manager: GameManager) -> bool:
	if not _is_revealable_hidden_card(card):
		return false

	var power := card as PowerCard
	if power != null:
		power.reveal_while_face_down()
		if not card.abilities_suppressed():
			card.on_reveal(game_manager)
		if game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
			game_manager.notify_card_revealed_by_effect(card, self)
		return true

	if card.is_prepared or _is_revealable_tiamat_slot_card(card):
		_reveal_without_flipping(card, game_manager)
		return true

	card.reveal(game_manager)
	if game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
		game_manager.notify_card_revealed_by_effect(card, self)
	return true

func _reveal_without_flipping(card: Card, game_manager: GameManager) -> void:
	var viewer := get_controller()
	var was_hidden := card.is_hidden_from_viewer(viewer)
	card.remove_status_effects_by_name("temporarily_revealed")
	card.add_status_effect("temporarily_revealed", card_name, self, viewer)
	if was_hidden and game_manager != null and not card.abilities_suppressed():
		card.on_reveal(game_manager)
	if game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
		game_manager.notify_card_revealed_by_effect(card, self)

func _is_revealable_zone(zone: Zone) -> bool:
	if zone == null:
		return false
	return zone.is_board_zone() \
		or zone.zone_type == Zone.ZoneType.GOD_SLOT \
		or zone.zone_type == Zone.ZoneType.POWER_SLOT

func _is_revealable_tiamat_slot_card(card: Card) -> bool:
	if card == null or card.is_temporarily_revealed():
		return false
	var zone := card.current_zone
	if zone == null or zone.zone_type != Zone.ZoneType.POWER_SLOT:
		return false
	var owner := zone.zone_owner
	if owner == null or owner.god_zone == null or owner.god_zone.cards.is_empty():
		return false
	if not TiamatThePrimordial.is_tiamat_god(owner.god_zone.cards[0]):
		return false
	return TiamatThePrimordial.is_valid_slot_creature(card)
