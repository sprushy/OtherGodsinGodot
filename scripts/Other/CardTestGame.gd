extends "res://scripts/Other/CombatMockGame.gd"
class_name CardTestGame

const SharurTheFlyingMaceScript := preload("res://scripts/cards/Equipment/SharurTheFlyingMace.gd")

var _test_turn_owner: Player = null
var _test_turn_opponent: Player = null

func _ready() -> void:
	super._ready()

# Override start_game to set up a focused test board while preserving
# the CombatMockGame interface.
func start_game(
	is_host: bool = false,
	is_client: bool = false,
	server_ip: String = "127.0.0.1",
	server_port: int = 12345,
	match_info: Dictionary = {},
	server_match_session = null
) -> void:
	await super.start_game(is_host, is_client, server_ip, server_port, match_info, server_match_session)
	load_featured_card_test_scenario()

func update_ui() -> void:
	_sync_test_priority_control()
	super.update_ui()
	if turn_label != null and player1 != null and player2 != null:
		turn_label.text += " | P1 Mana %d | P2 Mana %d" % [player1.mana, player2.mana]

func _on_forfeit_button_pressed() -> void:
	if _game_finished:
		super._on_forfeit_button_pressed()
		return
	_pending_forfeit_return_to_menu = false
	_pending_post_game_return_to_menu = false
	_set_match_reconnect_wait(false)
	_dismiss_transient_prompts()
	_hide_game_result_overlay()
	_hide_corner_action_button()
	_emit_forfeit_requested()

func _sync_test_priority_control() -> void:
	if game_manager == null or player1 == null or player2 == null:
		return
	if game_manager.current_player != null:
		_test_turn_owner = game_manager.current_player
		_test_turn_opponent = game_manager.other_player
	elif _test_turn_owner == null:
		_test_turn_owner = player1
		_test_turn_opponent = player2

	# Keep CardTest on the active player's perspective even during priority windows.
	# Swapping to priority_player mid-stack makes the whole board appear to invert.
	game_manager.feedback_viewer = _test_turn_owner

	var turn_owner := game_manager.turn_player if game_manager.turn_player != null else game_manager.current_player
	player1.is_turn_player = turn_owner == player1
	player2.is_turn_player = turn_owner == player2

func _add_test_hand_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.hand_zone.add_card(card)

func _add_test_deck_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.deck_zone.add_card(card)

func _add_test_graveyard_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.graveyard_zone.add_card(card)

func _add_test_abyss_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.abyss_zone.add_card(card)

func _add_test_power(player: Player, slot_index: int, power: PowerCard, unlocked: bool = false) -> void:
	if player == null or power == null:
		return
	if slot_index < 0 or slot_index >= player.power_zones.size():
		return
	power.card_owner = player
	power.is_publicly_revealed = false
	power.is_muted = false
	power.mute_turns_remaining = 0
	if unlocked:
		power.is_face_down = false
	else:
		power.relock()
	player.power_zones[slot_index].add_card(power)
	if unlocked:
		power.on_unlock(game_manager)

func _add_test_tiamat_slot_creature(player: Player, slot_index: int, creature: Card) -> void:
	if player == null or creature == null:
		return
	if slot_index < 0 or slot_index >= player.power_zones.size():
		return
	if not TiamatThePrimordial.is_valid_slot_creature(creature):
		return
	creature.card_owner = player
	creature.is_face_down = false
	creature.is_stealth = false
	creature.is_muted = false
	creature.mute_turns_remaining = 0
	creature.reset_creature_action_state()
	creature.summoned_this_turn = false
	creature.wake_up()
	player.power_zones[slot_index].add_card(creature)

func _add_test_god(player: Player, god: GodCard) -> void:
	if player == null or god == null:
		return
	god.card_owner = player
	god.is_face_down = false
	god.is_stealth = false
	god.is_muted = false
	god.mute_turns_remaining = 0
	god.reset_creature_action_state()
	god.summoned_this_turn = false
	god.wake_up()
	player.god_zone.add_card(god)
	if god.has_method("on_summon"):
		god.on_summon(game_manager)

func _place_test_board_card(player: Player, zone: Zone, card: Card, mode: Card.CreatureMode = Card.CreatureMode.AGGRESSIVE) -> void:
	if player == null or zone == null or card == null:
		return
	card.card_owner = player
	card.creature_mode = mode
	card.reset_creature_action_state()
	card.summoned_this_turn = false
	card.is_face_down = false
	card.is_stealth = false
	card.wake_up()
	zone.add_card(card)
	if game_manager != null and game_manager.has_method("_apply_god_passives_to_card"):
		game_manager._apply_god_passives_to_card(player, card)

func _place_test_hidden_creature(player: Player, zone: Zone, card: Card) -> void:
	_place_test_board_card(player, zone, card, Card.CreatureMode.DEFENSIVE)
	card.is_face_down = true
	card.is_stealth = true

func _place_test_board_permanent(player: Player, zone: Zone, card: Card) -> void:
	if player == null or zone == null or card == null:
		return
	card.card_owner = player
	card.is_face_down = false
	card.is_stealth = false
	zone.add_card(card)

func _equip_test_card(player: Player, zone: Zone, equipment: Card, creature: Card) -> void:
	if player == null or zone == null or equipment == null or creature == null:
		return
	equipment.card_owner = player
	equipment.is_face_down = false
	equipment.is_stealth = false
	zone.add_card(equipment)
	equipment.equip_to(creature)

func _place_test_prepared_card(player: Player, zone: Zone, card: Card) -> void:
	if player == null or zone == null or card == null:
		return
	card.card_owner = player
	card.is_prepared = true
	card.is_face_down = true
	card.is_stealth = false
	zone.add_card(card)
	if game_manager == null:
		return
	var ready_turn: int = maxi(0, game_manager.turn_number - 1)
	if card.card_type == Card.CardType.HEX:
		game_manager.prepared_hexes[card] = ready_turn
	elif card is CharmCard:
		game_manager.prepared_charms[card] = ready_turn

func _clear_zone(zone: Zone) -> void:
	if zone == null:
		return
	for card in zone.cards.duplicate():
		zone.remove_card(card)

func _reset_player_test_state(player: Player) -> void:
	if player == null:
		return
	_clear_zone(player.hand_zone)
	_clear_zone(player.deck_zone)
	_clear_zone(player.graveyard_zone)
	_clear_zone(player.abyss_zone)
	_clear_zone(player.god_zone)
	for zone in player.power_zones:
		_clear_zone(zone)
	for zone in player.frontline_zones:
		_clear_zone(zone)
	for zone in player.reserve_zones:
		_clear_zone(zone)

func _reset_test_match_state() -> void:
	_reset_player_test_state(player1)
	_reset_player_test_state(player2)
	game_manager.prepared_hexes.clear()
	game_manager.prepared_charms.clear()
	if game_manager.has_method("_clear_pending_doorway_choice"):
		game_manager._clear_pending_doorway_choice()
	if game_manager.has_method("_clear_pending_return_to_hand_choice"):
		game_manager._clear_pending_return_to_hand_choice()
	game_manager.attack_restrictions.clear()
	game_manager.died_this_turn.clear()
	game_manager.pending_resurrections.clear()
	game_manager.combat_destroy_events_this_turn.clear()
	game_manager.action_stack.clear()
	game_manager.resolving_stack_actions.clear()
	game_manager.consecutive_passes = 0
	game_manager.priority_player = null
	game_manager.turn_player = null
	game_manager.turn_number = 0
	game_manager._upkeep_started_turn = -1
	game_manager._upkeep_resolved_turn = -1
	game_manager._temporary_summon_cost_modifiers.clear()
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	if match_manager != null:
		match_manager.reset_runtime_state()

func _setup_test_board() -> void:
	load_featured_card_test_scenario()

func load_featured_card_test_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# Default Card Test is a clean stealth visual sandbox.
	# P1 stealth creatures show their hazed art; P2 stealth creatures show card backs.
	_place_test_hidden_creature(player1, player1.frontline_zones[1], PictishBeast.new())
	_place_test_hidden_creature(player1, player1.frontline_zones[2], BrownBear.new())
	_place_test_hidden_creature(player1, player1.frontline_zones[3], Pegasus.new())
	_place_test_hidden_creature(player1, player1.reserve_zones[1], Nimue.new())
	_place_test_hidden_creature(player1, player1.reserve_zones[3], Nagual.new())
	_place_test_prepared_card(player1, player1.frontline_zones[0], OccultSingularity.new())
	_place_test_prepared_card(player1, player1.reserve_zones[4], Absence.new())

	_place_test_hidden_creature(player2, player2.frontline_zones[1], Alu.new())
	_place_test_hidden_creature(player2, player2.frontline_zones[2], MinotaurFootsoldier.new())
	_place_test_hidden_creature(player2, player2.frontline_zones[3], Berserker.new())
	_place_test_hidden_creature(player2, player2.reserve_zones[1], TheWhiteSerpent.new())
	_place_test_hidden_creature(player2, player2.reserve_zones[3], GududPriest.new())
	_place_test_prepared_card(player2, player2.frontline_zones[0], Famine.new())
	_place_test_prepared_card(player2, player2.reserve_zones[4], FoolishOptimism.new())

	# Keep draw/upkeep choices stable if the sandbox runs longer.
	_add_test_deck_card(player1, BrownBear.new())
	_add_test_deck_card(player1, PictishBeast.new())
	_add_test_deck_card(player1, TheWhiteSerpent.new())
	_add_test_deck_card(player1, HeroicStand.new())
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())
	_add_test_deck_card(player2, TheWhiteSerpent.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(10)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.turn_number = 1
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"Stealth and Prepared Magic Visual Test. The board starts with stealth-mode creatures "
		+ "and prepared spells in the outer slots. "
		+ "Friendly stealth cards use visible hazed art; opposing stealth cards use hidden card backs. "
		+ "Prepared spells use the sun-and-moon cover and brighten when moused over."
	)
	update_ui()

func load_harii_jarl_test_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# Player 1 gets a clean Warband test: summon Jarl into an empty board,
	# then click from multiple Harii in hand with plenty of open zones.
	_add_test_hand_card(player1, HariiJarl.new())
	_add_test_hand_card(player1, HariiWarrior.new())
	_add_test_hand_card(player1, HariiFransiscan.new())
	_add_test_hand_card(player1, HariiShaman.new())
	_add_test_hand_card(player1, BrownBear.new())
	_add_test_deck_card(player1, HeroicStand.new())
	_add_test_deck_card(player1, FallOfTheMighty.new())

	# A little opposing board presence helps keep the scene readable
	# without consuming Warband summon space.
	_place_test_board_card(player2, player2.frontline_zones[1], BrownBear.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[1], MinotaurFootsoldier.new(), Card.CreatureMode.AGGRESSIVE)
	_add_test_hand_card(player2, DivineLightning.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(20)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.turn_number = 1
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"Harii Jarl Test Scenario. Choose Mana first, then play Harii Jarl from hand onto any empty friendly zone. "
		+ "Warband should open click selection with the Harii Jarl custom cursor, letting you pick up to two targets from Harii Warrior, Harii Fransiscan, and Harii Shaman. "
		+ "Right-click should finish early using the normal target-cancel flow."
	)
	update_ui()

func load_badge_test_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	var badge_attacker: Card = HariiWarrior.new()
	_place_test_board_card(player1, player1.frontline_zones[2], badge_attacker, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[2], BrownBear.new(), Card.CreatureMode.DEFENSIVE)

	# Enemy targets cover attack glows and equipment action affordances while keeping the board easy to scan.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], MinotaurFootsoldier.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_permanent(player2, player2.frontline_zones[2], BeardedAxe.new())
	_place_test_board_permanent(player2, player2.frontline_zones[3], WardingStone.new())
	_place_test_board_permanent(player2, player2.reserve_zones[2], RunicShortsword.new())

	_add_test_hand_card(player1, HeroicStand.new())
	_add_test_hand_card(player1, FallOfTheMighty.new())
	_add_test_hand_card(player1, Berserker.new())
	_add_test_deck_card(player1, BrownBear.new())
	_add_test_deck_card(player1, MinotaurFootsoldier.new())

	_add_test_hand_card(player2, DivineLightning.new())
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.turn_number = 1
	game_manager.start_turn()
	_open_upkeep_choice_window()
	selected_attacker = badge_attacker
	action_label.text = (
		"Badge Test Scenario. Harii Warrior starts selected on turn 2 so attack-target glows render immediately. "
		+ "Choose Mana first to make the actions live, then reselect Harii Warrior if the selection is cleared. "
		+ "Brown Bear, Minotaur Footsoldier, and Warding Stone should show red attack-target glows instead of centered attack badges. "
		+ "Bearded Axe should show the attack glow plus the steal glove affordance, and Runic Shortsword in reserve gives a second legal enemy equipment steal target for checking equipment action spacing on a lower row."
	)
	update_ui()

func load_clean_start_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, GuanYu.new())
	_add_test_god(player2, Thor.new())

	# Fresh opening hands only: no seeded board, no prepared cards, no active powers.
	_add_test_hand_card(player1, Berserker.new())
	_add_test_hand_card(player1, BrownBear.new())
	_add_test_hand_card(player1, HeroicStand.new())
	_add_test_hand_card(player1, HariiWarrior.new())
	_add_test_hand_card(player1, FallOfTheMighty.new())

	_add_test_hand_card(player2, MinotaurFootsoldier.new())
	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_hand_card(player2, Berserker.new())
	_add_test_hand_card(player2, DivineLightning.new())

	# Small known decks so draw/upkeep remains deterministic while staying low-complexity.
	_add_test_deck_card(player1, BrownBear.new())
	_add_test_deck_card(player1, MinotaurFootsoldier.new())
	_add_test_deck_card(player1, HeroicStand.new())
	_add_test_deck_card(player1, Berserker.new())

	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, MinotaurFootsoldier.new())
	_add_test_deck_card(player2, HeroicStand.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(8)
	player2.spend_mana(player2.mana)
	player2.gain_mana(8)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"Clean Start Scenario. Fresh game state with gods, empty boards, simple opening hands, and no seeded powers, summons, or queued effects. "
		+ "Choose an upkeep option first, then test priority windows from a plain opening turn."
	)
	update_ui()

func load_thor_vs_tiamat_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Thor.new())
	_add_test_god(player2, TiamatThePrimordial.new())

	# Thor (P1)
	_add_test_hand_card(player1, Berserker.new())
	_add_test_hand_card(player1, HariiWarrior.new())

	# Tiamat (P2)
	# She should have Take the Field and some Demons in hand
	_add_test_hand_card(player2, TakeTheField.new())
	_add_test_hand_card(player2, Alu.new())
	_add_test_hand_card(player2, Rabisu.new())
	_add_test_hand_card(player2, Asakku.new())

	# Tiamat replaces her power slots with Ancient Demons and Dragons
	_add_test_tiamat_slot_creature(player2, 0, Anzu.new())
	_add_test_tiamat_slot_creature(player2, 1, LesserMushussu.new())
	_add_test_tiamat_slot_creature(player2, 2, SulakTheUnclean.new())

	# Seed some board for testing
	_place_test_board_card(player1, player1.frontline_zones[0], MinotaurFootsoldier.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[0], GududPriest.new(), Card.CreatureMode.DEFENSIVE)

	player1.spend_mana(player1.mana)
	player1.gain_mana(15)
	player2.spend_mana(player2.mana)
	player2.gain_mana(15)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	
	action_label.text = "Thor vs Tiamat Scenario. Tiamat has Take the Field and Ancient Demons in hand. Thor is ready to fight."
	update_ui()

func load_tiamat_ragnarok_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, TiamatThePrimordial.new())
	_add_test_god(player2, Thor.new())

	# Tiamat replaces her power slots with Ancient Demons and Dragons. The first two slots
	# hold multiple creatures so the Matriarch stack visuals and chain release are easy to test.
	_add_test_tiamat_slot_creature(player1, 0, Anzu.new())
	_add_test_tiamat_slot_creature(player1, 0, Asakku.new())
	_add_test_tiamat_slot_creature(player1, 1, Alu.new())
	_add_test_tiamat_slot_creature(player1, 1, Rabisu.new())
	_add_test_tiamat_slot_creature(player1, 2, LesserMushussu.new())
	_add_test_tiamat_slot_creature(player1, 2, SulakTheUnclean.new())

	# Thor keeps Ragnarok locked so the opposing reset button fires when unlocked.
	_add_test_power(player2, 0, Ragnarok.new(), false)

	# Seed both battlefields so Ragnarok has visible payoff once it is activated.
	_place_test_board_card(player1, player1.frontline_zones[0], GududPriest.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.frontline_zones[0], Berserker.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], MinotaurFootsoldier.new(), Card.CreatureMode.DEFENSIVE)

	# A couple of visible follow-ups make it easy to test Matriarch Rule versus normal draw.
	_add_test_hand_card(player1, HeroicStand.new())
	_add_test_hand_card(player1, BrownBear.new())
	_add_test_deck_card(player1, GududPriest.new())
	_add_test_deck_card(player1, BrownBear.new())

	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_deck_card(player2, Berserker.new())
	_add_test_deck_card(player2, BrownBear.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"Tiamat vs Thor / Ragnarok Scenario. Choose an upkeep option first.  |  "
		+ "Tiamat - your three power slots are filled with face-up Ancient Demons and Dragons. The slot chains should remain over each stack until that slot is emptied into your hand.  |  "
		+ "Matriarch Rule - choose it on upkeep to add one slotted creature to hand instead of drawing, then repeat on later turns until a slot is empty and its chain disappears.  |  "
		+ "Thor - Ragnarok is locked on the opposing side, with creatures on both fields so you can unlock it and confirm only creatures are destroyed.  |  "
		+ "Board - Gudud Priest and Brown Bear give Tiamat simple bodies to preserve or sacrifice, while Thor starts with Berserker and Minotaur Footsoldier so the wipe has obvious results."
	)
	update_ui()

func load_t_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, TezcatlipocaTheSmokingMirror.new())
	_add_test_god(player2, Thor.new())

	# P1 board: the alphabetical T-range package is live immediately. Brown Bear is the
	# clean sacrifice for Tezcatlipoca Blasphemer, White Serpent is ready to answer an
	# enemy target, and Nagual is support for Tezcatlipoca's mana passive.
	_place_test_board_card(player1, player1.frontline_zones[0], TezcatlipocaBlasphemer.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], BrownBear.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], TheWhiteSerpent.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.reserve_zones[1], Nagual.new(), Card.CreatureMode.DEFENSIVE)

	# P1 prepared cards: The Inferno should punish the next enemy attack, and The Deluge
	# should wipe physical cards the next time a creature or structure is summoned.
	_place_test_prepared_card(player1, player1.reserve_zones[2], TheInferno.new())
	_place_test_prepared_card(player1, player1.reserve_zones[3], TheDeluge.new())

	# P1 hand/deck: an extra White Serpent gives you a deliberate Deluge trigger later,
	# with extra T-range copies in deck for follow-up draws.
	_add_test_hand_card(player1, TheWhiteSerpent.new())
	_add_test_deck_card(player1, TezcatlipocaBlasphemer.new())
	_add_test_deck_card(player1, TheWhiteSerpent.new())

	# P2 board: an enemy Tezcatlipoca Blasphemer plus sacrifice fodder lets White Serpent
	# answer a targeted Blood Magic activation, while the frontline is loaded for Inferno.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], MinotaurFootsoldier.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], TezcatlipocaBlasphemer.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[1], BrownBear.new(), Card.CreatureMode.DEFENSIVE)

	# P2 prepared/hand: the prepared Heroic Stand is the clean magical target for your
	# Blood Magic, and the hand creature is the deliberate Deluge trigger after the other tests.
	_place_test_prepared_card(player2, player2.reserve_zones[2], HeroicStand.new())
	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"T-Range Scenario: Tezcatlipoca Blasphemer through The White Serpent alphabetically. Choose an upkeep option first.  |  "
		+ "God - Tezcatlipoca, the Smoking Mirror leads P1. Use Nagual's shapeshift on your reserve to start building Tonal Mastery tokens before moving on to the other tests.  |  "
		+ "Board - Your Tezcatlipoca Blasphemer starts on the frontline with a Brown Bear beside it as sacrifice fodder, while The White Serpent is already face-up in reserve so it can answer enemy targeting.  |  "
		+ "Blood Magic - Enemy Heroic Stand is already prepared in reserve as the clean magical target for your Tezcatlipoca Blasphemer. Sacrifice your Brown Bear to destroy it. Then pass the turn so the opposing Tezcatlipoca Blasphemer can try to target your prepared Inferno or Deluge, and respond with The White Serpent's Shift Medicine.  |  "
		+ "Prepared - The Inferno and The Deluge are already prepared on your side. Let P2 declare an attack to trigger The Inferno and burn down its frontline, then have P2 summon the Brown Bear from hand when you are ready for The Deluge to wipe all physical cards.  |  "
		+ "Hand - A second The White Serpent is in your hand for a follow-up summon or a deliberate Deluge trigger if you want to fire it on your own turn instead."
	)
	update_ui()

func load_s_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# P1 power: Summoned Sap starts unlocked so its aura is live immediately.
	_add_test_power(player1, 0, SummonedSap.new(), true)

	# P1 board: Brown Bear keeps Summoned Sap active, Sulak is the clean non-Animal stance target
	# and an easy bearer for Sharur, Gudud Priest gives Storm a live activated-ability target,
	# and Tatzelwurm starts ready to attack for an immediate Dragon Heart test.
	_place_test_board_card(player1, player1.frontline_zones[0], GududPriest.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], Tatzelwurm.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.reserve_zones[1], SulakTheUnclean.new(), Card.CreatureMode.AGGRESSIVE)

	# P1 prepared cards: Shroud answers any action, Smite punishes an attack declaration,
	# and Spell Demolition is waiting for the opponent's spell.
	_place_test_prepared_card(player1, player1.reserve_zones[2], ShroudOfTheAncients.new())
	_place_test_prepared_card(player1, player1.reserve_zones[3], Smite.new())
	_place_test_prepared_card(player1, player1.reserve_zones[4], SpellDemolition.new())

	# P1 hand: Sharur equips to Sulak or another valid bearer, Storm clears the weather lane,
	# Tablet of Life can resurrect the Ancient creature already waiting in the graveyard,
	# and a second Tatzelwurm lets you retest Dragon Heart from hand.
	_add_test_hand_card(player1, SharurTheFlyingMaceScript.new())
	_add_test_hand_card(player1, Storm.new())
	_add_test_hand_card(player1, TabletOfLife.new())
	_add_test_hand_card(player1, Tatzelwurm.new())

	# P1 graveyard/deck: Tablet of Life has multiple Ancient ability creatures to bring back immediately,
	# and Tatzelwurm has multiple Dragons to search after a combat kill.
	_add_test_graveyard_card(player1, Alu.new())
	_add_test_graveyard_card(player1, FirstSageAdapa.new())
	_add_test_deck_card(player1, SulakTheUnclean.new())
	_add_test_deck_card(player1, Storm.new())
	_add_test_deck_card(player1, TabletOfLife.new())
	_add_test_deck_card(player1, Lindwyrm.new())
	_add_test_deck_card(player1, LesserMushussu.new())
	_add_test_deck_card(player1, Jiaolong.new())

	# P2 board: Brown Bear is ready to attack into Smite, Pegasus is a live Storm target,
	# Gudud Priest in lane 2 is a clean Tatzelwurm kill and also another activated-ability body
	# for silence testing, and Heavy Snow is face-up so Storm can destroy an existing Weather charm on resolution.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], GududPriest.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], Pegasus.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_permanent(player2, player2.reserve_zones[1], HeavySnow.new())

	# P2 hand/deck: Earthquake is the clean Spell Demolition target, with a second spell and follow-up creatures
	# available for longer S/T test lines after the first response window.
	_add_test_hand_card(player2, Earthquake.new())
	_add_test_hand_card(player2, FoolishOptimism.new())
	_add_test_hand_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Pegasus.new())
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Earthquake.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"S/T Scenario: Sharur through Tablet of Life alphabetically. Choose an upkeep option first.  |  "
		+ "Tatzelwurm - A ready Tatzelwurm starts in your second frontline lane with enemy Gudu Priest directly across from it. Attack there first for a clean Dragon Heart trigger, then choose Lindwyrm, Lesser Mushussu, or Jiaolong from your deck. A second Tatzelwurm is also in hand for repeat tests.  |  "
		+ "Power - Summoned Sap starts unlocked. Because Brown Bear is already on your field, Sulak is slowed by 1; switch Sulak's stance to confirm the aura makes it use up its full turn action.  |  "
		+ "Hand - Sharur, Storm, and Tablet of Life are ready now. Play Sharur onto Sulak or any valid bearer, cast Storm to destroy the face-up Heavy Snow and silence Gudud Priest while stripping Pegasus of Aerial, and cast Tablet of Life to resurrect Alu or First Sage Adapa from your graveyard with negated abilities.  |  "
		+ "Prepared - Shroud of the Ancients, Smite, and Spell Demolition are already prepared in reserve. Pass to P2 so Brown Bear can attack into Smite, and let Earthquake or Foolish Optimism give you clean response windows for Spell Demolition or Shroud.  |  "
		+ "Board - Your own Gudu Priest gives you an activated creature ability to test before and after Storm, while Sulak is your simple Ancient Demon body for Sharur and Summoned Sap testing.  |  "
		+ "Opponent - Pegasus is the best Storm target, Heavy Snow is the face-up Weather charm Storm should destroy on resolve, enemy Gudud Priest is another silence target, and P2 has extra spell and creature follow-ups in hand and deck for longer test loops."
	)
	update_ui()

func load_r_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# P1 powers: Rally starts active for the level-5 Warrior summon, and Ragnarok fires when unlocked.
	_add_test_power(player1, 0, RallyTheTroops.new(), true)
	_add_test_power(player1, 1, Ragnarok.new(), false)

	# P1 board: Rabid Wolf can attack immediately to trigger Raven Storm, while Red Cap must attack or perish.
	var rabid_wolf := RabidWolf.new()
	var red_cap := RedCap.new()
	_place_test_board_card(player1, player1.frontline_zones[0], rabid_wolf, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], red_cap, Card.CreatureMode.AGGRESSIVE)

	# P1 hand: the rest of the R package plus a level-5 Norse Warrior to fire Rally the Troops.
	var rally_trigger := HariiWarrior.new()
	rally_trigger.level = 5
	rally_trigger.mana_cost = 0
	_add_test_hand_card(player1, Sap.new())
	_add_test_hand_card(player1, Rabisu.new())
	_add_test_hand_card(player1, ReedBow.new())
	_add_test_hand_card(player1, RunicShortsword.new())
	_add_test_hand_card(player1, RunicSpellbreaker.new())
	_add_test_hand_card(player1, rally_trigger)

	# P1 deck: Rally reveals a non-Warrior, an R-Warrior recruit, and another shelf card in that order.
	_add_test_deck_card(player1, AncientPyre.new())
	_add_test_deck_card(player1, RedCap.new())
	_add_test_deck_card(player1, BrownBear.new())
	_add_test_deck_card(player1, RabidWolf.new())
	_add_test_deck_card(player1, RunicShortsword.new())

	# P2 power: a live magical target for Runic Spellbreaker, with extra copies hiding in deck.
	_add_test_power(player2, 0, NorseBloodlust.new(), true)

	# P2 board: sleeping creatures let Rabisu drain on impact, and a live defender survives Rabid Wolf combat to test Disease.
	var sleeping_bear := BrownBear.new()
	var sleeping_knight := BlessedKnights.new()
	var disease_target := MinotaurFootsoldier.new()
	_place_test_board_card(player2, player2.frontline_zones[0], sleeping_bear, Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], disease_target, Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], sleeping_knight, Card.CreatureMode.DEFENSIVE)
	sleeping_bear.add_status_effect("sleep", "Scenario Setup", rabid_wolf, player1)
	sleeping_knight.add_status_effect("sleep", "Scenario Setup", rabid_wolf, player1)

	# P2 hand/deck: enough cards to test Ragnarok's discard clause and Spellbreaker's deck mill.
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())
	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, Berserker.new())
	_add_test_hand_card(player2, DivineLightning.new())
	_add_test_hand_card(player2, VoidShield.new())
	_add_test_deck_card(player2, NorseBloodlust.new())
	_add_test_deck_card(player2, NorseBloodlust.new())
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"R-Card Scenario: All cards starting with R, except Robotic Footsoldier. Choose an upkeep option first.  |  "
		+ "Powers - Rally the Troops starts unlocked, and Ragnarok is locked so you can test recruitment first and the full-board reset when you unlock it afterward.  |  "
		+ "Board - Rabid Wolf is ready to attack and trigger Raven Storm, while Red Cap must attack this turn or Fresh Blood will destroy it at end of turn.  |  "
		+ "Hand - Raven Storm, Rabisu, Reed Bow, Runic Shortsword, and Runic Spellbreaker are ready, plus a level-5 Harii Warrior to trigger Rally the Troops immediately.  |  "
		+ "Deck - Your top three cards are stacked so Rally reveals Ancient Pyre, Red Cap, and Brown Bear, letting you recruit the Red Cap and shelve the rest.  |  "
		+ "Opponent - Sleeping Brown Bear and Blessed Knights fuel Rabisu's impact drain, Minotaur Footsoldier is a durable Disease target for Rabid Wolf, and the unlocked enemy Norse Bloodlust is a clean Runic Spellbreaker target with two more copies in deck."
	)
	update_ui()

func load_p_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, ManannanMacLir.new())
	_add_test_god(player2, Thor.new())

	# P1 power: Palisade starts unlocked so the lane shield can be tested immediately.
	_add_test_power(player1, 0, PalisadePower.new(), true)

	# P1 board: Berserker is a ready Human for Pegasus to mount, while a hidden Pictish Beast
	# sits behind the open lane where Palisade will be summoned.
	_place_test_board_card(player1, player1.frontline_zones[0], Berserker.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], Pegasus.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_hidden_creature(player1, player1.reserve_zones[1], PictishBeast.new())

	# P1 hand: Pazuzu is ready for an impact drain, and another Beast gives easy Mana Boon fodder.
	_add_test_hand_card(player1, Pazuzu.new())
	_add_test_hand_card(player1, PictishBeast.new())

	# P1 grave/deck: Mana Boon already counts a graveyard copy, and the next draws stay on-theme.
	_add_test_graveyard_card(player1, PictishBeast.new())
	_add_test_deck_card(player1, Pegasus.new())
	_add_test_deck_card(player1, PictishBeast.new())
	_add_test_deck_card(player1, Pazuzu.new())

	# P2 board: a grounded attacker and an aerial attacker let you test Palisade's restriction.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], Pegasus.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)

	# P2 hand/deck: simple follow-up bodies for second-player testing.
	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Pegasus.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
	player2.spend_mana(player2.mana)
	player2.gain_mana(8)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"P-Card Scenario: All cards starting with P. Choose an upkeep option first.  |  "
		+ "Power - Palisade is already unlocked, and the open frontline lane in front of your hidden Pictish Beast is reserved for its barrier.  |  "
		+ "Board - Berserker is live so Pegasus can be mounted immediately, while the hidden Pictish Beast can reveal into Mana Boon with another copy already in your graveyard.  |  "
		+ "Hand - Pazuzu is ready for Locust Swarm, and the extra Pictish Beast gives you an easy way to grow Mana Boon or provide sacrifice fodder.  |  "
		+ "Opponent - Brown Bear should be blocked from attacking through Palisade, while the enemy Pegasus lets you test that aerial attackers can still bypass the barrier."
	)
	update_ui()

func load_n_o_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, NuskuFirebearer.new())

	# P1 powers: Oracle's Sight starts locked to test its unlock resolution; Bloodlust is already live.
	_add_test_power(player1, 0, OraclesSight.new(), false)
	_add_test_power(player1, 1, NorseBloodlust.new(), true)

	# P1 board: live N-creatures plus a prepared Namburbi for a defensive combat/destruction response.
	_place_test_board_card(player1, player1.frontline_zones[0], Berserker.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], Nagual.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], Nimue.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_prepared_card(player1, player1.reserve_zones[1], NamburbiApotropaeon.new())

	# P1 hand: the rest of the N/O package plus a Norse Warrior for Bloodlust follow-up.
	_add_test_hand_card(player1, NergalLion.new())
	_add_test_hand_card(player1, OccultSingularity.new())
	_add_test_hand_card(player1, GungnirTheSpearOfOdin.new())
	_add_test_hand_card(player1, HariiWarrior.new())
	_add_test_hand_card(player1, RunicShortsword.new())

	# P1 graveyard: Nimue can Present the sword, and Nergal Lion can immolate Earthquake immediately.
	_add_test_graveyard_card(player1, RunicShortsword.new())
	_add_test_graveyard_card(player1, Earthquake.new())

	# P1 deck: Oracle's Sight and Odin both have known top-deck cards to work with.
	_add_test_deck_card(player1, OccultSingularity.new())
	_add_test_deck_card(player1, NamburbiApotropaeon.new())
	_add_test_deck_card(player1, Nagual.new())
	_add_test_deck_card(player1, RunicShortsword.new())
	_add_test_deck_card(player1, Nimue.new())
	_add_test_deck_card(player1, HariiWarrior.new())

	# P2 board: clean combat and Entomb targets while leaving open space for follow-up testing.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], MinotaurFootsoldier.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[1], BrownBear.new(), Card.CreatureMode.DEFENSIVE)

	# P2 hand: simple visible cards for longer follow-up turns.
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_hand_card(player2, OccultSingularity.new())

	# P2 deck: seven cards so Nusku mills the full amount and always finds Ancient charms/spells.
	_add_test_deck_card(player2, NamburbiApotropaeon.new())
	_add_test_deck_card(player2, BitMeseri.new())
	_add_test_deck_card(player2, KeyOfSolomon.new())
	_add_test_deck_card(player2, NamburbiApotropaeon.new())
	_add_test_deck_card(player2, BitMeseri.new())
	_add_test_deck_card(player2, KeyOfSolomon.new())
	_add_test_deck_card(player2, BrownBear.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"N/O Scenario: All cards starting with N and O. Choose an upkeep option first.  |  "
		+ "Gods - Odin leads P1 with a ready Runic Knowledge guess, while Nusku leads P2 with a full seven-card Ancient deck to mill.  |  "
		+ "Powers - Oracle's Sight starts locked so you can unlock it immediately, and Norse Bloodlust is already active for Berserker's first kill.  |  "
		+ "Board - Berserker, Nagual, and Nimue are live, and Namburbi Apotropaeon is already prepared as a defensive combat/destruction response.  |  "
		+ "Hand - Nergal Lion, Occult Singularity, Gungnir, Harii Warrior, and Runic Shortsword cover the remaining N/O cards and Bloodlust follow-up.  |  "
		+ "Graveyard - Runic Shortsword lets Nimue use Present, and Earthquake gives Nergal Lion a destruction spell to immolate.  |  "
		+ "Opponent - Brown Bears and a Minotaur Footsoldier give you clean combat and Entomb targets before passing to Nusku for Well of Fire."
	)
	update_ui()

func load_blot_sacrifice_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, NuskuFirebearer.new())

	# P1 board: one creature on the frontline to sacrifice for Blot Sacrifice.
	_place_test_board_card(player1, player1.frontline_zones[0], Berserker.new(), Card.CreatureMode.AGGRESSIVE)

	# P1 hand: Blot Sacrifice plus several low-level creatures to summon (within the 7-level budget).
	_add_test_hand_card(player1, BlotSacrifice.new())
	_add_test_hand_card(player1, HariiWarrior.new())
	_add_test_hand_card(player1, Beyla.new())
	_add_test_hand_card(player1, Berserker.new())

	# P2 board: a defensive blocker so attacks resolve normally.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)

	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
	player2.spend_mana(player2.mana)
	player2.gain_mana(10)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.turn_number = 1
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = "Blot Sacrifice scenario: sacrifice the Berserker, summon creatures, then try to attack."
	update_ui()

func load_m_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Mummu.new())
	_add_test_god(player2, Thor.new())

	# P1 powers: Mech Factory and Myrkwood unlocked for immediate testing.
	_add_test_power(player1, 0, MechFactory.new(), true)
	_add_test_power(player1, 1, Myrkwood.new(), true)

	# P1 board: live M-creatures plus a prepared Mead of Poetry.
	_place_test_board_card(player1, player1.frontline_zones[0], Muninn.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], MalinalxochitlAcolyte.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], Mopsus.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_prepared_card(player1, player1.reserve_zones[1], MeadOfPoetry.new())

	# P1 hand: remaining M-cards to play/prepare.
	_add_test_hand_card(player1, MalinalxochitlThrall.new())
	_add_test_hand_card(player1, MeadOfPoetry.new())

	# P1 deck: draw a Thrall first; keep Mead in deck for Muninn to prime later.
	_add_test_deck_card(player1, MalinalxochitlThrall.new())
	_add_test_deck_card(player1, MeadOfPoetry.new())

	# P2 board: face-up combat targets for the M-creatures.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], LesserMushussu.new(), Card.CreatureMode.DEFENSIVE)

	# P2 hand: visible hand-testing targets for Mopsus.
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())

	# P2 deck: simple draw targets for longer second-player test loops.
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(8)
	player2.spend_mana(player2.mana)
	player2.gain_mana(8)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"M-Card Scenario: All cards starting with M. Choose an upkeep option first.  |  "
		+ "Gods - Mummu leads P1; Thor leads P2 so Entropic Force can be tested right away.  |  "
		+ "Powers - Mech Factory and Myrkwood are unlocked for immediate token and extra-Animal summon testing.  |  "
		+ "Board - Muninn, Malinalxochitl Acolyte, and Mopsus are live; Mead of Poetry is already prepared in reserve.  |  "
		+ "Hand - Malinalxochitl Thrall and another Mead of Poetry are ready to play.  |  "
		+ "Deck - Malinalxochitl Thrall is the next draw, and Mead of Poetry stays in deck for Muninn's perish-prime.  |  "
		+ "Opponent - Brown Bear and Lesser Mushussu give you combat targets, while two hand cards let Mopsus use Seer."
	)
	update_ui()

func load_pictish_test_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, ManannanMacLir.new())
	_add_test_god(player2, Thor.new())

	var minotaur := MinotaurFootsoldier.new()
	var face_up_beast := PictishBeast.new()
	var sleeping_bear := BrownBear.new()

	_place_test_board_card(player1, player1.frontline_zones[0], minotaur, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], face_up_beast, Card.CreatureMode.DEFENSIVE)
	_place_test_hidden_creature(player1, player1.reserve_zones[1], PictishBeast.new())

	_add_test_hand_card(player1, PictishBeast.new())
	_add_test_hand_card(player1, MasmassuPriest.new())
	_add_test_hand_card(player1, Muninn.new())
	_add_test_graveyard_card(player1, PictishBeast.new())

	_add_test_deck_card(player1, PictishBeast.new())
	_add_test_deck_card(player1, MinotaurFootsoldier.new())
	_add_test_deck_card(player1, MeadOfPoetry.new())

	_place_test_board_card(player2, player2.frontline_zones[0], sleeping_bear, Card.CreatureMode.DEFENSIVE)
	sleeping_bear.add_status_effect("sleep", "Scenario Setup", minotaur, player1)
	_place_test_board_card(player2, player2.frontline_zones[1], GududPriest.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_hidden_creature(player2, player2.reserve_zones[0], BrownBear.new())

	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, Berserker.new())
	_add_test_hand_card(player2, MinotaurFootsoldier.new())
	_add_test_hand_card(player2, Muninn.new())

	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, GududPriest.new())
	_add_test_deck_card(player2, HeroicStand.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(6)
	player2.spend_mana(player2.mana)
	player2.gain_mana(6)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"Pictish Scenario: Pictish Beast, Manannan mac Lir, Masmassu Priest, and Minotaur Footsoldier. Choose an upkeep option first.  |  "
		+ "God - Manannan leads P1 so Mists of the Blessed Isles can hide your Triskelion creatures immediately.  |  "
		+ "Board - Minotaur Footsoldier is live on the frontline, one Pictish Beast is face-up, and another is already hidden in reserve.  |  "
		+ "Hand - A fresh Pictish Beast, Masmassu Priest, and Muninn are ready on P1, and P2 also has a Muninn for mirror testing.  |  "
		+ "Deck - Each player now has a Charm in deck for Muninn to prime on perish.  |  "
		+ "Grave - Another Pictish Beast is already in your graveyard so Mana Boon can spike mana as soon as one reveals.  |  "
		+ "Opponent - A sleeping Brown Bear tests Minotaur Footsoldier's stun, a hidden Brown Bear gives you a stealth target, and Gudud Priest is a Human that Masmassu Priest should leave alone."
	)
	update_ui()

func load_test_scenario_one() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Hermes.new())
	_add_test_god(player2, Thor.new())
	_add_test_power(player1, 0, KurnugiaTheBeginningOfTheEnd.new(), true)

	var enkidu := Enkidu.new()
	var frontline_enki := EnkiLordOfEridu.new()
	var en_hedu_anna := EnHeduAnna.new()
	var kur_jara := KurJara.new()
	_place_test_board_card(player1, player1.frontline_zones[0], enkidu, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], frontline_enki, Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], en_hedu_anna, Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.reserve_zones[1], kur_jara, Card.CreatureMode.AGGRESSIVE)

	_add_test_hand_card(player1, Lailoken.new())
	_add_test_hand_card(player1, HeroicStand.new())

	var graveyard_enki := EnkiLordOfEridu.new()
	_add_test_graveyard_card(player1, graveyard_enki)

	var enemy_brown_bear := BrownBear.new()
	_place_test_board_card(player2, player2.frontline_zones[0], enemy_brown_bear, Card.CreatureMode.DEFENSIVE)
	_place_test_prepared_card(player2, player2.reserve_zones[0], Exorcism.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())
	_add_test_hand_card(player2, VoidShield.new())

	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(4)
	player2.spend_mana(player2.mana)
	player2.gain_mana(4)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	game_manager.record_interception(en_hedu_anna)
	game_manager.record_interception(en_hedu_anna)
	_open_upkeep_choice_window()
	action_label.text = (
		"Scenario 1: Lailoken, Heroic Stand, Kurnugia, and Kur-Jara. Choose an upkeep option first.  |  "
		+ "Hand - Heroic Stand is already live because En-hedu-anna counts as having intercepted twice this turn.  |  "
		+ "Hand - Lailoken can reveal into any open lane and drain the prepared enemy Exorcism in reserve.  |  "
		+ "Power - Kurnugia is unlocked and ready to shelter your Ancient Humans or Mer when they are destroyed or voided from the field; sheltered creatures still count as field creatures for effects like Immortal Techniques.  |  "
		+ "Opponent - Thor starts with two Fall of the Mighty and a Void Shield in hand for repeated destroy and protection tests.  |  "
		+ "Board - Enki, Lord of Eridu is on your frontline as a live Mer target for Kurnugia, and another copy is in your graveyard as a Tree of Life target.  |  "
		+ "Follow-up - activate Kur-Jara, then end your turns twice to resurrect Kur-Jara and Enki while Kurnugia shelters En-hedu-anna and Enkidu from the level-cost destruction."
	)
	update_ui()

func load_sap_ragnarok_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# P1 power: Ragnarok is locked and fires on unlock; both gods and this power should survive its resolution.
	_add_test_power(player1, 0, Ragnarok.new(), false)

	# P1 board: a loaded frontline and reserve give Ragnarok plenty of targets on both sides.
	_place_test_board_card(player1, player1.frontline_zones[0], Berserker.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], BrownBear.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], MinotaurFootsoldier.new(), Card.CreatureMode.DEFENSIVE)

	# Sap is prepared so it intercepts any creature entering the frontline — including friendly plays.
	_place_test_prepared_card(player1, player1.reserve_zones[1], Sap.new())

	# P1 hand: SapStrength weakens a board creature by 10 Str; Rabid Wolf and Berserker can be summoned
	# to the frontline to show Sap fires on P1's own summons too.
	_add_test_hand_card(player1, SapStrength.new())
	_add_test_hand_card(player1, RabidWolf.new())
	_add_test_hand_card(player1, Berserker.new())

	# P1 deck: simple follow-up draws.
	_add_test_deck_card(player1, BrownBear.new())
	_add_test_deck_card(player1, Berserker.new())

	# P2 board: three creatures to give SapStrength and Ragnarok meaningful targets.
	_place_test_board_card(player2, player2.frontline_zones[0], BrownBear.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], MinotaurFootsoldier.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], Berserker.new(), Card.CreatureMode.DEFENSIVE)

	# P2 hand: Brown Bear can be summoned to the frontline to trigger Sap on P2's turn.
	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())

	# P2 deck: extra bodies for follow-up testing.
	_add_test_deck_card(player2, Berserker.new())
	_add_test_deck_card(player2, BrownBear.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(12)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"Sap / Sap Strength / Ragnarok Scenario. Choose an upkeep option first.  |  "
		+ "Sap - already prepared in your reserve; summon Rabid Wolf or Berserker from hand to the frontline to watch Sap destroy it on entry. Pass to P2 and let them summon their Brown Bear to test that it fires on the opponent's summons too.  |  "
		+ "Sap Strength - play it from hand and target any creature on the board to reduce its Str by 10 for the rest of the turn; useful for weakening a strong attacker before combat.  |  "
		+ "Ragnarok - unlock it to wipe all frontline and reserve creatures; Odin, Thor, and the Ragnarok power itself should all survive untouched."
	)
	update_ui()

func load_v_w_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# P1 power: Walk of the Sage starts unlocked so you can immediately pay 2 mana to Void
	# a Mage from your deck; Lailoken and Nimue are both valid targets in the deck.
	_add_test_power(player1, 0, WalkOfTheSage.new(), true)

	# P1 board: Wolf Cub offers Maturation on the very first upkeep and can convert into Skoll
	# from the deck. Wolf Adolescent is live and aggressive on the frontline —
	# attack Gudud Priest this turn to earn the kill, then Maturation is offered on your next
	# upkeep to send Wolf Adolescent to the grave and summon Hati. Warrior Dragon is a ready
	# Aerial Ancient body. White Stag sits in reserve; let it die to trigger Hunter's Mark.
	_place_test_board_card(player1, player1.frontline_zones[0], WolfAdolescent.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], WarriorDragon.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], WolfCub.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.reserve_zones[1], WhiteStag.new(), Card.CreatureMode.AGGRESSIVE)

	# P1 prepared hexes: Void Shield intercepts any enemy attack on your creatures and banishes
	# the attacker; Vision of Odin can respond to any action to swing a creature's Str and Spd
	# (choose a non-Norse for -7/-1, or target Wolf Adolescent for +7/+1).
	_place_test_prepared_card(player1, player1.reserve_zones[2], VoidShield.new())
	_place_test_prepared_card(player1, player1.reserve_zones[3], VisionOfOdin.new())

	# P1 hand: Wild Magic shelves Brown Bear then Lailoken before landing on Heroic Stand,
	# preparing it revealed in your first open reserve slot;
	# Vision of Tartarus hits any board creature for -6 Str / -6 Res (two Void creatures primed);
	# Wheel of Fire permanently binds the enemy Minotaur and can push it back again each turn.
	_add_test_hand_card(player1, WildMagic.new())
	_add_test_hand_card(player1, VisionOfTartarus.new())
	_add_test_hand_card(player1, WheelOfFire.new())

	# P1 abyss: two banished creatures so Vision of Tartarus applies -6 Str / -6 Res immediately.
	var void_bear := BrownBear.new()
	void_bear.card_owner = player1
	player1.abyss_zone.add_card(void_bear)
	var void_berserker := Berserker.new()
	void_berserker.card_owner = player1
	player1.abyss_zone.add_card(void_berserker)

	# P1 deck: stacked so Wild Magic shelves Brown Bear and Lailoken before finding Heroic Stand;
	# Walk of the Sage can Void Lailoken or Nimue (both Mages); Skoll is Wolf Cub's Maturation
	# target and Hati follows as Wolf Adolescent's Maturation target on the next turn.
	_add_test_deck_card(player1, BrownBear.new())
	_add_test_deck_card(player1, Lailoken.new())
	_add_test_deck_card(player1, HeroicStand.new())
	_add_test_deck_card(player1, Nimue.new())
	_add_test_deck_card(player1, Skoll.new())
	_add_test_deck_card(player1, Hati.new())

	# P2 board: Gudud Priest is the clean kill target for Wolf Adolescent; an aggressive Brown
	# Bear in the adjacent lane will attack your creatures this turn so Void Shield can intercept;
	# Minotaur Footsoldier in reserve is a durable Wheel of Fire and Vision of Tartarus target.
	_place_test_board_card(player2, player2.frontline_zones[0], GududPriest.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], BrownBear.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], MinotaurFootsoldier.new(), Card.CreatureMode.DEFENSIVE)

	# P2 hand/deck: simple follow-up bodies for longer V/W test lines.
	_add_test_hand_card(player2, BrownBear.new())
	_add_test_hand_card(player2, HeroicStand.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())
	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
	player2.spend_mana(player2.mana)
	player2.gain_mana(10)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	# Start on turn 2 so attacks are allowed immediately (turn_number > 1 is required to attack).
	game_manager.turn_number = 1
	game_manager.start_turn()
	_open_upkeep_choice_window()
	action_label.text = (
		"V/W Scenario: All V and W cards except Warding Stone. Choose an upkeep option first.  |  "
		+ "Upkeep - when you choose Draw or Gain Mana, Wolf Cub offers Maturation: choose Skoll to send the Cub to the graveyard and summon Skoll into its reserve lane, or skip.  |  "
		+ "Board - attack Gudud Priest with Wolf Adolescent this turn to earn the kill; on your next P1 upkeep (after choosing Draw or Gain Mana) the Maturation prompt appears and you can send Wolf Adolescent to the grave and summon Hati from your deck.  |  "
		+ "Warrior Dragon - ready Aerial Ancient on frontline lane 1; attack with it or hold it as a wall.  |  "
		+ "White Stag - in reserve, aggressive; let it attack into something that can kill it to trigger Hunter's Mark and hand your opponent 2 mana.  |  "
		+ "Hand - Wild Magic shelves Brown Bear then Lailoken from the top of your deck before landing on Heroic Stand and preparing it revealed in your first open reserve slot. Vision of Tartarus hits any board creature for -6 Str / -6 Res (two creatures are already banished in your Abyss). Wheel of Fire binds the enemy Minotaur Footsoldier, pushes it back one row on cast, then lets you pay 1 mana at the start of your turn to push it further again.  |  "
		+ "Prepared - pass to P2 and let the aggressive Brown Bear declare an attack on your creature: Void Shield intercepts and banishes the attacker. Vision of Odin is also prepared; respond to any action, target a non-Norse creature for -7 Str / -1 Spd, or target Wolf Adolescent (Norse) for +7 Str / +1 Spd instead.  |  "
		+ "Power - Walk of the Sage is unlocked; pay 2 mana to Void Lailoken or Nimue (both Mages) from your deck."
	)
	update_ui()
