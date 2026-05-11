extends ActiveGodCard
class_name BaldrActive

const LINKED_GOD_NAME := "Baldr"
const ART_PATH := "res://images/card_art/gods/BaldrAIEdit.png"
const DIVINE_RESILIENCE_STATUS := "blessed_ward"

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Baldr, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 7
	mana_cost = 11
	speed = 2
	resilience = 15
	strength = 25
	culture = "Norse"
	# flavor_text = "Baldr's radiance turns every blow against the faithful into renewed devotion."
	flavor_text = ""
	ability_text = "[b]Divine Resilience[/b] ([b]Passive[/b]): Immune to creature abilities. Cannot be destroyed in combat. Follower damage resulting from combat with this card is halved.\n[b]Radiant Wisdom[/b] ([b]Passive[/b]): Any time you would inflict follower damage, convert the followers instead."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func get_self_graveyard_replacement_zone(
	_game_manager: GameManager,
	combat_death: bool,
	_destruction: bool,
	send_to_abyss: bool
) -> Zone:
	if not combat_death or send_to_abyss:
		return null
	if not _passives_are_active():
		return null
	if current_zone == null or not current_zone.is_board_zone():
		return null
	return current_zone

func halves_follower_damage_inflicted() -> bool:
	return _passives_are_active()

func converts_follower_damage_to_conversion(_game_manager: GameManager = null) -> bool:
	return _passives_are_active()

func on_summon(_game_manager: GameManager) -> void:
	_refresh_divine_resilience()

func on_turn_start(_game_manager: GameManager) -> void:
	_refresh_divine_resilience()

func on_removed(_game_manager: GameManager) -> void:
	_clear_divine_resilience()

func on_muted(_game_manager: GameManager) -> void:
	_clear_divine_resilience()

func on_unmuted(_game_manager: GameManager) -> void:
	_refresh_divine_resilience()

func on_reveal(_game_manager: GameManager) -> void:
	_refresh_divine_resilience()

func on_any_card_moved(_game_manager: GameManager, _moved_card: Card, _from_zone: Zone, _to_zone: Zone) -> void:
	_refresh_divine_resilience()

func _passives_are_active() -> bool:
	return not abilities_suppressed() \
		and current_zone != null \
		and current_zone.is_board_zone() \
		and not is_face_down \
		and not is_stealth

func _refresh_divine_resilience() -> void:
	_clear_divine_resilience()
	if not _passives_are_active():
		return
	var controller := get_controller()
	if controller == null:
		return
	add_status_effect(
		DIVINE_RESILIENCE_STATUS,
		"Divine Resilience",
		self,
		controller,
		{"ward_kind": "creature_abilities"}
	)

func _clear_divine_resilience() -> void:
	remove_status_effects_from_source_card(self, DIVINE_RESILIENCE_STATUS)
