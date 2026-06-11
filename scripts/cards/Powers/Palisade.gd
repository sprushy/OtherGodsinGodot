extends PowerCard
class_name PalisadePower

const UNLOCK_COST := 1
const ACTIVATION_COST := 4
const ART_PATH := "res://images/card_art/structures/PalisadeArtEdit.png"
const PALISADE_STRUCTURE_SCRIPT := preload("res://scripts/cards/Structures/PalisadeBarrier.gd")

func _init() -> void:
	super._init()
	card_name = "Palisade"
	culture = "Neutral"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Construct", "Summon Structure", "Defense"]
	targets = false
	flavor_text = ""
	ability_text = "[b]Unlock[/b] (%d): [b]Activate[/b] - Pay %d mana to add a LV3, 25 RES Palisade structure to the field. Cards and followers on the line behind it cannot be attacked except by Aerial creatures." % [UNLOCK_COST, ACTIVATION_COST]
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	if not super.can_activate(game_manager):
		return false
	var summon_zone := _find_open_summon_zone()
	if summon_zone == null:
		return false
	var summon_tax := _get_summon_tax(game_manager)
	return card_owner != null and card_owner.mana >= get_activation_mana_cost(ACTIVATION_COST, game_manager) + summon_tax

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
	if _find_open_summon_zone() == null:
		return card_name + " needs an open lane for the structure."
	var total_cost := get_activation_mana_cost(ACTIVATION_COST, game_manager) + _get_summon_tax(game_manager)
	if card_owner == null or card_owner.mana < total_cost:
		return card_name + " needs " + str(total_cost) + " mana."
	return card_name + " cannot activate right now."

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return

	var summon_zone := _find_open_summon_zone()
	if summon_zone == null:
		game_manager.note_player_feedback(card_name + " fizzles: no open lane for the Palisade.")
		return

	var activation_cost := get_activation_mana_cost(ACTIVATION_COST, game_manager)
	if not spend_activation_mana(ACTIVATION_COST, game_manager):
		game_manager.note_player_feedback(card_name + " needs " + str(activation_cost) + " mana.")
		return

	var structure := PALISADE_STRUCTURE_SCRIPT.new()
	structure.card_owner = card_owner
	var summoned := game_manager != null and game_manager.summon_structure_by_effect(card_owner, structure, summon_zone, self, false, true)
	if not summoned:
		card_owner.gain_mana(activation_cost)
		game_manager.note_player_feedback(card_name + " fizzles: the Palisade could not be added to the field.")
		return

	game_manager.note_player_feedback("%s adds a Palisade to the field." % card_name)

func get_activation_cost_hover_data(game_manager: GameManager = null) -> Dictionary:
	return {
		"base_cost": ACTIVATION_COST,
		"current_cost": get_activation_mana_cost(ACTIVATION_COST, game_manager) + _get_summon_tax(game_manager),
		"cost_kind": Card.COST_KIND_POWER_ACTIVATION,
		"label": "Activation Cost",
	}

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

func _get_summon_tax(game_manager: GameManager) -> int:
	if game_manager == null or card_owner == null:
		return 0
	var preview_structure := PALISADE_STRUCTURE_SCRIPT.new()
	preview_structure.card_owner = card_owner
	return game_manager.get_card_summon_mana_cost(card_owner, preview_structure, self, true)
