#!/bin/bash
# Install US Train Tracker on this Mac. Double-click to run; run it again later to update.
#
# It installs the program in ~/Library/Application Support/Train Tracker, sets it up as a background service,
# and puts Start, Stop and Uninstall Train Tracker on your Desktop and in Applications › Train Tracker.
# Needs Python 3.11 or newer; if it isn't there, it offers to install Python from python.org (checked: the
# expected download, signed by the Python Software Foundation and notarized by Apple).
# Designed and Created by Project Moon Pi.
#
# For unattended installs, answer the questions ahead: TT_PHONES=yes|no TT_AUTOSTART=yes|no TT_OPEN=no
# TT_PYTHON=yes|no (install Python if needed; an unattended Python install still asks for the admin password)
SRC="$(cd "$(dirname "$0")" && pwd)"
. "$SRC/installer/mac/common.sh"
set -e

ask() {   # ask "question" "no-button" "yes-button" -> prints yes or no
  local b
  b=$(osascript -e "button returned of (display dialog \"$1\" buttons {\"$2\", \"$3\"} default button \"$3\" with title \"Install Train Tracker\")" 2>/dev/null) || b=""
  [ "$b" = "$3" ] && echo yes || echo no
}

find_python() {
  for p in python3.14 python3.13 python3.12 python3.11 \
           /Library/Frameworks/Python.framework/Versions/Current/bin/python3 /opt/homebrew/bin/python3 \
           /usr/local/bin/python3 python3; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
      command -v "$p"; return 0
    fi
  done
  return 1
}

echo "US Train Tracker installer - Designed and Created by Project Moon Pi"
# Python from python.org, offered when there's no Python 3.11 or newer
PY_VERSION=3.14.10
PY_PKG=python-$PY_VERSION-macos11.pkg
PY_SHA256=286c7018aa2730f6747ca433dccdc2b31be45f078a9ea0ffa44d5f06368fd2d7
PY_SIGNER="Developer ID Installer: Python Software Foundation (BMM5U3QVKW)"

no_python() {
  echo "Train Tracker needs Python 3.11 or newer: install it from https://www.python.org/downloads/ and run this again."
  osascript -e "display dialog \"$1\n\nClick Download to get Python from python.org, install it, then double-click Install Train Tracker again.\" buttons {\"Cancel\", \"Download\"} default button \"Download\" with title \"Install Train Tracker\"" \
    -e 'if button returned of result is "Download" then open location "https://www.python.org/downloads/"' >/dev/null 2>&1 || true
  exit 1
}

install_python() {
  local pkg
  PY_TMP=$(mktemp -d)
  trap 'rm -rf "$PY_TMP"' EXIT
  pkg="$PY_TMP/$PY_PKG"
  echo "Downloading Python $PY_VERSION from python.org (about 75 MB)…"
  curl -fL --progress-bar -o "$pkg" "https://www.python.org/ftp/python/$PY_VERSION/$PY_PKG" ||
    no_python "Python couldn't be downloaded. Check the internet connection."
  [ "$(shasum -a 256 "$pkg" | cut -d' ' -f1)" = "$PY_SHA256" ] ||
    no_python "The Python download wasn't the expected file, so it wasn't installed."
  pkgutil --check-signature "$pkg" | grep -qF "1. $PY_SIGNER" && spctl -a -t install "$pkg" 2>/dev/null ||
    no_python "The Python download isn't signed by the Python Software Foundation, so it wasn't installed."
  echo "Installing Python $PY_VERSION (macOS asks for your password)…"
  osascript -e "do shell script \"/usr/sbin/installer -pkg \" & quoted form of \"$pkg\" & \" -target /\" with administrator privileges with prompt \"Install Train Tracker wants to install Python $PY_VERSION from python.org.\"" >/dev/null ||
    no_python "Python wasn't installed."
}

PY=$(find_python) || {
  WANT=${TT_PYTHON:-$(ask "Train Tracker needs Python 3.11 or newer, and this Mac doesn't have it.\n\nInstall Python $PY_VERSION from python.org now? It's free, about 75 MB, and macOS asks for your password once." "Cancel" "Install Python")}
  [ "$WANT" = yes ] || no_python "Train Tracker needs Python 3.11 or newer."
  install_python
  PY=$(find_python) || no_python "Python was installed but can't be found."
}

PHONES=${TT_PHONES:-$(ask "Should phones and tablets on your Wi-Fi be able to open the train map?\n\nThey'll find the address and a QR code in the map's panel." "This Mac only" "Phones too")}
AUTOSTART=${TT_AUTOSTART:-$(ask "Start Train Tracker by itself whenever you log in?\n\nOtherwise, use the Start Train Tracker icon when you want it." "No" "Yes")}

# an update: stop the running service first
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true

echo "Installing with $("$PY" --version) into $APPDIR (about a minute)…"
# the apps go in Applications › Train Tracker, or in your own Applications folder (in your home folder) if this
# account can't add to Applications; an older install's copy in the other place goes
if [ -w /Applications ]; then APPS="/Applications/Train Tracker"; else APPS="$HOME/Applications/Train Tracker"; fi
for old in "/Applications/Train Tracker" "$HOME/Applications/Train Tracker"; do
  [ "$old" != "$APPS" ] && [ -d "$old/Start Train Tracker.app" ] && rm -rf "$old"
done
mkdir -p "$APPDIR" "$APPS" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
# a fresh environment if there's none, or its Python was removed or is too old
"$APPDIR/venv/bin/python" -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null || {
  rm -rf "$APPDIR/venv"
  "$PY" -m venv "$APPDIR/venv"
}
"$APPDIR/venv/bin/python" -m pip install --quiet --upgrade pip
"$APPDIR/venv/bin/python" -m pip install --quiet --upgrade "$SRC"
VERSION=$("$APPDIR/venv/bin/python" -c 'import train_tracker; print(train_tracker.__version__)')
# pystray and Pillow (with PyObjC) put Train Tracker's icon in the menu bar; without them it runs without the icon
"$APPDIR/venv/bin/python" -m pip install --quiet --disable-pip-version-check --upgrade pystray pillow ||
  echo "(Couldn't install pystray and Pillow: Train Tracker will run without its menu bar icon.)"

# venv/bin/Train Tracker: Python under Train Tracker's own name, so Activity Monitor shows "Train Tracker". It's a
# copy of Python's own program, signed again for its new place (its signature belongs to Python.app); plain python
# if that doesn't work.
EXE="$APPDIR/venv/bin/python"
REAL=$("$EXE" -c 'import os, sys; p = os.path.join(sys.base_prefix, "Resources/Python.app/Contents/MacOS/Python"); print(p if os.path.exists(p) else os.path.realpath(sys._base_executable))')
if cp "$REAL" "$APPDIR/venv/bin/Train Tracker.new" && codesign --force -s - "$APPDIR/venv/bin/Train Tracker.new" 2>/dev/null &&
   "$APPDIR/venv/bin/Train Tracker.new" -c 'import sys, train_tracker; sys.exit(sys.prefix == sys.base_prefix)' 2>/dev/null; then
  mv -f "$APPDIR/venv/bin/Train Tracker.new" "$APPDIR/venv/bin/Train Tracker"
  EXE="$APPDIR/venv/bin/Train Tracker"
else
  rm -f "$APPDIR/venv/bin/Train Tracker.new"
  echo "(Activity Monitor will show Train Tracker as Python.)"
fi
printf 'PORT=%s\nPHONES=%s\nAUTOSTART=%s\nAPPS=%q\n' "$PORT" "$PHONES" "$AUTOSTART" "$APPS" > "$APPDIR/settings.sh"

# the background service (a LaunchAgent: runs as you, only while you're logged in)
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

# the apps: Start, Stop and Uninstall. Each is a small AppleScript app (made by macOS's osacompile) that runs
# its script from Contents/Resources. A real app, not a script in a folder, so macOS can ask about it by name:
# Uninstall needs your OK, once, to remove its icons from the Desktop (as SkyScope's do).
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
}
make_app "Start Train Tracker" start.sh start start
make_app "Stop Train Tracker" stop.sh stop stop
make_app "Uninstall Train Tracker" uninstall.sh uninstall uninstall
# files from a downloaded zip carry macOS's "downloaded" flag; apps built here shouldn't
xattr -dr com.apple.quarantine "$APPS" 2>/dev/null || true
ln -sfn "$APPS/Start Train Tracker.app" "$HOME/Desktop/Start Train Tracker"
ln -sfn "$APPS/Stop Train Tracker.app" "$HOME/Desktop/Stop Train Tracker"
ln -sfn "$APPS/Uninstall Train Tracker.app" "$HOME/Desktop/Uninstall Train Tracker"

launchctl bootstrap "$DOMAIN" "$PLIST"
echo "Installed US Train Tracker $VERSION. Starting it…"
export TT_INSTALLING=1    # (Start doesn't need to say it's already running)
if [ "${TT_OPEN:-yes}" = no ]; then
  "$APPS/Start Train Tracker.app/Contents/Resources/run.sh" --no-browser
else
  "$APPS/Start Train Tracker.app/Contents/Resources/run.sh"
fi
echo "Done. Use Start Train Tracker and Stop Train Tracker on your Desktop (also in Applications › Train Tracker); Uninstall Train Tracker is there too."
[ -n "$TT_PHONES" ] || osascript -e 'display dialog "Train Tracker is installed and running.\n\nWhile it runs, its train icon is in the menu bar at the top of the screen: click it for the map, the API keys or to stop Train Tracker.\n\nUse Start Train Tracker and Stop Train Tracker on your Desktop (also in your Applications folder, under Train Tracker). Uninstall Train Tracker is there too.\n\nYou can delete the downloaded folder now." buttons {"OK"} default button "OK" with title "Install Train Tracker"' >/dev/null 2>&1 || true
