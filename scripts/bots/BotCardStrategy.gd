extends RefCounted

# Explicit rules, rather than ability-text guesses. Legal targets and timing
# always come from the authoritative card/manager before these scores are used.
const BAD := -1000000
const CARD_VALUE := 5000
const MANA_VALUE := 1000
# A face-up Kur-Jara on board is a repeatable value engine: Tree of Life
# withdraws it into the grave with a chosen Divine/Priest and resurrects both
# two own turns later, re-arming the ability while grave fuel remains. Price
# that repeatable resurrection well above its statline. During a pending
# cycle no new activation can start, and without grave fuel the engine is
# only potential, so the premium decays.
const KUR_JARA_ENGINE_PREMIUM := 2500
# Mana keeps some residual worth even when the stock passes everything the
# deck can still pay for: creature action taxes, equipment, and Guard always
# exist as buyers. Unbounded sinks raise that floor (see _mana_value_floor).
const MANA_VALUE_FLOOR_PCT := 15
const MANA_SINK_DEFENSIVE_FLOOR_PCT := 45
# How quickly the marginal rate decays per point of mana stock above the
# highest cost the remaining deck, hand, and board can still reach.
const MANA_SATURATION_DECAY := 0.4
const MIN_POWER_ACTIVATION_SCORE := 1200
# Meta reach/survival curves fitted to the ranked bot self-play window
# (copies-weighted creature statlines, 2026-11 snapshot). Reach = share of the
# field a strength value destroys (defender res <= strength); survival = share
# of the field that cannot destroy the body (attacker str < resilience).
# Aggressive defenders fight STR vs STR and defensive defenders STR vs RES, so
# both curves price the same currency: what the statline beats. The survival
# curve is steep through res 18-27 (res 21 survives ~54% of attackers, res 27
# ~84%), which the old flat res * 25 badly underpriced.
const META_REACH_ANCHOR_STATS := [0, 10, 15, 18, 21, 24, 27, 30, 36, 99]
const META_REACH_ANCHOR_SHARES := [0.0, 27.0, 49.5, 61.7, 73.1, 78.8, 93.0, 95.7, 99.3, 100.0]
const META_SURVIVAL_ANCHOR_STATS := [0, 9, 15, 18, 21, 24, 27, 30, 36, 99]
const META_SURVIVAL_ANCHOR_SHARES := [0.0, 10.0, 21.2, 39.7, 53.8, 73.8, 84.4, 92.6, 98.5, 100.0]
const META_STAT_POINT_WEIGHT := 23
const TACTICAL_CARDS := [
	"BitMeseri", "RunicSpellbreaker", "Snowball", "SirensSong", "TabletOfLife",
	"BookOfLife", "Earthquake", "FiresOfJudgment", "Famine", "OccultSingularity",
	"FalloftheMighty", "BaneOfTheSvartalfar", "CircleofRebirth", "Absence",
	"LightOfMorningsDoors", "FoolishOptimism", "DivineLightning", "FifaTheMagicalArrow", "Exorcism",
	"GungnirTheSpearOfOdin", "NamburbiApotropaeon", "HeroicStand", "Hringhorni",
	"Banishment", "SpellDemolition", "Sap", "SepLemutti", "Smite", "VoidShield", "ObsidianReflection",
	"TheInferno", "TheDeluge", "Dromi", "Gleipnir", "SapStrength", "VisionOfTartarus", "VisionOfOdin", "Hermes",
	"Drought", "HeavySnow", "Storm", "SavingGrace", "JiangZiyaFisherOfKings", "ShroudOfTheAncients", "WildMagic",
	"FairyBlast", "TheChangelingExchange",
]
const ACTIVE_POWERS := ["AcceleratedFate", "OraclesSight", "BerserkerMead", "MechFactory", "Palisade", "ManaGuard"]
const BOARD_ABILITIES := ["Alu", "Lindwyrm", "Lamashatu", "ClayEaters", "AncientPyre", "Watchtower", "Gawain", "Beyla", "Nimue", "JiangZiyaFisherOfKings",
	"Berserker", "EnHeduAnna", "GududPriest", "HariiShaman", "Isimud", "Mopsus", "SeventhSageUtuabzu", "WingedLion"]
# Creatures whose face-up value stealth suppresses, so they must not be summoned
# face-down. Card._abilities_disabled_by_hidden_state() turns every creature
# ability off while is_stealth is set, and the engine gates impact/kill/death
# hooks plus these self-gated passives on abilities_suppressed(). Printed
# Impact triggers are protected generically by BaseCard.declares_impact_trigger()
# in the bot's stealth gate, so this list is the backstop for those bodies and
# the registry for kill/death/passive-only ones. Reveal-trigger
# creatures (Afanc, PictishBeast, Grindylow, Lailoken, SulakTheUnclean...) are
# excluded on purpose: their payoff fires on reveal and is valued by the bot
# separately.
const STEALTH_SUPPRESSED_KEYS := [
	"AgainWalker", "AnkouServantToTheReaper", "AsagTheDestroyer", "Asakku", "Asaruludu",
	"Aurboda", "BlessedKnights", "Caleuche", "DurinnSecondborn", "EnkiLordOfEridu",
	"ErlqueensNightingale", "Fenrir", "FirstSageAdapa", "FourthSageEnmegalamma", "GalaTura",
	"Garm", "GiantMasterArchitect", "Gilgamesh", "GugalannaBullOfHeaven", "Gullinbursti",
	"HariiFransiscan", "HariiJarl", "HelBlarDraug", "HumbabaTheTerrible", "HyenaPack",
	"MalinalxochitlAcolyte", "MinotaurFootsoldier", "Nagual", "NergalLion", "PaiLongAutumnKing",
	"Pazuzu", "Pegasus", "RabidWolf", "Rabisu", "RedCap",
	"SixthSageAnEnlilda", "StoneMonkey", "TelchineApprentice", "Thiazi",
	"ThirdSageEnmedugga", "TianlongHolyDragon", "UriskGrovekeepers", "WhiteStag", "WolfAdolescent",
	"WolfCub",
]
const EQUIPMENT := ["BeardedAxe", "RunicShortsword", "ReedBow", "SharurTheFlyingMace", "SevenLeagueBoots", "DraupnirTheMultiplying", "Gambanteinn"]
const STRUCTURES := ["AncientPyre", "Watchtower", "WardingStone", "DoorwayToTheVoid", "E2Abzu",
	"AnointingStatue", "EriduCityOfSages", "GlitnirThePeaceful", "HildskjalfThroneOfOdin", "SleepOfTheDuat"]
const PLANNED_POWERS := ["AnankesBinding", "Breidablik", "WalkOfTheSage", "DivineCaprice", "FireAndGold"]
const PASSIVE_POWERS := ["ACostToWalkTheWorlds", "AdvancedBuildingTechniques", "FeastOfAmbrosiaAndNectar",
	"ImmortalTechniques", "LawsOfCivilization"]
const PASSIVE_TYPES := {
	"AncientWisdom": ["Mage"],
	"GiantsDisdain": ["Giant"], "SummonedSap": ["Plant", "Animal", "Hybrid"],
	"Terror": ["Demon"], "RallyTheTroops": ["Warrior"],
	"NorseBloodlust": ["Warrior", "Lupine"], "HuntingTactics": ["Warrior", "Lupine", "Raven"],
	"AltarOfDreams": ["Demon", "Spirit"], "Myrkwood": ["Animal"],
	"Kurnugia": ["Human", "Mer"],
}

static func key(card: Card) -> String:
	return card.get_script().resource_path.get_file().get_basename() if card != null else ""

static func supported(card: Card) -> bool:
	return key(card) in TACTICAL_CARDS

static func supports_ranked_deck_card(card: Card) -> bool:
	if card == null:
		return false
	if card is GodCard or card.card_type == Card.CardType.CREATURE:
		return true
	var id := key(card)
	if card is PowerCard:
		return id in ACTIVE_POWERS or id in PLANNED_POWERS or id in PASSIVE_POWERS or PASSIVE_TYPES.has(id) \
			or id in ["SavingGrace", "Ragnarok", "CallOfTheValkyrie", "AllfathersSacrifice", "FerociousDefence", "TakeTheField", "TonalExtraction"]
	return id in TACTICAL_CARDS or id in EQUIPMENT or id in STRUCTURES \
		or id in ["BlotSacrifice", "KeyOfSolomon", "MeadOfPoetry", "WheelOfFire", "ApollyonsDemiurge", "DeucalionsInfants", "TheChangelingExchange"]

static func visible(bot, card: Card) -> bool:
	if card == null:
		return false
	if card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.DECK:
		return card.current_zone.is_deck_card_publicly_known(card)
	if card.get_controller() == bot.bot_player:
		return true
	if card.current_zone == bot.opponent.hand_zone:
		return card.is_revealed_in_hand() or card.is_revealed_to_all()
	if card.current_zone in [bot.opponent.graveyard_zone, bot.opponent.abyss_zone]:
		return true
	return card.is_publicly_identified(bot.game_manager) or not (card.is_face_down or card.is_stealth)

static func open_spaces(player: Player) -> int:
	var count := 0
	for zone in player.frontline_zones + player.reserve_zones:
		if zone.cards.is_empty():
			count += 1
	return count

static func follower_gain(player: Player, amount: int) -> int:
	return amount * (600 if player.followers < 25 else 350 if player.followers < 50 else 200)

static func _meta_curve_share(anchor_stats: Array, anchor_shares: Array, stat: int) -> float:
	var clamped_value := maxi(0, stat)
	for index in range(1, anchor_stats.size()):
		if clamped_value <= int(anchor_stats[index]):
			var span := float(anchor_stats[index] - anchor_stats[index - 1])
			if span <= 0.0:
				return float(anchor_shares[index])
			var progress := float(clamped_value - int(anchor_stats[index - 1])) / span
			return lerpf(float(anchor_shares[index - 1]), float(anchor_shares[index]), progress)
	return float(anchor_shares[anchor_shares.size() - 1])

static func _strength_reach_points(strength: int) -> int:
	return int(_meta_curve_share(META_REACH_ANCHOR_STATS, META_REACH_ANCHOR_SHARES, strength) * META_STAT_POINT_WEIGHT)

static func _resilience_survival_points(resilience: int) -> int:
	return int(_meta_curve_share(META_SURVIVAL_ANCHOR_STATS, META_SURVIVAL_ANCHOR_SHARES, resilience) * META_STAT_POINT_WEIGHT)

static func value(bot, card: Card) -> int:
	if card == null:
		return 0
	if card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.DECK \
			and card.current_zone.zone_owner == bot.bot_player:
		# The owner knows its own remaining deck composition, so its deck
		# cards keep their real value instead of the generic unknown price.
		pass
	elif not visible(bot, card):
		return CARD_VALUE
	if card is WardingStone and card.get_attack_restriction_turns_remaining(bot.game_manager) <= 0:
		return bot._get_inactive_warding_stone_value(card)
	# Body value uses the meta-fitted curves above: strength prices at what it
	# can destroy, resilience at what survives it, so walls stop scoring at a
	# fraction of an attacker's value. (Old flat split: str * 80 + res * 25.)
	var score := CARD_VALUE + _strength_reach_points(card.get_effective_strength()) \
		+ _resilience_survival_points(card.get_effective_resilience()) \
		+ maxi(0, card.mana_cost) * 200
	score += kur_jara_engine_premium(card)
	if card.is_god and _would_destroying_god_cause_god_death(bot, card):
		var owner := card.get_controller()
		score += bot._score_follower_loss(owner, GameManager.GOD_DEATH_FOLLOWER_LOSS) + MANA_VALUE
	return score

static func kur_jara_engine_premium(card: Card) -> int:
	if not (card is KurJara):
		return 0
	var zone := card.current_zone
	if zone == null or not zone.is_board_zone() or card.is_face_down \
			or card.is_sleeping or card.abilities_suppressed():
		return 0
	if card.get_tree_of_life_target() != null or card.get_tree_of_life_pending_destroy_count() > 0:
		# A cycle is already running: the body survives in the grave and
		# comes back, but nothing new can activate until it resolves.
		@warning_ignore("integer_division")
		return KUR_JARA_ENGINE_PREMIUM / 2
	var fuel := false
	if card.card_owner != null and card.card_owner.graveyard_zone != null:
		for engine_card in card.card_owner.graveyard_zone.cards:
			if engine_card != null and engine_card.card_type == Card.CardType.CREATURE \
					and (engine_card.has_type("Divine") or engine_card.has_type("Priest")):
				fuel = true
				break
	# Graves are public board knowledge, so fuel is visible to both sides.
	@warning_ignore("integer_division")
	return KUR_JARA_ENGINE_PREMIUM if fuel else KUR_JARA_ENGINE_PREMIUM / 3

static func _would_destroying_god_cause_god_death(bot, god: Card) -> bool:
	if bot == null or bot.game_manager == null or god == null or not god.is_god:
		return false
	var owner := god.get_controller()
	return owner != null \
		and god.current_zone == owner.god_zone \
		and owner.has_had_god_in_play \
		and not bot.game_manager.player_has_face_up_awake_active_god(owner)

static func combat_visible(bot, action: CardAction) -> bool:
	if action == null or not visible(bot, action.attacker):
		return false
	var defender: Card = bot._get_attack_defender_card(action)
	return defender == null or visible(bot, defender)

static func mana_penalty(bot, amount: int, available_mana: int = -1, ignore_altar_hold := false) -> int:
	# Spending prices each paid point of mana at its own marginal rate: the
	# last points of a large stock are nearly free once nothing in the deck
	# can still use them, while early points of a tight stock are expensive.
	var stock: int = bot.bot_player.mana if available_mana < 0 else available_mana
	var spend := maxi(0, amount)
	var score := 0
	for index in range(spend):
		score += marginal_mana_value(bot, stock - index)
	if spend > 0 and not bot.bot_player.has_summoned_this_turn:
		var creature: Card = bot._get_best_affordable_hand_creature(0)
		if creature != null and bot._get_play_cost(creature, false) > bot.bot_player.mana - spend:
			@warning_ignore("integer_division")
			score += CARD_VALUE / 2
	# A spend that dips the stock below the held Altar of Dreams line's
	# funding strands its removal window until later upkeep income rebuilds
	# the dip, so competing plays carry a share of the payoff they spend
	# away. The line's own steps pass `ignore_altar_hold` so the unlock, the
	# sleep activation, and the Void-fuelled summon never pay for holding
	# themselves open.
	if spend > 0 and not ignore_altar_hold:
		score += altar_line_hold_charge(bot, stock, spend)
	return score

static func mana_gain_value(bot, amount: int, at_level: int = -1) -> int:
	# Mirror of mana_penalty for mana production (ramp, upkeep income,
	# mana-gain triggers). New stock arrives on top of the current level.
	var stock: int = bot.bot_player.mana if at_level < 0 else at_level
	var gain := maxi(0, amount)
	var score := 0
	for index in range(gain):
		score += marginal_mana_value(bot, stock + index)
	return score

static func marginal_mana_value(bot, level: int = -1) -> int:
	var stock: int = bot.bot_player.mana if level < 0 else level
	var econ := _mana_econ(bot)
	var ceiling := int(econ["ceiling"])
	if stock <= ceiling:
		return MANA_VALUE
	var decayed := int(float(MANA_VALUE) / (1.0 + float(stock - ceiling) * MANA_SATURATION_DECAY))
	return maxi(int(econ["floor"]), decayed)

# The saturation scan touches the whole hand, deck, and board on every call,
# and decisions read the rate dozens of times per step. The bot clears this
# cache when a decision tick starts (run step, priority, and prompt entry),
# so one scan serves an entire evaluation pass.
static func _mana_econ(bot) -> Dictionary:
	var cache = bot.get("_mana_econ_cache")
	if cache is Dictionary and cache.has("ceiling"):
		return cache
	var fresh := {"ceiling": _mana_saturation_ceiling(bot), "floor": _mana_value_floor(bot)}
	bot.set("_mana_econ_cache", fresh)
	return fresh

# The highest mana cost the bot can still grow into: hand plays, prepared
# activations, remaining deck composition (the owner knows its own deck),
# power unlocks and activations, and god abilities. Income for one more turn
# is included so a deck with an expensive card still justifies saving.
static func _mana_saturation_ceiling(bot) -> int:
	var player: Player = bot.bot_player
	var top := 0
	for card in player.hand_zone.cards:
		top = maxi(top, bot._get_play_cost(card, false))
		top = maxi(top, bot._get_play_cost(card, true))
	for card in player.deck_zone.cards:
		top = maxi(top, maxi(0, card.mana_cost))
	# A Mer Mage stranded in the Void is still spend potential while E2-abzu
	# can retrieve it: the structure's level-under-mana rule needs the whole
	# retrieval price plus the mage's level on hand, so banking toward that
	# line keeps mana at full rate instead of decaying as surplus the bot
	# happily spends down every turn.
	if e2_abzu_available(bot):
		for void_card in player.abyss_zone.cards:
			if void_card == null or void_card.is_god \
					or void_card.card_type != Card.CardType.CREATURE \
					or not void_card.has_type("Mer") or not void_card.has_type("Mage"):
				continue
			top = maxi(top, E2Abzu.RETURN_TO_HAND_COST + 1 + void_card.get_effective_level())
	for zone in player.power_zones:
		for card in zone.cards:
			if card is PowerCard:
				top = maxi(top, card.get_unlock_mana_cost(bot.game_manager))
				top = maxi(top, activation_cost(bot, card))
	for card in bot.game_manager.get_field_cards(player):
		if card.is_prepared:
			top = maxi(top, activation_cost(bot, card))
		if card is GodCard and card.has_method("get_activation_mana_cost"):
			top = maxi(top, card.get_activation_mana_cost(bot.game_manager))
		top = maxi(top, board_ability_save_ceiling(bot, card))
	if top <= 0:
		return 0
	var income: int = bot.game_manager.get_automatic_upkeep_mana_gain(player, bot.game_manager.turn_number + 1) \
		+ bot.game_manager.get_effective_upkeep_mana_gain(bot.game_manager.get_base_upkeep_mana_gain(), player)
	# A visible enemy Pazuzu drains the banked stock before the next turn can
	# spend it, so mana held for later is worth less while it lives.
	if bot.has_method("_incoming_mana_drain"):
		income -= int(bot._incoming_mana_drain())
	return top + income

# Board abilities priced by their target (Nimue's Entomb charges the target's
# level) are spend potential even when today's mana is short. A premium
# visible enemy body on the board keeps mana worth banking until the
# activation is actually affordable, the same way an expensive card in the
# deck does; without this the bot spends down every turn and never reaches
# the level of a high-cost target it should be saving for.
static func board_ability_save_ceiling(bot, card: Card) -> int:
	if bot == null or bot.opponent == null or not (card is Nimue) \
			or card.current_zone == null or not card.current_zone.is_board_zone() \
			or card.abilities_suppressed():
		return 0
	var best_level := 0
	for zone in bot.opponent.frontline_zones + bot.opponent.reserve_zones:
		if zone == null:
			continue
		for target in zone.cards:
			if target == null or not visible(bot, target) \
					or target.card_type != Card.CardType.CREATURE:
				continue
			best_level = maxi(best_level, target.get_effective_level())
	if best_level <= 0:
		return 0
	return best_level + bot.game_manager.get_creature_action_mana_cost(card, "activate")

# Mana never falls to zero because action taxes, equipment, and Guard remain.
# Unbounded sinks lift the floor further, and a sink that advances the actual
# win condition (Ancient Pyre's follower conversion) keeps mana at full rate:
# every point converts directly into follower swing regardless of stock size.
static func _mana_value_floor(bot) -> int:
	var profile := mana_sink_profile(bot)
	if bool(profile.get("win_condition", false)):
		return MANA_VALUE
	if bool(profile.get("defensive", false)):
		@warning_ignore("integer_division")
		return MANA_VALUE * MANA_SINK_DEFENSIVE_FLOOR_PCT / 100
	@warning_ignore("integer_division")
	return MANA_VALUE * MANA_VALUE_FLOOR_PCT / 100

static func mana_sink_profile(bot) -> Dictionary:
	var profile := {"win_condition": false, "defensive": false}
	var player: Player = bot.bot_player
	if bot.opponent == null or not bot.game_manager.can_player_lose_followers_now(bot.opponent):
		return profile
	for card in bot.game_manager.get_field_cards(player):
		if card is AncientPyre and not card.abilities_suppressed() \
				and card.can_activate(bot.game_manager):
			profile["win_condition"] = true
			break
	if not bool(profile.get("win_condition", false)):
		for zone in player.power_zones:
			for card in zone.cards:
				if card is ManaGuard and not card.abilities_suppressed():
					profile["defensive"] = true
				elif card is AdvancedBuildingTechniques and not card.abilities_suppressed():
					profile["defensive"] = true
	return profile

static func activation_cost(bot, card: Card) -> int:
	if card is PowerCard:
		if card.has_method("get_activation_cost_hover_data"):
			var data: Dictionary = card.get_activation_cost_hover_data(bot.game_manager)
			return int(data.get("current_cost", card.get_activation_mana_cost(int(data.get("base_cost", 0)), bot.game_manager)))
		return 0
	if card.is_prepared:
		return bot.game_manager.get_prepared_card_activation_mana_cost(bot.bot_player, card)
	return bot._get_play_cost(card, false)

static func targets(bot, card: Card, action: CardAction = null) -> Array:
	if card is HexCard and action != null:
		return bot.game_manager.get_priority_hex_targets(card, action)
	if card is CharmCard and action != null:
		return card.get_priority_targets(bot.game_manager, action)
	if action != null and card.has_method("get_priority_field_targets"):
		return card.get_priority_field_targets(bot.game_manager, action)
	match key(card):
		"BookOfLife":
			return card.get_valid_hand_creatures()
		"Absence":
			var choices: Array = bot.opponent.god_zone.cards.duplicate()
			for zone in bot.opponent.power_zones:
				choices.append_array(zone.cards)
			return choices
	if card.has_method("get_valid_targets"):
		return card.get_valid_targets(bot.game_manager)
	return []

static func best_target(bot, card: Card, choices: Array, action: CardAction = null) -> Card:
	var best: Card = null
	var score := BAD
	for choice in choices:
		if not choice is Card:
			continue
		var candidate := target_score(bot, card, choice, action)
		if candidate > score:
			score = candidate
			best = choice
	return best if score > 0 else null

static func removal_score(bot, source: Card, target: Card, action: CardAction = null, destruction: bool = true) -> int:
	if target == null or target.get_controller() != bot.opponent:
		return BAD
	var gm: GameManager = bot.game_manager
	if counterstroke_can_answer(bot, target, source, action, false):
		return BAD
	if visible(bot, target):
		if gm.is_immune_to_source(target, source):
			return BAD
		if destruction and destruction_guard(target):
			return BAD
		if destruction and target.card_type == Card.CardType.CREATURE and gm.has_turn_destruction_ward(bot.opponent):
			return BAD
	# A Siren's Song-style steal only lends the body: destroying a creature we
	# own while the opponent borrows it sends OUR card to the graveyard instead
	# of taking it back at end of turn. Price that destruction as a loss and
	# keep only the avoided-combat credit. Enslavement is a permanent flip, so
	# an enslaved body stays a normal removal target.
	if destruction and target.card_owner == bot.bot_player \
			and target.get_controller() != target.card_owner and not target.is_enslaved():
		var borrowed_loss := -value(bot, target)
		if action != null and action.type == CardAction.Type.ATTACK \
				and combat_visible(bot, action) \
				and (action.attacker == target or bot._get_attack_defender_card(action) == target):
			borrowed_loss -= bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
		return borrowed_loss
	var score := value(bot, target)
	score -= _debilitation_discount(bot, target)
	score -= _own_dromi_drain_loss(bot, target)
	score += _attached_debuff_release_value(bot, target)
	# Removing a combatant cancels this attack. Credit only the improvement
	# over letting the existing combat finish, including profitable trades.
	if action != null and action.type == CardAction.Type.ATTACK:
		if combat_visible(bot, action) and (action.attacker == target or bot._get_attack_defender_card(action) == target):
			score -= bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
	else:
		@warning_ignore("integer_division")
		score += CARD_VALUE / 5
	return score

static func _debilitation_discount(bot, target: Card) -> int:
	if target == null or (target.card_type != Card.CardType.CREATURE and not target.is_petrified()) or not visible(bot, target) \
			or target.current_zone == null or not target.current_zone.is_board_zone():
		return 0
	var disables := _disable_durations(bot, target)
	var weight := 0.4 * _disable_weight(disables.get("cannot_attack", 0.0))
	weight += 0.2 * _disable_weight(disables.get("cannot_intercept", 0.0))
	weight += 0.1 * _disable_weight(disables.get("cannot_move", 0.0))
	weight += 0.15 * _disable_weight(disables.get("activation_locked", 0.0))
	weight += 0.1 * _disable_weight(disables.get(Card.ABILITY_NEGATED_STATUS, 0.0))
	var other_effects := {}
	for status in target._get_effective_statuses():
		var name := str(status.get("name", ""))
		if name not in ["poison", "destroy_at_turn_end", "freyja_active_open_sessrumnir", "tonal_extraction_no_shift"]:
			continue
		var duration := 1.0
		if name != "destroy_at_turn_end" and (status.get("expires_after_combat", false) \
				or int(status.get("expires_turn", bot.game_manager.turn_number + 2)) <= bot.game_manager.turn_number + 1):
			duration = 0.5
		other_effects[name] = maxf(float(other_effects.get(name, 0.0)), duration)
	weight += 0.15 * float(other_effects.get("poison", 0.0))
	weight += 0.75 * float(other_effects.get("destroy_at_turn_end", 0.0))
	weight += 0.6 * float(other_effects.get("freyja_active_open_sessrumnir", 0.0))
	weight += 0.1 * float(other_effects.get("tonal_extraction_no_shift", 0.0))
	# Strength and resilience penalties are already in value(); only speed
	# needs a separate adjustment.
	var speed_loss := maxi(0, target.speed - target.get_effective_speed()) * 150
	return int(value(bot, target) * minf(weight, 0.85)) + speed_loss

static func status_duration(game: GameManager, target: Card, status: Dictionary) -> float:
	# Count the rest of the current turn as one turn. Combat-only effects
	# cover a smaller part of that window.
	var expires_turn = status.get("expires_turn")
	var duration := INF if expires_turn == null else maxf(0.0, int(expires_turn) - game.turn_number + 1)
	if status.get("expires_after_combat", false):
		return minf(duration, 0.5)
	if status.get("name") != "sleep":
		return duration
	var source := status.get("source_card") as Card
	if source is Gambanteinn:
		return minf(duration, 1.0)
	if source is Berserker:
		return minf(duration, 2.0 if game.current_player == source.get_controller() else 1.0)
	if source is BerserkerMead:
		for entry in source.affected_creatures:
			if entry.get("creature") == target and entry.get("state") == "sleeping":
				var until_owner_turn := 0 if game.current_player == source.get_controller() else 1
				if game.turn_number + until_owner_turn <= int(entry.get("sleep_started_turn", -1)):
					until_owner_turn += 2
				return minf(duration, until_owner_turn + 1)
	return duration

static func _mute_duration(game: GameManager, target: Card, owner_turns: int, skip_current: bool) -> float:
	if owner_turns < 0:
		return INF
	if owner_turns == 0:
		return 0.0
	if game.current_player == target.card_owner:
		return 2 * owner_turns + (1 if skip_current else -1)
	return 2 * owner_turns

static func _extend_disables(durations: Dictionary, restrictions: Array, duration: float) -> void:
	for restriction in restrictions:
		durations[restriction] = maxf(durations.get(restriction, 0.0), duration)

static func _disable_durations(bot, target: Card, include_pending: bool = false) -> Dictionary:
	var durations := {}
	for status in target._get_effective_statuses():
		var name := str(status.get("name", ""))
		var duration := status_duration(bot.game_manager, target, status)
		match name:
			"sleep":
				_extend_disables(durations, ["cannot_attack", "cannot_intercept"], duration)
			"petrified":
				_extend_disables(durations, ["cannot_attack", "cannot_intercept", "cannot_move", "activation_locked", Card.ABILITY_NEGATED_STATUS], duration)
			"paralyzed", "paralyze":
				_extend_disables(durations, ["cannot_attack", "cannot_intercept", "cannot_move"], duration)
			Card.ABILITY_NEGATED_STATUS:
				_extend_disables(durations, ["activation_locked", Card.ABILITY_NEGATED_STATUS], duration)
			"cannot_attack", "cannot_intercept", "cannot_move", "activation_locked":
				_extend_disables(durations, [name], duration)
	if target.is_muted or target.is_enslaved():
		var skip_current: bool = target._mute_applied_owner_turn_number == bot.game_manager.turn_number
		var duration := INF if target.is_enslaved() else _mute_duration(bot.game_manager, target, target.mute_turns_remaining, skip_current)
		_extend_disables(durations, ["activation_locked", Card.ABILITY_NEGATED_STATUS], duration)
	if include_pending:
		for pending: CardAction in bot.game_manager.action_stack:
			if pending.target != target or pending in bot.game_manager.resolving_stack_actions:
				continue
			if pending.card is Dromi or pending.card is Gleipnir:
				_extend_disables(durations, ["cannot_attack"], INF)
			if pending.card is Gleipnir:
				_extend_disables(durations, ["cannot_intercept", "activation_locked", Card.ABILITY_NEGATED_STATUS], INF)
	return durations

static func _disable_weight(duration: float) -> float:
	return 1.0 - pow(0.65, duration)

static func _disable_gain(bot, target: Card, values: Dictionary, duration: float = INF) -> int:
	var existing := _disable_durations(bot, target, true)
	var proposed := _disable_weight(duration)
	var gain := 0.0
	for restriction in values:
		gain += float(values[restriction]) * maxf(0.0, proposed - _disable_weight(existing.get(restriction, 0.0)))
	return roundi(gain)

static func adds_attack_lock_next_turn(bot, target: Card) -> bool:
	return float(_disable_durations(bot, target, true).get("cannot_attack", 0.0)) <= 1.0

static func adds_intercept_lock_this_turn(bot, target: Card) -> bool:
	return float(_disable_durations(bot, target, true).get("cannot_intercept", 0.0)) < 1.0

static func mute_gain(bot, target: Card, owner_turns: int, full_value: int) -> int:
	var duration := _mute_duration(bot.game_manager, target, owner_turns, true)
	# Mute replaces its own timer. Only value the turns beyond existing coverage.
	var values := {"activation_locked": full_value * 0.6, Card.ABILITY_NEGATED_STATUS: full_value * 0.4}
	return roundi(_disable_gain(bot, target, values, duration) / _disable_weight(duration))

static func _own_dromi_drain_loss(bot, target: Card) -> int:
	if target == null or target.get_controller() != bot.opponent or not visible(bot, target):
		return 0
	var bindings: Array[Dromi] = []
	for status in target._get_effective_statuses():
		if status.get("name", "") != "cannot_attack":
			continue
		var binding := status.get("source_card") as Dromi
		if binding == null or binding.get_controller() != bot.bot_player \
				or binding.attached_target != target or binding.current_zone == null \
				or not binding.current_zone.is_board_zone():
			continue
		if binding not in bindings:
			bindings.append(binding)
	if bindings.is_empty():
		return 0
	# The attack lock is priced by _debilitation_discount(). Cap uncertain
	# future drain so a possible later lethal does not outrank one now.
	var drain_value := mini(CARD_VALUE, bot._score_follower_loss(bot.opponent, Dromi.FOLLOWER_LOSS))
	return int(bindings.size() * drain_value * 1.5)

# Dromi drains 7 followers at the start of each of its target's turns and
# stays as long as the target does. The attack lock prices the first two
# turns; credit the ticking when the target is likely to persist (it is not
# trading into combat) and when the drain itself closes the game.
static func _dromi_drain_turns(bot, target: Card) -> int:
	var turns := 2
	if target != null and (target.creature_mode == Card.CreatureMode.DEFENSIVE or target.is_stealth):
		turns += 1
	if bot.opponent != null:
		var pool: int = bot.opponent.followers
		if pool <= 2 * Dromi.FOLLOWER_LOSS:
			turns += 2
		elif pool <= 4 * Dromi.FOLLOWER_LOSS:
			turns += 1
	return turns

static func _attached_debuff_release_value(bot, source: Card) -> int:
	if not (source is PermanentHexCard):
		return 0
	var attached := (source as PermanentHexCard).attached_target
	if attached == null or not visible(bot, attached) or attached.current_zone == null \
			or not attached.current_zone.is_board_zone() or attached.get_controller() != bot.bot_player:
		return 0
	var weight := 0.0
	for status in attached._get_effective_statuses():
		if status.get("source_card", null) != source:
			continue
		match str(status.get("name", "")):
			"cannot_attack":
				# Scale by the creature's own value so freeing a large body is worth
				# more than freeing a small one.
				weight += 0.65
			"cannot_intercept":
				weight += 0.35
			"activation_locked":
				weight += 0.4
			"petrified":
				weight += 0.8
			"sleep":
				weight += 0.25
			"ability_negated", "muted":
				weight += 0.4
	for buff in attached._get_effective_buffs():
		if buff.get("source_card", null) != source:
			continue
		var weakened_stats := maxi(0, -int(buff.get("str", 0))) \
			+ maxi(0, -int(buff.get("res", 0))) \
			+ maxi(0, -int(buff.get("spd", 0))) * 2
		weight += minf(0.5, float(weakened_stats) / 30.0)
	return int(float(value(bot, attached)) * minf(weight, 1.0))

static func counterstroke_can_answer(
	bot,
	target: Card,
	source: Card,
	action: CardAction = null,
	is_attack: bool = false
) -> bool:
	if not (target is JiangZiyaFisherOfKings) or source == null or bot == null or bot.game_manager == null:
		return false
	if target.get_controller() != bot.opponent or not visible(bot, target):
		return false
	if target.tactic_counters < JiangZiyaFisherOfKings.TACTIC_COUNTER_COST \
			or not target._can_use_counter_abilities(bot.game_manager):
		return false
	if source.get_controller() != bot.bot_player:
		return false
	if is_attack and bot.game_manager.is_immune_to_source(source, target):
		return false
	if not is_attack and not bot.game_manager.is_targeting_source(source):
		return false
	var threat := action if action != null else CardAction.new()
	if action == null:
		if is_attack:
			threat.type = CardAction.Type.ATTACK
		elif source.card_type == Card.CardType.SPELL:
			threat.type = CardAction.Type.SPELL
		elif source.card_type == Card.CardType.CHARM:
			threat.type = CardAction.Type.CHARM
		else:
			threat.type = CardAction.Type.ABILITY
		threat.source_player = source.get_controller()
		threat.target = target
		if is_attack:
			threat.attacker = source
		else:
			threat.card = source
	if not is_attack and source.has_method("can_be_negated") and not source.can_be_negated(threat):
		return false
	return true

static func _jiang_counterstroke_reserve_value(bot, jiang: Card) -> int:
	if not (jiang is JiangZiyaFisherOfKings) or bot == null or bot.opponent == null:
		return 0
	var reserve_value := 3500 if jiang.current_zone in bot.bot_player.frontline_zones else 1800
	for attacker: Card in bot._get_board_creatures(bot.opponent):
		if attacker.current_zone in bot.opponent.frontline_zones \
				and visible(bot, attacker) \
				and not attacker.is_sleeping \
				and not attacker.has_status_effect("cannot_attack") \
				and bot._can_attack_creature(attacker, jiang):
			reserve_value = maxi(reserve_value, int((value(bot, jiang) + value(bot, attacker)) / 2.0))
	return reserve_value

static func destruction_guard(target: Card) -> bool:
	return target.has_status_effect("berserker_mead_guard") or target.has_status_effect("berserker_rage_guard") or target.has_status_effect("en_hedu_anna_exaltation_guard")

static func can_remove_from_board(bot, source: Card, target: Card, destroys: bool, targeted: bool = true) -> bool:
	if source == null or target == null or target.current_zone == null or not target.current_zone.is_board_zone():
		return false
	if not visible(bot, target):
		return true
	var game: GameManager = bot.game_manager
	if game.is_immune_to_source(target, source) or (targeted and game.is_guardian_protected(target, source)):
		return false
	if not destroys:
		return true
	if destruction_guard(target) or (target.card_type == Card.CardType.CREATURE and target.get_controller() != source.get_controller() \
			and game.has_turn_destruction_ward(target.get_controller())):
		return false
	var replacement: Zone = null
	if target is BaseCard and not target.abilities_suppressed():
		replacement = target.get_self_graveyard_replacement_zone(game, false, true, false)
	return replacement == null or not replacement.is_board_zone()

static func removal_targets(bot, source: Card, target: Card = null, action: CardAction = null) -> Array:
	var victims: Array = []
	var destroys := true
	var targeted := true
	match key(source):
		"BitMeseri", "Mummu", "Nimue", "AphroditeAreia", "SepLemutti", "Terror":
			destroys = false
			victims = [target]
		"VoidShield":
			destroys = false
			victims = [target if target != null else action.attacker] if action != null else []
		"Smite":
			victims = [target if target != null else action.attacker] if action != null else []
		"GungnirTheSpearOfOdin":
			victims = [bot._get_attack_defender_card(action)] if action != null else []
		"DivineLightning", "RunicSpellbreaker", "GuanYu", "Lindwyrm", "Fenrir", "ClayEaters", "MasmassuPriest", "Grindylow", "GugalannaBullOfHeaven", "Sap":
			victims = [target]
		"AncientPyre":
			if target != null and source.is_frontline() and visible(bot, target) and target.get_effective_resilience() <= AncientPyre.EFFECT_AMOUNT:
				victims = [target]
		"E2Abzu":
			destroys = false
			if action != null and bot.game_manager.current_player == bot.opponent:
				victims = [target]
		"Ragnarok":
			targeted = false
			victims = bot.game_manager.get_field_cards()
		"TheInferno", "TheDeluge", "Earthquake", "FiresOfJudgment", "Famine", "OccultSingularity", "FalloftheMighty", "BaneOfTheSvartalfar":
			targeted = false
			destroys = not source is BaneOfTheSvartalfar
			victims = wipe_cards(bot, source)
	return victims.filter(func(victim: Card) -> bool: return can_remove_from_board(bot, source, victim, destroys, targeted))

# Explicit effect data feeds the same projection for main-phase buffs, responses,
# and attacks that only become worthwhile after a response. Never mutate cards
# or infer effects from their display text while planning.
static func stat_changes(bot, card: Card, target: Card) -> Dictionary:
	match key(card):
		"VisionOfOdin":
			var sign_value := 1 if target.culture == "Norse" else -1
			return {"str": sign_value * VisionOfOdin.STR_SWING, "res": 0, "spd": sign_value * VisionOfOdin.SPEED_SWING}
		"Hermes": return {"str": 0, "res": 0, "spd": Hermes.SPEED_BONUS}
		"Snowball": return {"str": -2, "res": 0, "spd": 0}
		"FairyBlast":
			var fairy_str := target.get_effective_strength() if target != null else 0
			var fairy_spd := target.get_effective_speed() if target != null else 0
			return {"str": -int(fairy_str / 2.0), "res": 0, "spd": -int(fairy_spd / 2.0)}
		"SapStrength": return {"str": -10, "res": 0, "spd": 0}
		"VisionOfTartarus":
			var reduction: int = -3 * card._count_void_creatures(bot.game_manager)
			return {"str": reduction, "res": reduction, "spd": 0}
		"FifaTheMagicalArrow": return {"str": FifaTheMagicalArrow.STR_BONUS, "res": 0, "spd": 0}
		"BerserkerMead": return {"str": BerserkerMead.STR_BONUS, "res": 0, "spd": 0}
		"Lamashatu":
			return {
				"str": Lamashatu.SUCKLE_STRENGTH_BONUS, "res": Lamashatu.SUCKLE_RESILIENCE_BONUS,
				"spd": Lamashatu.SUCKLE_SPEED_BONUS,
			}
		"SevenLeagueBoots":
			var old_base: int = target.speed - (1 if target.is_stealth else 0)
			for equipment in target.equipment:
				if equipment.has_method("get_speed_override_for_equipped_creature"):
					var override_speed = equipment.get_speed_override_for_equipped_creature(target)
					if override_speed != null:
						old_base = int(override_speed)
			return {"str": 0, "res": 0, "spd": SevenLeagueBoots.SPEED_OVERRIDE - old_base}
	if card is EquipmentCard:
		return {"str": card.strength_modifier, "res": card.resilience_modifier, "spd": card.speed_modifier}
	return {}

static func stat_gain(bot, card: Card, target: Card, action: CardAction = null) -> int:
	if target.negates_external_effects() and card != target:
		return 0
	var changes := stat_changes(bot, card, target)
	# Fifa lasts through the recipient's next fight. Equipment and Suckle
	# can also matter on a later turn. The other supported buffs expire this turn.
	var future_turns := 2 if card is EquipmentCard or card is Lamashatu or card is FifaTheMagicalArrow else 0
	return combat_gain(bot, target, int(changes.get("str", 0)), int(changes.get("res", 0)), action, int(changes.get("spd", 0)), future_turns)

static func combat_projection(bot, action: CardAction) -> Dictionary:
	var pending := {}
	if action != null and action in bot.game_manager.action_stack:
		var stack: Array[CardAction] = bot.game_manager.action_stack
		var negated: Array[CardAction] = []
		for index in range(stack.find(action), -1, -1):
			var queued := stack[index]
			if queued in negated or queued in bot.game_manager.resolving_stack_actions:
				continue
			if queued.type == CardAction.Type.ATTACK:
				action = queued
				break
			if queued.card is Banishment or queued.card is SpellDemolition:
				# Local actions carry the link. Snapshots keep the stack in resolution order.
				var countered := queued.response_to
				if countered == null and index > 0:
					countered = stack[index - 1]
				negated.append(countered)
				continue
			if not (queued.card is Card) or not (queued.target is Card):
				continue
			var target_card: Card = queued.target
			var changes := additive_combat_stats(bot, queued.card, target_card)
			if changes != Vector3i.ZERO:
				pending[target_card] = pending.get(target_card, Vector3i.ZERO) + changes
	return {"attack": action if action != null and action.type == CardAction.Type.ATTACK else null, "stats": pending}

static func combat_gain(bot, target: Card, str_delta: int, res_delta: int = 0, action: CardAction = null, speed_delta: int = 0, future_turns: int = 0) -> int:
	var delta := Vector3i(str_delta, res_delta, speed_delta)
	if delta == Vector3i.ZERO or not visible(bot, target):
		return 0
	var projection := combat_projection(bot, action)
	var pending: Dictionary = projection["stats"]
	var proposed := pending.duplicate()
	proposed[target] = pending.get(target, Vector3i.ZERO) + delta
	if action != null:
		var attack := projection["attack"] as CardAction
		if attack != null:
			if not combat_visible(bot, attack) or (attack.united_front_partner != null and not visible(bot, attack.united_front_partner)):
				return 0
			return _projected_combat_score(bot, attack, proposed) - _projected_combat_score(bot, attack, pending)
		if pending.is_empty():
			return 0
	if bot.game_manager.current_player != bot.bot_player:
		return 0
	var best: int = bot._forecast_stat_combat_gain(target, pending, proposed, 0)
	if bot._can_win_followers_after_modifiers(proposed) and not bot._can_win_followers_after_modifiers(pending):
		best = maxi(best, CARD_VALUE * 20)
	# During priority, let the existing stack settle before planning a later fight.
	var forecast_turns := future_turns if action == null else 0
	for turn_offset in range(1, forecast_turns + 1):
		var after_expiry: Dictionary = bot._forecast_expired_combat_stats(turn_offset)
		var projected_stats := after_expiry.duplicate()
		projected_stats[target] = after_expiry.get(target, Vector3i.ZERO) + delta
		var gain: int = bot._forecast_stat_combat_gain(target, after_expiry, projected_stats, turn_offset)
		# Use the best single opportunity. The fights can be alternatives, and
		# a next-combat buff is spent once the recipient fights.
		best = maxi(best, roundi(gain * pow(0.65, turn_offset)))
	return best

static func additive_combat_stats(bot, source: Card, target: Card) -> Vector3i:
	# These effects add stats without replacing a previous modifier or moving a card.
	if source == null or target == null:
		return Vector3i.ZERO
	if not (source is FifaTheMagicalArrow or source is Snowball or source is SapStrength \
			or source is VisionOfOdin or source is VisionOfTartarus or source is Hermes \
			or source is FairyBlast):
		return Vector3i.ZERO
	if not visible(bot, target) or target.current_zone == null or not target.current_zone.is_board_zone() \
			or target.negates_external_effects() or bot.game_manager.is_immune_to_source(target, source) \
			or bot.game_manager.is_guardian_protected(target, source):
		return Vector3i.ZERO
	var changes := stat_changes(bot, source, target)
	return Vector3i(int(changes.get("str", 0)), int(changes.get("res", 0)), int(changes.get("spd", 0)))

static func _projected_combat_score(bot, action: CardAction, stats: Dictionary) -> int:
	return bot._score_attack_economy(bot._estimate_projected_attack_economy(action, stats))

static func target_score(bot, card: Card, target: Card, action: CardAction = null) -> int:
	if target == null:
		return BAD
	var own: bool = target.get_controller() == bot.bot_player
	var enemy: bool = target.get_controller() == bot.opponent
	if enemy and counterstroke_can_answer(bot, target, card, action):
		return BAD
	if visible(bot, target) and (bot.game_manager.is_immune_to_source(target, card) or bot.game_manager.is_guardian_protected(target, card)):
		return BAD
	match key(card):
		"VisionOfOdin":
			if not visible(bot, target) or not ((own and target.culture == "Norse") or (enemy and target.culture != "Norse")):
				return BAD
			return stat_gain(bot, card, target, action)
		"Hermes":
			return stat_gain(bot, card, target, action) if visible(bot, target) else BAD
		"DivineLightning", "RunicSpellbreaker", "Lindwyrm":
			if own and action == null and can_remove_from_board(bot, card, target, true):
				return -value(bot, target)
			return removal_score(bot, card, target, action)
		"BitMeseri":
			if own and action == null:
				return -value(bot, target)
			return removal_score(bot, card, target, action, false)
		"ClayEaters":
			if target in card.pending_geophagia_targets:
				return BAD
			if own and can_remove_from_board(bot, card, target, true):
				return -value(bot, target)
			return int(removal_score(bot, card, target) * 0.7)
		"Alu":
			if not enemy or not visible(bot, target):
				return BAD
			if target.is_immune_to_sleep():
				return BAD
			var target_value := value(bot, target)
			return _disable_gain(bot, target, {"cannot_attack": target_value * 0.5, "cannot_intercept": target_value * 0.3})
		"Nimue":
			if own and target is EquipmentCard:
				for bearer in bot._get_board_creatures(bot.bot_player):
					if target.can_equip_to(bearer):
						@warning_ignore("integer_division")
						return value(bot, target) / 2
				return BAD
			if own and can_remove_from_board(bot, card, target, false):
				return -value(bot, target)
			return removal_score(bot, card, target, action, false) if enemy and visible(bot, target) else BAD
		"JiangZiyaFisherOfKings":
			if own and target.current_zone == bot.bot_player.deck_zone and bot.game_manager.can_player_add_to_hand_now(bot.bot_player):
				var mana: int = bot.bot_player.mana - bot.game_manager.get_creature_action_mana_cost(card, "activate")
				return bot._deck_pick_value(target, mana, bot._forecast_incoming_follower_loss()) \
					- _jiang_counterstroke_reserve_value(bot, card)
			return BAD
		"Dromi", "Gleipnir":
			if not enemy or not visible(bot, target):
				return BAD
			var target_value := value(bot, target)
			if card is Dromi:
				var attack_gain := _disable_gain(bot, target, {"cannot_attack": target_value * 0.75})
				return attack_gain + bot._score_follower_loss(bot.opponent, _dromi_drain_turns(bot, target) * Dromi.FOLLOWER_LOSS)
			var restrictions := {"cannot_attack": target_value * 0.5, "cannot_intercept": 2500}
			if not target.ability_text.is_empty():
				restrictions["activation_locked"] = target_value * 0.15
				restrictions[Card.ABILITY_NEGATED_STATUS] = target_value * 0.1
			return _disable_gain(bot, target, restrictions)
		"Snowball", "SapStrength", "VisionOfTartarus":
			if not enemy:
				return BAD
			return stat_gain(bot, card, target, action)
		"ObsidianReflection":
			if not enemy or not visible(bot, target):
				return BAD
			var reversed_damage := target.get_effective_strength()
			if bot.has_method("_get_direct_follower_damage"):
				reversed_damage = bot._get_direct_follower_damage(target)
			return maxi(1000, reversed_damage * 100)
		"FairyBlast":
			if not enemy or not visible(bot, target):
				return BAD
			if target.is_paralyzed():
				return BAD
			var fairy_score := stat_gain(bot, card, target, action)
			var fairy_value := value(bot, target)
			fairy_score += _disable_gain(bot, target, {"cannot_attack": fairy_value * 0.5, "cannot_intercept": fairy_value * 0.3, "cannot_move": fairy_value * 0.2})
			return fairy_score
		"FifaTheMagicalArrow", "BerserkerMead", "Lamashatu":
			if not own:
				return BAD
			if key(card) == "BerserkerMead" and target.has_status_effect("berserker_mead_guard"):
				return BAD
			if key(card) == "Lamashatu":
				for buff in target.active_buffs:
					if buff.get("source_card") == card and buff.get("effect_type") == "suckle":
						return BAD
			var score := stat_gain(bot, card, target, action)
			if key(card) == "BerserkerMead" and not target.is_immune_to_sleep():
				score -= 1500 # Sleeping through the next turn costs another action.
			return score
		"TabletOfLife", "Hringhorni":
			if bot._get_first_open_summon_zone(bot.bot_player) == null:
				return BAD
			var score := value(bot, target)
			var doomed_bodies: Array = []
			if key(card) == "TabletOfLife" and target.get_effective_level() >= 3:
				score = int(score * 0.45)
				# The resurrection is destroyed at this turn's end, so its only
				# window as sacrifice payment for a hand Demon is the same turn
				# the spell resolves.
				doomed_bodies = [target]
			var followup: int = bot._score_effect_summon_sacrifice_followup([target], activation_cost(bot, card), [], doomed_bodies)
			if followup <= BAD:
				# The cast would burn the sacrifice line that docks a hand
				# Demon here; hold the spell for a turn with its window open.
				return BAD
			return score + followup
		"BookOfLife":
			if bot._get_first_open_summon_zone(bot.bot_player) == null:
				return BAD
			# The body leaves the hand and loses its abilities. Value the saved
			# summon payment at the current marginal mana rate, rather than
			# counting it as an extra drawn card. Body value uses the same meta
			# reach/survival curves as value().
			var score: int = maxi(0, bot._get_play_cost(target, false)) * marginal_mana_value(bot) \
				+ _strength_reach_points(target.get_effective_strength()) \
				+ _resilience_survival_points(target.get_effective_resilience())
			if key(target) in ["EnkiLordOfEridu", "Askelladen", "Gawain", "Lindwyrm", "Lamashatu", "Mummu"]:
				score -= 4000
			if target.has_type("Mage") or target.has_type("Priest"):
				score -= 1000
			score += bot._score_effect_summon_sacrifice_followup([target], activation_cost(bot, card))
			return score
		"SirensSong":
			var steal: int = combat_gain_for_stolen_creature(bot, target) if enemy else BAD
			if steal > BAD:
				# A steal is normally a one-turn borrow of the body. With
				# Mummu leading, Entropic Force can end the control early by
				# shelving the borrowed card into its owner's deck, so the
				# denial outlasts the borrow: see _mummu_temporary_control_bonus.
				steal += bot._mummu_temporary_control_bonus(target)
			return steal
		"Absence":
			if not enemy or not visible(bot, target):
				return BAD
			var mute_value := 0
			if target.is_god:
				mute_value = value(bot, target)
			else:
				mute_value = 4500 + target.mana_cost * 800
				# Prioritize powers that are about to pay off over stored-but-
				# dormant ones: planned powers fire at a payoff moment the mute
				# delays, and a target the enemy can already pay for is an
				# imminent activation instead of a paper threat.
				if key(target) in PLANNED_POWERS:
					mute_value += 1500
				if bot.opponent != null and bot.opponent.mana >= activation_cost(bot, target):
					mute_value += 1000
			return mute_gain(bot, target, Absence.MUTE_DURATION, mute_value)
		"Exorcism":
			if not own:
				return BAD
			var score := 0
			for effect in bot.game_manager.get_field_cards(bot.opponent):
				if effect is PermanentHexCard and effect.attached_target == target:
					score += value(bot, effect) + 3000
			if action != null and action.card != null and action.card.get_controller() == bot.opponent and bot._target_includes_card(action.target, target):
				score += value(bot, action.card)
			for buff in target.active_buffs:
				if buff.get("source_card") != target:
					score -= int(buff.get("str", 0)) * 100 + int(buff.get("res", 0)) * 50 + int(buff.get("spd", 0)) * 200
			return score
		"AncientPyre":
			if target.is_god or not card.is_frontline():
				return BAD
			if visible(bot, target) and target.get_effective_resilience() <= AncientPyre.EFFECT_AMOUNT:
				if own and can_remove_from_board(bot, card, target, true):
					return -value(bot, target)
				return removal_score(bot, card, target)
			return combat_gain(bot, target, 0, -AncientPyre.EFFECT_AMOUNT, action, 0, 2) if enemy and not target.negates_external_effects() else BAD
		"Watchtower":
			return 1500 if enemy and not visible(bot, target) else BAD
		"Gawain":
			var score := 0
			for status in card.get_removable_statuses(target):
				score = maxi(score, healing_score(bot, target, status))
			return score if own else BAD
		"GududPriest":
			# Creature Ward removes only creature-applied effects, so value is
			# limited to those sources on either side of the board.
			if target == null or target.card_type != Card.CardType.CREATURE or not visible(bot, target) \
					or target.current_zone == null or not target.current_zone.is_board_zone():
				return BAD
			var ward_gain := 0
			for status in target._get_effective_statuses():
				var status_source := status.get("source_card") as Card
				if status_source == null or status_source.card_type != Card.CardType.CREATURE:
					continue
				ward_gain += maxi(0, healing_score(bot, target, status))
			for buff in target._get_effective_buffs():
				var buff_source := buff.get("source_card") as Card
				if buff_source == null or buff_source.card_type != Card.CardType.CREATURE:
					continue
				var buff_str := maxi(0, int(buff.get("str", 0)))
				var buff_res := maxi(0, int(buff.get("res", 0)))
				var buff_spd := maxi(0, int(buff.get("spd", 0)))
				if target.get_controller() == bot.opponent:
					ward_gain += buff_str * 100 + buff_res * 55 + buff_spd * 250
				else:
					ward_gain += maxi(0, -int(buff.get("str", 0))) * 100 \
						+ maxi(0, -int(buff.get("res", 0))) * 55 \
						+ maxi(0, -int(buff.get("spd", 0))) * 250
			return ward_gain if ward_gain >= 500 else BAD
		"HariiShaman":
			return _harii_shaman_transform_gain(bot, card, target)
		"Isimud":
			if target == null or target == card or not target.has_type("Divine Manifestation") \
					or target.current_zone != bot.bot_player.hand_zone:
				return BAD
			var revelation_zone: Zone = bot._get_first_open_summon_zone(bot.bot_player)
			if revelation_zone == null:
				return BAD
			var revelation_cost: int = bot.game_manager.get_creature_summon_mana_cost(bot.bot_player, target, card, false) \
				+ Isimud.REVELATION_SUMMON_TAX
			if revelation_cost > bot.bot_player.mana:
				return BAD
			var revelation_score: int = bot._score_projected_card(target) \
				+ bot._estimate_summon_attack_value(target, revelation_zone, bot.bot_player.mana - revelation_cost) * 3 / 4
			revelation_score -= mana_penalty(bot, revelation_cost)
			return revelation_score if revelation_score > 0 else BAD
		"SeventhSageUtuabzu":
			# Imbue Ally replays the target Sage's impact at the listed cost.
			if target == null or target == card or not visible(bot, target):
				return BAD
			return seventh_sage_channel_gain(bot, target)
		"OraclesSight":
			return bot._get_hand_value(target) * 60 + (2000 if target is CreatureCard and bot._get_best_affordable_hand_creature(0) == null else 0)
	return BAD

static func combat_gain_for_stolen_creature(bot, target: Card) -> int:
	if not visible(bot, target) or target.is_sleeping or not target.can_take_major_creature_action():
		return 0
	# Temporary control is valuable for its immediate attack and for denying
	# interception. It is not permanent removal or a newly acquired card, and
	# the borrowed body's death costs its owner, so every legal attack line is
	# priced with the same combat estimator the bot uses for its own attacks.
	var score := 0
	for defender in bot._get_board_creatures(bot.opponent):
		if defender == target or not visible(bot, defender):
			continue
		if not bot._can_attack_creature(target, defender):
			continue
		var action := CardAction.new()
		action.type = CardAction.Type.ATTACK
		action.attacker = target
		action.target = defender
		var economy: Dictionary = bot._estimate_attack_economy(action, null, 0, 0, 0, false)
		var line_score: int = bot._score_attack_economy(economy)
		# Until control actually moves, the estimator charges attack recoil to
		# the current controller. After the steal the bot pays those followers,
		# and a recoil that reaches the bot's pool can even lose the game. The
		# defender-side overflow (the stolen body winning the fight) is already
		# charged to the opponent and stays there, so only correct lines where
		# the defender survived.
		var recoil: int = int(economy.get("opponent_followers_lost", 0))
		if recoil > 0 and not (defender in economy.get("casualties", [])):
			line_score += -bot._score_follower_loss(bot.opponent, recoil) \
				+ bot._score_follower_loss(bot.bot_player, recoil)
			if bool(economy.get("bot_wins", false)):
				line_score -= CARD_VALUE * 20
				if recoil >= bot.bot_player.followers:
					line_score -= CARD_VALUE * 20
		score = maxi(score, line_score)
	if bot._board_creature_count(bot.opponent) == 1:
		score = maxi(score, bot._score_follower_loss(bot.opponent, target.get_effective_strength()))
	return score

static func wipe_cards(bot, card: Card) -> Array:
	var result: Array = []
	var id := key(card)
	for target in bot.game_manager.get_field_cards():
		# Conditional wipes must not inspect the identities of hidden enemies.
		if not visible(bot, target):
			if id == "TheInferno" and target.current_zone in bot.opponent.frontline_zones:
				result.append(target)
			continue
		var doomed := false
		match id:
			"TheInferno": doomed = target.current_zone in bot.opponent.frontline_zones
			"TheDeluge": doomed = target.current_zone != null and target.current_zone.is_board_zone() and target.is_physical_card()
			"Earthquake": doomed = card._is_doomed_card(target)
			"OccultSingularity": doomed = card._is_doomed_card(target, bot.game_manager)
			"FiresOfJudgment": doomed = card._is_doomed_card(target, bot.opponent)
			"Famine": doomed = card._should_destroy(target)
			"BaneOfTheSvartalfar": doomed = card._should_petrify(target)
		if doomed:
			result.append(target)
	if id == "FalloftheMighty":
		# Face-down cards are always prepared spells, hexes, or charms, and
		# stealthed creatures are excluded from the strength check, so no hidden
		# card can change which creatures the strength check dooms.
		return card.get_strongest_creatures(bot.game_manager)
	return result

static func effect_score(bot, card: Card, target: Card = null, action: CardAction = null) -> int:
	var gain := BAD
	var id := key(card)
	if target != null:
		gain = target_score(bot, card, target, action)
	match id:
		"SavingGrace":
			if not combat_visible(bot, action):
				return BAD
			var result: Dictionary = bot._estimate_attack_economy(action, null, 0, 0)
			var cost: int = card.get_unlock_mana_cost(bot.game_manager)
			if action.get_timing_speed() > SavingGrace.BASE_RESPONSE_SPEED:
				cost += SavingGrace.FAST_RESPONSE_EXTRA_COST
			return bot._score_follower_loss(bot.bot_player, int(result["bot_followers_lost"])) - mana_penalty(bot, cost)
		"JiangZiyaFisherOfKings":
			if action == null:
				return BAD
			if action.type == CardAction.Type.ATTACK:
				return maxi(1800, removal_score(bot, card, action.attacker, action))
			return maxi(1800, removal_score(bot, card, action.card, action))
		"Drought", "HeavySnow", "Storm":
			if action != null:
				return BAD
			gain = weather_score(bot, card)
		"ShroudOfTheAncients":
			gain = shroud_gain(bot, card, action)
		"WildMagic":
			gain = wild_magic_gain(bot, card)
		"Banishment", "SpellDemolition":
			if action != null and action.card != null and action.card.get_controller() == bot.opponent:
				gain = value(bot, action.card)
				if action.target is Card and action.target.get_controller() == bot.bot_player:
					gain += value(bot, action.target)
				elif action.card.has_method("would_destroy_creature_of_player") and action.card.would_destroy_creature_of_player(bot.game_manager, bot.bot_player, action.target):
					for creature in bot._get_board_creatures(bot.bot_player):
						@warning_ignore("integer_division")
						gain += value(bot, creature) / 2
		"Smite", "VoidShield":
			gain = removal_score(bot, card, action.attacker, action, id != "VoidShield") if action != null else BAD
		"Sap", "SepLemutti":
			gain = removal_score(bot, card, action.card, null, id == "Sap") if action != null else BAD
		"GungnirTheSpearOfOdin":
			gain = removal_score(bot, card, bot._get_attack_defender_card(action), action) if action != null else BAD
		"NamburbiApotropaeon":
			gain = 0
			if action != null and action.type == CardAction.Type.ATTACK and combat_visible(bot, action):
				var economy: Dictionary = bot._estimate_attack_economy(action, null, 0, 0)
				gain += bot._score_follower_loss(bot.bot_player, int(economy.get("bot_followers_lost", 0)))
			elif action != null and action.card != null and action.card.has_method("would_destroy_creature_of_player"):
				if action.card.would_destroy_creature_of_player(bot.game_manager, bot.bot_player, action.target):
					for creature in bot._get_board_creatures(bot.bot_player):
						@warning_ignore("integer_division")
						gain += value(bot, creature) / 2
		"HeroicStand": gain = mana_gain_value(bot, 7)
		"TheInferno", "TheDeluge", "Earthquake", "FiresOfJudgment", "Famine", "OccultSingularity", "FalloftheMighty", "BaneOfTheSvartalfar":
			gain = 0
			var removed: Array = []
			for doomed in removal_targets(bot, card, target, action):
				var amount := value(bot, doomed)
				if id == "BaneOfTheSvartalfar":
					amount = _disable_gain(bot, doomed, {
						"cannot_attack": amount * 0.3, "cannot_intercept": amount * 0.15, "cannot_move": amount * 0.1,
						"activation_locked": amount * 0.09, Card.ABILITY_NEGATED_STATUS: amount * 0.06,
					})
				elif doomed.get_controller() == bot.opponent:
					amount -= _debilitation_discount(bot, doomed) + _own_dromi_drain_loss(bot, doomed)
					if id == "FalloftheMighty" and amount > 0 and _bot_can_safely_contain(bot, doomed):
						amount = int(round(float(amount) * 0.35))
				else:
					amount -= _debilitation_discount(bot, doomed)
				gain += amount if doomed.get_controller() == bot.opponent else -amount
				removed.append(doomed)
			if action != null and action.type == CardAction.Type.ATTACK and combat_visible(bot, action) and (action.attacker in removed or bot._get_attack_defender_card(action) in removed):
				gain -= bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
		"BookOfLife": gain = maxi(0, gain) + follower_gain(bot.bot_player, 10)
		"FoolishOptimism":
			var choice := forced_combat_choice(bot, card, card.get_lowest_level_attacker_choices(bot.game_manager), card.get_highest_level_defender_choices(bot.game_manager))
			gain = int(choice.get("score", BAD))
		"CircleofRebirth":
			gain = 0
			var spaces := {bot.bot_player: open_spaces(bot.bot_player), bot.opponent: open_spaces(bot.opponent)}
			var friendly_summons: Array[Card] = []
			for dead in bot.game_manager.died_this_turn:
				if dead.current_zone not in [dead.card_owner.graveyard_zone, dead.card_owner.abyss_zone] or not (dead.has_type("Animal") or dead.has_type("Plant")) or spaces.get(dead.card_owner, 0) <= 0:
					continue
				spaces[dead.card_owner] -= 1
				gain += value(bot, dead) if dead.card_owner == bot.bot_player else -value(bot, dead)
				if dead.card_owner == bot.bot_player:
					friendly_summons.append(dead)
			gain += bot._score_effect_summon_sacrifice_followup(friendly_summons, activation_cost(bot, card))
		"LightOfMorningsDoors":
			gain = card._get_hidden_opponent_cards(bot.game_manager).size() * 1500
	if gain <= BAD:
		return BAD
	if id == "Hermes":
		return gain - mana_penalty(bot, Hermes.ACTIVATION_COST)
	return gain - CARD_VALUE - mana_penalty(bot, activation_cost(bot, card))

static func shroud_gain(bot, source: Card, action: CardAction = null) -> int:
	var gain := 0
	if action != null and action.type == CardAction.Type.ATTACK and combat_visible(bot, action):
		var attackers_stopped := true
		for attacker in [action.attacker, action.united_front_partner]:
			if attacker != null and attacker.creature_mode == Card.CreatureMode.AGGRESSIVE \
					and (not source._is_valid_creature(attacker) or bot.game_manager.is_immune_to_source(attacker, source)):
				attackers_stopped = false
		var defender: Card = bot._get_attack_defender_card(action)
		var before: Dictionary = bot._estimate_attack_economy(action, null, 0, 0)
		if attackers_stopped:
			gain -= bot._score_attack_economy(before)
		elif defender != null and source._is_valid_creature(defender) and not bot.game_manager.is_immune_to_source(defender, source):
			var after: Dictionary = bot._estimate_attack_economy(action, null, 0, 0, 0, true, Card.CreatureMode.DEFENSIVE, true)
			gain += bot._score_attack_economy(after) - bot._score_attack_economy(before)
	for creature: Card in bot.game_manager.get_field_cards(null, false):
		if not visible(bot, creature) or not source._is_valid_creature(creature) or creature.is_stealth \
				or bot.game_manager.is_immune_to_source(creature, source):
			continue
		var own: bool = creature.get_controller() == bot.bot_player
		if creature.creature_mode == Card.CreatureMode.AGGRESSIVE:
			gain += 1200 if own and creature.current_zone in bot.bot_player.reserve_zones else 0
		# A concealed creature loses access to its face-up abilities until revealed.
		if not creature.ability_text.is_empty() and not creature.abilities_suppressed():
			gain += -1800 if own else 1800
	return gain

# True when the bot already has a body that can contain the enemy creature: it
# can legally intercept the enemy's attacks (engine intercept gate) and would
# survive the resulting combat, either through a self-replacement zone (Stone
# Skin's "Cannot be Slain", "Cannot be destroyed in combat") or by simply
# out-resilience-ing the enemy's strength. Such a body holds off aggression by
# itself, so removing the enemy with a card is not an urgent need.
static func _bot_can_safely_contain(bot, enemy: Card) -> bool:
	if bot == null or enemy == null or enemy.card_type != Card.CardType.CREATURE:
		return false
	var game: GameManager = bot.game_manager
	if game == null:
		return false
	for ally in bot._get_board_creatures(bot.bot_player):
		if ally == null or ally.card_type != Card.CardType.CREATURE:
			continue
		if ally.is_face_down or ally.is_stealth:
			continue
		if not game._can_intercept_followers(ally, enemy):
			continue
		if not enemy.can_destroy_combat_protected_creatures(ally):
			var replacement: Zone = null
			if ally is BaseCard:
				replacement = ally.get_self_graveyard_replacement_zone(game, true, true, false)
			if replacement != null and ally.current_zone != null and replacement == ally.current_zone:
				return true
		if ally.get_effective_resilience() >= enemy.get_effective_strength():
			return true
	return false

static func wild_magic_gain(bot, spell: Card) -> int:
	if not spell.is_prepared and open_spaces(bot.bot_player) == 0:
		return BAD
	var deck: Zone = bot.bot_player.deck_zone
	var first_known_magic: Card
	var unknown_slots_before_known_magic := 0
	for index in deck.get_card_count():
		var card := deck.get_known_deck_card(index)
		if card == null:
			unknown_slots_before_known_magic += 1
		elif card.is_magical_card():
			first_known_magic = card
			break
	var unknown_count := 0
	var samples := 0
	var total := 0
	for card in deck.get_unordered_deck_cards():
		if deck.get_deck_placement(card) != Zone.DeckPlacement.UNKNOWN:
			continue
		unknown_count += 1
		if not card.is_magical_card():
			continue
		samples += 1
		total += _wild_magic_card_gain(bot, card)
	if first_known_magic == null:
		@warning_ignore("integer_division")
		return total / samples if samples > 0 else BAD
	var known_chance: float = bot._sample_avoids(unknown_count, samples, unknown_slots_before_known_magic)
	var unknown_gain := float(total) / samples if samples > 0 else 0.0
	return roundi(known_chance * _wild_magic_card_gain(bot, first_known_magic) + (1.0 - known_chance) * unknown_gain)

static func _wild_magic_card_gain(bot, card: Card) -> int:
	if card is WildMagic or not supports_ranked_deck_card(card):
		return 0
	@warning_ignore("integer_division")
	var gain: int = CARD_VALUE + bot._get_hand_value(card) * 30 - activation_cost(bot, card) * 400 * marginal_mana_value(bot) / 1000
	if card is SpellCard and bot.game_manager.spells_must_be_prepared():
		gain += MANA_VALUE
	return gain

static func weather_score(bot, weather: Card) -> int:
	var id := key(weather)
	var gain := 0
	for field_card in bot.game_manager.get_field_cards():
		if not visible(bot, field_card) or field_card.is_face_down:
			continue
		var side := 1 if field_card.get_controller() == bot.opponent else -1
		if key(field_card) == id:
			return BAD
		if field_card is SpellCard and field_card.has_type("Weather"):
			gain += side * CARD_VALUE
		if field_card.card_type != Card.CardType.CREATURE:
			continue
		match id:
			"HeavySnow":
				if weather._is_weather_locked_creature(field_card) and not weather._weather_effect_is_blocked(field_card):
					var target_value := value(bot, field_card)
					gain += side * _disable_gain(bot, field_card, {
						"cannot_attack": target_value * 0.35, "cannot_intercept": target_value * 0.25, "cannot_move": target_value * 0.15,
					})
			"Storm":
				if weather._weather_effect_is_blocked(field_card):
					continue
				if field_card.has_type("Aerial"):
					gain += side * 3000
				if weather._has_non_passive_creature_ability(field_card):
					gain += side * _disable_gain(bot, field_card, {"activation_locked": 1380, Card.ABILITY_NEGATED_STATUS: 920})
	if id == "Drought":
		# The extra preparation step is costly if our hand depends on spells.
		gain -= bot.bot_player.hand_zone.cards.filter(func(card: Card) -> bool: return card is SpellCard and card != weather).size() * 1700
		if open_spaces(bot.opponent) <= 2 and open_spaces(bot.bot_player) >= 3:
			gain += 6000
	return gain

# A face-up Storm silences every non-passive creature ability the moment the
# card enters the field (Storm.on_any_card_moved refreshes the field during
# the summon's move, before the impact resolves), so impact payoffs such as
# Fenrir's Devour can never fire while one is live. Returns true when an
# active, visible Storm that survives the planned removals would silence the
# arriving creature. Creatures already on the field are excluded: their live
# silence state is known and checked at the call site.
static func summon_impact_silenced_by_storm(bot, creature: Card, removed: Array = []) -> bool:
	if creature == null or bot == null or bot.game_manager == null:
		return false
	if creature.current_zone != null and creature.current_zone.is_board_zone():
		return false
	for field_card in bot.game_manager.get_field_cards():
		var storm := field_card as Storm
		if storm == null or storm in removed or not visible(bot, storm) \
				or storm.current_zone == null or not storm.current_zone.is_board_zone() \
				or storm.is_face_down or storm.abilities_suppressed():
			continue
		if storm._weather_effect_is_blocked(creature):
			continue
		if storm._has_non_passive_creature_ability(creature):
			return true
	return false

static func wake_gain(bot, source: Card, norse_only: bool = false) -> int:
	var gain := 0
	for player in [bot.bot_player, bot.opponent]:
		if player == bot.opponent and not norse_only:
			continue
		for creature in bot._get_board_creatures(player):
			if not visible(bot, creature) or not creature.is_sleeping or (norse_only and creature.culture != "Norse"):
				continue
			if bot.game_manager.is_immune_to_source(creature, source):
				continue
			@warning_ignore("integer_division")
			gain += (1 if player == bot.bot_player else -1) * value(bot, creature) / 2
	return gain

static func _active_hunting_tactics(bot) -> HuntingTactics:
	for power in bot._get_player_powers():
		var tactics := power as HuntingTactics
		if tactics != null and tactics.is_effectively_active() and not tactics.abilities_suppressed():
			return tactics
	return null

static func _is_hunting_tactics_attacker(card: Card) -> bool:
	return card != null and card.card_type == Card.CardType.CREATURE \
		and (card.has_type("Lupine") or (card.has_type("Human") and card.has_type("Warrior") and card.culture == "Norse"))

# Transform only pays when it flips a real synergy: restoring an Animal into a
# Norse Human Warrior under Thor's patron buff or Hunting Tactics eligibility,
# or turning an unused Norse Warrior into a Lupine supporter for an eligible
# attacker that currently has no support choices.
static func _harii_shaman_transform_gain(bot, _source: Card, target: Card) -> int:
	if target == null or not visible(bot, target) or target.get_controller() != bot.bot_player \
			or target.current_zone == null or not target.current_zone.is_board_zone():
		return BAD
	var tactics: HuntingTactics = _active_hunting_tactics(bot)
	if target.has_type("Animal"):
		var gain := 0
		if bot._find_player_god() is Thor and not target.has_type("Warrior"):
			gain += 900
		if tactics != null and not _is_hunting_tactics_attacker(target) \
				and target.culture == "Norse" and target.current_zone in bot.bot_player.frontline_zones:
			gain += 1300
		return gain if gain >= 900 else BAD
	if tactics != null and target.has_type("Warrior") and target.culture == "Norse" and not target.has_type("Animal"):
		for attacker in bot._get_board_creatures(bot.bot_player):
			if attacker == target or attacker.current_zone == null \
					or attacker.current_zone not in bot.bot_player.frontline_zones \
					or attacker.is_sleeping or attacker.has_status_effect("cannot_attack"):
				continue
			if _is_hunting_tactics_attacker(attacker) and tactics.get_support_choices(attacker).is_empty():
				return 1400
	return BAD

static func equipment_score(bot, equipment: Card, bearer: Card) -> int:
	if not equipment.can_equip_to(bearer) or bearer.is_sleeping:
		return BAD
	if key(equipment) == "DraupnirTheMultiplying":
		# Three end-turn payments are more likely on a protected reserve bearer.
		return (6500 if bearer.current_zone in bot.bot_player.reserve_zones else 5500) - CARD_VALUE
	if equipment is Gambanteinn:
		for enemy in bot._get_board_creatures(bot.opponent):
			if visible(bot, enemy) and not enemy.is_sleeping \
					and (bearer.has_type("Mage") or enemy.creature_mode == Card.CreatureMode.DEFENSIVE):
				return 2300 if bearer.has_type("Mage") else 1600
		return 0
	if key(equipment) not in EQUIPMENT:
		return BAD
	var gain := stat_gain(bot, equipment, bearer)
	if equipment is SharurTheFlyingMace:
		# The mace is nearly lossless: destroy/steal answers only cost its
		# owner 4 mana, and a dead bearer leaves it on the field ready to
		# re-equip, so charge half a card instead of a full card loss. Its +9
		# Str is the largest equipment swing in the catalog and stays on the
		# bearer permanently, so keep a positive floor once a legal bearer
		# exists instead of waiting for a forecastable combat flip.
		@warning_ignore("integer_division")
		var sharur_base := maxi(gain + 2000 - CARD_VALUE / 2, 600)
		return sharur_base - mana_penalty(bot, activation_cost(bot, equipment))
	if key(equipment) == "BeardedAxe" and bearer.culture == "Norse" and bearer.has_type("Warrior"):
		# Score the conditional axe bonus only against defensive creatures.
		for defender in bot._get_board_creatures(bot.opponent):
			if not visible(bot, defender) or defender.creature_mode != Card.CreatureMode.DEFENSIVE or bearer not in bot._get_attack_ready_creatures() or not bot._can_attack_creature(bearer, defender):
				continue
			var action := CardAction.new()
			action.type = CardAction.Type.ATTACK
			action.attacker = bearer
			action.target = defender
			gain = maxi(gain, combat_gain(bot, bearer, equipment.strength_modifier + 8, 0, action))
	return gain + 2000 - CARD_VALUE - mana_penalty(bot, activation_cost(bot, equipment))

static func equipment_pickup_score(bot, equipment: EquipmentCard, bearer: Card) -> int:
	if equipment == null or bearer == null or not equipment.can_equip_to(bearer):
		return BAD
	if key(equipment) == "DraupnirTheMultiplying":
		var remaining := maxi(0, DraupnirTheMultiplying.MAX_ACTIVATIONS - equipment.activations_used)
		var safety_bonus := 500 if bearer.current_zone in bot.bot_player.reserve_zones else 0
		# Future payments arrive while the current stock is being spent, so
		# price the total gain from today's level rather than today's rate.
		return mana_gain_value(bot, remaining * DraupnirTheMultiplying.MANA_GAIN) + safety_bonus
	# The item is already on the board, so its original card cost is sunk. Give
	# even low-impact gear a baseline value over passing, then account for its
	# stat changes and any special combat benefit.
	var gain := stat_gain(bot, equipment, bearer)
	if equipment is SharurTheFlyingMace:
		# Re-equipping re-arms the catalog's largest strength swing and keeps
		# the legendary out of enemy steal reach, so value the pickup above the
		# generic unequipped-gear baseline.
		return 3200 + gain
	if key(equipment) == "BeardedAxe" and bearer.culture == "Norse" and bearer.has_type("Warrior"):
		for defender in bot._get_board_creatures(bot.opponent):
			if not visible(bot, defender) or defender.creature_mode != Card.CreatureMode.DEFENSIVE or bearer not in bot._get_attack_ready_creatures() or not bot._can_attack_creature(bearer, defender):
				continue
			var action := CardAction.new()
			action.type = CardAction.Type.ATTACK
			action.attacker = bearer
			action.target = defender
			gain = maxi(gain, combat_gain(bot, bearer, equipment.strength_modifier + 8, 0, action))
	return 2500 + gain

static func structure_score(bot, structure: Card, excluded: Array = []) -> int:
	var gain := 0
	match key(structure):
		"AncientPyre":
			gain = 6500 if bot.opponent.followers < 50 or bot.bot_player.followers < 50 else 0
			# In a locked board state the Pyre is the win condition: its
			# conversion clock turns surplus mana into direct follower swing.
			# The sooner it ends the game, the more the structure is worth.
			if bot.has_method("_locked_board_state") and bot._locked_board_state() \
					and bot.opponent.followers > 0:
				var clock_turns := ceili(float(bot.opponent.followers) / float(AncientPyre.USES_PER_TURN * AncientPyre.EFFECT_AMOUNT))
				if clock_turns > 0:
					@warning_ignore("integer_division")
					gain = maxi(gain, CARD_VALUE + CARD_VALUE * 2 / clock_turns)
		"Watchtower":
			# Counters arrive from future enemy entries, not existing cards.
			gain = 6000 if bot._board_creature_count(bot.opponent) < 3 else 3000
			# Scout reveals pay off when the enemy actually hides bodies: each
			# face-down or stealthed opposing creature is a threat the tower
			# can flip for a counter, worth far more against stealth engines
			# than against boards that play face-up.
			var hidden_enemies := 0
			for enemy in bot._get_board_creatures(bot.opponent):
				if enemy.is_face_down or enemy.is_stealth:
					hidden_enemies += 1
			gain += mini(hidden_enemies, 3) * 1500
			if hidden_enemies == 0 and bot._board_creature_count(bot.opponent) >= 3:
				gain = 3000
		"DoorwayToTheVoid":
			for dead in bot.opponent.graveyard_zone.cards:
				if dead is CreatureCard:
					gain += 600
			for enemy in bot._get_board_creatures(bot.opponent):
				if visible(bot, enemy) and (enemy is AgainWalker or enemy is Huginn or enemy is Muninn):
					gain += 3500
			for god in bot.opponent.god_zone.cards:
				if visible(bot, god) and god is Freyja:
					gain += 4500
		"WardingStone":
			if bot.game_manager.attack_restrictions.has(bot.opponent):
				return BAD
			for creature in bot._get_board_creatures(bot.opponent):
				if visible(bot, creature) and not creature.is_sleeping and not creature.has_status_effect("cannot_attack"):
					@warning_ignore("integer_division")
					gain += value(bot, creature) / 2
			gain += 2500 if bot.bot_player.followers < 50 else 0
		"E2Abzu":
			var mer_mage_count := 0
			var candidate_zones: Array = [bot.bot_player.hand_zone, bot.bot_player.deck_zone, bot.bot_player.graveyard_zone, bot.bot_player.abyss_zone]
			candidate_zones.append_array(bot.bot_player.frontline_zones)
			candidate_zones.append_array(bot.bot_player.reserve_zones)
			for zone: Zone in candidate_zones:
				for candidate: Card in zone.cards:
					if candidate.card_type == Card.CardType.CREATURE and candidate.has_type("Mer") and candidate.has_type("Mage"):
						mer_mage_count += 1
			if mer_mage_count == 0:
				return BAD
			gain = 6500 + mini(3, mer_mage_count - 1) * 1000
		"AnointingStatue":
			gain = CARD_VALUE + 500 * bot._board_creature_count(bot.bot_player)
			for target in bot.game_manager.get_field_cards(null, false):
				gain = maxi(gain, CARD_VALUE + cleanse_score(bot, structure, target))
		"EriduCityOfSages":
			for creature in bot._get_board_creatures(bot.bot_player):
				if creature.has_type("Mage"):
					# One mana dose per turn for three turns, priced from the
					# current stock so a saturated position values it less.
					gain += mana_gain_value(bot, EriduCityOfSages.MANA_PER_MAGE * 3)
		"GlitnirThePeaceful":
			if bot.game_manager._any_active_structure_forces_defensive_summon():
				return BAD
			# An established frontline can keep attacking while new enemies must change stance.
			var friend_count := 0
			var enemy_count := 0
			for creature in bot._get_board_creatures(bot.bot_player):
				if creature.current_zone in bot.bot_player.frontline_zones and creature.creature_mode == Card.CreatureMode.AGGRESSIVE:
					friend_count += 1
			for creature in bot._get_board_creatures(bot.opponent):
				if visible(bot, creature) and creature.current_zone in bot.opponent.frontline_zones and creature.creature_mode == Card.CreatureMode.AGGRESSIVE:
					enemy_count += 1
			if friend_count > enemy_count and not bot.opponent.hand_zone.cards.is_empty():
				gain = 5500 + mini(3, friend_count - enemy_count) * 1800
		"SleepOfTheDuat":
			# The chain value nets the board-wide sleep against both sides
			# and adds the Altar of Dreams summon line the sleepers fuel,
			# including the upkeep mana and spare discard that still arrive
			# over the line's turns.
			var duat_chain := duat_chain_value(bot, excluded)
			if duat_chain <= BAD:
				return BAD
			gain = duat_chain
		"HildskjalfThroneOfOdin":
			if bot.bot_player.deck_zone.cards.size() > 2 or bot.opponent.deck_zone.cards.size() > 2:
				gain = 8600 if bot._find_player_god() is Odin else 6800
		_: return BAD
	return gain - CARD_VALUE - mana_penalty(bot, activation_cost(bot, structure))

static func preparation_score(bot, card: Card) -> int:
	var id := key(card)
	if card is ShroudOfTheAncients:
		@warning_ignore("integer_division")
		var score := maxi(0, shroud_gain(bot, card) / 2)
		for enemy in bot._get_board_creatures(bot.opponent):
			if visible(bot, enemy) and enemy.current_zone in bot.opponent.frontline_zones \
					and enemy.creature_mode == Card.CreatureMode.AGGRESSIVE and not enemy.is_sleeping \
					and not bot.game_manager.is_immune_to_source(enemy, card):
				score = maxi(score, 1400)
		return score
	if id in ["Banishment", "SpellDemolition", "Sap", "SepLemutti", "Smite", "VoidShield", "NamburbiApotropaeon", "Exorcism", "Hringhorni", "HeroicStand"]:
		return 1700 if bot._board_creature_count(bot.opponent) > 0 or bot._board_creature_count(bot.bot_player) > 0 else 0
	if id in ["TheInferno", "TheDeluge", "Dromi", "Gleipnir"]:
		var gain := 0
		if id in ["TheInferno", "TheDeluge"]:
			for target in wipe_cards(bot, card):
				gain += value(bot, target) if target.get_controller() == bot.opponent else -value(bot, target)
		else:
			for target in bot._get_board_creatures(bot.opponent):
				gain = maxi(gain, target_score(bot, card, target))
		return gain - CARD_VALUE - mana_penalty(bot, activation_cost(bot, card))
	if id in ["FifaTheMagicalArrow", "GungnirTheSpearOfOdin", "SapStrength", "VisionOfTartarus"]:
		return 1500 if bot._board_creature_count(bot.bot_player) > 0 and bot._board_creature_count(bot.opponent) > 0 else 0
	return 0

static func guard_mana(bot, available_mana: int = -1) -> int:
	var budget: int = bot.bot_player.mana if available_mana < 0 else available_mana
	var danger := 0
	for creature in bot._get_board_creatures(bot.opponent):
		if visible(bot, creature) and creature.current_zone in bot.opponent.frontline_zones and not creature.is_sleeping and not creature.has_status_effect("cannot_attack"):
			danger += maxi(0, creature.get_effective_strength())
	var needed := maxi(0, danger - bot.bot_player.guard)
	return mini(budget, int(ceil(float(needed) / ManaGuard.GUARD_PER_MANA)))

# A compelled fight still leaves the opponent a response window, and a prepared
# combat trick can pump the forced attacker (Fifa's +5 STR is the smallest
# common swing; Vision of Odin reaches +7). When the opponent has face-down
# reserve cards — the slot prepared tricks occupy — also score the fight with
# the compelled attacker pumped, so an exchange the raw stats only narrowly win
# cannot pay for the cast once the opponent answers.
const OPPONENT_TRICK_STR_BUMP := 5

static func forced_combat_choice(bot, source: Card, attackers: Array, defenders: Array) -> Dictionary:
	var best := {"score": BAD, "attacker_uid": "", "defender_uid": ""}
	var trick_bump := _opponent_trick_str_bump(bot)
	for attacker in attackers:
		for defender in defenders:
			if not source._can_force_attack(bot.game_manager, attacker, defender):
				continue
			# United Front needs a separate combined-strength model.
			if attacker.has_method("get_united_front_partner_for_attack") and attacker.get_united_front_partner_for_attack(bot.game_manager) != null:
				continue
			var action := CardAction.new()
			action.type = CardAction.Type.ATTACK
			action.attacker = attacker
			action.target = defender
			var score: int = bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
			if trick_bump > 0 and not attacker.negates_external_effects():
				var punished: int = bot._score_attack_economy(bot._estimate_attack_economy(action, attacker, trick_bump, 0))
				score = mini(score, punished)
			if score > int(best["score"]):
				best = {"score": score, "attacker_uid": attacker.uid, "defender_uid": defender.uid}
	return best

static func _opponent_trick_str_bump(bot) -> int:
	if bot == null or bot.opponent == null:
		return 0
	for zone in bot.opponent.reserve_zones:
		for card in zone.cards:
			if card != null and (card.is_face_down or card.is_prepared):
				return OPPONENT_TRICK_STR_BUMP
	return 0

static func healing_score(bot, target: Card, status: Dictionary) -> int:
	var name := str(status.get("name", ""))
	if name in ["sleep", "cannot_attack", "cannot_intercept", "petrified", "abilities_negated", "muted"]:
		return int(value(bot, target) * 0.6)
	return 0

static func cleanse_score(bot, source: Card, target: Card) -> int:
	if not visible(bot, target) or target.card_type not in [Card.CardType.CREATURE, Card.CardType.STRUCTURE] \
			or bot.game_manager.is_immune_to_source(target, source) or bot.game_manager.is_guardian_protected(target, source):
		return BAD
	var gain := 0
	for status in target.active_statuses:
		gain += healing_score(bot, target, status)
		match str(status.get("name", "")):
			"ability_negated", "activation_locked", "cannot_move", "destroy_at_turn_end", "poison":
				@warning_ignore("integer_division")
				gain += value(bot, target) / 3
			"guardian", "immune", "stone_skin", "temporarily_revealed":
				@warning_ignore("integer_division")
				gain -= value(bot, target) / 4
	for buff in target.active_buffs:
		gain -= int(buff.get("str", 0)) * 240 + int(buff.get("res", 0)) * 140 + int(buff.get("spd", 0)) * 700
	return gain if target.get_controller() == bot.bot_player else -gain

static func blot_summon_gain(bot, card: Card) -> int:
	@warning_ignore("integer_division")
	return bot._get_card_economic_value(card) - CARD_VALUE / 2 + (bot._get_play_cost(card, false) + card.sacrifice_cost * 2) * MANA_VALUE

static func budget_choices(bot, uids: Array, budget: int, count_limit: int, harmful: bool = false, blot: bool = false) -> Array[String]:
	# A small knapsack over level and board-space budgets beats choosing one
	# large creature that excludes a more valuable combination of small ones.
	var states := {Vector2i.ZERO: {"score": 0, "uids": []}}
	var seen := {}
	for raw_uid in uids:
		var uid := str(raw_uid)
		if seen.has(uid):
			continue
		seen[uid] = true
		var card: Card = bot.game_manager.get_card_by_uid(uid)
		if card == null:
			continue
		var level := maxi(0, card.get_effective_level())
		var gain := blot_summon_gain(bot, card) if blot else value(bot, card)
		if harmful == (card.get_controller() == bot.bot_player):
			gain = -gain
		var previous := states.duplicate(true)
		for state in previous:
			var next: Vector2i = state + Vector2i(level, 1)
			if next.x > budget or next.y > count_limit:
				continue
			var score := int(previous[state]["score"]) + gain
			if score <= int(states.get(next, {"score": BAD})["score"]):
				continue
			var state_uids: Array = previous[state]["uids"].duplicate()
			state_uids.append(uid)
			states[next] = {"score": score, "uids": state_uids}
	var best := {"score": 0, "uids": []}
	for state in states.values():
		if int(state["score"]) > int(best["score"]):
			best = state
	var selected: Array[String] = []
	selected.assign(best["uids"])
	return selected

static func power_score(bot, power: PowerCard, target: Card = null, available_mana: int = -1) -> int:
	var budget: int = bot.bot_player.mana if available_mana < 0 else available_mana
	var cost := activation_cost(bot, power)
	if cost > budget:
		return BAD
	var gain := BAD
	match key(power):
		"AcceleratedFate":
			if not bot.bot_player.deck_zone.cards.is_empty() and bot.game_manager.can_player_add_to_hand_now(bot.bot_player):
				gain = CARD_VALUE + (2500 if bot.bot_player.hand_zone.cards.size() <= 2 else 0)
		"OraclesSight": gain = target_score(bot, power, target) if target != null else BAD
		"BerserkerMead": gain = target_score(bot, power, target)
		"MechFactory": gain = 6500 if bot._get_first_open_summon_zone(bot.bot_player) != null else BAD
		"Palisade":
			gain = palisade_gain(bot)
		"ManaGuard":
			var amount := guard_mana(bot, budget)
			return bot._score_follower_loss(bot.bot_player, amount * ManaGuard.GUARD_PER_MANA) - mana_penalty(bot, amount) if amount > 0 else BAD
	return gain - mana_penalty(bot, cost) if gain > BAD else BAD

static func palisade_gain(bot) -> int:
	if open_spaces(bot.bot_player) == 0 or bot.game_manager.attack_restrictions.has(bot.opponent):
		return BAD
	for card in bot.game_manager.get_field_cards(bot.bot_player):
		if card is PalisadeBarrier and not card.abilities_suppressed():
			return BAD
	var damage := 0
	var pressure := 0
	for attacker in bot._get_board_creatures(bot.opponent):
		if not visible(bot, attacker) or attacker.is_sleeping or attacker.has_type("Aerial") or attacker.has_status_effect("cannot_attack"):
			continue
		if attacker.current_zone not in bot.opponent.frontline_zones or attacker.creature_mode != Card.CreatureMode.AGGRESSIVE:
			continue
		var strength: int = bot._get_direct_follower_damage(attacker)
		if strength <= 0:
			continue
		pressure += 1
		if bot.match_manager._get_possible_interceptors(attacker, bot.bot_player).is_empty():
			damage += strength
	if pressure == 0:
		return BAD
	# Advanced Building Techniques can reinforce a Palisade out of range of
	# most attackers, making the wall durable. Credit exactly the ward payment
	# the bot would make (ABT already unlocked, ward mana left after the
	# activation), so the combo is priced by its payoff instead of the power's
	# mere presence.
	var synergy := 0
	for power in bot._get_player_powers():
		if not (power is AdvancedBuildingTechniques) or power.is_face_down or power.abilities_suppressed():
			continue
		var palisade: PalisadePower = null
		for other in bot._get_player_powers():
			if other is PalisadePower:
				palisade = other
				break
		if palisade == null:
			break
		var ward_budget: int = bot.bot_player.mana - activation_cost(bot, palisade)
		if palisade.is_face_down:
			ward_budget -= palisade.get_unlock_mana_cost(bot.game_manager)
		if ward_budget > 0 and bot.has_method("_structure_ward_plan"):
			var preview := PalisadeBarrier.new()
			preview.card_owner = bot.bot_player
			var plan: Dictionary = bot._structure_ward_plan(preview, ward_budget, true, palisade._find_open_summon_zone())
			if int(plan.get("payment", 0)) > 0:
				synergy = maxi(synergy, int(plan.get("score", 0)))
		break
	# A Palisade can be attacked down, so discount the immediate follower risk.
	return mini(CARD_VALUE * 2, bot._score_follower_loss(bot.bot_player, maxi(0, damage - bot.bot_player.guard)) / 2) + pressure * 1500 + synergy

static func unlock_score(bot, power: PowerCard, unlock_cost: int = -1) -> int:
	if unlock_cost < 0:
		unlock_cost = power.get_unlock_mana_cost(bot.game_manager)
	var id := key(power)
	var gain := 0
	if id in ACTIVE_POWERS:
		var budget: int = bot.bot_player.mana - unlock_cost
		if budget < 0:
			return BAD
		var target: Card = null
		if power.targets:
			target = best_target(bot, power, power.get_valid_targets(bot.game_manager))
			if target == null:
				return BAD
		var activation := power_score(bot, power, target, budget)
		if activation < MIN_POWER_ACTIVATION_SCORE:
			return BAD
		# A usable repeatable Power is worth more than its first activation.
		var repeat_value := 0 if id in ["BerserkerMead", "ManaGuard"] else MANA_VALUE
		var cost := guard_mana(bot, budget) if id == "ManaGuard" else activation_cost(bot, power)
		return activation + mana_penalty(bot, cost) - mana_penalty(bot, unlock_cost + cost) + repeat_value
	elif id == "AltarOfDreams":
		# The Altar is worth the Void-fuelled summons it enables, not merely
		# the Demons standing around: sleepers on either side of the field
		# become premium sacrifice payment once the power is live.
		gain = altar_unlock_line_gain(bot)
		# The unlock is the held line's own step: it must not pay the hold
		# charge that keeps the stock for exactly this spend.
		return gain - mana_penalty(bot, unlock_cost, -1, true)
	elif PASSIVE_TYPES.has(id):
		for card in bot._get_board_creatures(bot.bot_player) + bot.bot_player.hand_zone.cards:
			for type in PASSIVE_TYPES[id]:
				if card.has_type(type):
					gain += 1700 if card.current_zone != bot.bot_player.hand_zone else 700
					break
	elif id == "FerociousDefence":
		for card in bot._get_board_creatures(bot.bot_player):
			if card.creature_mode == Card.CreatureMode.DEFENSIVE:
				gain += 2000
	elif id == "AdvancedBuildingTechniques":
		# Price the unlock by the ward payments the bot would actually make on
		# structures it can build: structures in hand it can play this turn, or
		# a Palisade its power can summon and then reinforce. Unlocking with no
		# funded build line is just spent mana, so an empty projection scores
		# nothing here.
		if bot.has_method("_project_advanced_building_unlock_gain"):
			gain += maxi(0, int(bot._project_advanced_building_unlock_gain(unlock_cost)))
	elif id == "FeastOfAmbrosiaAndNectar":
		for other in bot._get_player_powers():
			if other != power and other.culture == "Olympic" \
					and ((other.is_face_down and other.mana_cost > 0) or activation_cost(bot, other) > 0):
				gain += 2200
	elif id == "ImmortalTechniques":
		var mages := 0
		for card in bot._get_board_creatures(bot.bot_player) + bot.bot_player.hand_zone.cards:
			if card.has_type("Mage"):
				mages += 1
		if mages > 0:
			for card in bot.bot_player.hand_zone.cards + bot.bot_player.deck_zone.get_unordered_deck_cards():
				if card.mana_cost > 0 and (card is SpellCard or (card is HexCard and card.culture == "Ancient")):
					gain += 500
	elif id == "LawsOfCivilization":
		if bot.game_manager.has_active_laws_of_civilization():
			return BAD
		for player in [bot.bot_player, bot.opponent]:
			var side := -1 if player == bot.bot_player else 1
			for card in bot.game_manager.get_field_cards(player, false) + player.god_zone.cards:
				if visible(bot, card) and not card.is_face_down and not card.abilities_suppressed():
					if card is Odin or card is NuskuFirebearer or card is E2Abzu or card is DraupnirTheMultiplying:
						gain += side * 4500
			for zone in player.power_zones:
				for card in zone.cards:
					if visible(bot, card) and not card.is_face_down and not card.abilities_suppressed() \
							and (card is AcceleratedFate or card is OraclesSight or card is CallOfTheValkyrie):
						gain += side * 4500
	elif id == "ACostToWalkTheWorlds":
		for card in bot.bot_player.hand_zone.cards + bot.game_manager.get_field_cards(bot.bot_player, false):
			if card is BitMeseri or card is VoidShield or card is WheelOfFire or card is AsagTheDestroyer:
				gain += bot._score_follower_loss(bot.opponent, ACostToWalkTheWorlds.LOSS_AMOUNT)
			elif card is E2Abzu or card is SixthSageAnEnlilda:
				gain -= bot._score_follower_loss(bot.bot_player, ACostToWalkTheWorlds.LOSS_AMOUNT - ACostToWalkTheWorlds.GAIN_AMOUNT) / 2
		if bot.opponent.followers <= ACostToWalkTheWorlds.LOSS_AMOUNT and gain > 0:
			gain += MANA_VALUE * 2
	elif id == "Ragnarok":
		gain = -5000 # The bot forfeits its attacks this turn.
		for field_card in bot.game_manager.get_field_cards():
			if visible(bot, field_card) and (destruction_guard(field_card) or bot.game_manager.is_immune_to_source(field_card, power)):
				continue
			gain += value(bot, field_card) * (1 if field_card.get_controller() == bot.opponent else -1)
		gain += CARD_VALUE * (maxi(0, bot.opponent.hand_zone.cards.size() - Ragnarok.HAND_LIMIT) - maxi(0, bot.bot_player.hand_zone.cards.size() - Ragnarok.HAND_LIMIT))
		# Posture tilt: forfeiting its attacks is a real cost while the bot's
		# own clock is winning, while a reset that wipes the board is exactly
		# the forced action the locked-behind clock wants.
		if not bot._posture_evaluating and bot.has_method("_strategy_posture"):
			var posture := str(bot._strategy_posture().get("posture", "balanced"))
			if posture == "race" and bot.bot_player.followers >= bot.opponent.followers:
				@warning_ignore("integer_division")
				gain -= CARD_VALUE / 2
			elif posture == "locked_behind":
				@warning_ignore("integer_division")
				gain += CARD_VALUE / 2
	return gain - mana_penalty(bot, unlock_cost)

# ============================================================================
# Cross-turn combo lines: Sleep of the Duat, Altar of Dreams, and the Sages
#
# One creature summon per turn stretches the Asag line across three of the
# bot's turns: the Fourth Sage lands and acquires the Sixth Sage, the Sixth
# Sage lands the next turn and voids itself to Conjure Home the Sleep of the
# Duat, and only after the end of that turn puts the board to sleep can a
# Demon's sacrifice be paid by Voiding a sleeper with the Altar of Dreams.
# No single step is worth much alone, so every decision along the chain
# prices its own step with the projected continuation, including resources
# that only arrive over those turns: upcoming upkeep mana can fund a later
# Altar unlock, and the structure's spare discard can arrive as the next
# upkeep draw instead of sitting in hand right now.
# ============================================================================

# Voiding an enemy sleeper with the Altar is removal into the Abyss: it
# dodges destruction wards, death triggers, and graveyard replacement.
const ALTAR_VOID_REMOVAL_PREMIUM := 1500
# Share of the chain's value an earlier step still banks when one decision
# (a summon or a brood take) stands between it and the payoff.
const LINE_CONTINUATION_SHARE := 0.75

# Per-turn mana income the bot can plan on at its own upkeeps: the automatic
# gain plus the mana-option gain, net of an enemy Pazuzu's tax. The Matriarch
# brood take grants no income on its own turn, which the upkeep choice itself
# already prices, so projections cover the upkeeps after it.
static func projected_upkeep_income(bot, own_turns: int) -> int:
	if bot == null or bot.bot_player == null or bot.game_manager == null:
		return 0
	var drain_per_turn := 0
	if bot.has_method("_incoming_mana_drain"):
		drain_per_turn = int(bot._incoming_mana_drain())
	var income := 0
	for _index in range(maxi(0, own_turns)):
		income += bot.game_manager.get_automatic_upkeep_mana_gain(bot.bot_player, -1)
		income += bot.game_manager.get_effective_upkeep_mana_gain(
			bot.game_manager.get_base_upkeep_mana_gain(), bot.bot_player)
		# Each projected turn passes an enemy Pazuzu turn start, taxing the
		# stock this line plans to spend across those turns.
		income -= drain_per_turn
	return income

# Mana the bot can plan on across the line's turns: current stock plus each
# upcoming upkeep's income.
static func projected_upkeep_mana(bot, own_turns: int) -> int:
	if bot == null or bot.bot_player == null or bot.game_manager == null:
		return 0
	return bot.bot_player.mana + projected_upkeep_income(bot, own_turns)

# Fresh value of one creature being asleep under the Duat: sleep locks attack
# and intercept for as long as the structure lives, priced with the same
# weights the bot gives Alu's single-target sleep.
static func duat_sleep_lock_value(bot, creature: Card) -> int:
	if creature == null or not visible(bot, creature) \
			or creature.current_zone == null or not creature.current_zone.is_board_zone() \
			or creature.is_face_down or creature.is_stealth or creature.is_immune_to_sleep():
		return 0
	return int(value(bot, creature) * 0.8)

# A Divine Manifestation on either side wakes everyone, so the Duat cannot
# do anything while one is on the field.
static func divine_manifestation_on_field(bot) -> bool:
	if bot == null or bot.game_manager == null:
		return false
	for player in bot.game_manager.players:
		if player == null:
			continue
		for card in player.god_zone.cards:
			if card != null and not card.is_face_down and card.has_type("Divine Manifestation"):
				return true
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card != null and not card.is_face_down and not card.is_stealth \
						and card.has_type("Divine Manifestation"):
					return true
	return false

static func active_sleep_of_the_duat(bot) -> SleepOfTheDuat:
	if bot == null or bot.game_manager == null:
		return null
	for field_card in bot.game_manager.get_field_cards():
		var duat := field_card as SleepOfTheDuat
		if duat != null and duat._is_effectively_active():
			return duat
	return null

static func find_altar_of_dreams(bot) -> AltarOfDreams:
	if bot == null or bot.bot_player == null:
		return null
	for zone in bot.bot_player.power_zones:
		for power in zone.cards:
			var altar := power as AltarOfDreams
			if altar != null:
				return altar
	return null

# The Demon or Spirit whose sacrifice cost the Altar can replace; Asag is the
# flagship. Gods and active gods are never Altar payments.
static func _is_demon_or_spirit_coster(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and not (card is ActiveGodCard) \
		and card.sacrifice_cost > 0 \
		and (card.has_type("Demon") or card.has_type("Spirit"))

# Whether the Duat can still reach the field from wherever the bot currently
# stands in the line: already live, in hand, one Sixth Sage summon away
# (Conjure Home tutors it from the deck), or the full Fourth Sage chain with
# both Sages still to walk. The bot can jump in at any of these points.
static func duat_reachable(bot) -> bool:
	if bot == null or bot.bot_player == null or bot.game_manager == null:
		return false
	if divine_manifestation_on_field(bot):
		return false
	if active_sleep_of_the_duat(bot) != null:
		return true
	var fourth_in_hand := false
	var sixth_in_hand := false
	var duat_available := false
	for card in bot.bot_player.hand_zone.cards:
		if card is SleepOfTheDuat:
			duat_available = true
		elif key(card) == "FourthSageEnmegalamma":
			fourth_in_hand = true
		elif card is SixthSageAnEnlilda:
			sixth_in_hand = true
	if duat_available:
		return true
	var sixth_in_deck := false
	var duat_in_deck := false
	var sixth_deck_card: Card = null
	for card in bot.bot_player.deck_zone.get_unordered_deck_cards():
		if card is SixthSageAnEnlilda:
			sixth_in_deck = true
			sixth_deck_card = card
		elif card is SleepOfTheDuat:
			duat_in_deck = true
	# The Sixth Sage in hand tutors the structure straight from the deck; the
	# Fourth Sage in hand can still acquire the Sixth Sage beside it. The
	# Walk of the Sage + E2-abzu tutor can also pull the Sixth Sage out of
	# the deck without either Sage in hand.
	if not duat_in_deck:
		return false
	if sixth_in_hand:
		return true
	if fourth_in_hand and sixth_in_deck:
		return true
	if sixth_in_deck and walk_tutor_can_reach(bot, sixth_deck_card):
		return true
	# The Seventh Sage can replay a fielded Sixth Sage's Conjure Home, which
	# voids the Sixth Sage to fetch the structure straight from the deck.
	if duat_in_deck:
		var sixth_on_field := false
		var seventh_available := false
		for creature in bot._get_board_creatures(bot.bot_player):
			if creature is SixthSageAnEnlilda and not creature.is_face_down:
				sixth_on_field = true
			elif creature is SeventhSageUtuabzu and not creature.is_face_down and not creature.is_stealth:
				seventh_available = true
		for hand_card in bot.bot_player.hand_zone.cards:
			if hand_card is SeventhSageUtuabzu:
				seventh_available = true
		if sixth_on_field and seventh_available:
			return true
	return false

# The Demon or Spirit the Altar line summons: brood slots and hand are
# executable now (brood cards one upkeep take away), the deck is half a draw
# away and priced at half.
static func best_altar_coster(bot) -> Card:
	if bot == null or bot.bot_player == null:
		return null
	var best: Card = null
	var best_score := 0
	var sources: Array[Card] = []
	for zone in bot.bot_player.power_zones:
		for card in zone.cards:
			if _is_demon_or_spirit_coster(card):
				sources.append(card)
	for card in bot.bot_player.hand_zone.cards:
		if _is_demon_or_spirit_coster(card):
			sources.append(card)
	for card in sources:
		var score: int = bot._score_projected_card(card) \
			+ (500 if card.current_zone in bot.bot_player.power_zones else 0)
		if score > best_score:
			best_score = score
			best = card
	if bot.bot_player.deck_zone != null:
		for card in bot.bot_player.deck_zone.get_unordered_deck_cards():
			if not _is_demon_or_spirit_coster(card):
				continue
			var score := int(bot._score_projected_card(card) * 0.5)
			if score > best_score:
				best_score = score
				best = card
	return best

# Projected payoff of the Altar line: the Demon or Spirit body plus the
# sleeper it voids as sacrifice payment. `duat_will_land` also counts the
# enemy board a Duat that is live, in hand, or being fetched will put to
# sleep; without it only creatures asleep right now (from any sleep source)
# are payment. `turns_ahead` discounts a payoff still behind another summon.
static func altar_demon_payoff(bot, turns_ahead: int, duat_will_land: bool) -> Dictionary:
	var result := {"gain": 0, "coster": null, "void_target": null}
	if bot == null or bot.bot_player == null or bot.game_manager == null or bot.opponent == null:
		return result
	var altar := find_altar_of_dreams(bot)
	if altar == null:
		return result
	if altar.is_face_down:
		# The unlock can land on any turn of the line, so upkeep income the
		# bot still banks over the line's turns counts toward it.
		if projected_upkeep_mana(bot, 2) < altar.get_unlock_mana_cost(bot.game_manager):
			return result
	var coster := best_altar_coster(bot)
	if coster == null or bot._get_first_open_summon_zone(bot.bot_player) == null:
		return result
	var fuel: Array[Card] = []
	for player in bot.game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card == null or card is ActiveGodCard or card.card_type != Card.CardType.CREATURE:
					continue
				if card.is_sleeping:
					fuel.append(card)
				elif duat_will_land and player == bot.opponent and visible(bot, card) \
						and not card.is_face_down and not card.is_stealth and not card.is_immune_to_sleep():
					fuel.append(card)
	if fuel.is_empty():
		return result
	var void_target: Card = null
	var best_gain := 0
	for candidate in fuel:
		if candidate.get_controller() != bot.opponent:
			continue
		var void_gain := value(bot, candidate) + ALTAR_VOID_REMOVAL_PREMIUM
		if void_gain > best_gain:
			best_gain = void_gain
			void_target = candidate
	if void_target == null:
		# Only friendly sleepers are payment: voiding the cheapest one
		# replaces the direct sacrifice the summon would otherwise charge.
		for candidate in fuel:
			if void_target == null \
					or bot._score_summon_sacrifice_candidate(candidate) < bot._score_summon_sacrifice_candidate(void_target):
				void_target = candidate
	var gain: int = bot._score_projected_card(coster)
	if void_target.get_controller() == bot.opponent:
		gain += value(bot, void_target) + ALTAR_VOID_REMOVAL_PREMIUM
	else:
		gain += maxi(0, bot._score_summon_sacrifice_candidate(void_target))
	# A locked Altar still needs its unlock turn before the summon works.
	var availability := 1.0 if not altar.is_face_down else 0.85
	result["gain"] = int(float(gain) * availability * pow(0.8, maxi(0, turns_ahead)))
	result["coster"] = coster
	result["void_target"] = void_target
	return result

# Value of the Duat landing on the field: the board-wide sleep netted against
# the bot's own locked bodies, plus the Altar summon line the sleepers fuel.
# Creatures already asleep are skipped: their lock is not new (another Duat,
# Alu, or weather already holds it) while they still count as Altar fuel.
# `excluded` holds cards that leave the board as part of the decision being
# priced, such as the Sixth Sage voiding itself for Conjure Home.
static func duat_chain_value(bot, excluded: Array = []) -> int:
	if bot == null or bot.bot_player == null or bot.opponent == null:
		return BAD
	if divine_manifestation_on_field(bot):
		return BAD
	var gain := 0
	for enemy in bot._get_board_creatures(bot.opponent):
		if enemy.is_sleeping or enemy in excluded:
			continue
		gain += duat_sleep_lock_value(bot, enemy)
	for ally in bot._get_board_creatures(bot.bot_player):
		if ally.is_sleeping or ally in excluded:
			continue
		gain -= duat_sleep_lock_value(bot, ally)
	var payoff := altar_demon_payoff(bot, 1, true)
	if int(payoff["gain"]) > 0:
		gain += int(payoff["gain"])
	return gain

# Per-card continuation value added to deck picks along these lines. Each
# pick prices the step it is deciding with the chain's projected value, so
# the lines compete with ordinary card quality instead of being invisible.
static func deck_pick_line_gain(bot, card: Card, excluded: Array = []) -> int:
	if card == null or bot == null or bot.bot_player == null or bot.game_manager == null:
		return 0
	if card is SleepOfTheDuat:
		if divine_manifestation_on_field(bot):
			return 0
		var chain := duat_chain_value(bot, excluded)
		if chain <= BAD:
			return 0
		# The pick swaps a generic unknown card for this structure, so the
		# chain value replaces the generic card price.
		return maxi(0, chain - CARD_VALUE)
	if card is SixthSageAnEnlilda:
		# Conjure Home is the only tutor for the structure while it is in the
		# deck, and the Sixth Sage voids itself to cast it.
		var duat_in_deck := false
		for deck_card in bot.bot_player.deck_zone.get_unordered_deck_cards():
			if deck_card is SleepOfTheDuat:
				duat_in_deck = true
				break
		if not duat_in_deck or divine_manifestation_on_field(bot):
			return 0
		var chain := duat_chain_value(bot, excluded)
		if chain <= BAD:
			return 0
		return int(float(chain) * LINE_CONTINUATION_SHARE)
	if card is EnkiLordOfEridu:
		# A Divine Manifestation wakes every sleeper the Duat put down and
		# suppresses the sleep while it lives: the pick prices whether that
		# trade is actually good before the bot walks into it. With Isimud
		# standing by and the Walk + E2-abzu tutor live, the pick also
		# carries the Revelation continuation.
		return divine_manifestation_wake_adjustment(bot, card) \
			+ isimud_revelation_continuation(bot, card)
	if _is_demon_or_spirit_coster(card):
		# Demon and Spirit sacrifice-costers are the Altar's payoff bodies;
		# any sleep source the bot controls — not only the Duat chain —
		# turns the enemy board into their payment.
		var payoff := altar_demon_payoff(bot, 1, enemy_sleep_reachable(bot))
		if int(payoff["gain"]) <= 0:
			return 0
		return int(float(payoff["gain"]) * 0.5)
	return 0

# Value of the Ancient Dwelling the Sixth Sage's Conjure Home would add to
# hand. Voiding the Sage is the only way Conjure Home fires, and Conjure
# Home is the only way the deck's Dwelling is reachable, so the fetch prices
# the structure it actually deploys next rather than a generic deck pick:
# the better of the generic arrival value and the engine surplus of playing
# it now. A structure_score BAD means the Dwelling is dead in this board
# (no Mages for Eridu, a Divine Manifestation suppressing the Duat...), so
# only the generic pick remains and keeping the body can win.
static func conjure_home_fetch_value(bot, dwelling: Card, danger: int, excluded: Array = []) -> int:
	if bot == null or bot.bot_player == null or dwelling == null:
		return 0
	var gain: int = bot._deck_pick_value(dwelling, bot.bot_player.mana, danger, excluded)
	var structure_gain := structure_score(bot, dwelling, excluded)
	if structure_gain > BAD:
		gain = maxi(gain, CARD_VALUE + structure_gain)
	return gain

# Summoning a Divine Manifestation (Enki) while a Duat is live wakes every
# creature the structure put to sleep on both sides and keeps it from
# sleeping anyone new while the manifestation lives. Critically, that frees
# the opponent's locked board as well as the bot's own.
static func divine_manifestation_wake_adjustment(bot, card: Card) -> int:
	if card == null or bot == null or bot.game_manager == null:
		return 0
	var duat := active_sleep_of_the_duat(bot)
	if duat == null:
		return 0
	var adjustment := 0
	for player in bot.game_manager.players:
		if player == null:
			continue
		var own: bool = player == bot.bot_player
		for creature in bot._get_board_creatures(player):
			if creature == card or not creature.is_sleeping or creature.sleeping_from != duat:
				continue
			# Only the Duat's own sleep lifts; other sleep sources persist.
			var lock_value := duat_sleep_lock_value(bot, creature)
			adjustment += lock_value if own else -lock_value
	# While this manifestation lives, the structure can no longer put the
	# opponent's future bodies to sleep.
	if bot.opponent != null:
		for enemy in bot._get_board_creatures(bot.opponent):
			if enemy == card or enemy.is_sleeping or enemy.is_immune_to_sleep():
				continue
			@warning_ignore("integer_division")
			adjustment -= duat_sleep_lock_value(bot, enemy) / 2
	return adjustment

# Any creature asleep on the field right now, from any sleep source: the
# Altar can Void it as summon payment this very turn, so a payoff found this
# way needs no horizon discount.
static func any_sleeping_fuel(bot) -> bool:
	if bot == null or bot.game_manager == null:
		return false
	for player in bot.game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card != null and card.card_type == Card.CardType.CREATURE and card.is_sleeping:
					return true
	return false

# The Matriarch take that starts the Altar line: the brood Demon or Spirit is
# one upkeep and one Void-fuelled summon from the payoff, so the take carries
# the chain's continuation when the line is live. Sleepers already on the
# field let the payoff summon fire the same turn the take happens, and any
# sleep source the bot controls — not only the Duat chain — counts.
static func brood_take_line_gain(bot, card: Card) -> int:
	if not _is_demon_or_spirit_coster(card):
		return 0
	var source := controllable_sleep_source(bot)
	if not bool(source.get("available", false)):
		return 0
	var turns := 0 if any_sleeping_fuel(bot) else mini(1, maxi(0, int(source.get("turns_ahead", 2))))
	var payoff := altar_demon_payoff(bot, turns, true)
	return int(float(payoff["gain"]) * LINE_CONTINUATION_SHARE)

# Total Demon or Spirit sacrifice-costers the Altar could still pay for
# across brood slots, hand, and the remaining deck.
static func count_altar_costers(bot) -> int:
	if bot == null or bot.bot_player == null:
		return 0
	var count := 0
	for zone in bot.bot_player.power_zones:
		for card in zone.cards:
			if _is_demon_or_spirit_coster(card):
				count += 1
	for card in bot.bot_player.hand_zone.cards:
		if _is_demon_or_spirit_coster(card):
			count += 1
	if bot.bot_player.deck_zone != null:
		for card in bot.bot_player.deck_zone.get_unordered_deck_cards():
			if _is_demon_or_spirit_coster(card):
				count += 1
	return count

# Unlocking the Altar is worth the Void-fuelled summons it enables. The
# unlock's own mana is priced by unlock_score's return, so this is the gross
# line value: current sleepers (any source) plus the projected sleepers a
# reachable sleep engine still creates. The power stays unlocked for the rest
# of the game, so there is future value in more potential summons and more
# potential sleep: every further coster still to come is another
# Void-fuelled summon, and while the sleep engine runs the opponent's later
# arrivals turn into fresh Void targets for the uses after those.
static func altar_unlock_line_gain(bot) -> int:
	var source := controllable_sleep_source(bot)
	var reachable := bool(source.get("available", false))
	# A ready Alu or Gambanteinn sleeps its target the same turn it fires, so
	# the payoff it fuels is this turn's; a sleep engine still walking in
	# (the Duat chain) stays one turn out.
	var turns := 0 if any_sleeping_fuel(bot) else mini(1, maxi(0, int(source.get("turns_ahead", 1))))
	var payoff := altar_demon_payoff(bot, turns, reachable)
	var base_gain := int(payoff["gain"])
	if base_gain <= 0:
		return 0
	var gain := base_gain
	# Repeat fuel: sleepers standing now (any source) plus the enemy board
	# a reachable sleep engine still puts to sleep.
	var fuel_count := 0
	for player in bot.game_manager.players:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card != null and card.card_type == Card.CardType.CREATURE \
						and not (card is ActiveGodCard) and card.is_sleeping:
					fuel_count += 1
	if reachable:
		for enemy in bot._get_board_creatures(bot.opponent):
			if not enemy.is_sleeping and not enemy.is_immune_to_sleep() and visible(bot, enemy):
				fuel_count += 1
	# The payoff above consumed one sleeper; the uses beyond it need both
	# the bodies still to come and the fuel to pay for them. The opponent
	# gets a turn to answer between each use — removing the coster, waking
	# the board, or breaking the structure — so each further use is worth
	# well less than the last.
	var repeat_uses := clampi(mini(count_altar_costers(bot) - 1, fuel_count - 1), 0, 3)
	var repeat_share := 0.4
	for _use in range(repeat_uses):
		gain += int(float(base_gain) * repeat_share)
		repeat_share *= 0.5
	# Renewal: only while the sleep engine is actually running — not merely
	# planned — does everything the opponent still plays arrive asleep as
	# fuel for later uses. Attackers that can break the structure in one
	# combat are their standing answer to the engine, and are priced in.
	var duat := active_sleep_of_the_duat(bot)
	if duat != null and bot.opponent != null:
		var renewal := mini(bot.opponent.hand_zone.cards.size(), 4) * 250
		for enemy in bot._get_board_creatures(bot.opponent):
			if not enemy.is_sleeping and visible(bot, enemy) \
					and enemy.get_effective_strength() >= duat.get_effective_resilience():
				@warning_ignore("integer_division")
				renewal = renewal / 2
		gain += renewal
	return gain

# ============================================================================
# The held Altar line: sleep source + coster = on-demand enemy Void removal
#
# The Duat chain is one way sleepers arrive; a standing Alu (Stupefy) or a
# Gambanteinn on a Mage bearer is a sleep source the bot fires on demand,
# and a creature asleep right now — from any source — is fuel the moment the
# Altar is live. While the bot owns the Altar, controls such a source, and
# holds an executable Demon or Spirit coster, the enemy board is future Void
# payment. That line is worth holding mana for — the Altar's remaining unlock
# plus the coster's summon price plus the sleep activation tax, net of the
# upkeep income the line can wait for — so a good opportunity can be taken
# the turn it appears. Paying the same summon with the bot's own bodies
# forecloses its Void window, so a direct sacrifice is charged the line's
# continuation while the source is reachable.
# ============================================================================

# Share of the held line's Void value charged for spending the stock below
# its funding level: the window is delayed rather than dead while the source
# keeps offering fuel, so the strand costs a fraction of the payoff.
const ALTAR_HOLD_STRAND_SHARE := 0.3
# Discount on a burned Void window when another executable coster keeps the
# line's next summon open anyway.
const ALTAR_BURN_ALT_COSTER_SHARE := 0.5

# The bot's own ways to turn an enemy creature into Altar Void fuel, best
# first: a creature asleep right now needs no activation, a standing Alu or
# a Gambanteinn-equipped Mage sleeps any one target the turn it is fired, and
# the Sleep of the Duat blankets the enemy board from the end of its landing
# turn. Returns {"available": bool, "activation_cost": int, "turns_ahead":
# int, "sleeps_any_visible_enemy": bool}.
static func controllable_sleep_source(bot) -> Dictionary:
	var result := {"available": false, "activation_cost": 0, "turns_ahead": 0,
			"sleeps_any_visible_enemy": false}
	if bot == null or bot.bot_player == null or bot.game_manager == null or bot.opponent == null:
		return result
	var sleepable_enemies := 0
	var enemy_fuel_now := false
	for enemy in bot._get_board_creatures(bot.opponent):
		if enemy == null or enemy is ActiveGodCard or not visible(bot, enemy):
			continue
		sleepable_enemies += 1
		if enemy.is_sleeping:
			enemy_fuel_now = true
	var candidate := {"turns": 1000, "cost": 0, "sleeps_any": false}
	# 1) A creature asleep right now, from any source, is already fuel.
	if enemy_fuel_now:
		candidate = {"turns": 0, "cost": 0, "sleeps_any": false}
	# 2) A standing Alu stupefies any one visible enemy the turn it fires.
	if sleepable_enemies > 0:
		for creature in bot._get_board_creatures(bot.bot_player):
			var alu := creature as Alu
			if alu == null or alu.is_face_down or alu.is_stealth or alu.is_sleeping \
					or alu.abilities_suppressed() or alu.is_activation_locked(bot.game_manager) \
					or not alu.can_take_major_creature_action():
				continue
			var tax: int = bot.game_manager.get_creature_action_mana_cost(alu, "activate")
			if int(candidate["turns"]) > 0 or (int(candidate["turns"]) == 0 and int(candidate["cost"]) > tax):
				candidate = {"turns": 0, "cost": tax, "sleeps_any": true}
	# 3) A Gambanteinn on an awake Mage bearer sleeps any one target this turn.
	if sleepable_enemies > 0:
		for field_card in bot.game_manager.get_field_cards(bot.bot_player):
			var wand := field_card as Gambanteinn
			if wand == null or not wand.can_activate(bot.game_manager) or wand.equipped_on == null:
				continue
			if not wand.equipped_on.has_type("Mage"):
				continue
			if int(candidate["turns"]) > 0 \
					or (int(candidate["turns"]) == 0 and int(candidate["cost"]) > Gambanteinn.ACTIVATION_COST):
				candidate = {"turns": 0, "cost": Gambanteinn.ACTIVATION_COST, "sleeps_any": true}
	# 4) The Sleep of the Duat blankets the enemy board from the end of its
	#    landing turn: live now, or still walking in via the sage chain.
	var duat := active_sleep_of_the_duat(bot)
	if duat != null:
		if int(candidate["turns"]) > 1:
			candidate = {"turns": 1, "cost": 0, "sleeps_any": true}
	elif duat_reachable(bot) and int(candidate["turns"]) > 2:
		candidate = {"turns": 2, "cost": 0, "sleeps_any": true}
	if int(candidate["turns"]) >= 1000:
		return result
	result["available"] = true
	result["activation_cost"] = int(candidate["cost"])
	result["turns_ahead"] = int(candidate["turns"])
	result["sleeps_any_visible_enemy"] = bool(candidate["sleeps_any"])
	return result

# Whether the bot's own sleep engine can still turn enemy creatures into
# Altar Void fuel: the Duat chain, a creature asleep right now (any source),
# or a ready Alu / Gambanteinn sleep activation.
static func enemy_sleep_reachable(bot) -> bool:
	if bot == null or bot.bot_player == null or bot.game_manager == null:
		return false
	return bool(controllable_sleep_source(bot).get("available", false))

# The Demon or Spirit coster the held line can actually summon: hand or
# brood (one upkeep take away), best body first. Deck costers are speculation
# the line prices at half, not something to hold mana for.
static func executable_altar_coster(bot) -> Card:
	var best: Card = null
	var best_score := 0
	if bot == null or bot.bot_player == null:
		return best
	for zone in bot.bot_player.power_zones:
		for card in zone.cards:
			if not _is_demon_or_spirit_coster(card):
				continue
			var score: int = bot._score_projected_card(card) + 500
			if score > best_score:
				best_score = score
				best = card
	for card in bot.bot_player.hand_zone.cards:
		if not _is_demon_or_spirit_coster(card):
			continue
		var score: int = bot._score_projected_card(card)
		if score > best_score:
			best_score = score
			best = card
	return best

# Executable costers the held line can still name after the current one:
# while another is held, a direct-sacrifice summon only delays the line's
# next window instead of burning it.
static func count_executable_altar_costers(bot) -> int:
	if bot == null or bot.bot_player == null:
		return 0
	var count := 0
	for zone in bot.bot_player.power_zones:
		for card in zone.cards:
			if _is_demon_or_spirit_coster(card):
				count += 1
	for card in bot.bot_player.hand_zone.cards:
		if _is_demon_or_spirit_coster(card):
			count += 1
	return count

# The enemy creature the held line would Void: the most valuable one that is
# asleep already, or — when the source can sleep any visible enemy — the most
# valuable one it could still put to sleep.
static func best_future_void_target(bot, source: Dictionary) -> Card:
	if bot == null or bot.opponent == null:
		return null
	var sleeps_any := bool(source.get("sleeps_any_visible_enemy", false))
	var best: Card = null
	var best_gain := 0
	for enemy in bot._get_board_creatures(bot.opponent):
		if enemy == null or enemy is ActiveGodCard or not visible(bot, enemy) \
				or enemy.is_immune_to_sleep():
			continue
		if not enemy.is_sleeping and not sleeps_any:
			continue
		var gain := value(bot, enemy) + ALTAR_VOID_REMOVAL_PREMIUM
		if gain > best_gain:
			best_gain = gain
			best = enemy
	return best

# The held line in one decision-ready package, cached per decision step:
# `live` (altar + sleep source + executable coster + worthwhile enemy fuel),
# `gross` (the line's full funding: remaining unlock + coster summon +
# activation tax), `need` (gross net of the upkeep income over the source's
# window — the stock to keep on hand now), `gain` (the Void removal the
# window buys), and the source and coster it was computed from.
static func held_altar_line(bot) -> Dictionary:
	if bot == null:
		return {"live": false, "need": 0, "gross": 0, "gain": 0,
				"coster": null, "source_cost": 0, "turns_ahead": 0}
	var cache = bot.get("_altar_line_cache")
	if cache is Dictionary and cache.has("live"):
		return cache
	var fresh := _compute_held_altar_line(bot)
	bot.set("_altar_line_cache", fresh)
	return fresh

static func _compute_held_altar_line(bot) -> Dictionary:
	var result := {"live": false, "need": 0, "gross": 0, "gain": 0,
			"coster": null, "source_cost": 0, "turns_ahead": 0}
	if bot == null or bot.bot_player == null or bot.game_manager == null or bot.opponent == null:
		return result
	var altar := find_altar_of_dreams(bot)
	if altar == null:
		return result
	var source := controllable_sleep_source(bot)
	if not bool(source.get("available", false)):
		return result
	var coster := executable_altar_coster(bot)
	if coster == null or bot._get_first_open_summon_zone(bot.bot_player) == null:
		return result
	var turns_ahead := maxi(0, int(source.get("turns_ahead", 0)))
	var unlock_left: int = altar.get_unlock_mana_cost(bot.game_manager) if altar.is_face_down else 0
	var gross: int = unlock_left + bot._get_play_cost(coster, false) + int(source.get("activation_cost", 0))
	# The hold only exists while the line is actually reachable: within a few
	# of the bot's upkeeps the projected stock must cover the whole funding,
	# mirroring the face-down Altar's own unlock reachability check.
	if projected_upkeep_mana(bot, 3) < gross:
		return result
	var target := best_future_void_target(bot, source)
	if target == null:
		return result
	result["live"] = true
	result["coster"] = coster
	result["source_cost"] = int(source.get("activation_cost", 0))
	result["turns_ahead"] = turns_ahead
	result["gross"] = gross
	# The need is the funding net of the income over the source's window: an
	# opportunity that is live now wants the stock on hand, while a source
	# still a turn or two out can wait for its own upkeeps.
	result["need"] = maxi(0, gross - projected_upkeep_income(bot, turns_ahead))
	result["gain"] = value(bot, target) + ALTAR_VOID_REMOVAL_PREMIUM
	return result

# The charge for a spend that would dip the stock below the held line's
# funding: the removal window stays closed until later upkeep income rebuilds
# the dip. Zero while the line is not live, already funded, or the spend
# stays above its need.
static func altar_line_hold_charge(bot, stock: int, spend: int) -> int:
	if spend <= 0:
		return 0
	var line := held_altar_line(bot)
	if not bool(line.get("live", false)):
		return 0
	var need := int(line.get("need", 0))
	if need <= 0 or stock - spend >= need:
		return 0
	return int(float(line.get("gain", 0)) * ALTAR_HOLD_STRAND_SHARE)

# What a direct-sacrifice payment burns: the same Demon or Spirit could have
# paid by Voiding an enemy sleeper the bot's sleep source still creates, so
# spending the bot's own bodies instead is charged that removal — full weight
# while this is the line's own coster, halved while another executable one
# keeps the next window open, and discounted by the source's distance while
# the opponent still gets turns to answer it.
static func held_altar_void_burn_charge(bot, coster: Card) -> int:
	if bot == null or coster == null:
		return 0
	var line := held_altar_line(bot)
	if not bool(line.get("live", false)) or line.get("coster") != coster:
		return 0
	var charge := int(line.get("gain", 0))
	if count_executable_altar_costers(bot) > 1:
		charge = int(float(charge) * ALTAR_BURN_ALT_COSTER_SHARE)
	return int(float(charge) * pow(0.8, maxi(0, int(line.get("turns_ahead", 0)))))

# ============================================================================
# Walk of the Sage + E2-abzu: an on-demand tutor for the deck's Mer Mages
#
# Walk of the Sage voids a Mage from the deck; E2-abzu later returns a Mer
# Mage from the Void to hand, but only while the target's level fits under
# the mana left after the retrieval payment (level < mana - 3). With both
# halves available, every Mer Mage still in the deck is gettable whenever
# the bot wants it, so the power's activation and the deck picks price those
# cards with their real line value — fetching Enki for Isimud's Revelation
# being the flagship.
# ============================================================================

static func find_walk_of_the_sage(bot) -> WalkOfTheSage:
	if bot == null or bot.bot_player == null:
		return null
	for zone in bot.bot_player.power_zones:
		for power in zone.cards:
			var walk := power as WalkOfTheSage
			if walk != null:
				return walk
	return null

# True while E2-abzu is standing ready on the field or playable from hand.
static func e2_abzu_available(bot) -> bool:
	if bot == null or bot.bot_player == null or bot.game_manager == null:
		return false
	for field_card in bot.game_manager.get_field_cards(bot.bot_player):
		var abzu := field_card as E2Abzu
		if abzu != null and not abzu.is_face_down and not abzu.is_muted:
			return true
	for card in bot.bot_player.hand_zone.cards:
		if card is E2Abzu and bot._get_first_open_reserve_zone(bot.bot_player) != null:
			return true
	return false

# Projected mana the bot can still spend when E2-abzu retrieves, after the
# Walk of the Sage's own unlock and activation, or -1 when the tutor line is
# not live. The retrieval can wait a turn, so two upkeeps of income count.
static func walk_tutor_budget(bot) -> int:
	var walk := find_walk_of_the_sage(bot)
	if walk == null or not e2_abzu_available(bot):
		return -1
	var walk_cost: int = WalkOfTheSage.ACTIVATION_COST
	if walk.is_face_down:
		walk_cost += WalkOfTheSage.UNLOCK_COST
	var budget := projected_upkeep_mana(bot, 2) - walk_cost
	return budget if budget >= E2Abzu.RETURN_TO_HAND_COST else -1

# Whether the tutor can currently reach this card: Walk of the Sage only
# voids Mages, E2-abzu only returns Mer Mages, and the structure only lifts
# one whose level fits under the retrieval budget.
static func walk_tutor_can_reach(bot, target: Card) -> bool:
	if target == null or target.card_type != Card.CardType.CREATURE or target.is_god \
			or not target.has_type("Mer") or not target.has_type("Mage"):
		return false
	var budget := walk_tutor_budget(bot)
	if budget < 0:
		return false
	return target.get_effective_level() + E2Abzu.RETURN_TO_HAND_COST + 1 <= budget

# Isimud is standing by to deploy a Divine Manifestation: in hand (one free
# summon away) or face-up on the field with its abilities live.
static func isimud_available(bot) -> bool:
	if bot == null or bot.bot_player == null:
		return false
	for card in bot.bot_player.hand_zone.cards:
		if card is Isimud:
			return true
	for creature in bot._get_board_creatures(bot.bot_player):
		if creature is Isimud and not creature.is_face_down and not creature.is_stealth \
				and not creature.abilities_suppressed():
			return true
	return false

# The Revelation continuation: a Mer Mage Divine Manifestation (Enki is the
# flagship) is one tutor away from hand, and Isimud then deploys it at
# Forerunner's discount without spending the turn's normal summon.
static func isimud_revelation_continuation(bot, manifestation: Card) -> int:
	if manifestation == null or not manifestation.has_type("Divine Manifestation"):
		return 0
	if not isimud_available(bot) or not walk_tutor_can_reach(bot, manifestation):
		return 0
	return int(Isimud.DIVINE_MANIFESTATION_DISCOUNT * MANA_VALUE * 0.3 * LINE_CONTINUATION_SHARE)

# The Seventh Sage's Channel Ally (on summon, from the field or the Void)
# and Imbue Ally (activate, from the field) replay another allied Ancient
# Sage's impact, so the right channel is the one whose replayed impact is
# actually worth something now: the Fourth Sage's Search re-tutors a Mer Sage
# from the deck and works from the Void as well (Search does not need its
# body), the Sixth Sage's Conjure Home fetches an Ancient Dwelling but only
# while it stands on the field to void itself, and the other Sages keep
# their flat impact values.
static func seventh_sage_channel_gain(bot, target_sage: Card) -> int:
	if target_sage == null or not visible(bot, target_sage):
		return 0
	if not target_sage.has_type("Sage") or str(target_sage.culture).strip_edges() != "Ancient":
		return 0
	var on_field: bool = target_sage.current_zone != null and target_sage.current_zone.is_board_zone()
	match key(target_sage):
		"FourthSageEnmegalamma":
			if not bot.game_manager.can_player_add_to_hand_now(bot.bot_player):
				return 0
			var best := 0
			var danger: int = bot._forecast_incoming_follower_loss()
			for deck_card in target_sage.get_valid_targets(bot.game_manager):
				var acquisition: int = target_sage.get_acquisition_cost(deck_card) \
					if target_sage.has_method("get_acquisition_cost") else 0
				var pick: int = bot._deck_pick_value(deck_card, bot.bot_player.mana - acquisition, danger)
				best = maxi(best, pick - mana_penalty(bot, acquisition))
			return best
		"SixthSageAnEnlilda":
			# Conjure Home needs the Sixth Sage on the field to void itself;
			# channeled from the Void it fizzles without moving anything.
			if not on_field:
				return 0
			var best_dwelling := 0
			var dwelling_danger: int = bot._forecast_incoming_follower_loss()
			for dwelling in target_sage.get_valid_targets(bot.game_manager):
				best_dwelling = maxi(best_dwelling, conjure_home_fetch_value(bot, dwelling, dwelling_danger, [target_sage]))
			var body_loss: int = bot._get_card_economic_value(target_sage)
			return maxi(0, best_dwelling - body_loss)
		"FirstSageAdapa":
			return 2600
		"ThirdSageEnmedugga":
			return 1400
		_:
			return 1200
