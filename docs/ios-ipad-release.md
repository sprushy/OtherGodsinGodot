# iPad / iOS Release Flow

The Desktop Release workflow (`.github/workflows/windows-release.yml`) exports an
**unsigned Xcode project** for iOS on every tag release, next to the Windows and
macOS assets. Apple requires the final IPA to be signed from Xcode on a Mac, so
CI stops at the project and the signing/archiving step stays manual.

## What CI produces

- Release asset `OtherGods-ios-xcode.zip` (plus `.sha256`) containing
  `OtherGods.xcodeproj`, an Xcode project with the game PCK embedded.

## Prerequisites

- A Mac with Xcode and an Apple Developer account for device/TestFlight builds.
- Optional but recommended: the repo secret `APPLE_TEAM_ID` holding the
  10-character App Store Team ID (the same ID macOS notarization uses). When
  set, the workflow stamps it into the exported Xcode project so the right team
  is pre-selected. When it is missing, CI stamps a placeholder (`AAAAAAAAAA`)
  instead — Godot refuses to export with an empty team ID — and you select the
  real team in Xcode under Signing & Capabilities before building.

## Build and run on an iPad

1. Download `OtherGods-ios-xcode.zip` from the release and unzip it.
2. Open `OtherGods.xcodeproj` in Xcode.
3. Select the target → **Signing & Capabilities**: the team should already be
   filled in from CI. Keep "Automatically manage signing" enabled; Xcode
   registers the App ID `com.sprushy.othergods` on first run.
4. Connect the iPad, pick it as the run destination, press **Run**. On the
   iPad, trust the developer profile under Settings → General → VPN & Device
   Management.
5. For TestFlight / App Store: **Product → Archive**, then **Distribute App**
   from the Organizer.

## Exporting from the editor instead

The `iOS` preset in `export_presets.cfg` can also be exported manually
(Project → Export). Notes:

- The export errors out while `application/app_store_team_id` is empty — fill
  it in once in the preset UI.
- `application/export_project_only` is `true`, so export stops after generating
  the Xcode project. Turn it off only on a Mac with signing configured if you
  want Godot to drive `xcodebuild` all the way to an IPA.

## Configuration notes

- **Device family:** universal (`application/targeted_device_family=2`, i.e.
  "iPhone & iPad"). Switch to `1` (iPad only) if the 1920x1080 UI proves too
  cramped on phones.
- **Orientation:** engine default (landscape), which suits the board layout.
- **Icon:** `images/export_icons/nergal_lion_export_1024.png` is currently
  upscaled from the 256px export icon onto an opaque background (iOS icons must
  be square and opaque). Replace it with native 1024x1024 art when available.
- **Renderer:** the project's Forward+ renderer runs via Metal on iOS. If
  battery, heat, or older-device support becomes an issue, switching to the
  Mobile or Compatibility renderer is the lever, at the cost of 3D background
  fidelity.
- **Input:** touches emulate mouse input, so taps work everywhere, but
  hover-only affordances (e.g. card detail on hover) have no touch equivalent
  yet.
- **Layout:** the 4:3 iPad aspect is untested on hardware; the
  `canvas_items`/`expand` stretch should adapt, but verify edge-anchored UI on
  a real device.
- **Versions:** Info.plist versions come from `config/version` and the preset's
  `application/short_version`/`application/version`, which CI stamps from the
  release tag.
- **Textures:** `rendering/textures/vram_compression/import_etc2_astc` is
  already enabled, so no extra texture work is needed for iOS.
