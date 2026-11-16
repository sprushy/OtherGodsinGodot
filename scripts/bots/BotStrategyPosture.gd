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
	var bot_push := _sustained_push(bot)
	var opponent_push: int = bot._forecast_incoming_follower_loss()
	result["bot_push"] = bot_push
	result["opponent_push"] = opponent_push
	result["bot_clock"] = ceili(float(bot.opponent.followers) / float(maxi(1, bot_push))) if bot_push > 0 else NO_CLOCK
	result["opponent_clock"] = ceili(float(bot.bot_player.followers) / float(maxi(1, opponent_push))) if opponent_push > 0 else NO_CLOCK

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
	elif opponent_push > 0 and (int(result["opponent_clock"]) < int(result["bot_clock"]) \
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
