#!/bin/bash
# Uninstall Train Tracker: removes the service, the apps and the program. Asks before deleting your data.
. "$(dirname "$0")/common.sh"
# TT_UNATTENDED=1: no questions; removes the program and keeps your data
if [ -z "$TT_UNATTENDED" ]; then
  answer=$(osascript -e 'button returned of (display dialog "Remove Train Tracker from this Mac?" buttons {"Cancel", "Remove"} default button "Remove" with title "Uninstall Train Tracker" with icon caution)' 2>/dev/null)
  [ "$answer" = "Remove" ] || exit 0
fi
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1
rm -f "$PLIST" "$HOME/Desktop/Start Train Tracker" "$HOME/Desktop/Stop Train Tracker" "$HOME/Desktop/Uninstall Train Tracker" \
  "$LOG" "$LOG.1"
# Desktop icons that are still there (macOS asks once whether Uninstall Train Tracker may change the Desktop;
# if that was declined, they stay)
left=""
for n in Start Stop Uninstall; do [ -L "$HOME/Desktop/$n Train Tracker" ] && left="$left $n"; done
[ -z "$left" ] || osascript -e "display dialog \"macOS kept Train Tracker's icons on your Desktop. You can drag them to the Trash.\" buttons {\"OK\"} default button \"OK\" with title \"Uninstall Train Tracker\"" >/dev/null 2>&1
rm -rf "$APPDIR"
[ -n "$TT_UNATTENDED" ] || keep=$(osascript -e 'button returned of (display dialog "Also delete the downloaded maps and schedules, and any API keys you saved?" buttons {"Keep them", "Delete"} default button "Keep them" with title "Uninstall Train Tracker")' 2>/dev/null)
[ "$keep" = "Delete" ] && rm -rf "$HOME/.train-tracker"
[ -n "$TT_UNATTENDED" ] || osascript -e 'display dialog "Train Tracker has been removed." buttons {"OK"} default button "OK" with title "Uninstall Train Tracker"' >/dev/null 2>&1
rm -rf "$APPS" "$HOME/Applications/Train Tracker"     # last: this app lives in there (and an older install's place)
