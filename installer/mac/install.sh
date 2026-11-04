#!/bin/bash
# The Mac installer's work, run by its window (installer/mac/window.py, in "Install Train Tracker.app") with the
# answers already given:
#   TT_PY=<python 3.11+> TT_PHONES=yes|no TT_AUTOSTART=yes|no TT_DESKTOP=yes|no
#   TT_MODE=install|update|repair|fresh
#     install/update: compares the installed Train Tracker's files with this installer's and replaces only the ones
#                     that differ; the parts it runs on change only if this version needs them to.
#     repair:         checks every installed file against the fingerprint pip wrote down when installing it and
#                     installs again the packages with damaged or missing files (Python's environment is made again
#                     if it's broken); then makes the apps and the service again.
#     fresh:          removes everything Train Tracker put on this Mac (program, settings, apps, service, Desktop
#                     icons, log, the downloaded maps and schedules) except the saved API keys, then installs it new.
# Each step prints "@@ <percent> <what's happening>" for the window's progress bar, "@! <note>" for its last page;
# everything else goes to its log. It installs the program in ~/Library/Application Support/Train Tracker, sets it up
# as a background service (started last), and puts Start, Stop and Uninstall Train Tracker in Applications › Train
# Tracker (Start and Stop on the Desktop too, if wanted). Run it again to update: your settings are kept.
# Designed and Created by Project Moon Pi.
SRC="$(cd "$(dirname "$0")/../.." && pwd)"           # the program's files (inside the installer app)
. "$SRC/installer/mac/common.sh"
set -e
step() { echo "@@ $1 $2"; }
PIP=(--disable-pip-version-check --no-input --progress-bar off)   # pip says what it fetches (for the details box)
PY=${TT_PY:?}; PHONES=${TT_PHONES:-yes}; AUTOSTART=${TT_AUTOSTART:-no}; DESKTOP=${TT_DESKTOP:-yes}; MODE=${TT_MODE:-install}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

step 3 "Stopping Train Tracker, if it's running..."
if launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1; then echo "Stopped the running Train Tracker."; else echo "Train Tracker wasn't running."; fi
# the apps go in Applications › Train Tracker, or in your own Applications folder (in your home folder) if this
# account can't add to Applications; an older install's copy in the other place goes
if [ -w /Applications ]; then APPS="/Applications/Train Tracker"; else APPS="$HOME/Applications/Train Tracker"; fi
for old in "/Applications/Train Tracker" "$HOME/Applications/Train Tracker"; do
  [ "$old" != "$APPS" ] && [ -d "$old/Start Train Tracker.app" ] && rm -rf "$old"
done
if [ "$MODE" = fresh ]; then
  echo "Reinstalling from scratch: removing everything Train Tracker put on this Mac..."
  rm -rf "$APPDIR" && echo "Removed the program, its Python environment and settings ($APPDIR)"
  rm -f "$PLIST" "$LOG" "$LOG.1" && echo "Removed the background service and its log"
  rm -rf "/Applications/Train Tracker" "$HOME/Applications/Train Tracker" && echo "Removed Start, Stop and Uninstall Train Tracker"
  rm -f "$HOME/Desktop/Start Train Tracker" "$HOME/Desktop/Stop Train Tracker" "$HOME/Desktop/Uninstall Train Tracker" 2>/dev/null || true
  if [ -d "$HOME/.train-tracker" ]; then
    # everything it downloaded goes; the saved API keys (.env) stay: they can't be downloaded again
    find "$HOME/.train-tracker" -mindepth 1 -maxdepth 1 ! -name .env -exec rm -rf {} + &&
      echo "Removed the downloaded maps and schedules (~/.train-tracker); they download again when it starts"
    [ -f "$HOME/.train-tracker/.env" ] && echo "@! Reinstalled from scratch: everything was removed and installed new, except your saved API keys. The maps and schedules download again on its first start."
  fi
fi
mkdir -p "$APPDIR" "$APPS" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
echo "Program folder: $APPDIR"
echo "Apps folder: $APPS"

VPY="$APPDIR/venv/bin/python"
new_venv() {
  rm -rf "$APPDIR/venv"
  echo "Making Train Tracker's own Python environment (venv)..."
  "$PY" -m venv "$APPDIR/venv"
  "$VPY" -m pip install --quiet "${PIP[@]}" --upgrade pip || echo "(pip couldn't update itself; carrying on with this one.)"
}

step 8 "Setting up Python for Train Tracker..."
echo "Using $("$PY" -c 'import sys; print("Python", sys.version.split()[0])') ($PY)"
# a fresh environment if there's none, or its Python was removed or is too old
# (and if it can't run its own pip, as when Repair finds Python's environment broken)
if "$VPY" -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null && "$VPY" -m pip --version >/dev/null 2>&1; then
  echo "Using Train Tracker's Python environment: $APPDIR/venv"
else
  [ -d "$APPDIR/venv" ] && echo "Train Tracker's Python environment can't run: making it again."
  new_venv
fi

step 18 "Building Train Tracker from this installer..."
# built from a copy: pip leaves a build folder where it builds, which mustn't change the (signed) installer app
cp -R "$SRC" "$WORK/train-tracker"
"$VPY" -m pip wheel "${PIP[@]}" --quiet --no-deps -w "$WORK/wheel" "$WORK/train-tracker"
WHEEL=$(ls "$WORK"/wheel/*.whl)
CHECK="$SRC/installer/filecheck.py"
export FC_APP="Train Tracker"
if [ "$MODE" = repair ]; then
  step 30 "Checking Train Tracker's files..."
  if "$VPY" "$CHECK" check > "$WORK/check.txt" 2>&1; then
    cat "$WORK/check.txt"
    echo "@! Repair $(tail -1 "$WORK/check.txt" | sed 's/^Checked/checked/')"
  else
    cat "$WORK/check.txt"
    step 40 "Fixing the damaged files..."
    fixed=yes
    while read -r _ want; do
      if [ "${want%%==*}" = train-tracker ]; then
        "$VPY" -m pip install "${PIP[@]}" --force-reinstall --no-deps "$WHEEL" || fixed=""
      else
        "$VPY" -m pip install "${PIP[@]}" --force-reinstall --no-deps "$want" || fixed=""
      fi
    done < <(grep '^REPAIR ' "$WORK/check.txt")
    if [ -z "$fixed" ] || ! "$VPY" "$CHECK" check > "$WORK/check2.txt" 2>&1; then
      [ -f "$WORK/check2.txt" ] && cat "$WORK/check2.txt"
      echo "Some files couldn't be fixed in place: making Train Tracker's Python environment again."
      new_venv
      "$VPY" -m pip install "${PIP[@]}" "$WHEEL"
      echo "@! Repair $(tail -1 "$WORK/check.txt" | sed 's/^Checked/checked/') It set up Train Tracker's Python parts again to fix them."
    else
      echo "@! Repair $(tail -1 "$WORK/check.txt" | sed 's/^Checked/checked/') It fixed them."
    fi
  fi
  # and any part that's missing altogether (pip adds only what isn't there)
  "$VPY" -m pip install "${PIP[@]}" "$WHEEL"
else
  if "$VPY" -c 'import train_tracker' 2>/dev/null; then step 30 "Comparing the installed files with this installer's..."
  else step 30 "Installing Train Tracker..."; fi
  if "$VPY" "$CHECK" compare "$WHEEL" > "$WORK/compare.txt" 2>&1; then
    cat "$WORK/compare.txt"
  else
    cat "$WORK/compare.txt"
    "$VPY" -c 'import train_tracker' 2>/dev/null && step 40 "Replacing the files that differ..."
    "$VPY" -m pip install "${PIP[@]}" --force-reinstall --no-deps "$WHEEL"
  fi
  [ "$MODE" = update ] && echo "@! $(tail -1 "$WORK/compare.txt")"
  # the parts it runs on: only added or changed if this version needs them to be
  "$VPY" -m pip install "${PIP[@]}" "$WHEEL"
fi
VERSION=$("$VPY" -c 'import train_tracker; print(train_tracker.__version__)')
echo "Installed US Train Tracker $VERSION"

step 55 "Installing the menu bar icon (pystray, Pillow)..."
# pystray and Pillow (with PyObjC) put Train Tracker's icon in the menu bar; without them it runs without the icon
"$VPY" -m pip install "${PIP[@]}" pystray pillow ||
  echo "@! The menu bar icon's parts couldn't be installed: Train Tracker runs without its menu bar icon. Use Start and Stop Train Tracker."

step 74 "Naming Train Tracker for Activity Monitor..."
# venv/bin/Train Tracker: Python under Train Tracker's own name, so Activity Monitor shows "Train Tracker". It's a
# copy of Python's own program, signed again for its new place (its signature belongs to Python.app); plain python
# if that doesn't work.
EXE="$APPDIR/venv/bin/python"
REAL=$("$EXE" -c 'import os, sys; p = os.path.join(sys.base_prefix, "Resources/Python.app/Contents/MacOS/Python"); print(p if os.path.exists(p) else os.path.realpath(sys._base_executable))')
if cp "$REAL" "$APPDIR/venv/bin/Train Tracker.new" && codesign --force -s - "$APPDIR/venv/bin/Train Tracker.new" 2>/dev/null &&
   "$APPDIR/venv/bin/Train Tracker.new" -c 'import sys, train_tracker; sys.exit(sys.prefix == sys.base_prefix)' 2>/dev/null; then
  mv -f "$APPDIR/venv/bin/Train Tracker.new" "$APPDIR/venv/bin/Train Tracker"
  EXE="$APPDIR/venv/bin/Train Tracker"
  echo "Made $EXE (a signed copy of Python under Train Tracker's name)"
else
  rm -f "$APPDIR/venv/bin/Train Tracker.new"
  echo "(Activity Monitor will show Train Tracker as Python.)"
fi

step 78 "Keeping the uninstaller..."
# the uninstaller's window and work, run by Uninstall Train Tracker
rm -rf "$APPDIR/installer"
mkdir -p "$APPDIR/installer/mac" "$APPDIR/installer/icons"
cp "$SRC/installer/mac/window.py" "$SRC/installer/mac/uninstall.sh" "$SRC/installer/mac/common.sh" "$APPDIR/installer/mac/"
cp "$CHECK" "$APPDIR/installer/"
cp "$SRC/src/train_tracker/web/img/moon-pi-logo-128.png" "$APPDIR/installer/mac/"
cp "$SRC/installer/icons/uninstall-256.png" "$APPDIR/installer/icons/"
echo "Copied the uninstaller to $APPDIR/installer"
echo "Web port $PORT; phones on the Wi-Fi: $PHONES; start at login: $AUTOSTART; Desktop icons: $DESKTOP"
printf 'PORT=%s\nPHONES=%s\nAUTOSTART=%s\nDESKTOP=%s\nVERSION=%s\nAPPS=%q\n' "$PORT" "$PHONES" "$AUTOSTART" "$DESKTOP" "$VERSION" "$APPS" > "$APPDIR/settings.sh"

step 82 "Setting up the background service..."
# a LaunchAgent: runs as you, only while you're logged in
HOSTARGS=""
[ "$PHONES" = yes ] && HOSTARGS="<string>--host</string><string>0.0.0.0</string>"
RUNATLOAD=false
[ "$AUTOSTART" = yes ] && RUNATLOAD=true
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$EXE</string>
    <string>-m</string><string>train_tracker</string>
    <string>--port</string><string>$PORT</string>
    <string>--log-file</string><string>$LOG</string>
    <string>--tray</string>
    $HOSTARGS
  </array>
  <key>WorkingDirectory</key><string>$APPDIR</string>
  <key>RunAtLoad</key><$RUNATLOAD/>
  <key>ProcessType</key><string>Standard</string>
</dict>
</plist>
PLIST
echo "Wrote the service: $PLIST"

step 86 "Making Start, Stop and Uninstall Train Tracker..."
# Each is a small AppleScript app (made by macOS's osacompile) that runs its script from Contents/Resources. A real
# app, not a script in a folder, so macOS can ask about it by name: Uninstall needs your OK, once, to remove the
# icons from the Desktop.
make_app() {   # make_app "Name" script icon id
  local app="$APPS/$1.app" plist="$APPS/$1.app/Contents/Info.plist"
  rm -rf "$app"
  osacompile -o "$app" -e 'on run' \
    -e 'try' \
    -e 'do shell script quoted form of (POSIX path of (path to me) & "Contents/Resources/run.sh")' \
    -e 'end try' -e 'end run'   # (the script shows its own messages)
  cp "$SRC/installer/mac/$2" "$app/Contents/Resources/run.sh"
  cp "$SRC/installer/mac/common.sh" "$app/Contents/Resources/common.sh"
  chmod +x "$app/Contents/Resources/run.sh"
  cp "$SRC/installer/icons/$3.icns" "$app/Contents/Resources/applet.icns"
  rm -f "$app/Contents/Resources/Assets.car"
  plutil -remove CFBundleIconName "$plist" >/dev/null 2>&1 || true
  plutil -replace CFBundleName -string "$1" "$plist"
  plutil -replace CFBundleDisplayName -string "$1" "$plist"
  plutil -replace CFBundleIdentifier -string "$LABEL.$4" "$plist"
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$plist"
  plutil -replace NSHumanReadableCopyright -string "Designed and Created by Project Moon Pi" "$plist"
  plutil -replace NSDesktopFolderUsageDescription -string "To remove Train Tracker's icons from your Desktop." "$plist"
  plutil -replace LSUIElement -bool YES "$plist"
  codesign --force -s - "$app" 2>/dev/null || true   # signed again after the changes, so macOS knows it
  touch "$app"
  echo "Made $app"
}
make_app "Start Train Tracker" start.sh start start
make_app "Stop Train Tracker" stop.sh stop stop
make_app "Uninstall Train Tracker" uninstall-window.sh uninstall uninstall
# files from a downloaded zip carry macOS's "downloaded" flag; apps built here shouldn't
xattr -dr com.apple.quarantine "$APPS" "$APPDIR" 2>/dev/null || true

step 93 "Adding the icons..."
if [ "$DESKTOP" = yes ]; then
  # (macOS asks once whether the installer may change the Desktop)
  { ln -sfn "$APPS/Start Train Tracker.app" "$HOME/Desktop/Start Train Tracker" &&
    ln -sfn "$APPS/Stop Train Tracker.app" "$HOME/Desktop/Stop Train Tracker"; } 2>/dev/null && echo "Put Start and Stop Train Tracker on the Desktop" ||
    echo "@! macOS didn't let the installer put Start and Stop Train Tracker on your Desktop: they're in Applications › Train Tracker."
else
  rm -f "$HOME/Desktop/Start Train Tracker" "$HOME/Desktop/Stop Train Tracker" 2>/dev/null || true
  echo "No Desktop icons (as chosen)"
fi
rm -f "$HOME/Desktop/Uninstall Train Tracker" 2>/dev/null || true   # (0.5.0 put one there; it lives in Applications › Train Tracker)

step 96 "Starting Train Tracker..."
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl kickstart "$DOMAIN/$LABEL"
echo "Started the service; waiting for Train Tracker to answer on port $PORT..."
for _ in $(seq 1 240); do up && break; sleep 1; done
up && echo "Train Tracker is running: http://localhost:$PORT"
up || { echo "Train Tracker didn't start: its messages are in $LOG"; exit 2; }
step 100 "Done."
echo "VERSION=$VERSION PORT=$PORT"
