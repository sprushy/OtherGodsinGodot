# macOS Auto-Update

macOS release builds use the built-in bundle updater. When the shared GitHub
release check or connected server reports a newer version, the app downloads
`OtherGods-macos.zip`, verifies its SHA-256 checksum, stages the complete `.app`
with `ditto`, and checks its identifier, version, executable, and macOS signature.
Only then does the game close. A separate helper replaces the bundle in its
existing location and reopens it. If replacement or reopening fails, the helper
restores the previous app and records the reason in `update.log` and
`update_failure.txt` in the Godot user data folder.

This update path needs no Sparkle secrets. The release workflow publishes
`OtherGods-macos.zip.sha256` and checks the bundle version against the release
tag. Failed updates display the reason in the game, with retry, download-page,
and log-folder buttons. They do not silently open a browser or dismiss the
required update. Apps running from App Translocation or a read-only location
must first be moved to a writable Applications folder and reopened.

`python3 scripts/tests/macos_self_update_test.py` checks replacement, version and
signature rejection, waiting for game exit, and rollback without opening an app.
CI runs it on macOS using the native extraction and signature tools. Other hosts
substitute those tools to test the shell transaction.

## Optional Release Secrets

Tagged macOS releases can publish automatic updates without Developer ID or
Sparkle secrets; the bundle is ad-hoc signed in that case. Configure these GitHub
Actions secrets for Developer ID signing/notarization and the optional legacy
Sparkle feed:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_PRIVATE_ED_KEY`

The public and private Sparkle values must be from the same Ed25519 key pair.
`SPARKLE_PUBLIC_ED_KEY` and `SPARKLE_PRIVATE_ED_KEY` must come from the same
Ed25519 key pair. `SPARKLE_PRIVATE_ED_KEY` contains the private key file
contents accepted by Sparkle's `sign_update --ed-key-file` option. Keep this
value secret and retain a secure backup outside GitHub.

When Sparkle secrets and bridge build tooling are available, the release
workflow:

1. Downloads Sparkle and builds a universal Intel/Apple Silicon `MacSparkleBridge` GDExtension into `addons/macos_sparkle/bin/`.
2. Embeds `Sparkle.framework` and the public update key.
3. Signs and notarizes the complete app.
4. Packages `OtherGods-macos.zip`, generates `appcast.xml` plus any Sparkle delta assets, and signs them with the Sparkle private key.
5. Publishes the archive, `appcast.xml`, and generated Sparkle assets as GitHub release assets.

Tagged releases always include `OtherGods-macos.zip`. Sparkle-enabled releases
also include `appcast.xml` for older Sparkle-enabled clients. Current clients use
the built-in updater, including when no appcast is published.

Older Sparkle-enabled clients read their feed from:

`https://github.com/sprushy/OtherGodsinGodot/releases/latest/download/appcast.xml`

The compiled macOS bridge binary is intentionally not checked into git.
Sparkle-enabled releases rebuild it in CI so exported apps always ship with a
matching `libmacos_sparkle.macos.universal.dylib`.

## Bootstrap Limitation

Clients that only open a release page (including the affected v0.2.318 clients)
must install a build containing the built-in updater once from the release page.
Changing the server or release assets cannot add an installer to those existing
clients. Subsequent builds update automatically.

## Editor Version Display

Exported builds read the version stamped by CI. Editor runs resolve the nearest
release tag on their own Git checkout and display a `(debug)` suffix, falling
back to the project setting when Git or tags are unavailable. They never run
the release updater.
