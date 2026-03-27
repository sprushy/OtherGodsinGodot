extends PowerCard
class_name MechFactory

const UNLOCK_COST := 3
const ACTIVATION_COST := 3
const MAX_ACTIVATIONS_PER_TURN := 2
const ART_PATH := "res://images/card_art/powers/Mech_Factory.jpg"

var activations_this_turn: int = 0

func _init() -> void:
	super._init()
	card_name = "Mech Factory"
	culture = "Atlanitan"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Constructs", "Summon Creature", "Factory"]
	ability_text = "[b]Unlock[/b] (3): [b]Activate[/b] - Pay 3 mana to summon an unsacrificable [b]Combat Mech[/b] token with LV2, SPD 1, RES 18, and STR 18. Activate only twice per turn."
	artist = "Stanley Vay"
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and not is_muted \
		and not is_activation_locked(game_manager) \
		and card_owner == game_manager.current_player \
		and card_owner.mana >= ACTIVATION_COST \
		and activations_this_turn < MAX_ACTIVATIONS_PER_TURN \
		and _find_open_summon_zone() != null

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	var summon_zone := _find_open_summon_zone()
	if summon_zone == null:
		return
	if not card_owner.spend_mana(ACTIVATION_COST):
		return

	var token := CombatMech.new()
	token.card_owner = card_owner
	token.creature_mode = Card.CreatureMode.AGGRESSIVE
	token.reset_creature_action_state()
	token.summoned_this_turn = true
	token.is_face_down = false
	token.is_stealth = false
	token.wake_up()
	summon_zone.add_card(token)
	if game_manager != null and game_manager.has_method("_apply_god_passives_to_card"):
		game_manager._apply_god_passives_to_card(card_owner, token)

	activations_this_turn += 1
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s built a Combat Mech token (%d/%d activations used this turn)." % [
				card_name,
				activations_this_turn,
				MAX_ACTIVATIONS_PER_TURN
			]
		)

func on_turn_start(_game_manager: GameManager) -> void:
	activations_this_turn = 0

func _find_open_summon_zone() -> Zone:
	if card_owner == null:
		return null
	for zone in card_owner.frontline_zones:
		if zone.cards.is_empty():
			return zone
	for zone in card_owner.reserve_zones:
		if zone.cards.is_empty():
			return zone
	return null
