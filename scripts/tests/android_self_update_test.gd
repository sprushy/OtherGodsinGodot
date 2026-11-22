extends SceneTree

const AndroidUpdater = preload("res://scripts/client/AndroidSelfUpdater.gd")
const ReleaseInfo = preload("res://scripts/client/AppReleaseInfo.gd")

class FakePlatform extends RefCounted:
	var allowed := false
	var permission_requests := 0
	var installer_requests := 0
	var installer_error := ""

	func install_permission() -> Dictionary:
		return {"allowed": allowed}

	func request_install_permission() -> String:
		permission_requests += 1
		return ""

	func open_installer(_path: String) -> String:
		installer_requests += 1
		return installer_error

func _init() -> void:
	assert(ReleaseInfo.get_asset_names_for_platform("Android") == ["OtherGods-android.apk"])
	assert(ReleaseInfo.get_asset_names_for_platform("iOS").is_empty())
	var prefix := "user://android-updater-test-%d" % OS.get_process_id()
	var apk_path := prefix + ".apk"
	var pending_path := prefix + ".json"
	var file := FileAccess.open(apk_path, FileAccess.WRITE)
	file.store_string("a verified test download; never sent to a real installer")
	file.close()
	var sha256 := FileAccess.get_sha256(apk_path)
	var platform := FakePlatform.new()
	var updater = AndroidUpdater.new(platform, apk_path, pending_path)
	assert(updater.install("v0.2.332", "bad").status == "error")
	assert(platform.permission_requests == 0)
	assert(updater.install("v0.2.332", sha256).status == "permission_required")
	assert(platform.permission_requests == 1)
	assert(platform.installer_requests == 0)
	assert(updater.has_cached_update("v0.2.332", sha256))
	assert(not updater.has_cached_update("v0.2.333", sha256))
	assert(updater.install("v0.2.332", sha256, false).status == "permission_denied")
	assert(platform.permission_requests == 1)
	# Reopening the game after Android Settings reuses the verified download.
	var reopened = AndroidUpdater.new(platform, apk_path, pending_path)
	assert(reopened.has_cached_update("v0.2.332", sha256))
	platform.allowed = true
	assert(reopened.install("v0.2.332", sha256, false).status == "installer_opened")
	assert(platform.installer_requests == 1)
	platform.installer_error = "Installer unavailable"
	assert(reopened.install("v0.2.332", sha256).status == "error")
	assert(reopened.has_cached_update("v0.2.332", sha256))
	reopened.cleanup_completed_update("dev")
	assert(FileAccess.file_exists(apk_path))
	reopened.cleanup_completed_update("v0.2.331")
	assert(FileAccess.file_exists(apk_path))
	reopened.cleanup_completed_update("v0.2.332")
	assert(not FileAccess.file_exists(apk_path))
	assert(not FileAccess.file_exists(pending_path))
	# A changed download must never reach the installer, including after resume.
	file = FileAccess.open(apk_path, FileAccess.WRITE)
	file.store_string("modified content")
	file.close()
	assert(reopened.install("v0.2.333", sha256).status == "error")
	assert(platform.installer_requests == 2)
	assert(not FileAccess.file_exists(apk_path))
	assert(reopened.pending_update().is_empty())
	print("PASS: Android release selection, permission/resume, installer errors, integrity and cleanup")
	quit()
