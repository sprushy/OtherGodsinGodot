extends CreatureCard
class_name ClayEaters

const GEOPHAGIA_COST := 2

var pending_geophagia_targets: Array[Card] = []

func _init() -> void:
	super._init()
	card_name = "Clay-Eaters"
	card_types = ["Undead", "Horde", "Ancient Creature"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 15
	strength = 15
	ability_text = "Geophagia ([b]Activate[/b], Cost 2): Choose a structure. At the end of your turn, destroy it if this card is still on the field."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/Clay-eaters(web).jpg"
	targets = true

func get_activation_label() -> String:
	return "Geophagia"

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
	if card_owner == null or card_owner.mana < GEOPHAGIA_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card.card_type == Card.CardType.STRUCTURE:
					valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if target == null or target not in get_valid_targets(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback("%s fizzles: invalid structure target." % card_name)
		return
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		game_manager.note_player_feedback("%s fizzles: %s is immune to creature abilities." % [card_name, target.card_name])
		return
	if not card_owner.spend_mana(GEOPHAGIA_COST):
		return
	if not pending_geophagia_targets.has(target):
		pending_geophagia_targets.append(target)
	if game_manager != null:
		game_manager.note_player_feedback("%s marked %s with Geophagia." % [card_name, target.card_name])

func on_turn_end(game_manager: GameManager) -> void:
	if pending_geophagia_targets.is_empty():
		return
	var queued_targets := pending_geophagia_targets.duplicate()
	pending_geophagia_targets.clear()
	if current_zone == null or not current_zone.is_board_zone():
		return
	for target in queued_targets:
		if target == null:
			continue
		if target.current_zone == null or not target.current_zone.is_board_zone():
			continue
		if target.card_type != Card.CardType.STRUCTURE:
			continue
		if game_manager != null and game_manager.is_immune_to_source(target, self):
			game_manager.note_player_feedback("%s survives Geophagia because it is immune to creature abilities." % target.card_name)
			continue
		game_manager.note_player_feedback("%s devoured %s at end of turn." % [card_name, target.card_name])
		game_manager._send_to_graveyard_with_hook(target, false, true)

func on_removed(_game_manager: GameManager) -> void:
	pending_geophagia_targets.clear()
