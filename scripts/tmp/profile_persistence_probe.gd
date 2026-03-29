extends SceneTree

func _initialize() -> void:
	var LocalProfileStoreScript = load("res://scripts/client/LocalProfileStore.gd")
	var ProfileStoreScript = load("res://scripts/server/ProfileStore.gd")
	var DeckBuilderUIScript = load("res://scripts/ui/DeckBuilderUI.gd")
	var MainMenuScript = load("res://scripts/Other/MainMenu.gd")
	if LocalProfileStoreScript == null or ProfileStoreScript == null or DeckBuilderUIScript == null or MainMenuScript == null:
		push_error("PROFILE_PERSISTENCE_PROBE: failed to load one or more scripts")
		quit(1)
		return

	var local_store = LocalProfileStoreScript.new()
	var local_profile: Dictionary = local_store.restore_last_profile("ProbeUser")
	if str(local_profile.get("profile_id", "")).strip_edges().is_empty():
		push_error("PROFILE_PERSISTENCE_PROBE: missing local profile id")
		quit(1)
		return

	var saved_deck: Dictionary = local_store.save_deck(
		str(local_profile.get("profile_id", "")),
		"Probe Deck",
		{"Baldr": 1, "BlessedKnights": 3}
	)
	if str(saved_deck.get("deck_id", "")).strip_edges().is_empty():
		push_error("PROFILE_PERSISTENCE_PROBE: missing saved deck id")
		quit(1)
		return

	var restored_decks: Array = local_store.list_decks(str(local_profile.get("profile_id", "")))
	if restored_decks.is_empty():
		push_error("PROFILE_PERSISTENCE_PROBE: no decks restored for local profile")
		quit(1)
		return

	var server_store = ProfileStoreScript.new()
	var server_profile: Dictionary = server_store.login_profile(str(local_profile.get("profile_id", "")), "ProbeUser")
	if str(server_profile.get("profile_id", "")).strip_edges().is_empty():
		push_error("PROFILE_PERSISTENCE_PROBE: missing server profile id")
		quit(1)
		return

	print("PROFILE_PERSISTENCE_PROBE: PASS")
	quit()
