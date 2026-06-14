# Windows Auto-Update

The normal Windows update path downloads the release archive into Godot's
per-user data directory, verifies its size and GitHub SHA-256 digest when
available, extracts it to staging, and launches the staged `OtherGods.exe` in
native updater mode.

If Godot's downloader cannot start, resolve DNS, negotiate TLS, or write the
download file, the app switches to Windows' signed `curl.exe` downloader. This
uses an independent networking implementation and records curl's error text
before falling back to the browser. A usable partial download is resumed by the
Windows fallback instead of discarded.

The native updater:

- writes a readiness handshake before the old game exits;
- waits for the old process to close;
- copies each file to a temporary sibling;
- verifies SHA-256 before and after replacement;
- keeps backups and rolls back a partial update;
- retries file operations that antivirus scanners may temporarily lock;
- restarts the installed executable and records failures for the next launch.

PowerShell is only used when the install directory is not writable and Windows
elevation is required.

## Code Signing

Unsigned executables are much more likely to be blocked before updater code can
run. Configure these GitHub Actions secrets with a trusted Authenticode
certificate:

- `WINDOWS_CODESIGN_CERTIFICATE_PFX_BASE64`
- `WINDOWS_CODESIGN_CERTIFICATE_PASSWORD`

The PFX value must be the complete certificate file encoded as base64. Release
CI signs both Windows executables before packaging and verifies the signatures.
If the secret is absent, CI publishes the build but emits a warning.

Godot's Windows export documentation also recommends signing exported builds:
<https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html#code-signing>

## Supporting A Failed Update

Ask the user to open:

```text
%APPDATA%\Godot\app_userdata\OtherGods
```

The failure UI in newer builds has an **Open Update Log Folder** button. Request
`update.log` and, if present, `update_failure.txt`.

Also ask for a screenshot or export from:

```text
Windows Security > Virus & threat protection > Protection history
```

For third-party antivirus, request the quarantine/event entry containing the
file path, detection name, and timestamp. Useful `update.log` milestones are:

- `download_started` / `download_completed`
- `download_preflight_ok` / `download_preflight_failed`
- `download_fallback_unavailable` / `download_fallback_failed`
- `download_hash`
- `native_updater_process_started`
- `native_updater_ready`
- `native_file_attempt_failed`
- `native_update_complete`
- `native_updater_fallback_to_powershell`
- `updater_preflight_failed`

The first release containing the native updater may still need to be installed
manually by users whose older PowerShell-based updater is already blocked.
After that bootstrap release, future updates use the native path.
