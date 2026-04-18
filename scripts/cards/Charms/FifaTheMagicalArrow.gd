extends CharmCard
class_name FifaTheMagicalArrow

const STR_BONUS := 5
const BUYBACK_COST := 4
const BUFF_SOURCE := "Fifa the Magical Arrow"

var _buyback_archer: Card = null
var _buyback_turn_number: int = -1
var _buyback_event_start_index: int = -1

func _init() -> void:
	super._init()
	card_name = "Fifa the Magical Arrow"
	culture = "Norse"
	card_types = ["Charm", "Steel", "Warrior Buff"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 3
	mana_cost = 0
	speed = 2
	is_legendary = false
	targets = true
	flavor_text = ""
	ability_text = "Choose a friendly Warrior. It gains +5 STR until the end of its next combat. This turn, if the enchanted Archer destroys an attack target, you may pay 4 graveyard mana to return this to your hand."
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/FifaAIEdit.png"

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		var creature := zone.get_creature()
		if is_valid_target(creature):
			valid_targets.append(creature)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() == card_owner \
		and target.has_type("Warrior")

func resolve(game_manager: GameManager, target: Card = null) -> void:
	_clear_buyback_state()
	if not is_valid_target(target):
		print(card_name + " requires a friendly Warrior.")
		return
	if game_manager == null:
		return

	target.add_buff(
		BUFF_SOURCE,
		STR_BONUS,
		0,
		0,
		self,
		card_owner,
		"charm_buff",
		{"expires_after_combat": true}
	)

	var viewer: Player = game_manager.get_feedback_viewer()
	var target_name: String = target.get_target_log_display_name(viewer)
	var feedback: String = "%s gives %s +%d Str until the end of its next combat." % [
		card_name,
		target_name,
		STR_BONUS
	]

	if target.has_type("Archer"):
		_arm_buyback(target, game_manager)
		feedback += " If that Archer destroys an attack target later this turn, %s can return from the graveyard for %d mana." % [
			card_name,
			BUYBACK_COST
		]

	game_manager.note_player_feedback(feedback)
	print(feedback)

func has_pending_buyback_offer(game_manager: GameManager = null) -> bool:
	return can_activate_from_graveyard(game_manager)

func get_buyback_mana_cost() -> int:
	return BUYBACK_COST

func get_buyback_prompt_text() -> String:
	return "Pay %d mana to return %s from the graveyard to your hand?" % [BUYBACK_COST, card_name]

func resolve_buyback_choice(game_manager: GameManager, pay_cost: bool) -> String:
	if not pay_cost:
		return card_name + " stays in the graveyard."
	return activate_from_graveyard(game_manager)

func can_show_graveyard_hand_proxy(game_manager: GameManager) -> bool:
	return can_activate_from_graveyard(game_manager)

func get_graveyard_hand_proxy_mana_cost() -> int:
	return BUYBACK_COST

func can_activate_from_graveyard(game_manager: GameManager) -> bool:
	if not _has_buyback_window(game_manager):
		return false
	if not _buyback_condition_met(game_manager):
		return false
	return card_owner != null and card_owner.mana >= BUYBACK_COST

func activate_from_graveyard(game_manager: GameManager) -> String:
	if not _has_buyback_window(game_manager):
		return card_name + " can only return on the turn it was used."
	if not _buyback_condition_met(game_manager):
		return card_name + " is waiting for its enchanted Archer to destroy an attack target this turn."
	if card_owner == null:
		return card_name + " has no owner to return it."
	if card_owner.mana < BUYBACK_COST:
		return card_name + " needs %d mana to return." % BUYBACK_COST
	card_owner.spend_mana(BUYBACK_COST)
	card_owner.move_card(self, card_owner.hand_zone)
	_clear_buyback_state()
	return "%s returns from the graveyard to %s's hand for %d mana." % [
		card_name,
		card_owner.player_name,
		BUYBACK_COST
	]

func on_global_turn_end(game_manager: GameManager, _ending_player: Player) -> void:
	if game_manager == null:
		return
	if _buyback_turn_number == game_manager.turn_number:
		_clear_buyback_state()

func _arm_buyback(target: Card, game_manager: GameManager) -> void:
	if game_manager == null or target == null:
		return
	_buyback_archer = target
	_buyback_turn_number = game_manager.turn_number
	_buyback_event_start_index = game_manager.combat_destroy_events_this_turn.size()

func _clear_buyback_state() -> void:
	_buyback_archer = null
	_buyback_turn_number = -1
	_buyback_event_start_index = -1

func _has_buyback_window(game_manager: GameManager) -> bool:
	return game_manager != null \
		and card_owner != null \
		and current_zone == card_owner.graveyard_zone \
		and _buyback_archer != null \
		and _buyback_turn_number == game_manager.turn_number

func _buyback_condition_met(game_manager: GameManager) -> bool:
	if not _has_buyback_window(game_manager):
		return false
	return game_manager.card_destroyed_attack_target_since(_buyback_archer, _buyback_event_start_index)
