"""Configure an Android export without storing signing credentials in the repo."""

import argparse
import os
from pathlib import Path
import re


def version_code(version: str) -> int:
    """Reserve 2 digits for minor, 4 for patch, and 1 for a fourth component."""
    match = re.fullmatch(r"v?(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?", version)
    if not match:
        raise ValueError(f"Android releases require a numeric version, got {version!r}")
    major, minor, patch, revision = (int(part or 0) for part in match.groups())
    if minor > 99 or patch > 9999 or revision > 9:
        raise ValueError("Android version requires minor <= 99, patch <= 9999, revision <= 9")
    code = major * 10_000_000 + minor * 100_000 + patch * 10 + revision
    if not 1 <= code <= 2_100_000_000:
        raise ValueError("Android version code must be between 1 and 2100000000")
    return code


def quoted(value: str) -> str:
    return '"' + value.replace("\\", "/").replace('"', '\\"') + '"'


def set_setting(text: str, key: str, value: str) -> str:
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    replacement = f"{key}={value}"
    if re.search(pattern, text):
        return re.sub(pattern, lambda _: replacement, text)
    return text.rstrip() + "\n" + replacement + "\n"


def prepare(root: Path, settings: Path, java_sdk: Path, android_sdk: Path,
            version: str | None = None, preview: bool = False) -> None:
    executable_suffix = ".exe" if os.name == "nt" else ""
    for executable in (java_sdk / "bin" / f"java{executable_suffix}",
                       android_sdk / "platform-tools" / f"adb{executable_suffix}"):
        if not executable.is_file():
            raise ValueError(f"Required Android build tool is missing: {executable}")
    if not (android_sdk / "build-tools").is_dir():
        raise ValueError("Android SDK build-tools directory is missing")

    project_path = root / "project.godot"
    project = project_path.read_text(encoding="utf-8")
    if version is None:
        match = re.search(r'^config/version="([^"]+)"$', project, re.MULTILINE)
        if not match:
            raise ValueError("project.godot has no config/version")
        version = match[1]
    code = version_code(version)
    version = version.removeprefix("v")
    preset_path = root / "export_presets.cfg"
    presets = preset_path.read_text(encoding="utf-8")
    android_section = re.search(
        r'(?ms)^\[preset\.(\d+)\]\n(?:(?!^\[preset\.).)*?^name="Android"$', presets
    )
    if not android_section:
        raise ValueError("Android export preset was not found")
    index = android_section[1]
    options_pattern = rf"(?ms)(^\[preset\.{index}\.options\]\n)(.*?)(?=^\[|\Z)"
    options_match = re.search(options_pattern, presets)
    if not options_match:
        raise ValueError("Android export options were not found")
    options = options_match[2]
    options = set_setting(options, "version/code", str(code))
    options = set_setting(options, "version/name", quoted(version + ("-preview" if preview else "")))
    # A test build has a separate app identity so it cannot replace a release.
    options = set_setting(options, "package/unique_name", quoted(
        "com.sprushy.othergods.preview" if preview else "com.sprushy.othergods"))
    options = set_setting(options, "package/name", quoted("Other Gods Preview" if preview else "Other Gods"))
    presets = presets[:options_match.start(2)] + options + presets[options_match.end(2):]
    project = set_setting(project, "config/version", quoted("v" + version))
    # Godot's Android exporter checks the literal .mobile setting when deciding
    # whether to require Vulkan in the manifest. Set it for this build as well
    # as the repository's Android-specific runtime override.
    rendering = re.search(r"(?ms)(^\[rendering\]\n)(.*?)(?=^\[|\Z)", project)
    if not rendering:
        raise ValueError("project.godot has no rendering section")
    rendering_options = set_setting(rendering[2], "renderer/rendering_method.mobile", quoted("gl_compatibility"))
    project = project[:rendering.start(2)] + rendering_options + project[rendering.end(2):]

    settings_text = settings.read_text(encoding="utf-8") if settings.exists() else (
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    )
    settings_text = set_setting(settings_text, "export/android/java_sdk_path", quoted(java_sdk.resolve().as_posix()))
    settings_text = set_setting(settings_text, "export/android/android_sdk_path", quoted(android_sdk.resolve().as_posix()))
    settings.parent.mkdir(parents=True, exist_ok=True)
    settings.write_text(settings_text, encoding="utf-8")
    preset_path.write_text(presets, encoding="utf-8")
    project_path.write_text(project, encoding="utf-8")
    print(f"Android {'preview' if preview else 'release'}: {version} (version code {code})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--editor-settings", type=Path, required=True)
    parser.add_argument("--java-sdk", type=Path, required=True)
    parser.add_argument("--android-sdk", type=Path, required=True)
    parser.add_argument("--version")
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()
    prepare(args.project, args.editor_settings, args.java_sdk, args.android_sdk, args.version, args.preview)
