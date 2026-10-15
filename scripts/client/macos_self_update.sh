#!/bin/sh
# Run independently of Godot so the complete signed bundle can be replaced.
set -eu
archive=$1
target=$2
version=${3#v}
wait_pid=$4
status=$5
failure=$6
log=$7
exec >>"$log" 2>&1
trap '' HUP
work=''
closed=false
backed_up=false
installed=false

cleanup() {
    if [ -n "$work" ]; then
        rm -rf "$work"
    fi
}
trap cleanup EXIT

fail() {
    message=$1
    echo "macos_update_failed: $message"
    if [ "$installed" = true ]; then
        if ! mv "$target" "$work/rejected.app"; then
            printf '%s\n' "Update failed. The previous app is saved at $work/previous.app." > "$failure"
            work=''
            exit 1
        fi
    fi
    if [ "$backed_up" = true ]; then
        # Keep the backup if restoring it fails; never delete the only good app.
        if ! mv "$work/previous.app" "$target"; then
            printf '%s\n' "Update failed. The previous app is saved at $work/previous.app." > "$failure"
            work=''
            exit 1
        fi
    fi
    printf '%s\n' "$message" > "$failure"
    printf 'error:%s\n' "$message" > "$status"
    if [ "$closed" = true ]; then
        /usr/bin/open -n "$target" || true
    fi
    exit 1
}

case "$target" in
    /*.app) ;;
    *) fail 'Could not locate the installed Other Gods app bundle.' ;;
esac
case "$target" in
    */AppTranslocation/*) fail 'Move Other Gods to Applications and reopen it before updating.' ;;
esac
[ ! -L "$target" ] || fail 'Move Other Gods to Applications and reopen the app directly before updating.'
[ -f "$target/Contents/Info.plist" ] || fail 'The installed app bundle is incomplete.'
parent=$(dirname "$target")
work=$(mktemp -d "$parent/.othergods-update.XXXXXX") || fail 'Cannot update this folder. Move Other Gods to a writable Applications folder and reopen it.'
mkdir "$work/unpacked"
/usr/bin/ditto -x -k "$archive" "$work/unpacked" || fail 'Could not unpack the downloaded macOS update.'
set -- "$work/unpacked/"*.app
[ "$#" -eq 1 ] && [ -d "$1" ] || fail 'The update archive must contain one app bundle.'
new_app=$1
plist="$new_app/Contents/Info.plist"
new_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist") || fail 'The update is missing its bundle identifier.'
old_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist") || fail 'Could not read the installed bundle identifier.'
[ "$new_id" = 'com.sprushy.othergods' ] && [ "$new_id" = "$old_id" ] || fail 'The update does not match the installed Other Gods app.'
new_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist") || fail 'The update is missing its version.'
[ "$new_version" = "$version" ] || fail 'The downloaded app version does not match the required release.'
bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist") || fail 'The update is missing its bundle version.'
[ "$bundle_version" = "$version" ] || fail 'The downloaded bundle version does not match the required release.'
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist") || fail 'The update is missing its executable name.'
case "$executable" in
    ''|*/*|.|..) fail 'The update has an invalid executable name.' ;;
esac
[ -x "$new_app/Contents/MacOS/$executable" ] || fail 'The update is missing its executable or permissions.'
/usr/bin/codesign --verify --deep --strict "$new_app" || fail 'The downloaded app failed macOS signature verification.'
echo "macos_updater_ready version=$version target=$target"
printf 'ready\n' > "$status"
attempt=0
while kill -0 "$wait_pid" 2>/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 300 ] || fail 'Timed out waiting for Other Gods to close.'
    sleep 0.1
done
closed=true
mv "$target" "$work/previous.app" || fail 'Could not move the previous app out of the way.'
backed_up=true
mv "$new_app" "$target" || fail 'Could not install the updated app.'
installed=true
/usr/bin/open -n "$target" || fail 'macOS could not reopen the updated app. Restored the previous version.'
rm -f "$failure" "$archive" "$status"
echo "macos_update_complete version=$version target=$target"
