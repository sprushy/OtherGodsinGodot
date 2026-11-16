extends RefCounted

# Explicit rules, rather than ability-text guesses. Legal targets and timing
# always come from the authoritative card/manager before these scores are used.
const BAD := -1000000
const CARD_VALUE := 5000
const MANA_VALUE := 1000
# Mana keeps some residual worth even when the stock passes everything the
# deck can still pay for: creature action taxes, equipment, and Guard always
# exist as buyers. Unbounded sinks raise that floor (see _mana_value_floor).
const MANA_VALUE_FLOOR_PCT := 15
const MANA_SINK_DEFENSIVE_FLOOR_PCT := 45
# How quickly the marginal rate decays per point of mana stock above the
# highest cost the remaining deck, hand, and board can still reach.
const MANA_SATURATION_DECAY := 0.4
const MIN_POWER_ACTIVATION_SCORE := 1200
const TACTICAL_CARDS := [
	"BitMeseri", "RunicSpellbreaker", "Snowball", "SirensSong", "TabletOfLife",
	"BookOfLife", "Earthquake", "FiresOfJudgment", "Famine", "OccultSingularity",
	"FalloftheMighty", "BaneOfTheSvartalfar", "CircleofRebirth", "Absence",
	"LightOfMorningsDoors", "FoolishOptimism", "DivineLightning", "FifaTheMagicalArrow", "Exorcism",
	"GungnirTheSpearOfOdin", "NamburbiApotropaeon", "HeroicStand", "Hringhorni",
	"Banishment", "SpellDemolition", "Sap", "SepLemutti", "Smite", "VoidShield",
	"TheInferno", "TheDeluge", "Dromi", "Gleipnir", "SapStrength", "VisionOfTartarus", "VisionOfOdin", "Hermes",
	"Drought", "HeavySnow", "Storm", "SavingGrace", "JiangZiyaFisherOfKings", "ShroudOfTheAncients", "WildMagic",
]
const ACTIVE_POWERS := ["AcceleratedFate", "OraclesSight", "BerserkerMead", "MechFactory", "Palisade", "ManaGuard"]
const BOARD_ABILITIES := ["Alu", "Lindwyrm", "Lamashatu", "ClayEaters", "AncientPyre", "Watchtower", "Gawain", "Beyla", "Nimue", "JiangZiyaFisherOfKings",
	"Berserker", "EnHeduAnna", "GududPriest", "HariiShaman", "Isimud", "Mopsus", "SeventhSageUtuabzu", "WingedLion"]
# Creatures whose face-up value stealth suppresses, so they must not be summoned
# face-down. Card._abilities_disabled_by_hidden_state() turns every creature
# ability off while is_stealth is set, and the engine gates impact/kill/death
# hooks plus these self-gated passives on abilities_suppressed(). Reveal-trigger
# creatures (Afanc, PictishBeast, Grindylow, Lailoken...) are excluded on
# purpose: their payoff fires on reveal and is valued by the bot separately.
const STEALTH_SUPPRESSED_KEYS := [
	"AgainWalker", "AnkouServantToTheReaper", "AsagTheDestroyer", "Asakku", "Asaruludu",
	"Aurboda", "BlessedKnights", "Caleuche", "DurinnSecondborn", "EnkiLordOfEridu",
	"ErlqueensNightingale", "Fenrir", "FirstSageAdapa", "FourthSageEnmegalamma", "GalaTura",
	"Garm", "GiantMasterArchitect", "Gilgamesh", "GugalannaBullOfHeaven", "Gullinbursti",
	"HariiFransiscan", "HariiJarl", "HelBlarDraug", "HumbabaTheTerrible", "HyenaPack",
	"MalinalxochitlAcolyte", "MinotaurFootsoldier", "Nagual", "NergalLion", "PaiLongAutumnKing",
	"Pazuzu", "Pegasus", "RabidWolf", "Rabisu", "RedCap",
	"SixthSageAnEnlilda", "StoneMonkey", "SulakTheUnclean", "TelchineApprentice", "Thiazi",
	"ThirdSageEnmedugga", "TianlongHolyDragon", "UriskGrovekeepers", "WhiteStag", "WolfAdolescent",
	"WolfCub",
]
const EQUIPMENT := ["BeardedAxe", "RunicShortsword", "ReedBow", "SharurTheFlyingMace", "SevenLeagueBoots", "DraupnirTheMultiplying", "Gambanteinn"]
const STRUCTURES := ["AncientPyre", "Watchtower", "WardingStone", "DoorwayToTheVoid", "E2Abzu",
	"AnointingStatue", "EriduCityOfSages", "GlitnirThePeaceful", "HildskjalfThroneOfOdin"]
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
		or id in ["BlotSacrifice", "KeyOfSolomon", "MeadOfPoetry", "WheelOfFire", "ApollyonsDemiurge", "DeucalionsInfants"]

static func visible(bot, card: Card) -> bool:
	if card == null:
		return false
	if card.current_zone != null and card.current_zone.zone_type == Zone.ZoneType.DECK:
		return card.current_zone.get_deck_placement(card) != Zone.DeckPlacement.UNKNOWN
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
	var score := CARD_VALUE + maxi(0, card.get_effective_strength()) * 80 + maxi(0, card.get_effective_resilience()) * 25 + maxi(0, card.mana_cost) * 200
	if card.is_god and _would_destroying_god_cause_god_death(bot, card):
		var owner := card.get_controller()
		score += bot._score_follower_loss(owner, GameManager.GOD_DEATH_FOLLOWER_LOSS) + MANA_VALUE
	return score

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

static func mana_penalty(bot, amount: int, available_mana: int = -1) -> int:
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
			score += CARD_VALUE / 2
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
	if top <= 0:
		return 0
	var income: int = bot.game_manager.get_automatic_upkeep_mana_gain(player, bot.game_manager.turn_number + 1) \
		+ bot.game_manager.get_effective_upkeep_mana_gain(bot.game_manager.get_base_upkeep_mana_gain(), player)
	return top + income

# Mana never falls to zero because action taxes, equipment, and Guard remain.
# Unbounded sinks lift the floor further, and a sink that advances the actual
# win condition (Ancient Pyre's follower conversion) keeps mana at full rate:
# every point converts directly into follower swing regardless of stock size.
static func _mana_value_floor(bot) -> int:
	var profile := mana_sink_profile(bot)
	if bool(profile.get("win_condition", false)):
		return MANA_VALUE
	if bool(profile.get("defensive", false)):
		return MANA_VALUE * MANA_SINK_DEFENSIVE_FLOOR_PCT / 100
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
		if name not in ["malinalxochitl_poison", "destroy_at_turn_end", "freyja_active_open_sessrumnir", "tonal_extraction_no_shift"]:
			continue
		var duration := 1.0
		if name != "destroy_at_turn_end" and (status.get("expires_after_combat", false) \
				or int(status.get("expires_turn", bot.game_manager.turn_number + 2)) <= bot.game_manager.turn_number + 1):
			duration = 0.5
		other_effects[name] = maxf(float(other_effects.get(name, 0.0)), duration)
	weight += 0.15 * float(other_effects.get("malinalxochitl_poison", 0.0))
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
			var sign := 1 if target.culture == "Norse" else -1
			return {"str": sign * VisionOfOdin.STR_SWING, "res": 0, "spd": sign * VisionOfOdin.SPEED_SWING}
		"Hermes": return {"str": 0, "res": 0, "spd": Hermes.SPEED_BONUS}
		"Snowball": return {"str": -2, "res": 0, "spd": 0}
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
			or source is VisionOfOdin or source is VisionOfTartarus or source is Hermes):
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
			var target_value := value(bot, target)
			return _disable_gain(bot, target, {"cannot_attack": target_value * 0.5, "cannot_intercept": target_value * 0.3})
		"Nimue":
			if own and target is EquipmentCard:
				for bearer in bot._get_board_creatures(bot.bot_player):
					if target.can_equip_to(bearer):
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
				return attack_gain + bot._score_follower_loss(bot.opponent, 2 * Dromi.FOLLOWER_LOSS)
			var restrictions := {"cannot_attack": target_value * 0.5, "cannot_intercept": 2500}
			if not target.ability_text.is_empty():
				restrictions["activation_locked"] = target_value * 0.15
				restrictions[Card.ABILITY_NEGATED_STATUS] = target_value * 0.1
			return _disable_gain(bot, target, restrictions)
		"Snowball", "SapStrength", "VisionOfTartarus":
			if not enemy:
				return BAD
			return stat_gain(bot, card, target, action)
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
			if key(card) == "BerserkerMead":
				score -= 1500 # Sleeping through the next turn costs another action.
			return score
		"TabletOfLife", "Hringhorni":
			if bot._get_first_open_summon_zone(bot.bot_player) == null:
				return BAD
			var score := value(bot, target)
			if key(card) == "TabletOfLife" and target.get_effective_level() >= 3:
				score = int(score * 0.45)
			score += bot._score_effect_summon_sacrifice_followup([target], activation_cost(bot, card))
			return score
		"BookOfLife":
			if bot._get_first_open_summon_zone(bot.bot_player) == null:
				return BAD
			# The body leaves the hand and loses its abilities. Value the saved
			# summon payment at the current marginal mana rate, rather than
			# counting it as an extra drawn card.
			var score: int = maxi(0, bot._get_play_cost(target, false)) * marginal_mana_value(bot) + target.get_effective_strength() * 80 + target.get_effective_resilience() * 25
			if key(target) in ["EnkiLordOfEridu", "Askelladen", "Gawain", "Lindwyrm", "Lamashatu", "Mummu"]:
				score -= 4000
			if target.has_type("Mage") or target.has_type("Priest"):
				score -= 1000
			score += bot._score_effect_summon_sacrifice_followup([target], activation_cost(bot, card))
			return score
		"SirensSong":
			return combat_gain_for_stolen_creature(bot, target) if enemy else BAD
		"Absence":
			if not enemy or not visible(bot, target):
				return BAD
			var mute_value := value(bot, target) if target.is_god else 4500 + target.mana_cost * 800
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
			match key(target):
				"FirstSageAdapa": return 2600
				"ThirdSageEnmedugga": return 1400
				"FourthSageEnmegalamma": return 2200
				"SixthSageAnEnlilda": return 2400
				_: return 1200
		"OraclesSight":
			return bot._get_hand_value(target) * 60 + (2000 if target is CreatureCard and bot._get_best_affordable_hand_creature(0) == null else 0)
	return BAD

static func combat_gain_for_stolen_creature(bot, target: Card) -> int:
	if not visible(bot, target) or target.is_sleeping or not target.can_take_major_creature_action():
		return 0
	# Temporary control is valuable for its immediate attack and for denying
	# interception. It is not permanent removal or a newly acquired card.
	var score := 0
	for defender in bot._get_board_creatures(bot.opponent):
		if defender == target or not visible(bot, defender):
			continue
		if target.get_effective_strength() > defender.get_effective_strength() and defender.creature_mode == Card.CreatureMode.AGGRESSIVE:
			score = maxi(score, value(bot, defender))
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
		return total / samples if samples > 0 else BAD
	var known_chance: float = bot._sample_avoids(unknown_count, samples, unknown_slots_before_known_magic)
	var unknown_gain := float(total) / samples if samples > 0 else 0.0
	return roundi(known_chance * _wild_magic_card_gain(bot, first_known_magic) + (1.0 - known_chance) * unknown_gain)

static func _wild_magic_card_gain(bot, card: Card) -> int:
	if card is WildMagic or not supports_ranked_deck_card(card):
		return 0
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
static func _harii_shaman_transform_gain(bot, source: Card, target: Card) -> int:
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

static func structure_score(bot, structure: Card) -> int:
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
					gain = maxi(gain, CARD_VALUE + CARD_VALUE * 2 / clock_turns)
		"Watchtower":
			# Counters arrive from future enemy entries, not existing cards.
			gain = 6000 if bot._board_creature_count(bot.opponent) < 3 else 3000
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
		"HildskjalfThroneOfOdin":
			if bot.bot_player.deck_zone.cards.size() > 2 or bot.opponent.deck_zone.cards.size() > 2:
				gain = 8600 if bot._find_player_god() is Odin else 6800
		_: return BAD
	return gain - CARD_VALUE - mana_penalty(bot, activation_cost(bot, structure))

static func preparation_score(bot, card: Card) -> int:
	var id := key(card)
	if card is ShroudOfTheAncients:
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

static func forced_combat_choice(bot, source: Card, attackers: Array, defenders: Array) -> Dictionary:
	var best := {"score": BAD, "attacker_uid": "", "defender_uid": ""}
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
			if score > int(best["score"]):
				best = {"score": score, "attacker_uid": attacker.uid, "defender_uid": defender.uid}
	return best

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
			"ability_negated", "activation_locked", "cannot_move", "destroy_at_turn_end", "malinalxochitl_poison":
				gain += value(bot, target) / 3
			"guardian", "immune", "stone_skin", "temporarily_revealed":
				gain -= value(bot, target) / 4
	for buff in target.active_buffs:
		gain -= int(buff.get("str", 0)) * 240 + int(buff.get("res", 0)) * 140 + int(buff.get("spd", 0)) * 700
	return gain if target.get_controller() == bot.bot_player else -gain

static func blot_summon_gain(bot, card: Card) -> int:
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
			var selected: Array = previous[state]["uids"].duplicate()
			selected.append(uid)
			states[next] = {"score": score, "uids": selected}
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
	# A Palisade can be attacked down, so discount the immediate follower risk.
	return mini(CARD_VALUE * 2, bot._score_follower_loss(bot.bot_player, maxi(0, damage - bot.bot_player.guard)) / 2) + pressure * 1500

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
		for card in bot.bot_player.hand_zone.cards:
			if card.card_type == Card.CardType.STRUCTURE:
				gain += 2200
		for card in bot.bot_player.deck_zone.get_unordered_deck_cards():
			if card.card_type == Card.CardType.STRUCTURE:
				gain += 450
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
	return gain - mana_penalty(bot, unlock_cost)
