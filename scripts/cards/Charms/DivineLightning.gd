extends CharmCard
class_name DivineLightning

const ART_PATH := "res://images/card_art/charms/DivineLightningAIEdit.png"

func _init() -> void:
	super._init()
	card_name = "Divine Lightning"
	culture = "Neutral"
	card_types = ["Charm", "Magic Destruction", "Lightning"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 2
	mana_cost = 0
	speed = 2
	is_legendary = false
	targets = true
	flavor_text = ""
	ability_text = "Destroy a magical card on the field."
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null:
		return valid_targets
	for player in [game_manager.current_player, game_manager.other_player]:
		if player == null:
			continue
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if is_valid_target(card):
					valid_targets.append(card)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.is_magical_card()

func resolve(game_manager: GameManager, target = null) -> void:
	if not is_valid_target(target):
		print(card_name + " requires a magical card on the field.")
		return
	if game_manager == null:
		return
	var viewer := game_manager.get_feedback_viewer()
	var target_name = target.get_target_log_display_name(viewer)
	print(card_name + " destroys " + target.card_name + "!")
	game_manager.request_send_to_graveyard(target, func() -> void:
		if game_manager.reached_public_destroyed_destination(target):
			var destroyed_name := game_manager.get_resolved_destruction_log_name(target, viewer, target_name)
			game_manager.note_player_feedback(card_name + " destroyed " + destroyed_name + "!")
		else:
			game_manager.note_player_feedback(card_name + " failed to destroy " + target_name + ".")
	, false, true)
