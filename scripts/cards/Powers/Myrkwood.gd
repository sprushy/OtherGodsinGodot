extends PowerCard
class_name Myrkwood

const UNLOCK_COST := 5
const ART_PATH := "res://images/card_art/powers/MyrkwoodEdit.png"

var _extra_animal_summon_available: bool = false
var _extra_animal_summon_spent_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Myrkwood"
	culture = "Norse"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Swarm", "Animal"]
	ability_text = "Swarm: If you normal summoned an Animal this turn and you control more face-up cards on the field than your opponent, you may normal summon another Animal to your reserve line."
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_turn_start(_game_manager: GameManager) -> void:
	_clear_turn_state()

func on_turn_end(game_manager: GameManager) -> void:
	super.on_turn_end(game_manager)
	if game_manager != null and game_manager.current_player == card_owner:
		_clear_turn_state()

func on_creature_summoned(
	player: Player,
	card: Card,
	from_zone: Zone,
	_to_zone: Zone,
	summon_source: Card,
	_face_down: bool,
	_stealth: bool,
	game_manager: GameManager
) -> void:
	if not _can_watch_summons(player, game_manager):
		return
	if _extra_animal_summon_spent_turn == game_manager.turn_number:
		return
	if _extra_animal_summon_available:
		return
	if summon_source != null:
		return
	if from_zone != card_owner.hand_zone:
		return
	if not _is_animal_creature(card):
		return
	if not _controls_more_face_up_board_cards(game_manager):
		return

	_extra_animal_summon_available = true
	game_manager.note_player_feedback(
		"%s opens the swarm. You may normal summon another Animal to your reserve line this turn." % card_name
	)

func can_grant_extra_normal_summon(
	player: Player,
	card: Card,
	target_zone: Zone,
	game_manager: GameManager
) -> bool:
	if not _can_watch_summons(player, game_manager):
		return false
	if not _extra_animal_summon_available:
		return false
	if _extra_animal_summon_spent_turn == game_manager.turn_number:
		return false
	if not _is_animal_creature(card):
		return false
	if card.current_zone != card_owner.hand_zone:
		return false
	if target_zone == null or target_zone not in card_owner.reserve_zones:
		return false
	return true

func consume_extra_normal_summon(
	player: Player,
	card: Card,
	target_zone: Zone,
	game_manager: GameManager
) -> void:
	if not can_grant_extra_normal_summon(player, card, target_zone, game_manager):
		return
	_extra_animal_summon_available = false
	_extra_animal_summon_spent_turn = game_manager.turn_number if game_manager != null else _extra_animal_summon_spent_turn
	if game_manager != null and card != null:
		game_manager.note_player_feedback(
			"%s lets %s be normal summoned to the reserve line." % [card_name, card.card_name]
		)

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var lines := super.get_hover_detail_lines(viewer)
	if viewer != null and viewer != card_owner:
		return lines
	lines.append("Extra Animal summon ready." if _extra_animal_summon_available else "No extra Animal summon ready.")
	return lines

func _can_watch_summons(player: Player, game_manager: GameManager) -> bool:
	return is_effectively_active() \
		and game_manager != null \
		and player != null \
		and player == card_owner \
		and game_manager.current_player == card_owner

func _controls_more_face_up_board_cards(game_manager: GameManager) -> bool:
	if game_manager == null or card_owner == null:
		return false
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return false
	return _count_face_up_board_cards(card_owner, game_manager) > _count_face_up_board_cards(opponent, game_manager)

func _count_face_up_board_cards(player: Player, game_manager: GameManager) -> int:
	if player == null:
		return 0
	var total := 0
	if game_manager != null:
		for board_card in game_manager.get_field_cards(player):
			if _is_face_up_board_card(board_card, game_manager):
				total += 1
		return total
	for zone in player.frontline_zones + player.reserve_zones:
		for board_card in zone.cards:
			if _is_face_up_board_card(board_card):
				total += 1
	return total

func _is_face_up_board_card(card: Card, game_manager: GameManager = null) -> bool:
	return card != null \
		and card.counts_as_on_field(game_manager) \
		and not card.is_face_down \
		and not card.is_stealth

func _is_animal_creature(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.has_type("Animal")

func _clear_turn_state() -> void:
	_extra_animal_summon_available = false
	_extra_animal_summon_spent_turn = -1
