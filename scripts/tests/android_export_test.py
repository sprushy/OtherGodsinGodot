"""Nonvisual checks for Android build preparation and update version ordering."""

import importlib.util
import os
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("android_export", ROOT / "scripts/ci/prepare_android_export.py")
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class AndroidExportTest(unittest.TestCase):
    def test_version_ordering(self):
        versions = ["0.2.331", "v0.2.331.1", "0.2.332", "0.2.9999.9", "0.3.0", "1.0.0"]
        codes = [EXPORT.version_code(version) for version in versions]
        self.assertEqual(codes, sorted(set(codes)))
        self.assertEqual(codes[0], 203310)
        self.assertEqual(EXPORT.version_code("0.3"), EXPORT.version_code("0.3.0"))

    def test_rejects_unrepresentable_versions(self):
        for version in ("dev", "0.0.0", "v0.2.331-rc1", "0.100.0", "0.2.10000", "0.2.331.10", "211.0.0"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                EXPORT.version_code(version)

    def test_preview_and_release_preserve_other_presets_and_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("project.godot", "export_presets.cfg"):
                (root / name).write_bytes((ROOT / name).read_bytes())
            java_sdk = root / "java sdk"
            android_sdk = root / "android sdk"
            suffix = ".exe" if os.name == "nt" else ""
            for executable in (java_sdk / "bin" / f"java{suffix}",
                               android_sdk / "platform-tools" / f"adb{suffix}"):
                executable.parent.mkdir(parents=True)
                executable.touch()
            (android_sdk / "build-tools").mkdir()
            settings = root / "settings/editor_settings-4.7.tres"
            original_presets = (root / "export_presets.cfg").read_text()
            non_android = original_presets.split("[preset.4]")[0]
            settings.parent.mkdir()
            settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\ninterface/editor/editor_scale=1.25\n')
            EXPORT.prepare(root, settings, java_sdk, android_sdk, "v0.2.332", preview=True)
            preview = (root / "export_presets.cfg").read_text()
            self.assertTrue(preview.startswith(non_android))
            self.assertIn('package/unique_name="com.sprushy.othergods.preview"', preview)
            self.assertIn('version/name="0.2.332-preview"', preview)
            self.assertIn('version/code=203320', preview)
            self.assertIn('config/version="v0.2.332"', (root / "project.godot").read_text())
            self.assertIn('renderer/rendering_method.mobile="gl_compatibility"', (root / "project.godot").read_text())
            self.assertIn('interface/editor/editor_scale=1.25', settings.read_text())
            self.assertIn(java_sdk.as_posix(), settings.read_text())
            EXPORT.prepare(root, settings, java_sdk, android_sdk, "v0.2.333")
            release = (root / "export_presets.cfg").read_text()
            self.assertTrue(release.startswith(non_android))
            self.assertIn('package/unique_name="com.sprushy.othergods"', release)
            self.assertNotIn('com.sprushy.othergods.preview', release)
            self.assertIn('version/name="0.2.333"', release)
            self.assertEqual(settings.read_text().count("export/android/java_sdk_path="), 1)
            self.assertNotIn("keystore", settings.read_text())

    def test_missing_sdk_does_not_modify_project(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "project.godot"
            original = (ROOT / "project.godot").read_bytes()
            project.write_bytes(original)
            with self.assertRaises(ValueError):
                EXPORT.prepare(root, root / "editor_settings.tres", root / "missing", root / "missing")
            self.assertEqual(project.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
