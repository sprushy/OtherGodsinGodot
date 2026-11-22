extends GodCard
class_name AphroditeSkotia

const ART_PATH := "res://images/card_art/gods/aphrodite_skotia.png"

func _init() -> void:
	super._init()
	card_name = "Aphrodite Skotia"
	card_types = ["Love", "Sex", "War"]
	culture = "Olympic"
	ability_text = "[b]Veil of Night[/b]: Your hidden creatures have no speed penalty and are not revealed by combat."
	art_path = ART_PATH
	name_at_bottom = true
