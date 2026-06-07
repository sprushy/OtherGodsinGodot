# PowerCard.gd
# Base class for all power cards.
#
# Powers are selected before the game and live in the player's power_zones.
# They start face-down (locked). The player pays mana_cost to unlock (flip face-up).
# Once unlocked, the power's passive applies and/or its activatable ability becomes usable.
extends BaseCard
class_name PowerCard

const PowerUnlockSoundPlayerScript = preload("res://scripts/audio/PowerUnlockSoundPlayer.gd")

var is_publicly_revealed: bool = false
var _pending_activation_discards: Array[Card] = []

func _init() -> void:
	super._init()
	card_type = CardType.POWER
	is_power = true
	ability_immunity_tag = "powers"
	is_face_down = true   # locked until the player pays mana_cost to unlock

# ── Unlock (flip) ─────────────────────────────────────────────────────────────

func can_unlock(game_manager: GameManager) -> bool:
	if not is_face_down:
		return false
	if is_muted:
		return false
	if game_manager != null and card_owner != null and game_manager.has_method("can_player_use_powers") and not game_manager.can_player_use_powers(card_owner):
		return false
	if is_activation_locked(game_manager):
		return false
	if card_owner != game_manager.current_player:
		return false
	return can_pay_costs_with_mana_cost(card_owner, get_unlock_mana_cost(game_manager))

func unlock(game_manager: GameManager) -> void:
	var unlock_cost := get_unlock_mana_cost(game_manager)
	if not pay_costs_with_mana_cost(card_owner, unlock_cost, game_manager):
		return
	if game_manager != null and unlock_cost < mana_cost:
		game_manager.claim_cost_adjustments(self, mana_cost, Card.COST_KIND_POWER_UNLOCK)
	is_face_down = false
	remove_status_effects_with_flag("clear_when_hidden_state_ends")
	is_publicly_revealed = false
	is_muted = false
	mute_turns_remaining = 0
	_mute_applied_owner_turn_number = -1
	PowerUnlockSoundPlayerScript.play_sequence()
	on_unlock(game_manager)

# Called immediately when the power is flipped face-up.
# Override for passive or immediate on-unlock effects.
func on_unlock(_game_manager: GameManager) -> void:
	pass

# ── Activatable ability ────────────────────────────────────────────────────────

# Override to add conditions (mana check, once-per-turn, etc.)
func can_activate(game_manager: GameManager) -> bool:
	if is_face_down:
		return false
	if is_muted:
		return false
	if game_manager != null and card_owner != null and game_manager.has_method("can_player_use_powers") and not game_manager.can_player_use_powers(card_owner):
		return false
	if is_activation_locked(game_manager):
		return false
	if card_owner != game_manager.current_player:
		return false
	return true

# Override to implement the ability. target is null for untargeted abilities.
func activate(_game_manager: GameManager, _target: Card = null) -> void:
	pass

func get_unlock_mana_cost(game_manager: GameManager = null) -> int:
	return get_adjusted_mana_cost(mana_cost, Card.COST_KIND_POWER_UNLOCK, game_manager)

func get_unlock_display_mana_cost(game_manager: GameManager = null) -> int:
	return get_unlock_mana_cost(game_manager)

func get_unlock_display_cost_shorthand(
	game_manager: GameManager = null,
	force_show_mana: bool = false
) -> String:
	return get_cost_shorthand(get_unlock_display_mana_cost(game_manager), force_show_mana)

func should_include_unlock_cost_summary_line(game_manager: GameManager = null) -> bool:
	var unlock_cost := get_unlock_display_mana_cost(game_manager)
	if unlock_cost <= 0:
		return true
	return not _mentions_inline_unlock_mana_cost(get_display_ability_text(game_manager).to_lower(), unlock_cost)

func get_unlock_display_cost_lines(game_manager: GameManager = null) -> Array[String]:
	var lines: Array[String] = []
	var unlock_cost := get_unlock_display_mana_cost(game_manager)
	if should_include_unlock_cost_summary_line(game_manager):
		lines.append("Unlock Cost: %d" % unlock_cost)
	if discard_cost > 0:
		lines.append("Discard: %d" % discard_cost)
	for breakdown_line in get_cost_adjustment_lines(mana_cost, Card.COST_KIND_POWER_UNLOCK, game_manager):
		lines.append(breakdown_line)
	return lines

func get_activation_mana_cost(base_cost: int, game_manager: GameManager = null) -> int:
	return get_adjusted_mana_cost(base_cost, Card.COST_KIND_POWER_ACTIVATION, game_manager)

func get_activation_discard_cost() -> int:
	return 0

func requires_activation_hand_discards() -> bool:
	return get_activation_discard_cost() > 0

func get_valid_activation_discards() -> Array[Card]:
	var choices: Array[Card] = []
	if card_owner == null or card_owner.hand_zone == null:
		return choices
	for card in card_owner.hand_zone.cards:
		if card != null and card != self:
			choices.append(card)
	return choices

func set_pending_activation_discards(cards: Array[Card]) -> void:
	_pending_activation_discards = cards.duplicate()

func clear_pending_activation_discards() -> void:
	_pending_activation_discards.clear()

func has_pending_activation_discards_for_cost() -> bool:
	var activation_discard_cost := get_activation_discard_cost()
	if activation_discard_cost <= 0:
		return true
	if _pending_activation_discards.size() < activation_discard_cost:
		return false
	for i in range(activation_discard_cost):
		var card := _pending_activation_discards[i]
		if card == null or card == self or card_owner == null or card.current_zone != card_owner.hand_zone:
			return false
	return true

func can_pay_activation_costs(base_cost: int, game_manager: GameManager = null) -> bool:
	var activation_cost := get_activation_mana_cost(base_cost, game_manager)
	if card_owner == null:
		return false
	if card_owner.mana < activation_cost:
		return false
	if card_owner.hand_zone == null or card_owner.hand_zone.get_card_count() < get_activation_discard_cost():
		return false
	return true

func spend_activation_mana(base_cost: int, game_manager: GameManager = null) -> bool:
	var activation_cost := get_activation_mana_cost(base_cost, game_manager)
	if card_owner == null or card_owner.mana < activation_cost:
		return false
	if not card_owner.spend_mana(activation_cost):
		return false
	if game_manager != null and activation_cost < base_cost:
		game_manager.claim_cost_adjustments(self, base_cost, Card.COST_KIND_POWER_ACTIVATION)
	return true

func pay_activation_costs(base_cost: int, game_manager: GameManager = null) -> bool:
	if not can_pay_activation_costs(base_cost, game_manager):
		clear_pending_activation_discards()
		return false
	if base_cost > 0 and not spend_activation_mana(base_cost, game_manager):
		clear_pending_activation_discards()
		return false

	var activation_discard_cost := get_activation_discard_cost()
	for i in range(activation_discard_cost):
		if _pending_activation_discards.size() > i:
			var chosen_discard := _pending_activation_discards[i]
			if chosen_discard != null and chosen_discard.current_zone == card_owner.hand_zone and chosen_discard != self:
				card_owner.discard_card(chosen_discard)
				continue
		if card_owner.hand_zone.get_card_count() <= 0:
			break
		var discard_card := card_owner.hand_zone.cards[0]
		if discard_card == self and card_owner.hand_zone.get_card_count() > 1:
			discard_card = card_owner.hand_zone.cards[1]
		if discard_card != self:
			card_owner.discard_card(discard_card)

	clear_pending_activation_discards()
	return true

func get_unlock_cost_adjustment_lines(game_manager: GameManager = null) -> Array[String]:
	return get_cost_adjustment_lines(mana_cost, Card.COST_KIND_POWER_UNLOCK, game_manager)

func get_activation_cost_hover_data(_game_manager: GameManager = null) -> Dictionary:
	return {}

func should_include_activation_cost_summary_line(game_manager: GameManager = null) -> bool:
	var cost_data := _get_display_ability_cost_data(game_manager)
	if cost_data.is_empty():
		return true
	var current_cost: int = int(cost_data.get("current_cost", 0))
	if current_cost <= 0:
		return false
	return not _mentions_inline_activation_mana_cost(get_display_ability_text(game_manager).to_lower(), current_cost)

func _get_display_ability_cost_data(game_manager: GameManager = null) -> Dictionary:
	if ability_text == "" or game_manager == null:
		return {}

	var hover_data: Dictionary = get_activation_cost_hover_data(game_manager)
	if hover_data.is_empty():
		return {}

	var base_cost: int = int(hover_data.get("base_cost", 0))
	if base_cost <= 0:
		return {}

	var cost_kind: String = str(hover_data.get("cost_kind", Card.COST_KIND_POWER_ACTIVATION))
	var metadata: Dictionary = hover_data.get("metadata", {})
	var current_cost := get_adjusted_mana_cost(base_cost, cost_kind, game_manager, metadata)
	return {
		"base_cost": base_cost,
		"current_cost": current_cost,
	}

func _replace_display_ability_cost_text(
	text: String,
	base_cost: int,
	capitalized_replacement: String,
	lowercase_replacement: String
) -> String:
	var updated_text := text
	updated_text = updated_text.replace("Pay %d mana" % base_cost, capitalized_replacement)
	updated_text = updated_text.replace("pay %d mana" % base_cost, lowercase_replacement)
	return updated_text

func get_display_ability_text(game_manager: GameManager = null) -> String:
	var cost_data: Dictionary = _get_display_ability_cost_data(game_manager)
	if cost_data.is_empty():
		return ability_text

	var base_cost: int = int(cost_data.get("base_cost", 0))
	var current_cost: int = int(cost_data.get("current_cost", base_cost))
	return _replace_display_ability_cost_text(
		ability_text,
		base_cost,
		"Pay %d mana" % current_cost,
		"pay %d mana" % current_cost
	)

func get_display_ability_bbcode_text(game_manager: GameManager = null) -> String:
	var cost_data: Dictionary = _get_display_ability_cost_data(game_manager)
	if cost_data.is_empty():
		return ability_text

	var base_cost: int = int(cost_data.get("base_cost", 0))
	var current_cost: int = int(cost_data.get("current_cost", base_cost))
	var capitalized_replacement := "Pay %d mana" % current_cost
	var lowercase_replacement := "pay %d mana" % current_cost
	if current_cost < base_cost:
		capitalized_replacement = "[color=#66ff66]%s[/color]" % capitalized_replacement
		lowercase_replacement = "[color=#66ff66]%s[/color]" % lowercase_replacement
	elif current_cost > base_cost:
		capitalized_replacement = "[color=#ff6666]%s[/color]" % capitalized_replacement
		lowercase_replacement = "[color=#ff6666]%s[/color]" % lowercase_replacement
	return _replace_display_ability_cost_text(
		ability_text,
		base_cost,
		capitalized_replacement,
		lowercase_replacement
	)

func _mentions_inline_unlock_mana_cost(display_text: String, mana_amount: int) -> bool:
	if display_text == "" or mana_amount <= 0:
		return false
	return display_text.contains("[b]unlock[/b] (%d" % mana_amount)

func _mentions_inline_activation_mana_cost(display_text: String, mana_amount: int) -> bool:
	if display_text == "" or mana_amount <= 0:
		return false
	return display_text.contains("pay %d mana" % mana_amount) \
		or display_text.contains("(%d mana" % mana_amount) \
		or display_text.contains(", %d mana" % mana_amount)

func get_unlock_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot unlock right now."
	if not is_face_down:
		return card_name + " is already unlocked."
	if is_muted:
		return card_name + " is muted."
	if card_owner != null and game_manager.has_method("can_player_use_powers") and not game_manager.can_player_use_powers(card_owner):
		return "[b]God Death[/b] prevents powers from being used."
	if is_activation_locked(game_manager):
		return card_name + " cannot be unlocked this turn."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to unlock."
	var unlock_cost := get_unlock_mana_cost(game_manager)
	if card_owner == null or card_owner.mana < unlock_cost:
		return card_name + " needs " + str(unlock_cost) + " mana to unlock."
	if discard_cost > 0 and card_owner.hand_zone.get_card_count() < discard_cost:
		return card_name + " needs " + str(discard_cost) + " discard(s) to unlock."
	if not can_pay_costs_with_mana_cost(card_owner, unlock_cost):
		return card_name + " cannot pay its unlock costs right now."
	return card_name + " cannot unlock right now."

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_face_down:
		return card_name + " must be unlocked first."
	if is_muted:
		return card_name + " is muted."
	if card_owner != null and game_manager.has_method("can_player_use_powers") and not game_manager.can_player_use_powers(card_owner):
		return "[b]God Death[/b] prevents powers from being used."
	if is_activation_locked(game_manager):
		return card_name + " cannot be activated this turn."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	var activation_discard_cost := get_activation_discard_cost()
	if activation_discard_cost > 0 and (card_owner == null or card_owner.hand_zone.get_card_count() < activation_discard_cost):
		return card_name + " needs " + str(activation_discard_cost) + " discard(s)."
	return card_name + " cannot activate right now."

func relock() -> void:
	is_face_down = true
	is_publicly_revealed = false
	is_used = false
	_mute_applied_owner_turn_number = -1

func is_effectively_active() -> bool:
	return not is_face_down and not is_muted

func reveal_while_face_down() -> void:
	is_publicly_revealed = true

func on_turn_end(game_manager: GameManager) -> void:
	super.on_turn_end(game_manager)
