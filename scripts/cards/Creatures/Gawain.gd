extends CreatureCard
class_name Gawain

const ART_PATH := "res://images/card_art/creatures/gawain.png"
const SUN_BLESSING_SOURCE := "Gawain Sun Blessing"

# Status names that are internal/friendly buffs and should not be removable.
const _NON_REMOVABLE_STATUSES: Array[String] = [
	"temporarily_revealed",
	"berserker_rage_guard",
	"berserker_mead_guard",
	"en_hedu_anna_exaltation_guard",
	"gala_tura_graveward",
]

func _init() -> void:
	super._init()
	card_name = "Gawain"
	card_types = ["Human", "Warrior", "Knight", "Triskelion Creature"]
	level = 5
	mana_cost = 3
	sacrifice_cost = 0
	speed = 2
	resilience = 7
	strength = 10
	targets = true
	ability_text = "Sun Blessing ([b]Passive[/b]): During your turn, this creature's base STR and RES are tripled until your first attack resolves or your turn ends.\nHealing Hands (2 mana): Remove a negative effect from a friendly creature."
	flavor_text = ""
	culture = "Triskelion"
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

# ── Sun Blessing ─────────────────────────────────────────────────────────────

func on_summon(game_manager: GameManager) -> void:
	if get_controller() == game_manager.current_player:
		_apply_sun_blessing()

func on_reveal(game_manager: GameManager) -> void:
	if get_controller() == game_manager.current_player:
		_apply_sun_blessing()

func on_turn_start(_game_manager: GameManager) -> void:
	_apply_sun_blessing()

func on_after_combat(_game_manager: GameManager, _opposing_card: Card) -> void:
	_remove_sun_blessing()

func on_turn_end(_game_manager: GameManager) -> void:
	_remove_sun_blessing()

func on_removed(_game_manager: GameManager) -> void:
	_remove_sun_blessing()

func on_muted(_game_manager: GameManager) -> void:
	_remove_sun_blessing()

func on_unmuted(game_manager: GameManager) -> void:
	if get_controller() == game_manager.current_player:
		_apply_sun_blessing()

func _apply_sun_blessing() -> void:
	_remove_sun_blessing()
	if abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	add_buff(
		SUN_BLESSING_SOURCE,
		strength * 2,
		resilience * 2,
		0,
		self,
		card_owner,
		"sun_blessing",
		{"expires_after_combat": true}
	)

func _remove_sun_blessing() -> void:
	clear_buffs_from(SUN_BLESSING_SOURCE)

# ── Healing Hands ─────────────────────────────────────────────────────────────

func get_activation_label() -> String:
	return "Healing Hands"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_sleeping:
		return false
	var controller := get_controller()
	if controller == null or controller.mana < 2:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	var controller := get_controller()
	if controller == null:
		return valid_targets
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if card == null or card.card_type != Card.CardType.CREATURE:
				continue
			if get_removable_statuses(card).is_empty():
				continue
			if game_manager.is_immune_to_source(card, self):
				continue
			valid_targets.append(card)
	return valid_targets

# Returns statuses on `target` that Healing Hands can remove.
func get_removable_statuses(target: Card) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if target == null:
		return result
	for status in target.active_statuses:
		var name: String = status.get("name", "")
		if name in _NON_REMOVABLE_STATUSES:
			continue
		if status.get("source_card", null) == null:
			continue
		result.append(status)
	return result

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if target == null or target not in get_valid_targets(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(
				"%s: choose a friendly creature with a negative effect." % card_name
			)
		return
	if game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback("%s: %s is immune to creature abilities." % [card_name, target.card_name])
		return
	var removable := get_removable_statuses(target)
	if removable.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s: %s has no removable effects." % [card_name, target.card_name])
		return

	var controller := get_controller()
	if controller == null or not controller.spend_mana(2):
		if game_manager != null:
			game_manager.note_player_feedback("%s: not enough mana for Healing Hands." % card_name)
		return

	if removable.size() == 1:
		_resolve_healing_hands(game_manager, target, removable[0])
		return

	# Multiple effects — ask the UI to let the player choose.
	game_manager.decision_requested.emit(get_controller(), "gawain_healing_hands", {
		"source_uid": uid,
		"target_uid": target.uid,
		"statuses": serialize_healing_hands_statuses(target),
	})

func resolve_healing_hands(game_manager: GameManager, target: Card, status: Dictionary) -> String:
	if game_manager == null or target == null or status.is_empty():
		return card_name + " cannot remove an effect right now."
	_resolve_healing_hands(game_manager, target, status)
	return "%s removed %s from %s." % [
		card_name,
		status.get("source", status.get("name", "effect")),
		target.card_name
	]

func _resolve_healing_hands(game_manager: GameManager, target: Card, status: Dictionary) -> void:
	var source_card: Card = status.get("source_card", null) as Card
	var status_name: String = status.get("name", "")
	if source_card != null:
		target.remove_status_effects_from_source_card(source_card, status_name)
	else:
		target.remove_status_effects_by_name(status_name)

	if game_manager != null:
		var viewer := game_manager.get_feedback_viewer()
		game_manager.note_player_feedback(
			"%s removed %s from %s via Healing Hands." % [
				card_name,
				status.get("source", status_name),
				target.get_target_log_display_name(viewer)
			]
		)

func serialize_healing_hands_statuses(target: Card) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	var removable := get_removable_statuses(target)
	for idx in range(removable.size()):
		var status: Dictionary = removable[idx]
		serialized.append({
			"index": idx,
			"label": str(status.get("source", status.get("name", "effect"))),
		})
	return serialized

func resolve_healing_hands_by_index(game_manager: GameManager, target: Card, status_index: int) -> String:
	var removable := get_removable_statuses(target)
	if status_index < 0 or status_index >= removable.size():
		return card_name + " cannot remove an effect right now."
	return resolve_healing_hands(game_manager, target, removable[status_index])

