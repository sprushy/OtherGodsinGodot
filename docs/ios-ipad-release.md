# iPad / iOS Release Flow

The Desktop Release workflow builds iPad/iOS assets only when explicitly
requested. Tag releases build Windows and macOS by default. To include an
**unsigned iOS IPA** (`OtherGods-ios-unsigned.ipa`), manually dispatch the
workflow on the desired release tag with `include_ios` set to `true`.
Leaving this option unchecked skips the iOS job. iPadOS refuses to run
unsigned apps, so the final signing happens on a Windows PC with a free Apple
ID via Sideloadly (or AltStore). No Mac and no paid Apple Developer account is
needed anywhere in this flow.

## What CI produces

- Release asset `OtherGods-ios-unsigned.ipa` (plus `.sha256`) — the game
  packaged as an iOS app, ready to be re-signed by a sideloading tool.

## Install on an iPad with Sideloadly (Windows)

1. Install [Sideloadly](https://sideloadly.io) on the PC. It needs iTunes from
   Apple's website (not the Microsoft Store version) for the USB drivers.
2. Download `OtherGods-ios-unsigned.ipa` from the release, connect the iPad
   over USB, and trust the computer on the iPad when prompted.
3. In Sideloadly: drag the IPA in, enter your Apple ID, press Start, then
   approve the two-factor prompt when it appears.
4. On the iPad: Settings → General → VPN & Device Management → tap your Apple
   ID under Developer App → **Trust**.
5. Launch Other Gods from the home screen.

Free Apple ID limits:

- The signature expires after **7 days**; re-sideload the same IPA to refresh
  it (save data survives).
- At most 3 sideloaded apps and 10 new app IDs per week per free account.
- AltStore (with AltServer running on the PC) is an alternative that can
  refresh the 7-day signature automatically while the iPad is on the same
  network.

## How CI builds it

The `export-ios` job runs on a macOS runner (Apple's toolchain only exists
there; nobody touches it manually):

1. Godot exports the Xcode project from the `iOS` preset. A placeholder App
   Store Team ID is stamped first because Godot refuses an export with an
   empty team ID; the value is irrelevant here.
2. `xcodebuild` assembles the `.app` with code signing disabled
   (`CODE_SIGNING_ALLOWED=NO`), which is then zipped into the unsigned IPA.
3. The IPA is attached to the GitHub release next to the Windows/macOS assets.

If a paid Apple Developer Program membership is ever added, this job is where
a signed IPA / TestFlight upload would slot in; the Xcode project export stays
available via the preset's `application/export_project_only` option.

## Configuration notes

- **Device family:** universal (`application/targeted_device_family=2`, i.e.
  "iPhone & iPad"). Switch to `1` (iPad only) if the 1920x1080 UI proves too
  cramped on phones.
- **Orientation:** engine default (landscape), which suits the board layout.
- **Icon:** `images/export_icons/nergal_lion_export_1024.png` is currently
  upscaled from the 256px export icon onto an opaque background (iOS icons
  must be square and opaque). Replace it with native 1024x1024 art when
  available.
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
- **Versions:** Info.plist versions come from `config/version` and the
  preset's `application/short_version`/`application/version`, which CI stamps
  from the release tag.
- **Textures:** `rendering/textures/vram_compression/import_etc2_astc` is
  already enabled, so no extra texture work is needed for iOS.
