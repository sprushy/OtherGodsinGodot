# Android / Chromebook release

The `Android` Godot export preset produces an APK for ARM64 Android devices
and x86_64 Chromebooks. Android uses the Compatibility renderer and sensor
landscape orientation. Desktop renderer settings are unchanged. Internet
permission is enabled for lobby, matches, and release checks. Android apps
require a Chromebook with Android app support; managed devices may restrict
installation.

## First test build

Manually run **Desktop Release**, leaving `include_android` checked. Without
Android signing secrets, the `export-android` job uploads
`OtherGods-android-preview.apk` and its SHA-256 checksum as workflow artifacts.
This is an installable debug build, with the separate application ID
`com.sprushy.othergods.preview`. Preview APKs are not attached to public
releases. A new CI run generates a new preview signing key, so uninstall an
older CI preview before installing another (uninstalling removes its local
data). Local previews can reuse the same debug key.

On an Android phone/tablet, download the APK and allow installation from that
source when Android prompts. On a Chromebook, use Android debugging / ADB
where supported; downloading an APK alone does not enable installation.
For ordinary Chromebook users, Google Play distribution is the eventual path.

## Release signing

Create a permanent release keystore with Java's `keytool`, or reuse the
existing Android signing key if this application has already been distributed:

```powershell
keytool -genkeypair -v -keystore othergods-release.keystore -alias othergods -keyalg RSA -keysize 2048 -validity 10000
```

Use the same password for the keystore and key, as required by Godot. Keep
the key and password backed up outside the repository: future APK updates
must use the same signing key. Keystores and Godot's export credentials file
are gitignored, and Android exports exclude keystores and build directories.

Configure these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64`: Base64 of the release keystore file.
- `ANDROID_KEY_ALIAS`: signing alias (for example `othergods`).
- `ANDROID_KEYSTORE_PASSWORD`: password shared by the keystore and key.

With all three secrets configured, tag releases and manual Android builds
produce `OtherGods-android.apk` and its checksum. Tagged releases attach these
next to Windows/macOS assets. Incomplete signing configuration fails the Android
job; missing configuration produces a preview artifact instead. Android failure
does not block the existing desktop release, and the release summary reports
when no signed Android asset was produced.

CI uses the Godot version in `.godot-version`, Java 17 and Android build-tools
36.1.0. It verifies APK signatures and alignment before uploading artifacts.
Signing credentials are supplied through Godot environment variables and the
runner's temporary keystore, never committed export settings.

## Local export

Install matching Godot export templates, Java 17, and the Android SDK with
`platform-tools` and `build-tools;36.1.0`. Configure the Java SDK Path and
Android SDK Path in Godot's editor settings. For a release, set the following
environment variables before exporting:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`: absolute keystore path.
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`: alias.
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`: password.

```powershell
godot --headless --path . --export-release "Android" .exports/android/OtherGods-android.apk
```

For CI or scripted local exports, `scripts/ci/prepare_android_export.py`
configures SDK paths in the specified editor settings file, stamps the
Android preset and project version, and sets the mobile renderer to Compatibility
for the Android manifest/export. Run it in a disposable project copy when
building alongside other platforms. `--preview` also changes the Android app ID.
Other presets remain unchanged. Example:

```powershell
python scripts/ci/prepare_android_export.py --editor-settings "$env:APPDATA/Godot/editor_settings-4.7.tres" --java-sdk "$env:JAVA_HOME" --android-sdk "$env:ANDROID_HOME" --version v0.2.331
```

Version codes preserve numeric release ordering with
`major * 10000000 + minor * 100000 + patch * 10 + revision`.
For example, `0.2.331` becomes `203310`. Minor is limited to 99, patch to 9999,
and an optional fourth component to 9; invalid or overflowing versions fail
before export. When exporting manually through the editor, increase
`version/code` before distributing an update, or run the preparation script.

## Device checks before public distribution

Build/signature validation does not prove device compatibility. Manually check
startup, sign-in, practice, deck building, an online match, background/resume,
landscape rotation and Chromebook window resizing. Check touch controls and
card details as well as mouse/trackpad input; the current game has desktop
hover interactions and a 1920x1080 layout, so phone usability is unverified.
No visual QA or device UI automation is part of the build workflow.

This first pipeline builds APKs for direct testing/distribution. Google Play
publication is a separate step requiring an Android App Bundle (AAB), a Gradle
export and the Play Console listing/testing requirements. The APK workflow
does not publish to Google Play or implement Android self-installing updates;
the existing update check opens the GitHub release page.

References: [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html),
[ChromeOS Android apps](https://developer.android.com/chrome-os),
[Chromebook ADB testing](https://developers.google.com/chromeos/app-development/develop/deploying-apps).
