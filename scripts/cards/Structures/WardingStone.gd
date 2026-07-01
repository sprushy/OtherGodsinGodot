extends StructureCard
class_name WardingStone

const DEFAULT_ART_PATH := "res://images/card_art/structures/warding stone ai edit.png"
const ONE_TURN_EXPIRED_ART_PATH := "res://images/card_art/structures/warding_stone_one_turn_expired.png"

# Helper function to reliably get the restricted player (the opponent/non-owner)
# Now delegates logic to the robust GameManager function.
func _get_restricted_player(game_manager: GameManager) -> Player:
	# Use the GameManager's dedicated function to find the opponent of this card's owner
	return game_manager.get_opponent(card_owner)

func get_attack_restriction_turns_remaining(game_manager: GameManager = null) -> int:
	var gm := game_manager
	if gm == null and card_owner != null:
		gm = card_owner.game_manager
	if gm == null or current_zone == null or not current_zone.is_board_zone():
		return 0
	var restricted_player := _get_restricted_player(gm)
	if restricted_player == null or not gm.attack_restrictions.has(restricted_player):
		return 0
	var restriction: Dictionary = gm.attack_restrictions[restricted_player]
	var source: Card = restriction.get("source", null)
	if source != null and source != self:
		return 0
	return maxi(0, int(restriction.get("turns", 0)))

func get_turn_countdown_badge_text(game_manager: GameManager = null) -> String:
	return ""

func get_turn_countdown_badge_hover_text(game_manager: GameManager = null) -> String:
	var turns_remaining := get_attack_restriction_turns_remaining(game_manager)
	if turns_remaining <= 0:
		return ""
	return "Opponent cannot attack for %d more turn%s." % [
		turns_remaining,
		"" if turns_remaining == 1 else "s",
	]

func get_hover_detail_lines(viewer: Player = null) -> Array[String]:
	var lines := super.get_hover_detail_lines(viewer)
	var turns_remaining := get_attack_restriction_turns_remaining()
	if turns_remaining > 0:
		lines.append("[b]Opponent turns remaining:[/b] %d" % turns_remaining)
	return lines

func refresh_attack_restriction_art(game_manager: GameManager = null) -> void:
	var next_art_path := DEFAULT_ART_PATH
	if get_attack_restriction_turns_remaining(game_manager) == 1:
		next_art_path = ONE_TURN_EXPIRED_ART_PATH
	if art_path == next_art_path:
		return
	art_path = next_art_path
	art_updated.emit(art_path)
	_emit_visual_state_changed()

func _init() -> void:
	super._init()
	card_name = "Warding Stone"
	card_type = Card.CardType.STRUCTURE
	card_types = ["Runic", "Monument"]
	art_path = DEFAULT_ART_PATH
	exhausted_art_path = "res://images/card_art/structures/wardstone.jpeg"
	level = 2
	mana_cost = 0
	is_legendary = false
	
	resilience = 20
	speed = 0
	strength = 0
	
	sacrifice_cost = 0
	
	ability_text = "Your opponent cannot attack for two of their turns. Restriction ends if Warding Stone is removed from the field."
	culture = "Norse"

# Ability: Triggers when the structure is summoned to the board
func on_summon(game_manager: GameManager) -> void:
	# Identify the restricted player
	var restricted_player: Player = _get_restricted_player(game_manager)

	# Apply the restriction for the opponent's next 2 turns.
	game_manager.apply_attack_restriction(restricted_player, 2, self)
	print("Warding Stone summoned by " + card_owner.player_name + "! " + restricted_player.player_name + "'s attacks restricted for 2 turns.")

# Ability: Triggers when the structure is removed from the board (called by _send_to_graveyard_with_hook)
func on_removed(game_manager: GameManager) -> void:
	# Identify the restricted player, who is the opponent of the card_owner
	var restricted_player: Player = _get_restricted_player(game_manager)
	
	# Immediately clear the restriction counter for that player.
	game_manager.remove_attack_restriction(restricted_player)
	switch_to_exhausted_art()
	print("Warding Stone removed! " + restricted_player.player_name + "'s attack restriction lifted.")
