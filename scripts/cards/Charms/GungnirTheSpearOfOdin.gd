extends CharmCard
class_name GungnirTheSpearOfOdin

const ART_PATH := "res://images/card_art/charms/gungnir_the_spear_of_odin.png"

func _init() -> void:
	super._init()
	card_name = "Gungnir, the Spear of Odin"
	culture = "Norse"
	card_types = ["Charm", "Combat Aid", "Runic", "Destruction"]
	level = 3
	mana_cost = 1
	speed = 3
	is_legendary = false
	targets = false
	flavor_text = ""
	ability_text = "When one of your Norse Warriors attacks, destroy its attack target."
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func can_respond_to_action(action: CardAction, _game_manager: GameManager = null) -> bool:
	if action == null or action.type != CardAction.Type.ATTACK:
		return false
	if action.attacker == null:
		return false
	if action.attacker.get_controller() != card_owner:
		return false
	if not _is_norse_warrior(action.attacker):
		return false
	var combat_target := _get_combat_target(action)
	if combat_target == null:
		return false
	return get_effective_speed() >= action.get_timing_speed()

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return

	# Find the triggering Norse Warrior attack on the stack.
	var combat_target: Card = null
	for action in game_manager.action_stack:
		if action.type != CardAction.Type.ATTACK:
			continue
		if action.attacker == null or action.attacker.get_controller() != card_owner:
			continue
		if not _is_norse_warrior(action.attacker):
			continue
		combat_target = _get_combat_target(action)
		break

	if combat_target == null or combat_target.current_zone == null or not combat_target.current_zone.is_board_zone():
		game_manager.note_player_feedback("%s fizzles: attack target not found." % card_name)
		return

	if game_manager.is_immune_to_source(combat_target, self):
		game_manager.note_player_feedback(
			"%s fizzles: %s is immune." % [card_name, combat_target.card_name]
		)
		return

	game_manager.note_player_feedback(
		"%s destroys %s." % [card_name, combat_target.card_name]
	)
	game_manager.request_send_to_graveyard(combat_target, Callable(), false, true)

func _is_norse_warrior(card: Card) -> bool:
	if card == null or card.card_type != Card.CardType.CREATURE:
		return false
	if not card.has_type("Warrior"):
		return false
	return card.culture == "Norse"

func _get_combat_target(action: CardAction) -> Card:
	if action == null:
		return null
	var target: Card = null
	if action.interceptor != null:
		target = action.interceptor
	else:
		target = action.target as Card
	if target == null or target.current_zone == null or not target.current_zone.is_board_zone():
		return null
	return target
