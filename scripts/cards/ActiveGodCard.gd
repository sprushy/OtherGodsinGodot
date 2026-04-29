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
