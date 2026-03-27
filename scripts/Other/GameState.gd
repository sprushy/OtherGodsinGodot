# GameState.gd
extends RefCounted
class_name GameState

# This class holds the pure data for a single match, 
# allowing it to be cloned or used for headless simulation.

var players: Array[Player] = []
var turn_number: int = 0
var current_player: Player
var other_player: Player
var turn_player: Player
var current_phase: int = 0 # GameManager.GamePhase
var is_game_over: bool = false
var winning_player: Player = null
var losing_player: Player = null
var action_stack: Array[CardAction] = []

# Rules state
var prepared_hexes: Dictionary = {}
var prepared_charms: Dictionary = {}
var attack_restrictions: Dictionary = {} # player -> {turns: int, source: Card}
var died_this_turn: Array[Card] = []
var pending_resurrections: Array[Card] = []
var combat_destroy_events_this_turn: Array[Dictionary] = []

# Priority system
var priority_player: Player = null
var consecutive_passes: int = 0

func clone() -> GameState:
	var new_state = GameState.new()
	# TODO: Implement deep cloning of all properties.
	# This is complex because Player, Zone, and Card are Nodes/Resources 
	# and currently have many cross-references.
	return new_state
