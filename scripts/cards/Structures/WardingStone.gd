extends StructureCard
class_name WardingStone

# Helper function to reliably get the restricted player (the opponent/non-owner)
# Now delegates logic to the robust GameManager function.
func _get_restricted_player(game_manager: GameManager) -> Player:
	# Use the GameManager's dedicated function to find the opponent of this card's owner
	return game_manager.get_opponent(card_owner)

func _init() -> void:
	super._init()
	card_name = "Warding Stone"
	card_type = Card.CardType.STRUCTURE
	card_types = ["Runic", "Monument"]
	art_path = "res://images/card_art/structures/warding stone ai edit.png"
	exhausted_art_path = "res://images/card_art/structures/wardstone.jpeg"
	level = 2
	mana_cost = 0
	is_legendary = false
	
	resilience = 20
	speed = 0
	strength = 0
	
	sacrifice_cost = 0
	creature_sacrifice_cost = 0
	
	ability_text = "Your opponent cannot attack for two of their turns. Restriction ends if Warding Stone is removed from the field."
	culture = "Norse"

# Ability: Triggers when the structure is summoned to the board
func on_summon(game_manager: GameManager) -> void:
	# Identify the restricted player
	var restricted_player: Player = _get_restricted_player(game_manager)

	# Apply the restriction for 2 full turns
	game_manager.apply_attack_restriction(restricted_player, 3, self)
	print("Warding Stone summoned by " + card_owner.player_name + "! " + restricted_player.player_name + "'s attacks restricted for 2 turns.")

# Ability: Triggers when the structure is removed from the board (called by _send_to_graveyard_with_hook)
func on_removed(game_manager: GameManager) -> void:
	# Identify the restricted player, who is the opponent of the card_owner
	var restricted_player: Player = _get_restricted_player(game_manager)
	
	# Immediately clear the restriction counter for that player.
	game_manager.remove_attack_restriction(restricted_player)
	switch_to_exhausted_art()
	print("Warding Stone removed! " + restricted_player.player_name + "'s attack restriction lifted.")
