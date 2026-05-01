# cards/spells/BitMeseri.gd (The fix is in the resolve function)
extends SpellCard
class_name BitMeseri

var target_card: Card = null

func _init() -> void:
	super._init()
	card_name = "BitMeseri"
	
	var types: Array[String] = ["Void", "Physical"]
	card_types = types
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	
	level = 2
	mana_cost = 3
	speed = 1
	is_legendary = false
	flavor_text = "Cast into the depths of the abyss, never to return."
	culture = "Ancient"
	art_path = "res://images/card_art/spells/BitMeseriFireflyAI.png"
	artist = "Lorinda Tomko"
	ability_text = "[b]Void[/b] a physical card."
	targets = true

func resolve(game_manager: GameManager, target = null) -> void:
	if target == null:
		if game_manager != null:
			game_manager.note_player_feedback("BitMeseri fizzles: it requires a target.")
		print("BitMeseri requires a target!")
		return

	var target_card_typed: Card = target as Card
	if not is_valid_target(target_card_typed):
		if game_manager != null:
			game_manager.note_player_feedback("BitMeseri fizzles: it can only target a physical card on the field.")
		print("BitMeseri can only target physical cards on the field!")
		return
	
	print("BitMeseri voids " + target_card_typed.card_name + "!")
	
	# --- FIX: Use the GameManager's hook function for banishment ---
	# This ensures WardingStone.on_removed() is executed before removal.
	var target_name := target_card_typed.get_target_log_display_name(game_manager.get_feedback_viewer()) if game_manager != null else target_card_typed.card_name
	game_manager.banish_card_with_hook(target_card_typed)
	if game_manager != null:
		game_manager.note_player_feedback("BitMeseri sent " + target_name + " to the Abyss.")
	
	print(target_card_typed.card_name + " has been cast into the abyss!")

# Override can_be_played to require a valid target
func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false

	if get_valid_targets(game_manager).is_empty():
		print("BitMeseri has no valid targets!")
		return false
	return true

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if get_valid_targets(game_manager).is_empty():
		return card_name + " has no valid targets."
	return ""

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_target(card):
					valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.card_type in [Card.CardType.CREATURE, Card.CardType.STRUCTURE, Card.CardType.EQUIPMENT]
