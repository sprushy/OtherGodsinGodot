extends CombatMockGame
class_name CardTestGame

var _test_turn_owner: Player = null
var _test_turn_opponent: Player = null
var _habrok_scenario_button: Button = null

func _ready() -> void:
	super._ready()
	_ensure_card_test_scenario_button()

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
	_setup_test_board()

func update_ui() -> void:
	_sync_test_priority_control()
	super.update_ui()
	if turn_label != null and player1 != null and player2 != null:
		turn_label.text += " | P1 Mana %d | P2 Mana %d" % [player1.mana, player2.mana]

func _ensure_card_test_scenario_button() -> void:
	if left_panel == null or choice_container == null or _habrok_scenario_button != null:
		return
	_habrok_scenario_button = Button.new()
	_habrok_scenario_button.text = "Load Habrok Scenario"
	_habrok_scenario_button.pressed.connect(load_habrok_test_scenario)
	left_panel.add_child(_habrok_scenario_button)
	left_panel.move_child(_habrok_scenario_button, choice_container.get_index())

func _sync_test_priority_control() -> void:
	if game_manager == null or player1 == null or player2 == null:
		return
	if game_manager.current_player != null:
		_test_turn_owner = game_manager.current_player
		_test_turn_opponent = game_manager.other_player
	elif _test_turn_owner == null:
		_test_turn_owner = player1
		_test_turn_opponent = player2

	var viewer := _test_turn_owner
	if not game_manager.action_stack.is_empty() and game_manager.priority_player != null:
		viewer = game_manager.priority_player
	game_manager.feedback_viewer = viewer

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
	game_manager.attack_restrictions.clear()
	game_manager.died_this_turn.clear()
	game_manager.pending_resurrections.clear()
	game_manager.combat_destroy_events_this_turn.clear()
	game_manager.action_stack.clear()
	game_manager.consecutive_passes = 0
	game_manager.priority_player = null
	game_manager._temporary_summon_cost_modifiers.clear()
	selected_card = null
	selected_attacker = null
	selected_interceptor = null

func load_habrok_test_scenario() -> void:
	if game_manager == null or player1 == null or player2 == null:
		return
	_dismiss_transient_prompts()
	_reset_test_match_state()

	_add_test_god(player1, Thor.new())
	_add_test_god(player2, Thor.new())

	var habrok: HabrokParagonOfHawks = HabrokParagonOfHawks.new()
	var blessed_knights: BlessedKnights = BlessedKnights.new()
	var brown_bear: BrownBear = BrownBear.new()
	var enkidu: Enkidu = Enkidu.new()

	_place_test_board_card(player1, player1.frontline_zones[2], habrok, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], blessed_knights, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[2], brown_bear, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[3], enkidu, Card.CreatureMode.AGGRESSIVE)

	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
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
	game_manager.turn_player = player1
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	game_manager.current_phase = GameManager.GamePhase.MAIN
	game_manager.turn_number = 1
	_test_turn_owner = player1
	_test_turn_opponent = player2

	hide_turn_choice()
	action_label.text = (
		"HABROK TEST  |  "
		+ "Habrok is your only creature on the field.  |  "
		+ "Click End Turn, choose any upkeep option for P2, then click End Turn again.  |  "
		+ "At the end of P2's turn, Habrok should return to your hand and destroy Blessed Knights as the weakest enemy creature.  |  "
		+ "Brown Bear and Enkidu should remain on the board.  |  "
		+ "Click Load Habrok Scenario again to reset."
	)
	update_ui()

func _setup_test_board() -> void:
	_reset_test_match_state()

	# ── Gods ─────────────────────────────────────────────────────────────────
	var guan_yu := GuanYu.new()
	guan_yu.tactic_counters = 4  # Champion's Call immediately available (costs 4)
	_add_test_god(player1, guan_yu)
	_add_test_god(player2, Thor.new())

	# ── Powers ───────────────────────────────────────────────────────────────
	_add_test_power(player1, 0, GiantsDisdain.new(), true)

	# ── P1 Board ─────────────────────────────────────────────────────────────
	var berserker := Berserker.new()
	var gilgamesh := Gilgamesh.new()
	var gawain := Gawain.new()
	var gudu_priest := GududPriest.new()
	var garm := GarmWatchdogOfHel.new()
	var gala_tura := GalaTura.new()
	var gidim_ensi := GidimEnsi.new()
	var gallu_board := Gallu.new()

	# Graveyard cards must be placed BEFORE GalaTura summon so graveward applies to them.
	_add_test_graveyard_card(player1, Gallu.new())
	_add_test_graveyard_card(player1, AgainWalker.new())

	_place_test_board_card(player1, player1.frontline_zones[0], berserker, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], gilgamesh, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[2], gawain, Card.CreatureMode.AGGRESSIVE)
	gawain.on_summon(game_manager)  # Apply Sun Blessing for P1's active turn
	_place_test_board_card(player1, player1.frontline_zones[3], gudu_priest, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[4], garm, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], gala_tura, Card.CreatureMode.AGGRESSIVE)
	gala_tura.on_summon(game_manager)  # Apply Water of Life graveward to graveyard cards
	_place_test_board_card(player1, player1.reserve_zones[1], gidim_ensi, Card.CreatureMode.DEFENSIVE)
	gidim_ensi.on_summon(game_manager)  # Apply permanent cannot_attack to itself
	_place_test_board_card(player1, player1.reserve_zones[2], gallu_board, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_permanent(player1, player1.reserve_zones[4], GlitnirThePeaceful.new())

	# Give Berserker a removable status so Gawain's Healing Hands has something to cure.
	berserker.add_status_effect(
		"cannot_attack",
		"Bound (test)",
		gidim_ensi,
		player1,
		{"display_name": "Cannot attack — use Gawain Healing Hands (2 mana) to remove"}
	)

	# ── P1 Hand ──────────────────────────────────────────────────────────────
	_add_test_hand_card(player1, GugalannaBullOfHeaven.new())
	_add_test_hand_card(player1, GiantMasterArchitect.new())
	_add_test_hand_card(player1, Gleipnir.new())
	_add_test_hand_card(player1, GungnirTheSpearOfOdin.new())
	_add_test_hand_card(player1, Gullinbursti.new())

	# ── P1 Deck (for GiantMasterArchitect's Master Plan impact) ──────────────
	_add_test_deck_card(player1, GlitnirThePeaceful.new())
	_add_test_deck_card(player1, GlitnirThePeaceful.new())

	# ── P2 Board ─────────────────────────────────────────────────────────────
	var enki := EnkiLordOfEridu.new()
	var enkidu := Enkidu.new()
	_place_test_board_card(player2, player2.frontline_zones[0], enki, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], enkidu, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[2], BlessedKnights.new(), Card.CreatureMode.AGGRESSIVE)

	# ── Mana / followers ─────────────────────────────────────────────────────
	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
	player2.spend_mana(player2.mana)
	player2.gain_mana(10)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	# ── Turn state ───────────────────────────────────────────────────────────
	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	game_manager.current_phase = GameManager.GamePhase.MAIN
	game_manager.turn_number = 1
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	hide_turn_choice()
	action_label.text = (
		"G-CARD TEST  |  "
		+ "Click Load Habrok Scenario for a focused Breakout test.  |  "
		+ "GuanYu (god): 4 tactic counters ready — activate Champion's Call to destroy any board card. End P1's turn to test upkeep (P1 has 5 frontline vs P2's 3, gains another counter each turn).  |  "
		+ "GlitnirThePeaceful (P1 reserve[6]): forces all summons this game to defensive — test by summoning any hand card.  |  "
		+ "Berserker has 'cannot_attack' status — use Gawain Healing Hands (2 mana, minor action) to remove it; then Berserker can attack; play Gungnir from hand in response to destroy the target.  |  "
		+ "Gawain Sun Blessing: check tripled stats (10 Str → 30, 7 Res → 21) during P1's turn; resets after first attack.  |  "
		+ "Gilgamesh attacks EnkiLordOfEridu (level 6 vs 3): Inspired Strength grants +21 Str for that combat.  |  "
		+ "Gudu Priest Creature Ward: target Berserker or any creature to clear creature-applied effects, then make it immune to creature abilities this turn.  |  "
		+ "Garm Watchbeast: graveyard cards (Gallu, AgainWalker) immune to opponent effects while Garm is in play.  |  "
		+ "GalaTura (reserve): Water of Life graveward active on both graveyard cards — destroy GalaTura to trigger Destroyed and return up to 3 graveyard creatures to deck bottom.  |  "
		+ "GidimEnsi (reserve, defensive, Incorporeal): any P2 creature that attacks P1's followers falls asleep; can only be engaged by Spirits or faster Mages.  |  "
		+ "Hand — Gugalanna: summon for Celestial Charge impact (destroys EnkiLordOfEridu RES 36 or Enkidu RES 30, both SPD < 25; opponent may trigger attack hexes; Gugalanna returns to hand). "
		+ "GiantMasterArchitect: summon for Master Plan impact (finds GlitnirThePeaceful from deck; also tests GiantsDisdain +1 Reach/+1 SPD intercept as a Giant). "
		+ "Gleipnir: play to bind Enkidu (cannot attack/intercept, abilities negated). "
		+ "Gungnir: respond to a Norse Warrior (Berserker after healing) attacking to destroy its target. "
		+ "Gullinbursti: vanilla SPD-4 creature."
	)
	update_ui()
