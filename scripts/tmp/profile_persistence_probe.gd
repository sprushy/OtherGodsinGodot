extends SceneTree

func _initialize() -> void:
	var LocalProfileStoreScript = load("res://scripts/core/LocalProfileStore.gd")
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

	if not _check_offline_account_saves(MainMenuScript):
		quit(1)
		return

	print("PROFILE_PERSISTENCE_PROBE: PASS")
	quit()

func _check_offline_account_saves(main_menu_script: GDScript) -> bool:
	var store := LocalProfileStore.new()
	var profile := store.activate_account_session("offline-deck-probe@example.com")
	var profile_id := str(profile["profile_id"])
	const EXISTING_DECK_ID := "offline_deck_probe"
	var server_store := DeckStore.new()
	var original: Dictionary = server_store.save_deck(profile_id, "Original", {"Baldr": 1}, EXISTING_DECK_ID)["deck"]
	store.upsert_saved_decks(profile_id, [original])
	store.mark_account_decks_synced(profile_id, [EXISTING_DECK_ID])
	var new_deck := store.save_deck(profile_id, "New offline deck", {"Thor": 1})
	var edited_deck := store.save_deck(profile_id, "Edited offline", {"Baldr": 1}, EXISTING_DECK_ID, {}, {"Huginn": 2})

	var reopened := LocalProfileStore.new()
	reopened.upsert_saved_decks(profile_id, [original])
	var pending := reopened.get_pending_account_deck_saves(profile_id)
	if not pending.has(str(new_deck.get("deck_id", ""))) or not pending.has(EXISTING_DECK_ID):
		push_error("PROFILE_PERSISTENCE_PROBE: pending account saves did not survive restart and a stale server list")
		return false
	var remote_decks: Array[Dictionary] = [original]
	var catalog: Dictionary = main_menu_script._merge_account_deck_catalogs(
		remote_decks,
		reopened.list_decks(profile_id),
		{EXISTING_DECK_ID: true},
		{},
		pending
	)
	if catalog["decks_to_upload"].size() != 2 or catalog["visible_decks"][0]["name"] != edited_deck["name"]:
		push_error("PROFILE_PERSISTENCE_PROBE: catalog did not retain and queue the offline decks")
		return false

	var confirmation: Dictionary = server_store.save_deck(
		profile_id, edited_deck["name"], edited_deck["cards"], EXISTING_DECK_ID,
		edited_deck["special_setup"], edited_deck["reinforcements"]
	)["deck"]
	var latest := reopened.save_deck(profile_id, "Edited offline", {"Baldr": 1}, EXISTING_DECK_ID, {}, {"Huginn": 3})
	if reopened.upsert_saved_decks(profile_id, [confirmation], false, true) != 0:
		push_error("PROFILE_PERSISTENCE_PROBE: an old acknowledgement replaced a newer offline edit")
		return false
	confirmation = server_store.save_deck(
		profile_id, latest["name"], latest["cards"], EXISTING_DECK_ID,
		latest["special_setup"], latest["reinforcements"]
	)["deck"]
	if reopened.upsert_saved_decks(profile_id, [confirmation]) != 0:
		push_error("PROFILE_PERSISTENCE_PROBE: a matching list entry cleared an unconfirmed save")
		return false
	reopened.upsert_saved_decks(profile_id, [confirmation], false, true)
	var confirmed_store := LocalProfileStore.new()
	if confirmed_store.get_pending_account_deck_saves(profile_id).has(EXISTING_DECK_ID):
		push_error("PROFILE_PERSISTENCE_PROBE: the matching acknowledgement did not clear the pending save")
		return false
	return true
