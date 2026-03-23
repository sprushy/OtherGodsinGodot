# BaseCard.gd
extends Card
class_name BaseCard

# Keyword definitions - displayed as hover tooltips in ability text.
const KEYWORD_HINTS = {
	"Void": "Send this card to the Abyss - removed from the game.",
	"Sleep": "This creature cannot take any actions while asleep.",
	"Shelve": "Send this card to the bottom of its owner's deck.",
	"Convert": "Move followers from the opponent to you - they switch sides.",
}

# Wraps bold keywords in [hint=...] BBCode so RichTextLabel shows tooltips.
static func apply_keyword_hints(text: String) -> String:
	var hints = {
		"Void": "Send this card to the Abyss - removed from the game.",
		"Sleep": "This creature cannot take any actions while asleep.",
		"Shelve": "Send this card to the bottom of its owner's deck.",
		"Convert": "Move followers from the opponent to you - they switch sides.",
	}
	var result := text
	for keyword in hints:
		result = result.replace("[b]" + keyword + "[/b]",
			"[hint=" + hints[keyword] + "][b]" + keyword + "[/b][/hint]")
	return result

# Common hooks all cards can use
func on_play(game_manager: GameManager, target = null) -> void:
	pass

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	return can_pay_costs(player)

func on_enter_zone(zone: Zone) -> void:
	pass

func on_leave_zone(zone: Zone) -> void:
	pass
