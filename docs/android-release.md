# Android / Chromebook release

The `Android` Godot export preset produces an APK for ARM64 Android devices
and x86_64 Chromebooks. Android uses the Compatibility renderer and sensor
landscape orientation. Desktop renderer settings are unchanged. Internet
permission is enabled for lobby, matches, and release checks. Android apps
require a Chromebook with Android app support; managed devices may restrict
installation.

## First test build

For an Android-only build, enable `android_only` in **Desktop Release** and
leave `include_android` checked. `android_version` can specify a numeric
version for a manual build; tagged releases always use the release tag.

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

## Automatic updates

Release APKs check GitHub releases at startup and when the lobby requires a
newer client. They download `OtherGods-android.apk` inside the app with progress,
verify its size and SHA-256 checksum, then open Android's installer. A desktop
release without an Android APK does not trigger an Android update download.

On Android 8 and later, the first update asks the player to enable **Allow from
this source** for Other Gods. Returning from Settings continues installation;
Android still requires the player to confirm **Update**. Reopen Other Gods
after installation. Cancelling or denying permission keeps the verified APK
for **Install update** to retry without downloading it again. Cached APKs are
reverified before use and removed once the installed version reaches the update.
Local decks/settings survive an update using the same app ID and signing key.

This uses Godot's built-in Android runtime and FileProvider; no custom Android
plugin, Gradle build or broad storage permission is required. The APK declares
`REQUEST_INSTALL_PACKAGES` for this GitHub distribution flow. CI must use the
same permanent signing key as previously installed release APKs. An old APK
without the updater needs one manual/USB update to gain this feature.

Google Play publication remains a separate step requiring an Android App
Bundle (AAB), a Gradle export and the Play Console listing/testing requirements.
A future Play build should use Play's update mechanism instead of this
sideload updater and omit `REQUEST_INSTALL_PACKAGES`.

References: [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html),
[ChromeOS Android apps](https://developer.android.com/chrome-os),
[Chromebook ADB testing](https://developers.google.com/chromeos/app-development/develop/deploying-apps).
