extends CreatureCard
class_name Lamashatu

const ART_PATH := "res://images/card_art/creatures/LamashatuEdit.png"
const SUCKLE_SOURCE := "Lamashatu Suckle"
const SUCKLE_LEVEL_BONUS := 1
const SUCKLE_SPEED_BONUS := 1
const SUCKLE_STRENGTH_BONUS := 5
const SUCKLE_RESILIENCE_BONUS := 5

func _init() -> void:
	super._init()
	card_name = "Lamashatu"
	card_types = ["Demon", "Ancient Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 4
	mana_cost = 3
	sacrifice_cost = 0
	speed = 1
	resilience = 26
	strength = 23
	targets = true
	ability_text = "[b]Suckle[/b] ([b]Activate[/b]): Once per turn, choose another friendly Demon or Animal. It gains +1 Lvl, +1 Spd, +5 Str, and +5 Res until end of turn."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func get_activation_label() -> String:
	return "Suckle"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed() or is_activation_locked(game_manager):
		return false
	if is_sleeping:
		return false
	if is_used:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if game_manager == null or controller == null:
		return valid_targets
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if _is_valid_suckle_target(card):
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s cannot use Suckle right now." % card_name)
		return
	if target == null or target not in get_valid_targets(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose another friendly Demon or Animal." % card_name)
		return
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback(
			"%s is immune to %s's creature abilities this turn." % [
				target.get_target_log_display_name(game_manager.get_feedback_viewer()),
				card_name,
			]
		)
		return

	target.remove_buffs_from_source_card(self, "suckle")
	target.add_buff(
		SUCKLE_SOURCE,
		SUCKLE_STRENGTH_BONUS,
		SUCKLE_RESILIENCE_BONUS,
		SUCKLE_SPEED_BONUS,
		self,
		card_owner,
		"suckle",
		{
			"lvl": SUCKLE_LEVEL_BONUS,
			"expires_turn": game_manager.turn_number,
		}
	)
	is_used = true
	if game_manager != null:
		game_manager.note_player_feedback(
			"%s suckles %s, granting +1 Lvl, +1 Spd, +5 Str, and +5 Res until end of turn." % [
				card_name,
				target.get_target_log_display_name(game_manager.get_feedback_viewer()),
			]
		)

func on_turn_end(_game_manager: GameManager) -> void:
	is_used = false

func _is_valid_suckle_target(target: Card) -> bool:
	return target != null \
		and target != self \
		and target.card_type == Card.CardType.CREATURE \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() == get_controller() \
		and (target.has_type("Demon") or target.has_type("Animal"))
