extends SceneTree

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var card_script = load("res://scripts/cards/Creatures/FourthSageEnmegalamma.gd")
	_assert_state(card_script != null, "Smoke probe failed to load Fourth Sage Enmegalamma.")
	var card = card_script.new()
	_assert_state(card.card_name == "Fourth Sage Enmegalamma", "Smoke probe failed to instantiate Fourth Sage Enmegalamma.")
	_assert_state(card.resilience == 15, "Smoke probe expected Fourth Sage Enmegalamma to have 15 resilience.")
	_assert_state(card.strength == 15, "Smoke probe expected Fourth Sage Enmegalamma to have 15 strength.")
	print("fourth_sage_enmegalamma_smoke_probe: PASS")
	quit()
