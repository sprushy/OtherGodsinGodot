extends RefCounted

const ReleaseInfo = preload("res://scripts/client/AppReleaseInfo.gd")
const DOWNLOAD_PATH := "user://update_download.apk"
const PENDING_PATH := "user://android_update_pending.json"

var _platform: RefCounted
var _download_path: String
var _pending_path: String

func _init(platform: RefCounted = null, download_path: String = DOWNLOAD_PATH, pending_path: String = PENDING_PATH) -> void:
	_platform = platform if platform != null else AndroidPlatform.new()
	_download_path = download_path
	_pending_path = pending_path

func pending_update() -> Dictionary:
	if not FileAccess.file_exists(_pending_path) or not FileAccess.file_exists(_download_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_pending_path))
	if not (parsed is Dictionary):
		return {}
	if not ReleaseInfo.is_release_version(str(parsed.get("version", ""))) or not _is_sha256(str(parsed.get("sha256", ""))):
		return {}
	return parsed

func has_cached_update(version: String, sha256: String) -> bool:
	var pending := pending_update()
	return not pending.is_empty() \
		and ReleaseInfo.compare_versions(str(pending.version), version) == 0 \
		and str(pending.sha256) == sha256.to_lower()

func cleanup_completed_update(current_version: String) -> void:
	if not ReleaseInfo.is_release_version(current_version):
		return
	var pending := pending_update()
	if not pending.is_empty() and ReleaseInfo.compare_versions(current_version, str(pending.version)) >= 0:
		_clear_cached_update()

func install(version: String, sha256: String, request_permission: bool = true) -> Dictionary:
	if not ReleaseInfo.is_release_version(version) or not _is_sha256(sha256):
		return _failure("The Android update is missing its release version or checksum.")
	if not FileAccess.file_exists(_download_path):
		return _failure("The downloaded Android update is missing. Retry the download.")
	if FileAccess.get_sha256(_download_path).to_lower() != sha256.to_lower():
		_clear_cached_update()
		return _failure("The Android update failed SHA-256 verification. Retry the download.")
	# Persist before opening Settings: Android may stop the app while it is away.
	var pending_file := FileAccess.open(_pending_path, FileAccess.WRITE)
	if pending_file == null:
		return _failure("Could not save the Android update state. Check free storage and retry.")
	pending_file.store_string(JSON.stringify({"version": version, "sha256": sha256.to_lower()}))
	pending_file.close()
	var permission: Dictionary = _platform.install_permission()
	if not str(permission.get("error", "")).is_empty():
		return _failure(str(permission.error))
	if not bool(permission.get("allowed", false)):
		if not request_permission:
			return {"status": "permission_denied", "message": "Allow installs from Other Gods, then tap Install update to continue."}
		var permission_error: String = _platform.request_install_permission()
		if not permission_error.is_empty():
			return _failure(permission_error)
		return {"status": "permission_required", "message": "Enable Allow from this source for Other Gods, then return here to continue the update."}
	var install_error: String = _platform.open_installer(ProjectSettings.globalize_path(_download_path))
	if not install_error.is_empty():
		return _failure(install_error)
	return {"status": "installer_opened", "message": "Confirm Update in the Android installer, then reopen Other Gods. If you cancelled, tap Install update to try again."}

func _clear_cached_update() -> void:
	for path in [_download_path, _pending_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value.to_lower():
		if not character in "0123456789abcdef":
			return false
	return true

static func _failure(message: String) -> Dictionary:
	return {"status": "error", "message": message}

class AndroidPlatform extends RefCounted:
	func install_permission() -> Dictionary:
		if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
			return {"error": "Android installation support is unavailable in this build."}
		var wrapper = Engine.get_singleton("JavaClassWrapper")
		var activity = Engine.get_singleton("AndroidRuntime").getActivity()
		if activity == null:
			return {"error": "Android could not find the current activity. Reopen Other Gods and retry."}
		var version = wrapper.wrap("android.os.Build$VERSION")
		if int(version.SDK_INT) < 26:
			return {"allowed": true}
		var package_manager = activity.getPackageManager()
		var allowed: bool = package_manager.canRequestPackageInstalls()
		var exception = wrapper.get_exception()
		if exception != null:
			return {"error": "Android could not check installation permission: %s" % str(exception)}
		return {"allowed": allowed}

	func request_install_permission() -> String:
		var wrapper = Engine.get_singleton("JavaClassWrapper")
		var activity = Engine.get_singleton("AndroidRuntime").getActivity()
		var Intent = wrapper.wrap("android.content.Intent")
		var Uri = wrapper.wrap("android.net.Uri")
		var intent = Intent.Intent()
		intent.setAction("android.settings.MANAGE_UNKNOWN_APP_SOURCES")
		intent.setData(Uri.parse("package:%s" % str(activity.getPackageName())))
		activity.startActivity(intent)
		var exception = wrapper.get_exception()
		if exception != null:
			return "Android could not open installation settings: %s" % str(exception)
		return ""

	func open_installer(path: String) -> String:
		# Godot's Android shell_open uses its FileProvider and grants read access,
		# so the installer can read the private user:// file without storage access.
		var result := OS.shell_open(path)
		if result != OK:
			return "Android could not open the update installer (%s)." % error_string(result)
		return ""
