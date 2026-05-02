extends PowerCard
class_name NorseBloodlust

const UNLOCK_COST := 5
const ART_PATH := "res://images/card_art/powers/NorseBloodlustEdit.png"

var _bloodlust_spent_turn: int = -1
var _bloodlust_ready_announcement_turn: int = -1

func _init() -> void:
	super._init()
	card_name = "Norse Bloodlust"
	culture = "Norse"
	level = 0
	mana_cost = UNLOCK_COST
	card_types = ["Power", "Swarm", "Warrior", "Lupine"]
	ability_text = "[b]Swarm[/b]: Once per turn, if a friendly Norse Warrior destroys a creature in combat, you may summon a Lupine or Warrior from your hand and pay its summon cost."
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func on_global_turn_start(_game_manager: GameManager, starting_player: Player) -> void:
	if starting_player == card_owner:
		_bloodlust_spent_turn = -1
		_bloodlust_ready_announcement_turn = -1

func can_activate(_game_manager: GameManager) -> bool:
	return false

func get_activation_failure_reason(game_manager: GameManager) -> String:
	if is_face_down:
		return super.get_activation_failure_reason(game_manager)
	if is_muted:
		return card_name + " is muted."
	if is_activation_locked(game_manager):
		return card_name + " cannot be activated this turn."
	if game_manager != null and _bloodlust_spent_turn != game_manager.turn_number and _has_ready_bloodlust_trigger(game_manager):
		return "%s is passive. Summon a Lupine or Warrior from your hand to use Bloodlust." % card_name
	return "%s is passive and only becomes ready after a friendly Norse Warrior destroys a creature in combat." % card_name

func on_creature_after_combat(game_manager: GameManager, attacker: Card, defender: Card) -> void:
	if game_manager == null or card_owner == null:
		return
	if game_manager.current_player != card_owner:
		return
	if _bloodlust_spent_turn == game_manager.turn_number:
		return
	if _bloodlust_ready_announcement_turn == game_manager.turn_number:
		return
	if attacker == null and defender == null:
		return
	if not _has_ready_bloodlust_trigger(game_manager):
		return
	_bloodlust_ready_announcement_turn = game_manager.turn_number
	game_manager.note_player_feedback(
		"%s is ready. You may summon a Lupine or Warrior from your hand this turn and pay its summon cost." % card_name
	)

func can_grant_extra_normal_summon(
	player: Player,
	card: Card,
	target_zone: Zone,
	game_manager: GameManager
) -> bool:
	if not _can_use_bloodlust(player, game_manager):
		return false
	if _bloodlust_spent_turn == game_manager.turn_number:
		return false
	if not _has_ready_bloodlust_trigger(game_manager):
		return false
	if not _is_valid_bloodlust_summon(card):
		return false
	if card.current_zone != card_owner.hand_zone and card.current_zone != target_zone:
		return false
	if target_zone == null:
		return false
	if target_zone.zone_owner != card_owner:
		return false
	if target_zone not in card_owner.frontline_zones and target_zone not in card_owner.reserve_zones:
		return false
	if not target_zone.cards.is_empty() and card.current_zone != target_zone:
		return false
	return true

func consume_extra_normal_summon(
	player: Player,
	card: Card,
	target_zone: Zone,
	game_manager: GameManager
) -> void:
	if not _can_use_bloodlust(player, game_manager):
		return
	if game_manager == null or _bloodlust_spent_turn == game_manager.turn_number:
		return
	if not _has_ready_bloodlust_trigger(game_manager):
		return
	if not _is_valid_bloodlust_summon(card):
		return
	if target_zone == null or target_zone.zone_owner != card_owner:
		return
	_bloodlust_spent_turn = game_manager.turn_number if game_manager != null else _bloodlust_spent_turn
	if game_manager != null and card != null:
		game_manager.note_player_feedback(
			"%s unleashes the swarm. %s is summoned by Bloodlust." % [card_name, card.card_name]
		)

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var lines := super.get_hover_detail_lines(viewer)
	if viewer != null and viewer != card_owner:
		return lines
	if card_owner == null:
		return lines
	lines.append("Bloodlust summon ready." if _is_bloodlust_ready_now() else "No Bloodlust summon ready.")
	return lines

func is_ui_ready(game_manager: GameManager) -> bool:
	return _is_bloodlust_ready_with_game_manager(game_manager)

func _can_use_bloodlust(player: Player, game_manager: GameManager) -> bool:
	return is_effectively_active() \
		and player != null \
		and game_manager != null \
		and card_owner != null \
		and player == card_owner \
		and game_manager.current_player == card_owner

func _has_ready_bloodlust_trigger(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	for event: Dictionary in game_manager.combat_destroy_events_this_turn:
		var killer := event.get("killer", null) as Card
		var victim := event.get("victim", null) as Card
		var killer_owner := event.get("killer_owner", null) as Player
		if killer == null or victim == null or killer_owner != card_owner:
			continue
		if victim.card_type != Card.CardType.CREATURE:
			continue
		if not _is_friendly_norse_warrior(killer):
			continue
		return true
	return false

func _is_friendly_norse_warrior(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.get_controller() == card_owner \
		and card.has_type("Warrior") \
		and (card.has_type("Norse Creature") or card.culture == "Norse")

func _is_valid_bloodlust_summon(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and (card.has_type("Lupine") or card.has_type("Warrior"))

func _is_bloodlust_ready_now() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var scene := tree.current_scene
	if scene == null:
		return false
	var gm = scene.get("game_manager")
	if gm is GameManager:
		return _is_bloodlust_ready_with_game_manager(gm as GameManager)
	return false

func _is_bloodlust_ready_with_game_manager(game_manager: GameManager) -> bool:
	return game_manager != null \
		and is_effectively_active() \
		and _bloodlust_spent_turn != game_manager.turn_number \
		and _has_ready_bloodlust_trigger(game_manager)
