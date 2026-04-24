extends CreatureCard
class_name WolfCub

const ART_PATH := "res://images/card_art/creatures/WolfCubEdit.png"

func _init() -> void:
	super._init()
	card_name = "Wolf Cub"
	card_types = ["Animal", "Lupine", "Norse Creature"]
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 3
	strength = 10
	ability_text = "[b]Maturation[/b] ([b]Upkeep[/b]): You may send this creature to the graveyard to summon a level 4 or lower Lupine from your deck to the field."
	flavor_text = ""
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func on_turn_start(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var controller := get_controller()
	if controller == null or controller != game_manager.current_player:
		return
	if abilities_suppressed() or is_face_down or is_stealth:
		return
	if current_zone == null or not current_zone.is_board_zone():
		return

	var valid_targets := get_valid_maturation_targets()
	if valid_targets.is_empty():
		game_manager.note_player_feedback("%s matured, but found no level 4 or lower Lupine in the deck." % card_name)
		return

	var target_zone := current_zone
	var chosen_target := valid_targets[0]
	game_manager.request_send_to_graveyard(self, func() -> void:
		if target_zone == null or not target_zone.cards.is_empty():
			game_manager.note_player_feedback("%s matured, but there was no open lane for %s." % [
				card_name,
				chosen_target.card_name
			])
			return
		var summoned := game_manager.summon_creature_without_cost(
			controller,
			chosen_target,
			target_zone,
			Card.CreatureMode.AGGRESSIVE
		)
		if summoned:
			game_manager.note_player_feedback("%s matures into %s from the deck." % [
				card_name,
				chosen_target.card_name
			])
		else:
			game_manager.note_player_feedback("%s matured, but %s could not be summoned." % [
				card_name,
				chosen_target.card_name
			])
	, false, false)

func get_valid_maturation_targets() -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null or controller.deck_zone == null:
		return valid_targets
	for card in controller.deck_zone.cards:
		if _is_valid_maturation_target(card, controller):
			valid_targets.append(card)
	return valid_targets

func _is_valid_maturation_target(card: Card, controller: Player) -> bool:
	return card != null \
		and controller != null \
		and card.current_zone == controller.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Lupine") \
		and card.get_effective_level() <= 4
