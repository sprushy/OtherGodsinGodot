extends CreatureCard
class_name Alu

func _init() -> void:
	super._init()
	card_name = "Alu"
	card_types = ["Demon", "Ancient Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 16
	strength = 19
	ability_text = "Stupefy: Use this card's action to put an equal- or lower-level creature to [b]Sleep[/b] while Alu remains on the field."
	flavor_text = ""
	culture = "Ancient"
	art_path = "res://images/card_art/creatures/alu.jpg"
	targets = true

func get_activation_label() -> String:
	return "Stupefy"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed():
		return false
	if is_sleeping:
		return false
	if not can_take_major_creature_action():
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card == self:
					continue
				if card.card_type != Card.CardType.CREATURE:
					continue
				if card.get_effective_level() > get_effective_level():
					continue
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if target == null or target not in get_valid_targets(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: choose a creature of level %d or lower." % [card_name, get_effective_level()])
		return
	if game_manager != null and game_manager.is_guardian_protected(target, self):
		game_manager.note_player_feedback(target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is protected by Guardian!")
		return
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback(target.get_target_log_display_name(game_manager.get_feedback_viewer()) + " is immune to " + card_name + "'s creature abilities this turn.")
		return
	stupefy(target)
	if game_manager != null:
		game_manager.note_player_feedback("%s stupefied %s." % [card_name, target.get_target_log_display_name(game_manager.get_feedback_viewer())])

func stupefy(target: Card) -> void:
	target.apply_sleep(self)
	spend_major_creature_action()
	print(card_name + " stupefies " + target.card_name + "! It falls asleep.")

func on_removed(game_manager: GameManager) -> void:
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card.sleeping_from == self:
					card.remove_status_effects_from_source_card(self, "sleep")
					print(card.card_name + " wakes up - " + card_name + " left the field.")
