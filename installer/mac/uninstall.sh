#!/bin/bash
# Uninstall Train Tracker: removes the service, the apps and the program. Python stays.
# TT_WINDOW=1: run by the uninstaller's window (window.py --uninstall), which asked first: each step prints
# "@@ <percent> <what's happening>" for its progress bar, "@! <note>" for its last page; TT_DELETE_DATA=yes also
# deletes the downloaded maps, schedules and API keys (~/.train-tracker).
# TT_UNATTENDED=1: no questions; removes the program and keeps that data.
# Otherwise (no window: a Python without Tk) it asks and answers with dialogs.
. "$(dirname "$0")/common.sh"
step() { [ -n "$TT_WINDOW" ] && echo "@@ $1 $2"; return 0; }
DELETE_DATA=${TT_DELETE_DATA:-no}
if [ -z "$TT_UNATTENDED$TT_WINDOW" ]; then
  answer=$(osascript -e 'button returned of (display dialog "Remove Train Tracker from this Mac?" buttons {"Cancel", "Remove"} default button "Remove" with title "Uninstall Train Tracker" with icon caution)' 2>/dev/null)
  [ "$answer" = "Remove" ] || exit 0
  keep=$(osascript -e 'button returned of (display dialog "Also delete the downloaded maps and schedules, and any API keys you saved?" buttons {"Keep them", "Delete"} default button "Keep them" with title "Uninstall Train Tracker")' 2>/dev/null)
  [ "$keep" = "Delete" ] && DELETE_DATA=yes
fi
step 10 "Stopping Train Tracker..."
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 && echo "Stopped Train Tracker." || echo "Train Tracker wasn't running."
rm -f "$PLIST" "$LOG" "$LOG.1" && echo "Removed the background service ($PLIST)"
step 35 "Removing the program..."
rm -rf "$APPDIR" && echo "Removed $APPDIR (the program, its Python environment and settings)"
if [ "$DELETE_DATA" = yes ]; then
  rm -rf "$HOME/.train-tracker" && echo "Removed ~/.train-tracker (maps, schedules and API keys)"
else
  echo "Kept ~/.train-tracker (maps, schedules and API keys) for the next install"
fi
step 70 "Removing the icons..."
# the Desktop icons: macOS asks once whether Uninstall Train Tracker may change the Desktop
icons=("$HOME/Desktop/Start Train Tracker" "$HOME/Desktop/Stop Train Tracker" "$HOME/Desktop/Uninstall Train Tracker")
rm -f "${icons[@]}" 2>/dev/null
left=""
for i in "${icons[@]}"; do { [ -L "$i" ] || [ -e "$i" ]; } && left=yes; done
note="macOS didn't let it remove its icons from your Desktop: drag Start and Stop Train Tracker to the Trash."
if [ -n "$TT_WINDOW" ]; then
  [ -n "$left" ] && echo "@! $note"
elif [ -z "$TT_UNATTENDED" ]; then
  done_msg="Train Tracker has been removed."
  [ -n "$left" ] && done_msg="Train Tracker has been removed.\n\n$note"
  osascript -e "display dialog \"$done_msg\" buttons {\"OK\"} default button \"OK\" with title \"Uninstall Train Tracker\"" >/dev/null 2>&1
fi
step 95 "Removing Start, Stop and Uninstall Train Tracker..."
echo "Removing $APPS"
rm -rf "/Applications/Train Tracker" "$HOME/Applications/Train Tracker"   # last: this app lives in one of them
step 100 "Done."
