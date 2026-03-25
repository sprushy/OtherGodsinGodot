extends CreatureCard
class_name Caleuche

const SPIRIT_CREW_SOURCE := "Caleuche Spirit Crew"

func _init() -> void:
	super._init()
	card_name = "Caleuche, the Ghost Ship"
	card_types = ["Vessel", "Spirit", "Aqueous", "Nahuatl Creature"]
	level = 2
	mana_cost = 2
	sacrifice_cost = 0
	speed = 1
	resilience = 10
	strength = 10
	ability_text = "Spirit Crew ([b]Passive[/b]): Gains 10 STR and 1 SPD for each other friendly Spirit on the field."
	flavor_text = ""
	culture = "Nahuatl"
	art_path = "res://images/card_art/caleuche_art_fixed.png"

func on_summon(game_manager: GameManager) -> void:
	_update_spirit_crew_bonus(game_manager)

func on_reveal(game_manager: GameManager) -> void:
	_update_spirit_crew_bonus(game_manager)

func on_turn_start(game_manager: GameManager) -> void:
	_update_spirit_crew_bonus(game_manager)

func on_after_combat(game_manager: GameManager, _opposing_card: Card) -> void:
	_update_spirit_crew_bonus(game_manager)

func on_removed(_game_manager: GameManager) -> void:
	clear_buffs_from(SPIRIT_CREW_SOURCE)

func on_muted(_game_manager: GameManager) -> void:
	clear_buffs_from(SPIRIT_CREW_SOURCE)

func on_unmuted(game_manager: GameManager) -> void:
	_update_spirit_crew_bonus(game_manager)

func on_any_card_moved(game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	_update_spirit_crew_bonus(game_manager)

func _update_spirit_crew_bonus(_game_manager: GameManager) -> void:
	clear_buffs_from(SPIRIT_CREW_SOURCE)
	if current_zone == null or not current_zone.is_board_zone() or abilities_suppressed():
		return

	var controller := get_controller()
	if controller == null:
		return

	var other_friendly_spirits := 0
	for zone in [controller.god_zone] + controller.power_zones + controller.frontline_zones + controller.reserve_zones:
		for card in zone.cards:
			if card == self:
				continue
			if card.has_type("Spirit"):
				other_friendly_spirits += 1

	if other_friendly_spirits > 0:
		add_buff(
			SPIRIT_CREW_SOURCE,
			other_friendly_spirits * 10,
			0,
			other_friendly_spirits,
			self,
			controller,
			"passive"
		)
