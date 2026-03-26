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
	
	if not (target is Card):
		if game_manager != null:
			game_manager.note_player_feedback("BitMeseri fizzles: it can only target cards.")
		print("BitMeseri can only target cards!")
		return
	
	var target_card_typed: Card = target as Card
	
	# Check if target is a creature, structure, or equipment
	if target_card_typed.card_type != Card.CardType.CREATURE and target_card_typed.card_type != Card.CardType.STRUCTURE and target_card_typed.card_type != Card.CardType.EQUIPMENT:
		if game_manager != null:
			game_manager.note_player_feedback("BitMeseri fizzles: it can only target a physical card.")
		print("BitMeseri can only target creatures, structures, or equipment!")
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
	
	# Check if there are any valid targets on the board
	for p in [game_manager.current_player, game_manager.other_player]:
		for zone in p.frontline_zones + p.reserve_zones:
			for card in zone.cards:
				if card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE or card.card_type == Card.CardType.EQUIPMENT:
					return true
	
	print("BitMeseri has no valid targets!")
	return false
