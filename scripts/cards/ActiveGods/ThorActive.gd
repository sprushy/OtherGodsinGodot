extends ActiveGodCard
class_name ThorActive

const PASSIVE_SOURCE := "Thor Active - Patron's Hand"
const LINKED_GOD_NAME := "Thor"
const ART_PATH := "res://images/card_art/gods/ThorAIedit.png"

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Thor, Active God"
	card_types = ["Active God", "Divine Manifestation", "Human", "Warrior"]
	level = 7
	mana_cost = 10
	speed = 1
	resilience = 35
	strength = 40
	culture = "Norse"
	# flavor_text = "Thor steps onto the field and the human warbands rally around him."
	flavor_text = ""
	ability_text = "[b]Patron's Hand[/b] ([b]Passive[/b]): Can intercept any attack on your followers or Human creatures regardless of position or speed. Other friendly Warriors on the field gain +5 STR and +5 RES. Follower damage inflicted by this card is halved."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricarrdo Zoppello"

func applies_to(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card != self \
		and card.get_controller() == get_controller() \
		and card.has_type("Warrior") \
		and card.counts_as_on_field()

func apply_passive_to_board(game_manager: GameManager = null) -> void:
	var controller := get_controller()
	if controller == null:
		return
	remove_passive_from_board(game_manager)
	if abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if is_face_down or is_stealth:
		return
	var resolved_game_manager := game_manager if game_manager != null else controller.game_manager
	if resolved_game_manager != null:
		for card in resolved_game_manager.get_field_cards(controller):
			if applies_to(card):
				card.add_buff(PASSIVE_SOURCE, 5, 5, 0, self, controller, "passive")
		return
	for zone in controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if applies_to(card):
				card.add_buff(PASSIVE_SOURCE, 5, 5, 0, self, controller, "passive")

func remove_passive_from_board(game_manager: GameManager = null) -> void:
	var controller := get_controller()
	if controller == null:
		controller = card_owner
	if controller == null:
		return
	for zone in _get_passive_cleanup_zones(controller):
		for card in zone.cards:
			card.clear_buffs_from(PASSIVE_SOURCE)
	var resolved_game_manager := game_manager if game_manager != null else controller.game_manager
	if resolved_game_manager == null:
		return
	for card in resolved_game_manager.get_field_cards(controller):
		card.clear_buffs_from(PASSIVE_SOURCE)

func _get_passive_cleanup_zones(player: Player) -> Array[Zone]:
	var zones: Array[Zone] = []
	if player == null:
		return zones
	zones.append(player.hand_zone)
	zones.append(player.deck_zone)
	zones.append(player.graveyard_zone)
	zones.append(player.abyss_zone)
	zones.append(player.god_zone)
	zones.append_array(player.power_zones)
	zones.append_array(player.frontline_zones)
	zones.append_array(player.reserve_zones)
	return zones

func can_special_intercept(_game_manager: GameManager, _attacker: Card, protected_target) -> bool:
	if abilities_suppressed():
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_sleeping:
		return false
	var controller := get_controller()
	if controller == null:
		return false
	if protected_target is Player:
		return protected_target == controller
	var protected_card := protected_target as Card
	return protected_card != null \
		and protected_card.get_controller() == controller \
		and protected_card.has_type("Human")

func halves_follower_damage_inflicted() -> bool:
	return not abilities_suppressed()

func on_summon(game_manager: GameManager) -> void:
	apply_passive_to_board(game_manager)

func on_turn_start(game_manager: GameManager) -> void:
	apply_passive_to_board(game_manager)

func on_removed(game_manager: GameManager) -> void:
	remove_passive_from_board(game_manager)

func on_muted(game_manager: GameManager) -> void:
	remove_passive_from_board(game_manager)

func on_unmuted(game_manager: GameManager) -> void:
	apply_passive_to_board(game_manager)

func on_any_card_moved(game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	apply_passive_to_board(game_manager)
