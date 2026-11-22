"""Exercise the updater transaction without opening any app or browser.

macOS uses real ditto, PlistBuddy, and codesign. Other hosts substitute those
three tools; filesystem moves, process waiting, and rollback still run in sh.
"""
import os
import pathlib
import plistlib
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
SHELL = shutil.which("sh") or shutil.which("bash")
if not SHELL and os.name == "nt":
    SHELL = "C:/Program Files/Git/bin/bash.exe"

FAKE_TOOLS = r'''
import os, pathlib, plistlib, shutil, sys, zipfile
tool, *args = sys.argv[1:]
if os.name == 'nt':
    args = [p[1] + ':' + p[2:] if len(p) > 2 and p[0] == '/' and p[2] == '/' else p for p in args]
if tool == 'ditto':
    with zipfile.ZipFile(args[-2]) as archive:
        archive.extractall(args[-1])
        for entry in archive.infolist():
            os.chmod(pathlib.Path(args[-1]) / entry.filename, entry.external_attr >> 16)
elif tool == 'plist':
    with open(args[-1], 'rb') as f:
        print(plistlib.load(f)[args[1].split(':')[-1]])
elif tool == 'codesign':
    sys.exit(1 if (pathlib.Path(args[-1]) / 'invalid-signature').exists() else 0)
elif tool == 'open':
    with open(os.environ['UPDATE_TEST_OPEN_LOG'], 'a') as f:
        f.write(args[-1] + '\n')
    if os.environ.get('UPDATE_TEST_FAIL_OPEN') and not pathlib.Path(args[-1], 'old-version').exists():
        sys.exit(1)
elif tool == 'mv':
    if os.environ.get('UPDATE_TEST_FAIL_MOVE') and 'unpacked' in args[0]:
        sys.exit(1)
    if os.environ.get('UPDATE_TEST_FAIL_RESTORE') and args[0].endswith('previous.app'):
        sys.exit(1)
    shutil.move(args[0], args[1])
'''

def shell_path(path):
    value = path.as_posix()
    return "/" + value[0].lower() + value[2:] if os.name == "nt" else value


class MacOSUpdaterTest(unittest.TestCase):
    def setUp(self):
        # All destructive operations are confined to this resolved fixture root.
        self.temp = tempfile.TemporaryDirectory(prefix="othergods-update-test-")
        self.root = pathlib.Path(self.temp.name).resolve()
        self.target = self.root / "Games with spaces" / "Player's Other Gods.app"
        self.target.mkdir(parents=True)
        self.make_app(self.target, "0.2.318")
        (self.target / "old-version").touch()
        self.new_app = self.root / "release" / "OtherGods.app"
        self.new_app.mkdir(parents=True)
        self.make_app(self.new_app, "0.2.325")
        self.status = self.root / "status"
        self.failure = self.root / "failure"
        self.log = self.root / "update.log"
        self.open_log = self.root / "open.log"
        self.env = dict(os.environ, UPDATE_TEST_OPEN_LOG=str(self.open_log))
        source = (ROOT / "scripts/client/macos_self_update.sh").read_text()
        tools = self.root / "tools"
        tools.mkdir()
        helper = tools / "tools.py"
        helper.write_text(FAKE_TOOLS)
        for command, tool in (("/usr/bin/ditto", "ditto"),
                              ("/usr/libexec/PlistBuddy", "plist"),
                              ("/usr/bin/codesign", "codesign"),
                              ("/usr/bin/open", "open"), ("mv", "mv")):
            wrapper = tools / tool
            wrapper.write_text("#!/bin/sh\nexec " + " ".join(map(shlex.quote, [sys.executable.replace('\\', '/'), helper.as_posix(), tool])) + ' "$@"\n')
            wrapper.chmod(0o755)
            if command == "mv":
                # Also inject replacement failure on macOS without changing the
                # script's transaction logic or touching an actual installation.
                source = source.replace('mv "', shlex.quote(wrapper.as_posix()) + ' "')
            elif sys.platform != "darwin" or tool == "open":
                source = source.replace(command, shlex.quote(wrapper.as_posix()))
        self.script = self.root / "updater.sh"
        self.script.write_text(source, newline="\n")

    def tearDown(self):
        self.temp.cleanup()

    def make_app(self, path, version):
        (path / "Contents/MacOS").mkdir(parents=True, exist_ok=True)
        executable = path / "Contents/MacOS/OtherGods"
        if sys.platform == "darwin":
            subprocess.run(["clang", "-x", "c", "-", "-o", str(executable)], input="int main(void) { return 0; }", text=True, check=True, capture_output=True)
        else:
            executable.write_text("#!/bin/sh\nexit 0\n", newline="\n")
        executable.chmod(0o755)
        with (path / "Contents/Info.plist").open("wb") as f:
            plistlib.dump({"CFBundleIdentifier": "com.sprushy.othergods", "CFBundleShortVersionString": version,
                          "CFBundleVersion": version, "CFBundleExecutable": "OtherGods", "CFBundlePackageType": "APPL"}, f)

    def start_update(self, wait_pid="99999999"):
        if sys.platform == "darwin" and not (self.new_app / "invalid-signature").exists():
            subprocess.run(["codesign", "--force", "--sign", "-", str(self.new_app)], check=True, capture_output=True)
        archive = self.root / "update.zip"
        if sys.platform == "darwin":
            subprocess.run(["ditto", "-c", "-k", "--keepParent", str(self.new_app), str(archive)], check=True)
        else:
            with zipfile.ZipFile(archive, "w") as z:
                for path in self.new_app.rglob("*"):
                    if path.is_file():
                        z.write(path, path.relative_to(self.new_app.parent).as_posix())
        process = subprocess.Popen([SHELL, shell_path(self.script), shell_path(archive), shell_path(self.target),
                                    "v0.2.325", wait_pid, shell_path(self.status), shell_path(self.failure), shell_path(self.log)], env=self.env)
        self.addCleanup(self.stop_process, process)
        return process

    @staticmethod
    def stop_process(process):
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=5)

    def assert_old_app(self):
        self.assertTrue((self.target / "old-version").exists(), self.log.read_text())

    def test_install_replaces_whole_bundle_and_restarts(self):
        process = self.start_update()
        self.assertEqual(process.wait(timeout=20), 0, self.log.read_text())
        self.assertFalse((self.target / "old-version").exists())
        self.assertTrue((self.target / "Contents/MacOS/OtherGods").exists())
        self.assertTrue(self.open_log.exists())
        self.assertFalse(self.failure.exists())
        self.assertFalse(list(self.target.parent.glob(".othergods-update.*")))

    def test_wrong_version_keeps_existing_app(self):
        self.make_app(self.new_app, "0.2.318")
        process = self.start_update()
        self.assertNotEqual(process.wait(timeout=20), 0)
        self.assert_old_app()
        self.assertIn("version does not match", self.failure.read_text())
        self.assertFalse(self.open_log.exists())

    def test_invalid_signature_keeps_existing_app(self):
        (self.new_app / "invalid-signature").touch()
        process = self.start_update()
        self.assertNotEqual(process.wait(timeout=20), 0)
        self.assert_old_app()
        self.assertIn("signature verification", self.failure.read_text())

    def test_failed_replacement_restores_previous_app(self):
        self.env["UPDATE_TEST_FAIL_MOVE"] = "1"
        process = self.start_update()
        self.assertNotEqual(process.wait(timeout=20), 0)
        self.assert_old_app()
        self.assertTrue(self.open_log.exists())
        self.assertIn("Could not install", self.failure.read_text())

    def test_failed_restart_restores_previous_app(self):
        self.env["UPDATE_TEST_FAIL_OPEN"] = "1"
        process = self.start_update()
        self.assertNotEqual(process.wait(timeout=20), 0)
        self.assert_old_app()
        self.assertEqual(len(self.open_log.read_text().splitlines()), 2)
        self.assertIn("Restored the previous version", self.failure.read_text())

    def test_failed_restore_preserves_backup(self):
        self.env["UPDATE_TEST_FAIL_MOVE"] = "1"
        self.env["UPDATE_TEST_FAIL_RESTORE"] = "1"
        process = self.start_update()
        self.assertNotEqual(process.wait(timeout=20), 0)
        backups = list(self.target.parent.glob(".othergods-update.*/previous.app/old-version"))
        self.assertEqual(len(backups), 1)
        self.assertIn("previous app is saved", self.failure.read_text())

    def test_waits_for_game_exit_before_replacing(self):
        pid_path = self.root / "game.pid"
        stop_path = self.root / "game.stop"
        game = subprocess.Popen([SHELL, "-c", 'echo $$ > "$1"; while [ ! -f "$2" ]; do sleep 0.1; done',
                                 "sh", shell_path(pid_path), shell_path(stop_path)])
        deadline = time.monotonic() + 5
        while not pid_path.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        process = self.start_update(pid_path.read_text().strip())
        try:
            deadline = time.monotonic() + 15
            while not self.status.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertEqual(self.status.read_text().strip(), "ready")
            self.assertIsNone(process.poll())
            self.assert_old_app()
        finally:
            stop_path.touch()
            game.wait(timeout=5)
        self.assertEqual(process.wait(timeout=20), 0, self.log.read_text())


if __name__ == "__main__":
    unittest.main()
