extends Node
class_name PreflightProbe

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const BotCardStrategyScript = preload("res://scripts/bots/BotCardStrategy.gd")
const BotSideboardPolicyScript = preload("res://scripts/bots/BotSideboardPolicy.gd")
const BotSideboardRatingsScript = preload("res://scripts/bots/BotSideboardRatings.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")
const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const MatchCommandRegistryScript = preload("res://scripts/Other/MatchCommandRegistry.gd")
const MatchHistoryStoreScript = preload("res://scripts/server/MatchHistoryStore.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const MatchSupervisorScript = preload("res://scripts/server/MatchSupervisor.gd")
const NetworkManagerScript = preload("res://scripts/Other/NetworkManager.gd")
const RankedBotDeckPoolScript = preload("res://scripts/server/RankedBotDeckPool.gd")
const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const RankBadgeCatalog = preload("res://scripts/core/RankBadgeCatalog.gd")
const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")

const MIN_CATALOG_CARDS := 200
const RESULT_ARG_PREFIX := "preflight_result_file="

var _ran := false
var _fixture_games: Array[GameManager] = []
var _fixture_players: Array[Player] = []
var _fixture_matches: Array[MatchManager] = []
var _fixture_bots: Array[PracticeFuzzPlayerBot] = []

class RecordingLobby extends LobbyServerScript:
	var events: Array[Dictionary] = []

	func _send_to_peer(peer_id: int, message_type: String, payload: Dictionary) -> void:
		events.append({"peer": peer_id, "type": message_type, "payload": payload})

class BadgeTestAccountStore extends AccountStore:
	var storage_path: String

	func _get_storage_path() -> String:
		return storage_path

func _ready() -> void:
	var success := run()
	get_tree().quit(0 if success else 1)

func run() -> bool:
	if _ran:
		return true
	_ran = true
	var failures: PackedStringArray = []
	_check_card_catalog(failures)
	_check_legacy_card_culture(failures)
	_check_harii_shaman_culture(failures)
	_check_metamorphosis(failures)
	_check_deck_validator(failures)
	_check_anankes_binding_timing(failures)
	_check_match_command_registry_coverage(failures)
	_check_command_authority(failures)
	_check_combat_rounding(failures)
	_check_heroic_stand_combat_count(failures)
	_check_bot_locked_board_forecast(failures)
	_check_reveal_before_tactical_retreat(failures)
	_check_united_front_doorway(failures)
	_check_guan_yu_manoeuvre_and_slay(failures)
	_check_class_rend_ability_destruction(failures)
	_check_guardian_targeting(failures)
	_check_habrok_breakout_ties(failures)
	_check_ragnarok_doorway(failures)
	_check_freyja_doorway(failures)
	_check_card_interception_exceptions(failures)
	_check_target_prompt_refresh_during_submission(failures)
	_check_network_payload_guards(failures)
	_check_full_state_event_payload_budget(failures)
	_check_game_state_privacy(failures)
	_check_public_deck_knowledge(failures)
	_check_humbaba_augury_privacy(failures)
	_check_json_store_round_trip(failures)
	_check_match_supervisor_launch_config(failures)
	_check_ranked_progression(failures)
	_check_rank_badges(failures)
	_check_dedicated_ranked_history(failures)
	_check_ranked_bot_pool(failures)
	_check_quarantined_bot_release(failures)
	_check_bo3_bot_ladder_separation(failures)
	_check_cross_format_bot_identity_sync(failures)
	_check_community_bot_rank_badge(failures)
	_check_community_bot_quarantine(failures)
	_check_community_bot_replay_identity(failures)
	_check_ranked_bot_deck_generation(failures)
	_check_new_rubric_bot_batch(failures)
	_check_bot_sideboarding(failures)
	_check_ranked_bot_manifestations(failures)
	_check_bot_power_followthrough(failures)
	_check_bot_follower_valuation(failures)
	_check_bot_summon_and_intercept(failures)
	_check_bot_berserker_rage_combo(failures)
	_check_bot_interception_forecasts(failures)
	_check_bot_prepare_and_reflect(failures)
	_check_bot_eris_battle_cry_sweep(failures)
	_check_bot_namburbi_combat_ward(failures)
	_check_bot_speed_one_stealth(failures)
	_check_bot_reserve_summon_threat(failures)
	_check_bot_warding_stone_summon_forecast(failures)
	_check_bot_doorway_grave_denial(failures)
	_check_bot_fenrir_summon(failures)
	_check_bot_fenrir_creature_lethal(failures)
	_check_bot_wolf_master(failures)
	_check_bot_main_phase_combat_order(failures)
	_check_bot_equipment_forecast(failures)
	_check_bot_hyena_stealth_attack(failures)
	_check_bot_aurboda_pierce(failures)
	_check_bot_tablet_of_life_payoff(failures)
	_check_bot_conjure_eidolon(failures)
	_check_bot_removal_opens_attacks(failures)
	_check_bot_paired_removals(failures)
	_check_bot_summon_and_removal_order(failures)
	_check_bot_removal_threat_priority(failures)
	_check_bot_disable_overlap(failures)
	_check_bot_defender_target_value(failures)
	_check_bot_hermes_speed(failures)
	_check_aspect_shift(failures)
	_check_bot_aspect_shift(failures)
	_check_bot_call_of_the_crossing_safety(failures)
	_check_bot_call_of_the_crossing_holistic(failures)
	_check_bot_combat_mana_budget(failures)
	_check_aphrodite_aspect_shift(failures)
	_check_bot_violent_delights_upkeep(failures)
	_check_bot_shift_and_extraction(failures)
	_check_bot_combat_buff_value(failures)
	_check_bot_jiang_counterstroke(failures)
	_check_bot_reveal_defense(failures)
	_check_bot_exorcism_attached_sources(failures)
	_check_bot_brew_funds_pyre_lethal(failures)
	_check_bot_brew_funds_summon(failures)
	_check_bot_brew_funds_unlock(failures)
	_check_bot_immortal_techniques_refund(failures)
	_check_bot_pazuzu_drain_forecast(failures)
	_check_bot_next_turn_lethal(failures)
	_check_bot_defensive_stance_posture_gate(failures)
	_check_bot_defensive_mode_switch_option_gate(failures)
	_check_bot_mummu_entropic_force_economy(failures)
	_check_bot_mummu_active_entropy(failures)
	_check_bot_mummu_wipe_shelve_economy(failures)
	_check_bot_sirens_song_follow_through(failures)
	_check_bot_e2_abzu_sage_retrieval(failures)
	_check_bot_entomb_save_ceiling(failures)
	_check_standing_bot_seeks(failures)
	_check_ladder_pages(failures)
	_check_request_next(failures)
	_check_gugalanna_celestial_charge(failures)
	_release_fixtures()

	if not failures.is_empty():
		for failure in failures:
			push_error("preflight_probe: %s" % failure)
		_write_result_file(false, failures)
		return false

	print("preflight_probe: PASS")
	_write_result_file(true, failures)
	return true

func _new_fixture_game() -> GameManager:
	var game := GameManager.new()
	_fixture_games.append(game)
	return game

func _new_fixture_player() -> Player:
	var player := Player.new()
	_fixture_players.append(player)
	return player

func _new_fixture_match(game: GameManager) -> MatchManager:
	var manager := MatchManager.new(game)
	_fixture_matches.append(manager)
	return manager

func _new_fixture_bot() -> PracticeFuzzPlayerBot:
	var bot := PracticeFuzzPlayerBot.new()
	_fixture_bots.append(bot)
	return bot

func _release_fixtures() -> void:
	for bot in _fixture_bots:
		bot.detach()
	_fixture_bots.clear()
	for manager in _fixture_matches:
		manager.reset_runtime_state()
	_fixture_matches.clear()
	for game in _fixture_games:
		for player in game.players:
			if player not in _fixture_players:
				_fixture_players.append(player)
		# A queued resolver can capture its own action or match. Abandon
		# pending test work without executing gameplay during teardown.
		for action: CardAction in game.action_stack + game.resolving_stack_actions:
			action.resolve_callback = Callable()
		game.action_stack.clear()
		game.resolving_stack_actions.clear()
		game._pending_doorway_continue = Callable()
		game._queued_doorway_requests.clear()
		game._pending_return_to_hand_continue = Callable()
		game._deferred_combat_resume = Callable()
	_fixture_games.clear()
	for player in _fixture_players:
		player.game_manager = null
		player.current_deck.clear()
		player.card_collection.clear()
		player.reserved_active_god = null
		# Zones own their cards and players own their zones. Break the
		# back-references and clear effect sources that can point at themselves.
		for zone: Zone in [player.hand_zone, player.deck_zone, player.graveyard_zone, player.abyss_zone, player.god_zone] + player.power_zones + player.frontline_zones + player.reserve_zones:
			for card in zone.cards.duplicate():
				card.active_buffs.clear()
				card.active_statuses.clear()
				card.sleeping_from = null
				for equipment in card.equipment:
					equipment.equipped_on = null
				card.equipment.clear()
				zone.remove_card(card)
			zone.zone_owner = null
	_fixture_players.clear()

func _check_card_catalog(failures: PackedStringArray) -> void:
	for path in CardCatalogScript.CARD_SCRIPT_PATHS:
		if not ResourceLoader.exists(path):
			failures.append("registered card script is missing: %s" % path)
			continue
		var script = load(path)
		if script == null:
			failures.append("registered card script failed to load: %s" % path)

	var cards: Array[Card] = CardCatalogScript.make_all_cards()
	if cards.size() < MIN_CATALOG_CARDS:
		failures.append("card catalog only produced %d cards" % cards.size())
	var thor_one := CardCatalogScript.instantiate_card_by_name("Thor")
	var thor_two := CardCatalogScript.instantiate_card_by_name("Thor")
	if thor_one == null or thor_two == null:
		failures.append("card catalog failed to instantiate Thor by exact name")
	elif thor_one == thor_two:
		failures.append("card catalog returned a shared cached card instance")
	var compact_fall := CardCatalogScript.instantiate_card_by_name("fallofthemighty")
	if compact_fall == null:
		failures.append("card catalog failed to instantiate Fall of the Mighty by lookup key")
	elif CardCatalogScript.to_lookup_key(str(compact_fall.card_name)) != "fallofthemighty":
		failures.append("card catalog lookup key resolved the wrong card: %s" % str(compact_fall.card_name))

	var seen_names: Dictionary = {}
	for card in cards:
		if card == null:
			failures.append("card catalog returned a null card")
			continue
		var card_name := str(card.card_name).strip_edges()
		if card_name.is_empty() or card_name == "Unnamed" or card_name == "Card":
			failures.append("card catalog returned an unnamed card from %s" % _script_path(card))
			continue
		if seen_names.has(card_name):
			failures.append("card catalog returned duplicate card name: %s" % card_name)
		seen_names[card_name] = true
		if bool(card.is_token) or card.card_types.has("Token"):
			failures.append("card catalog exposed token card: %s" % card_name)
		for subtype in card.card_types:
			if CardSubtypes.is_culture_label(subtype):
				failures.append("card catalog includes culture as a subtype on %s: %s" % [card_name, subtype])

func _check_legacy_card_culture(failures: PackedStringArray) -> void:
	var legacy_card := {
		"card_type": Card.CardType.CREATURE,
		"card_types": ["Human", "Triskelion Creature"],
		"field_subtypes": ["Animal", "Norse Creature"],
		"active_statuses": [{"name": "legacy", "original_card_types": ["Human", "Triskelion Creature"]}],
	}
	var restored := GameState.deserialize_embedded_card(legacy_card)
	if restored.culture != "Triskelion" or restored.card_types != ["Human"] or restored.field_subtypes != ["Animal"] \
			or restored.active_statuses[0]["original_card_types"] != ["Human"]:
		failures.append("legacy snapshot culture did not migrate to the culture field")
	legacy_card["culture"] = "Olympic"
	if GameState.deserialize_embedded_card(legacy_card).culture != "Olympic":
		failures.append("a legacy subtype overrode the explicit culture field")

func _check_harii_shaman_culture(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	game.players.assign([player, _new_fixture_player()])
	game.current_player = player
	var shaman := HariiShaman.new()
	shaman.card_owner = player
	player.frontline_zones[0].add_card(shaman)
	var bear := BrownBear.new()
	bear.card_owner = player
	player.reserve_zones[0].add_card(bear)
	shaman.resolve_transform(game, bear)
	if bear.culture != "Norse" or not bear.has_type("Human") or not bear.has_type("Warrior") or bear.has_type("Animal"):
		failures.append("Harii Shaman did not change the animal's culture and subtypes to a Norse Human Warrior")

func _check_metamorphosis(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	player.game_manager = game
	opponent.game_manager = game
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var input := ServerBotGameInput.new(manager, 0)
	var spell := CardCatalogScript.instantiate_card_by_name("Metamorphosis") as Metamorphosis
	if spell == null or spell.level != 2 or spell.mana_cost != 0 or spell.culture != "Olympic" \
			or spell.card_type != Card.CardType.SPELL or not spell.has_type("Transformation") \
			or not spell.has_type("Aura") or not spell.is_permanent():
		failures.append("Metamorphosis catalog entry has incorrect card data")
		return
	spell.card_owner = player
	player.hand_zone.add_card(spell)
	var duplicate_typing := CreatureCard.new()
	duplicate_typing.card_types = ["Porcine", "Animal", "Olympic Creature", "Targeting"]
	var gawain := Gawain.new()
	player.record_starting_creature_typings([Gullinbursti.new(), gawain, duplicate_typing, spell])
	opponent.record_starting_creature_typings([BrownBear.new()])
	if player.starting_creature_typings.size() != 2 or gawain.get_subtypes().has("Triskelion Creature"):
		failures.append("Metamorphosis did not combine equivalent typings or hide culture labels")
	var knight := CreatureCard.new()
	knight.card_types = ["Knight"]
	knight.culture = "Triskelion"
	knight.card_owner = player
	player.frontline_zones[0].add_card(knight)
	var opposing_creature := BrownBear.new()
	opposing_creature.card_owner = opponent
	opponent.reserve_zones[0].add_card(opposing_creature)
	var face_down_creature := BrownBear.new()
	face_down_creature.card_owner = opponent
	face_down_creature.is_face_down = true
	opponent.reserve_zones[1].add_card(face_down_creature)
	var stealthed_creature := BrownBear.new()
	stealthed_creature.card_owner = player
	stealthed_creature.is_stealth = true
	player.reserve_zones[1].add_card(stealthed_creature)
	var equipment := BeardedAxe.new()
	equipment.card_owner = player
	player.frontline_zones[0].add_card(equipment)
	equipment.equip_to(knight)
	var god := Odin.new()
	god.card_owner = opponent
	opponent.god_zone.add_card(god)
	var power := KurnugiaTheBeginningOfTheEnd.new()
	power.card_owner = opponent
	power.is_face_down = true
	opponent.power_zones[0].add_card(power)
	var hand_card := BrownBear.new()
	hand_card.card_owner = opponent
	opponent.hand_zone.add_card(hand_card)
	var structure := Watchtower.new()
	structure.card_owner = opponent
	opponent.frontline_zones[0].add_card(structure)
	if not knight.has_type("Warrior") or not CardSubtypes.matches("Raven", "Animal"):
		failures.append("Card subtype hierarchy did not inherit parent types")
	for invalid_choice in ["Gullinbursti", "Animal / Ursine", "Animal / Norse Creature / Porcine"]:
		if input.submit_action({type = "cast_spell", spell_uid = spell.uid, creature_typing = invalid_choice}):
			failures.append("Metamorphosis accepted an ineligible decklist choice: %s" % invalid_choice)
	if not input.submit_action({type = "cast_spell", spell_uid = spell.uid, creature_typing = "Animal / Porcine"}):
		failures.append("Metamorphosis could not be cast with zero mana and an eligible typing")
		return
	for _step in range(8):
		manager.advance_priority()
	for transformed: Card in [knight, opposing_creature]:
		if not transformed.has_type("Porcine") or not transformed.has_type("Animal") or transformed.has_type("Norse Creature"):
			failures.append("Metamorphosis did not copy explicit subtypes alone to face-up creatures on both sides")
			break
	for unaffected: Card in [equipment, god, power, structure, hand_card, face_down_creature, stealthed_creature]:
		if unaffected.get_subtypes() != unaffected.card_types:
			failures.append("Metamorphosis transformed a card outside its face-up creature scope")
			break
	if knight.has_type("Warrior") or knight.culture != "Triskelion" or equipment.equipped_on != knight or not spell.is_aura_live():
		failures.append("Metamorphosis did not stay face up as an Aura or preserve culture and attachments")
	if spell.get_hover_detail_lines(player) != ["Animal / Porcine"]:
		failures.append("Metamorphosis did not return the chosen typing as typed hover text")
	var board_popup := CardDetailContentBuilder.build_board_popup_body(spell, player, {"game_manager": game})
	if board_popup == null:
		failures.append("Metamorphosis could not build its board popup after resolving")
	else:
		board_popup.free()
	var snapshot := GameState.serialize(game, 0)
	var hidden_creature: Dictionary = snapshot["players"][1]["reserve_zones"][1][0]
	if hidden_creature.has("field_subtypes") or hidden_creature.has("card_name"):
		failures.append("Metamorphosis leaked a face-down creature through a match snapshot")
	var mirror := _new_fixture_game()
	mirror.players.assign([_new_fixture_player(), _new_fixture_player()])
	mirror.setup_game()
	GameState.apply_to_manager(snapshot, mirror)
	var mirrored_knight := mirror.get_card_by_uid(knight.uid)
	if mirrored_knight == null or not mirrored_knight.has_type("Porcine") or mirrored_knight.culture != "Triskelion" \
			or mirrored_knight.has_type("Warrior") or not mirror.players[0].starting_creature_typings.has("Human / Knight / Warrior") \
			or not mirror.players[1].starting_creature_typings.is_empty():
		failures.append("Metamorphosis Aura did not round-trip through a match snapshot")
	face_down_creature.reveal(game)
	var entrant := BrownBear.new()
	entrant.card_owner = opponent
	opponent.move_card(entrant, opponent.reserve_zones[2])
	if not face_down_creature.has_type("Porcine") or not entrant.has_type("Porcine"):
		failures.append("Metamorphosis did not apply to creatures revealed or entering play after it resolved")
	spell.is_face_down = true
	if not knight.has_type("Warrior") or entrant.has_type("Porcine"):
		failures.append("Metamorphosis remained active while face down")
	spell.reveal(game)
	player.move_card(knight, player.reserve_zones[2])
	if not knight.has_type("Porcine"):
		failures.append("Metamorphosis expired while a card was still in play")
	player.move_card(knight, player.graveyard_zone)
	if knight.has_type("Porcine") or not knight.has_type("Warrior"):
		failures.append("Metamorphosis did not restore original typing when the card left play")
	var second_aura := Metamorphosis.new()
	second_aura.card_owner = player
	second_aura.is_prepared = true
	second_aura.is_face_down = true
	player.reserve_zones[3].add_card(second_aura)
	if not input.submit_action({type = "cast_spell", spell_uid = second_aura.uid, creature_typing = "Human / Knight / Warrior"}):
		failures.append("Prepared Metamorphosis could not activate")
	else:
		for _step in range(8):
			manager.advance_priority()
		if not entrant.has_type("Knight") or not entrant.has_type("Human") or entrant.has_type("Triskelion Creature") \
				or entrant.has_type("Porcine") or second_aura.current_zone != player.reserve_zones[3]:
			failures.append("The most recently resolved Metamorphosis did not take precedence")
	player.move_card(second_aura, player.graveyard_zone)
	if not entrant.has_type("Porcine"):
		failures.append("The older Metamorphosis did not resume after the newer Aura left play")
	player.move_card(spell, player.graveyard_zone)
	if entrant.has_type("Porcine") or not entrant.has_type("Ursine") or not face_down_creature.has_type("Ursine"):
		failures.append("Metamorphosis did not restore underlying subtypes when the final Aura left play")

func _check_anankes_binding_timing(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.setup_game()
	var binding := AnankesBinding.new()
	var chosen := BrownBear.new()
	var later := Enkidu.new()
	binding.card_owner = player
	binding.is_face_down = false
	chosen.card_owner = player
	later.card_owner = player
	player.power_zones[0].add_card(binding)
	player.deck_zone.add_card(chosen)
	player.deck_zone.add_card(later)
	player.mana = 2 * AnankesBinding.ACTIVATION_COST
	binding.activate(game, chosen)
	if not chosen.is_revealed_to_all():
		failures.append("Ananke's Binding did not reveal the card it stored")
	game._notify_controller_turn_end(player)
	game.current_player = opponent
	game._notify_controller_turn_end(opponent)
	if chosen not in binding.stored_cards or chosen in player.deck_zone.cards:
		failures.append("Ananke's Binding primed a card before the owner's next turn ended")
	game.current_player = player
	binding.activate(game, later)
	var stored_entries: Array = binding.get_serialized_state()["stored_cards"]
	if stored_entries.size() != 2 or stored_entries[0]["turns_until_return"] != 1 or stored_entries[1]["turns_until_return"] != 2:
		failures.append("Ananke's Binding did not preserve individual countdowns in match snapshots")
	game._notify_controller_turn_end(player)
	if chosen in binding.stored_cards or player.deck_zone.cards.front() != chosen:
		failures.append("Ananke's Binding did not prime the chosen card at the end of the owner's next turn")
	if player.deck_zone.get_deck_placement(chosen) != Zone.DeckPlacement.PRIMED \
			or not player.deck_zone.is_deck_identity_public(chosen):
		failures.append("Ananke's Binding did not keep the stored card's identity public when priming it")
	if later not in binding.stored_cards or later in player.deck_zone.cards:
		failures.append("Ananke's Binding primed the second card with the first card")
	game._notify_controller_turn_end(player)
	if later in binding.stored_cards or player.deck_zone.cards.front() != later:
		failures.append("Ananke's Binding did not prime the second card on its own countdown")
	player.deck_zone.shuffle_deck()
	if chosen.is_revealed_to_all() or later.is_revealed_to_all() \
			or player.deck_zone.is_deck_identity_public(chosen) \
			or player.deck_zone.is_deck_identity_public(later):
		failures.append("Shuffling did not clear Ananke's public reveal on stored cards")

func _check_deck_validator(failures: PackedStringArray) -> void:
	var validator = DeckValidatorScript.new()
	var valid_deck := _known_good_deck_counts()
	var result: Dictionary = validator.validate_deck(valid_deck)
	if not bool(result.get("is_valid", false)):
		failures.append("known-good deck failed validation: %s" % str(result.get("error", "")))
	var invalid_result: Dictionary = validator.validate_deck({"Thor": 2})
	if bool(invalid_result.get("is_valid", false)):
		failures.append("invalid duplicate-god deck passed validation")
	if DeckValidatorScript.get_reinforcement_limit(40, 3) != 14:
		failures.append("40 regular cards plus 3 Powers should allow 14 Reinforcements")
	var oversized_reinforcements := {
		"Tablet of Life": 3,
		"Pictish Beast": 3,
		"Hyena Pack": 3,
		"Ancient Pyre": 3,
		"Harii Shaman": 2,
	}
	var reinforcement_result: Dictionary = validator.validate_deck(valid_deck, {}, oversized_reinforcements)
	if bool(reinforcement_result.get("is_valid", false)):
		failures.append("deck validator accepted Reinforcements above the rounded-down limit")
	var registered_reinforcements := {"Tablet of Life": 3}
	var proposed_main := valid_deck.duplicate(true)
	proposed_main["Tablet of Life"] = 2
	var proposed_reinforcements := {
		"Tablet of Life": 1,
	}
	var swap_result: Dictionary = validator.validate_reinforcement_swap(
		valid_deck,
		registered_reinforcements,
		proposed_main,
		proposed_reinforcements
	)
	if not bool(swap_result.get("is_valid", false)):
		failures.append("legal Reinforcement resubmission with changed main-deck size failed validation: %s" % str(swap_result.get("error", "")))
	# Your actual god can never sit in Reinforcements.
	var god_side_result: Dictionary = validator.validate_deck(valid_deck, {}, {"Thor": 1})
	if bool(god_side_result.get("is_valid", false)):
		failures.append("deck validator accepted the God slot card in Reinforcements")
	# Deck-legal (foreign) Active Gods follow normal Reinforcement rules: an
	# Odin Patriarch deck may side out a foreign Norse Active God.
	var odin_main := {
		"Odin, the Allfather": 1,
		"Thor, Active God": 1,
		"Harii Warrior": 3,
		"Harii Shaman": 3,
		"Harii Fransiscan": 3,
		"Valkyrie Warrior": 3,
		"Skoll": 3,
		"White Stag": 3,
		"Wolf Cub": 3,
		"Hrimgrimmnir": 3,
		"Berserker": 3,
		"Gullinbursti": 3,
		"Muninn": 3,
		"Again-Walker": 3,
		"Hel-blar Draug": 3,
		"Huginn": 1,
	}
	var odin_main_result: Dictionary = validator.validate_deck(odin_main, {}, {})
	if not bool(odin_main_result.get("is_valid", false)):
		failures.append("Odin deck with a foreign Active God in the main deck failed validation: %s" % str(odin_main_result.get("error", "")))
	else:
		var odin_main_cards: Dictionary = odin_main_result.get("cards", {})
		var god_to_side_main: Dictionary = odin_main_cards.duplicate(true)
		god_to_side_main["Thor, Active God"] = int(god_to_side_main.get("Thor, Active God", 1)) - 1
		if int(god_to_side_main["Thor, Active God"]) <= 0:
			god_to_side_main.erase("Thor, Active God")
		var god_swap_result: Dictionary = validator.validate_reinforcement_swap(
			odin_main_cards, {}, god_to_side_main, {"Thor, Active God": 1}
		)
		if not bool(god_swap_result.get("is_valid", false)):
			failures.append("Reinforcement swap rejected siding out a deck-legal Active God: %s" % str(god_swap_result.get("error", "")))
	var player := _new_fixture_player()
	if not player.validate_deck(_cards_from_counts(valid_deck)):
		failures.append("Player.validate_deck rejected a DeckValidator-valid deck")
	if player.validate_deck(_cards_from_counts({"Thor": 2})):
		failures.append("Player.validate_deck accepted an invalid duplicate-god deck")

func _check_match_command_registry_coverage(failures: PackedStringArray) -> void:
	var implemented_commands := _extract_match_manager_command_types(failures)
	if implemented_commands.is_empty():
		return
	var registered_commands := MatchCommandRegistryScript.get_known_command_types()
	var implemented_lookup := _string_lookup(implemented_commands)
	var registered_lookup := _string_lookup(registered_commands)
	for command_type in implemented_commands:
		if not registered_lookup.has(command_type):
			failures.append("MatchCommandRegistry is missing implemented command: %s" % command_type)
	for command_type in registered_commands:
		if not implemented_lookup.has(command_type):
			failures.append("MatchCommandRegistry lists unimplemented command: %s" % command_type)

func _extract_match_manager_command_types(failures: PackedStringArray) -> Array[String]:
	var source_path := "res://scripts/Other/MatchManager.gd"
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		failures.append("preflight could not read %s" % source_path)
		return []
	var source := file.get_as_text()
	file.close()
	var start_idx := source.find("func _process_command_impl")
	var end_idx := source.find("move_failed.emit(\"Unknown command type", start_idx)
	if start_idx < 0 or end_idx <= start_idx:
		failures.append("preflight could not find MatchManager command dispatch block")
		return []
	var dispatch_source := source.substr(start_idx, end_idx - start_idx)
	var regex := RegEx.new()
	if regex.compile("(?m)^\\t\\t\"([a-z0-9_]+)\":") != OK:
		failures.append("preflight could not compile command dispatch regex")
		return []
	var commands: Array[String] = []
	for match_result in regex.search_all(dispatch_source):
		var command_type := match_result.get_string(1)
		if command_type not in commands:
			commands.append(command_type)
	# Cosmetic commands can return from process_command before rules dispatch.
	var entry_idx := source.find("func process_command(")
	var early_dispatch := RegEx.new()
	if entry_idx >= 0 and early_dispatch.compile("(?m)^\\tif str\\(command\\.get\\(\"type\", \"\"\\)\\) == \"([a-z0-9_]+)\":\\r?\\n\\t\\treturn _process_[a-z0-9_]+\\(command, sender_info\\)") == OK:
		for match_result in early_dispatch.search_all(source.substr(entry_idx, start_idx - entry_idx)):
			var command_type := match_result.get_string(1)
			if command_type not in commands:
				commands.append(command_type)
	commands.sort()
	return commands

func _string_lookup(values: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for value in values:
		var text := str(value)
		if not text.is_empty():
			lookup[text] = true
	return lookup

func _check_command_authority(failures: PackedStringArray) -> void:
	var game_manager := _new_fixture_game()
	var player_one := _new_fixture_player()
	player_one.player_name = "Player 1"
	game_manager.players.append(player_one)
	var player_two := _new_fixture_player()
	player_two.player_name = "Player 2"
	game_manager.players.append(player_two)
	game_manager.current_player = player_one
	game_manager.other_player = player_two
	game_manager.turn_player = player_one
	game_manager.turn_number = 2
	game_manager._upkeep_started_turn = game_manager.turn_number
	game_manager._upkeep_resolved_turn = game_manager.turn_number

	var match_manager := _new_fixture_match(game_manager)
	var attacker := BaseCard.new()
	attacker.card_name = "Probe Attacker"
	attacker.card_type = Card.CardType.CREATURE
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.card_owner = player_one
	player_one.frontline_zones[0].add_card(attacker)
	var required_player := MatchCommandRegistryScript.get_required_player(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		game_manager,
		match_manager
	)
	if required_player != player_one:
		failures.append("command registry resolved the wrong player for select_attacker")
	if MatchCommandRegistryScript.get_ui_interaction_type("intercept_decision") != "intercept":
		failures.append("command registry lost the intercept prompt mapping")
	if not MatchCommandRegistryScript.requires_clear_stack_window("play_card"):
		failures.append("command registry should block play_card during unresolved stack windows")
	if MatchCommandRegistryScript.requires_resolved_upkeep({"type": "priority_pass"}):
		failures.append("command registry should allow priority_pass during upkeep prompts")
	if not MatchCommandRegistryScript.is_known_command_type("select_attacker"):
		failures.append("command registry lost known command coverage for select_attacker")
	if MatchCommandRegistryScript.is_known_command_type("draw"):
		failures.append("command registry treated an upkeep choice value as a command type")
	if MatchCommandRegistryScript.is_known_command_type("probe_unknown_command"):
		failures.append("command registry accepted an unknown command type")
	var unknown_command := match_manager.process_command(
		{
			"type": "probe_unknown_command",
		},
		{
			"peer_id": 1,
			"player_index": 0,
		}
	)
	if unknown_command:
		failures.append("unknown command was processed successfully")
	if match_manager.last_move_failed_reason.find("Unknown command type") == -1:
		failures.append("unknown command did not fail with a clear reason: %s" % match_manager.last_move_failed_reason)

	match_manager.last_move_failed_reason = ""
	var unauthorized := match_manager.process_command(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		{
			"peer_id": 2,
			"player_index": 1,
		}
	)
	if unauthorized:
		failures.append("unauthorized player was allowed to select attacker")
	if match_manager.last_move_failed_reason.find("belongs to Player 1") == -1:
		failures.append("unexpected unauthorized command failure reason: %s" % match_manager.last_move_failed_reason)

	match_manager.last_move_failed_reason = ""
	var authorized := match_manager.process_command(
		{
			"type": "select_attacker",
			"card_uid": attacker.uid,
		},
		{
			"peer_id": 1,
			"player_index": 0,
		}
	)
	if not authorized:
		failures.append("authorized player could not select attacker: %s" % match_manager.last_move_failed_reason)
	elif match_manager.selected_attacker != attacker:
		failures.append("authorized attacker selection did not stick")

func _check_target_prompt_refresh_during_submission(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	var manager := _new_fixture_match(game)
	var lailoken := Lailoken.new()
	lailoken.card_owner = player
	player.frontline_zones[0].add_card(lailoken)
	var target := SpellCard.new()
	var other_target := SpellCard.new()
	for spell in [target, other_target]:
		spell.card_name = "Prepared Spell"
		spell.card_owner = opponent
		spell.is_prepared = true
	opponent.frontline_zones[0].add_card(target)
	opponent.frontline_zones[1].add_card(other_target)
	manager._record_pending_ui_interaction(player, "lailoken_reveal", {"source_uid": lailoken.uid})
	var prompts_during_refresh: Array[int] = []
	manager.move_validated.connect(func(_move: Dictionary) -> void:
		prompts_during_refresh.append(manager.get_pending_reveal_target_ui_interactions().size())
		prompts_during_refresh.append(manager.get_pending_state_refresh_ui_interactions().size())
	, CONNECT_ONE_SHOT)
	var submitted := manager.process_command({
		"type": "lailoken_reveal_choice", "source_uid": lailoken.uid, "target_uid": target.uid,
	})
	if not submitted or target.current_zone != opponent.graveyard_zone \
			or manager.get_pending_ui_interaction_count() != 0 \
			or other_target not in lailoken.get_valid_targets(game):
		failures.append("Lailoken's target choice failed to resolve with another valid target still in play")
	if prompts_during_refresh != [0, 0]:
		failures.append("Submitting Lailoken's target choice re-exposed the answered prompt during state refresh")

func _check_network_payload_guards(failures: PackedStringArray) -> void:
	var network_manager = NetworkManagerScript.new()
	var valid_reason: String = network_manager.get_command_payload_rejection_reason({"type": "priority_pass"})
	if not valid_reason.is_empty():
		failures.append("network guard rejected a simple valid command: %s" % valid_reason)
	var shorthand_key_reason: String = network_manager.get_command_payload_rejection_reason({type = "priority_pass"})
	if not shorthand_key_reason.is_empty():
		failures.append("network guard rejected a command with StringName shorthand keys: %s" % shorthand_key_reason)
	var missing_type_reason: String = network_manager.get_command_payload_rejection_reason({"player_index": 0})
	if missing_type_reason.is_empty():
		failures.append("network guard accepted a command without a type")
	var unknown_type_reason: String = network_manager.get_command_payload_rejection_reason({"type": "probe_unknown_command"})
	if unknown_type_reason.find("Unknown command type") == -1:
		failures.append("network guard accepted an unknown command type: %s" % unknown_type_reason)
	var oversized_value := ""
	for _index in range(NetworkManagerScript.MAX_NETWORK_PAYLOAD_STRING_LENGTH + 1):
		oversized_value += "x"
	var oversized_reason: String = network_manager.get_command_payload_rejection_reason(
		{
			"type": "priority_pass",
			"payload": oversized_value,
		}
	)
	if oversized_reason.is_empty():
		failures.append("network guard accepted an oversized command string")
	var unsupported_node := Node.new()
	var unsupported_reason: String = network_manager.get_command_payload_rejection_reason(
		{
			"type": "priority_pass",
			"payload": unsupported_node,
		}
	)
	unsupported_node.free()
	if unsupported_reason.is_empty():
		failures.append("network guard accepted an unsupported object payload")
	var below_top_50_validation := LobbyProtocolScript.validate_request(LobbyProtocolScript.make_message(
		LobbyProtocolScript.REQUEST_BOT_WORK,
		{"below_top_50": true}))
	if not below_top_50_validation.is_empty():
		failures.append("lobby guard rejected a below-top-50 bot work request: %s" % below_top_50_validation)
	for invalid_bot_work in [
		{"top_50": true, "below_top_50": true},
		{"bot_id": "owned_bot", "below_top_50": true},
		{"below_top_50": "true"},
	]:
		var invalid_reason := LobbyProtocolScript.validate_request(LobbyProtocolScript.make_message(
			LobbyProtocolScript.REQUEST_BOT_WORK,
			invalid_bot_work))
		if invalid_reason.is_empty():
			failures.append("lobby guard accepted invalid below-top-50 bot work: %s" % JSON.stringify(invalid_bot_work))
	var join_reason: String = network_manager.get_join_request_payload_rejection_reason(
		{
			"match_id": "probe",
			"session_id": "probe-session",
		}
	)
	if not join_reason.is_empty():
		failures.append("network guard rejected a simple join request: %s" % join_reason)
	var valid_event_reason: String = network_manager.get_game_event_payload_rejection_reason("full_state", {"turn": 1})
	if not valid_event_reason.is_empty():
		failures.append("network guard rejected a simple game event: %s" % valid_event_reason)
	var missing_event_type_reason: String = network_manager.get_game_event_payload_rejection_reason("", {})
	if missing_event_type_reason.is_empty():
		failures.append("network guard accepted a game event without a type")
	var oversized_event_value := ""
	for _index in range(NetworkManagerScript.MAX_NETWORK_PAYLOAD_STRING_LENGTH + 1):
		oversized_event_value += "x"
	var oversized_event_reason: String = network_manager.get_game_event_payload_rejection_reason(
		"full_state",
		{
			"payload": oversized_event_value,
		}
	)
	if oversized_event_reason.is_empty():
		failures.append("network guard accepted an oversized game event string")
	network_manager.free()

func _check_full_state_event_payload_budget(failures: PackedStringArray) -> void:
	var game_manager := _new_fixture_game()
	var deck_counts := _known_good_deck_counts()
	var session := MatchSessionScript.new(
		"preflight_payload_budget",
		"preflight_room",
		"127.0.0.1",
		12345,
		["session_one", "session_two"],
		{
			"session_one": {"deck_name": "Preflight One", "cards": deck_counts, "reinforcements": {"Gawain": 1}},
			"session_two": {"deck_name": "Preflight Two", "cards": deck_counts},
		},
		{
			"session_one": {"player_name": "Player 1"},
			"session_two": {"player_name": "Player 2"},
		}
	)
	var setup = DefaultMatchSetupScript.new()
	if setup.build_match_from_session_decks(game_manager, session).is_empty():
		failures.append("preflight could not build submitted-deck match for full_state payload budget")
		return
	var starting_typings := game_manager.players[0].starting_creature_typings
	if not starting_typings.has("Human / Knight / Warrior") or not starting_typings.has("Animal / Ursine") or starting_typings.has("Silence"):
		failures.append("submitted deck did not record just the starting and Reinforcement creature typings")
	game_manager.start_turn()
	var network_manager = NetworkManagerScript.new()
	for view in [[0, []], [1, []], [GameState.SPECTATOR_VIEWER_INDEX, []], [GameState.SPECTATOR_VIEWER_INDEX, [0, 1]]]:
		var viewer_index: int = view[0]
		var visible_indices: Array = view[1]
		var event_payload := {
			"state": GameState.serialize(game_manager, viewer_index, visible_indices),
			"action_message": "preflight payload budget",
		}
		for player_index in range(2):
			var has_private_typings: bool = event_payload["state"]["players"][player_index].has("starting_creature_typings")
			if has_private_typings != (viewer_index == player_index):
				failures.append("starting creature typings were not private to their owner")
		var rejection_reason: String = network_manager.get_game_event_payload_rejection_reason("full_state", event_payload)
		if not rejection_reason.is_empty():
			var payload_bytes := JSON.stringify(event_payload).to_utf8_buffer().size()
			failures.append("full_state payload for viewer %d exceeded network guard: %s (%d bytes)" % [
				viewer_index,
				rejection_reason,
				payload_bytes,
			])
	network_manager.free()

func _check_game_state_privacy(failures: PackedStringArray) -> void:
	var game_manager := _new_fixture_game()
	var player_one := _new_fixture_player()
	player_one.player_name = "Player 1"
	game_manager.players.append(player_one)
	var player_two := _new_fixture_player()
	player_two.player_name = "Player 2"
	game_manager.players.append(player_two)
	game_manager.current_player = player_one
	game_manager.other_player = player_two
	game_manager.turn_player = player_one

	var own_card := BaseCard.new()
	own_card.card_name = "Probe Own Hand"
	own_card.card_owner = player_one
	player_one.hand_zone.add_card(own_card)
	var opponent_card := BaseCard.new()
	opponent_card.card_name = "Probe Opponent Secret"
	opponent_card.card_owner = player_two
	player_two.hand_zone.add_card(opponent_card)

	var state := GameState.serialize(game_manager, 0)
	var players = state.get("players", [])
	if not (players is Array) or (players as Array).size() != 2:
		failures.append("serialized state did not contain two players")
		return
	var own_hand = ((players as Array)[0] as Dictionary).get("hand", [])
	var opponent_hand = ((players as Array)[1] as Dictionary).get("hand", [])
	if not (own_hand is Array) or (own_hand as Array).is_empty():
		failures.append("viewer hand was missing from serialized state")
	elif bool(((own_hand as Array)[0] as Dictionary).get("hidden", false)):
		failures.append("viewer hand was hidden from itself")
	if not (opponent_hand is Array) or (opponent_hand as Array).is_empty():
		failures.append("opponent hand placeholder was missing from serialized state")
	else:
		var hidden_card := (opponent_hand as Array)[0] as Dictionary
		if not bool(hidden_card.get("hidden", false)):
			failures.append("opponent hand card was not hidden from viewer")
		if hidden_card.has("card_name"):
			failures.append("opponent hand leaked card name: %s" % str(hidden_card.get("card_name", "")))

func _check_public_deck_knowledge(failures: PackedStringArray) -> void:
	var manager := _new_fixture_game()
	var deck_owner := _new_fixture_player()
	manager.players.assign([deck_owner, _new_fixture_player()])
	var deck := deck_owner.deck_zone
	var hidden := BrownBear.new()
	hidden.card_owner = deck_owner
	deck.add_card(hidden)
	var first := RedCap.new()
	first.card_owner = deck_owner
	deck.add_card(first)
	deck.prime_card(first)
	var second := Huginn.new()
	second.card_owner = deck_owner
	deck_owner.hand_zone.add_card(second)
	deck_owner.move_card(second, deck, Zone.DeckPlacement.PRIMED)
	var shelved := Muninn.new()
	shelved.card_owner = deck_owner
	deck_owner.hand_zone.add_card(shelved)
	deck_owner.shelve_card(shelved)

	var mirror := _new_fixture_game()
	mirror.players.assign([_new_fixture_player(), _new_fixture_player()])
	var mirror_deck := mirror.players[0].deck_zone
	for viewer in [0, 1, GameState.SPECTATOR_VIEWER_INDEX]:
		GameState.apply_to_manager(GameState.serialize(manager, viewer), mirror)
		if viewer == 0:
			if mirror_deck.get_card_count() != 4 or mirror_deck.get_primed_top_card() == null \
					or mirror_deck.get_primed_top_card().uid != second.uid \
					or mirror_deck.get_known_deck_card(1) == null or mirror_deck.get_known_deck_card(1).uid != first.uid \
					or mirror_deck.get_known_deck_card(2) != null \
					or mirror_deck.get_known_deck_card(3) == null or mirror_deck.get_known_deck_card(3).uid != shelved.uid:
				failures.append("The deck owner lost their own primed/shelved positions for viewer %d" % viewer)
				break
		else:
			if mirror_deck.get_card_count() != 4 or mirror_deck.get_known_deck_card(2) != null:
				failures.append("Unknown deck positions leaked to viewer %d" % viewer)
				break
			var placed_cards := [
				mirror_deck.get_primed_top_card(),
				mirror_deck.get_known_deck_card(1),
				mirror_deck.get_known_deck_card(3),
			]
			var positions_visible := true
			for placed_card in placed_cards:
				if placed_card == null or placed_card.card_name != "Hidden card" or not placed_card.is_face_down:
					positions_visible = false
					break
			if not positions_visible:
				failures.append("Hidden primed/shelved positions lost their placeholders for viewer %d" % viewer)
				break
		if viewer != 0 and mirror.get_card_by_uid(hidden.uid) != null:
			failures.append("Unknown deck card leaked to viewer %d" % viewer)
			break
	var opponent := manager.players[1]
	manager.current_player = opponent
	manager.other_player = deck_owner
	manager.turn_player = opponent
	var throne := HildskjalfThroneOfOdin.new()
	throne.card_owner = opponent
	opponent.reserve_zones[0].add_card(throne)
	GameState.apply_to_manager(GameState.serialize(manager, 1), mirror)
	if mirror_deck.cards[2].uid != hidden.uid or mirror_deck.get_known_deck_card(2) != null:
		failures.append("A private High Seat peek did not stay separate from public deck knowledge")
	opponent.reserve_zones[0].remove_card(throne)
	var bot := ThorPracticeBot.new()
	bot.bot_player = opponent
	bot.opponent = deck_owner
	if BotCardStrategyScript.visible(bot, shelved) or BotCardStrategyScript.visible(bot, hidden):
		failures.append("Bot visibility did not distinguish public from unknown deck cards")

	if deck_owner.draw_card() != second or deck.get_primed_top_card() != first \
			or deck.get_deck_placement(second) != Zone.DeckPlacement.UNKNOWN:
		failures.append("Drawing a primed card did not expose the next primed card")
	if second.is_revealed_in_hand():
		failures.append("Drawing a privately primed card wrongly revealed it in hand")
	deck.shelve_deck_card(first)
	if deck.known_top_card != null or deck.get_known_deck_card(1) != shelved or deck.get_known_deck_card(2) != first:
		failures.append("Shelving a primed card did not preserve public cards in bottom order")
	deck.shuffle_deck()
	GameState.apply_to_manager(GameState.serialize(manager, 1), mirror)
	if BotCardStrategyScript.visible(bot, shelved):
		failures.append("Bot retained the identity of a shelved deck position after a shuffle")
	for index in deck.get_card_count():
		if deck.get_known_deck_card(index) != null or mirror_deck.get_known_deck_card(index) != null \
				or not mirror_deck.cards[index].uid.is_empty():
			failures.append("Shuffling did not clear public deck knowledge")
			break

	# Cards primed from public information stay known after a shuffle; cards
	# primed from an unknown deck position remain hidden to the opponent.
	deck.prime_card(second)
	var grave_card := RedCap.new()
	grave_card.card_owner = deck_owner
	deck_owner.graveyard_zone.add_card(grave_card)
	deck_owner.move_card(grave_card, deck, Zone.DeckPlacement.PRIMED)
	GameState.apply_to_manager(GameState.serialize(manager, 1), mirror)
	var grave_view := mirror_deck.get_primed_top_card()
	if grave_view == null or grave_view.uid != grave_card.uid \
			or grave_view.card_name != grave_card.card_name \
			or mirror_deck.get_deck_placement(grave_view) != Zone.DeckPlacement.PRIMED \
			or not deck.is_deck_identity_public(grave_card):
		failures.append("A graveyard-sourced primed card lost its public identity")
	var second_view := mirror_deck.get_known_deck_card(1)
	if second_view == null or second_view.card_name != "Hidden card":
		failures.append("A deck-sourced primed card leaked its identity to the opponent")
	if BotCardStrategyScript.visible(bot, second) or not BotCardStrategyScript.visible(bot, grave_card):
		failures.append("Bot visibility did not distinguish public from unknown deck cards")
	if deck_owner.draw_card() != grave_card or not grave_card.is_revealed_in_hand():
		failures.append("Drawing a publicly known deck card did not keep it revealed in hand")

func _check_humbaba_augury_privacy(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var deck_owner := _new_fixture_player()
	var humbaba_owner := _new_fixture_player()
	game.players.assign([deck_owner, humbaba_owner])
	game.feedback_viewer = deck_owner
	var humbaba := HumbabaTheTerrible.new()
	humbaba.card_owner = humbaba_owner
	humbaba_owner.frontline_zones[0].add_card(humbaba)
	var deck := deck_owner.deck_zone
	var primed := BrownBear.new()
	var shelved := RedCap.new()
	var revealed := Huginn.new()
	for card: Card in [primed, shelved, revealed]:
		card.card_owner = deck_owner
		deck.add_card(card)
	deck.reveal_deck_card(revealed)

	var feedback := humbaba.resolve_augury_reading(game, primed)
	if primed.get_display_name() in feedback or shelved.get_display_name() in feedback:
		failures.append("Humbaba's shared Augury Reading feedback named a private deck card")
	if revealed.get_display_name() not in feedback or not deck.is_deck_card_publicly_known(revealed):
		failures.append("Humbaba's Augury Reading lost a publicly known deck card's identity")
	if deck.get_primed_top_card() != primed or deck.is_deck_card_publicly_known(primed) \
			or deck.get_deck_placement(shelved) != Zone.DeckPlacement.SHELVED \
			or deck.is_deck_card_publicly_known(shelved):
		failures.append("Humbaba's Augury Reading did not keep the chosen card primed and the other cards shelved privately")

func _check_json_store_round_trip(failures: PackedStringArray) -> void:
	var storage_path := "user://ci_preflight_json_store.json"
	var global_path := ProjectSettings.globalize_path(storage_path)
	DirAccess.remove_absolute(global_path)
	DirAccess.remove_absolute("%s.tmp" % global_path)
	DirAccess.remove_absolute("%s.bak" % global_path)
	var payload := {
		"version": 1,
		"nested": {
			"ok": true,
		},
	}
	if not JsonStoreScript.save_json(global_path, payload, "preflight_probe"):
		failures.append("JsonStore failed to save a probe payload")
		return
	var loaded := JsonStoreScript.load_dictionary(global_path, {}, "preflight_probe")
	if int(loaded.get("version", 0)) != 1:
		failures.append("JsonStore failed to load saved probe payload")
	if not JsonStoreScript.save_json(global_path, {"version": 2}, "preflight_probe"):
		failures.append("JsonStore failed to replace an existing payload")
		return
	var backup := JsonStoreScript.load_dictionary("%s.bak" % global_path, {}, "preflight_probe")
	if int(backup.get("version", 0)) != 1:
		failures.append("JsonStore did not preserve a previous payload backup")
	DirAccess.remove_absolute(global_path)
	DirAccess.remove_absolute("%s.tmp" % global_path)
	DirAccess.remove_absolute("%s.bak" % global_path)

func _check_match_supervisor_launch_config(failures: PackedStringArray) -> void:
	var supervisor = MatchSupervisorScript.new()
	var session = MatchSessionScript.new(
		"preflight_match_config",
		"preflight_room",
		"127.0.0.1",
		12345,
		["session_one", "session_two"]
	)
	if session.to_match_info("session_one").get("has_bot") != false:
		failures.append("Human-only match assignment did not disable the bot loading hint")
	var config_path: String = supervisor._write_launch_config(session)
	if config_path.is_empty():
		failures.append("MatchSupervisor failed to write a launch config")
		supervisor.clear()
		supervisor.free()
		return
	var loaded := JsonStoreScript.load_dictionary(config_path, {}, "preflight_probe")
	if str(loaded.get("match_id", "")) != "preflight_match_config":
		failures.append("MatchSupervisor launch config did not round-trip through JsonStore")
	session.launch_config_path = config_path
	supervisor._cleanup_launch_config(session)
	if FileAccess.file_exists(config_path) \
			or FileAccess.file_exists("%s.tmp" % config_path) \
			or FileAccess.file_exists("%s.bak" % config_path):
		failures.append("MatchSupervisor did not clean launch config artifacts")
	var other_supervisor := MatchSupervisorScript.new()
	var other_session := MatchSessionScript.new(
		"preflight_other_match_config", "preflight_room", "127.0.0.1", 12346, ["session_three", "session_four"]
	)
	other_session.launch_config_path = other_supervisor._write_launch_config(other_session)
	var heartbeat_path := str(loaded.get("supervisor_heartbeat_path", ""))
	var other_heartbeat_path := other_session.supervisor_heartbeat_path
	if not FileAccess.file_exists(heartbeat_path) or not FileAccess.file_exists(other_heartbeat_path):
		failures.append("MatchSupervisor did not write both heartbeat files")
	supervisor.clear()
	if FileAccess.file_exists(heartbeat_path) or not FileAccess.file_exists(other_heartbeat_path):
		failures.append("Closing one MatchSupervisor did not remove only its own heartbeat")
	supervisor.free()
	other_supervisor._cleanup_launch_config(other_session)
	other_supervisor.clear()
	other_supervisor.free()

func _check_ranked_progression(failures: PackedStringArray) -> void:
	var progress := {}
	var season := RankedProgressionScript.season_for_time(1767225600.0)
	RankedProgressionScript.apply_result(progress, "loss", season)
	var summary := RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Iron V" or summary["last_delta"] != 0:
		failures.append("Ranked progression did not protect the entry rank")
	for _win in range(3):
		RankedProgressionScript.apply_result(progress, "win", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Iron IV" or summary["stars"] != 1 or summary["last_delta"] != 2:
		failures.append("Ranked progression did not apply the third-win bonus and promotion")
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["stars"] != 1 or summary["last_delta"] != 0 or summary["win_streak"] != 0 or not summary["at_floor"]:
		failures.append("Ranked progression did not protect earned Iron stars and clear the win streak")
	for _win in range(2):
		RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "draw", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Iron III" or summary["last_delta"] != 0 or summary["win_streak"] != 0:
		failures.append("Ranked progression did not preserve stars and clear the streak on a draw")
	for _win in range(8):
		RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Bronze IV" or summary["stars"] != 2 or summary["last_delta"] != 0 or not summary["at_floor"]:
		failures.append("Ranked progression did not protect earned Bronze stars")
	for _win in range(6):
		RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Silver V" or summary["last_delta"] != 0 or not summary["at_floor"]:
		failures.append("Ranked progression did not protect the Silver entry floor")
	RankedProgressionScript.apply_result(progress, "win", season)
	RankedProgressionScript.apply_result(progress, "loss", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Silver V" or summary["stars"] != 0 or summary["last_delta"] != -1:
		failures.append("Ranked progression did not deduct a star above the Silver floor")

	while summary["rank_name"] != "Divine" and int(progress["matches"]) < 130:
		if summary["stars_required"] != 3:
			failures.append("Ranked progression did not require three stars per division")
			break
		var rank_before: String = summary["rank_name"]
		RankedProgressionScript.apply_result(progress, "win", season)
		summary = RankedProgressionScript.summarize(progress, season)
		if summary["points"] == 60 and (rank_before != "Gold I" or summary["rank_name"] != "Diamond V" or summary["last_delta"] != 2):
			failures.append("Ranked progression did not promote Gold I directly to Diamond V with the streak bonus")
		if rank_before.begins_with("Diamond") and int(progress["last_delta"]) != 1:
			failures.append("Ranked progression applied a streak bonus in Diamond")
			break
	RankedProgressionScript.apply_result(progress, "loss", season)
	RankedProgressionScript.apply_result(progress, "draw", season)
	summary = RankedProgressionScript.summarize(progress, season)
	if summary["rank_name"] != "Divine" or summary["points"] != 90 or summary["stars"] != 0 or summary["last_delta"] != 0:
		failures.append("Ranked progression did not reach or protect Divine at 90 stars")
	summary = RankedProgressionScript.summarize(progress, season + 2)
	if summary["rank_name"] != "Diamond V" or summary["season"] != "2026-03" or summary["matches"] != 0:
		failures.append("Ranked progression did not reset using the peak and elapsed seasons")

func _check_rank_badges(failures: PackedStringArray) -> void:
	var ranks := ["Iron V", "Bronze V", "Silver V", "Gold V", "Diamond V", "Ascendant V", "Divine"]
	var defaults := ["Wolf Cub", "Minotaur Footsoldier", "Berserker", "En-hedu-anna", "Nergal Lion", "Enki, Lord of Eridu", "Freyja"]
	for league in range(ranks.size()):
		var default_portrait := RankBadgeCatalog.resolve_portrait(league, {})
		var card: Card = RankBadgeCatalog.get_cards(league).get(defaults[league])
		if RankBadgeCatalog.league_for_rank(ranks[league]) != league or default_portrait.get("card") != defaults[league] \
				or card == null or not ResourceLoader.exists(card.art_path, "Texture2D"):
			failures.append("Rank badge default portrait or art missing for %s" % ranks[league])
	var portrait := {"card": "Wolf Cub", "art": 0, "x": 0.15, "y": 0.85, "zoom": 2.25}
	var saved := RankBadgeCatalog.validate_portrait(0, portrait)
	if saved != portrait or not RankBadgeCatalog.validate_portrait(1, portrait).is_empty() \
			or not RankBadgeCatalog.validate_portrait(0, {"card": "Wolf Cub", "x": 1.5}).is_empty() \
			or not RankBadgeCatalog.validate_portrait(0, {"card": "Wolf Cub", "art": 99}).is_empty() \
			or not RankBadgeCatalog.validate_portrait(0, {"card": "Freyja"}).is_empty() \
			or RankBadgeCatalog.validate_portrait(6, {"card": "Freyja, Active God"}).is_empty():
		failures.append("Rank badge eligibility or crop validation failed")
	var session := MatchSessionScript.new("badge_match", "badge_room", "127.0.0.1", 12345, ["seat_a", "seat_b"], {}, {
		"seat_a": {"rank_badge": {"rank_name": "Iron V", "portrait": saved}},
		"seat_b": {"rank_badge": {"rank_name": "Bronze IV"}},
	})
	var badges: Array = session.to_spectator_match_info()["rank_badges"]
	if badges.size() != 2 or badges[0].get("portrait") != portrait or badges[1].get("rank_name") != "Bronze IV" \
			or session.to_match_info("seat_b")["rank_badges"] != badges:
		failures.append("Match assignment did not preserve public rank badges in seat order")

	var account_path := ProjectSettings.globalize_path("user://preflight_badges_%d.json" % OS.get_process_id())
	var legacy_account := {"account_id": "badge_account", "username": "Badge Player", "password_salt": "test_salt", "password_hash": "test_hash"}
	if not JsonStoreScript.save_json(account_path, {"accounts_by_id": {"badge_account": legacy_account}}, "preflight_probe"):
		failures.append("Could not prepare a preflight account for rank badge persistence")
		return
	var store := BadgeTestAccountStore.new()
	store.storage_path = account_path
	var bronze := RankBadgeCatalog.validate_portrait(1, {"card": "Minotaur Footsoldier"})
	if not store.get_rank_badge("badge_account", 0).is_empty() \
			or not store.set_rank_badge("badge_account", 0, saved) or not store.set_rank_badge("badge_account", 1, bronze):
		failures.append("Could not save badge preferences for an existing account")
	var reopened := BadgeTestAccountStore.new()
	reopened.storage_path = account_path
	if RankBadgeCatalog.validate_portrait(0, reopened.get_rank_badge("badge_account", 0)) != saved \
			or RankBadgeCatalog.validate_portrait(1, reopened.get_rank_badge("badge_account", 1)) != bronze:
		failures.append("Rank badge choices or crop did not round-trip through account storage")
	if not reopened.set_rank_badge("badge_account", 0, {}):
		failures.append("Could not restore the default rank badge")
	var reset_store := BadgeTestAccountStore.new()
	reset_store.storage_path = account_path
	if not reset_store.get_rank_badge("badge_account", 0).is_empty() \
			or RankBadgeCatalog.validate_portrait(1, reset_store.get_rank_badge("badge_account", 1)) != bronze:
		failures.append("Resetting a rank badge changed preferences for another league")
	DirAccess.remove_absolute(account_path)
	DirAccess.remove_absolute(account_path + ".bak")

func _check_dedicated_ranked_history(failures: PackedStringArray) -> void:
	var storage_file := "preflight_ranked_%d.json" % OS.get_process_id()
	var storage_path := ServerPathsScript.get_server_data_file_path(storage_file)
	var result_dir := storage_path.get_basename() + "_results"
	var legacy_store := MatchHistoryStoreScript.new(storage_file)
	var writer_a := MatchHistoryStoreScript.new(storage_file, true)
	var writer_b := MatchHistoryStoreScript.new(storage_file, true)
	var reader := MatchHistoryStoreScript.new(storage_file, true)
	var session := MatchSessionScript.new("legacy", "preflight_room", "127.0.0.1", 12345, ["session_a", "session_b"], {}, {
		"session_a": {"profile_id": "profile_a", "account_id": "account_a"},
		"session_b": {"profile_id": "profile_b", "account_id": "account_b"},
	})
	legacy_store.record_completed_match(session, 0, 1, "Thor", "Odin")
	var initial_summary := reader.get_profile_summary("profile_a", 5, "account_a")
	if initial_summary["total_wins"] != 1 or initial_summary["ranked_progress"]["matches"] != 0 \
			or initial_summary["ranked_bo3_progress"]["matches"] != 0:
		failures.append("Ranked progression did not preserve legacy records without awarding stars")

	session.match_id = "ranked_a"
	var first_match := writer_a.record_completed_match(session, 0, 1, "Thor", "Odin")
	var old_entry: Dictionary = first_match["entry"]
	old_entry.erase("best_of")
	var old_result_path := result_dir.path_join("%s.json" % session.match_id.sha256_text())
	if not JsonStoreScript.save_json(old_result_path, old_entry, "preflight_probe"):
		failures.append("Could not prepare a ranked result without a stored format")
	session.match_id = "ranked_b"
	session.configure_series_format(3)
	var bo3_match := writer_b.record_completed_match(session, 0, 1, "Loki", "Freyja")
	writer_a.record_completed_match(session, 1, 0, "Odin", "Thor")
	session.configure_series_format(1)
	session.match_id = "ranked_c"
	writer_a.record_completed_match(session, 0, 1, "Thor", "Odin")
	session.match_id = "ranked_d"
	var promotion_match := writer_b.record_completed_match(session, 0, 1, "Thor", "Odin")
	session.match_id = "guest"
	session.configure_series_format(3)
	session.player_identity_by_session["session_b"]["account_id"] = ""
	var guest_match := writer_b.record_completed_match(session, 0, 1, "Thor", "Odin")
	var winner_summary := reader.get_profile_summary("profile_a", 5, "account_a")
	var loser_summary := reader.get_profile_summary("profile_b", 5, "account_b")
	if winner_summary["total_wins"] != 6 or winner_summary["ranked_progress"]["matches"] != 3 \
			or winner_summary["ranked_progress"]["rank_name"] != "Iron IV" or winner_summary["ranked_progress"]["stars"] != 1 \
			or loser_summary["ranked_progress"]["matches"] != 3 or loser_summary["ranked_progress"]["stars"] != 0:
		failures.append("Dedicated ranked history lost, duplicated, or miscounted match results")
	var bo3_progress: Dictionary = winner_summary["ranked_bo3_progress"]
	if bo3_progress["matches"] != 1 or bo3_progress["win_streak"] != 1 \
			or bo3_progress["rank_name"] != "Iron V" or bo3_progress["stars"] != 1:
		failures.append("Bo3 ranked progression did not stay independent of Bo1")
	var usernames := {"account_a": "Winner", "account_b": "Opponent"}
	var bo1_ladder := reader.get_human_ladder(usernames, 1)
	var bo3_ladder := reader.get_human_ladder(usernames, 3)
	if bo1_ladder[0]["points"] != 4 or bo3_ladder[0]["points"] != 1:
		failures.append("Ladder standings did not use the requested ranked format")
	if bo1_ladder[0]["wins"] != 3 or bo3_ladder[0]["wins"] != 1 \
			or bo1_ladder[0]["losses"] != 0 or bo3_ladder[0]["losses"] != 0 \
			or bo1_ladder[0]["draws"] != 0 or bo3_ladder[0]["draws"] != 0:
		failures.append("Ladder W/L/D records mixed Bo1 and Bo3 results")
	if bo1_ladder[0]["main_gods"] != ["Thor"] or bo3_ladder[0]["main_gods"] != ["Loki"]:
		failures.append("Ladder main gods mixed Bo1 and Bo3 results")
	var bo1_recent: Array = bo1_ladder[0]["recent_matches"]
	var bo3_recent: Array = bo3_ladder[0]["recent_matches"]
	if bo1_recent.size() != 3 or bo3_recent.size() != 1 \
			or bo1_recent.any(func(match: Dictionary) -> bool: return int(match.get("best_of", 1)) != 1) \
			or bo3_recent.any(func(match: Dictionary) -> bool: return int(match.get("best_of", 1)) != 3):
		failures.append("Ladder recent matches mixed Bo1 and Bo3 results")
	var first_results := reader.get_ranked_match_results(first_match["entry"])
	var first_win: Dictionary = first_results.get(0, {})
	var first_loss: Dictionary = first_results.get(1, {})
	if first_win.get("best_of") != 1 or first_win.get("star_delta") != 1 or first_win.get("stars") != 1 or first_win.get("rank_name") != "Iron V" \
			or first_loss.get("star_delta") != 0 or first_loss.get("stars") != 0 or first_loss.get("loss_protected") != true:
		failures.append("Ranked recap did not return each player's exact result after later matches")
	var bo3_result: Dictionary = reader.get_ranked_match_results(bo3_match["entry"]).get(0, {})
	if bo3_result.get("best_of") != 3 or bo3_result.get("previous_stars") != 0 or bo3_result.get("stars") != 1:
		failures.append("Bo3 ranked recap used progress from a different format")
	var promotion: Dictionary = reader.get_ranked_match_results(promotion_match["entry"]).get(0, {})
	if promotion.get("previous_rank_name") != "Iron V" or promotion.get("previous_stars") != 2 \
			or promotion.get("rank_name") != "Iron IV" or promotion.get("stars") != 1 or promotion.get("star_delta") != 2:
		failures.append("Ranked recap did not report both sides of a promotion with carryover stars")
	if not reader.get_ranked_match_results(guest_match["entry"]).is_empty():
		failures.append("Ranked recap awarded stars for an ineligible match")
	var reopened := MatchHistoryStoreScript.new(storage_file, true)
	var reopened_summary := reopened.get_profile_summary("profile_a", 5, "account_a")
	if reopened_summary["ranked_progress"] != winner_summary["ranked_progress"] \
			or reopened_summary["ranked_bo3_progress"] != bo3_progress:
		failures.append("Dedicated ranked history did not restore progress after reopening the store")
	session.configure_series_format(1)
	session.player_identity_by_session["session_b"]["account_id"] = "account_b"
	session.match_id = "ranked_thor_loss"
	writer_a.record_completed_match(session, 1, 0, "Odin", "Thor")
	session.match_id = "ranked_hermes_draw"
	session.registered_player_decks_by_session["session_a"] = {"cards": {"Hermes": 1}}
	session.registered_player_decks_by_session["session_b"] = {"cards": {"Odin": 1}}
	writer_b.record_completed_match(session, -1, -1, "", "")
	session.match_id = "ranked_previous_season"
	var previous_season_entry: Dictionary = writer_b.record_completed_match(session, 0, 1, "Thor", "Odin")["entry"]
	previous_season_entry["played_unix"] -= 35 * 86400
	var previous_season_path := result_dir.path_join("%s.json" % session.match_id.sha256_text())
	if not JsonStoreScript.save_json(previous_season_path, previous_season_entry, "preflight_probe"):
		failures.append("Could not prepare a ranked result from an earlier season")
	if reader.get_ranked_god_records("account_a", 1) != [
		{"god_name": "Thor", "wins": 3, "losses": 1, "draws": 0, "games": 4},
		{"god_name": "Hermes", "wins": 0, "losses": 0, "draws": 1, "games": 1},
	] or reader.get_ranked_god_records("account_a", 3) != [
		{"god_name": "Loki", "wins": 1, "losses": 0, "draws": 0, "games": 1},
	]:
		failures.append("Ranked records by god missed results or mixed seasons or formats")
	if reader.get_human_ladder(usernames, 1)[0]["wins"] != 4:
		failures.append("The seasonal records by god changed the ladder's lifetime totals")
	DirAccess.remove_absolute(old_result_path + ".bak")
	DirAccess.remove_absolute(previous_season_path + ".bak")
	for match_id in ["ranked_a", "ranked_b", "ranked_c", "ranked_d", "guest", "ranked_thor_loss", "ranked_hermes_draw", "ranked_previous_season"]:
		DirAccess.remove_absolute(result_dir.path_join("%s.json" % match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir)
	DirAccess.remove_absolute(storage_path)

func _check_bot_sideboarding(failures: PackedStringArray) -> void:
	var validator := DeckValidatorScript.new()
	# Survey ratings: spot-check provenance values and the unrated fallback.
	if BotSideboardRatingsScript.rating_for("Berserker Mead") != 56 \
			or BotSideboardRatingsScript.rating_for("Nusku, Active God") != -82:
		failures.append("Bot sideboard survey ratings lost their Δ field values")
	if BotSideboardRatingsScript.rating_for("Not A Real Card") != 0:
		failures.append("Unrated cards should default to the field-average rating")

	# Fresh ranked decks now ship a full, validator-legal sideboard.
	var factory := PracticeAutofillDeckFactory.new()
	# Your actual god can never be cut or sideboarded; deck-legal Active Gods
	# are ordinary swappable cards.
	var thor_god: Card = factory._cards_by_name.get("Thor", null)
	if not BotSideboardPolicyScript._is_protected_main_deck_card(thor_god, {}):
		failures.append("The God slot card must be protected from Reinforcement cuts")
	var deck := factory.build_random_deck(4242, "Thor", true)
	if deck.is_empty():
		failures.append("Ranked bot generator produced no Thor deck for sideboard checks")
		return
	var side: Dictionary = deck.get("reinforcements", {})
	if side.is_empty():
		failures.append("Ranked bot deck shipped without Reinforcements")
	else:
		var regular_count := 0
		var power_count := 0
		for card_name in deck.get("cards", {}):
			var copies := int(deck["cards"][card_name])
			var template: Card = factory._cards_by_name.get(str(card_name), null)
			if template == null:
				continue
			if template.is_power:
				power_count += copies
			elif not template.is_god:
				regular_count += copies
		var side_total := 0
		for card_name in side:
			side_total += int(side[card_name])
		if side_total != DeckValidatorScript.get_reinforcement_limit(regular_count, power_count):
			failures.append("Ranked bot Reinforcements did not fill the reinforcement limit (%d of %d)" % [
				side_total,
				DeckValidatorScript.get_reinforcement_limit(regular_count, power_count),
			])
		if not bool(validator.validate_deck(deck.get("cards", {}), deck.get("special_setup", {}), side).get("is_valid", false)):
			failures.append("Ranked bot Reinforcements failed combined validation")

	# Existing bots without sideboards get one deterministically through the
	# auditor, and the derivation is stable for the same deck identity.
	var audited := factory.audit_ranked_bot_deck({
		"god_name": "Thor",
		"deck_name": "Preflight Audit Bot",
		"cards": deck.get("cards", {}).duplicate(true),
		"special_setup": deck.get("special_setup", {}),
	})
	if audited.is_empty() or (audited.get("reinforcements", {}) as Dictionary).is_empty():
		failures.append("Audited existing bot deck did not gain Reinforcements")
	else:
		var reaudited := factory.audit_ranked_bot_deck({
			"god_name": "Thor",
			"deck_name": "Preflight Audit Bot",
			"cards": deck.get("cards", {}).duplicate(true),
			"special_setup": deck.get("special_setup", {}),
		})
		if JSON.stringify(reaudited.get("reinforcements", {})) != JSON.stringify(audited.get("reinforcements", {})):
			failures.append("Existing bot Reinforcement derivation is not deterministic")
		var varied := false
		for probe_seed in range(6):
			var other := factory.build_random_deck(900 + probe_seed, "Thor", true)
			if not other.is_empty() \
					and JSON.stringify(other.get("reinforcements", {})) != JSON.stringify(audited.get("reinforcements", {})):
				varied = true
				break
		if not varied:
			failures.append("Bot Reinforcement derivation did not vary across decks")

	# Tablet of Life audit repair: historical lists with unsupported tablets
	# either gain six Ancient creatures (swapping the worst survey cards) or
	# lose the tablets, and the repair is deterministic for a given list.
	var tablet_fixture := {
		"Thor": 1,
		"Tablet of Life": 2,
		"Alu": 2,
		"Gallu": 2,
		"Bearded Axe": 3,
		"Blessed Knights": 3,
		"Third Sage Enmedugga": 1,
		"Wolf Cub": 3,
		"Berserker": 3,
		"Harii Warrior": 3,
	}
	var repaired_tablets := factory.audit_ranked_bot_deck({
		"god_name": "Thor",
		"deck_name": "Preflight Tablet Repair",
		"cards": tablet_fixture,
	})
	if repaired_tablets.is_empty():
		failures.append("Tablet of Life audit repair failed")
	else:
		var tablet_side: Dictionary = repaired_tablets.get("reinforcements", {})
		var tablet_combined: Dictionary = (repaired_tablets.get("cards", {}) as Dictionary).duplicate(true)
		for side_name in tablet_side.keys():
			tablet_combined[str(side_name)] = int(tablet_combined.get(str(side_name), 0)) + int(tablet_side[side_name])
		var kept_tablets := int(tablet_combined.get("Tablet of Life", 0))
		var repaired_ancients := 0
		for tablet_card_name in tablet_combined:
			var tablet_template: Card = factory._cards_by_name.get(str(tablet_card_name), null)
			if tablet_template != null and not tablet_template.is_god \
					and tablet_template.card_type == Card.CardType.CREATURE \
					and str(tablet_template.culture).strip_edges() == "Ancient":
				repaired_ancients += int(tablet_combined[tablet_card_name])
		if kept_tablets > 0 and repaired_ancients < 6:
			failures.append("Audited bot deck kept Tablet of Life without six Ancient creatures")
		if not bool(validator.validate_deck(
				repaired_tablets.get("cards", {}),
				repaired_tablets.get("special_setup", {}),
				tablet_side).get("is_valid", false)):
			failures.append("Tablet of Life audit repair produced an invalid deck")
		var reaudited_tablets := factory.audit_ranked_bot_deck({
			"god_name": "Thor",
			"deck_name": "Preflight Tablet Repair",
			"cards": tablet_fixture,
		})
		if JSON.stringify(reaudited_tablets.get("cards", {})) != JSON.stringify(repaired_tablets.get("cards", {})):
			failures.append("Tablet of Life audit repair is not deterministic")

	# Swap planning against a controlled fixture: a Thor shell whose worst
	# survey cards are known, plus a hate sideboard.
	var fixture_cards := {
		"Thor": 1,
		"Berserker Mead": 1,
		"Mana Guard": 1,
		"Palisade": 1,
		"Byggvir": 3,
		"Isimud": 3,
		"Beyla": 3,
		"Heavy Snow": 3,
		"First Sage Adapa": 3,
		"Harii Warrior": 3,
		"Valkyrie Warrior": 3,
		"Skoll": 3,
		"Án the Bowbender": 3,
		"Grindylow": 3,
		"White Stag": 3,
		"Wolf Cub": 3,
		"Hrimgrimmnir": 3,
		"Fenrir": 1,
	}
	var fixture_side := {
		"Runic Spellbreaker": 2,
		"Banishment": 2,
		"Fires of Judgment": 2,
		"Absence": 1,
		"Smite": 2,
	}
	var fixture_validation: Dictionary = validator.validate_deck(fixture_cards, {}, fixture_side)
	if not bool(fixture_validation.get("is_valid", false)):
		failures.append("Sideboard swap fixture deck failed validation: %s" % str(fixture_validation.get("error", "")))
		return
	fixture_cards = fixture_validation.get("cards", {})
	fixture_side = fixture_validation.get("reinforcements", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122

	var magical_observed := {"cards": {"Fires of Judgment": 3}, "tags": {BotSideboardPolicyScript.Tag.MAGICAL: 8}}
	var magical_plan: Dictionary = BotSideboardPolicyScript.plan_swap(
		fixture_cards, fixture_side, {}, magical_observed, rng, validator
	)
	if not bool(magical_plan.get("changed", false)):
		failures.append("Bot sideboard plan ignored a magical-heavy opponent")
	else:
		var log_entries: Array = magical_plan.get("log", [])
		if log_entries.size() != 4:
			failures.append("Bot sideboard plan did not use its full swap window")
		var expected_cuts := ["Byggvir", "Isimud", "Beyla", "Heavy Snow"]
		for index in range(mini(4, log_entries.size())):
			var entry: Dictionary = log_entries[index]
			if str(entry.get("out", "")) != expected_cuts[index]:
				failures.append("Bot sideboard cuts did not follow survey rating order (expected %s, cut %s)" % [
					expected_cuts[index], str(entry.get("out", "")),
				])
				break
		for entry in log_entries:
			if str(entry.get("in", "")) not in ["Banishment", "Runic Spellbreaker"]:
				failures.append("Bot sideboard brought in a card without anti-magical need")
				break
		var swap_check: Dictionary = validator.validate_reinforcement_swap(
			fixture_cards, fixture_side,
			magical_plan.get("cards", {}), magical_plan.get("reinforcements", {}), {}
		)
		if not bool(swap_check.get("is_valid", false)):
			failures.append("Bot sideboard plan produced an illegal swap: %s" % str(swap_check.get("error", "")))

	var empty_plan: Dictionary = BotSideboardPolicyScript.plan_swap(
		fixture_cards, fixture_side, {}, {"cards": {}, "tags": {}}, rng, validator
	)
	if bool(empty_plan.get("changed", false)):
		failures.append("Bot sideboard plan swapped cards with nothing observed")

	var creature_observed := {"cards": {"Harii Warrior": 3}, "tags": {BotSideboardPolicyScript.Tag.CREATURE: 6}}
	var creature_plan: Dictionary = BotSideboardPolicyScript.plan_swap(
		fixture_cards, fixture_side, {}, creature_observed, rng, validator
	)
	if not bool(creature_plan.get("changed", false)):
		failures.append("Bot sideboard plan ignored a creature-heavy opponent")
	for entry in creature_plan.get("log", []):
		var cut_card: Card = BotSideboardPolicyScript.get_card(str((entry as Dictionary).get("out", "")))
		if cut_card != null and cut_card.card_type == Card.CardType.CREATURE:
			failures.append("Bot sideboard cut a creature against a creature-heavy opponent")
			break

	# Observations only ever use public zones: the opponent hand stays out.
	var game := _new_fixture_game()
	var opponent := _new_fixture_player()
	opponent.player_name = "Observed Opponent"
	var god_card = factory._cards_by_name.get("Odin, the Allfather", null)
	if god_card != null:
		opponent.god_zone.add_card(god_card)
	var hidden_spell = factory._cards_by_name.get("Drought", null)
	if hidden_spell != null:
		opponent.hand_zone.add_card(hidden_spell)
	var seen_creature = factory._cards_by_name.get("Gilgamesh", null)
	if seen_creature != null:
		opponent.graveyard_zone.add_card(seen_creature)
	var fixture_players: Array[Player] = [_new_fixture_player(), opponent]
	game.players = fixture_players
	var observation: Dictionary = BotSideboardPolicyScript.summarize_opponent(game, 1)
	if bool(observation.get("cards", {}).has("Drought")):
		failures.append("Bot opponent observation leaked a card from the hidden hand")
	if not bool(observation.get("cards", {}).has("Gilgamesh")):
		failures.append("Bot opponent observation missed a public graveyard card")
	if int(observation.get("tags", {}).get(BotSideboardPolicyScript.Tag.POWER_GOD, 0)) < 1:
		failures.append("Bot opponent observation missed the public god slot")

func _check_ranked_bot_deck_generation(failures: PackedStringArray) -> void:
	var factory := PracticeAutofillDeckFactory.new()
	var skotia_name := AphroditeSkotia.new().card_name
	if not factory.get_ranked_god_names().has(skotia_name):
		failures.append("Aphrodite Skotia was missing from the ranked bot god pool")
	for ranked: bool in [false, true]:
		var skotia_deck := factory.build_random_deck(7600, skotia_name, ranked)
		if int(skotia_deck.get("cards", {}).get(skotia_name, 0)) != 1:
			failures.append("Bot generator did not produce an Aphrodite Skotia deck (ranked: %s)" % ranked)
	var tez := TezcatlipocaTheSmokingMirror.new()
	var tez_deck := factory.build_random_deck(1337, tez.card_name, true)
	if int(tez_deck.get("cards", {}).get("Tonal Extraction", 0)) != 1:
		failures.append("Ranked Tezcatlipoca did not include Tonal Extraction in a generated Shapeshifter deck")
	if factory._get_power_candidates(tez, {tez.card_name: 1, "Brown Bear": 3}, true).any(func(card: Card) -> bool: return card is TonalExtraction):
		failures.append("Ranked Tezcatlipoca added Tonal Extraction without an eligible creature")
	var psychopompus := HermesPsychopompus.new()
	var psychopompus_ghost_signatures: Array[String] = []
	for seed_value in range(8):
		var psychopompus_deck := factory.build_random_deck(7600 + seed_value, psychopompus.card_name, true)
		if psychopompus_deck.is_empty():
			failures.append("Ranked bot generator did not produce a Hermes Psychopompos deck")
			break
		var ghost_names: Array[String] = []
		var psychopompus_cards: Dictionary = psychopompus_deck.get("cards", {})
		for card_name in psychopompus_cards:
			var template: Card = factory._cards_by_name.get(str(card_name), null)
			if template == null or not template.has_type("Ghost") or template.is_god:
				continue
			for _copy in range(int(psychopompus_cards[card_name])):
				ghost_names.append(str(card_name))
		if ghost_names.size() < PracticeAutofillDeckFactory.HERMES_PSYCHOPOMPUS_MIN_GHOSTS:
			failures.append("Ranked Hermes Psychopompos autofill included fewer than four Ghosts")
		ghost_names.sort()
		psychopompus_ghost_signatures.append(JSON.stringify(ghost_names))
	var unique_ghost_signatures := {}
	for signature in psychopompus_ghost_signatures:
		unique_ghost_signatures[signature] = true
	if psychopompus_ghost_signatures.size() == 8 and unique_ghost_signatures.size() < 2:
		failures.append("Ranked Hermes Psychopompos autofill Ghosts did not vary by seed")
	for god_case in [
		[NuskuFirebearer.new(), PracticeAutofillDeckFactory.NUSKU_MIN_ANCIENT_MAGICAL],
		[ManannanMacLir.new(), PracticeAutofillDeckFactory.MANANNAN_MAC_LIR_MIN_TRISKELION_CREATURES],
		[Odin.new(), PracticeAutofillDeckFactory.ODIN_MIN_RUNIC_ACTIVATORS],
		[Cernunnos.new(), PracticeAutofillDeckFactory.CERNUNNOS_MIN_LEVEL_5_ANIMALS],
	]:
		var required_god: GodCard = god_case[0]
		var required_deck: Dictionary = factory.build_random_deck(4100 + int(god_case[1]), required_god.card_name, true)
		if required_deck.is_empty() or factory._god_specific_regular_deficit(required_god, required_deck.get("cards", {})) != 0:
			failures.append("Ranked %s autofill did not meet its god-specific card minimum" % required_god.card_name)
	var cernunnos := Cernunnos.new()
	for ranked_mode in [false, true]:
		var cernunnos_deck := factory.build_random_deck(
			4800 + int(ranked_mode), cernunnos.card_name, ranked_mode
		)
		if cernunnos_deck.is_empty() \
				or factory._god_specific_regular_deficit(cernunnos, cernunnos_deck.get("cards", {})) != 0:
			failures.append("Cernunnos autofill did not include three level 5 or higher Animals")
	if factory._is_level_5_or_higher_animal(BrownBear.new()) \
			or not factory._is_level_5_or_higher_animal(Afanc.new()):
		failures.append("Cernunnos autofill Animal level threshold did not match level 5 or higher")
	var odin := Odin.new()
	var odin_deck := factory.build_random_deck(4400, odin.card_name, true)
	if odin_deck.is_empty():
		failures.append("Ranked bot generator did not produce an Odin deck")
	else:
		var odin_cards: Dictionary = (odin_deck.get("cards", {}) as Dictionary).duplicate(true)
		odin_cards["Fires of Judgment"] = int(odin_cards.get("Fires of Judgment", 0)) + 1
		var repaired_odin := factory.audit_ranked_bot_deck({
			"god_name": odin.card_name,
			"deck_name": "Preflight Odin Audit",
			"cards": odin_cards,
		})
		if repaired_odin.is_empty() or (repaired_odin.get("cards", {}) as Dictionary).has("Fires of Judgment"):
			failures.append("Odin deck audit did not remove culture-incompatible Fires of Judgment")
	var thor := Thor.new()
	for legendary in [false, true]:
		# Circle of Rebirth only joins ranked decks with five Animal/Plant
		# targets, so its candidate check runs against a seeded deck context.
		var deck_context: Dictionary = {"Brown Bear": 3, "White Stag": 3} if legendary else {}
		var candidates := factory._get_regular_candidates(thor, deck_context, legendary, true)
		var expected := "Circle of Rebirth" if legendary else "Fall of the Mighty"
		if not candidates.any(func(card: Card) -> bool: return card.card_name == expected):
			failures.append("Ranked bot decks cannot generate %s" % expected)

	var requirement_cases := [
		["Gambanteinn", {}, false],
		["Gambanteinn", {"Harii Shaman": 3, "Draug Revenant": 1}, true],
		["Sharur, the Flying Mace", {}, false],
		["Sharur, the Flying Mace", {"Berserker": 3, "Blessed Knights": 1}, true],
		["Durinn Secondborn", {"Bearded Axe": 2}, false],
		["Durinn Secondborn", {"Bearded Axe": 3}, true],
		["Circle of Rebirth", {}, false],
		["Tablet of Life", {}, false],
		["Tablet of Life", {"Alu": 3, "Gallu": 3}, true],
		["Sixth Sage An-Enlilda", {"E2-abzu": 1}, false],
		["Sixth Sage An-Enlilda", {"E2-abzu": 2}, true],
		["Key of Solomon", {}, false],
		["Key of Solomon", {"Brown Bear": 2}, false],
		["Key of Solomon", {"Alu": 2}, false],
		["Key of Solomon", {"Brown Bear": 2, "Alu": 2}, false],
		["Key of Solomon", {"Brown Bear": 2, "Alu": 2, "Gallu": 2}, true],
		["Vision of Tartarus", {}, false],
		["Vision of Tartarus", {"Bit Meseri": 2}, false],
		["Vision of Tartarus", {"Bit Meseri": 1, "Void Shield": 1}, false],
		["Vision of Tartarus", {"Bit Meseri": 1, "Void Shield": 1, "Wheel of Fire": 1}, true],
	]
	for entry in requirement_cases:
		var ruled_card: Card = factory._cards_by_name.get(str(entry[0]), null)
		var supported: bool = factory._has_deckbuilding_requirements(ruled_card, entry[1], thor)
		if supported != bool(entry[2]):
			failures.append("Ranked bot deck support rule mismatch for %s" % str(entry[0]))

	var unsupported_practice_candidates := factory._get_regular_candidates(thor, {"Brown Bear": 2}, false)
	if unsupported_practice_candidates.any(func(card: Card) -> bool: return card.card_name == "Key of Solomon"):
		failures.append("Practice autofill added Key of Solomon without Animal and Demon support")
	var insufficient_target_candidates := factory._get_regular_candidates(thor, {"Brown Bear": 2, "Alu": 2}, false)
	if insufficient_target_candidates.any(func(card: Card) -> bool: return card.card_name == "Key of Solomon"):
		failures.append("Practice autofill added Key of Solomon with fewer than four Demon targets")
	var supported_practice_candidates := factory._get_regular_candidates(thor, {"Brown Bear": 2, "Alu": 2, "Gallu": 2}, false)
	if not supported_practice_candidates.any(func(card: Card) -> bool: return card.card_name == "Key of Solomon"):
		failures.append("Practice autofill cannot add Key of Solomon with Animal sources and four Demon targets")

	var unsupported_vision_candidates := factory._get_regular_candidates(thor, {"Bit Meseri": 2}, false)
	if unsupported_vision_candidates.any(func(card: Card) -> bool: return card.card_name == "Vision of Tartarus"):
		failures.append("Practice autofill added Vision of Tartarus without three Void sources")
	var supported_vision_candidates := factory._get_regular_candidates(thor, {"Bit Meseri": 1, "Void Shield": 1, "Wheel of Fire": 1}, false)
	if not supported_vision_candidates.any(func(card: Card) -> bool: return card.card_name == "Vision of Tartarus"):
		failures.append("Practice autofill cannot add Vision of Tartarus with three Void sources")

	var deck := factory.build_random_deck(1337, TiamatThePrimordial.TIAMAT_CARD_NAME, true)
	var player := _new_fixture_player()
	if deck.is_empty() or not DeckBuilder.new().build_deck(player, _cards_from_counts(deck["cards"]), deck["special_setup"]):
		failures.append("Ranked bot generator did not produce a legal Tiamat deck")
		return
	var brood_slot_count := 0
	var power_card_count := 0
	for zone in player.power_zones:
		if zone.cards.is_empty():
			failures.append("Ranked Tiamat left a shared power/Brood slot empty")
			return
		var zone_has_brood := false
		for slot_card: Card in zone.cards:
			if TiamatThePrimordial.is_valid_slot_creature(slot_card):
				zone_has_brood = true
			elif slot_card.is_power and not slot_card.is_god:
				power_card_count += 1
			else:
				failures.append("Ranked Tiamat put an invalid card in a shared power/Brood slot")
				return
		if zone_has_brood:
			brood_slot_count += 1
	if brood_slot_count + power_card_count != TiamatThePrimordial.POWER_SLOT_COUNT:
		failures.append("Ranked Tiamat did not fill all three shared power/Brood slots")
		return

	var game_manager := _new_fixture_game()
	var opponent := _new_fixture_player()
	game_manager.players.assign([player, opponent])
	game_manager.current_player = player
	game_manager.other_player = opponent
	game_manager.start_turn()
	var match_manager := _new_fixture_match(game_manager)
	var bot := _new_fixture_bot()
	bot.attach(game_manager, match_manager, ServerBotGameInput.new(match_manager, 0), 0)
	var deck_size := player.deck_zone.cards.size()
	bot._handle_upkeep()
	bot.detach()
	if player.hand_zone.cards.size() != 1 or player.deck_zone.cards.size() != deck_size \
			or player.mana != 0 or not game_manager.has_resolved_turn_upkeep():
		failures.append("Ranked Tiamat did not use Matriarch Rule to take a Brood creature on turn one")

func _check_new_rubric_bot_batch(failures: PackedStringArray) -> void:
	var valid_reason := LobbyProtocolScript.validate_request(LobbyProtocolScript.make_message(
		LobbyProtocolScript.REQUEST_BOT_WORK,
		{"new_bots_only": true}))
	if not valid_reason.is_empty():
		failures.append("lobby guard rejected a new bot batch work request: %s" % valid_reason)
	for invalid_batch_work in [
		{"new_bots_only": true, "top_50": true},
		{"new_bots_only": true, "below_top_50": true},
		{"new_bots_only": true, "bot_id": "owned_bot"},
		{"new_bots_only": "true"},
	]:
		var invalid_reason := LobbyProtocolScript.validate_request(LobbyProtocolScript.make_message(
			LobbyProtocolScript.REQUEST_BOT_WORK,
			invalid_batch_work))
		if invalid_reason.is_empty():
			failures.append("lobby guard accepted invalid new bot batch work: %s" % JSON.stringify(invalid_batch_work))
	var lobby := RecordingLobby.new()
	lobby._generate_new_rubric_bot_batch(1, 2)
	var batch := lobby._get_new_rubric_bot_batch(1)
	var decks: Dictionary = batch.get("decks", {})
	var records: Dictionary = batch.get("records", {})
	if decks.size() < 2:
		failures.append("new rubric bot batch did not generate at least two decks")
		lobby.free()
		return
	var first_pair := lobby._select_new_rubric_bot_pair({}, 1)
	if first_pair.size() != 2:
		failures.append("new rubric bot batch could not select an initial pair")
		lobby.free()
		return
	var finished_ids: Array[String] = []
	for raw_id in decks.keys():
		var list_id := str(raw_id)
		finished_ids.append(list_id)
		var record: Dictionary = records.get(list_id, {})
		record["games"] = LobbyServerScript.NEW_BOT_BATCH_GAME_LIMIT
		records[list_id] = record
	var refreshed_pair := lobby._select_new_rubric_bot_pair({}, 1)
	if refreshed_pair.size() != 2:
		failures.append("new rubric bot batch did not refresh after every bot reached the game limit")
	else:
		for picked: Dictionary in refreshed_pair:
			var picked_id := str(picked.get("bot_list_id", picked.get("list_id", "")))
			if finished_ids.has(picked_id):
				failures.append("new rubric bot batch reused a bot with %d games" % LobbyServerScript.NEW_BOT_BATCH_GAME_LIMIT)
				break
	lobby.free()

func _check_ranked_bot_manifestations(failures: PackedStringArray) -> void:
	var factory := PracticeAutofillDeckFactory.new()
	for god in factory._gods:
		for legendary in [false, true]:
			var candidates := factory._get_regular_candidates(god, {}, legendary, true)
			for card in CardCatalogScript.get_cached_card_templates():
				if card is ActiveGodCard and card.is_legendary == legendary:
					var allowed: bool = (god is Odin or god is TiamatThePrimordial) \
						and card.culture == god.culture and not god.is_own_active_god_card(card)
					if candidates.any(func(candidate: Card) -> bool: return candidate.card_name == card.card_name) != allowed:
						failures.append("Unexpected ranked deck eligibility for %s under %s" % [card.card_name, god.card_name])
	var freyja_powers := factory._get_power_candidates(Freyja.new(), {}, true)
	if not freyja_powers.any(func(card: Card) -> bool: return card is TakeTheField):
		failures.append("Take the Field was unavailable to a ranked god with a matching Active God")
	for god in [Thor.new(), GuanYu.new(), TezcatlipocaTheSmokingMirror.new(), Odin.new()]:
		var powers := factory._get_power_candidates(god, {}, true)
		if powers.any(func(card: Card) -> bool: return card is TakeTheField):
			failures.append("Take the Field was offered in the ranked power pool for %s" % god.card_name)
	var mixed_tiamat_deck := false
	for seed_value in range(12):
		var deck := factory.build_random_deck(seed_value, TiamatThePrimordial.TIAMAT_CARD_NAME, true)
		if deck.is_empty():
			continue
		var slots := TiamatThePrimordial.get_slot_card_names_from_setup(deck["special_setup"])
		var brood_slots := 0
		for slot_cards in slots:
			if not slot_cards.is_empty():
				brood_slots += 1
		var deck_powers := 0
		for card_name in deck.get("cards", {}):
			var template: Card = CardCatalogScript.instantiate_card_by_name(str(card_name))
			if template != null and template.is_power and not template.is_god:
				deck_powers += int(deck["cards"][card_name])
		if brood_slots > 0 and deck_powers > 0 \
				and brood_slots + deck_powers == TiamatThePrimordial.POWER_SLOT_COUNT:
			mixed_tiamat_deck = true
			break
	if not mixed_tiamat_deck:
		failures.append("Ranked Tiamat did not generate a legal deck with mixed Brood and power slots")

	var gods: Array[GodCard] = [Thor.new(), GuanYu.new(), TiamatThePrimordial.new(), TezcatlipocaTheSmokingMirror.new()]
	for god in gods:
		var game_manager := _new_fixture_game()
		var player := _new_fixture_player()
		var opponent := _new_fixture_player()
		game_manager.players.assign([player, opponent])
		game_manager.current_player = player
		game_manager.other_player = opponent
		game_manager.start_turn()
		game_manager.player_chooses_upkeep_only()
		# Ranked bots now reserve Active God manifestations for a turn where
		# the resulting creature can take a meaningful attack.
		game_manager.turn_number = 2
		game_manager._upkeep_started_turn = game_manager.turn_number
		game_manager._upkeep_resolved_turn = game_manager.turn_number
		var match_manager := _new_fixture_match(game_manager)
		var bot := _new_fixture_bot()
		bot.attach(game_manager, match_manager, ServerBotGameInput.new(match_manager, 0), 0)
		god.card_owner = player
		player.god_zone.add_card(god)
		if god is Thor or god is GuanYu:
			player.mana = god.get_champions_call_candidate().mana_cost - GodCard.CHAMPIONS_CALL_SHELVE_MANA_VALUE
			var valuable := EnkiLordOfEridu.new()
			var shelve := BrownBear.new()
			for card in [valuable, shelve]:
				card.card_owner = player
				player.hand_zone.add_card(card)
			bot._submit_strategy_plan(bot._plan_god_manifestation())
			for _step in range(8):
				match_manager.advance_priority()
			if shelve.current_zone != player.deck_zone or valuable.current_zone != player.hand_zone or player.mana != 0:
				failures.append("Champion's Call did not shelve the lower-value card and pay the rest in mana")
			var summoned_creatures := bot._get_board_creatures(player)
			var active_god: ActiveGodCard = null if summoned_creatures.is_empty() else summoned_creatures[0] as ActiveGodCard
			if active_god == null or not active_god.summoned_by_champions_call:
				failures.append("Champion's Call did not mark its summoned Active God")
			else:
				var active_copy := GameState.deserialize_embedded_card(GameState.serialize_embedded_card(active_god)) as ActiveGodCard
				if active_copy == null or not active_copy.summoned_by_champions_call:
					failures.append("Champion's Call summon provenance was lost during serialization")
				active_god.strength = 31
				opponent.followers = 50
				opponent.guard = 2
				match_manager.selected_attacker = active_god
				match_manager.pending_attack_target = opponent
				var attack := match_manager._build_pending_attack_action()
				var projected := bot._estimate_projected_attack_economy(attack, {}, false)
				match_manager._finish_followers_attack(attack, opponent)
				var expected_loss := 5 if god is Thor else 13
				var before_guard := expected_loss + 2
				var expected_math := "31 STR (%s) ÷ 2 (Champion's Call)" % active_god.card_name
				if god is Thor:
					expected_math += " ÷ 2 (Patron's Hand)"
				expected_math += " → %d (rounded down) − 2 (Guard) = %d" % [before_guard, expected_loss]
				if opponent.followers != 50 - expected_loss or opponent.guard != 0 \
						or int(projected["opponent_followers_lost"]) != expected_loss \
						or not match_manager.last_resolution_text.contains("(" + expected_math):
					failures.append("Champion's Call did not apply and log the expected halving and Guard for %s" % active_god.card_name)
		elif god is TiamatThePrimordial:
			player.mana = TiamatActive.new().mana_cost
			var birth_target := Asakku.new()
			birth_target.card_owner = player
			player.hand_zone.add_card(birth_target)
			var power := TakeTheField.new()
			power.card_owner = player
			player.power_zones[2].add_card(power)
			bot._submit_strategy_plan(bot._plan_power_unlock())
			if power.is_face_down or player.mana != 0:
				failures.append("Take the Field did not pay for and unlock Tiamat's manifestation")
			for _step in range(8):
				match_manager.advance_priority()
			if not bot._get_board_creatures(player).has(birth_target):
				failures.append("Ranked Tiamat did not use Birth after Take the Field")
		elif god is TezcatlipocaTheSmokingMirror:
			var offerings: Array[Card] = []
			for i in range(TezcatlipocaTheSmokingMirror.REQUIRED_NECOC_YAOTL_SACRIFICES + 1):
				var offering := Asakku.new()
				offering.card_owner = player
				player.reserve_zones[i].add_card(offering)
				offering.spend_major_creature_action()
				offerings.append(offering)
			var victim := BrownBear.new()
			victim.card_owner = opponent
			opponent.frontline_zones[0].add_card(victim)
			for offering in offerings.slice(2):
				offering.current_zone.remove_card(offering)
			if not bot._plan_god_manifestation().is_empty():
				failures.append("Necoc Yaotl sacrificed an ordinary creature without spare board presence")
			for i in range(2, offerings.size()):
				player.reserve_zones[i].add_card(offerings[i])
			for _action in range(TezcatlipocaTheSmokingMirror.REQUIRED_NECOC_YAOTL_SACRIFICES + 1):
				bot._submit_strategy_plan(bot._plan_god_manifestation())
				for _step in range(8):
					match_manager.advance_priority()
			if victim.get_controller() != player:
				failures.append("Necoc Yaotl did not complete Titlacauan with the stored sacrifices")
		if god.current_zone == player.god_zone or not bot._get_board_creatures(player).any(func(card: Card) -> bool:
			return card is ActiveGodCard and god.is_own_active_god_card(card)
		):
			failures.append("Ranked bot failed to summon the matching Active God for %s" % god.card_name)
		bot.detach()

func _check_bot_power_followthrough(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.start_turn()
	game.player_chooses_upkeep_only()
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var factory := MechFactory.new()
	factory.card_owner = player
	player.power_zones[0].add_card(factory)

	player.mana = MechFactory.UNLOCK_COST + MechFactory.ACTIVATION_COST - 1
	if not bot._plan_power_unlock().is_empty():
		failures.append("Bot planned to unlock Mech Factory without enough mana to build a Mech")

	player.mana += 1
	var plan := bot._plan_power_unlock()
	if plan.get("activate_after_unlock_uid") != factory.uid or not bot._submit_strategy_plan(plan):
		failures.append("Bot did not plan a funded Mech Factory unlock and activation")
	elif not bot._take_main_phase_action():
		failures.append("Bot did not follow through after unlocking Mech Factory")
	else:
		for _step in range(8):
			manager.advance_priority()
		if factory.activations_this_turn != 1 or player.mana != 0:
			failures.append("Bot's Mech Factory follow-up did not resolve through the match command path")

	var palisade := PalisadePower.new()
	palisade.card_owner = player
	player.power_zones[1].add_card(palisade)
	player.mana = PalisadePower.UNLOCK_COST + PalisadePower.ACTIVATION_COST
	if not bot._plan_power_unlock().is_empty():
		failures.append("Bot unlocked Palisade with no enemy attack pressure")
	bot.detach()

func _check_heroic_stand_combat_count(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	var charm := HeroicStand.new()
	var attacker := BrownBear.new()
	var defender := Enkidu.new()
	charm.card_owner = player
	attacker.card_owner = player
	defender.card_owner = opponent
	player.deck_zone.add_card(charm)
	game.players.assign([player, opponent])
	game.setup_game()
	player.move_card(charm, player.hand_zone)
	player.frontline_zones[0].add_card(attacker)
	opponent.frontline_zones[0].add_card(defender)
	var mana_sink := BrownBear.new()
	mana_sink.card_owner = player
	mana_sink.mana_cost = 12
	player.deck_zone.add_card(mana_sink)
	player.mana = 0
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	if BotCardStrategyScript.preparation_score(bot, charm) > 0:
		failures.append("Bot wanted to prepare Heroic Stand before any combat")
	for turn in [2, 3]:
		game.turn_number = turn
		game._record_combat_participation(attacker, defender)
	if charm.can_activate_from_hand(game):
		failures.append("Heroic Stand activated before three combats")
	if BotCardStrategyScript.effect_score(bot, charm) != BotCardStrategyScript.BAD \
			or BotCardStrategyScript.preparation_score(bot, charm) <= 0:
		failures.append("Bot did not distinguish preparing Heroic Stand from casting it at two combats")
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = player
	attack.attacker = attacker
	attack.target = defender
	attacker.strength = 10
	defender.creature_mode = Card.CreatureMode.DEFENSIVE
	defender.resilience = 10
	var safe := bot._estimate_attack_economy(attack, null, 0, 0)
	defender.creature_mode = Card.CreatureMode.AGGRESSIVE
	defender.strength = 11
	var fatal := bot._estimate_attack_economy(attack, null, 0, 0)
	attack.target = opponent
	var direct := bot._estimate_attack_economy(attack, null, 0, 0)
	var reward := int(safe.get("heroic_stand_reward", 0))
	if reward <= 0 or fatal.has("heroic_stand_reward") or direct.has("heroic_stand_reward"):
		failures.append("Bot did not reserve Heroic Stand's combat reward for a surviving creature fight")
	if bot._score_attack_economy(safe) - bot._score_attack_economy(safe, {"heroic_stand_reward": reward}) != reward:
		failures.append("Bot counted Heroic Stand twice in one attack line")
	game.turn_number = 4
	game._record_combat_participation(attacker, defender)
	if not charm.can_activate_from_hand(game):
		failures.append("Heroic Stand did not count combats across turns")
	var plan := bot._get_best_strategy_action([], {}, 0)
	if plan.get("command", {}).get("charm_uid", "") != charm.uid or plan.get("score", 0) <= 0:
		failures.append("Bot did not plan to cast Heroic Stand once a creature qualified")
	var mana_before := player.mana
	charm.resolve(game)
	if player.mana != mana_before + HeroicStand.MANA_GAIN:
		failures.append("Heroic Stand did not grant mana after three combats")
	var private_snapshot := GameState.serialize(game, 0)
	var opponent_snapshot := GameState.serialize(game, 1)
	if not bool(private_snapshot.players[0].get("starting_deck_has_heroic_stand", false)) \
			or opponent_snapshot.players[0].has("starting_deck_has_heroic_stand") \
			or "Combats this game: 3" not in CardDetailContentBuilder._get_hover_detail_lines(attacker, player) \
			or "Combats this game: 3" in CardDetailContentBuilder._get_hover_detail_lines(attacker, opponent):
		failures.append("Heroic Stand's hover count did not respect starting deck privacy")
	if BeardedAxe.new().get_bonus_strength_vs_defense(attacker) != 8:
		failures.append("Bearded Axe did not grant its Defensive-stance bonus to a non-Norse Warrior")
	game._upkeep_resolved_turn = game.turn_number
	game.prepare_card(player, charm, player.reserve_zones[0])
	if not charm.is_prepared:
		failures.append("Heroic Stand priority fixture could not prepare the charm")
		return
	game.turn_number = 5
	game.current_player = opponent
	game.other_player = player
	game.turn_player = opponent
	game._upkeep_resolved_turn = game.turn_number
	game.priority_player = player
	player.mana = 0
	var end_turn := CardAction.new()
	end_turn.type = CardAction.Type.EVENT
	end_turn.source_player = opponent
	end_turn.event_name = "end_turn"
	game.action_stack.append(end_turn)
	if bot._choose_priority_response() != charm or not bot._submit_priority_response(charm):
		failures.append("Bot did not use a prepared Heroic Stand on the opponent's turn")
		return
	for _step in range(8):
		if charm.current_zone == player.graveyard_zone:
			break
		manager.advance_priority()
	if charm.current_zone != player.graveyard_zone or player.mana != HeroicStand.MANA_GAIN:
		failures.append("Bot's prepared Heroic Stand did not resolve for seven mana")

func _check_bot_locked_board_forecast(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.setup_game()
	game.turn_number = 2
	var attacker := BrownBear.new()
	attacker.card_owner = player
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = 1
	player.frontline_zones[0].add_card(attacker)
	opponent.guard = 1
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	if not manager.can_attack(attacker) or not bot._locked_board_state():
		failures.append("Locked board fixture did not have a legal attack absorbed by Guard")
	if not (bot._posture_cache["value"] as Dictionary).is_empty():
		failures.append("Locked board forecast re-entered strategic posture evaluation")
	if bot._strategy_posture().get("posture", "") != "locked_ahead":
		failures.append("Strategic posture did not use the computed board lock")
	bot.detach()

func _check_combat_rounding(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	player.player_name = "Attacker"
	opponent.player_name = "Defender"
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.sfx_enabled = false
	player.game_manager = game
	opponent.game_manager = game
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)

	var attacker := RoboticFootsoldier.new()
	var partner := RoboticFootsoldier.new()
	for card: Card in [attacker, partner]:
		card.card_owner = player
		card.creature_mode = Card.CreatureMode.AGGRESSIVE
		card.strength = 5
	player.frontline_zones[0].add_card(attacker)
	player.frontline_zones[1].add_card(partner)
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.attacker = attacker
	action.united_front_partner = partner
	action.target = opponent
	action.halve_follower_damage = true
	opponent.followers = 10
	opponent.guard = 1
	var projected := bot._estimate_projected_attack_economy(action, {}, false)
	manager._finish_followers_attack(action, opponent)
	var attacker_label := "Robotic Footsoldier at Attacker's Front Line position 1"
	var partner_label := "Robotic Footsoldier at Attacker's Front Line position 2"
	var united_front_math := "5 STR (%s) + 5 STR (%s) → 10 ÷ 2 (attack effect)" % [attacker_label, partner_label]
	if opponent.followers != 6 or opponent.guard != 0 or int(projected["opponent_followers_lost"]) != 4 \
			or not manager.last_resolution_text.contains(united_front_math):
		failures.append("United Front did not combine 5 and 5 Strength before halving and spending Guard")
	opponent.guard = 8
	manager._finish_followers_attack(action, opponent)
	if opponent.followers != 6 or opponent.guard != 3 \
			or not manager.last_resolution_text.contains("5 (rounded down) − 5 (Guard) = 0"):
		failures.append("Follower damage log did not show how much Guard was spent to block all damage")

	var tez := TezcatlipocaActive.new()
	tez.card_owner = player
	tez.creature_mode = Card.CreatureMode.AGGRESSIVE
	tez.strength = 11 - TezcatlipocaActive.JAGUAR_FORM_STRENGTH_BONUS
	player.frontline_zones[2].add_card(tez)
	action.attacker = tez
	action.united_front_partner = null
	action.halve_follower_damage = false
	var expected_conversion_by_followers := {20: 4, 5: 2, 1: 0}
	for followers: int in expected_conversion_by_followers:
		opponent.followers = followers
		opponent.guard = 2
		var expected: int = expected_conversion_by_followers[followers]
		var previous_followers := player.followers
		projected = bot._estimate_projected_attack_economy(action, {}, false)
		var converted := game.resolve_followers_attack([tez], opponent)
		if converted != expected or opponent.guard != 0 or opponent.followers != followers - expected \
				or player.followers != previous_followers + expected or int(projected["opponent_followers_lost"]) != expected:
			failures.append("The Smoking Mirror miscalculated conversion against %d followers and 2 Guard" % followers)
		if not game.consume_player_feedback().contains("(11 STR (%s) − 2 (Guard) = 9)" % tez.card_name):
			failures.append("Follower damage log did not show Guard applied without any halving effects")

	var defender := RoboticFootsoldier.new()
	defender.card_owner = opponent
	defender.creature_mode = Card.CreatureMode.DEFENSIVE
	defender.strength = 3
	defender.resilience = 10
	opponent.frontline_zones[0].add_card(defender)
	var defender_label := "Robotic Footsoldier at Defender's Front Line position 1"
	game.resolve_combat_with_continuation(attacker, defender)
	if not game.consume_player_feedback().contains("(10 RES (%s) − 5 STR (%s) → 5)" % [defender_label, attacker_label]):
		failures.append("Follower damage log did not name the creatures in the RES and STR calculation")
	defender.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.followers = 10
	game.capture_committed_combat_snapshot(attacker, defender)
	game.resolve_combat_with_continuation(attacker, defender)
	if opponent.followers != 8 \
			or not game.consume_player_feedback().contains("(5 STR (%s) − 3 STR (%s) → 2)" % [attacker_label, defender_label]):
		failures.append("Follower damage log did not show the STR difference in committed combat")

func _check_bot_follower_valuation(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)

	var loss := bot._score_follower_loss(player, 2, 25)
	var result := {"bot_followers_lost": 2}
	if bot._score_attack_economy(result, {"bot_followers": 25}) != -loss \
			or bot._score_attack_economy(result) >= 0 or bot._score_attack_economy(result) <= -loss:
		failures.append("Bot did not price combat loss from the followers remaining in the line")
	player.followers = 23
	if BotCardStrategyScript.follower_gain(player, 2) != loss \
			or bot._score_follower_safety(23, 25) != roundi(loss * bot._posture_safety_multiplier()):
		failures.append("Bot prices equivalent follower damage, healing, and safety on different scales")
	var terminal := {"bot_followers_lost": 2, "opponent_wins": true}
	var line := {"bot_followers": 2}
	if bot._score_attack_economy(result, line) - bot._score_attack_economy(terminal, line) != bot.ECON_CARD_VALUE * 20:
		failures.append("Bot did not account for lethal separately from the follower change")

	var guard := ManaGuard.new()
	guard.card_owner = player
	guard.is_face_down = false
	player.power_zones[0].add_card(guard)
	var attacker := CreatureCard.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = 14
	opponent.frontline_zones[0].add_card(attacker)
	player.followers = 10
	player.mana = 20

	guard.is_face_down = true
	player.mana = ManaGuard.UNLOCK_COST
	if not bot._plan_power_unlock().is_empty():
		failures.append("Bot unlocked Mana Guard without enough mana to buy protection")
	player.mana = 20
	if bot._plan_power_unlock().get("activate_after_unlock_uid") != guard.uid:
		failures.append("Bot did not plan to unlock and activate Mana Guard against a lethal attack")
	guard.is_face_down = false
	var plan := bot._plan_power_activation(guard)
	var payment := 3
	var expected := bot._score_follower_safety(0, player.followers) - BotCardStrategyScript.mana_penalty(bot, payment)
	if plan.get("command", {}).get("mana_amount") != payment or int(plan.get("score", 0)) != expected:
		failures.append("Bot did not price Mana Guard once for the follower loss the payment prevents")
	elif not bot._submit_strategy_plan(plan):
		failures.append("Bot could not submit its Mana Guard payment")
	else:
		for _step in range(8):
			manager.advance_priority()
		if player.guard != payment * ManaGuard.GUARD_PER_MANA or player.mana != 20 - payment:
			failures.append("Bot's Mana Guard payment did not resolve as planned")
	bot.detach()

func _check_card_interception_exceptions(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	var manager := _new_fixture_match(game)

	var attacker := HariiWarrior.new()
	attacker.card_owner = opponent
	attacker.speed = 6
	opponent.frontline_zones[0].add_card(attacker)
	var human := HariiWarrior.new()
	human.card_owner = player
	player.reserve_zones[0].add_card(human)
	var animal := StoneMonkey.new()
	animal.card_owner = player
	player.frontline_zones[0].add_card(animal)

	var serpent := SevenHeadedSerpent.new()
	serpent.card_owner = player
	serpent.creature_mode = Card.CreatureMode.DEFENSIVE
	player.frontline_zones[1].add_card(serpent)
	if not manager._can_intercept(serpent, attacker, human) or manager._can_intercept(serpent, attacker, animal):
		failures.append("Seven-Headed Serpent did not ignore speed while respecting position")
	if manager._can_intercept(attacker, serpent, opponent):
		failures.append("An opposing creature could intercept Seven-Headed Serpent")

	var urisk := UriskGrovekeepers.new()
	urisk.card_owner = player
	urisk.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.reserve_zones[1].add_card(urisk)
	if not manager._can_intercept(urisk, attacker, animal) or manager._can_intercept(urisk, attacker, human):
		failures.append("Urisk Grovekeepers did not limit its position and speed exceptions to its protected types")

	var tianlong := TianlongHolyDragon.new()
	tianlong.card_owner = player
	tianlong.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.reserve_zones[3].add_card(tianlong)
	var dragon := PaiLongAutumnKing.new()
	dragon.card_owner = player
	player.frontline_zones[4].add_card(dragon)
	if not manager._can_intercept(tianlong, attacker, player) or not manager._can_intercept(tianlong, attacker, dragon):
		failures.append("Tianlong could not use Reach and bypass speed for its god or higher-level Dragon")
	if manager._can_intercept(tianlong, attacker, human):
		failures.append("Tianlong used Reach for an unrelated creature")
	for card: Card in [urisk, tianlong]:
		if "Reach" not in CardDetailContentBuilder.extract_card_keywords(card):
			failures.append("%s did not show the Reach keyword in its card details" % card.card_name)

	# Patron's Hand intercepts at a fixed Speed 4 for your followers or humans.
	var skimmer := CreatureCard.new()
	skimmer.card_owner = opponent
	skimmer.creature_mode = Card.CreatureMode.AGGRESSIVE
	skimmer.speed = 4
	opponent.frontline_zones[1].add_card(skimmer)
	var thor := ThorActive.new()
	thor.card_owner = player
	thor.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.reserve_zones[2].add_card(thor)
	if manager._can_intercept(thor, attacker, player):
		failures.append("Active Thor intercepted for followers from the reserve in aggressive stance")
	player.move_card(thor, player.frontline_zones[2])
	if manager._can_intercept(thor, attacker, player) or not manager._can_intercept(thor, skimmer, player):
		failures.append("Active Thor did not intercept for followers at exactly Speed 4")
	thor.creature_mode = Card.CreatureMode.DEFENSIVE
	if not manager._can_intercept(thor, attacker, player) or not manager._can_intercept(thor, attacker, human):
		failures.append("A face-up Defensive Thor could not intercept a faster attacker for followers or a Human in range")

	var power := GiantsDisdain.new()
	power.card_owner = player
	power.is_face_down = false
	player.power_zones[0].add_card(power)
	var giant := GiantMasterArchitect.new()
	giant.card_owner = player
	giant.creature_mode = Card.CreatureMode.DEFENSIVE
	# A face-up Defensive body intercepts regardless of Speed, so hide the Giant
	# to leave Giant's Disdain as its only way past a faster attacker.
	giant.is_stealth = true
	giant.is_face_down = true
	player.frontline_zones[3].add_card(giant)
	if not manager._can_intercept(giant, attacker, human) or manager._can_intercept(giant, attacker, animal):
		failures.append("Giant's Disdain did not bypass speed alone when intercepting a non-Giant")
	attacker.card_types.append("Giant")
	if manager._can_intercept(giant, attacker, human):
		failures.append("Giant's Disdain bypassed the speed of an attacking Giant")

	# A face-up Defensive body intercepts regardless of Speed. Stealth is face-down,
	# and hiding no longer costs a creature any Speed.
	var wall := CreatureCard.new()
	wall.card_owner = player
	wall.speed = 1
	wall.creature_mode = Card.CreatureMode.DEFENSIVE
	player.reserve_zones[2].add_card(wall)
	if not manager._can_intercept(wall, attacker, player):
		failures.append("A face-up Defensive creature did not intercept a faster attack")
	wall.is_stealth = true
	wall.is_face_down = true
	if wall.get_effective_speed() != 1 or manager._can_intercept(wall, attacker, player):
		failures.append("A stealth creature lost Speed or intercepted a faster attack without an ability")

	# Hermes: your creatures cannot be intercepted by slower creatures.
	var hermes := Hermes.new()
	hermes.card_owner = player
	player.god_zone.add_card(hermes)
	var swift := CreatureCard.new()
	swift.card_owner = player
	swift.speed = 5
	player.reserve_zones[4].add_card(swift)
	var drudge := CreatureCard.new()
	drudge.card_owner = opponent
	drudge.speed = 4
	drudge.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[2].add_card(drudge)
	if manager._can_intercept(drudge, swift, opponent) or not manager._can_intercept(drudge, skimmer, opponent):
		failures.append("Hermes did not block only slower creatures from intercepting")
	hermes.is_muted = true
	if not manager._can_intercept(drudge, swift, opponent):
		failures.append("A muted Hermes still blocked a face-up Defensive interceptor")

func _check_bot_summon_and_intercept(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 2
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var enki := EnkiLordOfEridu.new()
	enki.card_owner = opponent
	enki.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(enki)
	var berserker := Berserker.new()
	berserker.card_owner = opponent
	berserker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[1].add_card(berserker)
	var mech := DevastatorMech.new()
	mech.card_owner = player
	player.hand_zone.add_card(mech)
	var plan := bot._plan_creature_summon()
	var command: Dictionary = plan.get("command", {})
	if command.get("card_uid") != mech.uid or command.get("mode") != Card.CreatureMode.AGGRESSIVE:
		failures.append("Bot overlooked a Devastator Mech summon with Berserker available to attack alongside Enki")
	player.hand_zone.remove_card(mech)
	player.frontline_zones[0].add_card(mech)
	mech.creature_mode = Card.CreatureMode.AGGRESSIVE
	var attack := bot._plan_combat(bot._get_combat_candidates())
	if attack.get("target") != berserker:
		failures.append("Bot did not choose Berserker over Enki and a less valuable direct attack")
	var intercept := {"attacker_uid": enki.uid, "target_uid": "0", "interceptor_uids": [mech.uid]}
	player.followers = 12
	if bot._choose_interceptor(intercept) != mech.uid:
		failures.append("Bot declined to lose its Mech to intercept a lethal follower attack it could survive")
	player.followers = 8
	if not bot._choose_interceptor(intercept).is_empty():
		failures.append("Bot chose a losing interception that still allowed lethal follower damage")
	bot.detach()

func _check_bot_berserker_rage_combo(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 2
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)

	var berserker := Berserker.new()
	berserker.card_owner = player
	player.hand_zone.add_card(berserker)
	var threat := CreatureCard.new()
	threat.card_owner = opponent
	threat.card_name = "Preflight Rage Threat"
	threat.strength = 26
	threat.resilience = 20
	threat.speed = 3
	threat.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(threat)
	player.mana = 5
	opponent.followers = 20

	var summon := bot._plan_creature_summon()
	var command: Dictionary = summon.get("command", {})
	if command.get("card_uid") != berserker.uid or command.get("mode") != Card.CreatureMode.AGGRESSIVE:
		failures.append("Bot did not summon Berserker aggressively to set up Rage against a 26-STR creature")

	player.hand_zone.remove_card(berserker)
	player.frontline_zones[0].add_card(berserker)
	berserker.creature_mode = Card.CreatureMode.AGGRESSIVE
	var candidates := bot._get_combat_candidates()
	var baseline := bot._plan_combat(candidates)
	var strategy := bot._get_best_strategy_action(candidates, baseline, 0)
	var strategy_command: Dictionary = strategy.get("command", {})
	if strategy_command.get("type") != "activate_card_ability" or strategy_command.get("source_uid") != berserker.uid:
		failures.append("Bot did not activate Berserker Rage before attacking a 26-STR creature")

	var guard_action := CardAction.new()
	guard_action.type = CardAction.Type.ATTACK
	guard_action.attacker = berserker
	guard_action.source_player = player
	guard_action.target = threat
	var rage_stats := {
		berserker: Vector3i(Berserker.RAGE_STR_BONUS, 0, 0),
		ThorPracticeBot.PROJECTED_DESTRUCTION_GUARDS_KEY: [berserker],
	}
	var guarded := bot._estimate_raw_attack_economy(guard_action, rage_stats)
	if threat not in guarded.get("casualties", []) or berserker in guarded.get("casualties", []):
		failures.append("Projected Berserker Rage did not kill the 26-STR creature while preserving Berserker")
	bot.detach()

func _check_bot_interception_forecasts(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	opponent.mana = 10
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)

	var threat := HariiWarrior.new()
	threat.card_owner = opponent
	threat.creature_mode = Card.CreatureMode.AGGRESSIVE
	threat.speed = 6
	threat.strength = 25
	opponent.frontline_zones[0].add_card(threat)
	var tianlong := TianlongHolyDragon.new()
	tianlong.card_owner = player
	player.hand_zone.add_card(tianlong)
	var projected := {"summon": tianlong, "zone": player.reserve_zones[0]}
	var danger := bot._forecast_incoming_follower_loss()
	var with_guard := bot._forecast_incoming_follower_loss(projected)
	projected["stealth"] = true
	projected["defensive_summons"] = true
	if with_guard >= danger or bot._forecast_incoming_follower_loss(projected) != danger:
		failures.append("Bot did not account for face-up Tianlong's Reach from the aggressive reserve when projecting a summon")

	var guard := CreatureCard.new()
	guard.card_owner = player
	guard.creature_mode = Card.CreatureMode.DEFENSIVE
	guard.speed = 6
	guard.resilience = 36
	player.frontline_zones[0].add_card(guard)
	var animal := CreatureCard.new()
	animal.card_owner = player
	animal.card_types.append("Animal")
	animal.creature_mode = Card.CreatureMode.AGGRESSIVE
	animal.strength = 5
	player.frontline_zones[1].add_card(animal)
	var urisk := UriskGrovekeepers.new()
	urisk.card_owner = player
	player.hand_zone.add_card(urisk)
	var zone := player.reserve_zones[0]
	if bot._estimate_defensive_summon_value(urisk, zone) <= 0 or bot._estimate_defensive_summon_value(urisk, zone, true) != 0:
		failures.append("Bot did not value Urisk's face-up protection of a frontline Animal from the reserve")

	var hidden := CreatureCard.new()
	hidden.card_owner = opponent
	hidden.is_face_down = true
	hidden.is_stealth = true
	hidden.speed = 6
	opponent.frontline_zones[1].add_card(hidden)
	var serpent := SevenHeadedSerpent.new()
	serpent.card_owner = player
	player.frontline_zones[2].add_card(serpent)
	var serpent_attack := CardAction.new()
	serpent_attack.type = CardAction.Type.ATTACK
	serpent_attack.attacker = serpent
	serpent_attack.source_player = player
	serpent_attack.target = opponent
	if not bot._can_attack_followers_after_modifiers(serpent, {}) \
			or bot._score_stat_attack_line(serpent_attack, {}, [hidden], 0) != bot._score_stat_attack_line(serpent_attack, {}, [], 0):
		failures.append("Bot still expected an interception from a hidden defender against Seven-Headed Serpent")
	serpent.is_muted = true
	if bot._can_attack_followers_after_modifiers(serpent, {}):
		failures.append("Bot expected muted Seven-Headed Serpent to bypass hidden defenders")

	var thor := ThorActive.new()
	thor.card_owner = opponent
	thor.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.reserve_zones[0].add_card(thor)
	var power := GiantsDisdain.new()
	power.card_owner = opponent
	opponent.power_zones[0].add_card(power)
	var giant := GiantMasterArchitect.new()
	giant.card_owner = opponent
	# Aggressive stance, so only Giant's Disdain can beat the faster attack: a
	# face-up Defensive body would intercept regardless of Speed.
	giant.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[2].add_card(giant)
	guard.creature_mode = Card.CreatureMode.AGGRESSIVE
	var replies: Dictionary = bot._get_attack_candidates(guard, null)[0]["replies"]
	if thor in replies or giant in replies:
		failures.append("Bot predicted that aggressive reserve Thor or a Giant with locked Giant's Disdain could intercept a faster attack")
	thor.creature_mode = Card.CreatureMode.DEFENSIVE
	power.is_face_down = false
	replies = bot._get_attack_candidates(guard, null)[0]["replies"]
	if thor not in replies or giant not in replies:
		failures.append("Bot omitted Thor or a Giant with unlocked Giant's Disdain from replies to a faster attacker")
	guard.card_types.append("Giant")
	replies = bot._get_attack_candidates(guard, null)[0]["replies"]
	if giant in replies:
		failures.append("Bot expected Giant's Disdain to bypass an attacking Giant's speed")
	bot.detach()

func _check_bot_prepare_and_reflect(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 0
	player.followers = 100
	opponent.followers = 100
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var mirror := ObsidianReflection.new()
	mirror.card_owner = player
	player.hand_zone.add_card(mirror)
	if not bot._take_main_phase_action() or mirror.current_zone not in player.reserve_zones or not mirror.is_prepared:
		failures.append("Bot did not prepare Obsidian Reflection on an empty board")
		return
	for zone in player.reserve_zones:
		if zone.cards.is_empty():
			var equipment := EquipmentCard.new()
			equipment.card_owner = player
			zone.add_card(equipment)
	var trap := SpellDemolition.new()
	trap.card_owner = player
	player.hand_zone.add_card(trap)
	if not bot._try_prepare_strategy_card() or trap.current_zone not in player.frontline_zones or player.mana != 0:
		failures.append("Bot did not prepare a future Hex for free in an available frontline lane")
	var attacker := RoboticFootsoldier.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = 20
	attacker.speed = 3
	opponent.frontline_zones[0].add_card(attacker)
	var defender := RoboticFootsoldier.new()
	defender.card_owner = player
	defender.creature_mode = Card.CreatureMode.DEFENSIVE
	defender.resilience = 5
	defender.strength = 5
	player.frontline_zones[0].add_card(defender)
	game.current_player = opponent
	game.other_player = player
	game.turn_number += 1
	game._upkeep_resolved_turn = game.turn_number
	game.priority_player = player
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = opponent
	attack.attacker = attacker
	attack.target = defender
	game.action_stack.append(attack)
	if bot._choose_priority_response() == mirror:
		failures.append("Bot spent Obsidian Reflection on combat with no follower loss")
	attack.target = player
	if bot._choose_priority_response() != mirror:
		failures.append("Bot missed Obsidian Reflection on a direct follower attack")
	attack.target = defender
	defender.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.guard = 4
	if bot._choose_priority_response() != mirror or not bot._submit_priority_response(mirror):
		failures.append("Bot did not submit Obsidian Reflection in a losing creature fight")
		return
	for _step in range(8):
		manager.advance_priority()
	if mirror.current_zone != player.graveyard_zone or defender.current_zone != player.graveyard_zone \
			or player.followers != 100 or opponent.followers != 89 or opponent.guard != 0:
		failures.append("Obsidian Reflection did not redirect combat damage through the attacker's Guard")
	for united_front in [false, true]:
		var next_defender := RoboticFootsoldier.new()
		next_defender.card_owner = player
		next_defender.creature_mode = Card.CreatureMode.AGGRESSIVE
		next_defender.strength = 5
		player.frontline_zones[1].add_card(next_defender)
		opponent.followers = 100
		game.set_temporary_combat_follower_damage_reversed(true)
		var expected_followers := 85
		if united_front:
			var partner := RoboticFootsoldier.new()
			partner.card_owner = opponent
			partner.creature_mode = Card.CreatureMode.AGGRESSIVE
			partner.strength = 10
			opponent.frontline_zones[1].add_card(partner)
			game.resolve_united_front_combat(attacker, partner, next_defender)
			expected_followers = 75
		else:
			game.capture_committed_combat_snapshot(attacker, next_defender)
			game.resolve_combat_with_continuation(attacker, next_defender, Callable())
		if player.followers != 100 or opponent.followers != expected_followers \
				or game._temporary_combat_follower_damage_reversed:
			failures.append("Obsidian Reflection did not apply and clear after %s combat" % ("United Front" if united_front else "committed"))

func _check_bot_eris_battle_cry_sweep(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 0
	player.followers = 100
	opponent.followers = 100
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)

	# A dominating wall against a wide attacking board: Eris' Battle Cry in
	# hand must be prepared so the sweep line exists at all.
	var wall := RoboticFootsoldier.new()
	wall.card_owner = player
	wall.creature_mode = Card.CreatureMode.DEFENSIVE
	wall.strength = 8
	wall.resilience = 36
	wall.speed = 2
	player.frontline_zones[2].add_card(wall)
	for index in range(4):
		var attacker := RoboticFootsoldier.new()
		attacker.card_owner = opponent
		attacker.creature_mode = Card.CreatureMode.AGGRESSIVE if index % 2 == 0 else Card.CreatureMode.DEFENSIVE
		attacker.strength = 10 + index * 4
		attacker.resilience = 6
		attacker.speed = 2
		opponent.frontline_zones[index].add_card(attacker)
	var eris := ErisBattleCry.new()
	eris.card_owner = player
	player.hand_zone.add_card(eris)
	if not bot._try_prepare_strategy_card() or eris.current_zone not in player.reserve_zones or not eris.is_prepared:
		failures.append("Bot did not prepare Eris' Battle Cry behind a dominating wall against a wide board")
		return

	# The bot's next turn: the hex prepared last turn can now fire.
	game.turn_number += 2
	game._upkeep_resolved_turn = game.turn_number
	var plain_gain := BotCardStrategyScript.eris_battle_cry_gain(bot, eris)
	if plain_gain <= 0:
		failures.append("Eris' Battle Cry priced the wide-board sweep non-positive behind a dominating wall")
	var eris_bonus := BotCardStrategyScript.ferocious_eris_sweep_gain(bot)
	if eris_bonus < 4 * 700:
		failures.append("Ferocious Defence unlock did not price the Eris' Battle Cry sweep against a dominated board")
	var ferocious := FerociousDefence.new()
	ferocious.card_owner = player
	ferocious.is_face_down = false
	player.power_zones[0].add_card(ferocious)
	var ferocious_gain := BotCardStrategyScript.eris_battle_cry_gain(bot, eris)
	if ferocious_gain <= plain_gain or ferocious_gain < 4 * BotCardStrategyScript.CARD_VALUE:
		failures.append("Eris' Battle Cry did not price Ferocious Defence kills on every compelled attacker")
	var plan := bot._get_best_strategy_action([], {})
	var command: Dictionary = plan.get("command", {})
	if command.get("type") != "activate_prepared_hex" or command.get("hex_uid") != eris.uid:
		failures.append("Bot did not plan Eris' Battle Cry activation once the sweep line was live")

	# Honesty guard: with the wall gone the same board punishes the bot, so
	# the cry must not fire.
	player.power_zones[0].remove_card(ferocious)
	player.frontline_zones[2].remove_card(wall)
	var bare_gain := BotCardStrategyScript.eris_battle_cry_gain(bot, eris)
	if bare_gain >= 0:
		failures.append("Eris' Battle Cry priced a sweep non-negative with no wall to intercept the compelled attacks")
	var bare_plan := bot._get_best_strategy_action([], {})
	if bare_plan.get("command", {}).get("type") == "activate_prepared_hex":
		failures.append("Bot planned Eris' Battle Cry activation without a wall to intercept the compelled attacks")

func _check_bot_namburbi_combat_ward(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 10
	opponent.mana = 10
	player.followers_enabled = false
	opponent.followers_enabled = false
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var ward := NamburbiApotropaeon.new()
	ward.card_owner = player
	player.hand_zone.add_card(ward)
	for controller: Player in [player, opponent]:
		for lane in range(2):
			var creature := RoboticFootsoldier.new()
			creature.card_owner = controller
			creature.creature_mode = Card.CreatureMode.AGGRESSIVE
			creature.strength = 20
			controller.frontline_zones[lane].add_card(creature)
	var attacks := bot._get_combat_candidates()
	var plan := bot._plan_namburbi_ward(attacks, bot._plan_combat(attacks))
	var command: Dictionary = plan.get("command", {})
	if command.get("charm_uid") != ward.uid or command.get("prepared", true):
		failures.append("Bot missed the Namburbi cast that turns two combat trades into clean kills")
	if game.has_turn_destruction_ward(player) or game.has_turn_follower_loss_prevention(player):
		failures.append("Bot forecasting Namburbi left its ward active in the game")
	for card in bot._get_board_creatures(player):
		card.strength += 1
	attacks = bot._get_combat_candidates()
	if not bot._plan_namburbi_ward(attacks, bot._plan_combat(attacks)).is_empty():
		failures.append("Bot wasted Namburbi on attacks its creatures already survive")
	for card in bot._get_board_creatures(player):
		card.strength -= 1
	ward.is_prepared = true
	player.move_card(ward, player.reserve_zones[0])
	game.prepared_charms[ward] = game.turn_number - 1
	game.current_player = opponent
	game.other_player = player
	game.priority_player = player
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = opponent
	attack.attacker = opponent.frontline_zones[0].cards[0]
	attack.target = player.frontline_zones[0].cards[0]
	game.action_stack.append(attack)
	if bot._choose_priority_response() != ward:
		failures.append("Bot did not use prepared Namburbi to save a creature from a combat trade")
	attack.attack_speed_override = ward.get_effective_speed() + 1
	if bot._choose_priority_response() == ward:
		failures.append("Bot selected Namburbi against an attack too fast to answer")
	attack.attack_speed_override = -1
	var defender := attack.target as Card
	if not bot._submit_priority_response(ward):
		failures.append("Bot could not submit its prepared Namburbi response")
	else:
		for _step in range(8):
			manager.advance_priority()
		if ward.current_zone != player.graveyard_zone or not game.has_turn_destruction_ward(player) \
				or defender.current_zone != player.frontline_zones[0] or attack.attacker.current_zone != opponent.graveyard_zone:
			failures.append("Bot's Namburbi response did not turn the trade into a clean kill")
	bot.detach()

func _check_bot_speed_one_stealth(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	game.has_resolved_attack_this_turn = true
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var sulak := SulakTheUnclean.new()
	sulak.card_owner = player
	player.hand_zone.add_card(sulak)
	var threat := CreatureCard.new()
	threat.card_owner = opponent
	threat.creature_mode = Card.CreatureMode.AGGRESSIVE
	threat.speed = 1
	threat.strength = 14
	opponent.frontline_zones[0].add_card(threat)
	var danger := bot._forecast_incoming_follower_loss()
	var hidden := bot._plan_creature_summon(danger)
	if not hidden.get("command", {}).get("stealth", false):
		failures.append("Bot failed to summon Speed 1 Sulak in Stealth when it can block just as well")
	var optimism := FoolishOptimism.new()
	optimism.card_owner = player
	player.hand_zone.add_card(optimism)
	var face_up: Dictionary = bot._plan_creature_summon(danger).get("command", {})
	if face_up.get("card_uid") != sulak.uid or face_up.get("stealth", true):
		failures.append("Bot hid Sulak even though Foolish Optimism has a profitable face-up combat")
	player.hand_zone.remove_card(optimism)
	sulak.level = 1
	sulak.speed = 2
	if bot._plan_creature_summon(danger).get("command", {}).get("stealth", true):
		failures.append("Bot treated level 1 as a reason to hide a faster creature")
	sulak.level = 2
	sulak.speed = 1
	var hermes := Hermes.new()
	hermes.card_owner = player
	player.god_zone.add_card(hermes)
	player.mana = Hermes.ACTIVATION_COST
	game.has_resolved_attack_this_turn = false
	threat.creature_mode = Card.CreatureMode.DEFENSIVE
	threat.speed = 2
	threat.resilience = 30
	opponent.followers = sulak.strength
	var boosted := bot._plan_creature_summon(bot._forecast_incoming_follower_loss())
	if boosted.get("command", {}).get("mode") != Card.CreatureMode.AGGRESSIVE \
			or boosted.get("command", {}).get("stealth", true) or int(boosted.get("combat_score", 0)) < ThorPracticeBot.ECON_CARD_VALUE * 20:
		failures.append("Bot missed a face-up summon that Hermes can speed up for lethal")
	game.has_resolved_attack_this_turn = true
	if not bot._submit_strategy_plan(hidden) or not sulak.is_stealth:
		failures.append("Bot did not submit the Stealth summon for Sulak")
	bot.detach()

	var sage_game := _new_fixture_game()
	var sage_player := _new_fixture_player()
	var sage_opponent := _new_fixture_player()
	sage_game.players.assign([sage_player, sage_opponent])
	sage_game.current_player = sage_player
	sage_game.other_player = sage_opponent
	sage_game.turn_number = 3
	sage_game._upkeep_resolved_turn = sage_game.turn_number
	sage_game.has_resolved_attack_this_turn = true
	var sage_manager := _new_fixture_match(sage_game)
	var sage_bot := _new_fixture_bot()
	sage_bot.attach(sage_game, sage_manager, ServerBotGameInput.new(sage_manager, 0), 0)
	var sage := SixthSageAnEnlilda.new()
	sage.card_owner = sage_player
	sage_player.hand_zone.add_card(sage)
	var dwelling := E2Abzu.new()
	dwelling.card_owner = sage_player
	sage_player.deck_zone.add_card(dwelling)
	var sage_threat := CreatureCard.new()
	sage_threat.card_owner = sage_opponent
	sage_threat.creature_mode = Card.CreatureMode.AGGRESSIVE
	sage_threat.speed = 1
	sage_threat.strength = 13
	sage_opponent.frontline_zones[0].add_card(sage_threat)
	if sage.get_valid_targets(sage_game).is_empty():
		failures.append("Fixture lost the Ancient Dwelling the Sixth Sage can Conjure")
	if sage_bot._prefers_stealth_summon(sage):
		failures.append("Bot prefers hiding a Sixth Sage whose Conjure Home can still fetch an Ancient Dwelling")
	var sage_danger := sage_bot._forecast_incoming_follower_loss()
	var sage_plan: Dictionary = sage_bot._plan_creature_summon(sage_danger).get("command", {})
	if sage_plan.get("card_uid") == sage.uid and sage_plan.get("stealth", false):
		failures.append("Bot hid the Sixth Sage and forfeited its Conjure Home impact")
	sage_player.deck_zone.remove_card(dwelling)
	if not sage_bot._prefers_stealth_summon(sage):
		failures.append("Bot forgot an Impact with no targets left may hide again")
	var printed_impact := CreatureCard.new()
	printed_impact.card_owner = sage_player
	printed_impact.ability_text = "Sample ([b]Impact[/b]): stay face-up to resolve."
	if not sage_bot._stealth_would_forfeit_value(printed_impact):
		failures.append("Bot only protected listed cards instead of any printed Impact body")
	if sage_bot._stealth_would_forfeit_value(sage_threat):
		failures.append("Bot protected a plain body with no printed Impact and no suppressed hooks")
	sage_bot.detach()

func _check_bot_reserve_summon_threat(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var recruit := CreatureCard.new()
	recruit.card_owner = player
	recruit.strength = 12
	recruit.resilience = 10
	player.hand_zone.add_card(recruit)
	var defender := CreatureCard.new()
	defender.card_owner = player
	defender.resilience = 30
	defender.speed = 3
	player.frontline_zones[0].add_card(defender)
	var attacker := CreatureCard.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = 21
	attacker.speed = 3
	opponent.reserve_zones[0].add_card(attacker)
	var protected_summon := bot._plan_creature_summon(0)
	if protected_summon.get("command", {}).get("zone_type") != Zone.ZoneType.RESERVE:
		failures.append("Bot passed up a protected reserve summon that an advancing enemy could kill in the frontline")
	attacker.add_status_effect("cannot_move", "Preflight")
	if bot._plan_creature_summon(0).get("command", {}).get("zone_type") != Zone.ZoneType.FRONTLINE:
		failures.append("Bot passed up the frontline summon when the reserve attacker could not advance")
	attacker.remove_status_effects_by_name("cannot_move")
	defender.add_status_effect("cannot_intercept", "Preflight")
	if not bot._plan_creature_summon(0).is_empty():
		failures.append("Bot assumed a reserve summon was safe even though the advancing attacker could reach both rows")
	defender.remove_status_effects_by_name("cannot_intercept")
	if not bot._submit_strategy_plan(protected_summon) or recruit.current_zone not in player.reserve_zones:
		failures.append("Bot did not submit the summon in the protected reserve")
	bot.detach()

func _check_bot_warding_stone_summon_forecast(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	opponent.mana = 5
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var stone := WardingStone.new()
	stone.card_owner = player
	player.hand_zone.add_card(stone)
	player.followers = 12
	if not bot._plan_strategy_support(0).is_empty():
		failures.append("Bot planned Warding Stone with no board attackers or potential recruits")
	var recruit := CreatureCard.new()
	recruit.card_owner = opponent
	recruit.mana_cost = 2
	recruit.strength = 30
	recruit.speed = 3
	opponent.hand_zone.add_card(recruit)
	var hidden_score := int(bot._plan_strategy_support(0).get("score", 0))
	if hidden_score <= 0 or hidden_score >= bot.ECON_CARD_VALUE * 20:
		failures.append("Bot did not price hidden summon risk as a precautionary Warding Stone play")
	recruit.strength = 1
	if int(bot._plan_strategy_support(0).get("score", 0)) != hidden_score:
		failures.append("Warding Stone's hidden summon forecast used a private card's stats")
	player.followers = 100
	if not bot._plan_strategy_support(0).is_empty():
		failures.append("Bot spent Warding Stone on speculative summon risk at healthy followers")
	player.followers = 12
	player.guard = 24
	if not bot._plan_strategy_support(0).is_empty():
		failures.append("Bot planned Warding Stone for a speculative summon already covered by Guard")
	player.guard = 0
	recruit.strength = 30
	recruit.add_status_effect("revealed_in_hand", "Preflight")
	if int(bot._plan_strategy_support(0).get("score", 0)) < bot.ECON_CARD_VALUE * 20:
		failures.append("Bot missed a lethal attack from a revealed, affordable recruit")
	recruit.mana_cost = 20
	if not bot._plan_strategy_support(0).is_empty():
		failures.append("Bot planned Warding Stone for an unaffordable revealed recruit")
	bot.detach()

func _check_bot_doorway_grave_denial(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var doorway := DoorwayToTheVoid.new()
	doorway.card_owner = player
	player.hand_zone.add_card(doorway)
	var warrior := HariiWarrior.new()
	warrior.card_owner = opponent
	opponent.frontline_zones[0].add_card(warrior)
	var hidden_power := ManaGuard.new()
	hidden_power.card_owner = opponent
	hidden_power.is_face_down = true
	opponent.power_zones[0].add_card(hidden_power)
	var hidden_score := int(bot._plan_strategy_support(0).get("score", 0))
	var call := CallOfTheValkyrie.new()
	call.card_owner = opponent
	call.is_face_down = true
	opponent.power_zones[0].remove_card(hidden_power)
	opponent.power_zones[0].add_card(call)
	if hidden_score <= 0 or int(bot._plan_strategy_support(0).get("score", 0)) != hidden_score:
		failures.append("Doorway did not price a hidden power's possible recursion without reading its identity")
	call.is_face_down = false
	if int(bot._plan_strategy_support(0).get("score", 0)) <= hidden_score:
		failures.append("Doorway did not give more weight to a confirmed Call of the Valkyrie")
	opponent.move_card(warrior, opponent.graveyard_zone)
	if not bot._plan_strategy_support(0).is_empty():
		failures.append("Bot built Doorway for a creature already in the graveyard")
	var priest := FirstSageAdapa.new()
	priest.card_owner = opponent
	opponent.frontline_zones[0].add_card(priest)
	var kur_jara := KurJara.new()
	kur_jara.card_owner = opponent
	opponent.hand_zone.add_card(kur_jara)
	var possible_tree_score := int(bot._plan_strategy_support(0).get("score", 0))
	kur_jara.add_status_effect("revealed_in_hand", "Preflight")
	if possible_tree_score <= 0 or int(bot._plan_strategy_support(0).get("score", 0)) <= possible_tree_score:
		failures.append("Doorway did not price possible Kur-Jara fuel below a confirmed Kur-Jara")
	bot.detach()

func _check_bot_fenrir_summon(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	opponent.followers = 30
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var fenrir := Fenrir.new()
	fenrir.card_owner = player
	player.hand_zone.add_card(fenrir)
	for index in range(fenrir.sacrifice_cost):
		var payment := CreatureCard.new()
		payment.card_owner = player
		# Aggressive keeps these chumps out of interception range, so the
		# incoming attack stays lethal before Fenrir's Devour resilience.
		payment.creature_mode = Card.CreatureMode.AGGRESSIVE
		player.reserve_zones[index].add_card(payment)
	var prey := CreatureCard.new()
	prey.card_owner = opponent
	prey.level = 3
	prey.strength = 7
	prey.resilience = 32
	prey.speed = 3
	prey.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[0].add_card(prey)
	prey.add_buff("Preflight", 8, 1, 0)
	prey.add_status_effect("berserker_mead_guard", "Preflight")
	if not bot._plan_creature_summon().is_empty():
		failures.append("Bot planned Fenrir's Devour against a target protected from destruction")
	prey.remove_status_effects_by_name("berserker_mead_guard")
	var attacker := CreatureCard.new()
	attacker.card_owner = opponent
	attacker.level = 5
	attacker.strength = 40
	attacker.speed = 2
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[1].add_card(attacker)
	var starting_followers := player.followers
	player.followers = 10
	var danger := bot._forecast_incoming_follower_loss()
	var defense := bot._plan_creature_summon(danger)
	var defense_command: Dictionary = defense.get("command", {})
	if danger < player.followers or defense_command.get("card_uid") != fenrir.uid \
			or defense_command.get("mode") != Card.CreatureMode.DEFENSIVE \
			or int(defense.get("score", 0)) < ThorPracticeBot.ECON_CARD_VALUE * 30:
		failures.append("Bot overlooked Fenrir's Devour resilience when forecasting lethal on the opponent's turn")
	opponent.frontline_zones[1].remove_card(attacker)
	player.followers = starting_followers
	var summon := bot._plan_creature_summon()
	var command: Dictionary = summon.get("command", {})
	if command.get("card_uid") != fenrir.uid or command.get("mode") != Card.CreatureMode.AGGRESSIVE \
			or int(summon.get("combat_score", 0)) < ThorPracticeBot.ECON_CARD_VALUE * 20:
		failures.append("Bot overlooked Fenrir's same-turn lethal after devouring a buffed interceptor")
	elif not bot._submit_strategy_plan(summon):
		failures.append("Bot could not submit the projected Fenrir summon")
	else:
		for _step in range(8):
			manager.advance_priority()
		var attack := bot._plan_combat(bot._get_combat_candidates())
		if prey.current_zone != opponent.graveyard_zone or fenrir.get_effective_strength() != 35 \
				or fenrir.get_effective_resilience() != 53 or not bool(attack.get("lethal", false)):
			failures.append("Fenrir's resolved Devour did not produce the projected lethal attack")
	bot.detach()

func _check_bot_fenrir_creature_lethal(failures: PackedStringArray) -> void:
	# A Devour-buffed Fenrir must take the same-turn kill on a creature body:
	# killing an aggressive defender sends the excess STR to Followers. This
	# mirrors a live match where Fenrir reached 46/46 off The White Serpent and
	# then sat in defensive stance while Garm stayed on the opponent's board.
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 6
	opponent.followers = 26
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var fenrir := Fenrir.new()
	fenrir.card_owner = player
	player.hand_zone.add_card(fenrir)
	for index in range(fenrir.sacrifice_cost):
		var payment := CreatureCard.new()
		payment.card_owner = player
		payment.creature_mode = Card.CreatureMode.AGGRESSIVE
		player.reserve_zones[index].add_card(payment)
	var prey := CreatureCard.new()
	prey.card_owner = opponent
	prey.level = 4
	prey.strength = 26
	prey.resilience = 26
	prey.speed = 3
	prey.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(prey)
	var garm := GarmWatchdogOfHel.new()
	garm.card_owner = opponent
	garm.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[1].add_card(garm)
	var hidden := CreatureCard.new()
	hidden.card_owner = opponent
	hidden.level = 9
	hidden.strength = 1
	hidden.resilience = 80
	hidden.creature_mode = Card.CreatureMode.DEFENSIVE
	hidden.is_face_down = true
	opponent.reserve_zones[0].add_card(hidden)
	var summon := bot._plan_creature_summon()
	var command: Dictionary = summon.get("command", {})
	if command.get("card_uid") != fenrir.uid or command.get("mode") != Card.CreatureMode.AGGRESSIVE \
			or not bool(summon.get("lethal", false)):
		failures.append("Bot passed up Devour-buffed Fenrir's lethal attack on an aggressive creature")
	elif not bot._submit_strategy_plan(summon):
		failures.append("Bot could not submit the projected creature-target lethal summon")
	else:
		for _step in range(8):
			manager.advance_priority()
		var attack := bot._plan_combat(bot._get_combat_candidates())
		if fenrir.get_effective_strength() != 46 or fenrir.get_effective_resilience() != 46 \
				or prey.current_zone != opponent.graveyard_zone or not bool(attack.get("lethal", false)):
			failures.append("Fenrir's resolved Devour did not yield the projected creature-target lethal")
		# The same hidden reply must still veto an ordinary, non-lethal swing.
		opponent.followers = 200
		var saw_nonlethal_candidate := false
		for candidate: Dictionary in bot._get_combat_candidates():
			if candidate["target"] != garm:
				continue
			saw_nonlethal_candidate = true
			if not bot._project_attack(candidate).is_empty():
				failures.append("Bot treated a hidden interceptor as harmless for a non-lethal attack")
			break
		if not saw_nonlethal_candidate:
			failures.append("Bot did not project Fenrir's non-lethal attack on Garm")
	bot.detach()

func _check_bot_wolf_master(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 1
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var fenrir := Fenrir.new()
	fenrir.card_owner = player
	player.hand_zone.add_card(fenrir)
	var hand_creature := CreatureCard.new()
	hand_creature.card_owner = player
	hand_creature.strength = 60
	player.hand_zone.add_card(hand_creature)
	var rabid_wolf := RabidWolf.new()
	rabid_wolf.card_owner = player
	player.deck_zone.add_card(rabid_wolf)
	var skoll := Skoll.new()
	skoll.card_owner = player
	player.deck_zone.add_card(skoll)
	var plan := bot._plan_creature_summon()
	if plan.get("command", {}).get("card_uid") != hand_creature.uid:
		failures.append("Bot chose Wolf Master over a stronger summon in hand")
	hand_creature.strength = 1
	plan = bot._plan_creature_summon()
	if plan.get("command", {}).get("lupine_uid") != rabid_wolf.uid:
		failures.append("Bot did not choose an affordable Wolf Master summon over a weaker hand summon")
	var valuable_body := CreatureCard.new()
	valuable_body.card_owner = player
	valuable_body.strength = 40
	valuable_body.level = fenrir.level
	player.frontline_zones[0].add_card(valuable_body)
	var fodder := CreatureCard.new()
	fodder.card_owner = player
	fodder.level = fenrir.level
	player.reserve_zones[0].add_card(fodder)
	plan = bot._plan_creature_summon()
	var command: Dictionary = plan.get("command", {})
	if command.get("type") != "wolf_master_summon" or command.get("lupine_uid") != skoll.uid \
			or command.get("sacrifice_uids", []) != [fodder.uid]:
		failures.append("Bot did not value Skoll with the cheaper Wolf Master sacrifice")
	elif not bot._submit_strategy_plan(plan) or not skoll.current_zone.is_board_zone() \
			or fenrir.current_zone != player.deck_zone or fodder.current_zone != player.graveyard_zone \
			or valuable_body.current_zone != player.frontline_zones[0] or not player.has_summoned_this_turn:
		failures.append("Wolf Master did not resolve with the planned recruit, sacrifice, and normal summon")
	bot.detach()

func _check_bot_aurboda_pierce(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var aurboda := Aurboda.new()
	aurboda.card_owner = opponent
	aurboda.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(aurboda)
	var attacker := CreatureCard.new()
	attacker.card_owner = player
	attacker.strength = aurboda.strength
	attacker.speed = aurboda.speed
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(attacker)
	player.guard = 10
	for followers in [6, 7, 8]:
		player.followers = followers
		var trades := bot._get_attack_candidates(attacker, null).filter(func(candidate: Dictionary) -> bool:
			return candidate["target"] == aurboda
		)
		if trades.is_empty():
			failures.append("Aurboda trade fixture did not produce a legal attack")
			break
		var result: Dictionary = trades[0]["base"]
		var converted := mini(followers, 7)
		if result["bot_followers_lost"] != converted or result.get("opponent_followers_gained") != converted \
				or result["bot_guard_spent"] != 0 or result["opponent_wins"] != (followers <= 7):
			failures.append("Bot misforecast Aurboda's Pierce in a trade at %d followers" % followers)
		if followers <= 7 and (not bot._plan_combat(trades).is_empty() or not bot._get_best_standard_attack([attacker], [aurboda]).is_empty()):
			failures.append("Bot planned a lethal trade into Aurboda at %d followers" % followers)
		if followers == 8:
			var later := bot._project_attack(trades[0], [], null, null, -1, {
				"bot_followers": 6, "opponent_followers": opponent.followers,
				"bot_guard": player.guard, "opponent_guard": opponent.guard,
			})
			if later.is_empty() or later["bot_followers_lost"] != 6 \
					or later.get("opponent_followers_gained") != 6 or not later["opponent_wins"]:
				failures.append("Bot did not recap Pierce against the followers remaining later in the combat line")
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.attacker = attacker
	action.target = aurboda
	player.guard = 0
	attacker.strength -= 1
	var loss := bot._estimate_attack_economy(action, null, 0, 0)
	if loss["bot_followers_lost"] != 8 or not loss["opponent_wins"]:
		failures.append("Bot missed lethal from combining combat damage with Aurboda's Pierce")
	aurboda.is_muted = true
	if bot._estimate_attack_economy(action, null, 0, 0)["bot_followers_lost"] != 1:
		failures.append("Bot forecast Pierce from a muted Aurboda")
	bot.detach()
	aurboda.is_muted = false
	player.followers = 6
	attacker.strength = aurboda.strength
	bot.attach(game, manager, ServerBotGameInput.new(manager, 1), 1)
	action.attacker = aurboda
	action.target = attacker
	var win := bot._estimate_attack_economy(action, null, 0, 0)
	if win["opponent_followers_lost"] != 6 or win.get("bot_followers_gained") != 6 or not win["bot_wins"]:
		failures.append("Bot missed lethal from its own Aurboda's Pierce")
	game.grant_turn_follower_loss_prevention(player)
	if bot._estimate_attack_economy(action, null, 0, 0)["opponent_followers_lost"] != 0:
		failures.append("Bot forecast Pierce through follower-loss prevention")
	bot.detach()

func _check_bot_hyena_stealth_attack(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 100
	opponent.followers = 100
	var pai_long := PaiLongAutumnKing.new()
	var hyena := HyenaPack.new()
	for attacker: Card in [pai_long, hyena]:
		attacker.card_owner = player
		attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(pai_long)
	player.frontline_zones[1].add_card(hyena)
	var hidden := BrownBear.new()
	hidden.card_owner = opponent
	hidden.is_face_down = true
	hidden.is_stealth = true
	hidden.creature_mode = Card.CreatureMode.DEFENSIVE
	hidden.resilience = 22
	opponent.frontline_zones[0].add_card(hidden)
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	if not bot._plan_scavenge_against_unknown_stealth().is_empty():
		failures.append("Bot planned a Scavenge attack with no packmates in the deck")
	var packmate := HyenaPack.new()
	packmate.card_owner = player
	player.deck_zone.add_card(packmate)
	var plan := bot._plan_scavenge_against_unknown_stealth()
	if plan.get("attacker") != hyena or plan.get("target") != hidden:
		failures.append("Bot passed up Scavenge against an unknown Stealth creature")
	hidden.resilience = 12
	if bot._plan_scavenge_against_unknown_stealth() != plan:
		failures.append("Bot used an unknown Stealth creature's resilience to plan Scavenge")
	if bot._take_main_phase_action():
		for _step in range(8):
			manager.advance_priority()
	if hidden.current_zone != opponent.graveyard_zone or packmate.current_zone not in player.frontline_zones:
		failures.append("Bot did not attack the Stealth creature with Hyena Pack ahead of Pai Long and trigger Scavenge")
	bot.detach()

func _check_bot_main_phase_combat_order(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var veteran := CreatureCard.new()
	veteran.card_owner = player
	veteran.strength = 20
	veteran.speed = 4
	veteran.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(veteran)
	var second_attacker := CreatureCard.new()
	second_attacker.card_owner = player
	second_attacker.strength = 10
	second_attacker.speed = 3
	second_attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[1].add_card(second_attacker)
	var recruit := CreatureCard.new()
	recruit.card_owner = player
	recruit.strength = 8
	recruit.speed = 3
	recruit.mana_cost = 1
	player.hand_zone.add_card(recruit)
	var wall := CreatureCard.new()
	wall.card_owner = player
	wall.strength = 0
	wall.resilience = 300
	wall.mana_cost = 1
	player.hand_zone.add_card(wall)
	var blocker := CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 18
	blocker.resilience = 12
	blocker.speed = 5
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	opponent.guard = 6
	var attacks := bot._get_combat_candidates()
	var baseline := bot._plan_combat(attacks)
	var summon := bot._plan_creature_summon(bot._forecast_incoming_follower_loss(), attacks, baseline)
	if summon.get("command", {}).get("card_uid") != wall.uid \
			or summon.get("attack_setup", {}).get("command", {}).get("card_uid") != recruit.uid:
		failures.append("Bot did not retain the attacking summon alongside the higher-value wall")
	opponent.followers = 14
	attacks = bot._get_combat_candidates()
	baseline = bot._plan_combat(attacks)
	var lethal_summon := bot._plan_creature_summon(bot._forecast_incoming_follower_loss(), attacks, baseline)
	if baseline.get("lethal", false) or not lethal_summon.get("attack_setup", {}).get("lethal", false):
		failures.append("Bot did not identify lethal that needs all three attacks and spends guard only once")
	opponent.followers = 100
	if not bot._take_main_phase_action() or recruit.current_zone not in player.frontline_zones \
			or recruit.creature_mode != Card.CreatureMode.AGGRESSIVE or game.has_resolved_attack_this_turn:
		failures.append("Bot attacked before summoning a third creature that could hit followers after the blocker fell")
	else:
		for _step in range(8):
			manager.advance_priority()
		var fight := bot._plan_combat(bot._get_combat_candidates())
		if fight.get("attacker") != veteran or fight.get("target") != blocker \
				or fight.get("attackers", []).size() != 3:
			failures.append("Bot did not use the stronger creature to clear the blocker after summoning")
		elif not bot._take_main_phase_action():
			failures.append("Bot did not submit the attack that clears the blocker")
		else:
			for _step in range(8):
				manager.advance_priority()
			var followers := opponent.followers
			var expected_damage := second_attacker.strength + recruit.strength - opponent.guard
			if blocker.current_zone != opponent.graveyard_zone:
				failures.append("Bot did not clear the blocker")
			else:
				for _attack in range(2):
					if not bot._take_main_phase_action():
						failures.append("Bot did not submit both follow-up attacks")
						break
					for _step in range(8):
						manager.advance_priority()
				if opponent.followers != followers - expected_damage:
					failures.append("Summoning first did not deliver both projected follow-up hits")
	bot.detach()

	game = _new_fixture_game()
	player = _new_fixture_player()
	opponent = _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	manager = _new_fixture_match(game)
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	recruit = CreatureCard.new()
	recruit.card_owner = player
	recruit.strength = 15
	recruit.resilience = 25
	recruit.mana_cost = 2
	player.hand_zone.add_card(recruit)
	blocker = CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 22
	blocker.speed = 5
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	var fall := FallOfTheMighty.new()
	fall.card_owner = player
	player.hand_zone.add_card(fall)
	if not bot._take_main_phase_action() or recruit.current_zone != player.hand_zone:
		failures.append("Bot summoned before Fall of the Mighty could clear the stronger creature")
	else:
		for _step in range(8):
			manager.advance_priority()
		if blocker.current_zone != opponent.graveyard_zone or not bot._take_main_phase_action() \
				or recruit.current_zone not in player.frontline_zones or recruit.creature_mode != Card.CreatureMode.AGGRESSIVE:
			failures.append("Bot did not follow Fall of the Mighty with a summon ready to attack")
	bot.detach()

	# A face-down prepared card cannot be a creature, so it must not veto the
	# Fall of the Mighty strength check (practice regressions hid Humbaba-scale
	# threats behind ordinary prepared hexes).
	game = _new_fixture_game()
	player = _new_fixture_player()
	opponent = _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	manager = _new_fixture_match(game)
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	recruit = CreatureCard.new()
	recruit.card_owner = player
	recruit.strength = 15
	recruit.resilience = 25
	recruit.mana_cost = 2
	player.hand_zone.add_card(recruit)
	blocker = CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 22
	blocker.speed = 5
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	fall = FallOfTheMighty.new()
	fall.card_owner = player
	player.hand_zone.add_card(fall)
	var prepared_hex := VoidShield.new()
	prepared_hex.card_owner = opponent
	prepared_hex.is_face_down = true
	prepared_hex.is_prepared = true
	opponent.reserve_zones[0].add_card(prepared_hex)
	if not bot._take_main_phase_action() or recruit.current_zone != player.hand_zone:
		failures.append("A face-down prepared card stopped Fall of the Mighty from clearing the stronger creature")
	else:
		for _step in range(8):
			manager.advance_priority()
		if blocker.current_zone != opponent.graveyard_zone:
			failures.append("Fall of the Mighty did not destroy the strongest creature behind a face-down prepared card")
	bot.detach()

	game = _new_fixture_game()
	player = _new_fixture_player()
	opponent = _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	manager = _new_fixture_match(game)
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	blocker = CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 22
	blocker.resilience = 25
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	fall = FallOfTheMighty.new()
	fall.card_owner = player
	player.hand_zone.add_card(fall)
	var unbound_score := BotCardStrategyScript.effect_score(bot, fall)
	var unbound_combat_value := bot._get_card_economic_value(blocker)
	blocker.add_status_effect("cannot_attack", "Preflight")
	var attack_locked_score := BotCardStrategyScript.effect_score(bot, fall)
	if bot._get_card_economic_value(blocker) >= unbound_combat_value:
		failures.append("Bot combat economy ignored an attack-locked creature")
	blocker.add_status_effect("cannot_intercept", "Preflight")
	blocker.add_status_effect(Card.ABILITY_NEGATED_STATUS, "Preflight")
	if BotCardStrategyScript.effect_score(bot, fall) >= attack_locked_score:
		failures.append("Bot ignored additional interception and ability debilitation")
	blocker.remove_status_effects_by_name("cannot_attack")
	blocker.remove_status_effects_by_name("cannot_intercept")
	blocker.remove_status_effects_by_name(Card.ABILITY_NEGATED_STATUS)
	var dromi := Dromi.new()
	dromi.card_owner = player
	player.reserve_zones[0].add_card(dromi)
	dromi.attached_target = blocker
	dromi.on_attached(game, blocker)
	var bound_score := BotCardStrategyScript.effect_score(bot, fall)
	if unbound_score <= 0 or attack_locked_score >= unbound_score or bound_score >= attack_locked_score:
		failures.append("Bot did not price generic attack loss and Dromi's additional follower drain separately")
	var bound_plan := bot._get_best_strategy_action([], {}, 0)
	if str(bound_plan.get("command", {}).get("spell_uid", "")) == fall.uid:
		failures.append("Bot spent Fall of the Mighty on its own Dromi-bound creature without a follow-up")
	blocker.remove_status_effects_from_source_card(dromi)
	dromi.attached_target = null
	blocker.add_status_effect("sleep", "Preflight")
	if BotCardStrategyScript.effect_score(bot, fall) >= unbound_score:
		failures.append("Bot ignored sleep when valuing removal of a debilitated creature")
	blocker.remove_status_effects_by_name("sleep")
	blocker.add_buff("Preflight Weakness", -10, -5, -2)
	if BotCardStrategyScript.effect_score(bot, fall) >= unbound_score:
		failures.append("Bot ignored weakened stats when valuing removal of a creature")
	blocker.clear_buffs_from("Preflight Weakness")
	blocker.add_status_effect(MalinalxochitlAcolyte.POISON_STATUS, "Preflight")
	if BotCardStrategyScript.effect_score(bot, fall) >= unbound_score:
		failures.append("Bot ignored ongoing poison when valuing removal of a creature")
	blocker.remove_status_effects_by_name(MalinalxochitlAcolyte.POISON_STATUS)
	blocker.mute_permanently(game)
	if BotCardStrategyScript.effect_score(bot, fall) >= unbound_score:
		failures.append("Bot ignored ability suppression when valuing removal of a debilitated creature")
	bot.detach()

func _check_bot_tablet_of_life_payoff(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	player.game_manager = game
	opponent.game_manager = game
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	opponent.followers = 20
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var tablet := TabletOfLife.new()
	tablet.card_owner = player
	player.hand_zone.add_card(tablet)
	var humbaba := HumbabaTheTerrible.new()
	humbaba.card_owner = player
	player.graveyard_zone.add_card(humbaba)
	var stone := WardingStone.new()
	stone.card_owner = opponent
	opponent.frontline_zones[0].add_card(stone)
	stone.on_summon(game)
	if not bot._get_best_strategy_action([], {}).is_empty():
		failures.append("Bot spent Tablet of Life on Humbaba with no payoff under Warding Stone")
	var demon := AsagTheDestroyer.new()
	demon.card_owner = player
	player.hand_zone.add_card(demon)
	var sacrifice: Dictionary = bot._get_best_strategy_action([], {}).get("command", {})
	if sacrifice.get("spell_uid") != tablet.uid or sacrifice.get("target_uid") != humbaba.uid:
		failures.append("Bot passed up Tablet of Life as sacrifice payment under Warding Stone")
	player.move_card(demon, player.abyss_zone)
	opponent.move_card(stone, opponent.graveyard_zone)
	var command: Dictionary = bot._get_best_strategy_action([], {}).get("command", {})
	if command.get("spell_uid") != tablet.uid or command.get("target_uid") != humbaba.uid:
		failures.append("Bot passed up a lethal Tablet of Life attack once Warding Stone was gone")
	game.has_resolved_attack_this_turn = true
	if not bot._get_best_strategy_action([], {}).is_empty():
		failures.append("Bot spent Tablet of Life on Humbaba after the first attack resolved")
	bot.detach()

func _check_bot_conjure_eidolon(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	player.game_manager = game
	opponent.game_manager = game
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 3
	opponent.followers = 20
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var spell := ConjureEidolon.new()
	spell.card_owner = player
	player.hand_zone.add_card(spell)
	var weak := CreatureCard.new()
	weak.card_owner = player
	weak.strength = 5
	weak.creature_major_action_used = true
	player.reserve_zones[0].add_card(weak)
	weak.add_buff("Fixture buff", 30, 0, 0)
	var strong := CreatureCard.new()
	strong.card_owner = player
	strong.card_name = "Fixture Warrior"
	strong.card_types = ["Warrior"]
	strong.strength = 21
	strong.creature_major_action_used = true
	player.reserve_zones[1].add_card(strong)
	var spirit := CreatureCard.new()
	spirit.card_owner = player
	spirit.card_types = ["Spirit"]
	spirit.strength = 40
	spirit.creature_major_action_used = true
	player.reserve_zones[2].add_card(spirit)
	var plan := bot._get_best_strategy_action([], {})
	if not plan.get("lethal", false) or plan.get("command", {}).get("target_uid") != strong.uid:
		failures.append("Bot did not choose the legal Eidolon copy with a lethal printed stat line")
	elif bot._take_main_phase_action():
		for _step in range(8):
			manager.advance_priority()
		var eidolon: Card = player.frontline_zones[0].cards.front() if not player.frontline_zones[0].cards.is_empty() else null
		if eidolon == null or eidolon.card_name != strong.card_name + " Eidolon" or not eidolon.is_silenced():
			failures.append("Bot did not resolve the planned Eidolon cast")
		else:
			opponent.followers = 100
			var attack := CardAction.new()
			attack.type = CardAction.Type.ATTACK
			attack.attacker = eidolon
			attack.target = opponent
			var outcome := bot._estimate_projected_attack_economy(attack, {})
			if eidolon not in outcome["casualties"] or int(outcome["opponent_followers_lost"]) != eidolon.strength:
				failures.append("Bot did not forecast the Eidolon expiring after direct follower damage")
			if bot._take_main_phase_action():
				for _step in range(8):
					manager.advance_priority()
			if opponent.followers != 100 - strong.strength or eidolon.current_zone != null:
				failures.append("Bot did not follow through with the Eidolon's direct attack")
	else:
		failures.append("Bot did not cast Conjure Eidolon before combat")
	bot.detach()

func _check_bot_removal_opens_attacks(failures: PackedStringArray) -> void:
	for use_spell in [true, false]:
		var game := _new_fixture_game()
		var player := _new_fixture_player()
		var opponent := _new_fixture_player()
		game.players.assign([player, opponent])
		game.current_player = player
		game.other_player = opponent
		game.turn_number = 3
		game._upkeep_resolved_turn = game.turn_number
		player.mana = 5
		opponent.followers = 37
		var manager := _new_fixture_match(game)
		var bot := _new_fixture_bot()
		bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
		for strength in [21, 8, 8]:
			var attacker := CreatureCard.new()
			attacker.card_owner = player
			attacker.strength = strength
			attacker.speed = 3
			attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
			bot._get_first_open_summon_zone(player).add_card(attacker)
		var blocker := CreatureCard.new()
		blocker.card_owner = opponent
		blocker.strength = 20
		blocker.resilience = 5
		blocker.speed = 5
		blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
		opponent.frontline_zones[0].add_card(blocker)
		@warning_ignore("incompatible_ternary")
		var removal: Card = BitMeseri.new() if use_spell else AncientPyre.new()
		removal.card_owner = player
		var source_zone := player.hand_zone if use_spell else player.frontline_zones[4]
		source_zone.add_card(removal)
		var attacks := bot._get_combat_candidates()
		var baseline := bot._plan_combat(attacks)
		var plan := bot._get_best_strategy_action(attacks, baseline)
		if baseline.get("lethal", false) or not plan.get("lethal", false) or not bot._take_main_phase_action():
			failures.append("Bot missed the lethal line opened by %s" % removal.card_name)
			bot.detach()
			continue
		for _step in range(8):
			manager.advance_priority()
		if blocker.current_zone.is_board_zone() or game.has_resolved_attack_this_turn:
			failures.append("Bot attacked before clearing the blocker with %s" % removal.card_name)
			bot.detach()
			continue
		for _attack in range(3):
			if not bot._take_main_phase_action():
				break
			for _step in range(8):
				manager.advance_priority()
		if opponent.followers > 0:
			failures.append("Bot did not use all three attackers after %s cleared the blocker" % removal.card_name)
		bot.detach()

func _check_bot_paired_removals(failures: PackedStringArray) -> void:
	for scenario in ["lethal", "economy", "barriers"]:
		var lethal_case: bool = scenario != "economy"
		var game := _new_fixture_game()
		var player := _new_fixture_player()
		var opponent := _new_fixture_player()
		game.players.assign([player, opponent])
		game.current_player = player
		game.other_player = opponent
		game.turn_number = 3
		game._upkeep_resolved_turn = game.turn_number
		player.mana = 6
		opponent.followers = 39 if lethal_case else 100
		var manager := _new_fixture_match(game)
		var bot := _new_fixture_bot()
		bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
		var strengths := [23, 8, 8]
		for index in range(strengths.size()):
			var attacker := CreatureCard.new()
			attacker.card_owner = player
			attacker.strength = strengths[index]
			attacker.speed = 3
			attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
			player.frontline_zones[index].add_card(attacker)
		for index in range(2):
			@warning_ignore("incompatible_ternary")
			var blocker: Card = PalisadeBarrier.new() if scenario == "barriers" else CreatureCard.new()
			blocker.card_owner = opponent
			var zone := opponent.frontline_zones[index]
			if scenario == "barriers":
				if index == 1:
					zone = opponent.reserve_zones[0]
			else:
				blocker.strength = 20
				blocker.speed = 5
				blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
			zone.add_card(blocker)
			var removal := BitMeseri.new()
			removal.card_owner = player
			player.hand_zone.add_card(removal)
		var attacks := bot._get_combat_candidates()
		var baseline := bot._plan_combat(attacks)
		var removals: Array[Dictionary] = []
		var danger := bot._forecast_incoming_follower_loss()
		var single := bot._get_best_strategy_action(attacks, baseline, danger, removals)
		var pair := bot._plan_paired_removals(removals, attacks, baseline, danger)
		if lethal_case:
			if single.get("lethal", false) or not pair.get("lethal", false):
				failures.append("Bot did not find lethal that requires both removal spells")
			player.mana = 5
			if not bot._plan_paired_removals(removals, attacks, baseline, danger).is_empty():
				failures.append("Bot projected two removal spells without enough mana for both")
			player.mana = 6
		elif int(single.get("score", 0)) <= int(pair.get("score", 0)):
			failures.append("Bot valued the second removal above a profitable combat clear")
		for _action in range(2):
			if not bot._take_main_phase_action():
				failures.append("Bot did not submit both parts of the multi-defender plan")
				break
			for _step in range(8):
				manager.advance_priority()
		var remaining_cards := 0 if lethal_case else 1
		if player.hand_zone.cards.size() != remaining_cards or not bot._get_board_creatures(opponent).is_empty() \
				or game.has_resolved_attack_this_turn == lethal_case:
			failures.append("Bot did not choose the expected removal or combat sequence against two defenders")
		if lethal_case:
			for _attack in range(3):
				if not bot._take_main_phase_action():
					break
				for _step in range(8):
					manager.advance_priority()
			if opponent.followers > 0:
				failures.append("Bot did not use all three follower attacks after the two removal spells")
		bot.detach()

func _check_bot_summon_and_removal_order(failures: PackedStringArray) -> void:
	for summon_first in [false, true]:
		var game := _new_fixture_game()
		var player := _new_fixture_player()
		var opponent := _new_fixture_player()
		game.players.assign([player, opponent])
		game.current_player = player
		game.other_player = opponent
		game.turn_number = 3
		game._upkeep_resolved_turn = game.turn_number
		player.mana = 5
		opponent.followers = 16
		var manager := _new_fixture_match(game)
		var bot := _new_fixture_bot()
		bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
		var attacker_count := 2 if summon_first else 1
		for index in range(attacker_count):
			var attacker := CreatureCard.new()
			attacker.card_owner = player
			attacker.strength = 8
			attacker.speed = 3
			attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
			player.frontline_zones[index].add_card(attacker)
		var blocker := CreatureCard.new()
		blocker.card_owner = opponent
		blocker.level = 1
		blocker.strength = 20
		blocker.resilience = 5
		blocker.speed = 5
		blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
		opponent.frontline_zones[0].add_card(blocker)
		var recruit: Card = Lindwyrm.new() if summon_first else CreatureCard.new()
		recruit.card_owner = player
		if not summon_first:
			recruit.strength = 8
			recruit.speed = 3
			recruit.mana_cost = 1
		player.hand_zone.add_card(recruit)
		var bit_meseri := BitMeseri.new()
		if summon_first:
			bit_meseri.card_owner = player
			player.hand_zone.add_card(bit_meseri)
		else:
			var pyre := AncientPyre.new()
			pyre.card_owner = player
			player.frontline_zones[4].add_card(pyre)
		if not bot._take_main_phase_action():
			failures.append("Bot had no first action for a summon and removal combination")
			bot.detach()
			continue
		for _step in range(8):
			manager.advance_priority()
		if recruit.current_zone.is_board_zone() != summon_first or blocker.current_zone.is_board_zone() != summon_first:
			failures.append("Bot chose the wrong order for the summon and removal combination")
			bot.detach()
			continue
		if not bot._take_main_phase_action():
			failures.append("Bot did not complete the summon and removal setup")
			bot.detach()
			continue
		for _step in range(8):
			manager.advance_priority()
		if not recruit.current_zone.is_board_zone() or blocker.current_zone.is_board_zone() or game.has_resolved_attack_this_turn:
			failures.append("Bot did not complete both setup actions before attacking")
		for _attack in range(2):
			if not bot._take_main_phase_action():
				break
			for _step in range(8):
				manager.advance_priority()
		if opponent.followers > 0 or (summon_first and bit_meseri.current_zone != player.hand_zone):
			failures.append("Bot missed the two attacks opened by the setup or spent the spell unnecessarily")
		bot.detach()

func _check_bot_removal_threat_priority(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = opponent
	game.other_player = player
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 2
	player.followers = 100
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var entrant := CreatureCard.new()
	entrant.card_owner = opponent
	entrant.mana_cost = 2
	entrant.strength = 16
	entrant.resilience = 14
	entrant.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(entrant)
	var sap := Sap.new()
	sap.card_owner = player
	sap.is_prepared = true
	sap.is_face_down = true
	player.reserve_zones[0].add_card(sap)
	game.prepared_hexes[sap] = game.turn_number - 1
	var entry := CardAction.new()
	entry.type = CardAction.Type.EVENT
	entry.event_name = "frontline_entry"
	entry.source_player = opponent
	entry.card = entrant
	game.push_to_stack(entry)
	if bot._choose_priority_response() != sap:
		failures.append("Bot passed on a worthwhile Sap target without a combat answer")
	var recruit := CreatureCard.new()
	recruit.card_owner = player
	recruit.mana_cost = 2
	recruit.strength = 20
	recruit.resilience = 18
	player.hand_zone.add_card(recruit)
	bot._mana_econ_cache = {}
	if bot._choose_priority_response() != null:
		failures.append("Bot spent Sap with healthy followers and a clean summon-and-attack answer")
	player.followers = entrant.strength
	if bot._choose_priority_response() != sap:
		failures.append("Bot saved Sap despite a lethal attack before it could summon its answer")
	game.action_stack.clear()
	game.current_player = player
	game.other_player = opponent
	player.followers = 100
	var fall := FallOfTheMighty.new()
	fall.card_owner = player
	player.hand_zone.add_card(fall)
	bot._mana_econ_cache = {}
	bot._take_main_phase_action()
	if recruit.current_zone not in player.frontline_zones or fall.current_zone != player.hand_zone:
		failures.append("Bot did not favor a clean summon-and-attack over Fall of the Mighty")

func _check_bot_disable_overlap(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	var manager := _new_fixture_match(game)
	var bot := ThorPracticeBot.new()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)

	var target := Alu.new()
	target.card_owner = opponent
	opponent.frontline_zones[0].add_card(target)
	var alu := Alu.new()
	alu.card_owner = player
	var gleipnir := Gleipnir.new()
	gleipnir.card_owner = player
	var awake_score := BotCardStrategyScript.target_score(bot, alu, target)
	var awake_binding := BotCardStrategyScript.target_score(bot, gleipnir, target)
	target.add_status_effect("sleep", "Preflight", null, null, {"expires_turn": game.turn_number})
	var short_sleep := BotCardStrategyScript.target_score(bot, alu, target)
	target.remove_status_effects_by_name("sleep")
	target.add_status_effect("sleep", "Preflight", null, null, {"expires_turn": game.turn_number + 2})
	var long_sleep := BotCardStrategyScript.target_score(bot, alu, target)
	target.apply_sleep(alu)
	var permanent_sleep := BotCardStrategyScript.target_score(bot, alu, target)
	if awake_score <= short_sleep or short_sleep <= long_sleep or long_sleep <= 0 or permanent_sleep != 0:
		failures.append("Bot did not value only the sleep duration Alu adds")
	var sleeping_binding := BotCardStrategyScript.target_score(bot, gleipnir, target)
	target.mute_permanently(game)
	if sleeping_binding <= 0 or sleeping_binding >= awake_binding or BotCardStrategyScript.target_score(bot, gleipnir, target) != 0:
		failures.append("Bot did not score Gleipnir's ability suppression independently of sleep")

	var adapa := FirstSageAdapa.new()
	adapa.card_owner = player
	player.frontline_zones[0].add_card(adapa)
	var renewing := BerserkerMead.new()
	renewing.card_owner = opponent
	opponent.power_zones[0].add_card(renewing)
	var fresh := ManaGuard.new()
	fresh.card_owner = opponent
	opponent.power_zones[1].add_card(fresh)
	var prompt := {"source_uid": adapa.uid, "target_uids": [renewing.uid, fresh.uid]}
	renewing.mute_for_turns(1, game)
	var extended := BotCardStrategyScript.mute_gain(bot, renewing, FirstSageAdapa.MUTE_DURATION, 5000)
	var choice := BotCardPromptPolicy.build_command(bot, "first_sage_adapa_impact", prompt)
	renewing.mute_for_turns(Absence.MUTE_DURATION, game)
	fresh.mute_permanently(game)
	var redundant := BotCardPromptPolicy.build_command(bot, "first_sage_adapa_impact", prompt)
	if extended <= 0 or extended >= 5000 or choice.get("target_uid") != fresh.uid or redundant.get("target_uid") != "":
		failures.append("Bot did not prefer a fresh mute and skip mutes that add no duration")

func _check_bot_defender_target_value(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	opponent.mana = AgainWalker.RESURRECTION_COST
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var attacker := CreatureCard.new()
	attacker.card_owner = player
	attacker.strength = 19
	attacker.speed = 1
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(attacker)
	var walker := AgainWalker.new()
	walker.card_owner = opponent
	walker.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[0].add_card(walker)
	var priest := EnHeduAnna.new()
	priest.card_owner = opponent
	priest.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[1].add_card(priest)
	var plan := bot._plan_combat(bot._get_combat_candidates())
	var fallback := bot._get_best_standard_attack([attacker], [walker, priest])
	if plan.get("target") != priest or fallback.get("target") != priest:
		failures.append("Bot preferred a resurrectable Again-Walker to permanently removing En-hedu-anna")

	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.attacker = attacker
	action.target = walker
	walker.creature_mode = Card.CreatureMode.AGGRESSIVE
	var returning := bot._estimate_attack_economy(action, null, 0, 0)
	if walker not in returning.get("returning_casualties", []) or walker not in returning["casualties"] \
			or int(returning["opponent_followers_lost"]) != attacker.strength - walker.strength:
		failures.append("Bot lost the immediate combat benefits of slaying a resurrectable Again-Walker")
	var followers := opponent.followers
	opponent.followers = attacker.strength - walker.strength
	if bot._plan_combat(bot._get_combat_candidates()).get("target") != walker:
		failures.append("Bot passed up lethal follower damage against a resurrectable Again-Walker")
	opponent.followers = followers
	opponent.mana = 0
	var permanent := bot._estimate_attack_economy(action, null, 0, 0)
	if walker in permanent.get("returning_casualties", []) or int(permanent["opponent_cards_lost"]) <= int(returning["opponent_cards_lost"]):
		failures.append("Bot discounted an Again-Walker that could not afford to resurrect")
	opponent.mana = AgainWalker.RESURRECTION_COST
	for zone in opponent.reserve_zones:
		var blocker := CreatureCard.new()
		blocker.card_owner = opponent
		zone.add_card(blocker)
	var full_reserve := bot._estimate_attack_economy(action, null, 0, 0)
	if walker in full_reserve.get("returning_casualties", []):
		failures.append("Bot forecast a frontline Again-Walker resurrecting into a full reserve")
	var asag := AsagTheDestroyer.new()
	asag.card_owner = player
	player.reserve_zones[0].add_card(asag)
	action.attacker = asag
	var reserve: Zone = opponent.reserve_zones[0]
	reserve.remove_card(reserve.cards[0])
	var voided := bot._estimate_attack_economy(action, null, 0, 0)
	if walker in voided.get("returning_casualties", []) or int(voided["opponent_cards_lost"]) != int(permanent["opponent_cards_lost"]):
		failures.append("Bot discounted an Again-Walker sent to the Abyss by Class Rend")
	action.attacker = attacker
	opponent.move_card(walker, reserve)
	var vacated_reserve := bot._estimate_attack_economy(action, null, 0, 0)
	if walker not in vacated_reserve.get("returning_casualties", []):
		failures.append("Bot missed that Again-Walker could return to its own vacated reserve slot")
	bot.detach()

func _check_bot_hermes_speed(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 2
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var hermes := Hermes.new()
	hermes.card_owner = player
	player.god_zone.add_card(hermes)
	var attacker := CreatureCard.new()
	attacker.card_owner = player
	attacker.strength = 20
	attacker.speed = 2
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(attacker)
	var blocker := CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 8
	blocker.speed = 3
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	var attacks := bot._get_combat_candidates()
	if not bot._plan_hermes_speed(attacks, bot._plan_combat(attacks)).is_empty():
		failures.append("Hermes paid for a faster follower attack when the unbuffed frontline attack was already better")
	var shield := VoidShield.new()
	shield.card_owner = opponent
	shield.is_face_down = true
	shield.is_prepared = true
	opponent.reserve_zones[0].add_card(shield)
	game.prepared_hexes[shield] = game.turn_number - 1
	attacks = bot._get_combat_candidates()
	if not bot._plan_hermes_speed(attacks, bot._plan_combat(attacks)).is_empty():
		failures.append("Hermes used private information to outrun an unidentified prepared card")
	shield.add_status_effect("publicly_revealed", "Preflight")
	attacks = bot._get_combat_candidates()
	var speed_plan := bot._plan_hermes_speed(attacks, bot._plan_combat(attacks))
	if speed_plan.get("command", {}).get("target_uid") != attacker.uid:
		failures.append("Hermes did not outrun a known Void Shield when that improved the attack line")
	attacker.speed = 4
	attacks = bot._get_combat_candidates()
	if not bot._plan_hermes_speed(attacks, bot._plan_combat(attacks)).is_empty():
		failures.append("Hermes paid for speed even though the attacker already outran Void Shield")

	var psychopompus := HermesPsychopompus.new()
	psychopompus.card_owner = player
	player.god_zone.remove_card(hermes)
	player.god_zone.add_card(psychopompus)
	player.mana = 4
	var ghost := Edimmu.new()
	ghost.card_owner = player
	player.deck_zone.add_card(ghost)
	var discard := CreatureCard.new()
	discard.card_owner = player
	player.hand_zone.add_card(discard)
	var summon := bot._plan_deck_god_ability(0)
	if not bot._submit_strategy_plan(summon):
		failures.append("Hermes Psychopompos did not submit Call of the Crossing")
	for _step in range(8):
		manager.advance_priority()
	if ghost.current_zone not in player.frontline_zones or ghost.creature_mode != Card.CreatureMode.AGGRESSIVE \
			or discard.current_zone != player.graveyard_zone or player.mana != 4:
		failures.append("Call of the Crossing did not summon the bot's chosen Ghost for one hand discard")

	attacker.speed = 2
	opponent.followers = 15
	for _ghost_index in range(2):
		var buried_ghost := Edimmu.new()
		buried_ghost.card_owner = player
		player.graveyard_zone.add_card(buried_ghost)
	if not bot._take_main_phase_action():
		failures.append("Hermes Psychopompos did not submit Wings of the Departed to outrun Void Shield")
	for _step in range(8):
		manager.advance_priority()
	if attacker.get_effective_speed() != 4 or player.mana != 2:
		failures.append("Wings of the Departed did not give the bot's attacker the required +2 Speed for 2 mana")
	bot.detach()

func _check_aspect_shift(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 8
	var manager := _new_fixture_match(game)
	var hermes := Hermes.new()
	hermes.card_owner = player
	hermes._last_used_turn = game.turn_number
	player.god_zone.add_card(hermes)
	var shift := AspectShift.new()
	shift.card_owner = player
	player.power_zones[0].add_card(shift)
	if not manager.process_command({"type": "unlock_power", "power_uid": shift.uid}) \
			or not (player.god_zone.cards[0] is HermesPsychopompus) or player.mana != 4:
		failures.append("Aspect Shift did not unlock and shift Hermes for 4 mana")
		return
	GameState.apply_to_manager(GameState.serialize(game), game)
	var restored_power := game.get_card_by_uid(shift.uid) as AspectShift
	if restored_power == null or not manager.process_command({"type": "activate_power", "power_uid": restored_power.uid}):
		failures.append("Aspect Shift could not shift back after a game-state round trip")
		return
	for _step in range(8):
		manager.advance_priority()
	var restored_hermes := game.get_card_by_uid(hermes.uid) as Hermes
	if restored_hermes == null or restored_hermes.current_zone != player.god_zone \
			or restored_hermes._last_used_turn != game.turn_number or player.mana != 0 or not restored_power.is_face_down:
		failures.append("Aspect Shift did not restore the original Hermes and relock for 4 mana")

func _check_aphrodite_aspect_shift(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 20
	player.followers = 10
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var areia := AphroditeAreia.new()
	areia.card_owner = player
	player.god_zone.add_card(areia)
	var power := AspectShift.new()
	power.card_owner = player
	player.power_zones[0].add_card(power)
	var defender := SulakTheUnclean.new()
	defender.card_owner = player
	defender.speed = 4
	defender.resilience = 30
	defender.creature_mode = Card.CreatureMode.DEFENSIVE
	defender.is_stealth = true
	defender.is_face_down = true
	player.reserve_zones[0].add_card(defender)
	var enemy := CreatureCard.new()
	enemy.card_owner = opponent
	enemy.speed = 6
	enemy.strength = 20
	enemy.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(enemy)
	var danger := bot._forecast_incoming_follower_loss()
	var shift := bot._plan_aspect_shift([], {}, danger, {}, player.mana)
	# Hiding no longer costs Speed, so only Veil of Night lets the hidden body
	# intercept this faster attack.
	if defender.get_effective_speed() != 4 or manager._can_intercept(defender, enemy, player) \
			or danger != player.followers \
			or shift.get("command", {}).get("type") != "unlock_power" \
			or player.god_zone.cards[0] != areia or not bot._take_main_phase_action():
		failures.append("Bot did not shift Aphrodite to let a hidden defender intercept a lethal attack")
		return
	var skotia := player.god_zone.cards[0] as AphroditeSkotia
	if skotia == null or not manager._can_intercept(defender, enemy, player) or player.mana != 16:
		failures.append("Veil of Night did not let a hidden defender intercept a faster attack")
		return
	var recruit := CreatureCard.new()
	recruit.card_owner = player
	recruit.speed = 4
	if not bot._should_summon_creature_stealthily(recruit, player.reserve_zones[1], Card.CreatureMode.DEFENSIVE) \
			or not bot._should_summon_creature_stealthily(defender, player.reserve_zones[1], Card.CreatureMode.DEFENSIVE):
		failures.append("Bot did not hide Reveal-trigger bodies under Veil of Night")
	skotia.is_muted = true
	if manager._can_intercept(defender, enemy, player) or not defender.will_reveal_in_combat():
		failures.append("Muting Aphrodite Skotia did not suppress Veil of Night")
	skotia.is_muted = false
	game._begin_declared_combat(enemy, defender)
	var visible_to_opponent: Dictionary = GameState.serialize(game, 1)["players"][0]["reserve_zones"][0][0]
	if defender.get_combat_log_display_name(opponent) == defender.card_name or not visible_to_opponent.get("hidden", false):
		failures.append("A creature under Veil of Night leaked its identity during combat")
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = opponent
	attack.attacker = enemy
	attack.target = player
	attack.interceptor = defender
	manager._resolve_attack(attack)
	if not defender.is_stealth or not defender.is_face_down or defender.get_effective_strength() != defender.strength \
			or defender.card_name in manager.last_resolution_text:
		failures.append("A hidden defender revealed or triggered its Reveal ability under Veil of Night")
	if not defender.is_combat_resilience_inferable() \
			or "RES %d" % defender.get_effective_resilience() not in defender.get_public_combat_log_display_name():
		failures.append("A Veil of Night defender did not expose its inferable Resilience after combat")
	var outside_reveal := SulakTheUnclean.new()
	outside_reveal.card_owner = player
	outside_reveal.is_stealth = true
	outside_reveal.is_face_down = true
	player.reserve_zones[1].add_card(outside_reveal)
	outside_reveal.reveal_from_stealth(game)
	if outside_reveal.is_stealth or outside_reveal.get_effective_strength() <= outside_reveal.strength:
		failures.append("Veil of Night blocked a reveal outside combat")
	defender.clear_buffs_from(SulakTheUnclean.SURPRISE_BUFF_SOURCE)
	var attacker := CreatureCard.new()
	attacker.card_owner = player
	attacker.strength = 20
	attacker.is_stealth = true
	attacker.is_face_down = true
	attacker.creature_mode = Card.CreatureMode.DEFENSIVE
	player.frontline_zones[0].add_card(attacker)
	var victim := CreatureCard.new()
	victim.card_owner = opponent
	victim.resilience = 1
	victim.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[1].add_card(victim)
	game.creature_attack(attacker, victim)
	# Attacking from stealth is the sequential line: the switch to Aggressive
	# stance is a Minor Action that reveals the creature before combat, so the
	# veil never conceals an attacker — only hidden defenders stay concealed.
	if attacker.is_stealth or attacker.is_face_down or attacker.creature_mode != Card.CreatureMode.AGGRESSIVE \
			or victim.current_zone != opponent.graveyard_zone:
		failures.append("A stealth attack did not reveal through the Aggressive stance switch before combat")
	player.followers = 100
	GameState.apply_to_manager(GameState.serialize(game), game)
	danger = bot._forecast_incoming_follower_loss()
	shift = bot._plan_aspect_shift([], {}, danger, {}, player.mana)
	if shift.get("command", {}).get("type") != "activate_power" or not bot._take_main_phase_action():
		failures.append("Bot did not restore Aphrodite Areia for a qualifying Violent Delights capture")
		return
	for _step in range(8):
		manager.advance_priority()
	var restored_power := game.get_card_by_uid(power.uid) as AspectShift
	var restored_attacker := game.get_card_by_uid(attacker.uid)
	if not player.god_zone.cards[0] is AphroditeAreia or restored_power == null or not restored_power.is_face_down \
			or restored_attacker == null or not defender.will_reveal_in_combat() or player.mana != 12:
		failures.append("Aspect Shift did not restore Aphrodite Areia and end Veil of Night after a state round trip")
		return
	var capture_target := game.get_card_by_uid(enemy.uid)
	if capture_target == null or not bot._take_main_phase_action():
		failures.append("Bot did not follow the shift with Violent Delights")
		return
	for _step in range(8):
		manager.advance_priority()
	if capture_target.get_controller() != player or not capture_target.is_enslaved() \
			or player.mana != 12 - AphroditeAreia.ACTIVATION_COST:
		failures.append("Violent Delights did not capture the attacker after the shift")

func _check_bot_aspect_shift(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 5
	opponent.followers = 8
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var hermes := Hermes.new()
	hermes.card_owner = player
	player.god_zone.add_card(hermes)
	var power := AspectShift.new()
	power.card_owner = player
	player.power_zones[0].add_card(power)
	var ghost := Edimmu.new()
	ghost.card_owner = player
	player.deck_zone.add_card(ghost)
	if not bot._plan_aspect_shift([], {}, 0, {}, player.mana).is_empty():
		failures.append("Bot planned to shift without a hand card to discard for its Ghost")
	var discard := CreatureCard.new()
	discard.card_owner = player
	player.hand_zone.add_card(discard)
	player.mana = 6
	if not bot._take_main_phase_action() or not (player.god_zone.cards[0] is HermesPsychopompus):
		failures.append("Bot did not unlock Aspect Shift for a lethal Ghost summon")
	elif not bot._take_main_phase_action():
		failures.append("Bot did not follow through with Call of the Crossing after shifting")
	for _step in range(8):
		manager.advance_priority()
	if ghost.current_zone not in player.frontline_zones or discard.current_zone != player.graveyard_zone or player.mana != 2:
		failures.append("Shifting and discarding for the bot's Ghost did not resolve for the 4-mana unlock")

	# Empty graveyard means the Hades aspect cannot outrun the prepared shield.
	player.mana = 6
	opponent.followers = 15
	var attacker := CreatureCard.new()
	attacker.card_owner = player
	attacker.strength = 20
	attacker.speed = 2
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(attacker)
	var blocker := CreatureCard.new()
	blocker.card_owner = opponent
	blocker.strength = 8
	blocker.speed = 3
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(blocker)
	var shield := VoidShield.new()
	shield.card_owner = opponent
	shield.is_face_down = true
	shield.is_prepared = true
	opponent.reserve_zones[0].add_card(shield)
	game.prepared_hexes[shield] = game.turn_number - 1
	shield.add_status_effect("publicly_revealed", "Preflight")
	var attacks := bot._get_combat_candidates()
	var baseline := bot._plan_combat(attacks)
	hermes._last_used_turn = game.turn_number
	if not bot._plan_aspect_shift(attacks, baseline, 0, {}, player.mana).is_empty():
		failures.append("Bot planned to return to Hermes for an ability he had already used this turn")
	hermes._last_used_turn = -1
	if not bot._take_main_phase_action():
		failures.append("Bot did not shift back for the lethal Deceptive Speed line")
	for _step in range(8):
		manager.advance_priority()
	if hermes.current_zone != player.god_zone or not power.is_face_down or player.mana != 2:
		failures.append("Bot did not return to the original Hermes and relock Aspect Shift")
	elif not bot._take_main_phase_action():
		failures.append("Bot did not follow through with Deceptive Speed after returning to Hermes")
	for _step in range(8):
		manager.advance_priority()
	if attacker.get_effective_speed() != 5 or player.mana != 0:
		failures.append("Returning to Hermes did not produce the planned speed boost")

	attacker.remove_buffs_from_source_card(hermes, Hermes.BUFF_EFFECT_TYPE)
	player.mana = 6
	for _ghost_index in range(2):
		var buried_ghost := Edimmu.new()
		buried_ghost.card_owner = player
		player.graveyard_zone.add_card(buried_ghost)
	attacks = bot._get_combat_candidates()
	baseline = bot._plan_combat(attacks)
	hermes._last_used_turn = -1
	var normal_speed := bot._plan_hermes_speed(attacks, baseline)
	if not bot._plan_aspect_shift(attacks, baseline, 0, normal_speed, player.mana).is_empty():
		failures.append("Bot paid to shift when normal Hermes already had a lethal speed boost")
	hermes._last_used_turn = game.turn_number
	if not bot._take_main_phase_action() or not (player.god_zone.cards[0] is HermesPsychopompus) \
			or not bot._take_main_phase_action():
		failures.append("Bot did not shift and follow through with Wings of the Departed")
	for _step in range(8):
		manager.advance_priority()
	if attacker.get_effective_speed() != 4 or player.mana != 0:
		failures.append("Shifting for Wings of the Departed did not produce the planned speed boost")
	bot.detach()

func _check_bot_call_of_the_crossing_safety(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.setup_game()
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 5
	var hermes := Hermes.new()
	hermes.card_owner = player
	player.god_zone.add_card(hermes)
	var shift := AspectShift.new()
	shift.card_owner = player
	player.power_zones[0].add_card(shift)
	var ghost := Edimmu.new()
	ghost.card_owner = player
	player.deck_zone.add_card(ghost)
	var discard := CreatureCard.new()
	discard.card_owner = player
	player.hand_zone.add_card(discard)
	var sap := Sap.new()
	sap.card_owner = player
	sap.is_face_down = true
	sap.is_prepared = true
	player.reserve_zones[0].add_card(sap)
	game.prepared_hexes[sap] = game.turn_number - 1
	var thor := Thor.new()
	thor.card_owner = opponent
	opponent.god_zone.add_card(thor)
	opponent.mana = ThorActive.new().mana_cost
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	player.mana = shift.get_unlock_mana_cost(game)
	var danger := bot._forecast_incoming_follower_loss()
	if danger != 0 or bot._forecast_incoming_follower_loss({"mana_left": 0}) < player.followers:
		failures.append("Call of the Crossing fixture did not have a lethal Champion's Call stopped by Sap")
	elif not bot._plan_aspect_shift([], {}, danger, {}, player.mana).is_empty():
		failures.append("Bot planned to shift and summon without leaving mana for Sap against Champion's Call")
	player.mana += game.get_prepared_card_activation_mana_cost(player, sap)
	# Already Psychopompus: the summon costs no mana, only a hand discard, so it is
	# worth taking even while keeping Sap's mana reserved against Champion's Call.
	var crossing := shift.make_hades_aspect() as HermesPsychopompus
	var funded := bot._plan_call_of_the_crossing(crossing, bot._forecast_incoming_follower_loss(), [], {}, player.mana)
	if funded.get("command", {}).get("ghost_uid") != ghost.uid:
		failures.append("Bot passed up Call of the Crossing with mana left for Sap against Champion's Call")

	var sap_cost := game.get_prepared_card_activation_mana_cost(player, sap)
	var mead := MeadOfPoetry.new()
	mead.card_owner = player
	mead.is_prepared = true
	mead.is_face_down = true
	player.reserve_zones[2].add_card(mead)
	game.prepared_charms[mead] = game.turn_number - 1
	player.mana -= sap_cost
	if bot._ready_brew_mana_gain() <= 0 or not bot._plan_aspect_shift([], {}, 0, {}, player.mana + MeadOfPoetry.MANA_GAIN).is_empty():
		failures.append("Call of the Crossing counted Mead without planning to brew it")
	game.prepared_charms.erase(mead)
	player.reserve_zones[2].remove_card(mead)
	player.mana = sap_cost
	var setup := {"score": BotCardStrategyScript.CARD_VALUE}
	var unsafe_setup := bot._plan_removal_setup(setup, [], {}, 0, [], sap_cost, null, false)
	var safe_setup := bot._plan_removal_setup(setup, [], {}, 0, [], 0, null, false)
	if int(unsafe_setup["score"]) >= 0 or int(safe_setup["score"]) != int(setup["score"]):
		failures.append("Removal setup safety did not account for spending the mana reserved for Sap")
	var refunded_setup := bot._plan_removal_setup(setup.merged({"mana_refund": 1}), [], {}, 0, [], sap_cost, null, false)
	if int(refunded_setup["score"]) != int(setup["score"]):
		failures.append("Removal setup safety missed mana refunded in time to pay for Sap")

	var demiurge := ApollyonsDemiurge.new()
	demiurge.card_owner = player
	player.hand_zone.add_card(demiurge)
	var demon := SulakTheUnclean.new()
	demon.card_owner = player
	demon.add_status_effect("cannot_intercept", "Preflight")
	player.deck_zone.add_card(demon, Zone.DeckPlacement.PRIMED)
	player.deck_zone.add_card(CreatureCard.new())
	player.mana = sap_cost
	var unsafe_mill := bot._plan_demiurge(demiurge, 0, true)
	player.mana += sap_cost
	var safe_mill := bot._plan_demiurge(demiurge, 0, true)
	if not unsafe_mill.is_empty() or safe_mill.get("command", {}).get("x_value") != 1:
		failures.append("Apollyon's Demiurge did not leave mana for Sap when choosing X")

	var blocker := CreatureCard.new()
	blocker.card_owner = player
	blocker.creature_mode = Card.CreatureMode.DEFENSIVE
	blocker.resilience = 40
	blocker.speed = 3
	player.frontline_zones[0].add_card(blocker)
	var fodder := CreatureCard.new()
	fodder.card_owner = player
	fodder.creature_mode = Card.CreatureMode.DEFENSIVE
	fodder.strength = 25
	fodder.add_status_effect("cannot_intercept", "Preflight")
	player.reserve_zones[1].add_card(fodder)
	var recruit := CreatureCard.new()
	recruit.card_owner = player
	recruit.mana_cost = 2
	recruit.sacrifice_cost = 1
	recruit.add_status_effect("cannot_intercept", "Preflight")
	player.hand_zone.add_card(recruit)
	var zone := player.frontline_zones[1]
	player.mana = recruit.mana_cost
	var protect_blocker := bot._build_creature_play_command(recruit, zone, Card.CreatureMode.DEFENSIVE, 0, true)
	player.mana += sap_cost
	var use_sap := bot._build_creature_play_command(recruit, zone, Card.CreatureMode.DEFENSIVE, 0, true)
	if protect_blocker.get("sacrifice_uids", []) != [fodder.uid] or use_sap.get("sacrifice_uids", []) != [blocker.uid]:
		failures.append("Summon sacrifice selection did not keep the blocker when the summon spent Sap's mana")
	bot.detach()

func _check_bot_call_of_the_crossing_holistic(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.setup_game()
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var hermes := Hermes.new()
	hermes.card_owner = player
	player.god_zone.add_card(hermes)
	var shift := AspectShift.new()
	shift.card_owner = player
	player.power_zones[0].add_card(shift)
	var ghost := Edimmu.new()
	ghost.card_owner = player
	player.deck_zone.add_card(ghost)
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var crossing := shift.make_hades_aspect() as HermesPsychopompus
	player.mana = 5
	# Attacks already resolved and no Spirit/Mage to engage: Incorporeal Edimmu is
	# a do-nothing body this turn, so the discard's opportunity cost decides the
	# trade. Tossing an average playable body for it is poor.
	game.has_resolved_attack_this_turn = true
	var average := CreatureCard.new()
	average.card_owner = player
	average.strength = 10
	average.resilience = 10
	player.hand_zone.add_card(average)
	if not bot._plan_call_of_the_crossing(crossing, 0, [], {}, player.mana).is_empty():
		failures.append("Call of the Crossing tossed an average body for a do-nothing Incorporeal Ghost")
	# The same Ghost is worth a genuinely weak discard, and can actually fight
	# once attacks are open: the trade depends on the discard and the result.
	player.hand_zone.remove_card(average)
	var weak := CreatureCard.new()
	weak.card_owner = player
	player.hand_zone.add_card(weak)
	game.has_resolved_attack_this_turn = false
	var worth := bot._plan_call_of_the_crossing(crossing, 0, [], {}, player.mana)
	if worth.get("command", {}).get("ghost_uid") != ghost.uid:
		failures.append("Call of the Crossing passed up a weak discard into a fighting Ghost")
	bot.detach()

func _check_bot_combat_mana_budget(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.setup_game()
	game.turn_number = 3
	var beast := PictishBeast.new()
	beast.card_owner = player
	beast.is_stealth = true
	beast.is_face_down = true
	player.frontline_zones[0].add_card(beast)
	var asakku := Asakku.new()
	asakku.card_owner = player
	player.reserve_zones[0].add_card(asakku)
	var target := CreatureCard.new()
	target.card_owner = opponent
	target.resilience = 1
	opponent.frontline_zones[0].add_card(target)
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var attacks := bot._get_attack_candidates(beast, null, false, null, 0, null, {}, null, target)
	if attacks.is_empty():
		failures.append("Combat mana fixture could not forecast the attack")
		return
	attacks[0]["mana_cost"] = 1
	var funded := bot._plan_combat(attacks, [], null, 0, null, 1)
	if funded.get("mana", -1) != PictishBeast.MANA_PER_BEAST + 2 or funded.get("mana_required", -1) != 1 \
			or not bot._plan_combat(attacks, [], null, 0, null, 0).is_empty():
		failures.append("Combat budget missed Mana Boon or Offering, or spent them before the attack")
	var cancelled: Dictionary = attacks[0]["base"].duplicate()
	cancelled.erase("mana_boon_sources")
	cancelled.erase("offering_victims")
	attacks[0]["replies"][VoidShield.new()] = cancelled
	if bot._plan_combat(attacks, [], null, 0, null, 1).get("mana", -1) != 0:
		failures.append("Combat budget relied on mana an opposing response could prevent")
	bot.detach()

func _check_bot_violent_delights_upkeep(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	player.mana = AphroditeAreia.ACTIVATION_COST - 1
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var aphrodite := AphroditeAreia.new()
	aphrodite.card_owner = player
	player.god_zone.add_card(aphrodite)
	var attacker := CreatureCard.new()
	attacker.card_owner = player
	attacker.strength = 24
	attacker.speed = 4
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(attacker)
	var defender := CreatureCard.new()
	defender.card_owner = opponent
	defender.resilience = 8
	defender.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[0].add_card(defender)
	var captive := CreatureCard.new()
	captive.card_owner = opponent
	captive.strength = 30
	captive.speed = 1
	captive.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.reserve_zones[0].add_card(captive)
	var upkeep_zone := bot._get_first_open_summon_zone(player)
	if str(bot._choose_upkeep_option(upkeep_zone).get("choice", "")) != "mana":
		failures.append("Aphrodite did not take mana for a combat kill followed by Violent Delights")
	player.mana = AphroditeAreia.ACTIVATION_COST
	var line := bot._plan_combat(bot._get_combat_candidates())
	if line.get("target") != defender or not line.get("violent_delights", false):
		failures.append("Aphrodite did not plan the qualifying attack with mana available for Violent Delights")
	if str(bot._choose_upkeep_option(upkeep_zone).get("choice", "")) != "draw":
		failures.append("Aphrodite took extra mana when she could already afford the Violent Delights line")
	player.mana = AphroditeAreia.ACTIVATION_COST - 1
	opponent.reserve_zones[0].remove_card(captive)
	if str(bot._choose_upkeep_option(upkeep_zone).get("choice", "")) != "draw":
		failures.append("Aphrodite planned to enslave a creature that would be destroyed in combat")
	bot.detach()

	player.mana = AphroditeAreia.ACTIVATION_COST
	game._upkeep_resolved_turn = game.turn_number
	opponent.reserve_zones[0].add_card(captive)
	var sender := {"player_index": 0}
	var attack := {"type": "request_attack", "attacker_uid": attacker.uid, "target_id": defender.uid}
	if not manager.process_command(attack, sender):
		failures.append("Violent Delights regression setup could not declare the qualifying attack")
		return
	for _step in range(8):
		manager.advance_priority()
	if defender.current_zone != opponent.graveyard_zone or not aphrodite.can_activate(game):
		failures.append("Violent Delights did not become available after an authoritative combat kill")
		return
	if manager.get_pending_ui_interaction_count() != 0:
		failures.append("Violent Delights left a blocking prompt after combat")
		return
	var enslave := {"type": "god_ability", "god_uid": aphrodite.uid, "target_uid": captive.uid}
	if not manager.process_command(enslave, sender):
		failures.append("Violent Delights rejected a valid target chosen directly after combat")
		return
	for _step in range(8):
		manager.advance_priority()
	if captive.get_controller() != player or not captive.is_enslaved() or player.mana != 0:
		failures.append("Violent Delights did not capture the chosen creature for its mana cost")

func _check_bot_shift_and_extraction(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	opponent.followers = 26
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var thiazi := Thiazi.new()
	thiazi.card_owner = player
	thiazi.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(thiazi)
	var blocker := CreatureCard.new()
	blocker.card_owner = opponent
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	blocker.strength = 25
	blocker.speed = 1
	opponent.frontline_zones[0].add_card(blocker)
	var attacks := bot._get_combat_candidates()
	var shift := bot._plan_shift(attacks, bot._plan_combat(attacks), 0)
	if not bool(shift.get("lethal", false)) or thiazi.in_animal_form:
		failures.append("Bot failed to forecast a lethal Shift without changing Thiazi's live form")
	thiazi.creature_minor_actions_used = thiazi.get_max_minor_creature_actions_per_turn()
	if bool(bot._plan_shift(attacks, bot._plan_combat(attacks), 0).get("lethal", false)):
		failures.append("Bot forecast an attack after a Shift that consumes Thiazi's major action")
	thiazi.creature_minor_actions_used = 0
	if not bot._take_main_phase_action():
		failures.append("Bot did not submit the combat Shift")
	for _step in range(8):
		manager.advance_priority()
	if not thiazi.in_animal_form or not thiazi.can_take_major_creature_action():
		failures.append("Thiazi's Shift did not resolve with its attack still available")

	opponent.frontline_zones[0].remove_card(blocker)
	thiazi.shift_forms()
	thiazi.creature_mode = Card.CreatureMode.DEFENSIVE
	var tez := TezcatlipocaTheSmokingMirror.new()
	tez.card_owner = player
	tez.tonal_mastery_tokens = 2
	player.god_zone.add_card(tez)
	player.mana = 2
	var nagual := Nagual.new()
	nagual.card_owner = player
	nagual.creature_mode = Card.CreatureMode.DEFENSIVE
	player.frontline_zones[1].add_card(nagual)
	blocker.strength = 21
	blocker.speed = 3
	opponent.frontline_zones[0].add_card(blocker)
	var danger := bot._forecast_incoming_follower_loss()
	if not bot._plan_shift([], {}, danger).is_empty():
		failures.append("Tezcatlipoca traded Nagual's 22 RES for 17 RES and exposed it to a 21 STR attacker to gain mana")
	nagual.shift_forms()
	tez.is_muted = true
	shift = bot._plan_shift([], {}, danger)
	if shift.get("command", {}).get("source_uid") != nagual.uid:
		failures.append("Bot did not Shift Nagual back to 22 RES to survive a 21 STR attack")
	tez.is_muted = false
	opponent.frontline_zones[0].remove_card(blocker)
	opponent.reserve_zones[0].add_card(blocker)
	nagual.shift_forms()
	blocker.spend_minor_creature_action()
	blocker.spend_major_creature_action()
	danger = bot._forecast_incoming_follower_loss()
	if not bot._plan_shift([], {}, danger).is_empty():
		failures.append("Bot exposed Nagual to a reserve attacker that could advance after its actions reset")
	blocker.add_status_effect("cannot_move", "Preflight")
	shift = bot._plan_shift([], {}, danger)
	if shift.get("command", {}).get("source_uid") != nagual.uid:
		failures.append("Bot avoided a safe Shift because it expected a movement-locked creature to advance")
	blocker.remove_status_effects_by_name("cannot_move")
	var occupied_lanes: Array[Card] = []
	for lane in [0, 1]:
		var occupant := CreatureCard.new()
		occupant.card_owner = opponent
		opponent.frontline_zones[lane].add_card(occupant)
		occupied_lanes.append(occupant)
	shift = bot._plan_shift([], {}, danger)
	if shift.get("command", {}).get("source_uid") != nagual.uid:
		failures.append("Bot avoided a safe Shift because it expected a reserve creature to move into an occupied lane")
	for occupant in occupied_lanes:
		occupant.current_zone.remove_card(occupant)
	var weak_target := CreatureCard.new()
	weak_target.card_owner = opponent
	weak_target.resilience = 1
	opponent.frontline_zones[4].add_card(weak_target)
	opponent.followers = 100
	if bot._get_best_mode_switch_candidate() == nagual:
		failures.append("Bot switched Nagual to Aggressive for a weak target while a reserve attacker could kill it")
	opponent.frontline_zones[4].remove_card(weak_target)
	opponent.followers = 15
	if bot._get_best_mode_switch_candidate() != nagual:
		failures.append("Bot passed up a winning attack because of a reserve threat on the next turn")
	opponent.followers = 26
	opponent.frontline_zones[4].add_card(weak_target)
	blocker.add_status_effect("cannot_move", "Preflight")
	if not bot._try_switch_to_aggressive_mode(danger) or nagual.creature_mode != Card.CreatureMode.AGGRESSIVE:
		failures.append("Bot did not switch Nagual to Aggressive once the reserve attacker could no longer advance")
	opponent.frontline_zones[4].remove_card(weak_target)
	nagual.reset_creature_action_state()
	nagual.spend_attack_creature_action()
	if bot._get_best_defensive_mode_switch_candidate() == nagual:
		failures.append("Bot spent Nagual's remaining minor action on defense against a reserve attacker that could not advance")
	blocker.remove_status_effects_by_name("cannot_move")
	var original_strength := blocker.strength
	blocker.strength = 23
	if bot._get_best_defensive_mode_switch_candidate() == nagual:
		failures.append("Bot switched Nagual to Defensive even though the reserve attacker could still kill it")
	blocker.strength = original_strength
	if not bot._try_switch_to_defensive_mode() or nagual.creature_mode != Card.CreatureMode.DEFENSIVE:
		failures.append("Bot did not switch Nagual back to Defensive after attacking to survive the advancing reserve creature")
	opponent.reserve_zones[0].remove_card(blocker)
	player.frontline_zones[1].remove_card(nagual)
	var serpent := TheWhiteSerpent.new()
	serpent.card_owner = player
	player.reserve_zones[0].add_card(serpent)
	if not bot._take_main_phase_action():
		failures.append("Tezcatlipoca did not submit a Shift to complete Tonal Mastery")
	for _step in range(8):
		manager.advance_priority()
	if player.mana != 5 or tez.get_tonal_mastery_token_count() != 0 or not serpent.in_serpent_form:
		failures.append("Tezcatlipoca's bot did not gain mana from a tactically neutral Shift")

	var power := TonalExtraction.new()
	power.card_owner = player
	power.is_face_down = true
	player.power_zones[0].add_card(power)
	if not bot._take_main_phase_action():
		failures.append("Tezcatlipoca did not spend the Tonal Mastery mana on a useful extraction")
	# The meta-fitted body curves (v0.2.372) price The White Serpent's
	# alternate form (26/26) above Thiazi's animal form (27/15), so the
	# extraction takes the Serpent here. The assertions still pin the whole
	# unlock line: the face-down power turns face-up, the mastery mana is
	# spent to 0, the extracted Shapeshifter locks, and the Spirit carries
	# its alternate form's stats and classes.
	var spirit := player.frontline_zones[1].get_creature() as TonalExtractionSpiritToken
	if power.is_face_down or player.mana != 0 or not serpent.is_shapeshift_locked() \
			or spirit == null or spirit.get_effective_strength() != 26 or not spirit.has_type("Human"):
		failures.append("Bot did not extract the Serpent's higher-valued alternate form through the unlock command")
	bot.detach()

func _check_bot_equipment_forecast(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 5
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var lane := player.frontline_zones[0]
	var bearer := CreatureCard.new()
	bearer.card_owner = player
	bearer.strength = 10
	bearer.speed = 2
	bearer.creature_mode = Card.CreatureMode.AGGRESSIVE
	lane.add_card(bearer)
	var blocker := CreatureCard.new()
	blocker.card_owner = opponent
	blocker.resilience = 21
	blocker.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[0].add_card(blocker)
	var sword := RunicShortsword.new()
	sword.card_owner = player
	player.hand_zone.add_card(sword)
	if not bot._plan_combat_equipment(0, 0).is_empty():
		failures.append("Bot planned a Shortsword attack that still loses to the blocker")
	var bow := ReedBow.new()
	bow.card_owner = player
	player.hand_zone.add_card(bow)
	if not bot._take_main_phase_action() or sword.equipped_on != bearer or not bot._take_main_phase_action() \
			or bow.equipped_on != bearer or bearer.get_effective_strength() != 22:
		failures.append("Bot did not equip both free weapons before the attack they win together")
	player.move_card(bearer, player.graveyard_zone)
	var gawain := Gawain.new()
	gawain.card_owner = player
	player.hand_zone.add_card(gawain)
	var boots := SevenLeagueBoots.new()
	boots.card_owner = player
	player.hand_zone.add_card(boots)
	var shield := VoidShield.new()
	shield.card_owner = opponent
	shield.is_prepared = true
	shield.is_face_down = true
	opponent.reserve_zones[0].add_card(shield)
	game.prepared_hexes[shield] = game.turn_number - 1
	player.mana = 4
	var summon_lane := bot._get_first_open_summon_zone(player)
	var hidden_hexes := bot._count_unidentified_attack_hexes()
	var unfunded := bot._upkeep_equipment_plan(4, summon_lane, gawain, hidden_hexes)
	var funded := bot._upkeep_equipment_plan(8, summon_lane, gawain, hidden_hexes)
	if hidden_hexes != 1 or not unfunded.is_empty() or funded.get("command", {}).get("card_uid") != boots.uid:
		failures.append("Bot did not distinguish paying for Gawain from paying for Gawain and the Boots")
	shield.speed = 7
	if bot._upkeep_equipment_plan(8, summon_lane, gawain, hidden_hexes) != funded:
		failures.append("Bot used the hidden Hex's actual speed in its equipment forecast")
	shield.speed = 3
	blocker.creature_mode = Card.CreatureMode.AGGRESSIVE
	blocker.strength = 5
	opponent.followers = 20
	var upkeep := bot._choose_upkeep_option(summon_lane)
	if upkeep.get("choice") != "mana" or not upkeep.get("prioritize_mana", false):
		failures.append("Bot did not take upkeep mana for a winning Gawain and Boots attack")
	opponent.followers = 100
	blocker.creature_mode = Card.CreatureMode.DEFENSIVE
	shield.is_face_down = false
	player.mana = 2
	player.move_card(gawain, summon_lane)
	gawain.creature_mode = Card.CreatureMode.AGGRESSIVE
	gawain.on_summon(game)
	if not bot._take_main_phase_action() or boots.equipped_on != gawain or gawain.get_effective_speed() != 7:
		failures.append("Bot did not equip the Boots before attacking into a known Void Shield")
	bot.detach()

func _check_bot_combat_buff_value(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var enkidu := Enkidu.new()
	enkidu.card_owner = player
	enkidu.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(enkidu)
	var asaruludu := Asaruludu.new()
	asaruludu.card_owner = opponent
	asaruludu.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(asaruludu)
	var first := FifaTheMagicalArrow.new()
	first.card_owner = player
	player.hand_zone.add_card(first)
	var second := FifaTheMagicalArrow.new()
	second.card_owner = player
	player.hand_zone.add_card(second)
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = player
	attack.attacker = enkidu
	attack.target = asaruludu
	if int(bot._score_priority_card(first, attack, -1)["score"]) <= 0:
		failures.append("Bot did not value Fifa turning Enkidu's loss into a win")
	asaruludu.strength = 34
	var planned := bot._get_best_supported_attack([enkidu], [asaruludu])
	if planned.get("target") != asaruludu:
		failures.append("Bot did not see the two-Fifa combat line before declaring the attack")
	game.push_to_stack(attack)
	game.pass_priority()
	if bot._choose_priority_response() not in [first, second]:
		failures.append("Bot would not start the predicted two-Fifa combat line")
	game.action_stack.clear()
	var third := FifaTheMagicalArrow.new()
	third.card_owner = player
	player.hand_zone.add_card(third)
	asaruludu.strength = 39
	if bot._get_best_supported_attack([enkidu], [asaruludu]).get("target") != asaruludu:
		failures.append("Bot did not anticipate a fight that needs three Fifas to win")
	var vision := VisionOfOdin.new()
	vision.card_owner = player
	vision.is_prepared = true
	player.reserve_zones[0].add_card(vision)
	game.prepared_hexes[vision] = game.turn_number - 1
	enkidu.culture = "Norse"
	asaruludu.strength = 45
	opponent.followers = 4
	if bot._get_best_supported_attack([enkidu], [asaruludu]).get("target") != asaruludu:
		failures.append("Bot did not anticipate lethal from a prepared Vision followed by three Fifas")
	game.push_to_stack(attack)
	game.pass_priority()
	if bot._choose_priority_response() != vision:
		failures.append("Bot did not start the four-card lethal sequence with its slower response")
	var pending_vision := CardAction.new()
	pending_vision.type = CardAction.Type.ABILITY
	pending_vision.source_player = player
	pending_vision.card = vision
	pending_vision.target = enkidu
	pending_vision.response_to = attack
	game.push_to_stack(pending_vision)
	game.pass_priority()
	if bot._choose_priority_response() not in [first, second, third]:
		failures.append("Bot missed the three remaining responses with Vision already pending")
	opponent.followers = 100
	asaruludu.strength = 28
	if bot._choose_priority_response() != null:
		failures.append("Bot spent three more cards for nonlethal damage after the pending Vision already won the fight")
	game.action_stack.clear()
	game.prepared_hexes.erase(vision)
	player.move_card(vision, player.graveyard_zone)
	player.move_card(third, player.graveyard_zone)
	enkidu.culture = "Ancient"
	opponent.followers = 100
	asaruludu.strength = 28
	var pending := CardAction.new()
	pending.type = CardAction.Type.SPELL
	pending.source_player = player
	pending.card = first
	pending.target = enkidu
	game.push_to_stack(pending)
	game.pass_priority()
	if bot._choose_priority_response() != null:
		failures.append("Bot stacked another Fifa before the first one resolved")
	game.action_stack.push_front(attack)
	pending.response_to = attack
	opponent.followers = 8
	if bot._choose_priority_response() != second:
		failures.append("Bot did not anticipate lethal from both Fifas while the first was pending")
	if enkidu.get_effective_strength() != enkidu.strength:
		failures.append("Projecting pending buffs changed Enkidu's live stats")
	opponent.followers = 100
	asaruludu.strength = 34
	if bot._choose_priority_response() != second:
		failures.append("Bot did not anticipate that stacking two Fifas would flip the fight")
	asaruludu.strength = 28
	if bot._choose_priority_response() != null:
		failures.append("Bot stacked a second Fifa for nonlethal damage in a pending attack")
	var counter := CardAction.new()
	counter.type = CardAction.Type.ABILITY
	counter.card = Banishment.new()
	counter.card.card_owner = opponent
	opponent.reserve_zones[0].add_card(counter.card)
	counter.source_player = opponent
	counter.response_to = pending
	second.speed = counter.card.get_effective_speed()
	game.push_to_stack(counter)
	if bot._choose_priority_response() != second:
		failures.append("Bot still counted a pending Fifa after the opponent queued Banishment against it")
	game.action_stack.clear()
	first.resolve(game, enkidu)
	if int(bot._score_priority_card(second, attack, -1)["score"]) > 0:
		failures.append("Bot spent a second Fifa for five nonlethal followers after the fight was already won")
	opponent.followers = 8
	if int(bot._score_priority_card(second, attack, -1)["score"]) <= 0:
		failures.append("Bot did not value a second Fifa when the extra damage was lethal")
	var non_object_action := CardAction.new()
	non_object_action.type = CardAction.Type.SPELL
	non_object_action.card = first
	non_object_action.target = ["non_object_target", 42]
	game.push_to_stack(non_object_action)
	var projection := BotCardStrategyScript.combat_projection(bot, non_object_action)
	if projection.get("attack") != null:
		failures.append("combat_projection misidentified a non-object spell target as an attack")
	game.action_stack.clear()
	enkidu.clear_all_effects()
	enkidu.strength = 20
	enkidu.spend_major_creature_action()
	asaruludu.creature_mode = Card.CreatureMode.DEFENSIVE
	asaruludu.resilience = 23
	asaruludu.speed = 7
	opponent.followers = 100
	enkidu.add_buff("Preflight temporary strength", 6, 0, 0, null, null, "buff", {"expires_turn": game.turn_number})
	var lasting_gain := BotCardStrategyScript.stat_gain(bot, second, enkidu)
	var temporary_gain := BotCardStrategyScript.combat_gain(bot, enkidu, FifaTheMagicalArrow.STR_BONUS)
	if lasting_gain <= 0 or temporary_gain != 0 or enkidu.get_effective_strength() != 26:
		failures.append("Bot did not distinguish a buff that lasts until the next fight from one that expires before it")
	enkidu.add_buff("Preflight lasting strength", 6, 0, 0)
	if BotCardStrategyScript.stat_gain(bot, second, enkidu) != 0:
		failures.append("Bot valued extra strength when the existing lasting buff already secured the fight")

	enkidu.clear_all_effects()
	asaruludu.resilience = 24
	var pyre := AncientPyre.new()
	pyre.card_owner = player
	player.frontline_zones[1].add_card(pyre)
	var open_defense := BotCardStrategyScript.target_score(bot, pyre, asaruludu)
	asaruludu.add_buff("Preflight lasting resilience reduction", 0, -AncientPyre.EFFECT_AMOUNT, 0)
	if open_defense <= 0 or BotCardStrategyScript.target_score(bot, pyre, asaruludu) != 0:
		failures.append("Bot did not distinguish a resilience debuff that opens a fight from a redundant stack")
	bot.detach()

func _check_bot_jiang_counterstroke(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = opponent
	game.other_player = player
	game.turn_number = 2
	game._upkeep_resolved_turn = game.turn_number
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var jiang := JiangZiyaFisherOfKings.new()
	jiang.card_owner = player
	jiang.tactic_counters = JiangZiyaFisherOfKings.TACTIC_COUNTER_COST
	player.frontline_zones[0].add_card(jiang)
	var attacker := Enkidu.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[0].add_card(attacker)
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = opponent
	attack.attacker = attacker
	attack.target = jiang
	game.push_to_stack(attack)
	if not game.get_priority_responses(player).has(jiang) \
			or int(bot._score_priority_card(jiang, attack, -1)["score"]) <= 0 \
			or bot._choose_priority_response() != jiang:
		failures.append("Bot did not recognize or choose Jiang's Counterstroke when Jiang was attacked")
	manager.advance_priority()
	var counterstroke_action: CardAction = game.action_stack.back() if game.action_stack.size() >= 2 else null
	if counterstroke_action == null or counterstroke_action.card != jiang:
		failures.append("Bot did not submit Jiang's Counterstroke during the attack priority window")
	else:
		if counterstroke_action.get_timing_speed() != JiangZiyaFisherOfKings.COUNTER_RESPONSE_SPEED:
			failures.append("Jiang's submitted Counterstroke lost its response speed")
		manager.resolve_action(counterstroke_action)
	if attack in game.action_stack or jiang.tactic_counters != 0 or attacker.current_zone != opponent.graveyard_zone:
		failures.append("Bot's submitted Counterstroke did not negate the attack and destroy its attacker")
	bot.detach()

	game = _new_fixture_game()
	player = _new_fixture_player()
	opponent = _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 2
	game._upkeep_resolved_turn = game.turn_number
	manager = _new_fixture_match(game)
	bot = _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	jiang = JiangZiyaFisherOfKings.new()
	jiang.card_owner = opponent
	jiang.tactic_counters = JiangZiyaFisherOfKings.TACTIC_COUNTER_COST
	opponent.frontline_zones[0].add_card(jiang)
	attacker = Enkidu.new()
	attacker.card_owner = player
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[0].add_card(attacker)
	var targeted_effect := SpellCard.new()
	targeted_effect.card_owner = player
	targeted_effect.targets = true
	if not BotCardStrategyScript.counterstroke_can_answer(bot, jiang, targeted_effect):
		failures.append("Bot did not recognize an enemy Jiang that can counter a targeted effect")
	if not BotCardStrategyScript.counterstroke_can_answer(bot, jiang, attacker, null, true) \
			or not bot._is_attack_target_tactically_bad(attacker, jiang):
		failures.append("Bot did not account for enemy Jiang's Counterstroke when choosing an attacker")
	jiang.tactic_counters = 0
	if BotCardStrategyScript.counterstroke_can_answer(bot, jiang, attacker, null, true) \
			or bot._is_attack_target_tactically_bad(attacker, jiang):
		failures.append("Bot still avoided enemy Jiang after its Counterstroke counters were spent")
	bot.detach()

func _check_reveal_before_tactical_retreat(failures: PackedStringArray) -> void:
	for destroy_attacker in [false, true]:
		var game := _new_fixture_game()
		var attacking_player := _new_fixture_player()
		var defending_player := _new_fixture_player()
		game.players.assign([attacking_player, defending_player])
		game.current_player = attacking_player
		game.other_player = defending_player
		game.turn_number = 3
		var manager := _new_fixture_match(game)
		var attacker := Askelladen.new()
		attacker.card_owner = attacking_player
		attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
		attacking_player.frontline_zones[0].add_card(attacker)
		var priest := MasmassuPriest.new()
		priest.card_owner = defending_player
		priest.creature_mode = Card.CreatureMode.DEFENSIVE
		priest.is_stealth = true
		priest.is_face_down = true
		defending_player.frontline_zones[0].add_card(priest)
		var other_creature := BrownBear.new()
		other_creature.card_owner = attacking_player
		attacking_player.reserve_zones[1].add_card(other_creature)

		var attack := CardAction.new()
		attack.type = CardAction.Type.ATTACK
		attack.source_player = attacking_player
		attack.attacker = attacker
		attack.target = priest
		game.push_to_stack(attack)
		manager.resolve_action(attack)
		manager._release_next_queued_ui_interaction()
		if not manager.has_pending_ui_interaction(defending_player, "masmassu_priest_reveal", priest.uid) \
				or manager.pending_retreat_action != null:
			failures.append("Askelladen's attack blocked the Priest's Reveal choice behind Tactical Retreat")
			continue

		manager.set_priority_preferences(attacking_player, {"combat": true}, false)
		var reveal_target: Card = attacker if destroy_attacker else other_creature
		var reveal_ok := manager.process_command({
			"type": "masmassu_priest_reveal_choice", "source_uid": priest.uid, "target_uid": reveal_target.uid,
		}, {"player_index": 1})
		manager.advance_priority()
		if not reveal_ok or not manager.has_pending_ui_interaction(attacking_player, "priority") \
				or manager.pending_retreat_action != null or game.action_stack.back() == attack:
			failures.append("Dalkhu Break did not offer its response window before Tactical Retreat")
			continue
		if not manager.process_command({"type": "priority_pass"}, {"player_index": 0}):
			failures.append("Could not pass priority on Dalkhu Break during Askelladen's attack")
			continue
		manager.advance_priority()
		if reveal_target.current_zone != attacking_player.graveyard_zone:
			failures.append("Dalkhu Break did not destroy its target during Askelladen's attack")
			continue
		if not destroy_attacker:
			if not manager.has_pending_ui_interaction(attacking_player, "combat_retreat"):
				failures.append("Askelladen did not get Tactical Retreat after the Priest's Reveal resolved")
				continue
			manager.set_priority_preferences(attacking_player, {}, false)
			if not manager.process_command({
				"type": "combat_retreat_decision", "askelladen_uid": attacker.uid, "retreat": true,
			}, {"player_index": 0}) or attacker.current_zone != attacking_player.deck_zone \
					or priest.current_zone != defending_player.deck_zone:
				failures.append("Tactical Retreat did not shelve both creatures after the Priest's Reveal")
		if manager.has_unresolved_stack_action_window():
			failures.append("Askelladen's attack left the combat stack locked after the Priest's Reveal")

func _new_doorway_match() -> MatchManager:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.setup_game()
	game.turn_number = 2
	game.sfx_enabled = false
	var doorway := DoorwayToTheVoid.new()
	doorway.card_owner = opponent
	opponent.reserve_zones[0].add_card(doorway)
	return _new_fixture_match(game)

func _answer_doorway_choice(manager: MatchManager, card: Card, send_to_abyss: bool) -> bool:
	var game := manager.game_manager
	var doorway := game.get_pending_doorway_structure()
	return doorway != null and game.get_pending_doorway_card() == card \
		and manager.process_command({
			"type": "doorway_choice", "structure_uid": doorway.uid, "card_uid": card.uid,
			"send_to_abyss": send_to_abyss,
		}, {"player_index": game.players.find(doorway.card_owner)})

func _check_united_front_doorway(failures: PackedStringArray) -> void:
	for defender_strength in [14, 10]:
		var manager := _new_doorway_match()
		var game := manager.game_manager
		var player := game.current_player
		var opponent := game.other_player
		var attacker := RoboticFootsoldier.new()
		var partner := RoboticFootsoldier.new()
		var defender := BrownBear.new()
		for card: Card in [attacker, partner]:
			card.card_owner = player
			card.creature_mode = Card.CreatureMode.AGGRESSIVE
			card.strength = 5
		player.frontline_zones[0].add_card(attacker)
		player.frontline_zones[1].add_card(partner)
		defender.card_owner = opponent
		defender.creature_mode = Card.CreatureMode.AGGRESSIVE
		defender.strength = defender_strength
		opponent.frontline_zones[0].add_card(defender)

		var attack := CardAction.new()
		attack.type = CardAction.Type.ATTACK
		attack.source_player = player
		attack.attacker = attacker
		attack.united_front_partner = partner
		attack.target = defender
		game.push_to_stack(attack)
		manager.resolve_action(attack)
		if not _answer_doorway_choice(manager, attacker, true) or not manager.has_unresolved_stack_action_window() \
				or not _answer_doorway_choice(manager, partner, false):
			failures.append("United Front did not wait for each attacker's Doorway choice")
			continue
		if defender_strength == 10 and not _answer_doorway_choice(manager, defender, false):
			failures.append("United Front tie did not offer a Doorway choice for the defender")
		if attacker.current_zone != player.abyss_zone or partner.current_zone != player.graveyard_zone \
				or defender.current_zone != (opponent.graveyard_zone if defender_strength == 10 else opponent.frontline_zones[0]) \
				or not game.has_resolved_attack_this_turn or manager.has_unresolved_stack_action_window():
			failures.append("United Front did not complete after its Doorway choices")

func _check_guan_yu_manoeuvre_and_slay(failures: PackedStringArray) -> void:
	var manager := _new_doorway_match()
	var game := manager.game_manager
	var player := game.current_player
	var opponent := game.other_player
	var guan_yu := GuanYuActive.new()
	var watchtower := Watchtower.new()
	var warrior := HariiWarrior.new()
	guan_yu.card_owner = player
	watchtower.card_owner = player
	warrior.card_owner = player
	player.frontline_zones[0].add_card(guan_yu)
	player.reserve_zones[0].add_card(watchtower)
	player.frontline_zones[1].add_card(warrior)
	guan_yu.on_impact(game)
	if guan_yu.get_valid_targets(game) != [watchtower]:
		failures.append("Manoeuvre did not recognize a Watchtower with zero tactic counters")
	guan_yu.activate(game, watchtower)
	if guan_yu.tactic_counters != 6 or watchtower.tactic_counters != 1:
		failures.append("Manoeuvre did not transfer exactly one tactic counter")

	for send_to_abyss: bool in [true, false]:
		var target := BrownBear.new()
		target.card_owner = opponent
		opponent.frontline_zones[0].add_card(target)
		game._combat_kill_deferred(warrior, target)
		if not _answer_doorway_choice(manager, target, send_to_abyss):
			failures.append("Guan Yu's combat test did not resolve the Doorway choice")
			return
		var expected := 6 if send_to_abyss else 7
		if guan_yu.tactic_counters != expected:
			failures.append("Guan Yu gained the wrong number of counters for a combat casualty")

func _check_class_rend_ability_destruction(failures: PackedStringArray) -> void:
	var manager := _new_doorway_match()
	var game := manager.game_manager
	var player := game.current_player
	var opponent := game.other_player
	var asag := AsagTheDestroyer.new()
	var demon := Lindwyrm.new()
	var victim := BrownBear.new()
	var weapon := ReedBow.new()
	asag.card_owner = player
	demon.card_owner = player
	demon.card_types.append("Demon")
	demon.level = victim.level + 2
	victim.card_owner = opponent
	weapon.card_owner = opponent
	player.reserve_zones[0].add_card(asag)
	player.frontline_zones[0].add_card(demon)
	opponent.frontline_zones[0].add_card(victim)
	opponent.frontline_zones[0].add_card(weapon)
	game.equip_card(weapon, victim)

	game.grant_turn_destruction_ward(opponent)
	game.run_with_effect_source(demon, func() -> void:
		demon.activate(game, victim)
	)
	if victim.current_zone != opponent.frontline_zones[0] or game.has_pending_doorway_choice():
		failures.append("Class Rend bypassed an effect-destruction ward")

	game.turn_number += 1
	game.run_with_effect_source(demon, func() -> void:
		demon.activate(game, victim)
	)
	if game.has_pending_doorway_choice() or victim.current_zone != opponent.abyss_zone \
			or weapon.current_zone != opponent.abyss_zone or victim not in game.destroyed_this_turn:
		failures.append("Class Rend did not Void a Demon ability's victim and its Equipment")

func _check_guardian_targeting(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.setup_game()
	game.turn_number = 2
	var manager := _new_fixture_match(game)
	var asaruludu := Asaruludu.new()
	var enkidu := Enkidu.new()
	var smite := Smite.new()
	asaruludu.card_owner = player
	enkidu.card_owner = player
	smite.card_owner = opponent
	player.frontline_zones[0].add_card(asaruludu)
	player.frontline_zones[1].add_card(enkidu)
	opponent.reserve_zones[0].add_card(smite)

	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = player
	attack.target = opponent
	attack.attacker = enkidu
	if not game.get_attack_hex_targets(attack, smite).is_empty():
		failures.append("Guardian allowed Smite to target another Ancient creature")
	attack.attacker = asaruludu
	if game.get_attack_hex_targets(attack, smite) != [asaruludu]:
		failures.append("Asaruludu's Guardian protected himself")
	if game.is_guardian_protected(enkidu, Famine.new()):
		failures.append("Guardian blocked an untargeted effect")

	var gungnir := GungnirTheSpearOfOdin.new()
	var warrior := HariiWarrior.new()
	gungnir.card_owner = opponent
	warrior.card_owner = opponent
	opponent.frontline_zones[0].add_card(warrior)
	var opposing_attack := CardAction.new()
	opposing_attack.type = CardAction.Type.ATTACK
	opposing_attack.attacker = warrior
	opposing_attack.target = enkidu
	if not gungnir.get_priority_targets(game, opposing_attack).is_empty():
		failures.append("Gungnir ignored Guardian on its implicit target")

	var response := CardAction.new()
	response.type = CardAction.Type.ABILITY
	response.card = smite
	response.attacker = enkidu
	response.target = opponent
	manager._resolve_ability(response)
	if enkidu.current_zone != player.frontline_zones[1] or smite.current_zone != opponent.graveyard_zone:
		failures.append("Smite bypassed Guardian during resolution")

	var spell := BitMeseri.new()
	spell.card_owner = opponent
	opponent.hand_zone.add_card(spell)
	var spell_action := CardAction.new()
	spell_action.card = spell
	spell_action.source_player = opponent
	spell_action.target = enkidu
	spell_action.resolve_callback = func() -> void:
		game.banish_card_with_hook(enkidu)
	manager._resolve_spell(spell_action)
	if enkidu.current_zone != player.frontline_zones[1] or spell.current_zone != opponent.graveyard_zone:
		failures.append("A spell's queued target bypassed Guardian during resolution")

	if "Allied" not in CardDetailContentBuilder.extract_card_keywords(asaruludu) \
			or "Friendly" not in CardDetailContentBuilder.extract_card_keywords(FifaTheMagicalArrow.new()) \
			or not BaseCard.apply_keyword_hints("Choose a friendly Warrior.").contains("[hint="):
		failures.append("Allied and Friendly did not appear as card keywords")

func _check_habrok_breakout_ties(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([opponent, player])
	game.setup_game()
	game.turn_number = 2
	var manager := _new_fixture_match(game)
	var habrok := HabrokParagonOfHawks.new()
	var first := BrownBear.new()
	var second := BrownBear.new()
	var stronger := BrownBear.new()
	habrok.card_owner = player
	player.frontline_zones[0].add_card(habrok)
	for creature: Card in [first, second, stronger]:
		creature.card_owner = opponent
	stronger.strength += 1
	second.resilience += 1
	opponent.frontline_zones[0].add_card(first)
	opponent.frontline_zones[1].add_card(second)
	opponent.frontline_zones[2].add_card(stronger)
	if habrok.get_breakout_targets(game) != [first, second]:
		failures.append("Breakout did not offer all creatures tied for lowest STR")
	if not manager._offer_habrok_breakout(opponent):
		failures.append("Breakout did not offer a prompt at opponent turn end")
		return
	var command := {"type": "habrok_breakout_choice", "source_uid": habrok.uid, "do_breakout": true}
	if manager.process_command(command, {"player_index": 1}):
		failures.append("Breakout accepted a tie without a target choice")
		return
	command["target_uid"] = second.uid
	if not manager.process_command(command, {"player_index": 1}) \
			or second.current_zone != opponent.graveyard_zone or first.current_zone != opponent.frontline_zones[0] \
			or habrok.current_zone != player.hand_zone:
		failures.append("Breakout failed to destroy the chosen tied creature and return Habrok")

func _check_ragnarok_doorway(failures: PackedStringArray) -> void:
	var manager := _new_doorway_match()
	var game := manager.game_manager
	var player := game.current_player
	var doorway := game.other_player.reserve_zones[0].cards[0] as DoorwayToTheVoid
	game._upkeep_resolved_turn = game.turn_number
	player.mana = Ragnarok.UNLOCK_COST
	var power := Ragnarok.new()
	power.card_owner = player
	player.power_zones[0].add_card(power)
	var victims: Array[Card] = [BrownBear.new(), BrownBear.new()]
	for i in range(victims.size()):
		victims[i].card_owner = player
		player.frontline_zones[i].add_card(victims[i])
	for i in range(Ragnarok.HAND_LIMIT + 1):
		var card := BrownBear.new()
		card.card_owner = player
		player.hand_zone.add_card(card)
	if not manager.process_command({"type": "unlock_power", "power_uid": power.uid}, {"player_index": 0}) \
			or power.get_pending_discard_player(game) != null \
			or not _answer_doorway_choice(manager, victims[0], false) \
			or power.get_pending_discard_player(game) != null \
			or not _answer_doorway_choice(manager, victims[1], true):
		failures.append("Ragnarok did not finish both Doorway choices before asking for discards")
		return
	if not manager.process_command({
		"type": "ragnarok_discard_choice", "source_uid": power.uid, "target_uid": player.hand_zone.cards[0].uid,
	}, {"player_index": 0}) or player.hand_zone.get_card_count() != Ragnarok.HAND_LIMIT \
			or victims[0].current_zone != player.graveyard_zone or victims[1].current_zone != player.abyss_zone \
			or doorway.current_zone != game.other_player.graveyard_zone or not game.attack_restrictions.has(player) \
			or power.get_relock_turns_remaining(game) != Ragnarok.RELOCK_TURNS \
			or not manager.get_pending_ui_interaction_entries().is_empty():
		failures.append("Ragnarok did not finish destruction, discards, and relock after Doorway choices")

func _check_freyja_doorway(failures: PackedStringArray) -> void:
	for active in [false, true]:
		var manager := _new_doorway_match()
		var game := manager.game_manager
		var player := game.current_player
		var freyja: Card = FreyjaActive.new() if active else Freyja.new()
		freyja.card_owner = player
		var god_zone := player.frontline_zones[4] if active else player.god_zone
		god_zone.add_card(freyja)
		var warriors: Array[Card] = [HariiWarrior.new(), HariiWarrior.new()]
		for i in range(warriors.size()):
			warriors[i].card_owner = player
			player.frontline_zones[i].add_card(warriors[i])
			if active:
				(freyja as FreyjaActive)._apply_open_sessrumnir_effects(warriors[i], game)
			else:
				(freyja as Freyja)._apply_receiver_of_the_slain(warriors[i], game)
		game.start_turn()
		var upkeep := {"type": "upkeep_choice", "choice": "skip"}
		if active and not manager.process_command(upkeep, {"player_index": 0}):
			failures.append("Freyja, Active God could not finish upkeep to trigger warrior expiration")
			continue
		var other_casualty := BrownBear.new()
		other_casualty.card_owner = player
		player.frontline_zones[2].add_card(other_casualty)
		game.request_send_to_graveyard(other_casualty, Callable(), false, true)
		if not _answer_doorway_choice(manager, warriors[0], true) \
				or not _answer_doorway_choice(manager, warriors[1], false) \
				or not _answer_doorway_choice(manager, other_casualty, false):
			failures.append("%s did not resolve consecutive Doorway choices during warrior expiration" % freyja.card_name)
			continue
		if not active and not manager.process_command(upkeep, {"player_index": 0}):
			failures.append("Freyja could not finish upkeep after the Doorway choices")
		if warriors[0].current_zone != player.abyss_zone or warriors[1].current_zone != player.graveyard_zone \
				or warriors[0].has_type("Spirit") or warriors[1].has_type("Spirit") \
				or other_casualty.current_zone != player.graveyard_zone or game.has_pending_doorway_choice() \
				or not manager.get_pending_ui_interaction_entries().is_empty():
			failures.append("%s left warrior expiration or a Doorway choice unfinished" % freyja.card_name)

func _check_bot_reveal_defense(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game.has_resolved_attack_this_turn = true
	player.followers = 15
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var priest := MasmassuPriest.new()
	priest.card_owner = player
	player.hand_zone.add_card(priest)
	var chump := CreatureCard.new()
	chump.card_owner = player
	chump.strength = 14
	chump.resilience = 6
	chump.speed = 2
	player.hand_zone.add_card(chump)
	var first := CreatureCard.new()
	first.card_owner = opponent
	first.creature_mode = Card.CreatureMode.AGGRESSIVE
	first.strength = 24
	first.speed = 1
	opponent.frontline_zones[0].add_card(first)
	var second := CreatureCard.new()
	second.card_owner = opponent
	second.creature_mode = Card.CreatureMode.AGGRESSIVE
	second.strength = 20
	second.speed = 1
	opponent.frontline_zones[1].add_card(second)
	var danger := bot._forecast_incoming_follower_loss()
	var command: Dictionary = bot._plan_creature_summon(danger).get("command", {})
	if danger < player.followers or command.get("card_uid") != priest.uid or not command.get("stealth", false):
		failures.append("Bot failed to choose the Stealth Priest over a plain blocker against two lethal attackers")
	first.speed = 2
	second.speed = 2
	command = bot._plan_creature_summon(danger).get("command", {})
	if command.get("card_uid") != chump.uid:
		failures.append("Bot credited the Priest with an interception against attackers it could not catch")
	player.hand_zone.remove_card(priest)
	player.frontline_zones[0].add_card(priest)
	var action := CardAction.new()
	action.type = CardAction.Type.ATTACK
	action.attacker = first
	action.target = player
	action.interceptor = priest
	manager.pending_combat_reveal_linger_action = action
	var reveal_command := BotCardPromptPolicy.build_command(bot, "masmassu_priest_reveal", {
		"source_uid": priest.uid, "target_uids": [first.uid, second.uid],
	})
	if reveal_command.get("target_uid") != second.uid:
		failures.append("Bot targeted the committed attacker with Dalkhu Break instead of stopping the lethal follow-up")
	player.frontline_zones[0].remove_card(priest)
	player.hand_zone.remove_card(chump)
	var beast := PictishBeast.new()
	beast.card_owner = player
	player.hand_zone.add_card(beast)
	opponent.frontline_zones[1].remove_card(second)
	first.speed = 1
	command = bot._plan_creature_summon(bot._forecast_incoming_follower_loss()).get("command", {})
	if command.get("card_uid") != beast.uid or not command.get("stealth", false):
		failures.append("Bot failed to include Pictish Beast's Mana Boon in its defensive summon")
	bot.detach()

func _check_bot_exorcism_attached_sources(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 100
	opponent.followers = 100
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)

	var gilgamesh := Gilgamesh.new()
	gilgamesh.card_owner = player
	player.frontline_zones[0].add_card(gilgamesh)

	var lion := NergalLion.new()
	lion.card_owner = player
	lion.creature_mode = Card.CreatureMode.AGGRESSIVE
	player.frontline_zones[1].add_card(lion)

	var priest := MasmassuPriest.new()
	priest.card_owner = opponent
	priest.creature_mode = Card.CreatureMode.DEFENSIVE
	priest.is_face_down = true
	priest.is_stealth = true
	opponent.frontline_zones[0].add_card(priest)

	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = player
	attack.attacker = lion
	attack.target = priest
	game.push_to_stack(attack)

	var reveal := CardAction.new()
	reveal.type = CardAction.Type.EVENT
	reveal.event_name = "masmassu_priest_reveal"
	reveal.source_player = opponent
	reveal.card = priest
	reveal.target = gilgamesh
	game.push_to_stack(reveal)

	var exorcism := Exorcism.new()
	exorcism.card_owner = player
	# A queued Dalkhu Break is a one-shot reveal, not an ongoing effect, so
	# Exorcism gets no save credit for the creature and no destroyed-source
	# credit for the Priest.
	var queued_reveal_score := BotCardStrategyScript.target_score(bot, exorcism, gilgamesh)
	if queued_reveal_score > 0:
		failures.append("Bot still credits Exorcism against a queued Dalkhu Break it cannot negate")

	lion.strength = 2
	if BotCardStrategyScript.target_score(bot, exorcism, gilgamesh) != queued_reveal_score:
		failures.append("Bot's Exorcism score changed when the reveal source's combat fate changed")

	# Enemy hexes attached to the creature are ongoing sources Exorcism destroys.
	var wheel := WheelOfFire.new()
	wheel.card_owner = opponent
	wheel.attached_target = gilgamesh
	opponent.reserve_zones[0].add_card(wheel)
	if BotCardStrategyScript.target_score(bot, exorcism, gilgamesh) <= 0:
		failures.append("Bot stopped valuing the enemy hex Exorcism destroys as an attached source")

func _check_bot_defensive_stance_posture_gate(failures: PackedStringArray) -> void:
	# A preservation stance switch is tempo-negative, so it is reserved for
	# lethal prevention and scarce pools. The defend posture is the third
	# allowed state: when the opponent's push already owns the clock, walling
	# up beats donating bodies to a race the bot cannot win.
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 56
	player.mana = 4
	opponent.followers = 100
	opponent.mana = 5
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var wall := CreatureCard.new()
	wall.card_name = "Fixture Wall Body"
	wall.card_owner = player
	wall.creature_mode = Card.CreatureMode.AGGRESSIVE
	wall.strength = 20
	wall.resilience = 40
	player.frontline_zones[0].add_card(wall)
	var heavy := CreatureCard.new()
	heavy.card_name = "Fixture Lost-Clock Attacker"
	heavy.card_owner = opponent
	heavy.creature_mode = Card.CreatureMode.AGGRESSIVE
	heavy.strength = 23
	opponent.frontline_zones[1].add_card(heavy)
	var light := CreatureCard.new()
	light.card_name = "Fixture Lost-Clock Skirmisher"
	light.card_owner = opponent
	light.creature_mode = Card.CreatureMode.AGGRESSIVE
	light.strength = 21
	opponent.frontline_zones[2].add_card(light)
	var danger := bot._forecast_incoming_follower_loss()
	if danger <= 0 or danger >= player.followers:
		failures.append("Fixture failed to project a non-lethal incoming push for the stance posture gate")
	if str(bot._strategy_posture().get("posture", "balanced")) != "defend":
		failures.append("Fixture failed to classify a lost race clock as defend posture")
	var stance: Dictionary = bot._plan_defensive_stance(danger).get("command", {})
	if stance.get("card_uid") != wall.uid:
		failures.append("Bot skipped a defensive stance switch that walls a push the posture clock already lost")
	# The same preservation gain stays gated off while the bot owns the race:
	# tempo beats a small safety gain outside defend posture.
	var race_game := _new_fixture_game()
	var race_player := _new_fixture_player()
	var race_opponent := _new_fixture_player()
	race_game.players.assign([race_player, race_opponent])
	race_game.current_player = race_player
	race_game.other_player = race_opponent
	race_game.turn_number = 3
	race_game._upkeep_resolved_turn = race_game.turn_number
	race_player.followers = 100
	race_player.mana = 4
	race_opponent.followers = 10
	race_opponent.mana = 5
	var race_manager := _new_fixture_match(race_game)
	var race_bot := _new_fixture_bot()
	race_bot.attach(race_game, race_manager, ServerBotGameInput.new(race_manager, 0), 0)
	var race_wall := CreatureCard.new()
	race_wall.card_name = "Fixture Race Body"
	race_wall.card_owner = race_player
	race_wall.creature_mode = Card.CreatureMode.AGGRESSIVE
	race_wall.strength = 20
	race_wall.resilience = 40
	race_player.frontline_zones[0].add_card(race_wall)
	var race_attacker := CreatureCard.new()
	race_attacker.card_name = "Fixture Race Attacker"
	race_attacker.card_owner = race_opponent
	race_attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	race_attacker.strength = 24
	race_opponent.frontline_zones[1].add_card(race_attacker)
	var race_danger := race_bot._forecast_incoming_follower_loss()
	if race_danger <= 0:
		failures.append("Fixture failed to project an incoming push while the bot owns the race")
	if str(race_bot._strategy_posture().get("posture", "balanced")) != "race":
		failures.append("Fixture failed to classify a winning race clock as race posture")
	if not race_bot._plan_defensive_stance(race_danger).is_empty():
		failures.append("Bot planned a preservation stance switch while winning the race")

func _check_bot_defensive_mode_switch_option_gate(failures: PackedStringArray) -> void:
	# The preservation block keeps a healthy-follower body aggressive to
	# preserve its attack option — but only when an attack option actually
	# exists. In an even-clock balanced game, a body with no profitable
	# creature attack and no safe followers poke must fall through to the
	# casualty-savings math and flip against attackers its defensive RES
	# walls, while a body that still owns a safe poke stays aggressive.
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 100
	player.mana = 4
	opponent.followers = 100
	opponent.mana = 8
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var wall := CreatureCard.new()
	wall.card_name = "Fixture Option-Gate Wall"
	wall.card_owner = player
	wall.creature_mode = Card.CreatureMode.AGGRESSIVE
	wall.strength = 20
	wall.resilience = 40
	wall.speed = 2
	player.frontline_zones[0].add_card(wall)
	var poker := CreatureCard.new()
	poker.card_name = "Fixture Option-Gate Poker"
	poker.card_owner = player
	poker.creature_mode = Card.CreatureMode.AGGRESSIVE
	poker.strength = 24
	poker.resilience = 24
	poker.speed = 5
	player.frontline_zones[1].add_card(poker)
	var heavy := CreatureCard.new()
	heavy.card_name = "Fixture Option-Gate Heavy"
	heavy.card_owner = opponent
	heavy.creature_mode = Card.CreatureMode.AGGRESSIVE
	heavy.strength = 35
	heavy.speed = 2
	opponent.frontline_zones[1].add_card(heavy)
	var skirmisher := CreatureCard.new()
	skirmisher.card_name = "Fixture Option-Gate Skirmisher"
	skirmisher.card_owner = opponent
	skirmisher.creature_mode = Card.CreatureMode.AGGRESSIVE
	skirmisher.strength = 33
	skirmisher.speed = 2
	opponent.frontline_zones[2].add_card(skirmisher)
	var danger := bot._forecast_incoming_follower_loss()
	if danger <= 0 or danger >= player.followers:
		failures.append("Fixture failed to project a non-lethal even-clock push for the mode-switch option gate")
	if str(bot._strategy_posture().get("posture", "balanced")) != "balanced":
		failures.append("Fixture failed to keep even clocks in balanced posture")
	var opponents: Array[Card] = bot._get_board_creatures(opponent)
	if bot._get_defensive_mode_switch_score(wall, opponents) <= 0:
		failures.append("Bot refused a defensive flip for a body with no real attack option in balanced posture")
	if bot._get_best_defensive_mode_switch_candidate() != wall:
		failures.append("Bot did not pick the optionless wall as its defensive mode-switch candidate")
	if bot._get_defensive_mode_switch_score(poker, opponents) != -1:
		failures.append("Bot flipped a body that still owns a safe followers poke")

func _check_bot_next_turn_lethal(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 10
	player.mana = 3
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var attacker := CreatureCard.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = 20
	opponent.frontline_zones[0].add_card(attacker)
	var weak := CreatureCard.new()
	weak.card_owner = player
	weak.creature_mode = Card.CreatureMode.AGGRESSIVE
	weak.strength = 5
	player.frontline_zones[0].add_card(weak)
	var defender := CreatureCard.new()
	defender.card_owner = player
	defender.creature_mode = Card.CreatureMode.DEFENSIVE
	defender.resilience = 25
	player.frontline_zones[1].add_card(defender)
	var mummu := Mummu.new()
	mummu.card_owner = player
	player.god_zone.add_card(mummu)
	var danger := bot._forecast_incoming_follower_loss()
	if danger < player.followers or bot._forecast_incoming_follower_loss({"removed": [weak]}) >= player.followers:
		failures.append("Bot did not distinguish lethal through a weak aggressive creature from a covered direct attack")
	var stance: Dictionary = bot._plan_defensive_stance(danger).get("command", {})
	if stance.get("card_uid") != weak.uid:
		failures.append("Bot did not identify a defensive stance change that prevents lethal")
	weak.creature_major_action_used = true
	weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	var entropic: Dictionary = bot._plan_removal_god_ability(danger).get("command", {})
	if entropic.get("target_uid") != weak.uid:
		failures.append("Mummu failed to shelve the exposed creature when it could not change stance")
	elif not bot._take_main_phase_action():
		failures.append("Mummu did not submit the Entropic Force survival plan")
	else:
		for _step in range(8):
			manager.advance_priority()
		if weak.current_zone != player.deck_zone:
			failures.append("Entropic Force survival plan did not resolve through the match command path")
		else:
			player.move_card(weak, player.frontline_zones[0])
			weak.creature_mode = Card.CreatureMode.AGGRESSIVE
			weak.creature_major_action_used = true
			weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	player.god_zone.remove_card(mummu)
	var tez := TezcatlipocaTheSmokingMirror.new()
	tez.card_owner = player
	player.god_zone.add_card(tez)
	var offering: Dictionary = bot._plan_god_manifestation({}, danger).get("command", {})
	if offering.get("target_uid") != weak.uid:
		failures.append("Necoc Yaotl failed to sacrifice the creature exposing its followers to lethal")
	player.god_zone.remove_card(tez)
	var spell := BitMeseri.new()
	spell.card_owner = player
	player.hand_zone.add_card(spell)
	var alternative := CreatureCard.new()
	alternative.card_owner = opponent
	alternative.creature_mode = Card.CreatureMode.AGGRESSIVE
	alternative.strength = 15
	opponent.frontline_zones[1].add_card(alternative)
	var bit_meseri: Dictionary = bot._get_best_strategy_action([], {}, danger).get("command", {})
	if bit_meseri.get("target_uid") != weak.uid:
		failures.append("Bot failed to consider voiding its own creature when removing either individual attacker still leaves lethal")
	player.guard = 15
	if bot._forecast_incoming_follower_loss() >= player.followers:
		failures.append("Bot forecast lethal even though Guard and the defensive creature cover both attacks")
	player.guard = 0
	if not bot._take_main_phase_action():
		failures.append("Bot did not submit the Bit Meseri survival plan")
	else:
		for _step in range(8):
			manager.advance_priority()
		if weak.current_zone != player.abyss_zone:
			failures.append("Bit Meseri survival plan did not resolve through the match command path")
		else:
			player.move_card(weak, player.frontline_zones[0])
			weak.creature_mode = Card.CreatureMode.AGGRESSIVE
			weak.creature_major_action_used = true
			weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	var nimue := Nimue.new()
	player.mana = 3
	player.god_zone.add_card(mummu)
	mummu.is_muted = true
	nimue.card_owner = player
	nimue.creature_mode = Card.CreatureMode.DEFENSIVE
	player.reserve_zones[0].add_card(nimue)
	var entomb_plan := bot._get_best_strategy_action([], {}, danger)
	var entomb: Dictionary = entomb_plan.get("command", {})
	if entomb.get("source_uid") != nimue.uid or entomb.get("target_uid") != weak.uid:
		failures.append("Nimue did not consider shelving her own exposed creature")
	elif not bot._submit_strategy_plan(entomb_plan):
		failures.append("Nimue's Entomb survival plan was rejected")
	else:
		for _step in range(8):
			manager.advance_priority()
		if weak.current_zone != player.deck_zone:
			failures.append("Nimue's Entomb survival plan did not resolve")
		else:
			player.move_card(weak, player.frontline_zones[0])
			weak.creature_mode = Card.CreatureMode.AGGRESSIVE
			weak.creature_major_action_used = true
			weak.creature_minor_actions_used = weak.get_max_minor_creature_actions_per_turn()
	player.reserve_zones[0].remove_card(nimue)
	var pyre := AncientPyre.new()
	pyre.card_owner = player
	player.frontline_zones[2].add_card(pyre)
	weak.resilience = AncientPyre.EFFECT_AMOUNT
	var flame: Dictionary = bot._get_best_strategy_action([], {}, danger).get("command", {})
	if flame.get("source_uid") != pyre.uid or flame.get("target_uid") != weak.uid:
		failures.append("Ancient Pyre did not consider destroying its own exposed creature")
	weak.resilience += 1
	if bot._effect_follower_safety_gain(pyre, weak, danger, player.mana - AncientPyre.ACTIVATION_COST) != 0:
		failures.append("Ancient Pyre was credited with destroying a creature above its damage threshold")
	weak.resilience -= 1
	weak.add_status_effect("berserker_mead_guard", "Preflight")
	if bot._effect_follower_safety_gain(pyre, weak, danger, player.mana - AncientPyre.ACTIVATION_COST) != 0:
		failures.append("Ancient Pyre was credited with destroying a protected creature")
	weak.remove_status_effects_by_name("berserker_mead_guard")
	player.frontline_zones[2].remove_card(pyre)
	weak.card_types.append("Animal")
	var offering_bear := BrownBear.new()
	offering_bear.card_owner = player
	player.reserve_zones[1].add_card(offering_bear)
	var demon := Asakku.new()
	demon.card_owner = player
	player.graveyard_zone.add_card(demon)
	var key := KeyOfSolomon.new()
	key.card_owner = player
	player.hand_zone.add_card(key)
	var sacrifice_plan: Dictionary = bot._plan_sacrifice_spell(key, danger).get("command", {})
	if sacrifice_plan.get("sacrifice_uid") != weak.uid:
		failures.append("A sacrifice spell did not choose the friendly payment that prevents lethal")
	player.hand_zone.remove_card(key)
	player.reserve_zones[1].remove_card(offering_bear)
	var fenrir := Fenrir.new()
	fenrir.card_owner = player
	player.reserve_zones[0].add_card(fenrir)
	var impact := bot._choose_impact_removal_target(fenrir, [weak.uid, attacker.uid, alternative.uid])
	if impact != weak.uid:
		failures.append("Fenrir's removal prompt did not choose the friendly target that prevents lethal")
	player.reserve_zones[0].remove_card(fenrir)
	var ragnarok := Ragnarok.new()
	ragnarok.card_owner = player
	player.power_zones[0].add_card(ragnarok)
	player.mana = ragnarok.get_unlock_mana_cost(game)
	var wipe: Dictionary = bot._plan_power_unlock(danger).get("command", {})
	if wipe.get("power_uid") != ragnarok.uid:
		failures.append("Bot overlooked a legal Ragnarok unlock that prevents lethal")
	bot.detach()

# A ready Mead of Poetry must fund paid lines the current stock cannot cover —
# the flagship case being an Ancient Pyre conversion that empties the
# opponent's follower stock. The brew is submitted first, and the next
# planning pass takes the funded conversion on the grown stock.
func _check_bot_brew_funds_pyre_lethal(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 1
	opponent.followers = 5
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var pyre := AncientPyre.new()
	pyre.card_owner = player
	player.reserve_zones[0].add_card(pyre)
	var attacks := bot._get_combat_candidates()
	var baseline := bot._plan_combat(attacks)
	var unfunded := bot._get_best_strategy_action(attacks, baseline)
	if bool(unfunded.get("lethal", false)):
		failures.append("Bot planned an unfunded Ancient Pyre conversion lethal")
	var mead := MeadOfPoetry.new()
	mead.card_owner = player
	mead.is_prepared = true
	mead.is_face_down = true
	player.reserve_zones[1].add_card(mead)
	game.prepared_charms[mead] = game.turn_number - 1
	var plan := bot._get_best_strategy_action(attacks, baseline)
	if not bool(plan.get("lethal", false)):
		failures.append("Bot missed the Mead-funded Ancient Pyre conversion lethal")
	elif not bool(plan.get("brew_setup", false)):
		failures.append("Bot did not tag the unpaid Pyre conversion for the Mead brew")
	elif not bot._take_main_phase_action():
		failures.append("Bot failed to submit the Mead brew for the Pyre lethal")
	else:
		for _step in range(8):
			manager.advance_priority()
		if player.mana < 1 + MeadOfPoetry.MANA_GAIN:
			failures.append("Mead brew did not bank its mana before the conversion")
		elif not bot._take_main_phase_action():
			failures.append("Bot failed to submit the funded Pyre conversion after brewing")
		else:
			for _step in range(8):
				manager.advance_priority()
			if opponent.followers > 0:
				failures.append("Bot brewed but never converted the remaining followers")
	bot.detach()

# The Mead brew generalizes beyond abilities: a summon only the brew can pay
# is tagged, the Mead is submitted first, and the next pass replays the same
# summon on the grown stock.
func _check_bot_brew_funds_summon(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 1
	player.followers = 50
	opponent.followers = 100
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var creature := CreatureCard.new()
	creature.card_name = "Fixture Summon"
	creature.mana_cost = 5
	creature.strength = 20
	creature.resilience = 20
	creature.speed = 2
	creature.card_owner = player
	player.hand_zone.add_card(creature)
	var danger := bot._forecast_incoming_follower_loss()
	var attacks := bot._get_combat_candidates()
	var baseline := bot._plan_combat(attacks)
	var unfunded := bot._plan_creature_summon(danger, attacks, baseline)
	if not unfunded.is_empty() and str(unfunded.get("command", {}).get("card_uid", "")) == creature.uid:
		failures.append("Bot planned a summon it could not pay without brewing")
	var mead := MeadOfPoetry.new()
	mead.card_owner = player
	mead.is_prepared = true
	mead.is_face_down = true
	player.reserve_zones[1].add_card(mead)
	game.prepared_charms[mead] = game.turn_number - 1
	var plan := bot._plan_creature_summon(danger, attacks, baseline)
	if not bool(plan.get("brew_setup", false)) or str(plan.get("command", {}).get("card_uid", "")) != creature.uid:
		failures.append("Bot did not tag the brew-funded summon")
	elif not bot._take_main_phase_action():
		failures.append("Bot failed to submit the Mead brew for the summon")
	else:
		for _step in range(8):
			manager.advance_priority()
		if player.mana < 1 + MeadOfPoetry.MANA_GAIN:
			failures.append("Mead brew did not bank its mana before the summon")
		elif not bot._take_main_phase_action():
			failures.append("Bot failed to submit the funded summon after brewing")
		else:
			for _step in range(8):
				manager.advance_priority()
			if creature.current_zone == null or not creature.current_zone.is_board_zone():
				failures.append("Bot brewed but the summon never landed")
	bot.detach()

# Power unlocks follow the same brew rule: a face-down power priced past the
# current stock is tagged, the Mead is submitted first, and the unlock replays
# on the grown stock.
func _check_bot_brew_funds_unlock(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 1
	player.followers = 30
	opponent.followers = 100
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var attacker := CreatureCard.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = 20
	attacker.speed = 2
	opponent.frontline_zones[0].add_card(attacker)
	var power := Ragnarok.new()
	power.card_owner = player
	power.mana_cost = 4
	player.power_zones[0].add_card(power)
	var danger := bot._forecast_incoming_follower_loss()
	var attacks := bot._get_combat_candidates()
	var baseline := bot._plan_combat(attacks)
	if danger <= 0:
		failures.append("Unlock brew fixture lost its incoming threat")
	var unfunded := bot._plan_power_unlock(danger, attacks, baseline)
	if not unfunded.is_empty() and str(unfunded.get("command", {}).get("power_uid", "")) == power.uid:
		failures.append("Bot planned an unlock it could not pay without brewing")
	var mead := MeadOfPoetry.new()
	mead.card_owner = player
	mead.is_prepared = true
	mead.is_face_down = true
	player.reserve_zones[1].add_card(mead)
	game.prepared_charms[mead] = game.turn_number - 1
	var plan := bot._plan_power_unlock(danger, attacks, baseline)
	if not bool(plan.get("brew_setup", false)) or str(plan.get("command", {}).get("power_uid", "")) != power.uid:
		failures.append("Bot did not tag the brew-funded unlock")
	elif not bot._take_main_phase_action():
		failures.append("Bot failed to submit the Mead brew for the unlock")
	else:
		for _step in range(8):
			manager.advance_priority()
		if player.mana < 1 + MeadOfPoetry.MANA_GAIN:
			failures.append("Mead brew did not bank its mana before the unlock")
		elif not bot._take_main_phase_action():
			failures.append("Bot failed to submit the funded unlock after brewing")
		else:
			for _step in range(8):
				manager.advance_priority()
			if power.is_face_down:
				failures.append("Bot brewed but the power never unlocked")
	bot.detach()

# Immortal Techniques refunds each spell or Ancient hex while a friendly Mage
# is fielded: the refund must price into the bot's cast economics, and it must
# know the +1 only flows with the power face-up and the Mage on the field.
func _check_bot_immortal_techniques_refund(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 3
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var power := ImmortalTechniques.new()
	power.card_owner = player
	# PowerCard starts face-down (locked); unlock it so the passive is live.
	power.is_face_down = false
	player.power_zones[0].add_card(power)
	var spell := FallOfTheMighty.new()
	spell.card_owner = player
	player.hand_zone.add_card(spell)
	var ancient_hex := SapStrength.new()
	ancient_hex.card_owner = player
	player.hand_zone.add_card(ancient_hex)
	var neutral_hex := Sap.new()
	neutral_hex.card_owner = player
	player.hand_zone.add_card(neutral_hex)
	if bot._immortal_techniques_refund_gain(spell) != 0 \
			or bot._immortal_techniques_refund_gain(ancient_hex) != 0:
		failures.append("Bot forecast an Immortal Techniques refund with no Mage on the field")
	var mage := CreatureCard.new()
	mage.card_name = "Fixture Mage"
	mage.card_types = ["Mage"]
	mage.card_owner = player
	player.frontline_zones[0].add_card(mage)
	if bot._immortal_techniques_refund_gain(spell) != 1 \
			or bot._immortal_techniques_refund_gain(ancient_hex) != 1:
		failures.append("Bot missed the Immortal Techniques refund on a live Mage line")
	if bot._immortal_techniques_refund_gain(neutral_hex) != 0:
		failures.append("Bot credited the Immortal Techniques refund to a non-Ancient hex")
	if bot._immortal_techniques_refund_gain(mage) != 0:
		failures.append("Bot credited the Immortal Techniques refund to a creature")
	power.is_face_down = true
	if bot._immortal_techniques_refund_gain(spell) != 0:
		failures.append("Bot forecast an Immortal Techniques refund from a face-down power")
	bot.detach()

# Pazuzu's Locust Plague taxes the stock the bot carries past this turn: the
# forecast must see each visible enemy copy, price it into cross-turn mana
# projections, and stay blind to hidden bodies it cannot know about.
func _check_bot_pazuzu_drain_forecast(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 4
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	if bot._incoming_mana_drain() != 0:
		failures.append("Bot forecast a Pazuzu drain with no Pazuzu on the field")
	var pazuzu := Pazuzu.new()
	pazuzu.card_owner = opponent
	opponent.frontline_zones[0].add_card(pazuzu)
	if bot._incoming_mana_drain() != Pazuzu.MANA_DRAIN:
		failures.append("Bot missed Pazuzu's Locust Plague in its mana forecast")
	var income := game.get_automatic_upkeep_mana_gain(player, -1) \
		+ game.get_effective_upkeep_mana_gain(game.get_base_upkeep_mana_gain(), player)
	if BotCardStrategyScript.projected_upkeep_mana(bot, 1) != player.mana + income - Pazuzu.MANA_DRAIN:
		failures.append("Bot did not subtract Pazuzu's drain from its projected upkeep mana")
	pazuzu.is_stealth = true
	if bot._incoming_mana_drain() != 0:
		failures.append("Bot forecast Pazuzu's drain through a hidden body it cannot see")
	bot.detach()

# Mummu's Entropic Force is a ramp engine, not only a survival removal: the
# bot must shelve devalued fuel (expired Warding Stones, doomed Tablet of Life
# summons, borrowed bodies about to return) for its level-minus-one mana, value
# shelving that completes this turn's unaffordable summon, and price a Siren's
# Song steal higher because Entropic Force can end the temporary control by
# burying the borrowed card in its owner's deck.
func _check_bot_mummu_entropic_force_economy(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 40
	opponent.followers = 40
	player.mana = 2
	# A stocked deck keeps marginal mana at its full rate, as in a real match.
	for index in range(4):
		var deck_card := CreatureCard.new()
		deck_card.card_owner = player
		deck_card.mana_cost = 5 + (index % 2)
		player.deck_zone.add_card(deck_card)
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var mummu := Mummu.new()
	mummu.card_owner = player
	player.god_zone.add_card(mummu)
	var stones: Array[Card] = []
	for index in range(3):
		var stone := WardingStone.new()
		stone.card_owner = player
		player.reserve_zones[index].add_card(stone)
		stones.append(stone)
	var ramp: Dictionary = bot._plan_removal_god_ability(bot._forecast_incoming_follower_loss()).get("command", {})
	if not stones.any(func(stone: Card) -> bool: return ramp.get("target_uid") == stone.uid):
		failures.append("Mummu did not plan Entropic Force on an expired Warding Stone")
	else:
		var shelved := false
		for _step in range(4):
			if not bot._take_main_phase_action():
				break
			for _advance in range(8):
				manager.advance_priority()
			if stones.any(func(stone: Card) -> bool: return stone.current_zone == player.deck_zone):
				shelved = true
				break
		if not shelved or player.mana != 3:
			failures.append("Mummu did not ramp an expired Warding Stone through the main phase")
	# A doomed Tablet of Life resurrection is preferred over a healthy body:
	# shelving banks its level in mana and saves the card from the turn-end
	# graveyard instead of paying a healthy card's board value.
	var healthy := CreatureCard.new()
	healthy.card_owner = player
	healthy.creature_mode = Card.CreatureMode.DEFENSIVE
	healthy.strength = 8
	healthy.resilience = 12
	player.frontline_zones[0].add_card(healthy)
	var doomed := CreatureCard.new()
	doomed.card_owner = player
	doomed.creature_mode = Card.CreatureMode.AGGRESSIVE
	doomed.strength = 5
	doomed.resilience = 6
	doomed.level = 4
	doomed.creature_major_action_used = true
	doomed.add_status_effect(
		TabletOfLife.DESTROY_AT_TURN_END_STATUS,
		"Preflight",
		null,
		player,
		{"expires_turn": game.turn_number, "remove_when_leaves_board": true}
	)
	player.frontline_zones[1].add_card(doomed)
	if bot._plan_removal_god_ability(bot._forecast_incoming_follower_loss()).get("command", {}).get("target_uid") != doomed.uid:
		failures.append("Mummu preferred a healthy body over a doomed Tablet summon for Entropic Force")
	player.frontline_zones[0].remove_card(healthy)
	player.frontline_zones[1].remove_card(doomed)
	# A borrowed body scheduled to return to the opponent is premium fuel:
	# Entropic Force ends the temporary control, burying the card in its
	# owner's deck bottom and pocketing the mana.
	var borrowed := CreatureCard.new()
	borrowed.card_name = "Fixture Borrowed Body"
	borrowed.card_owner = opponent
	borrowed.creature_mode = Card.CreatureMode.AGGRESSIVE
	borrowed.strength = 15
	borrowed.resilience = 20
	borrowed.level = 3
	borrowed.creature_major_action_used = true
	opponent.frontline_zones[0].add_card(borrowed)
	var song := SirensSong.new()
	song.card_owner = player
	if not game.grant_temporary_control_of_creature(borrowed, player, song):
		failures.append("Fixture failed to grant temporary control of the borrowed body")
	elif bot._plan_removal_god_ability(bot._forecast_incoming_follower_loss()).get("command", {}).get("target_uid") != borrowed.uid:
		failures.append("Mummu did not prefer ending a temporary control with Entropic Force")
	borrowed.current_zone.remove_card(borrowed)
	opponent.frontline_zones[0].add_card(borrowed)
	# Shelving that completes this turn's unaffordable summon is worth more
	# than the same shelve with the summon still out of reach.
	var hand_creature := CreatureCard.new()
	hand_creature.card_owner = player
	hand_creature.strength = 8
	hand_creature.resilience = 12
	hand_creature.mana_cost = player.mana + 1
	player.hand_zone.add_card(hand_creature)
	var funded := int(bot._plan_removal_god_ability(bot._forecast_incoming_follower_loss()).get("score", 0))
	player.hand_zone.remove_card(hand_creature)
	var unfunded := int(bot._plan_removal_god_ability(bot._forecast_incoming_follower_loss()).get("score", 0))
	if funded < unfunded + 2000:
		failures.append("Entropic Force did not value shelving to fund this turn's unaffordable summon")
	# A Siren's Song steal is worth more with Mummu leading because the
	# borrow can be ended permanently with Entropic Force.
	var steal_score := BotCardStrategyScript.target_score(bot, song, borrowed)
	mummu.is_muted = true
	var muted_score := BotCardStrategyScript.target_score(bot, song, borrowed)
	if steal_score <= muted_score:
		failures.append("Siren's Song steal did not gain value from Mummu's Entropic Force follow-up")
	bot.detach()

# Mummu, Active God's Entropy chooses Prime or Shelve for any card it
# destroys. Prime is the default draw-lock: the victim rides its owner's
# next draw, so a non-answer burns a fresh topdeck (worst against a thin
# hand), while a stolen body recovers on top of the bot's own deck. Shelve
# wins only when the victim's return would threaten Mummu in combat.
# Combat projections price both sides of the choice, and Mummu's own death
# never starts God Death because its removal reactivates the stored god.
func _check_bot_mummu_active_entropy(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 40
	opponent.followers = 40
	player.mana = 5
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	# God Death pricing first, while no Active God shares the board: a
	# stored-god manifestation death still bleeds followers, Mummu Active's
	# does not because its removal reactivates the stored normal god.
	var thor := ThorActive.new()
	thor.card_owner = player
	player.frontline_zones[0].add_card(thor)
	if bot._combat_god_death_cost(player, [thor], 0) <= 0:
		failures.append("A stored-god Active God death was not priced as God Death")
	player.frontline_zones[0].remove_card(thor)
	var mummu := MummuActive.new()
	mummu.card_owner = player
	player.frontline_zones[0].add_card(mummu)
	if bot._combat_god_death_cost(player, [mummu], 0) != 0:
		failures.append("Killing Mummu Active was priced as God Death")
	# A non-answer body against a draw-starved opponent is pure lock fuel:
	# prime it even though it is worthless, because the lock denies the
	# fresh draw the answer would have been.
	var junk := CreatureCard.new()
	junk.card_name = "Fixture Junk Body"
	junk.card_owner = opponent
	junk.creature_mode = Card.CreatureMode.DEFENSIVE
	junk.strength = 2
	junk.resilience = 2
	junk.level = 2
	opponent.frontline_zones[0].add_card(junk)
	if bot._choose_mummu_entropy_placement(mummu, junk) != MummuActive.ENTROPY_PRIME:
		failures.append("Mummu Active did not prime a non-answer victim against a draw-starved opponent")
	# A body that kills Mummu in combat comes back as a real threat on top
	# of the deck, so shelve it instead of priming it.
	var answer := CreatureCard.new()
	answer.card_name = "Fixture Mummu Answer"
	answer.card_owner = opponent
	answer.creature_mode = Card.CreatureMode.DEFENSIVE
	answer.strength = 40
	answer.resilience = 40
	answer.level = 7
	opponent.frontline_zones[1].add_card(answer)
	if bot._choose_mummu_entropy_placement(mummu, answer) != MummuActive.ENTROPY_SHELVE:
		failures.append("Mummu Active primed a victim that answers Mummu in combat")
	opponent.frontline_zones[1].remove_card(answer)
	# A fat hand mutes the lock but never zeroes it: the primed non-answer
	# keeps squatting on the topdeck and stays free information, so junk
	# remains prime fuel while the denial itself fades with hand size.
	var starved_lock := bot._mummu_prime_lock_value(opponent)
	for _index in range(5):
		var filler := CreatureCard.new()
		filler.card_owner = opponent
		opponent.hand_zone.add_card(filler)
	var fat_lock := bot._mummu_prime_lock_value(opponent)
	if fat_lock <= 0 or fat_lock >= starved_lock:
		failures.append("Mummu Active's draw-lock value did not fade with hand size to a positive floor")
	if bot._choose_mummu_entropy_placement(mummu, junk) != MummuActive.ENTROPY_PRIME:
		failures.append("Mummu Active did not keep priming junk against a fat hand")
	for card in opponent.hand_zone.cards.duplicate():
		opponent.hand_zone.remove_card(card)
	# A stolen body the opponent controls still belongs to the bot: priming
	# returns it to the top of the bot's own deck instead of burying it.
	var stolen := CreatureCard.new()
	stolen.card_name = "Fixture Stolen Body"
	stolen.card_owner = player
	stolen.creature_mode = Card.CreatureMode.AGGRESSIVE
	stolen.strength = 10
	stolen.resilience = 10
	stolen.level = 3
	opponent.frontline_zones[2].add_card(stolen)
	if bot._choose_mummu_entropy_placement(mummu, stolen) != MummuActive.ENTROPY_PRIME:
		failures.append("Mummu Active did not prime its own stolen body back onto the deck")
	opponent.frontline_zones[2].remove_card(stolen)
	# Attack projections tag the entropy outcome: our Mummu killing a
	# non-answer banks a positive draw-lock, and an enemy Mummu killing our
	# junk — as a declared target or through a suicidal recoil — charges the
	# bot for the locked draw.
	var attack := CardAction.new()
	attack.type = CardAction.Type.ATTACK
	attack.source_player = player
	attack.attacker = mummu
	attack.target = junk
	if int(bot._estimate_attack_economy(attack, null, 0, 0).get("mummu_entropy_value", 0)) <= 0:
		failures.append("Mummu Active attacks did not price the entropy draw-lock")
	var bot_junk := CreatureCard.new()
	bot_junk.card_name = "Fixture Bot Junk"
	bot_junk.card_owner = player
	bot_junk.creature_mode = Card.CreatureMode.DEFENSIVE
	bot_junk.strength = 2
	bot_junk.resilience = 2
	bot_junk.level = 2
	player.frontline_zones[1].add_card(bot_junk)
	var enemy_mummu := MummuActive.new()
	enemy_mummu.card_owner = opponent
	# Aggressive stance makes the recoil kill mutual: the chump dies to the
	# counter-strength instead of bouncing off a defensive body.
	enemy_mummu.creature_mode = Card.CreatureMode.AGGRESSIVE
	opponent.frontline_zones[1].add_card(enemy_mummu)
	var enemy_attack := CardAction.new()
	enemy_attack.type = CardAction.Type.ATTACK
	enemy_attack.source_player = opponent
	enemy_attack.attacker = enemy_mummu
	enemy_attack.target = bot_junk
	if int(bot._estimate_attack_economy(enemy_attack, null, 0, 0).get("mummu_entropy_value", 0)) >= 0:
		failures.append("An enemy Mummu Active kill was not priced against the bot's draws")
	var chump := CreatureCard.new()
	chump.card_name = "Fixture Bot Chump"
	chump.card_owner = player
	chump.creature_mode = Card.CreatureMode.AGGRESSIVE
	chump.strength = 2
	chump.resilience = 2
	chump.level = 2
	player.frontline_zones[2].add_card(chump)
	var suicide := CardAction.new()
	suicide.type = CardAction.Type.ATTACK
	suicide.source_player = player
	suicide.attacker = chump
	suicide.target = enemy_mummu
	if int(bot._estimate_attack_economy(suicide, null, 0, 0).get("mummu_entropy_value", 0)) >= 0:
		failures.append("A recoil death to an enemy Mummu Active was not priced against the bot's draws")
	bot.detach()

# Mummu's Entropic Force pre-removes every own card a self-cast wipe would
# destroy when the shelf (deck-bottom banking plus level-minus-one mana) beats
# the graveyard death: the wipe line prices the shelf credit, the plan submits
# the god abilities ahead of the sweep, and The Deluge resolves off a
# calculated self-summon trigger under the same shelf-first ordering.
func _check_bot_mummu_wipe_shelve_economy(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 40
	opponent.followers = 40
	player.mana = 8
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var mummu := Mummu.new()
	mummu.card_owner = player
	player.god_zone.add_card(mummu)
	# The sweeps are clearly worth it: three huge enemy bodies die, and the
	# only own casualties are low-level bodies the shelf converts into mana.
	for index in range(3):
		var brute := CreatureCard.new()
		brute.card_name = "Fixture Enemy Brute %d" % index
		brute.card_owner = opponent
		brute.creature_mode = Card.CreatureMode.DEFENSIVE
		brute.strength = 30
		brute.resilience = 30
		brute.level = 5
		opponent.frontline_zones[index].add_card(brute)
	var fodder := CreatureCard.new()
	fodder.card_name = "Fixture Own Fodder"
	fodder.card_owner = player
	fodder.creature_mode = Card.CreatureMode.DEFENSIVE
	fodder.strength = 2
	fodder.resilience = 6
	fodder.level = 3
	player.frontline_zones[0].add_card(fodder)
	var famine := Famine.new()
	famine.card_owner = player
	player.hand_zone.add_card(famine)
	if bot._mummu_wipe_shelve_credit(fodder) <= 0:
		failures.append("Mummu did not price a wipe-doomed own card as Entropic Force fuel")
	if not bot._mummu_wipe_shelve_targets(famine).any(func(target: Card) -> bool: return target == fodder):
		failures.append("Famine's doomed own card was not listed for Entropic Force shelving")
	mummu.is_muted = true
	if bot._mummu_wipe_shelve_credit(fodder) != 0 or not bot._mummu_wipe_shelve_targets(famine).is_empty():
		failures.append("A muted Mummu still priced wipe-doomed own cards as shelf fuel")
	mummu.is_muted = false
	var wipe_plan := bot._get_best_strategy_action([], {}, 0)
	if str(wipe_plan.get("command", {}).get("type", "")) != "cast_spell" \
			or str(wipe_plan["command"].get("spell_uid", "")) != famine.uid \
			or str(wipe_plan.get("mummu_shelve_setup", "")) != famine.uid:
		failures.append("Famine's plan did not tag the Entropic Force shelf setup")
	# Submission order: the shelf is submitted in the wipe plan's place, and
	# the shelved body banks into the deck while Famine waits in hand.
	var mana_before := player.mana
	if not bot._submit_strategy_plan(wipe_plan):
		failures.append("Famine's shelf setup did not submit through the strategy plan")
	else:
		var shelved := false
		for _step in range(4):
			for _advance in range(8):
				manager.advance_priority()
			if fodder.current_zone == player.deck_zone:
				shelved = true
				break
		if not shelved or player.mana != mana_before + fodder.get_effective_level() - 1:
			failures.append("Entropic Force did not bank the wipe-doomed own card for its mana")
		bot._mana_econ_cache = {}
	# The Deluge resolves off a calculated self-summon: the trigger is a cheap
	# face-up hand summon, and the line still carries the shelf setup while
	# Mummu can shelve the sweep's own doomed cards first.
	var deluge := TheDeluge.new()
	deluge.card_owner = player
	deluge.is_prepared = true
	deluge.is_face_down = true
	player.reserve_zones[2].add_card(deluge)
	game.prepared_hexes[deluge] = game.turn_number - 1
	var fodder_two := CreatureCard.new()
	fodder_two.card_name = "Fixture Own Fodder Two"
	fodder_two.card_owner = player
	fodder_two.creature_mode = Card.CreatureMode.DEFENSIVE
	fodder_two.strength = 2
	fodder_two.resilience = 6
	fodder_two.level = 2
	player.frontline_zones[1].add_card(fodder_two)
	var cheap := CreatureCard.new()
	cheap.card_name = "Fixture Trigger Body"
	cheap.card_owner = player
	cheap.strength = 1
	cheap.resilience = 1
	cheap.level = 1
	cheap.mana_cost = 1
	player.hand_zone.add_card(cheap)
	var deluge_plan := bot._plan_self_deluge(0)
	if deluge_plan.is_empty() or str(deluge_plan.get("command", {}).get("type", "")) != "play_creature" \
			or str(deluge_plan["command"].get("card_uid", "")) != cheap.uid \
			or bool(deluge_plan["command"].get("stealth", true)) \
			or str(deluge_plan.get("mummu_shelve_setup", "")) != deluge.uid:
		failures.append("The Deluge self-summon line was not planned with a face-up trigger and shelf setup")
	bot.detach()

# A Siren's Song steal is only worth casting for lines the bot can actually
# spend this turn, and the turn spent holding the borrow must model the body
# as leaving at turn end: the danger forecast counts it as the owner's
# returning attacker instead of bot-side defense, no stance plan flips it
# defensive, and a stuck defensive borrow still flips aggressive so the owner
# re-receives it in attack stance.
func _check_bot_sirens_song_follow_through(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 20
	opponent.followers = 40
	player.mana = 6
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var song := SirensSong.new()
	song.card_owner = player
	# Pricing: an aggressive frontline borrow attacks (their last body even
	# pokes their own followers), a defensive frontline borrow is one minor
	# action from that attack, and a defensive reserve borrow can neither
	# flip nor advance into an attack this turn, so it prices as denial only.
	var raider := CreatureCard.new()
	raider.card_name = "Fixture Raider"
	raider.card_owner = opponent
	raider.creature_mode = Card.CreatureMode.AGGRESSIVE
	raider.strength = 8
	raider.resilience = 8
	opponent.frontline_zones[0].add_card(raider)
	if BotCardStrategyScript.target_score(bot, song, raider) <= 0:
		failures.append("Siren's Song did not price an aggressive frontline steal's attack")
	raider.creature_mode = Card.CreatureMode.DEFENSIVE
	if BotCardStrategyScript.target_score(bot, song, raider) <= 0:
		failures.append("Siren's Song did not price a flippable frontline steal's attack")
	var wall := CreatureCard.new()
	wall.card_name = "Fixture Reserve Wall"
	wall.card_owner = opponent
	wall.creature_mode = Card.CreatureMode.DEFENSIVE
	wall.strength = 5
	wall.resilience = 20
	opponent.reserve_zones[0].add_card(wall)
	if BotCardStrategyScript.target_score(bot, song, wall) != 0:
		failures.append("Siren's Song priced an attack a defensive reserve borrow cannot make")
	opponent.reserve_zones[0].remove_card(wall)
	opponent.frontline_zones[0].remove_card(raider)
	# Forecast and follow-through: with the borrow held, the same bodies
	# attack next turn as before the steal, and the borrowed body is never
	# flipped to defensive stance no matter how loud the danger forecast is.
	var striker := CreatureCard.new()
	striker.card_name = "Fixture Striker"
	striker.card_owner = opponent
	striker.creature_mode = Card.CreatureMode.AGGRESSIVE
	striker.strength = 10
	striker.resilience = 10
	opponent.frontline_zones[1].add_card(striker)
	var loan := CreatureCard.new()
	loan.card_name = "Fixture Loan Body"
	loan.card_owner = opponent
	loan.creature_mode = Card.CreatureMode.AGGRESSIVE
	loan.strength = 8
	loan.resilience = 20
	opponent.frontline_zones[0].add_card(loan)
	var danger_before := bot._forecast_incoming_follower_loss()
	if not game.grant_temporary_control_of_creature(loan, player, song):
		failures.append("Fixture failed to grant temporary control of the loan body")
	else:
		var danger_during := bot._forecast_incoming_follower_loss()
		if danger_during < danger_before:
			failures.append("Borrowed body still counted as bot-side defense in the danger forecast")
		if not bot._plan_defensive_stance(danger_during).is_empty():
			failures.append("Bot planned a defensive stance switch while its only body was borrowed")
		if bot._get_defensive_mode_switch_score(loan, bot._get_board_creatures(opponent)) != -1:
			failures.append("Bot scored a defensive stance switch on a borrowed body")
		# A defensive borrow with no profitable attack still flips aggressive:
		# it cannot guard the bot after this turn, and returning it aggressive
		# makes the owner pay to re-defend it.
		loan.creature_mode = Card.CreatureMode.DEFENSIVE
		if bot._get_mode_switch_score(loan, bot._get_board_creatures(opponent)) <= 0:
			failures.append("Bot refused to flip a defensive borrowed body aggressive before returning it")
		# A borrowed body's ability belongs to the controller, not the owner,
		# so priority/response windows must be attributed to the controller.
		var stack_size_before := game.action_stack.size()
		manager._queue_authoritative_magical_action(CardAction.Type.ABILITY, loan, null, Callable())
		if game.action_stack.size() != stack_size_before + 1:
			failures.append("Ability queue did not push the borrowed body action")
		else:
			var queued_action := game.action_stack.back() as CardAction
			if queued_action.source_player != player:
				failures.append("Borrowed body ability was attributed to the owner instead of the controller")
			game.action_stack.erase(queued_action)
	bot.detach()

func _check_bot_e2_abzu_sage_retrieval(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.followers = 40
	opponent.followers = 40
	# Retrieving the level-6 Enki needs 10 mana on hand, so the stock must
	# stay worth banking up to that line instead of decaying as surplus the
	# bot spends down every turn.
	player.mana = 10
	for index in range(4):
		var deck_card := CreatureCard.new()
		deck_card.card_owner = player
		deck_card.mana_cost = 1
		player.deck_zone.add_card(deck_card)
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var abzu := E2Abzu.new()
	abzu.card_owner = player
	player.hand_zone.add_card(abzu)
	var enki := EnkiLordOfEridu.new()
	enki.card_owner = player
	for zone: Zone in [player.deck_zone, player.hand_zone, player.graveyard_zone, player.frontline_zones[0]]:
		player.move_card(enki, zone)
		if not bot._plan_strategy_support().is_empty():
			failures.append("Bot planned E2-abzu for a Mer Mage with no retrieval or protection use in %s" % zone.zone_type)
	var attacker := CreatureCard.new()
	attacker.card_owner = opponent
	attacker.creature_mode = Card.CreatureMode.AGGRESSIVE
	attacker.strength = maxi(enki.strength, enki.resilience) + 1
	attacker.speed = E2Abzu.VOID_RESPONSE_SPEED
	opponent.frontline_zones[0].add_card(attacker)
	if bot._plan_strategy_support().get("command", {}).get("card_uid") != abzu.uid:
		failures.append("Bot skipped E2-abzu when it could protect Enki from a lethal attack")
	attacker.speed += 1
	if not bot._plan_strategy_support().is_empty():
		failures.append("Bot planned E2-abzu for an attack too fast for its protection")
	opponent.frontline_zones[0].remove_card(attacker)
	player.move_card(enki, player.deck_zone)
	var walk := WalkOfTheSage.new()
	walk.card_owner = player
	player.power_zones[0].add_card(walk)
	if not BotCardStrategyScript.walk_tutor_can_reach(bot, enki) or not bot._plan_strategy_support().is_empty():
		failures.append("Walk of the Sage should be able to plan its tutor with E2-abzu still in hand")
	# While both halves stand ready, a high-level Mer Sage still in the deck is
	# one Walk activation away from the Void, so its retrieval floor is spend
	# potential the same way a Voided mage's is. The 2-cost Seventh Sage pins
	# the gap: its 8-mana floor beats everything the plain card scans reach
	# (Enki's own 8-cost deck entry would mask it), so Enki sits this check out.
	player.deck_zone.remove_card(enki)
	var seventh := SeventhSageUtuabzu.new()
	seventh.card_owner = player
	player.deck_zone.add_card(seventh)
	if BotCardStrategyScript._mana_saturation_ceiling(bot) \
			< E2Abzu.RETURN_TO_HAND_COST + 1 + seventh.get_effective_level():
		failures.append("Mana ceiling ignored a reachable deck Mer Sage while the tutor line stands ready")
	player.deck_zone.remove_card(seventh)
	player.deck_zone.add_card(enki)
	player.power_zones[0].remove_card(walk)
	player.move_card(enki, player.abyss_zone)
	var retrieval_floor := E2Abzu.RETURN_TO_HAND_COST + 1 + enki.get_effective_level()
	player.mana = retrieval_floor - 1
	if not bot._plan_strategy_support().is_empty():
		failures.append("Bot built E2-abzu before it could afford to retrieve Enki")
	if BotCardStrategyScript._mana_saturation_ceiling(bot) < retrieval_floor:
		failures.append("Mana ceiling ignored a Void Mer Mage the held E2-abzu can retrieve")
	player.mana = retrieval_floor
	var build := bot._plan_strategy_support()
	if build.get("command", {}).get("card_uid") != abzu.uid or not bot._submit_strategy_plan(build):
		failures.append("Bot did not build E2-abzu for a funded Enki retrieval")
	for _advance in range(8):
		manager.advance_priority()
	var plan := bot._plan_e2_abzu_return(abzu)
	if plan.get("command", {}).get("target_uid") != enki.uid or int(plan.get("score", 0)) <= 0:
		failures.append("E2-abzu did not plan the Enki retrieval from the Void")
	var retrieved := false
	for _step in range(4):
		if not bot._take_main_phase_action():
			break
		for _advance in range(8):
			manager.advance_priority()
		if enki.current_zone == player.hand_zone:
			retrieved = true
			break
	if not retrieved:
		failures.append("Bot left a retrievable Enki stranded in the Void through the main phase")
	enki.current_zone.remove_card(enki)
	# The held line funds its own retrieval: a Voided Enki with E2-abzu
	# standing charges competing spends that dip below the retrieval floor,
	# and the upkeep mana option wins while its income is what closes the
	# funding gap. Enki goes back to the Void for these checks.
	player.move_card(enki, player.abyss_zone)
	player.mana = 3
	bot._mana_econ_cache = {}
	bot._tutor_line_cache = {}
	var hold_with_line := BotCardStrategyScript.mana_penalty(bot, 1)
	player.move_card(enki, player.graveyard_zone)
	bot._mana_econ_cache = {}
	bot._tutor_line_cache = {}
	if BotCardStrategyScript.mana_penalty(bot, 1) >= hold_with_line:
		failures.append("Competing spend paid nothing for dipping below the held tutor retrieval funding")
	player.move_card(enki, player.abyss_zone)
	bot._mana_econ_cache = {}
	bot._tutor_line_cache = {}
	var mana_gain := game.get_effective_upkeep_mana_gain(game.get_base_upkeep_mana_gain(), player)
	player.mana = E2Abzu.RETURN_TO_HAND_COST + 1 + enki.get_effective_level() - mana_gain
	if bot._choose_upkeep_option(player.frontline_zones[0]).get("choice", "") != "mana":
		failures.append("Upkeep draw won while the mana option closed the held tutor retrieval funding")
	enki.current_zone.remove_card(enki)
	# A retrieved Adapa is bought for its Silence, priced through the same
	# impact table the Seventh Sage's channel uses; a passive-only Sage
	# never reads as carrying an impact at all.
	var adapa := FirstSageAdapa.new()
	adapa.card_owner = player
	player.abyss_zone.add_card(adapa)
	var opposing_power := WalkOfTheSage.new()
	opposing_power.card_owner = opponent
	opponent.power_zones[0].add_card(opposing_power)
	if bot._sage_retrieval_impact_gain(adapa, false) <= 0:
		failures.append("Sage retrieval ignored Adapa's Silence impact")
	if bot._sage_retrieval_impact_gain(enki, false) != 0:
		failures.append("Sage retrieval priced a phantom impact on the passive-only Enki")
	bot.detach()

func _check_bot_entomb_save_ceiling(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 3
	game._upkeep_resolved_turn = game.turn_number
	player.mana = 3
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var nimue := Nimue.new()
	nimue.card_owner = player
	nimue.creature_mode = Card.CreatureMode.DEFENSIVE
	player.reserve_zones[0].add_card(nimue)
	var manifestation := ThorActive.new()
	manifestation.card_owner = opponent
	manifestation.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[0].add_card(manifestation)
	# The Entomb costs the target's level and the bot cannot afford it yet:
	# the saturation ceiling must still count it as spend potential so the
	# bot banks mana for the activation instead of spending down each turn.
	var ceiling := BotCardStrategyScript._mana_saturation_ceiling(bot)
	if ceiling < manifestation.get_effective_level():
		failures.append("Mana ceiling ignored a live premium Entomb target the bot should be saving for")
	bot.detach()

func _check_standing_bot_seeks(failures: PackedStringArray) -> void:
	var lobby := LobbyServerScript.new()
	lobby.is_listening = true
	lobby.match_history_store = MatchHistoryStoreScript.new("preflight_standing_bot_seeks_%d.json" % OS.get_process_id(), true)
	lobby._ensure_server_bot_seeks()
	lobby._ensure_server_bot_seeks()
	var open_formats: Array[String] = []
	for entry: Dictionary in lobby._build_room_list():
		if entry["host_is_bot"] and entry["member_count"] == 1:
			open_formats.append("%s|%d" % [entry["is_ranked"], int(entry.get("best_of", 1))])
			if entry.has("bot_stars"):
				failures.append("Open bot challenge advertised a rank before matchmaking")
	var expected_formats := ["true|1", "true|3", "false|1", "false|3"]
	if open_formats.size() != expected_formats.size() \
			or open_formats.any(func(format_key: String) -> bool: return format_key not in expected_formats):
		failures.append("Lobby did not maintain one open rated and unrated bot seek per Bo1/Bo3 format: %s" % str(open_formats))
	lobby.free()

func _check_request_next(failures: PackedStringArray) -> void:
	var lobby := RecordingLobby.new()
	var supervisor := MatchSupervisorScript.new()
	lobby.match_supervisor = supervisor
	var target: Dictionary = lobby._create_session("Playing", 2, false, "", "target_account")
	var viewer: Dictionary = lobby._create_session("Challenger", 3, false, "", "viewer_account")
	var same_account: Dictionary = lobby._create_session("Playing", 4, false, "", "target_account")
	var room := LobbyRoom.new("NEXT", "BOT_A")
	room.add_member("BOT_A")
	room.add_member(target["session_id"])
	room.status = LobbyRoom.STATUS_IN_MATCH
	room.assigned_match_id = "match_next"
	lobby.rooms_by_id[room.room_id] = room
	var session := MatchSessionScript.new(room.assigned_match_id, room.room_id, "127.0.0.1", 12345, room.members, {}, {
		"BOT_A": {"player_name": "Thor"},
		target["session_id"]: {"player_name": "Playing"},
	})
	session.mark_active()
	session.server_mode = MatchSessionScript.SERVER_MODE_DEDICATED_HEADLESS
	session.status_file_path = "user://preflight_request_next_%d.json" % OS.get_process_id()
	supervisor.active_matches[session.match_id] = session
	if lobby._build_room_list(viewer["session_id"])[0].has("request_next_match_id"):
		failures.append("Request Next was advertised before the dedicated match started")
	if not JsonStoreScript.save_json(session.status_file_path, {"status": MatchSessionScript.STATUS_ACTIVE}, "preflight_probe"):
		failures.append("Could not write Request Next match status")
	var entry: Dictionary = lobby._build_room_list(viewer["session_id"])[0]
	if entry.get("request_next_match_id") != session.match_id or entry.get("match_player_names") != ["Thor", "Playing"] \
			or lobby._build_room_list(same_account["session_id"])[0].has("request_next_match_id") \
			or lobby._build_room_list()[0].has("request_next_match_id"):
		failures.append("Request Next was not advertised only to eligible viewers")
	var request := LobbyProtocol.make_message(LobbyProtocol.REQUEST_NEXT, {"match_id": session.match_id})
	lobby._handle_request(3, request)
	if lobby.events.size() != 2 \
			or lobby.events[0] != {"peer": 2, "type": LobbyProtocol.REQUEST_NEXT_RECEIVED, "payload": {"requester_name": "Challenger"}} \
			or lobby.events[1]["peer"] != 3 or lobby.events[1]["type"] != LobbyProtocol.REQUEST_NEXT_RESULT:
		failures.append("Request Next did not privately notify the player and confirm to the requester")
	lobby.events.clear()
	lobby._handle_request(3, request)
	lobby._handle_request(4, request)
	lobby._handle_request(5, request)
	if lobby.events.size() != 3 or lobby.events.any(func(event: Dictionary) -> bool: return event["type"] != LobbyProtocol.REQUEST_NEXT_RESULT) \
			or lobby._build_room_list(viewer["session_id"])[0].has("request_next_match_id"):
		failures.append("Request Next permitted a duplicate, self-request, or unauthenticated request")
	session.next_requests_by_account.clear()
	var finished_status := {
		"status": MatchSessionScript.STATUS_FINISHED,
		"waiting_for_reconnect": true,
		"reconnect_deadline_unix": int(Time.get_unix_time_from_system()) + 60,
	}
	if not JsonStoreScript.save_json(session.status_file_path, finished_status, "preflight_probe"):
		failures.append("Could not write finished Request Next match status")
	lobby.events.clear()
	lobby._handle_request(3, request)
	if not lobby._build_room_list(target["session_id"])[0]["viewer_can_rejoin"] \
			or lobby.events.size() != 1 or lobby.events[0]["type"] != LobbyProtocol.REQUEST_NEXT_RESULT \
			or lobby._build_room_list(viewer["session_id"])[0].has("request_next_match_id"):
		failures.append("Request Next did not distinguish a finished match from a rejoinable match")
	DirAccess.remove_absolute(session.status_file_path)
	DirAccess.remove_absolute(session.status_file_path + ".bak")
	supervisor.free()
	lobby.free()

func _check_ladder_pages(failures: PackedStringArray) -> void:
	var account_path := ProjectSettings.globalize_path("user://preflight_ladder_%d.json" % OS.get_process_id())
	var accounts := {}
	var player_count := NetworkManagerScript.MAX_NETWORK_PAYLOAD_ITEMS + 1
	var portrait := {"card": "Wolf Cub", "art": 0, "x": 0.2, "y": 0.75, "zoom": 2.125}
	for index in range(player_count):
		var account_id := "account_%d" % index
		accounts[account_id] = {"account_id": account_id, "username": "Player %03d" % index,
			"password_salt": "test_salt", "password_hash": "test_hash"}
		if index > 1:
			accounts[account_id]["rank_badges"] = {"0": portrait}
	accounts["account_1"]["rank_badges"] = {"0": {"card": "Freyja"}}
	if not JsonStoreScript.save_json(account_path, {"accounts_by_id": accounts}, "preflight_probe"):
		failures.append("Could not prepare ladder page test accounts")
		return
	var store := BadgeTestAccountStore.new()
	store.storage_path = account_path
	var lobby := RecordingLobby.new()
	lobby.account_store = store
	var storage_file := "preflight_ladder_history_%d.json" % OS.get_process_id()
	var history := MatchHistoryStoreScript.new(storage_file, true)
	lobby.match_history_store = history
	var session := MatchSessionScript.new("ladder_bot_win", "preflight_room", "127.0.0.1", 12345, ["BOT_A", "human"], {
		"BOT_A": {"bot_god_name": "Thor", "cards": {"Thor": 1, "Berserker": 3}},
	}, {"human": {"account_id": "account_0"}})
	history.record_completed_match(session, 0, 1, "Thor", "Odin")
	lobby._create_session("Player 001", 2, false, "", "account_1")
	var god_records_request := LobbyProtocol.make_message(LobbyProtocol.REQUEST_RANKED_GOD_RECORDS, {
		"username": "Player 000", "best_of": 1, "request_id": 99,
	})
	lobby._handle_request(2, god_records_request)
	if lobby.events.size() != 1 or lobby.events[0] != {
		"peer": 2, "type": LobbyProtocol.RANKED_GOD_RECORDS,
		"payload": {"request_id": 99, "available": true, "god_records": [
			{"god_name": "Odin", "wins": 0, "losses": 1, "draws": 0, "games": 1},
		]},
	}:
		failures.append("The lobby did not return another player's public ranked record by god")
	lobby.events.clear()
	var network := NetworkManagerScript.new()
	var names := {}
	var bot_count := 0
	var bot_position := 0
	var portraits_valid := true
	var capped_entry_count := mini(player_count + 1, 100)
	var last_page := ceili(float(capped_entry_count) / LobbyProtocolScript.LADDER_PAGE_SIZE) - 1
	for page in range(last_page + 1):
		var summary := lobby._build_ladder_page({"best_of": 1, "request_id": page, "page": page})
		var message := LobbyProtocolScript.make_message(LobbyProtocolScript.BOT_LADDER, summary)
		if summary["request_id"] != page or summary["page"] != page or summary["last_page"] != last_page \
				or not network.get_game_event_payload_rejection_reason("__lobby_event__", message).is_empty():
			failures.append("A ranked ladder page exceeded the network limits or reported incorrect page metadata")
			break
		for row: Dictionary in summary["ladder"]:
			if row.has("account_id") or row.has("email"):
				failures.append("Ladder exposed private account fields")
				break
			if row.get("is_bot", false):
				bot_count += 1
				bot_position = int(row.get("ladder_position", 0))
				if page != 0 or str(row.get("list_id", "")).is_empty():
					failures.append("Bo1 standings did not rank the winning bot or include its deck link")
			else:
				names[row["name"]] = true
				var expected := {} if row["name"] in ["Player 000", "Player 001"] else portrait
				portraits_valid = portraits_valid and row.get("portrait", {}) == expected
	if names.size() != capped_entry_count - 1:
		failures.append("Ladder pages did not expose the expected top 100 standings")
	if not portraits_valid:
		failures.append("Ladder pages did not return valid saved portraits and crops")
	var bo3 := lobby._build_ladder_page({"best_of": 3, "request_id": 0, "page": 0})
	if not bo3["ladder"].any(func(row: Dictionary) -> bool: return row.get("portrait") == portrait):
		failures.append("Bo3 ladder did not include the player's saved crop")
	# The mirrored Bo3 copy starts at zero points, so it sorts below every
	# zero-point player on the unfiltered ladder; query the bots-only view to
	# inspect its zeroed record.
	var bo3_bots := lobby._build_ladder_page({
		"best_of": 3, "request_id": 55, "page": 0, "player_type": LobbyProtocolScript.LADDER_FILTER_BOTS,
	})
	var bo3_bot_rows: Array = bo3_bots["ladder"].filter(func(row: Dictionary) -> bool: return bool(row.get("is_bot", false)))
	if bot_count != 1:
		failures.append("Ladder did not show ranked bots in their match format")
	if bo3_bot_rows.size() != 1:
		failures.append("The Bo3 ladder did not mirror the Bo1-only bot with a zeroed record")
	else:
		var mirrored_row: Dictionary = bo3_bot_rows[0]
		if int(mirrored_row.get("wins", 0)) != 0 or int(mirrored_row.get("losses", 0)) != 0 \
				or int(mirrored_row.get("points", 0)) != 0:
			failures.append("A mirrored Bo3 ladder bot carried the Bo1 record instead of a zeroed one")
	var player_entry_update := lobby._ladder_rank_update(249, 149, LobbyServerScript.PLAYER_LADDER_NOTIFICATION_DEPTH)
	var bot_entry_update := lobby._ladder_rank_update(149, 99, LobbyServerScript.LADDER_NOTIFICATION_DEPTH)
	var top_ten_climb := lobby._ladder_rank_update(7, 4, LobbyServerScript.LADDER_NOTIFICATION_DEPTH)
	var top_ten_drop := lobby._ladder_rank_update(4, 7, LobbyServerScript.LADDER_NOTIFICATION_DEPTH)
	if not player_entry_update.contains("top 150") or not bot_entry_update.contains("top 100") \
			or not top_ten_climb.contains("#8 to #5") or not top_ten_drop.contains("#5 to #8"):
		failures.append("Ladder notifications did not track player depth and every top-ten move")
	var filter_validation := LobbyProtocolScript.validate_request(LobbyProtocolScript.make_message(
		LobbyProtocolScript.REQUEST_BOT_LADDER,
		{"best_of": 1, "page": 0, "request_id": 1, "player_type": LobbyProtocolScript.LADDER_FILTER_PLAYERS}))
	var invalid_filter_validation := LobbyProtocolScript.validate_request(LobbyProtocolScript.make_message(
		LobbyProtocolScript.REQUEST_BOT_LADDER,
		{"best_of": 1, "page": 0, "request_id": 1, "player_type": "creatures"}))
	if not filter_validation.is_empty() or invalid_filter_validation.is_empty():
		failures.append("Ladder player filter validation did not accept valid filters and reject invalid ones")
	var players_last_page := ceili(float(player_count) / LobbyProtocolScript.LADDER_PAGE_SIZE) - 1
	var players_seen := {}
	var deep_player_positions_kept := false
	for page in range(players_last_page + 1):
		var typed := lobby._build_ladder_page({"best_of": 1, "request_id": 2 + page, "page": page, "player_type": LobbyProtocolScript.LADDER_FILTER_PLAYERS})
		if typed["page"] != page or typed["last_page"] != players_last_page:
			failures.append("Player-filtered ladder reported incorrect page metadata")
		for row: Dictionary in typed["ladder"]:
			if row.get("is_bot", false):
				failures.append("Player-filtered ladder still included bots")
			players_seen[row["name"]] = true
			if int(row.get("ladder_position", 0)) > LobbyProtocolScript.LADDER_PAGE_SIZE:
				deep_player_positions_kept = true
	if players_seen.size() != player_count or not deep_player_positions_kept:
		failures.append("Player-filtered ladder did not compact ranked players onto consecutive pages with true positions")
	var bots_page := lobby._build_ladder_page({"best_of": 1, "request_id": 99, "page": 0, "player_type": LobbyProtocolScript.LADDER_FILTER_BOTS})
	if bots_page["ladder"].size() != 1 or bots_page["last_page"] != 0 \
			or not bots_page["ladder"][0].get("is_bot", false) \
			or int(bots_page["ladder"][0].get("ladder_position", 0)) != bot_position:
		failures.append("Bot-filtered ladder did not keep the bot's overall ladder position")
	var legacy_summary := lobby._build_ladder_page({})
	if legacy_summary["ladder"].size() != 100:
		failures.append("Legacy ladder response did not cap standings at the top 100")
	var pool := lobby._ranked_bot_deck_pool
	var held_id := pool.register_league_list("Thor", {
		"deck_name": "Thor: Held Bot", "cards": {"Thor": 1}, "reinforcements": {}, "special_setup": {},
	}, "held_bot")
	var thor_pool: Dictionary = pool._by_god["Thor"]
	pool._retire_list(thor_pool, pool._find_list_by_id(thor_pool, held_id))
	lobby.session_id_by_peer[2] = "ladder_account"
	lobby.sessions_by_id["ladder_account"] = {"account_id": "account_0", "username": "Player 000"}
	var quarantine_ladder := LobbyProtocolScript.make_message(LobbyProtocolScript.REQUEST_BOT_LADDER, {
		"best_of": 1, "page": 0, "request_id": 101, "search_query": "held", "quarantined_only": true,
	})
	var quarantine_deck := LobbyProtocolScript.make_message(LobbyProtocolScript.REQUEST_BOT_DECK, {
		"list_id": held_id, "quarantined_only": true,
	})
	lobby._handle_request(2, quarantine_ladder)
	lobby._handle_request(2, quarantine_deck)
	if lobby.events.size() != 2 or lobby.events[0]["type"] != LobbyProtocolScript.ROOM_ERROR \
			or lobby.events[1]["type"] != LobbyProtocolScript.ROOM_ERROR:
		failures.append("The quarantined bot view allowed a non-admin to request its list or decks")
	lobby.events.clear()
	lobby.sessions_by_id["ladder_account"]["is_admin"] = true
	lobby._handle_request(2, quarantine_ladder)
	lobby._handle_request(2, quarantine_deck)
	lobby._handle_request(2, LobbyProtocolScript.make_message(LobbyProtocolScript.REQUEST_BOT_DECK, {"list_id": held_id}))
	if lobby.events.size() != 3 or lobby.events[0]["type"] != LobbyProtocolScript.BOT_LADDER \
			or lobby.events[1]["type"] != LobbyProtocolScript.BOT_DECK or lobby.events[2]["type"] != LobbyProtocolScript.BOT_DECK:
		failures.append("The admin quarantined bot view did not return ladder and deck responses")
	else:
		var held_rows: Array = lobby.events[0]["payload"]["ladder"]
		if held_rows.size() != 1 or held_rows[0]["list_id"] != held_id \
				or held_rows[0]["quarantine_status"] != "Matchmaking pool":
			failures.append("The quarantined bot ladder did not show the retired matchmaking bot alone")
		if lobby.events[1]["payload"]["deck"].is_empty() or not lobby.events[2]["payload"]["deck"].is_empty():
			failures.append("A retired bot deck was unavailable to the admin view or accessible through the normal ladder")
	network.free()
	lobby.free()
	DirAccess.remove_absolute(account_path)
	DirAccess.remove_absolute(account_path + ".bak")
	var result_dir := ServerPathsScript.get_server_data_file_path(storage_file).get_basename() + "_results"
	DirAccess.remove_absolute(result_dir.path_join("%s.json" % session.match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir)

## Bo1 and Bo3 replays stay format-local for records, stars, and quarantine,
## while identity reconciliation mirrors each format's bots onto the other
## ladder. A Bo1 seek must never be answered by a Bo3-quarantined bot and vice
## versa, and mirrored copies must carry zeroed records.
func _check_bo3_bot_ladder_separation(failures: PackedStringArray) -> void:
	var storage_file := "preflight_bo3_bot_pool_%d.json" % OS.get_process_id()
	var writer := MatchHistoryStoreScript.new(storage_file, true)
	var deck_counts := _known_good_deck_counts()
	# Distinct decks keep the two fixtures separate identities: identical deck
	# content minted in both formats is reconciled into one bot by design.
	var bo3_deck_counts := deck_counts.duplicate()
	bo3_deck_counts["Fall of the Mighty"] = 3
	var specs: Array[Dictionary] = [
		{"match_id": "bo1_only_bot", "best_of": 1, "bot_name": "Thor: Bo1 Only", "cards": deck_counts},
		{"match_id": "bo3_only_bot", "best_of": 3, "bot_name": "Thor: Bo3 Only", "cards": bo3_deck_counts},
	]
	for spec: Dictionary in specs:
		var bot_session_id := "BOT_%s" % str(spec["match_id"]).to_upper()
		var session := MatchSessionScript.new(str(spec["match_id"]), "preflight_room", "127.0.0.1", 12345,
			[bot_session_id, "human"], {
				bot_session_id: {
					"bot_god_name": "Thor", "bot_name": str(spec["bot_name"]), "cards": (spec["cards"] as Dictionary).duplicate(),
				},
			}, {
				bot_session_id: {"is_bot": true, "player_name": str(spec["bot_name"])},
				"human": {"account_id": "bo_ladder_human"},
			})
		session.is_ranked = true
		session.configure_series_format(int(spec["best_of"]))
		var saved := writer.record_completed_match(session, 0, 1, "Thor", "Odin")
		if not bool(saved.get("success", false)):
			failures.append("Could not record the %s bot result" % spec["match_id"])
	var reader := MatchHistoryStoreScript.new(storage_file, true)
	var results := reader.get_bot_deck_results()
	var bo3_record := reader.get_ranked_bot_record_page("bo3_only_bot", 3, 50, "")
	var mirrored_record := reader.get_ranked_bot_record_page("bo3_only_bot", 1, 50, "")
	if bo3_record["matches"].size() != 1 or not mirrored_record["matches"].is_empty():
		failures.append("Bot records omitted the founding match or mixed ladder formats")
	var bo1_count := 0
	var bo3_count := 0
	for result: Dictionary in results:
		if int(result.get("best_of", 0)) == 1:
			bo1_count += 1
		elif int(result.get("best_of", 0)) == 3:
			bo3_count += 1
	if bo1_count != 1 or bo3_count != 1:
		failures.append("Bot results were not tagged with their match format: Bo1=%d Bo3=%d" % [bo1_count, bo3_count])
	var lobby := LobbyServerScript.new()
	lobby.match_history_store = reader
	lobby._refresh_ranked_bot_deck_pool()
	var bo1_pool := lobby._ranked_bot_deck_pool
	var bo3_pool := lobby._ranked_bot_deck_pool_bo3
	# Identity reconciliation mirrors each format's bots onto the other ladder
	# with a zeroed record. What must stay format-local is the record itself:
	# a mirrored copy cannot inherit the other format's wins or stars.
	var bo1_details := bo1_pool.get_deck_details("bo1_only_bot")
	var bo1_mirror := bo3_pool.get_deck_details("bo1_only_bot")
	var bo3_details := bo3_pool.get_deck_details("bo3_only_bot")
	var bo3_mirror := bo1_pool.get_deck_details("bo3_only_bot")
	if bo1_details.is_empty() or int(bo1_details.get("wins", 0)) != 1 or int(bo1_details.get("stars", 0)) != 1 \
			or bo1_mirror.is_empty() or int(bo1_mirror.get("wins", 0)) != 0 or int(bo1_mirror.get("stars", 0)) != 0 \
			or bo3_details.is_empty() or int(bo3_details.get("wins", 0)) != 1 or int(bo3_details.get("stars", 0)) != 1 \
			or bo3_mirror.is_empty() or int(bo3_mirror.get("wins", 0)) != 0 or int(bo3_mirror.get("stars", 0)) != 0:
		failures.append("A mirrored cross-format bot carried the other format's record instead of a zeroed one")
	if str(bo1_mirror.get("deck_name", "")) != str(bo1_details.get("deck_name", "")) \
			or str(bo3_mirror.get("deck_name", "")) != str(bo3_details.get("deck_name", "")) \
			or str(bo1_mirror.get("cards", {})) != str(bo1_details.get("cards", {})):
		failures.append("A mirrored cross-format bot changed decks or display names between formats")
	# Quarantine one bot in each pool. Iron V matchmaking must pull the Bo1 bot
	# for a Bo1 seek and the Bo3 bot for a Bo3 seek, never the other format's.
	var bo1_thor: Dictionary = bo1_pool._by_god["Thor"]
	bo1_pool._retire_list(bo1_thor, bo1_pool._find_list_by_id(bo1_thor, "bo1_only_bot"))
	var bo3_thor: Dictionary = bo3_pool._by_god["Thor"]
	bo3_pool._retire_list(bo3_thor, bo3_pool._find_list_by_id(bo3_thor, "bo3_only_bot"))
	lobby.sessions_by_id["bo1_human"] = {"account_id": "bo1_account", "connected": true}
	lobby.sessions_by_id["bo3_human"] = {"account_id": "bo3_account", "connected": true}
	var bo1_seek := lobby._create_server_bot_seek(true, 1)
	var bo3_seek := lobby._create_server_bot_seek(true, 3)
	if bo1_seek == null or bo3_seek == null:
		failures.append("Could not create a seek for both bot match formats")
	else:
		lobby._join_room_for_session("bo1_human", bo1_seek.room_id)
		lobby._join_room_for_session("bo3_human", bo3_seek.room_id)
		var bo1_matched := lobby._match_server_bot_to_player(bo1_seek)
		var bo3_matched := lobby._match_server_bot_to_player(bo3_seek)
		var bo1_bot := bo1_seek.get_deck_submission(bo1_seek.host_session_id)
		var bo3_bot := bo3_seek.get_deck_submission(bo3_seek.host_session_id)
		if not bo1_matched or not bo3_matched or str(bo1_bot.get("bot_list_id", "")) != "bo1_only_bot" \
				or str(bo3_bot.get("bot_list_id", "")) != "bo3_only_bot":
			failures.append("Ranked bot matchmaking did not draw each format's opponent from its own ladder")
		elif int(bo1_bot.get("bot_stars", -1)) != int(bo1_pool.get_deck_details("bo1_only_bot", true).get("stars", -2)) \
				or int(bo3_bot.get("bot_stars", -1)) != int(bo3_pool.get_deck_details("bo3_only_bot", true).get("stars", -2)):
			failures.append("Ranked bot seek ranks did not come from the format-specific ladder")
	lobby.free()

## One bot name must mean one decklist across both ladders: a Bo3 naming
## collision is renamed (the Bo1 identity keeps the name), Bo3-only bots are
## mirrored onto the Bo1 ladder with zeroed records and vice versa, both pools
## converge on one shared name map, and quarantine stays format-local.
func _check_cross_format_bot_identity_sync(failures: PackedStringArray) -> void:
	var bo1_pool := RankedBotDeckPoolScript.new()
	var bo3_pool := RankedBotDeckPoolScript.new()
	var bo1_results: Array[Dictionary] = [
		_bot_pool_result("bo1_bloodaxe", "", {"Thor": 1, "Bloodaxe Deck": 40}, "win", true),
	]
	bo1_results[0]["bot_name"] = "Thor: Bloodaxe"
	# Bo3 independently mints a different deck that claims the same display
	# name, plus a Bo3-only bot with a name of its own.
	var bo3_results: Array[Dictionary] = [
		_bot_pool_result("bo3_bloodaxe", "", {"Thor": 1, "Different Deck": 40}, "win", true),
		_bot_pool_result("bo3_storm", "", {"Thor": 1, "Storm Deck": 40}, "win", true),
	]
	bo3_results[0]["bot_name"] = "Thor: Bloodaxe"
	bo3_results[1]["bot_name"] = "Thor: Stormbelt"
	bo1_pool.refresh(bo1_results)
	bo3_pool.refresh(bo3_results)
	var summary: Dictionary = bo1_pool.sync_shared_identities(bo3_pool, true)
	var bo1_bloodaxe := bo1_pool.get_deck_details("bo1_bloodaxe")
	var bo1_mirror_of_bloodaxe := bo3_pool.get_deck_details("bo1_bloodaxe")
	var bo3_bloodaxe := bo3_pool.get_deck_details("bo3_bloodaxe")
	var bo1_mirror_of_bo3_bloodaxe := bo1_pool.get_deck_details("bo3_bloodaxe")
	var bo1_mirror_of_storm := bo1_pool.get_deck_details("bo3_storm")
	var bo3_storm := bo3_pool.get_deck_details("bo3_storm")
	if bo1_bloodaxe.get("deck_name", "") != "Thor: Bloodaxe" or int(bo1_bloodaxe.get("wins", 0)) != 1:
		failures.append("The primary-format identity lost its name or record during identity sync")
	if str(bo3_bloodaxe.get("deck_name", "")).is_empty() or str(bo3_bloodaxe.get("deck_name", "")) == "Thor: Bloodaxe":
		failures.append("A Bo3 bot kept a display name already owned by a different Bo1 deck")
	if bo1_mirror_of_bloodaxe.is_empty() or int(bo1_mirror_of_bloodaxe.get("wins", 0)) != 0 \
			or bo1_mirror_of_bo3_bloodaxe.is_empty() or int(bo1_mirror_of_bo3_bloodaxe.get("wins", 0)) != 0 \
			or bo1_mirror_of_storm.is_empty() or int(bo1_mirror_of_storm.get("stars", 0)) != 0:
		failures.append("Bo1 did not mirror the Bo3-only bots with zeroed records")
	if int(bo3_bloodaxe.get("wins", 0)) != 1 or bo1_mirror_of_bloodaxe.is_empty() \
			or str(bo1_mirror_of_bloodaxe.get("cards", {})) != str(bo1_bloodaxe.get("cards", {})) \
			or str(bo1_mirror_of_storm.get("cards", {})) != str(bo3_storm.get("cards", {})):
		failures.append("A mirrored bot did not keep the source deck's cards or the source kept its own record")
	# Both pools share one assigned-name map so future replays keep agreeing.
	var shared_map: Dictionary = bo1_pool._assigned_names_by_list_id
	if bo1_pool._assigned_names_by_list_id != bo3_pool._assigned_names_by_list_id \
			or str(shared_map.get("bo1_bloodaxe", "")) != "Thor: Bloodaxe" \
			or str(shared_map.get("bo3_bloodaxe", "")) != str(bo3_bloodaxe.get("deck_name", "")) \
			or str(shared_map.get("bo3_storm", "")) != "Thor: Stormbelt":
		failures.append("The two format pools did not converge on one shared bot name map")
	# A repeated reconciliation must be a no-op: no new mirrors, no renames.
	var resync: Dictionary = bo1_pool.sync_shared_identities(bo3_pool, true)
	if int(summary.get("mirrored", -1)) != 3 or int(summary.get("renamed", -1)) != 1 \
			or int(resync.get("mirrored", -1)) != 0 or int(resync.get("renamed", -1)) != 0:
		failures.append("A repeated identity sync duplicated mirrors or renames")
	# Quarantining a mirrored bot in one format leaves it active in the other.
	var bo3_thor: Dictionary = bo3_pool._by_god["Thor"]
	bo3_pool._retire_list(bo3_thor, bo3_pool._find_list_by_id(bo3_thor, "bo1_bloodaxe"))
	if bo3_pool.can_play_list("Thor", "bo1_bloodaxe") or not bo1_pool.can_play_list("Thor", "bo1_bloodaxe"):
		failures.append("A bot quarantined in Bo3 was not quarantined independently of Bo1")

func _check_ranked_bot_pool(failures: PackedStringArray) -> void:
	var named_results: Array[Dictionary] = [
		_bot_pool_result("m_bloodaxe", "", {"Thor": 1, "Bloodaxe Variant": 40}, "win"),
		_bot_pool_result("z_moon", "", {"Thor": 1, "Moon Variant": 40}, "win"),
	]
	for result in named_results:
		result["is_self_play"] = true
		result["bot_name"] = "Thor: Challenger"
	for i in range(15):
		named_results.append(_bot_pool_result("moon_win_%d" % i, "z_moon", {}, "win"))
	var named_pool := RankedBotDeckPoolScript.new()
	named_pool.refresh(named_results)
	var moon_before := named_pool.get_deck_details("z_moon")
	var new_named_result := _bot_pool_result("a_new", "", {"Thor": 1, "New Variant": 40}, "win")
	new_named_result["is_self_play"] = true
	new_named_result["bot_name"] = "Thor: Challenger"
	named_results.append(new_named_result)
	named_pool.refresh(named_results)
	var moon_after := named_pool.get_deck_details("z_moon")
	var replayed_named_pool := RankedBotDeckPoolScript.new()
	replayed_named_pool.refresh(named_results)
	if moon_before.get("name") != "Thor: Moon" or moon_after.get("name") != "Thor: Moon" \
			or moon_after.get("stars") != moon_before.get("stars") \
			or replayed_named_pool.get_deck_details("z_moon").get("name") != "Thor: Moon":
		failures.append("An established Thor bot changed its name when a new generic list arrived")
	var storage_file := "preflight_bot_pool_%d.json" % OS.get_process_id()
	var writer := MatchHistoryStoreScript.new(storage_file, true)
	var reader := MatchHistoryStoreScript.new(storage_file, true)
	var session := MatchSessionScript.new("bot_win", "preflight_room", "127.0.0.1", 12345, ["BOT_A", "human"], {
		"BOT_A": {"bot_god_name": "Thor", "bot_name": "Thor: Challenger", "cards": _known_good_deck_counts()},
	}, {"human": {"account_id": "human_account", "profile_id": "human_profile"}})
	if not session.to_match_info("human").get("has_bot", false):
		failures.append("Rated bot match assignment did not identify the bot")
	var saved := writer.record_completed_match(session, 0, 1, "", "Odin")
	var recap := reader.get_ranked_match_results(saved["entry"])
	if recap.has(0) or not recap.get(1, {}).get("loss_protected", false):
		failures.append("Rated bot match did not award a recap only to the signed-in player")
	var stored_results := reader.get_bot_deck_results()
	if stored_results.size() != 1 or stored_results[0]["god_name"] != "Thor" or stored_results[0]["result"] != "win" \
			or int(stored_results[0].get("best_of", 0)) != 1:
		failures.append("Rated bot match did not persist the registered winning list and its best-of")
	var lobby := LobbyServerScript.new()
	lobby.match_history_store = reader
	var seek := lobby._create_server_bot_seek(true)
	var pool_for_seek := lobby._ranked_bot_deck_pool
	var held_id := pool_for_seek.register_league_list("Thor", {
		"deck_name": "Thor: Held Test Bot", "cards": _known_good_deck_counts(),
		"reinforcements": {}, "special_setup": {},
	}, "held_test_bot")
	var thor_pool: Dictionary = pool_for_seek._by_god["Thor"]
	pool_for_seek._retire_list(thor_pool, pool_for_seek._find_list_by_id(thor_pool, held_id))
	lobby.sessions_by_id["human"] = {"account_id": "human_account", "connected": true}
	lobby._join_room_for_session("human", seek.room_id)
	var matched_before := lobby._match_server_bot_to_player(seek)
	var before_win := seek.get_deck_submission(seek.host_session_id)
	var human_win_ids: Array[String] = []
	for index in range(3):
		var match_id := "human_win_%d" % index
		human_win_ids.append(match_id)
		var human_win := MatchSessionScript.new(match_id, "preflight_room", "127.0.0.1", 12345, ["human", "opponent"], {}, {
			"human": {"account_id": "human_account"},
			"opponent": {"account_id": "opponent_account"},
		})
		writer.record_completed_match(human_win, 0, 1, "Thor", "Odin")
	var matched_after := lobby._match_server_bot_to_player(seek)
	var after_win := seek.get_deck_submission(seek.host_session_id)
	if not matched_before or before_win.get("bot_list_id") != held_id \
			or not matched_after or after_win.get("bot_list_id") != "bot_win":
		failures.append("Iron V did not use the quarantine pool or Iron IV failed to resume regular matchmaking")
	reader.set_serve_quarantined_next("human_account", true)
	if lobby._find_rank_matched_bot_deck(1, "human_account", false).get("bot_list_id") != "bot_win" \
			or lobby._find_rank_matched_bot_deck(1, "human_account").get("bot_list_id") != held_id \
			or lobby._find_rank_matched_bot_deck(1, "human_account").get("bot_list_id") != "bot_win":
		failures.append("Post-loss quarantine did not apply once to the next ranked bot challenge")
	lobby.free()
	var self_play := MatchSessionScript.new("bot_self_play", "preflight_room", "127.0.0.1", 12345, ["BOT_A", "BOT_B"], {
		"BOT_A": {"bot_god_name": "Thor", "bot_list_id": "bot_win", "bot_stars": 1, "cards": {"Thor": 1, "Berserker": 3}},
		"BOT_B": {"bot_god_name": "Odin", "cards": {"Odin": 1, "Brown Bear": 3}},
	}, {"BOT_A": {"player_name": "Thor: Bloodaxe"}, "BOT_B": {"player_name": "Odin: Test"}})
	if not self_play.to_spectator_match_info("observer").get("has_bot", false):
		failures.append("Self-play spectator assignment did not identify the bots")
	var self_play_saved := writer.record_completed_match(self_play, 1, 0, "Odin", "Thor", {"turns": 9})
	var recent := reader.get_recent_bot_matches(1)
	var first_page := reader.get_ranked_bot_record_page("bot_win", 1, 1, "")
	var last_page := reader.get_ranked_bot_record_page("bot_win", 1, 1, first_page["next_cursor"])
	var first_page_matches: Array = first_page["matches"]
	var last_page_matches: Array = last_page["matches"]
	if first_page_matches.size() != 1 or first_page_matches[0]["opponent_name"] != "Odin: Test" \
			or first_page["next_cursor"] != "bot_self_play" or last_page_matches.size() != 1 \
			or last_page_matches[0]["opponent_god_name"] != "Odin" or last_page_matches[0]["result"] != "win" \
			or not str(last_page["next_cursor"]).is_empty():
		failures.append("Bot record pagination lost or duplicated a ranked match")
	var self_play_results := reader.get_bot_deck_results()
	if (not self_play_saved.get("success", false)
			or self_play_saved["entry"].get("advances_rank", true)
			or self_play_results.size() != 3 or recent["matches"].size() != 1):
		failures.append("Self-play did not save both bot seats without changing human ranks")
	else:
		var battle: Dictionary = recent["matches"][0]
		if battle["players"][1]["name"] != "Odin: Test" or battle["battle"].get("turns") != 9:
			failures.append("Self-play history lost the names or battle summary")
	# The new 20-game threshold quarantines a bot on its first rated loss. Give
	# the losing Thor seat an extra prior win so this still tests promotion.
	var thor_seed := _bot_pool_result("thor_seed", "bot_win", {"Thor": 1, "Berserker": 3}, "win")
	thor_seed["god_name"] = "Thor"
	thor_seed["bot_name"] = "Thor: Bloodaxe"
	var replay_results: Array[Dictionary] = []
	for result: Dictionary in self_play_results:
		if str(result.get("god_name", "")) == "Thor" and str(result.get("result", "")) == "loss":
			replay_results.append(thor_seed)
		replay_results.append(result)
	self_play_results = replay_results
	if (not RankedBotDeckPoolScript.can_self_play_pair({"stars": 14}, {"stars": 17})
			or RankedBotDeckPoolScript.can_self_play_pair({"stars": 0}, {"stars": 90})
			or RankedBotDeckPoolScript.can_self_play_pair({"stars": 14}, {"stars": 45})
			or not RankedBotDeckPoolScript.can_self_play_pair({"stars": 5}, {"stars": 9})
			or RankedBotDeckPoolScript.can_self_play_pair({"stars": 5, "list_id": "same"}, {"stars": 5, "list_id": "same"})):
		failures.append("Bot matchmaking did not enforce the adjacent-league band and distinct seats")
	var band_pair_results: Array[Dictionary] = [
		_bot_pool_result("band_a", "", {"Thor": 1, "Band A": 40}, "win"),
		_bot_pool_result("band_a_seed", "band_a", {}, "win"),
		_bot_pool_result("band_b", "", {"Thor": 1, "Band B": 40}, "win"),
	]
	var band_far_entry := _bot_pool_result("band_far", "", {"Odin": 1, "Band Far": 40}, "win")
	band_far_entry["god_name"] = "Odin"
	band_pair_results.append(band_far_entry)
	for i in range(44):
		var band_far_seed := _bot_pool_result("band_far_seed_%d" % i, "band_far", {}, "win")
		band_far_seed["god_name"] = "Odin"
		band_pair_results.append(band_far_seed)
	var band_pair_pool := RankedBotDeckPoolScript.new()
	band_pair_pool.refresh(band_pair_results)
	var band_pair_rng := RandomNumberGenerator.new()
	band_pair_rng.seed = 11
	var band_pair_ok := false
	for i in range(60):
		var band_pair := band_pair_pool.select_self_play_pair({}, band_pair_rng)
		if band_pair.is_empty():
			continue
		if band_pair.size() != 2 \
				or absi(int(RankedProgressionScript.summarize_bot_stars(int(band_pair[0].get("stars", 0)))["league"]) \
					- int(RankedProgressionScript.summarize_bot_stars(int(band_pair[1].get("stars", 0)))["league"])) > 1:
			band_pair_ok = false
			break
		band_pair_ok = true
	if not band_pair_ok:
		failures.append("Bot self-play pairing did not prefer the adjacent-league band")
	var closest_pair: Array[Dictionary] = []
	for i in range(60):
		closest_pair = band_pair_pool.select_self_play_pair({"band_b": true}, band_pair_rng)
		if not closest_pair.is_empty():
			break
	if closest_pair.size() != 2:
		failures.append("Bot self-play pairing did not fall back to the closest available gap")
	var restricted_first := {"band_b": true}
	var restricted_pair_found := false
	for i in range(60):
		var restricted_pair := band_pair_pool.select_self_play_pair({}, band_pair_rng, restricted_first)
		if restricted_pair.is_empty() or restricted_pair[0].get("list_id") != "band_b":
			failures.append("Restricted bot self-play did not put an eligible bot in the first seat")
			break
		if restricted_pair.size() == 2 and restricted_pair[1].get("list_id") == "band_a":
			restricted_pair_found = true
	if not restricted_pair_found:
		failures.append("Restricted bot self-play did not pair with a bot outside the first-seat restriction")
	if not band_pair_pool.select_self_play_pair({"band_b": true}, band_pair_rng, restricted_first).is_empty():
		failures.append("Restricted bot self-play replaced a busy eligible bot with an ineligible first bot")
	var allowed_below_ids := {"band_a": true, "band_b": true}
	var allowed_below_pair := band_pair_pool.select_self_play_pair(
		{}, band_pair_rng, allowed_below_ids, allowed_below_ids, true
	)
	if allowed_below_pair.size() != 2 \
			or not allowed_below_ids.has(str(allowed_below_pair[0].get("list_id", ""))) \
			or not allowed_below_ids.has(str(allowed_below_pair[1].get("list_id", ""))):
		failures.append("Below-top-50 bot self-play did not keep both bots inside the allowed pool")
	var one_allowed_id := {"band_a": true}
	if not band_pair_pool.select_self_play_pair(
		{}, band_pair_rng, one_allowed_id, one_allowed_id, true
	).is_empty():
		failures.append("Below-top-50 bot self-play accepted a single bot instead of a full pair")
	var result_dir := ServerPathsScript.get_server_data_file_path(storage_file).get_basename() + "_results"
	DirAccess.remove_absolute(result_dir.path_join("%s.json" % session.match_id.sha256_text()))
	for match_id in human_win_ids:
		DirAccess.remove_absolute(result_dir.path_join("%s.json" % match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir.path_join("%s.json" % self_play.match_id.sha256_text()))
	DirAccess.remove_absolute(result_dir)

	var pool := RankedBotDeckPoolScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var representation_results: Array[Dictionary] = []
	for god_name in ["Thor", "Odin"]:
		for i in range(7 if god_name == "Thor" else 2):
			var entry := _bot_pool_result("representation_%s_%d" % [god_name, i], "", {"Variant %d" % i: 40}, "win")
			entry["god_name"] = god_name
			representation_results.append(entry)
	var representation_pool := RankedBotDeckPoolScript.new()
	representation_pool.refresh(representation_results)
	var preferred_gods := representation_pool.rank_underrepresented_gods(["Thor", "Odin", "Baldr"], rng)
	var reserved_gods := representation_pool.rank_underrepresented_gods(["Thor", "Odin", "Baldr"], rng, {"Baldr": 3})
	var nearly_full_gods := representation_pool.rank_underrepresented_gods(["Thor", "Odin", "Baldr"], rng, {"Thor": 6, "Odin": 12, "Baldr": 14})
	var full_gods := representation_pool.rank_underrepresented_gods(["Thor", "Odin", "Baldr"], rng, {"Thor": 7, "Odin": 12, "Baldr": 14})
	if preferred_gods != ["Baldr", "Odin", "Thor"] or reserved_gods != ["Odin", "Baldr", "Thor"] \
			or nearly_full_gods != ["Thor"] or not full_gods.is_empty():
		failures.append("Fresh bot gods were not prioritized by representation with a shared fourteen-list cap")
	pool.refresh(stored_results)
	var first_list := pool.select_deck({}, rng, 1)
	if first_list.get("deck_name") != "Thor: Bloodaxe" or first_list.get("stars") != 1:
		failures.append("A winning bot list did not return with its permanent name and star")
	if pool.select_deck({}, rng, 0).is_empty():
		failures.append("Bot matchmaking did not allow a same-tier bot for a player at zero stars")
	pool.refresh(self_play_results)
	var after_self_play: Dictionary = pool.get_ladder_summary()
	if after_self_play["gods"].size() != 2:
		failures.append("Self-play did not promote the named winning bot")
	else:
		var odin: Dictionary = after_self_play["gods"][0]["lists"][0]
		var after_thor: Dictionary = after_self_play["gods"][1]["lists"][0]
		if odin["name"] != "Odin: Test":
			failures.append("Self-play winning bot name was %s" % str(odin["name"]))
		if int(odin["stars"]) != 1:
			failures.append("Self-play winning bot stars were %d" % int(odin["stars"]))
		if int(after_thor["stars"]) != 2:
			failures.append("Self-play losing bot stars were %d" % int(after_thor["stars"]))

	var results: Array[Dictionary] = []
	var list_capacity := RankedBotDeckPoolScript.LISTS_PER_GOD
	for i in range(list_capacity):
		results.append(_bot_pool_result("list_%d" % i, "", {"Thor": 1, "Common": 30, "Variant %d" % i: 10}, "win"))
		for game in range(7 if i == 0 else 8):
			results.append(_bot_pool_result("seed_%d_%d" % [i, game], "list_%d" % i, {}, "win"))
	results.append(_bot_pool_result("candidate", "", {"Thor": 1, "Common": 30, "Challenger": 10}, "win"))
	pool.refresh(results)
	var candidate := pool.select_deck({}, rng, 1)
	if pool.can_play_list("Thor", "list_0") or not pool.can_play_list("Thor", "list_1") \
			or candidate.is_empty() or pool.get_deck_details("candidate").is_empty():
		failures.append("Adding a bot above capacity did not quarantine an incumbent while preserving same-tier matching")
	var high_rank_results := results.duplicate()
	for i in range(14):
		high_rank_results.append(_bot_pool_result("ranked_%d" % i, "list_1", {}, "win"))
	for i in range(15):
		high_rank_results.append(_bot_pool_result("quarantined_%d" % i, "list_0", {}, "win"))
	var far_entry := _bot_pool_result("far_list", "", {"Odin": 1, "Common": 30, "Far Variant": 10}, "win")
	far_entry["god_name"] = "Odin"
	high_rank_results.append(far_entry)
	for i in range(44):
		var far_seed := _bot_pool_result("far_seed_%d" % i, "far_list", {}, "win")
		far_seed["god_name"] = "Odin"
		high_rank_results.append(far_seed)
	var high_rank_pool := RankedBotDeckPoolScript.new()
	high_rank_pool.refresh(high_rank_results)
	var high_rank_match := high_rank_pool.select_deck({}, rng, 16)
	var high_rank_alternative := high_rank_pool.select_deck({"list_1": true}, rng, 16)
	var high_rank_thor: Dictionary = {}
	for god_summary in high_rank_pool.get_ladder_summary()["gods"]:
		if str(god_summary["god_name"]) == "Thor":
			high_rank_thor = god_summary
			break
	var band_samples_out_of_range := false
	for i in range(40):
		var band_sample := high_rank_pool.select_deck({"far_list": true}, rng, 16)
		if band_sample.is_empty() \
				or abs(int(RankedProgressionScript.summarize_bot_stars(int(band_sample["stars"]))["league"]) - 1) > 1:
			band_samples_out_of_range = true
			break
	var busy_thor_lists := {"candidate": true}
	for i in range(list_capacity):
		busy_thor_lists["list_%d" % i] = true
	var high_rank_fallback := high_rank_pool.select_deck(busy_thor_lists, rng, 16)
	if high_rank_match.is_empty() or high_rank_alternative.is_empty() \
			or high_rank_thor.is_empty() \
			or band_samples_out_of_range \
			or high_rank_thor["challenger"].get("trial_length") != 23 \
			or abs(int(RankedProgressionScript.summarize_bot_stars(int(high_rank_match["stars"]))["league"]) - 1) > 1 \
			or abs(int(RankedProgressionScript.summarize_bot_stars(int(high_rank_alternative["stars"]))["league"]) - 1) > 1 \
			or high_rank_alternative.get("list_id") == "list_1" \
			or str(high_rank_fallback.get("list_id")) != "far_list":
		failures.append("Bot matchmaking did not sample the league band with a closest-gap fallback while skipping busy lists")
	var protected_results: Array[Dictionary] = []
	for i in range(list_capacity):
		protected_results.append(_bot_pool_result("protected_list_%d" % i, "", {"Thor": 1, "Common": 30, "Protected %d" % i: 10}, "win"))
		if i > 0:
			for game in range(3):
				protected_results.append(_bot_pool_result("protected_seed_%d_%d" % [i, game], "protected_list_%d" % i, {}, "win"))
	for i in range(15):
		protected_results.append(_bot_pool_result("protected_win_%d" % i, "protected_list_0", {}, "win"))
	for i in range(8):
		protected_results.append(_bot_pool_result("protected_loss_%d" % i, "protected_list_0", {}, "loss", true))
	protected_results.append(_bot_pool_result("protected_candidate", "", {"Thor": 1, "Common": 30, "Protected Challenger": 10}, "win"))
	var protected_pool := RankedBotDeckPoolScript.new()
	protected_pool.refresh(protected_results)
	var protected_thor: Dictionary = protected_pool.get_ladder_summary()["gods"][0]
	if protected_thor["lists"][0]["quarantined"] or not protected_pool.can_play_list("Thor", "protected_list_0") \
			or protected_thor["challenger"].get("trial_length") != 4:
		failures.append("A high-star bot was treated as weaker than a short-trial challenger")
	for i in range(6):
		var outcome := "loss" if i % 2 == 0 else "win"
		results.append(_bot_pool_result("trial_%d" % i, "candidate", {}, outcome, i % 2 == 0))
	pool.refresh(results)
	if pool.can_play_list("Thor", "list_0"):
		failures.append("A bot list trial ended before the challenger matched the incumbent's game count")
	var ladder_summary := pool.get_ladder_summary()
	var thor: Dictionary = ladder_summary["gods"][0]
	var challenger: Dictionary = thor["challenger"]
	if thor["lists"].size() != list_capacity or not thor["lists"][0]["quarantined"] \
			or challenger.get("matches_played") != 7 or challenger.get("wins") != 4 \
			or challenger.get("losses") != 3 or challenger.get("draws") != 0 \
			or challenger.has("cards") or challenger.get("trial_length") != 8:
		failures.append("Bot ladder did not report the incumbent-sized challenger trial")
	var quarantined_deck := pool.get_deck_details(thor["lists"][0]["list_id"])
	var challenger_deck := pool.get_deck_details(challenger.get("list_id", ""))
	if quarantined_deck.get("cards", {}).get("Variant 0") != 10 \
			or challenger_deck.get("cards", {}).get("Challenger") != 10:
		failures.append("Bot ladder did not resolve both quarantined and challenger deck contents")
	results.append(_bot_pool_result("trial_6", "candidate", {}, "win"))
	pool.refresh(results)
	if not pool.can_play_list("Thor", "list_0") or pool.can_play_list("Thor", "candidate"):
		failures.append("The stronger incumbent did not return when the challenger matched its game count")
	thor = pool.get_ladder_summary()["gods"][0]
	if not thor["challenger"].is_empty() or thor["lists"][0]["quarantined"]:
		failures.append("Bot ladder still showed a trial after the challenger matched the incumbent's game count")
	if not pool.get_deck_details("candidate").is_empty():
		failures.append("Bot ladder still returned a retired challenger deck")

	var early_retirement_results: Array[Dictionary] = []
	for i in range(list_capacity):
		early_retirement_results.append(_bot_pool_result("early_list_%d" % i, "", {"Thor": 1, "Common": 30, "Variant %d" % i: 10}, "win"))
		for game in range(3 if i == 0 else 4):
			early_retirement_results.append(_bot_pool_result("early_seed_%d_%d" % [i, game], "early_list_%d" % i, {}, "win"))
	early_retirement_results.append(_bot_pool_result("early_candidate", "", {"Thor": 1, "Common": 30, "Early Challenger": 10}, "win"))
	for i in range(2):
		early_retirement_results.append(_bot_pool_result("early_loss_%d" % i, "early_candidate", {}, "loss", true))
	var early_retirement_pool := RankedBotDeckPoolScript.new()
	early_retirement_pool.refresh(early_retirement_results)
	var early_summary: Dictionary = early_retirement_pool.get_ladder_summary()["gods"][0]
	if early_summary["challenger"].get("matches_played") != 3 \
			or early_summary["challenger"].get("trial_length") != 4 \
			or early_retirement_pool.can_play_list("Thor", "early_list_0"):
		failures.append("A challenger was removed before matching the incumbent's game count")
	early_retirement_results.append(_bot_pool_result("early_loss_final", "early_candidate", {}, "loss", true))
	early_retirement_pool.refresh(early_retirement_results)
	early_summary = early_retirement_pool.get_ladder_summary()["gods"][0]
	if not early_summary["challenger"].is_empty() or not early_retirement_pool.can_play_list("Thor", "early_list_0") \
			or not early_retirement_pool.get_deck_details("early_candidate").is_empty():
		failures.append("The weaker challenger remained after matching the incumbent's game count")

	var threshold_pool := RankedBotDeckPoolScript.new()
	var early_quarantine_cases: Array[Dictionary] = [
		{"wins": 1, "losses": 1, "draws": 0, "expected": true},
		{"wins": 2, "losses": 1, "draws": 0, "expected": false},
		{"wins": 10, "losses": 10, "draws": 0, "expected": true},
		{"wins": 11, "losses": 9, "draws": 0, "expected": false},
		{"wins": 11, "losses": 8, "draws": 1, "expected": false},
		{"wins": 9, "losses": 9, "draws": 2, "expected": true},
		{"wins": 11, "losses": 10, "draws": 0, "expected": false},
		{"wins": 7, "losses": 14, "draws": 0, "expected": true},
		{"wins": 20, "losses": 40, "draws": 0, "expected": true},
		{"wins": 21, "losses": 42, "draws": 0, "expected": false},
	]
	for case: Dictionary in early_quarantine_cases:
		if threshold_pool._should_retire_early(case) != bool(case["expected"]):
			failures.append("Early quarantine threshold mismatch: %d-%d-%d" % [
				int(case["wins"]), int(case["losses"]), int(case["draws"]),
			])

	var variety_results: Array[Dictionary] = []
	for i in range(list_capacity):
		variety_results.append(_bot_pool_result("variety_list_%d" % i, "", {"Thor": 1, "Common": 30, "Variant %d" % i: 10}, "win"))
		for game in range(7):
			var outcome := "loss" if i == 0 and game >= 4 else "win"
			variety_results.append(_bot_pool_result("variety_seed_%d_%d" % [i, game], "variety_list_%d" % i, {}, outcome, i == 0 and game >= 4))
	variety_results.append(_bot_pool_result("distinct", "", {"Thor": 1, "Different": 40}, "win"))
	for i in range(7):
		variety_results.append(_bot_pool_result("variety_%d" % i, "distinct", {}, "win"))
	var variety_pool := RankedBotDeckPoolScript.new()
	variety_pool.refresh(variety_results)
	if not variety_pool.can_play_list("Thor", "distinct") or variety_pool.can_play_list("Thor", "variety_list_0"):
		failures.append("A challenger with a better equal-length record did not replace the weakest incumbent")

	var streak_results: Array[Dictionary] = []
	streak_results.append(_bot_pool_result("streak_0", "", {"Thor": 1, "Common": 30, "Streak": 10}, "win"))
	for i in range(4):
		streak_results.append(_bot_pool_result("streak_seed_%d" % i, "streak_0", {}, "win"))
	var streak_pool := RankedBotDeckPoolScript.new()
	streak_pool.refresh(streak_results)
	var streak_list := streak_pool.select_deck({}, rng, 5)
	if streak_list.is_empty() or int(streak_list.get("stars", 0)) != 8:
		failures.append("A bot on a five-win streak did not earn the third-win bonus stars")
	streak_results.append(_bot_pool_result("streak_draw", "streak_0", {}, "draw"))
	streak_results.append(_bot_pool_result("streak_win_after_draw", "streak_0", {}, "win"))
	streak_pool.refresh(streak_results)
	var streak_after_break := streak_pool.get_deck_details("streak_0")
	if int(streak_after_break.get("stars", 0)) != 9 or int(streak_after_break.get("draws", 0)) != 1:
		failures.append("A bot draw did not reset the win streak before the next bonus star")

	var player_loss_results: Array[Dictionary] = []
	for i in range(list_capacity):
		player_loss_results.append(_bot_pool_result("player_loss_list_%d" % i, "", {"Thor": 1, "Common": 30, "Variant %d" % i: 10}, "win"))
		for game in range(3):
			player_loss_results.append(_bot_pool_result("player_loss_seed_%d_%d" % [i, game], "player_loss_list_%d" % i, {}, "win", true))
	var player_loss_pool := RankedBotDeckPoolScript.new()
	player_loss_pool.refresh(player_loss_results)
	var stars_before_player_losses := int(player_loss_pool.get_deck_details("player_loss_list_0").get("stars", -1))
	player_loss_results.append(_bot_pool_result("player_loss_challenger", "", {"Thor": 1, "Common": 30, "Player Loss Challenger": 10}, "win", true))
	for i in range(6):
		player_loss_results.append(_bot_pool_result("player_loss_trial_%d" % i, "player_loss_challenger", {}, "loss"))
	player_loss_results.append(_bot_pool_result("player_loss_incumbent", "player_loss_list_0", {}, "loss"))
	player_loss_pool.refresh(player_loss_results)
	var player_loss_summary: Dictionary = player_loss_pool.get_ladder_summary()["gods"][0]
	var player_loss_list := player_loss_pool.get_deck_details("player_loss_list_0")
	if player_loss_summary["challenger"].get("matches_played") != 1 \
			or player_loss_summary["challenger"].get("losses") != 0 \
			or int(player_loss_list.get("losses", -1)) != 0 \
			or int(player_loss_list.get("stars", -1)) != stars_before_player_losses:
		failures.append("A loss to a human player counted toward bot pool evaluation")
	player_loss_results.append(_bot_pool_result("player_loss_trial_self_play", "player_loss_challenger", {}, "loss", true))
	player_loss_pool.refresh(player_loss_results)
	player_loss_summary = player_loss_pool.get_ladder_summary()["gods"][0]
	if player_loss_summary["challenger"].is_empty() \
			or player_loss_summary["challenger"].get("matches_played") != 2 \
			or player_loss_summary["challenger"].get("losses") != 1:
		failures.append("A self-play loss stopped counting toward bot pool evaluation")

## A quarantined bot that climbs back over the release win rate (60%) returns
## to the main pool; without a free ladder slot it waits until one opens.
func _check_quarantined_bot_release(failures: PackedStringArray) -> void:
	var results: Array[Dictionary] = []
	for i in range(RankedBotDeckPoolScript.LISTS_PER_GOD - 1):
		results.append(_bot_pool_result("release_seed_%d" % i, "", {"Thor": 1, "Common": 30, "Release %d" % i: 10}, "win"))
	results.append(_bot_pool_result("release_roomy_win", "release_roomy", {}, "win"))
	results.append(_bot_pool_result("release_roomy_loss", "release_roomy", {}, "loss", true))
	var pool := RankedBotDeckPoolScript.new()
	pool.refresh(results)
	if pool.can_play_list("Thor", "release_roomy") or pool.get_quarantined_ladder_summary().is_empty():
		failures.append("A 1-1 bot was not quarantined before the release rule could apply")
	# One comeback win reaches a 60% win rate but not the 20-game minimum, so
	# the bot stays quarantined; release fires once the rate holds over 20
	# games and a ladder slot is free.
	results.append(_bot_pool_result("release_roomy_comeback", "release_roomy", {}, "win"))
	pool.refresh(results)
	if pool.can_play_list("Thor", "release_roomy") or pool.get_quarantined_ladder_summary().is_empty():
		failures.append("A quarantined bot under the 20-game release minimum was released early")
	for game in range(17):
		results.append(_bot_pool_result("release_roomy_comeback_%d" % game, "release_roomy", {}, "win"))
	pool.refresh(results)
	if not pool.can_play_list("Thor", "release_roomy") or not pool.get_quarantined_ladder_summary().is_empty():
		failures.append("A quarantined bot above the release win rate over 20 games was not returned to the main pool")
	# Refill the ladder, quarantine a second bot, and refill again so no slot
	# is free when its record qualifies for release.
	results.append(_bot_pool_result("release_filler", "release_filler", {}, "win"))
	results.append(_bot_pool_result("release_blocked_win", "release_blocked", {}, "win"))
	results.append(_bot_pool_result("release_blocked_loss", "release_blocked", {}, "loss", true))
	results.append(_bot_pool_result("release_filler_two", "release_filler_two", {}, "win"))
	pool.refresh(results)
	if pool.can_play_list("Thor", "release_blocked"):
		failures.append("A bot quarantined while the ladder was full was not held in the quarantine pool")
	for game in range(18):
		results.append(_bot_pool_result("release_blocked_comeback_%d" % game, "release_blocked", {}, "win"))
	pool.refresh(results)
	if pool.can_play_list("Thor", "release_blocked"):
		failures.append("A quarantined bot was released without a free ladder slot")
	# Retiring another bot frees a slot; the held bot's next win releases it.
	results.append(_bot_pool_result("release_seed_2_loss", "release_seed_2", {}, "loss", true))
	results.append(_bot_pool_result("release_blocked_final_win", "release_blocked", {}, "win"))
	pool.refresh(results)
	var held_ids := {}
	for entry in pool.get_quarantined_ladder_summary():
		held_ids[str(entry["list_id"])] = true
	if not pool.can_play_list("Thor", "release_blocked") \
			or not held_ids.has("release_seed_2") or held_ids.has("release_blocked"):
		failures.append("A quarantined bot above the release win rate stayed held after a ladder slot opened")
	# finalize_league keeps the quarantined seeded bot on the ladder; releasing
	# it only clears the quarantine flags.
	var league_pool := RankedBotDeckPoolScript.new()
	league_pool.register_league_list("Thor", {
		"deck_name": "Thor: Held League Bot", "cards": {"Thor": 1, "Common": 30},
		"reinforcements": {}, "special_setup": {},
	}, "held_league_bot")
	league_pool.finalize_league(["Thor"] as Array[String])
	if not bool(league_pool.get_ladder_summary()["gods"][0]["lists"][0]["quarantined"]):
		failures.append("finalize_league did not quarantine the seeded league bot")
	for game in range(19):
		league_pool._apply_result(_bot_pool_result("held_league_comeback_%d" % game, "held_league_bot", {"Thor": 1, "Common": 30}, "win"))
	if league_pool.can_play_list("Thor", "held_league_bot"):
		failures.append("A quarantined on-ladder bot was released under the 20-game minimum")
	league_pool._apply_result(_bot_pool_result("held_league_comeback_final", "held_league_bot", {"Thor": 1, "Common": 30}, "win"))
	if not league_pool.can_play_list("Thor", "held_league_bot") \
			or not league_pool.get_quarantined_ladder_summary().is_empty():
		failures.append("A quarantined on-ladder bot was not released after reaching the release win rate over 20 games")

## A user-submitted bot must carry its replayed ladder record into every hosted
## match so its rank badge keeps updating, instead of restarting at zero stars.
func _check_community_bot_rank_badge(failures: PackedStringArray) -> void:
	var storage_file := "preflight_community_bot_%d.json" % OS.get_process_id()
	var store := MatchHistoryStoreScript.new(storage_file, true)
	var lobby := LobbyServerScript.new()
	lobby.match_history_store = store
	var owner_id := "community_owner_%d" % OS.get_process_id()
	var bot_dir := ServerPathsScript.get_server_data_file_path("community_bot_pool")
	var bot_id := "probebot_%d" % OS.get_process_id()
	var fresh_bot_id := "freshbot_%d" % OS.get_process_id()
	var bot_fixture := {
		"bot_id": bot_id,
		"account_id": owner_id,
		"owner_name": "Probe Owner",
		"bot_name": "Probe Bot",
		"deck_name": "Thor: Probe Bot",
		"god_name": "Thor",
		"cards": {"Thor": 1, "Berserker": 3},
		"special_setup": {},
		"reinforcements": {},
	}
	var fresh_fixture := bot_fixture.duplicate(true)
	fresh_fixture["bot_id"] = fresh_bot_id
	fresh_fixture["bot_name"] = "Fresh Bot"
	fresh_fixture["deck_name"] = "Thor: Fresh Bot"
	var bot_path := bot_dir.path_join("%s.json" % bot_id)
	var fresh_path := bot_dir.path_join("%s.json" % fresh_bot_id)
	if not JsonStoreScript.save_json(bot_path, bot_fixture, "preflight_probe") \
			or not JsonStoreScript.save_json(fresh_path, fresh_fixture, "preflight_probe"):
		failures.append("Could not write the community bot fixtures")
		return
	var community_deck := bot_fixture.duplicate(true)
	community_deck["bot_god_name"] = "Thor"
	community_deck["bot_list_id"] = bot_id
	community_deck["list_id"] = bot_id
	community_deck["is_community_bot"] = true
	community_deck["stars"] = 0
	community_deck["win_streak"] = 0
	var foe_deck := {
		"deck_name": "Thor: Foe",
		"god_name": "Thor",
		"bot_god_name": "Thor",
		"stars": 0,
		"win_streak": 0,
		"cards": {"Thor": 1, "Askelladen": 3},
		"special_setup": {},
		"reinforcements": {},
	}
	var session := MatchSessionScript.new("community_bot_win_%d" % OS.get_process_id(), "preflight_room", "127.0.0.1", 12345, ["BOT_COMMUNITY", "BOT_FOE"], {
		"BOT_COMMUNITY": community_deck,
		"BOT_FOE": foe_deck,
	}, {
		"BOT_COMMUNITY": {"is_bot": true, "player_name": "Thor: Probe Bot"},
		"BOT_FOE": {"is_bot": true, "player_name": "Thor: Foe"},
	})
	session.is_ranked = true
	session.configure_series_format(1)
	# Three self-play wins award 1 + 1 + 2 (streak bonus) = 4 stars, which moves
	# the bot out of the zero-star division so the badge change is observable.
	for win_index in range(3):
		session.match_id = "community_bot_win_%d_%d" % [OS.get_process_id(), win_index]
		var recorded: Dictionary = store.record_completed_match(session, 0, 1, "Thor", "Thor")
		if not bool(recorded.get("success", false)):
			failures.append("Could not record the community bot self-play win")
			break
	var found := lobby._find_community_bot(owner_id, bot_id)
	var zero_star_rank := str(RankedProgressionScript.summarize_bot_stars(0)["name"])
	var found_rank := str(RankedProgressionScript.summarize_bot_stars(int(found.get("stars", 0)))["name"])
	if found.is_empty() or int(found.get("stars", -1)) != 4 or int(found.get("bot_stars", -1)) != 4 \
			or int(found.get("win_streak", -1)) != 3 or found_rank == zero_star_rank:
		failures.append("A hosted community bot did not carry its current ladder stars and streak")
	var fresh := lobby._find_community_bot(owner_id, fresh_bot_id)
	if fresh.is_empty() or int(fresh.get("stars", -1)) != 0 or int(fresh.get("bot_stars", -1)) != 0 \
			or int(fresh.get("win_streak", -1)) != 0:
		failures.append("A community bot without recorded results did not default to zero stars")
	if DirAccess.copy_absolute(bot_path, bot_path + ".bak") != OK:
		failures.append("Could not write the community bot backup fixture")
	lobby.session_id_by_peer[2] = "community_probe_session"
	lobby.sessions_by_id["community_probe_session"] = {"account_id": owner_id}
	lobby._handle_delete_bot(2, {"bot_id": bot_id})
	if not lobby._find_community_bot(owner_id, bot_id).is_empty() \
			or not lobby._ranked_bot_deck_pool.get_deck_details(bot_id).is_empty():
		failures.append("A deleted community bot remained available in the pool or through its backup")
	for fixture_path in [bot_path, fresh_path]:
		DirAccess.remove_absolute(fixture_path)
		DirAccess.remove_absolute(fixture_path + ".bak")
		DirAccess.remove_absolute(fixture_path + ".tmp")
	lobby.free()

## A submitter quarantine is distinct from the Iron V weak-bot quarantine: it
## keeps the submission on disk but removes it from every matchmaking path.
func _check_community_bot_quarantine(failures: PackedStringArray) -> void:
	var owner_id := "quarantine_owner_%d" % OS.get_process_id()
	var bot_id := "quarantinebot_%d" % OS.get_process_id()
	var bot_dir := ServerPathsScript.get_server_data_file_path("community_bot_pool")
	var bot_path := bot_dir.path_join("%s.json" % bot_id)
	var fixture := {
		"bot_id": bot_id,
		"account_id": owner_id,
		"owner_name": "Quarantine Owner",
		"bot_name": "Quarantine Probe",
		"deck_name": "Thor: Quarantine Probe",
		"god_name": "Thor",
		"cards": {"Thor": 1, "Berserker": 3},
		"special_setup": {},
		"reinforcements": {},
		"quarantined": true,
	}
	if not JsonStoreScript.save_json(bot_path, fixture, "preflight_probe"):
		failures.append("Could not write the quarantined community bot fixture")
		return
	var lobby := LobbyServerScript.new()
	lobby.match_history_store = MatchHistoryStoreScript.new("preflight_quarantine_%d.json" % OS.get_process_id(), true)
	lobby.session_id_by_peer[2] = "quarantine_owner_session"
	lobby.sessions_by_id["quarantine_owner_session"] = {"account_id": owner_id}
	lobby.session_id_by_peer[3] = "quarantine_other_session"
	lobby.sessions_by_id["quarantine_other_session"] = {"account_id": "not_the_owner"}
	# Another account cannot release somebody else's quarantined bot.
	lobby._handle_quarantine_bot(3, {"bot_id": bot_id, "quarantined": false})
	var after_other := JsonStoreScript.load_dictionary(bot_path, {}, "preflight_probe")
	if not bool(after_other.get("quarantined", false)):
		failures.append("A non-owner changed another account's bot quarantine")
	# Isolated pool assertions avoid depending on any other submissions on disk.
	var results: Array[Dictionary] = [_bot_pool_result("quarantine_probe", bot_id, fixture["cards"], "win", true)]
	var submission := fixture.duplicate(true)
	submission["deck_name"] = str(fixture["deck_name"])
	var held := RankedBotDeckPoolScript.new()
	held.sync_community_bots({bot_id: submission})
	held.refresh(results)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if not held.select_deck({}, rng, 0).is_empty() \
			or not held.select_deck({}, rng, 0, true).is_empty() \
			or not held.select_self_play_pair({}, rng).is_empty():
		failures.append("A quarantined community bot was still available to matchmaking")
	# The owner can release it; the submission remains on disk and pairs again.
	lobby._handle_quarantine_bot(2, {"bot_id": bot_id, "quarantined": false})
	var released := JsonStoreScript.load_dictionary(bot_path, {}, "preflight_probe")
	if released.is_empty() or bool(released.get("quarantined", false)):
		failures.append("Releasing a quarantined bot deleted it or left the flag set")
	var restored := RankedBotDeckPoolScript.new()
	var released_submission := released.duplicate(true)
	released_submission["deck_name"] = str(released.get("bot_name", "Quarantine Probe"))
	restored.sync_community_bots({bot_id: released_submission})
	restored.refresh(results)
	if restored.select_deck({}, rng, 0).is_empty():
		failures.append("A released community bot did not return to matchmaking")
	for fixture_path in [bot_path]:
		DirAccess.remove_absolute(fixture_path)
		DirAccess.remove_absolute(fixture_path + ".bak")
		DirAccess.remove_absolute(fixture_path + ".tmp")
	lobby.free()

func _check_community_bot_replay_identity(failures: PackedStringArray) -> void:
	var old_id := "0123456789ab_ABCDEFGHJKLM"
	var current_id := "0123456789ab_NPQRSTUVWXYZ"
	var resubmitted_id := "0123456789ab_23456789ABCD"
	var god_name := "Tiamat, the Primordial"
	var cards := {god_name: 1, "Gallu": 3}
	var old_result := _bot_pool_result("old_tiamat", old_id, cards, "win", true)
	old_result["god_name"] = god_name
	old_result["bot_name"] = "Tiamat: World Serpent"
	var current_result := _bot_pool_result("current_tiamat", current_id, cards, "win", true)
	current_result["god_name"] = god_name
	var current_bot := {"owner_name": "Probe Owner", "deck_name": "Tiamat: Dreameater"}
	var active := {current_id: current_bot}
	var results: Array[Dictionary] = [old_result, current_result]
	var pool := RankedBotDeckPoolScript.new()
	# Simulate a cache written before deleted submissions were filtered.
	pool.sync_community_bots({old_id: {"owner_name": "", "deck_name": old_result["bot_name"]}, current_id: current_bot})
	pool.refresh(results)
	var god_pool: Dictionary = pool._by_god.get(god_name, {})
	var cached_old := pool._find_list_by_id(god_pool, old_id)
	if cached_old.is_empty():
		failures.append("Could not prepare the stale community bot pool fixture")
		return
	cached_old.erase("is_community_bot")
	god_pool["quarantined_lists"].append(cached_old.duplicate(true))
	var cache_path := ProjectSettings.globalize_path("user://preflight_community_bot_pool_%d.json" % OS.get_process_id())
	var restored := RankedBotDeckPoolScript.new()
	if not pool.save_state(cache_path, results.size()) or not restored.load_state(cache_path):
		failures.append("Could not restore the stale ranked bot pool fixture")
		return
	DirAccess.remove_absolute(cache_path)
	restored.sync_community_bots(active)
	restored.refresh(results)
	var current_record := restored.get_deck_details(current_id)
	if not restored.get_deck_details(old_id).is_empty() or not restored.get_deck_details(old_id, true).is_empty() \
			or not restored.select_deck({}, RandomNumberGenerator.new(), 0, true).is_empty() \
			or restored.select_deck({}, RandomNumberGenerator.new(), 0).get("list_id") != current_id \
			or int(current_record.get("wins", 0)) != 1 or int(current_record.get("stars", 0)) != 1 \
			or int(current_record.get("win_streak", 0)) != 1 or current_record.get("deck_name") != current_bot["deck_name"]:
		failures.append("A stale community bot remained playable or changed the current submission's record")

	# A late finish from the deleted bot still publishes match history, but must
	# never replay into the resubmission, even when the deck and owner match.
	var late_result := old_result.duplicate(true)
	late_result["match_id"] = "late_tiamat"
	late_result["owner_name"] = current_bot["owner_name"]
	late_result["is_community_bot"] = true
	var resubmitted_result := current_result.duplicate(true)
	resubmitted_result["match_id"] = "resubmitted_tiamat"
	resubmitted_result["list_id"] = resubmitted_id
	results.append_array([late_result, resubmitted_result])
	var resubmitted := {resubmitted_id: current_bot}
	restored.sync_community_bots(resubmitted)
	restored.refresh(results)
	var rebuilt := RankedBotDeckPoolScript.new()
	rebuilt.sync_community_bots(resubmitted)
	rebuilt.rebuild_league_records(results)
	for replayed_pool in [restored, rebuilt]:
		if not replayed_pool.get_deck_details(old_id).is_empty() or not replayed_pool.get_deck_details(current_id).is_empty() \
				or int(replayed_pool.get_deck_details(resubmitted_id).get("wins", 0)) != 1:
			failures.append("A deleted community submission or its record returned after resubmission")

func _bot_pool_result(match_id: String, list_id: String, cards: Dictionary, outcome: String, is_self_play: bool = false) -> Dictionary:
	return {
		"match_id": match_id,
		"list_id": list_id,
		"god_name": "Thor",
		"cards": cards,
		"special_setup": {},
		"reinforcements": {},
		"result": outcome,
		"is_self_play": is_self_play,
	}

func _script_path(card: Card) -> String:
	if card == null or card.get_script() == null:
		return ""
	return card.get_script().resource_path

func _known_good_deck_counts() -> Dictionary:
	return {
		"Thor": 1,
		"Askelladen": 3,
		"Berserker": 3,
		"Brown Bear": 3,
		"Byggvir": 3,
		"Bit Meseri": 3,
		"Absence": 3,
		"Warding Stone": 3,
		"Void Shield": 3,
		"Bearded Axe": 3,
		"Blot Sacrifice": 3,
		"Fall of the Mighty": 2,
		"Blessed Knights": 3,
		"Again-Walker": 3,
		"Alu": 2,
	}

func _cards_from_counts(card_counts: Dictionary) -> Array[Card]:
	var cards: Array[Card] = []
	for raw_card_name in card_counts.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(card_counts[raw_card_name])
		for _copy_index in range(maxi(0, count)):
			var card := CardCatalogScript.instantiate_card_by_name(card_name)
			if card != null:
				cards.append(card)
	return cards

func _write_result_file(success: bool, failures: PackedStringArray) -> void:
	var result_path := _get_result_path()
	if result_path.is_empty():
		return
	var parent_dir := result_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file == null:
		push_warning("preflight_probe: failed to open result file %s" % result_path)
		return
	if success:
		file.store_string("PASS\n")
	else:
		file.store_string("FAIL\n")
		for failure in failures:
			file.store_string("%s\n" % failure)
	file.flush()
	file.close()

func _get_result_path() -> String:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with(RESULT_ARG_PREFIX):
			var path := text.substr(RESULT_ARG_PREFIX.length()).strip_edges()
			if path.is_empty():
				return ""
			if path.begins_with("res://") or path.begins_with("user://"):
				return ProjectSettings.globalize_path(path)
			if path.is_absolute_path():
				return path
			return ProjectSettings.globalize_path("res://").path_join(path)
	return ""

func _check_gugalanna_celestial_charge(failures: PackedStringArray) -> void:
	_check_bot_gugalanna_celestial_charge(failures)
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	var gugalanna := GugalannaBullOfHeaven.new()
	gugalanna.card_owner = player
	player.frontline_zones[0].add_card(gugalanna)
	var defender := GenericCreature.new()
	defender.card_owner = opponent
	defender.resilience = 35
	defender.speed = 1
	opponent.frontline_zones[0].add_card(defender)
	gugalanna.apply_celestial_charge(game, defender)
	if defender.current_zone != opponent.graveyard_zone:
		failures.append("Gugalanna celestial charge did not send target to graveyard")
	if gugalanna.current_zone != player.hand_zone:
		failures.append("Gugalanna did not return to hand after celestial charge")
	var charge_action := CardAction.new()
	charge_action.type = CardAction.Type.EVENT
	charge_action.event_name = "gugalanna_celestial_charge"
	charge_action.card = gugalanna
	charge_action.target = defender
	charge_action.source_player = player
	player.frontline_zones[0].add_card(gugalanna)
	var hex := Smite.new()
	hex.card_owner = opponent
	var targets := game.get_attack_hex_targets(charge_action, hex)
	if targets.is_empty() or targets[0] != gugalanna:
		failures.append("get_attack_hex_targets failed to identify Gugalanna as celestial charge hex target")
	var normal_attack := CardAction.new()
	normal_attack.type = CardAction.Type.ATTACK
	normal_attack.attacker = gugalanna
	normal_attack.target = defender
	normal_attack.source_player = player
	var attack_targets := game.get_attack_hex_targets(normal_attack, hex)
	if attack_targets.is_empty() or attack_targets[0] != gugalanna:
		failures.append("get_attack_hex_targets failed for normal attack")

func _check_bot_gugalanna_celestial_charge(failures: PackedStringArray) -> void:
	var game := _new_fixture_game()
	var player := _new_fixture_player()
	var opponent := _new_fixture_player()
	game.players.assign([player, opponent])
	game.current_player = player
	game.other_player = opponent
	game.turn_number = 10
	game._upkeep_resolved_turn = game.turn_number
	game.has_resolved_attack_this_turn = true
	player.mana = 3
	var manager := _new_fixture_match(game)
	var bot := _new_fixture_bot()
	bot.attach(game, manager, ServerBotGameInput.new(manager, 0), 0)
	var gugalanna := GugalannaBullOfHeaven.new()
	gugalanna.card_owner = player
	player.hand_zone.add_card(gugalanna)
	var recruit := CreatureCard.new()
	recruit.card_owner = player
	recruit.mana_cost = 3
	recruit.strength = 35
	recruit.resilience = 25
	recruit.speed = 3
	player.hand_zone.add_card(recruit)
	var lesser_target := CreatureCard.new()
	lesser_target.card_owner = opponent
	lesser_target.speed = 1
	lesser_target.resilience = 30
	lesser_target.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[0].add_card(lesser_target)
	var thor := ThorActive.new()
	thor.card_owner = opponent
	thor.creature_mode = Card.CreatureMode.DEFENSIVE
	opponent.frontline_zones[1].add_card(thor)
	var plan := bot._plan_creature_summon(bot._forecast_incoming_follower_loss())
	if plan.get("command", {}).get("card_uid") != gugalanna.uid:
		failures.append("Bot did not plan Gugalanna as removal for an opposing Active Thor")
	elif not bot._submit_strategy_plan(plan):
		failures.append("Bot could not summon Gugalanna for Celestial Charge")
	else:
		for _step in range(8):
			manager.advance_priority()
		if thor.current_zone != opponent.graveyard_zone or gugalanna.current_zone != player.hand_zone:
			failures.append("Bot's Celestial Charge did not destroy Active Thor and return Gugalanna to hand")
		if lesser_target.current_zone != opponent.frontline_zones[0]:
			failures.append("Bot's Celestial Charge chose the weaker target over Active Thor")
	bot.detach()
