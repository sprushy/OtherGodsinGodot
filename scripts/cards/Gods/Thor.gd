extends GodCard
class_name Thor

const PASSIVE_SOURCE := "Thor's Patron of Midguard"
const THOR_ACTIVE_SCRIPT := preload("res://scripts/cards/ActiveGods/ThorActive.gd")

func _init() -> void:
	super._init()
	card_name = "Thor"
	card_types = ["God", "Divine Manifestation", "Human", "Warrior"]
	mana_cost = 0
	culture = "Norse"
	# flavor_text = "Thunder echoes across Midgard wherever he walks."
	flavor_text = ""
	ability_text = "Patron of Midguard ([b]Passive[/b]): Friendly Human Warriors on the field gain +3 STR and +3 RES.\n[b]Champion's Call[/b] ([b]Activate[/b]): Summon Thor, Active God. You may [b]Shelve[/b] cards from your hand to pay 4 mana each of its summon cost."
	art_path = "res://images/card_art/gods/ThorAIedit.png"
	name_at_bottom = true
	artist = "Ricarrdo Zoppello"

func can_activate(game_manager: GameManager) -> bool:
	return can_use_champions_call(game_manager)

func should_show_activation_aura(_game_manager: GameManager) -> bool:
	return false

func get_activation_failure_reason(game_manager: GameManager) -> String:
	return get_champions_call_failure_reason(game_manager)

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_use_champions_call(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_champions_call_failure_reason(game_manager))
		return
	var feedback := resolve_champions_call(game_manager)
	if game_manager != null:
		game_manager.note_player_feedback(feedback)
	if current_zone != card_owner.god_zone:
		notify_power_activated(game_manager, null)

func activate_from_command(game_manager: GameManager, command: Dictionary) -> void:
	if is_champions_call_command(command):
		var champion_feedback := resolve_champions_call_from_command(game_manager, command)
		if game_manager != null:
			game_manager.note_player_feedback(champion_feedback)
		if current_zone != card_owner.god_zone:
			notify_power_activated(game_manager, null)
		return
	if not can_use_champions_call(game_manager):
		activate(game_manager, null)
		return
	var feedback := resolve_champions_call(
		game_manager,
		get_champions_call_selected_cards_from_command(game_manager, command),
		get_champions_call_zone_from_command(command),
		get_champions_call_mode_from_command(command)
	)
	if game_manager != null:
		game_manager.note_player_feedback(feedback)
	if current_zone != card_owner.god_zone:
		notify_power_activated(game_manager, null)

func get_champions_call_candidate(allow_fallback: bool = true) -> Card:
	if card_owner == null:
		return null
	var reserved_manifestation := get_reserved_active_god_candidate()
	if reserved_manifestation != null:
		return reserved_manifestation
	for zone in [
		card_owner.hand_zone,
		card_owner.deck_zone,
		card_owner.graveyard_zone,
	] + card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			var active_god := card as ActiveGodCard
			if active_god == null or active_god.get_linked_god_name() != "Thor":
				continue
			if card.current_zone != null and card.current_zone.is_board_zone():
				return null
			return card
	if allow_fallback:
		var manifestation := THOR_ACTIVE_SCRIPT.new()
		manifestation.card_owner = card_owner
		return manifestation
	return null

func can_autofill_take_the_field() -> bool:
	return false

func applies_to(card: Card) -> bool:
	return (
		not is_muted
		and
		card != null
		and
		card.card_type == Card.CardType.CREATURE
		and card != self
		and card.card_owner == card_owner
		and card.has_type("Human")
		and card.has_type("Warrior")
		and card.current_zone != null
		and card.current_zone.is_board_zone()
	)

func apply_passive_to_board() -> void:
	if card_owner == null:
		return
	remove_passive_from_board()
	if is_muted:
		return
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if applies_to(card):
				card.add_buff(PASSIVE_SOURCE, 3, 3, 0, self, card_owner, "passive")

func remove_passive_from_board() -> void:
	if card_owner == null:
		return
	for zone in _get_passive_cleanup_zones(card_owner):
		for card in zone.cards:
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

func on_summon(_game_manager: GameManager) -> void:
	apply_passive_to_board()

func on_turn_start(_game_manager: GameManager) -> void:
	apply_passive_to_board()

func on_removed(_game_manager: GameManager) -> void:
	remove_passive_from_board()

func on_muted(_game_manager: GameManager) -> void:
	remove_passive_from_board()

func on_unmuted(_game_manager: GameManager) -> void:
	apply_passive_to_board()

func on_any_card_moved(_game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	apply_passive_to_board()
