extends RefCounted
class_name AppReleaseInfo

const VERSION_PROJECT_SETTING := "application/config/version"
const UNKNOWN_VERSION := "dev"
const RELEASES_API_URL := "https://api.github.com/repos/sprushy/OtherGodsinGodot/releases/latest"
const RELEASES_PAGE_URL := "https://github.com/sprushy/OtherGodsinGodot/releases/latest"
const WINDOWS_ASSET_NAME := "OtherGods-windows.zip"
const LEGACY_WINDOWS_ASSET_NAME := "ClaudeOtherGods-windows.zip"
const WINDOWS_ASSET_NAMES = [
	WINDOWS_ASSET_NAME,
	LEGACY_WINDOWS_ASSET_NAME,
]
const PREFERRED_WINDOWS_EXECUTABLE_NAME := "OtherGods.exe"

static func get_current_version() -> String:
	return normalize_version(str(ProjectSettings.get_setting(VERSION_PROJECT_SETTING, UNKNOWN_VERSION)))

static func normalize_version(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized.is_empty():
		return ""
	if normalized.begins_with("refs/tags/"):
		normalized = normalized.trim_prefix("refs/tags/")
	if normalized.to_lower() == UNKNOWN_VERSION:
		return UNKNOWN_VERSION
	if not normalized.begins_with("v") and _looks_like_numeric_version(normalized):
		return "v%s" % normalized
	return normalized

static func is_release_version(value: String) -> bool:
	return not parse_semver(value).is_empty()

static func compare_versions(left: String, right: String) -> int:
	var left_parts := parse_semver(left)
	var right_parts := parse_semver(right)
	if left_parts.is_empty() or right_parts.is_empty():
		return 0
	var max_size := maxi(left_parts.size(), right_parts.size())
	for index in range(max_size):
		var left_value := left_parts[index] if index < left_parts.size() else 0
		var right_value := right_parts[index] if index < right_parts.size() else 0
		if left_value == right_value:
			continue
		return -1 if left_value < right_value else 1
	return 0

static func parse_semver(value: String) -> Array[int]:
	var normalized := normalize_version(value)
	if normalized.is_empty() or normalized == UNKNOWN_VERSION:
		return []
	if normalized.begins_with("v"):
		normalized = normalized.substr(1)
	var prerelease_index := normalized.find("-")
	if prerelease_index >= 0:
		normalized = normalized.substr(0, prerelease_index)
	var build_index := normalized.find("+")
	if build_index >= 0:
		normalized = normalized.substr(0, build_index)
	var parts := normalized.split(".")
	if parts.is_empty():
		return []
	var parsed: Array[int] = []
	for part in parts:
		if not _is_numeric(part):
			return []
		parsed.append(part.to_int())
	return parsed

static func _looks_like_numeric_version(value: String) -> bool:
	return value.find(".") >= 0 and _is_numeric_version_string(value)

static func _is_numeric_version_string(value: String) -> bool:
	var parts := value.split(".")
	if parts.is_empty():
		return false
	for part in parts:
		if not _is_numeric(part):
			return false
	return true

static func _is_numeric(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true
