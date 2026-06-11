extends PowerCard
class_name WalkOfTheSage

const UNLOCK_COST := 1
const ACTIVATION_COST := 2
const ART_PATH := "res://images/card_art/powers/Walk of the Sage(web).jpg"

func _init() -> void:
	super._init()
	card_name = "Walk of the Sage"
	culture = "Ancient"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Void", "Creature", "Search"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	targets = true
	ability_text = "[b]Unlock[/b] (%d): [b]Activate[/b] - Pay %d mana: [b]Void[/b] a Mage from your deck." % [UNLOCK_COST, ACTIVATION_COST]
	flavor_text = ""
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	return super.can_activate(game_manager) \
		and can_pay_activation_costs(ACTIVATION_COST, game_manager) \
		and not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_face_down:
		return card_name + " must be unlocked first."
	if is_muted:
		return card_name + " is muted."
	if is_activation_locked(game_manager):
		return card_name + " cannot be activated this turn."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	var activation_cost := get_activation_mana_cost(ACTIVATION_COST, game_manager)
	if card_owner == null or card_owner.mana < activation_cost:
		return card_name + " needs " + str(activation_cost) + " mana."
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no Mage in your deck to void."
	return card_name + " cannot activate right now."

func get_activation_cost_hover_data(_game_manager: GameManager = null) -> Dictionary:
	return {
		"base_cost": ACTIVATION_COST,
		"cost_kind": Card.COST_KIND_POWER_ACTIVATION,
		"label": "Activation Cost",
	}

func get_valid_targets(_game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if card_owner == null or card_owner.deck_zone == null:
		return valid_targets
	for card in card_owner.deck_zone.cards:
		if _is_valid_target(card):
			valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	if not _is_valid_target(target):
		game_manager.note_player_feedback("%s fizzles: choose a Mage from your deck." % card_name)
		return
	if not pay_activation_costs(ACTIVATION_COST, game_manager):
		game_manager.note_player_feedback("%s needs %d mana." % [card_name, get_activation_mana_cost(ACTIVATION_COST, game_manager)])
		return

	var controller := card_owner
	controller.move_card(target, controller.abyss_zone)
	if controller.deck_zone != null:
		controller.deck_zone.cards.shuffle()

	game_manager.note_player_feedback(
		"%s voids %s from %s's deck." % [
			card_name,
			target.card_name,
			controller.player_name
		]
	)

func _is_valid_target(card: Card) -> bool:
	return card != null \
		and card_owner != null \
		and card.current_zone == card_owner.deck_zone \
		and card.card_type == Card.CardType.CREATURE \
		and not card.is_god \
		and card.has_type("Mage")
