extends RefCounted

# Explicit rules, rather than ability-text guesses. Legal targets and timing
# always come from the authoritative card/manager before these scores are used.
const BAD := -1000000
const CARD_VALUE := 5000
const MANA_VALUE := 1000
const TACTICAL_CARDS := [
	"BitMeseri", "RunicSpellbreaker", "Snowball", "SirensSong", "TabletOfLife",
	"BookOfLife", "Earthquake", "FiresOfJudgment", "Famine", "OccultSingularity",
	"FallOfTheMighty", "BaneOfTheSvartalfar", "CircleOfRebirth", "Absence",
	"LightOfMorningsDoors", "FoolishOptimism", "DivineLightning", "FifaTheMagicalArrow", "Exorcism",
	"GungnirTheSpearOfOdin", "NamburbiApotropaeon", "HeroicStand", "Hringhorni",
	"Banishment", "SpellDemolition", "Sap", "SepLemutti", "Smite", "VoidShield",
	"TheInferno", "TheDeluge", "Dromi", "Gleipnir", "SapStrength", "VisionOfTartarus", "VisionOfOdin", "Hermes",
]
const ACTIVE_POWERS := ["AcceleratedFate", "OraclesSight", "BerserkerMead", "MechFactory", "Palisade", "ManaGuard"]
const BOARD_ABILITIES := ["Alu", "Lindwyrm", "Lamashatu", "ClayEaters", "AncientPyre", "Watchtower", "Gawain"]
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

static func visible(bot, card: Card) -> bool:
	if card == null:
		return false
	if card.get_controller() == bot.bot_player:
		return true
	if card.current_zone in [bot.opponent.hand_zone, bot.opponent.deck_zone]:
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
	if not visible(bot, card):
		return CARD_VALUE
	return CARD_VALUE + maxi(0, card.get_effective_strength()) * 80 + maxi(0, card.get_effective_resilience()) * 25 + maxi(0, card.mana_cost) * 200

static func combat_visible(bot, action: CardAction) -> bool:
	if action == null or not visible(bot, action.attacker):
		return false
	var defender: Card = bot._get_attack_defender_card(action)
	return defender == null or visible(bot, defender)

static func mana_penalty(bot, amount: int) -> int:
	var score := maxi(0, amount) * MANA_VALUE
	if amount > 0 and not bot.bot_player.has_summoned_this_turn:
		var creature: Card = bot._get_best_affordable_hand_creature(0)
		if creature != null and bot._get_play_cost(creature, false) > bot.bot_player.mana - amount:
			score += CARD_VALUE / 2
	return score

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
	if visible(bot, target):
		if gm.is_immune_to_source(target, source):
			return BAD
		if destruction and destruction_guard(target):
			return BAD
		if destruction and target.card_type == Card.CardType.CREATURE and gm.has_turn_destruction_ward(bot.opponent):
			return BAD
	var score := value(bot, target)
	# Removing a combatant cancels this attack. Credit only the improvement
	# over letting the existing combat finish, including profitable trades.
	if action != null and action.type == CardAction.Type.ATTACK:
		if combat_visible(bot, action) and (action.attacker == target or bot._get_attack_defender_card(action) == target):
			score -= bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
	else:
		score += CARD_VALUE / 5
	return score

static func destruction_guard(target: Card) -> bool:
	return target.has_status_effect("berserker_mead_guard") or target.has_status_effect("berserker_rage_guard") or target.has_status_effect("en_hedu_anna_exaltation_guard")

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
		"Lamashatu": return {"str": 5, "res": 5, "spd": 0}
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
	var changes := stat_changes(bot, card, target)
	var combat_action := action if action != null and action.type == CardAction.Type.ATTACK else null
	return combat_gain(bot, target, int(changes.get("str", 0)), int(changes.get("res", 0)), combat_action, int(changes.get("spd", 0)))

static func combat_gain(bot, target: Card, str_delta: int, res_delta: int = 0, action: CardAction = null, speed_delta: int = 0) -> int:
	if not visible(bot, target):
		return 0
	if action != null:
		if action.type != CardAction.Type.ATTACK or action.united_front_partner != null or not visible(bot, action.attacker):
			return 0
		var defender: Card = bot._get_attack_defender_card(action)
		if defender != null and not visible(bot, defender):
			return 0
		return bot._score_attack_economy(bot._estimate_attack_economy(action, target, str_delta, speed_delta, res_delta)) - bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
	# These forecasts concern attacks later this turn, not next-turn value from
	# temporary buffs that expire during the opponent's turn.
	if bot.game_manager.current_player != bot.bot_player:
		return 0
	var best := 0
	for attacker in bot._get_attack_ready_creatures():
		if bot._has_committed_attack(attacker):
			continue
		if target.get_controller() == bot.bot_player and target != attacker:
			continue
		var defenders: Array = bot._get_board_creatures(bot.opponent) if target == attacker else [target]
		if target == attacker:
			defenders.append(bot.opponent)
		for defender in defenders:
			if defender is Card and (not visible(bot, defender) or not bot._can_attack_creature(attacker, defender)):
				continue
			if defender is Player and not bot._can_attack_followers_after_modifier(attacker, target, speed_delta):
				continue
			var planned := CardAction.new()
			planned.type = CardAction.Type.ATTACK
			planned.attacker = attacker
			planned.target = defender
			planned.halve_follower_damage = attacker.halves_follower_damage_inflicted()
			var before: int = bot._score_attack_economy(bot._estimate_attack_economy(planned, null, 0, 0))
			if defender is Player and not bot._can_attack_followers_safely(attacker):
				before = 0
			var after: int = bot._score_attack_economy(bot._estimate_attack_economy(planned, target, str_delta, speed_delta, res_delta))
			# A buff must create an attack the bot would actually want to take.
			if after > 0:
				best = maxi(best, after - maxi(0, before))
	if bot._can_win_followers_after_modifier(target, str_delta, speed_delta) and not bot._can_win_followers_after_modifier(null, 0, 0):
		best = maxi(best, CARD_VALUE * 20)
	return best

static func target_score(bot, card: Card, target: Card, action: CardAction = null) -> int:
	if target == null:
		return BAD
	var own: bool = target.get_controller() == bot.bot_player
	var enemy: bool = target.get_controller() == bot.opponent
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
			return removal_score(bot, card, target, action)
		"BitMeseri":
			return removal_score(bot, card, target, action, false)
		"ClayEaters":
			if target in card.pending_geophagia_targets:
				return BAD
			return int(removal_score(bot, card, target) * 0.7)
		"Alu":
			return int(value(bot, target) * 0.8) if enemy and not target.is_sleeping else BAD
		"Dromi", "Gleipnir":
			if not enemy or not visible(bot, target) or target.has_status_effect("cannot_attack"):
				return BAD
			var gain := int(value(bot, target) * 0.75)
			if key(card) == "Dromi":
				gain += bot._score_follower_loss(bot.opponent, 14)
			elif not target.has_status_effect("cannot_intercept"):
				gain += 2500
			return gain
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
			if key(card) == "Lamashatu":
				score += 1800 # Persistent growth, even without an immediate attack.
			if key(card) == "BerserkerMead":
				score -= 1500 # Sleeping through the next turn costs another action.
			return score
		"TabletOfLife", "Hringhorni":
			if bot._get_first_open_summon_zone(bot.bot_player) == null:
				return BAD
			var score := value(bot, target)
			if key(card) == "TabletOfLife" and target.get_effective_level() >= 3:
				score = int(score * 0.45)
			return score
		"BookOfLife":
			if bot._get_first_open_summon_zone(bot.bot_player) == null:
				return BAD
			# The body leaves the hand and loses its abilities. Value the saved
			# summon payment, rather than counting it as an extra drawn card.
			var score: int = maxi(0, bot._get_play_cost(target, false)) * MANA_VALUE + target.get_effective_strength() * 80 + target.get_effective_resilience() * 25
			if key(target) in ["EnkiLordOfEridu", "Askelladen", "Gawain", "Lindwyrm", "Lamashatu", "Mummu"]:
				score -= 4000
			if target.has_type("Mage") or target.has_type("Priest"):
				score -= 1000
			return score
		"SirensSong":
			return combat_gain_for_stolen_creature(bot, target) if enemy else BAD
		"Absence":
			if not enemy or not visible(bot, target) or target.is_muted:
				return BAD
			return value(bot, target) if target.is_god else 4500 + target.mana_cost * 800
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
			if not enemy or target.is_god:
				return BAD
			if target.get_effective_resilience() <= 5:
				return removal_score(bot, card, target)
			return combat_gain(bot, target, 0, -5)
		"Watchtower":
			return 1500 if enemy and not visible(bot, target) else BAD
		"Gawain":
			var score := 0
			for status in card.get_removable_statuses(target):
				score = maxi(score, healing_score(bot, target, status))
			return score if own else BAD
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
	if id == "FallOfTheMighty":
		# Its maximum depends on hidden strength; leave that uncertain cast
		# alone rather than querying private stats from the authoritative state.
		for target in bot.game_manager.get_field_cards():
			if not visible(bot, target):
				return []
		return card.get_strongest_creatures(bot.game_manager)
	return result

static func effect_score(bot, card: Card, target: Card = null, action: CardAction = null) -> int:
	var gain := BAD
	var id := key(card)
	if target != null:
		gain = target_score(bot, card, target, action)
	match id:
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
		"HeroicStand": gain = 7 * MANA_VALUE
		"TheInferno", "TheDeluge", "Earthquake", "FiresOfJudgment", "Famine", "OccultSingularity", "FallOfTheMighty", "BaneOfTheSvartalfar":
			gain = 0
			var removed: Array = []
			for doomed in wipe_cards(bot, card):
				if visible(bot, doomed) and bot.game_manager.is_immune_to_source(doomed, card):
					continue
				if id != "BaneOfTheSvartalfar" and visible(bot, doomed) and destruction_guard(doomed):
					continue
				if id != "BaneOfTheSvartalfar" and doomed.get_controller() == bot.opponent and doomed.card_type == Card.CardType.CREATURE and bot.game_manager.has_turn_destruction_ward(bot.opponent):
					continue
				var amount := value(bot, doomed)
				if id == "BaneOfTheSvartalfar":
					amount = int(amount * 0.7)
				gain += amount if doomed.get_controller() == bot.opponent else -amount
				removed.append(doomed)
			if action != null and action.type == CardAction.Type.ATTACK and combat_visible(bot, action) and (action.attacker in removed or bot._get_attack_defender_card(action) in removed):
				gain -= bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
		"BookOfLife": gain = maxi(0, gain) + follower_gain(bot.bot_player, 10)
		"FoolishOptimism":
			var choice := forced_combat_choice(bot, card, card.get_lowest_level_attacker_choices(bot.game_manager), card.get_highest_level_defender_choices(bot.game_manager))
			gain = int(choice.get("score", BAD))
		"CircleOfRebirth":
			gain = 0
			var spaces := {bot.bot_player: open_spaces(bot.bot_player), bot.opponent: open_spaces(bot.opponent)}
			for dead in bot.game_manager.died_this_turn:
				if dead.current_zone not in [dead.card_owner.graveyard_zone, dead.card_owner.abyss_zone] or not (dead.has_type("Animal") or dead.has_type("Plant")) or spaces.get(dead.card_owner, 0) <= 0:
					continue
				spaces[dead.card_owner] -= 1
				gain += value(bot, dead) if dead.card_owner == bot.bot_player else -value(bot, dead)
		"LightOfMorningsDoors":
			gain = card._get_hidden_opponent_cards(bot.game_manager).size() * 1500
	if gain <= BAD:
		return BAD
	if id == "Hermes":
		return gain - mana_penalty(bot, Hermes.ACTIVATION_COST)
	return gain - CARD_VALUE - mana_penalty(bot, activation_cost(bot, card))

static func equipment_score(bot, equipment: Card, bearer: Card) -> int:
	if not equipment.can_equip_to(bearer) or bearer.is_sleeping:
		return BAD
	if key(equipment) == "DraupnirTheMultiplying":
		# Three end-turn payments are more likely on a protected reserve bearer.
		return (6500 if bearer.current_zone in bot.bot_player.reserve_zones else 5500) - CARD_VALUE
	if key(equipment) not in ["BeardedAxe", "RunicShortsword", "ReedBow", "SharurTheFlyingMace", "SevenLeagueBoots"]:
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

static func structure_score(bot, structure: Card) -> int:
	var gain := 0
	match key(structure):
		"AncientPyre": gain = 6500 if bot.opponent.followers < 50 or bot.bot_player.followers < 50 else 0
		"Watchtower":
			# Counters arrive from future enemy entries, not existing cards.
			gain = 6000 if bot._board_creature_count(bot.opponent) < 3 else 3000
		"WardingStone":
			if bot.game_manager.attack_restrictions.has(bot.opponent):
				return BAD
			for creature in bot._get_board_creatures(bot.opponent):
				if visible(bot, creature) and not creature.is_sleeping and not creature.has_status_effect("cannot_attack"):
					gain += value(bot, creature) / 2
			gain += 2500 if bot.bot_player.followers < 50 else 0
		_: return BAD
	return gain - CARD_VALUE - mana_penalty(bot, activation_cost(bot, structure))

static func preparation_score(bot, card: Card) -> int:
	var id := key(card)
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

static func guard_mana(bot) -> int:
	var danger := 0
	for creature in bot._get_board_creatures(bot.opponent):
		if visible(bot, creature) and creature.current_zone in bot.opponent.frontline_zones and not creature.is_sleeping and not creature.has_status_effect("cannot_attack"):
			danger += maxi(0, creature.get_effective_strength())
	var needed := maxi(0, danger - bot.bot_player.guard)
	return mini(bot.bot_player.mana, int(ceil(float(needed) / 5.0)))

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
			action.halve_follower_damage = true
			var score: int = bot._score_attack_economy(bot._estimate_attack_economy(action, null, 0, 0))
			if score > int(best["score"]):
				best = {"score": score, "attacker_uid": attacker.uid, "defender_uid": defender.uid}
	return best

static func healing_score(bot, target: Card, status: Dictionary) -> int:
	var name := str(status.get("name", ""))
	if name in ["sleep", "cannot_attack", "cannot_intercept", "petrified", "abilities_negated", "muted"]:
		return int(value(bot, target) * 0.6)
	return 0

static func budget_choices(bot, uids: Array, budget: int, count_limit: int, harmful: bool = false) -> Array[String]:
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
		var gain := value(bot, card)
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

static func power_score(bot, power: PowerCard, target: Card = null) -> int:
	var gain := BAD
	match key(power):
		"AcceleratedFate":
			if not bot.bot_player.deck_zone.cards.is_empty():
				gain = CARD_VALUE + (2500 if bot.bot_player.hand_zone.cards.size() <= 2 else 0)
		"OraclesSight": gain = target_score(bot, power, target) if target != null else BAD
		"BerserkerMead": gain = target_score(bot, power, target)
		"MechFactory": gain = 6500 if bot._get_first_open_summon_zone(bot.bot_player) != null else BAD
		"Palisade":
			gain = 4500 if bot._board_creature_count(bot.opponent) > bot._board_creature_count(bot.bot_player) else 0
			for field_card in bot.game_manager.get_field_cards(bot.bot_player):
				if key(field_card) == "PalisadeBarrier":
					gain = 0
		"ManaGuard":
			var amount := guard_mana(bot)
			return bot._score_follower_loss(bot.bot_player, amount * 5) - mana_penalty(bot, amount) if amount > 0 else BAD
	return gain - mana_penalty(bot, activation_cost(bot, power)) if gain > BAD else BAD

static func unlock_score(bot, power: PowerCard) -> int:
	var id := key(power)
	var gain := 0
	if id in ACTIVE_POWERS:
		if id == "BerserkerMead":
			for target in power.get_valid_targets(bot.game_manager):
				gain = maxi(gain, target_score(bot, power, target))
		elif id == "ManaGuard":
			gain = power_score(bot, power)
		elif id == "AcceleratedFate":
			gain = 3000 if bot.bot_player.hand_zone.cards.size() <= 2 and not bot.bot_player.deck_zone.cards.is_empty() else 0
		else:
			gain = 4500 if bot._board_creature_count(bot.bot_player) < 3 else 2000
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
		for card in bot.game_manager.get_field_cards(bot.bot_player) + bot.bot_player.hand_zone.cards:
			if card.card_type == Card.CardType.STRUCTURE:
				gain += 1700
	elif id == "FeastOfAmbrosiaAndNectar":
		for other in bot._get_player_powers():
			if other != power and other.culture == "Olympic":
				gain += 2200
	return gain - mana_penalty(bot, power.get_unlock_mana_cost(bot.game_manager))
