extends CombatMockGame
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
	load_s_card_scenario()

func update_ui() -> void:
	_sync_test_priority_control()
	super.update_ui()
	if turn_label != null and player1 != null and player2 != null:
		turn_label.text += " | P1 Mana %d | P2 Mana %d" % [player1.mana, player2.mana]

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
	game_manager.turn_player = null
	game_manager.turn_number = 0
	game_manager._upkeep_started_turn = -1
	game_manager._upkeep_resolved_turn = -1
	game_manager._temporary_summon_cost_modifiers.clear()
	selected_card = null
	selected_attacker = null
	selected_interceptor = null

func _setup_test_board() -> void:
	load_s_card_scenario()

func load_s_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# P1 board: a live S-weapon target, a direct attacker for follower pressure, and an Ancient Sage
	# so Seventh Sage Utuabzu can immediately test Channel Ally and Imbue Ally.
	_place_test_board_card(player1, player1.frontline_zones[0], SevenHeadedSerpent.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], ScorpionManWarrior.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[1], FirstSageAdapa.new(), Card.CreatureMode.DEFENSIVE)

	# P1 prepared cards: Sap punishes frontline entry, and Sep Lemutti catches summoned Monsters.
	_place_test_prepared_card(player1, player1.reserve_zones[3], Sap.new())
	_place_test_prepared_card(player1, player1.reserve_zones[4], SepLemutti.new())

	# P1 hand: the remaining S cards in this alphabetical block.
	_add_test_hand_card(player1, SapStrength.new())
	_add_test_hand_card(player1, ScorpionManArcher.new())
	_add_test_hand_card(player1, SevenLeagueBoots.new())
	_add_test_hand_card(player1, SeventhSageUtuabzu.new())
	_add_test_hand_card(player1, SharurTheFlyingMaceScript.new())

	# P1 void/deck: Utuabzu can channel Adapa from the Void immediately, and another Adapa copy is ready for longer loops.
	_add_test_deck_card(player1, FirstSageAdapa.new())
	_add_test_deck_card(player1, SeventhSageUtuabzu.new())
	_add_test_deck_card(player1, SevenHeadedSerpent.new())
	_add_test_deck_card(player1, ScorpionManArcher.new())
	var void_adapa := FirstSageAdapa.new()
	void_adapa.card_owner = player1
	player1.abyss_zone.add_card(void_adapa)

	# P2 power: Saving Grace starts face-down with an otherwise empty field so direct attacks can test it cleanly.
	_add_test_power(player2, 0, SavingGrace.new(), false)

	# P2 hand/deck: S-creature summons can be fed into Sap and Sep Lemutti once Saving Grace has been tested.
	_add_test_hand_card(player2, ScorpionManArcher.new())
	_add_test_hand_card(player2, ScorpionManWarrior.new())
	_add_test_hand_card(player2, SevenHeadedSerpent.new())
	_add_test_deck_card(player2, ScorpionManArcher.new())
	_add_test_deck_card(player2, ScorpionManWarrior.new())
	_add_test_deck_card(player2, BrownBear.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(12)
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
		"S Scenario: Saving Grace through Sharur alphabetically. Choose Draw Card or Gain 4 Mana first.  |  "
		+ "Opponent - P2 starts with only a face-down Saving Grace, so attack followers immediately with Seven-Headed Serpent to test the base response, then try again later after boosting speed with Seven-League Boots for the fast-response version.  |  "
		+ "Prepared - Sap is waiting to destroy frontline entries, and Sep Lemutti is waiting to return summoned Monsters; let P2 summon Scorpion-Man Archer or Scorpion-Man Warrior on later turns to test each trigger.  |  "
		+ "Hand - Sap Strength, Scorpion-Man Archer, Seven-League Boots, Seventh Sage Utuabzu, and Sharur cover the rest of the S block.  |  "
		+ "Board - Scorpion-Man Warrior is a clean bearer for Seven-League Boots or Sharur, while First Sage Adapa is already in play so Utuabzu can use Imbue Ally right away.  |  "
		+ "Void/Deck - First Sage Adapa is already in your Void for Utuabzu's Channel Ally impact, and another copy is stacked in deck for longer follow-up turns."
	)
	update_ui()

func load_r_card_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# P1 powers: Rally starts active for the level-5 Warrior summon, and Ragnarok is ready as the reset button.
	_add_test_power(player1, 0, RallyTheTroops.new(), true)
	_add_test_power(player1, 1, Ragnarok.new(), true)

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
		"R-Card Scenario: All cards starting with R, except Robotic Footsoldier. Choose Draw Card or Gain 4 Mana first.  |  "
		+ "Powers - Rally the Troops and Ragnarok both start unlocked so you can test recruitment first and the full-board reset afterward.  |  "
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
		"P-Card Scenario: All cards starting with P. Choose Draw Card or Gain 4 Mana first.  |  "
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

	# P1 board: live N-creatures plus a prepared Namburbi for the opening turn-start window.
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
		"N/O Scenario: All cards starting with N and O. Choose Draw Card or Gain 4 Mana first.  |  "
		+ "Gods - Odin leads P1 with a ready Runic Knowledge guess, while Nusku leads P2 with a full seven-card Ancient deck to mill.  |  "
		+ "Powers - Oracle's Sight starts locked so you can unlock it immediately, and Norse Bloodlust is already active for Berserker's first kill.  |  "
		+ "Board - Berserker, Nagual, and Nimue are live, and Namburbi Apotropaeon is already prepared for the opening turn-start window.  |  "
		+ "Hand - Nergal Lion, Occult Singularity, Gungnir, Harii Warrior, and Runic Shortsword cover the remaining N/O cards and Bloodlust follow-up.  |  "
		+ "Graveyard - Runic Shortsword lets Nimue use Present, and Earthquake gives Nergal Lion a destruction spell to immolate.  |  "
		+ "Opponent - Brown Bears and a Minotaur Footsoldier give you clean combat and Entomb targets before passing to Nusku for Well of Fire."
	)
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
		"M-Card Scenario: All cards starting with M. Choose Draw Card or Gain 4 Mana first.  |  "
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
		"Pictish Scenario: Pictish Beast, Manannan mac Lir, Masmassu Priest, and Minotaur Footsoldier. Choose Draw Card or Gain 4 Mana first.  |  "
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
		"Scenario 1: Lailoken, Heroic Stand, Kurnugia, and Kur-Jara. Choose Draw Card or Gain 4 Mana first.  |  "
		+ "Hand - Heroic Stand is already live because En-hedu-anna counts as having intercepted twice this turn.  |  "
		+ "Hand - Lailoken can reveal into any open lane and drain the prepared enemy Exorcism in reserve.  |  "
		+ "Power - Kurnugia is unlocked and ready to shelter your Ancient Humans or Mer when they are destroyed or voided.  |  "
		+ "Opponent - Thor starts with two Fall of the Mighty and a Void Shield in hand for repeated destroy and protection tests.  |  "
		+ "Board - Enki, Lord of Eridu is on your frontline as a live Mer target for Kurnugia, and another copy is in your graveyard as a Tree of Life target.  |  "
		+ "Follow-up - activate Kur-Jara, then end your turns twice to resurrect Kur-Jara and Enki while Kurnugia shelters En-hedu-anna and Enkidu from the level-cost destruction."
	)
	update_ui()

func load_sap_ragnarok_scenario() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Odin.new())
	_add_test_god(player2, Thor.new())

	# P1 power: Ragnarok is unlocked and ready to fire — both gods and this power should survive its activation.
	_add_test_power(player1, 0, Ragnarok.new(), true)

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
		"Sap / Sap Strength / Ragnarok Scenario. Choose Draw Card or Gain 4 Mana first.  |  "
		+ "Sap - already prepared in your reserve; summon Rabid Wolf or Berserker from hand to the frontline to watch Sap destroy it on entry. Pass to P2 and let them summon their Brown Bear to test that it fires on the opponent's summons too.  |  "
		+ "Sap Strength - play it from hand and target any creature on the board to reduce its Str by 10 for the rest of the turn; useful for weakening a strong attacker before combat.  |  "
		+ "Ragnarok - activate from the unlocked power slot to wipe all frontline and reserve creatures; Odin, Thor, and the Ragnarok power itself should all survive untouched."
	)
	update_ui()
