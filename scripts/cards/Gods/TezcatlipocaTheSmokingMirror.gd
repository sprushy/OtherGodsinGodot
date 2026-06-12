extends GodCard
class_name TezcatlipocaTheSmokingMirror

const TONAL_MASTERY_TOKEN_THRESHOLD := 3
const TONAL_MASTERY_MANA_GAIN := 3
const ART_PATH := "res://images/card_art/gods/TezArt.png"
const REQUIRED_NECOC_YAOTL_SACRIFICES := 4
const TEZCATLIPOCA_ACTIVE_SCRIPT := preload("res://scripts/cards/ActiveGods/TezcatlipocaActive.gd")

var necoc_yaotl_sacrifices: Array[Card] = []
var tonal_mastery_tokens: int = 0

func _init() -> void:
	super._init()
	card_name = "Tezcatlipoca, the Smoking Mirror"
	card_types = ["Weather", "Sorcery", "War", "Night", "Dominion"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	mana_cost = 0
	culture = "Nahuatl"
	targets = true
	flavor_text = ""
	ability_text = "Tonal Mastery ([b]Passive[/b]): Every time a creature shapeshifts, gain 1 Tonal Mastery token. At 3 tokens, clear them and gain 3 mana.\nNecoc Yaotl ([b]Activate[/b]): Sacrifice a friendly creature and place it under this card. Once you have done this 4 times, summon Tezcatlipoca, Active God."
	artist = "Ricardo Zoppello"
	art_path = ART_PATH
	name_at_bottom = true
	paragon_of_champions = "Weather, Dominion"

func can_activate(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	if can_resolve_necoc_yaotl_summon(game_manager):
		return true
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if not can_use_god_power(game_manager):
		if is_muted:
			return card_name + " is muted."
		if card_owner != game_manager.current_player:
			return "It is not " + card_name + "'s turn to act."
		return card_name + " cannot activate right now."
	if _has_completed_necoc_yaotl():
		return get_necoc_yaotl_summon_failure_reason(game_manager)
	if get_valid_targets(game_manager).is_empty():
		return "Necoc Yaotl needs a friendly creature to sacrifice."
	return ""

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or _has_completed_necoc_yaotl():
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if _is_valid_necoc_yaotl_sacrifice(card):
				valid_targets.append(card)
	return valid_targets

func is_valid_activation_target(target: Card) -> bool:
	return target != null and target in get_valid_targets(null)

func activate(game_manager: GameManager, target: Card = null) -> void:
	var feedback := resolve_necoc_yaotl_sacrifice(game_manager, target) if target != null else resolve_necoc_yaotl_summon(game_manager)
	if game_manager != null and feedback.strip_edges() != "":
		game_manager.note_player_feedback(feedback)

func activate_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if game_manager == null:
		return
	var target_uid := str(command.get("target_uid", ""))
	var target := game_manager.get_card_by_uid(target_uid) if not target_uid.is_empty() else null
	activate(game_manager, target)

func get_necoc_yaotl_sacrifices() -> Array[Card]:
	var stored: Array[Card] = []
	for card in necoc_yaotl_sacrifices:
		if card != null:
			stored.append(card)
	return stored

func get_necoc_yaotl_total_level() -> int:
	var total := 0
	for card in necoc_yaotl_sacrifices:
		if card != null:
			total += card.get_effective_level()
	return total

func get_hover_stored_cards(_viewer: Player = null) -> Array[Card]:
	return get_necoc_yaotl_sacrifices()

func get_hover_stored_cards_title(_viewer: Player = null) -> String:
	return "Necoc Yaotl Sacrifices"

func get_hover_summoned_active_gods(_viewer: Player = null) -> Array[Card]:
	var manifestation := _get_necoc_yaotl_candidate(true)
	var summoned_active_gods: Array[Card] = []
	if manifestation != null:
		summoned_active_gods.append(manifestation)
	return summoned_active_gods

func get_hover_summoned_active_gods_title(_viewer: Player = null) -> String:
	return "Necoc Yaotl summons"

func get_tonal_mastery_token_count() -> int:
	return clampi(tonal_mastery_tokens, 0, TONAL_MASTERY_TOKEN_THRESHOLD)

func get_serialized_state() -> Dictionary:
	var stored_sacrifices: Array[Dictionary] = []
	for card in necoc_yaotl_sacrifices:
		if card == null:
			continue
		stored_sacrifices.append({
			"card": GameState.serialize_embedded_card(card),
		})
	return {
		"tonal_mastery_tokens": get_tonal_mastery_token_count(),
		"necoc_yaotl_sacrifices": stored_sacrifices,
		"necoc_yaotl_sacrifice_count": stored_sacrifices.size(),
		"necoc_yaotl_total_level": get_necoc_yaotl_total_level(),
	}

func apply_serialized_state(state: Dictionary) -> void:
	tonal_mastery_tokens = clampi(int(state.get("tonal_mastery_tokens", 0)), 0, TONAL_MASTERY_TOKEN_THRESHOLD)
	necoc_yaotl_sacrifices.clear()
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

func can_resolve_necoc_yaotl_summon(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	if not _has_completed_necoc_yaotl():
		return false
	return get_necoc_yaotl_summon_failure_reason(game_manager) == ""

func get_necoc_yaotl_summon_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot summon its Active God right now."
	if not _has_completed_necoc_yaotl():
		return "Necoc Yaotl needs %d sacrifices (have %d)." % [REQUIRED_NECOC_YAOTL_SACRIFICES, necoc_yaotl_sacrifices.size()]
	var manifestation := _get_necoc_yaotl_candidate(true)
	if manifestation == null:
		return card_name + " found no Active God to summon."
	if _get_champions_call_open_zone() == null:
		return card_name + " needs an open lane for its Active God."
	return ""

func resolve_necoc_yaotl_sacrifice(game_manager: GameManager, target: Card) -> String:
	if game_manager == null:
		return card_name + " cannot use Necoc Yaotl right now."
	if not can_use_god_power(game_manager):
		return get_activation_failure_reason(game_manager)
	if _has_completed_necoc_yaotl():
		return "Necoc Yaotl is complete. Summon Tezcatlipoca, Active God instead."
	if not _is_valid_necoc_yaotl_sacrifice(target):
		return "Necoc Yaotl needs a valid friendly creature to sacrifice."

	for equipment_card in target.equipment.duplicate():
		equipment_card.unequip()
	var from_zone := target.current_zone
	if from_zone != null:
		if from_zone.is_board_zone():
			target.last_board_zone_type = from_zone.zone_type
			target.last_board_zone_index = from_zone.zone_index
			if target.has_method("reset_activation_counter"):
				target.reset_activation_counter()
			if target.has_method("remove_status_effects_with_flag"):
				target.remove_status_effects_with_flag("remove_when_leaves_board")
			target.remove_effects_expiring_after_combat()
		from_zone.remove_card(target)
	target.current_zone = null
	if target.card_owner != null and from_zone != null:
		target.card_owner.card_moved.emit(target, from_zone, null)
	necoc_yaotl_sacrifices.append(target)
	_emit_visual_state_changed()
	notify_power_activated(game_manager, target)

	return "%s places %s under itself for Necoc Yaotl. (%d/%d)" % [
		card_name,
		target.get_target_log_display_name(game_manager.get_feedback_viewer()),
		necoc_yaotl_sacrifices.size(),
		REQUIRED_NECOC_YAOTL_SACRIFICES
	]

func resolve_necoc_yaotl_summon(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot summon its Active God right now."
	var failure_reason := get_necoc_yaotl_summon_failure_reason(game_manager)
	if failure_reason != "":
		return failure_reason

	var manifestation := _get_necoc_yaotl_candidate(true)
	var summon_zone := _get_champions_call_open_zone()
	if manifestation.has_method("set_stored_normal_god"):
		manifestation.call("set_stored_normal_god", self)
	if manifestation.has_method("receive_necoc_yaotl_sacrifices"):
		manifestation.call("receive_necoc_yaotl_sacrifices", get_necoc_yaotl_sacrifices())

	var summoned := game_manager.summon_creature_by_effect(
		card_owner,
		manifestation,
		summon_zone,
		Card.CreatureMode.AGGRESSIVE,
		false,
		false,
		self,
		false,
		false,
		false
	)
	if not summoned:
		return card_name + " could not summon its Active God."

	necoc_yaotl_sacrifices.clear()
	game_manager.remove_card_from_game_with_hook(self)
	_emit_visual_state_changed()
	notify_power_activated(game_manager, manifestation)
	if manifestation.has_method("on_impact"):
		manifestation.call("on_impact", game_manager)
	return "%s summons Tezcatlipoca, Active God through Necoc Yaotl." % card_name

func get_effect_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Tonal Mastery: %d / %d" % [get_tonal_mastery_token_count(), TONAL_MASTERY_TOKEN_THRESHOLD])
	lines.append("Necoc Yaotl sacrifices: %d / %d" % [necoc_yaotl_sacrifices.size(), REQUIRED_NECOC_YAOTL_SACRIFICES])
	lines.append("Stored levels: %d" % get_necoc_yaotl_total_level())
	return lines

func on_creature_shapeshifted(game_manager: GameManager, creature: Card, _source_card: Card = null) -> void:
	if game_manager == null or creature == null or card_owner == null or is_muted:
		return

	tonal_mastery_tokens = mini(tonal_mastery_tokens + 1, TONAL_MASTERY_TOKEN_THRESHOLD)
	var creature_name := creature.get_target_log_display_name(game_manager.get_feedback_viewer())
	if tonal_mastery_tokens >= TONAL_MASTERY_TOKEN_THRESHOLD:
		tonal_mastery_tokens = 0
		var mana_before := card_owner.mana
		card_owner.gain_mana(TONAL_MASTERY_MANA_GAIN)
		var mana_gained := card_owner.mana - mana_before
		if mana_gained > 0:
			game_manager.note_player_feedback(
				"%s completes Tonal Mastery after %s shapeshifts, clears its tokens, and gains %d mana." % [
					card_name,
					creature_name,
					mana_gained
				]
			)
		else:
			game_manager.note_player_feedback(
				"%s completes Tonal Mastery after %s shapeshifts and clears its tokens." % [
					card_name,
					creature_name
				]
			)
	else:
		game_manager.note_player_feedback(
			"%s gains a Tonal Mastery token (%d/%d) after %s shapeshifts." % [
				card_name,
				tonal_mastery_tokens,
				TONAL_MASTERY_TOKEN_THRESHOLD,
				creature_name
			]
		)
	_emit_visual_state_changed()
	notify_power_activated(game_manager, creature)

func _has_completed_necoc_yaotl() -> bool:
	return necoc_yaotl_sacrifices.size() >= REQUIRED_NECOC_YAOTL_SACRIFICES

func _is_valid_necoc_yaotl_sacrifice(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.get_controller() == card_owner \
		and card.can_be_used_for_creature_sacrifice \
		and card.current_zone != null \
		and card.current_zone.is_board_zone()

func _get_necoc_yaotl_candidate(allow_fallback: bool = true) -> Card:
	if card_owner == null:
		return null
	var reserved_manifestation := get_reserved_active_god_candidate()
	if reserved_manifestation != null:
		return reserved_manifestation
	for zone in [
		card_owner.hand_zone,
		card_owner.deck_zone,
		card_owner.graveyard_zone,
	] + card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			var active_god := card as ActiveGodCard
			if active_god == null or active_god.get_linked_god_name() != card_name:
				continue
			if card.current_zone != null and card.current_zone.is_board_zone():
				return null
			return card
	if allow_fallback:
		var manifestation := TEZCATLIPOCA_ACTIVE_SCRIPT.new()
		manifestation.card_owner = card_owner
		return manifestation
	return null

func can_autofill_take_the_field() -> bool:
	return true
