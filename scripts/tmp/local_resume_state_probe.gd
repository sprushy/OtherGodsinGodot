extends SceneTree

func _init() -> void:
	var store_script = load("res://scripts/client/LocalProfileStore.gd")
	if store_script == null:
		push_error("local_resume_state_probe: failed to load LocalProfileStore.gd")
		quit(1)
		return
	var store = store_script.new()
	var profile: Dictionary = store.restore_last_profile("Probe")
	var profile_id := str(profile.get("profile_id", "")).strip_edges()
	print("current_profile_id=", store.get_current_profile_id())
	print("restored_profile_id=", profile_id)
	print("restored_profile_name=", str(profile.get("display_name", "")))
	print("lobby_resume=", JSON.stringify(store.get_lobby_resume(profile_id)))
	print("active_match=", JSON.stringify(store.get_active_match(profile_id)))
	quit()
