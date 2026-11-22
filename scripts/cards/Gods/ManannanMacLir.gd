extends GodCard
class_name ManannanMacLir

const ACTIVATION_COST := 2
const ACTIVATION_MODE := Card.CreatureMode.DEFENSIVE

func _init() -> void:
	super._init()
	card_name = "Manannán mac Lir"
	card_types = ["Sea", "Guardian"]
	mana_cost = 0
	culture = "Triskelion"
	targets = false
	flavor_text = ""
	ability_text = "Mists of the Blessed Isles ([b]Activate[/b], %d mana): Put all your Triskelion creatures into stealth stance." % ACTIVATION_COST
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/gods/MannanMacLirEdit.png"
	paragon_of_champions = "Sea"

func can_activate(game_manager: GameManager) -> bool:
	if not can_use_god_power(game_manager):
		return false
	if card_owner == null or card_owner.mana < ACTIVATION_COST:
		return false
	return not get_valid_targets(game_manager).is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if game_manager == null:
		return card_name + " cannot activate right now."
	if is_muted:
		return card_name + " is muted."
	if card_owner != game_manager.current_player:
		return "It is not " + card_name + "'s turn to act."
	if card_owner == null or card_owner.mana < ACTIVATION_COST:
		return card_name + " needs " + str(ACTIVATION_COST) + " mana."
	if get_valid_targets(game_manager).is_empty():
		return "Mists of the Blessed Isles has no friendly Triskelion creatures to hide."
	return ""

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if is_valid_activation_target(card, game_manager):
				valid_targets.append(card)
	return valid_targets

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if game_manager == null:
		return
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		game_manager.note_player_feedback("Mists of the Blessed Isles fizzles: no friendly Triskelion creatures can enter stealth.")
		return
	if not card_owner.spend_mana(ACTIVATION_COST):
		game_manager.note_player_feedback(card_name + " needs " + str(ACTIVATION_COST) + " mana.")
		return

	var viewer := game_manager.get_feedback_viewer()
	var hidden_names: Array[String] = []
	for creature in valid_targets:
		_apply_stealth_stance(creature)
		hidden_names.append(creature.get_target_log_display_name(viewer))

	var feedback := "Mists of the Blessed Isles shrouds %d Triskelion creature(s) in stealth." % hidden_names.size()
	if not hidden_names.is_empty():
		feedback += " " + ", ".join(hidden_names) + "."
	game_manager.note_player_feedback(feedback)
	notify_power_activated(game_manager)

func is_valid_activation_target(target: Card, game_manager: GameManager = null) -> bool:
	if target == null:
		return false
	if target.card_type != Card.CardType.CREATURE:
		return false
	if target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	if target.get_controller() != card_owner:
		return false
	if not _is_triskelion_creature(target):
		return false
	if target.is_face_down and target.is_stealth and target.creature_mode == ACTIVATION_MODE:
		return false
	return game_manager == null or not game_manager.is_immune_to_source(target, self)

func _is_triskelion_creature(card: Card) -> bool:
	return card != null and card.culture == "Triskelion"

func _apply_stealth_stance(creature: Card) -> void:
	if creature == null:
		return
	creature.is_face_down = true
	creature.is_stealth = true
	creature.creature_mode = ACTIVATION_MODE
