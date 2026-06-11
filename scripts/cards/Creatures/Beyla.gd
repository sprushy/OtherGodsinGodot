extends CreatureCard
class_name Beyla

const REVIVE_ACTIVATION_COST := 2

func _init() -> void:
	super._init()
	card_name = "Beyla"
	card_types = ["Human", "Servant"]
	level = 1
	mana_cost = 0
	speed = 2
	resilience = 3
	strength = 1
	sacrifice_cost = 0
	ability_text = "Revive ([b]Impact[/b]): [b]Wake[/b] all Norse creatures.\nRevive (%d mana): [b]Wake[/b] all friendly creatures." % REVIVE_ACTIVATION_COST
	flavor_text = ""
	culture = "Norse"
	artist = "Elliot Chan"
	art_path = "res://images/card_art/creatures/beyla_clean_art.png"

func get_activation_label() -> String:
	return "Revive"

func can_activate(game_manager: GameManager) -> bool:
	if game_manager == null:
		return false
	if get_controller() != game_manager.current_player:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if abilities_suppressed():
		return false
	if is_sleeping:
		return false
	if card_owner == null or card_owner.mana < REVIVE_ACTIVATION_COST:
		return false
	return not is_used

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null and card_owner != null and card_owner.mana < REVIVE_ACTIVATION_COST:
			game_manager.note_player_feedback("%s needs %d mana to use Revive." % [card_name, REVIVE_ACTIVATION_COST])
		return
	if not card_owner.spend_mana(REVIVE_ACTIVATION_COST):
		if game_manager != null:
			game_manager.note_player_feedback("%s needs %d mana to use Revive." % [card_name, REVIVE_ACTIVATION_COST])
		return
	_wake_matching_creatures(game_manager, func(card: Card) -> bool:
		return card.get_controller() == get_controller()
	)
	is_used = true
	print("%s uses Revive and wakes all friendly creatures." % card_name)

func on_impact(game_manager: GameManager) -> void:
	_wake_matching_creatures(game_manager, func(card: Card) -> bool:
		return card.culture == "Norse"
	)
	print("%s revives all Norse creatures on impact." % card_name)

func on_turn_end(_game_manager: GameManager) -> void:
	is_used = false

func _wake_matching_creatures(game_manager: GameManager, matcher: Callable) -> void:
	if game_manager == null:
		return
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if card.card_type != Card.CardType.CREATURE:
					continue
				if not matcher.call(card):
					continue
				card.wake_up()
