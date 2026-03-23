extends CombatMockGame
class_name CardTestGame

# Override start_game to set up a focused test board.
# Update this whenever a new card ability is coded.
func start_game() -> void:
	await super.start_game()
	_setup_test_board()

func _setup_test_board() -> void:
	# --- Testing: Aurboda "Pierce" + Asaruludu "Guardian" vs Askelladen "Tactful Retreat"
	#             + Ancient Pyre "Ritual Flame" ---
	#
	# P1: Aurboda (Pierce: Convert 7 on kill) + Asaruludu (Guardian: protects Ancient creatures)
	#     + Asakku (Ancient creature, protected by Guardian)
	#     + Ancient Pyre in reserve (backline: click to Convert 5 followers)
	# P2: Two BrownBears (kill with Aurboda to trigger Pierce x2)
	#     + Askelladen (SPD 2, fights Asakku SPD 1 — retreat blocked by Guardian)
	#
	# Tests:
	# - Aurboda kills a BrownBear: P2 loses 7 followers, P1 gains 7.
	# - Askelladen attacks Asakku (SPD 1 <= 2): retreat prompt should NOT appear (Guardian blocks it).
	# - Askelladen attacks Aurboda (non-Ancient, SPD 1 <= 2): retreat prompt SHOULD appear.
	# - Click Ancient Pyre (backline): converts 5 followers from P2 (costs 2 mana).
	# - Move Ancient Pyre to frontline, then click it: select a target to reduce Res by 5.

	var p1_aurboda := Aurboda.new()
	p1_aurboda.card_owner = player1
	p1_aurboda.creature_mode = Card.CreatureMode.ATTACK
	player1.frontline_zones[2].add_card(p1_aurboda)

	var p1_asaruludu := Asaruludu.new()
	p1_asaruludu.card_owner = player1
	p1_asaruludu.creature_mode = Card.CreatureMode.DEFENSE
	player1.frontline_zones[3].add_card(p1_asaruludu)

	var p1_asakku := Asakku.new()
	p1_asakku.card_owner = player1
	p1_asakku.creature_mode = Card.CreatureMode.ATTACK
	player1.frontline_zones[4].add_card(p1_asakku)

	var p2_bear1 := BrownBear.new()
	p2_bear1.card_owner = player2
	p2_bear1.creature_mode = Card.CreatureMode.ATTACK
	player2.frontline_zones[2].add_card(p2_bear1)

	var p2_bear2 := BrownBear.new()
	p2_bear2.card_owner = player2
	p2_bear2.creature_mode = Card.CreatureMode.ATTACK
	player2.frontline_zones[3].add_card(p2_bear2)

	var p2_askelladen := Askelladen.new()
	p2_askelladen.card_owner = player2
	p2_askelladen.creature_mode = Card.CreatureMode.ATTACK
	player2.frontline_zones[4].add_card(p2_askelladen)

	var p1_fate := AcceleratedFate.new()
	p1_fate.card_owner = player1
	player1.power_zones[0].add_card(p1_fate)

	var p1_pyre := AncientPyre.new()
	p1_pyre.card_owner = player1
	player1.reserve_zones[0].add_card(p1_pyre)

	var p1_pyre_front := AncientPyre.new()
	p1_pyre_front.card_owner = player1
	player1.frontline_zones[0].add_card(p1_pyre_front)

	player1.spend_mana(player1.mana)
	player1.gain_mana(5)
	player2.spend_mana(player2.mana)
	player2.gain_mana(5)

	game_manager.turn_number = 1
	update_ui()
