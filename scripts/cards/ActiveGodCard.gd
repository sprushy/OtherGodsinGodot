extends CreatureCard
class_name ActiveGodCard

var linked_god_name: String = ""
var stored_normal_god: Card = null

func _init() -> void:
	super._init()
	level = 7
	if "Active God" not in card_types:
		card_types.append("Active God")

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if player == null or player.god_zone == null or player.god_zone.cards.is_empty():
		return false
	var current_god := player.god_zone.cards[0] as GodCard
	if current_god == null or not current_god.uses_culture_locked_deckbuilding():
		return false
	if not current_god.can_include_card_in_culture_locked_deck(self):
		return false
	if current_god.is_own_active_god_card(self):
		return false
	return super.can_be_played(game_manager, player)

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	if player == null:
		return "No acting player was provided."
	if player.god_zone == null or player.god_zone.cards.is_empty():
		return "No God is available to manifest this Active God."
	var current_god := player.god_zone.cards[0] as GodCard
	if current_god == null or not current_god.uses_culture_locked_deckbuilding():
		return "%s cannot be played right now." % card_name
	if not current_god.can_include_card_in_culture_locked_deck(self):
		return "%s does not match %s's culture lock." % [card_name, current_god.card_name]
	if current_god.is_own_active_god_card(self):
		return "%s is already your active manifestation." % card_name
	return super.get_play_failure_reason(game_manager, player)

func get_linked_god_name() -> String:
	return linked_god_name

func set_stored_normal_god(god_card: Card) -> void:
	stored_normal_god = god_card

func get_stored_normal_god() -> Card:
	return stored_normal_god

func restore_stored_normal_god() -> Card:
	if card_owner == null or stored_normal_god == null:
		return null
	if stored_normal_god.current_zone == card_owner.god_zone:
		var already_active := stored_normal_god
		stored_normal_god = null
		return already_active
	if not card_owner.god_zone.cards.is_empty():
		return null
	var restored_god := stored_normal_god
	stored_normal_god = null
	card_owner.move_card(restored_god, card_owner.god_zone)
	restored_god.is_face_down = false
	restored_god.is_stealth = false
	return restored_god

func get_serialized_state() -> Dictionary:
	var state := super.get_serialized_state()
	if stored_normal_god != null:
		state["stored_normal_god"] = GameState.serialize_embedded_card(stored_normal_god)
	return state

func apply_serialized_state(state: Dictionary) -> void:
	super.apply_serialized_state(state)
	stored_normal_god = null
	var stored_god_data = state.get("stored_normal_god", {})
	if not (stored_god_data is Dictionary):
		return
	stored_normal_god = GameState.deserialize_embedded_card(stored_god_data as Dictionary)
	if stored_normal_god != null:
		stored_normal_god.card_owner = card_owner
		stored_normal_god.current_zone = null
