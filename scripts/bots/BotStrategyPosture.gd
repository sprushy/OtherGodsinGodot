extends RefCounted

# Strategic posture evaluation for the practice/ranked bots. The tactical
# engine (ThorPracticeBot) scores local exchanges well; this layer answers the
# strategic question those scores cannot: what kind of game is this, and how
# should the shared economy be weighted while it stays that way.
#
# Postures:
# - "race": the bot's clock is at least a full turn faster than the opponent's
#   (or the opponent cannot answer attacks at all). Follower damage to the
#   opponent is worth more than card economy.
# - "defend": the opponent's clock is faster, or they can take a large bite
#   out of the bot's followers next turn. Follower safety gains are worth
#   more than tempo.
# - "locked_ahead": neither side can push follower damage through, and the
#   bot survives the shared fatigue clock longer. Doing nothing risky wins;
#   trades that lose bodies are charged extra.
# - "locked_behind": the board is locked and the fatigue clock favors the
#   opponent. The bot must force action: attacks that remove enemy bodies get
#   a bonus even at card parity.
# - "balanced": no posture pressure; scoring runs at neutral weights.
#
# God Death is folded into both clocks: a player without a face-up awake god
# bleeds 7 followers at every own upkeep (and skips the automatic upkeep mana
# gain) no matter what either board blocks, so the bleeding side's clock is
# real even behind a wall.
#
# The evaluate() result is cached per turn by the bot (like the locked-board
# cache), with a reentrancy guard in the bot so nested scoring passes during
# evaluation read neutral weights instead of recursing.

const NO_CLOCK := 1000
const RACE_DAMAGE_MULTIPLIER := 1.35
const DEFEND_SAFETY_MULTIPLIER := 1.3
const MAX_FATIGUE_UPKEEPS := 200

static func neutral() -> Dictionary:
	return {
		"posture": "balanced",
		"damage_multiplier": 1.0,
		"safety_multiplier": 1.0,
		"bot_push": 0,
		"opponent_push": 0,
		"bot_clock": NO_CLOCK,
		"opponent_clock": NO_CLOCK,
	}


static func evaluate(bot) -> Dictionary:
	if bot == null or bot.game_manager == null or bot.bot_player == null or bot.opponent == null:
		return neutral()
	var result := neutral()
	var bot_attack_push := _sustained_push(bot)
	var opponent_attack_push: int = bot._forecast_incoming_follower_loss()
	# God Death taxes the dying player's own upkeep no matter what either board
	# does: blocking cannot stop it, and the affected player also skips the
	# automatic upkeep mana gain. Add that guaranteed bleed to the clock the
	# bleeding player faces so a walled-in bot plans to force the wall open (or
	# develop bodies that can) instead of trading into it.
	var bot_bleed := _god_death_bleed(bot, bot.bot_player)
	var opponent_bleed := _god_death_bleed(bot, bot.opponent)
	var bot_push := bot_attack_push + opponent_bleed
	var opponent_push := opponent_attack_push + bot_bleed
	# Radiant Wisdom-style conversion (Baldr Active): follower damage becomes
	# follower gain, so each point of a converter's push also heals its owner
	# every turn and doubles the race swing. God Death is not combat damage, so
	# the bleed never feeds a converter.
	var bot_conversion_gain: int = bot_attack_push if _has_live_converter(bot, bot.bot_player) else 0
	var opponent_conversion_gain: int = opponent_attack_push if _has_live_converter(bot, bot.opponent) else 0
	# Net clocks: recurring upkeep heals (Baldr's Blessed One) slow a clock
	# that does not out-damage them; a faster clock ignores the heal.
	var bot_net_push: int = bot_push - _upkeep_follower_gain(bot, bot.opponent) - opponent_conversion_gain
	var opponent_net_push: int = opponent_push - _upkeep_follower_gain(bot, bot.bot_player) - bot_conversion_gain
	result["bot_push"] = bot_push
	result["opponent_push"] = opponent_push
	result["bot_clock"] = ceili(float(bot.opponent.followers) / float(maxi(1, bot_net_push))) if bot_net_push > 0 else NO_CLOCK
	result["opponent_clock"] = ceili(float(bot.bot_player.followers) / float(maxi(1, opponent_net_push))) if opponent_net_push > 0 else NO_CLOCK

	var posture := "balanced"
	if bot_push <= 0 and opponent_push <= 0 and bot._locked_board_state():
		var bot_fatigue_upkeeps := _fatigue_upkeeps_to_death(bot, bot.bot_player)
		var opponent_fatigue_upkeeps := _fatigue_upkeeps_to_death(bot, bot.opponent)
		if bot_fatigue_upkeeps != opponent_fatigue_upkeeps:
			posture = "locked_ahead" if bot_fatigue_upkeeps > opponent_fatigue_upkeeps else "locked_behind"
		else:
			posture = "locked_ahead" if bot.bot_player.followers >= bot.opponent.followers else "locked_behind"
	elif opponent_push <= 0 and bot_push > 0:
		# Free damage every turn: the race is the only plan that matters.
		posture = "race"
	elif int(result["bot_clock"]) + 1 <= int(result["opponent_clock"]):
		posture = "race"
	elif opponent_net_push > 0 and (int(result["opponent_clock"]) < int(result["bot_clock"]) \
			or opponent_push * 4 >= bot.bot_player.followers):
		posture = "defend"
	result["posture"] = posture
	if posture == "race":
		result["damage_multiplier"] = RACE_DAMAGE_MULTIPLIER
	elif posture == "defend":
		result["safety_multiplier"] = DEFEND_SAFETY_MULTIPLIER
	return result


# Recurring unblocked follower damage the bot's current board can push per
# turn: the guaranteed total from attackers with no possible interceptor, or
# half the total of all aggressive frontline bodies that would need blockers
# cleared. Guard absorbs the first points of either line.
static func _sustained_push(bot) -> int:
	var guaranteed := 0
	var potential := 0
	for attacker in bot._get_board_creatures(bot.bot_player):
		if attacker.current_zone == null or attacker.current_zone not in bot.bot_player.frontline_zones:
			continue
		if attacker.creature_mode != Card.CreatureMode.AGGRESSIVE or attacker.is_sleeping \
				or attacker.has_status_effect("cannot_attack"):
			continue
		var damage: int = bot._get_direct_follower_damage(attacker)
		potential += damage
		if bot._can_attack_followers_safely(attacker):
			guaranteed += damage
	return maxi(0, maxi(guaranteed, potential / 2) - bot.opponent.guard)


# A live Radiant Wisdom-style converter (Baldr Active) turns its owner's
# follower damage into follower gain: each point of that owner's push also
# heals them, so the net clock must subtract the owner's own push.
static func _has_live_converter(bot, player: Player) -> bool:
	if bot == null or player == null:
		return false
	for creature in bot._get_board_creatures(player):
		if creature.has_method("converts_follower_damage_to_conversion") \
				and creature.converts_follower_damage_to_conversion():
			return true
	return false


# Recurring upkeep follower gain from a player's god (Baldr's Blessed One).
# God zones are public, so this is information the bot is allowed to have.
static func _upkeep_follower_gain(bot, player: Player) -> int:
	if bot == null or player == null or player.god_zone == null:
		return 0
	for god in player.god_zone.cards:
		if god is Baldr and not god.is_muted:
			return Baldr.FOLLOWERS_GAINED_PER_TURN
	return 0


# Guaranteed God Death bleed at the player's own upkeeps: 7 followers per turn
# plus the skipped automatic upkeep mana gain. The god-zone/board state that
# decides god death is public, and an active follower-loss prevention stems
# the bleed while it lasts.
static func _god_death_bleed(bot, player: Player) -> int:
	if bot == null or bot.game_manager == null or player == null:
		return 0
	if not bot.game_manager.is_player_under_god_death(player):
		return 0
	if bot.game_manager.has_turn_follower_loss_prevention(player):
		return 0
	return GameManager.GOD_DEATH_FOLLOWER_LOSS


# Upkeeps (of this player's own turns) until fatigue alone reduces their
# followers to zero. Fatigue starts at turn 49 and escalates every 7 turns.
static func _fatigue_upkeeps_to_death(bot, player: Player) -> int:
	if bot.game_manager == null or player == null:
		return MAX_FATIGUE_UPKEEPS
	var followers: int = player.followers
	var turn: int = bot.game_manager.turn_number + (2 if bot.game_manager.current_player == player else 1)
	var upkeeps := 0
	while followers > 0 and upkeeps < MAX_FATIGUE_UPKEEPS:
		followers -= bot.game_manager.get_fatigue_follower_loss(turn)
		turn += 2
		upkeeps += 1
	return upkeeps
