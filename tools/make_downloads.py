#!/usr/bin/env python3
"""Build the two downloads attached to each GitHub release:

  dist/US-Train-Tracker-for-Mac.zip       Install Train Tracker.app (the program and the Mac installer inside it:
                                          build_mac_app(); needs a Mac, for macOS's osacompile and codesign)
  dist/US-Train-Tracker-for-Windows.zip   Install Train Tracker.exe + the Windows installer pieces

Each holds the app (installed from the folder by the installer), the printable guide and a READ ME FIRST note.
The release workflow runs this; it also runs locally:  python3 tools/make_downloads.py
"""
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
GUIDE = ROOT / "docs" / "US-Train-Tracker-Install-Guide.pdf"
VERSION = re.search(r'__version__ = "([^"]+)"', (ROOT / "src/train_tracker/__init__.py").read_text()).group(1)

COMMON = ["pyproject.toml", "README.md", "LICENSE", "CHANGELOG.md", ".env.example"]

READ_ME = {
    "Mac": """US Train Tracker {v} for Mac
Designed and Created by Project Moon Pi

1. Double-click "Install Train Tracker" (the train icon).
   The first time, macOS may say it can't check the developer: open System Settings > Privacy & Security,
   scroll down to the message about Install Train Tracker and click Open Anyway.
   If this Mac hasn't got Python 3.11 or newer, it offers to install it from python.org first (click
   Install Python; your Mac asks for your password).
2. The installer's window checks this Mac, then asks: phones on your Wi-Fi, start at login, and Start and
   Stop on the Desktop. If Train Tracker is already installed it offers Update (or Repair) and Reinstall from
   scratch (which keeps your maps and API keys). Click Install and watch the train.
3. Click Finish. Leave "Open the map now" ticked to see the map.
   If macOS asks whether Train Tracker may accept incoming network connections, click Allow (so phones can
   reach it).

While it runs, its train icon is in the menu bar: click it for the map, the API keys or Stop.
Start, Stop and Uninstall Train Tracker are in Applications > Train Tracker (Start and Stop on your Desktop
too, if you chose). Uninstall asks whether to keep your maps and API keys for the next install.
You can delete this folder once it's installed. The full guide is "US Train Tracker - Installation Guide.pdf".
""",
    "Windows": """US Train Tracker {v} for Windows
Designed and Created by Project Moon Pi

1. Extract this zip (right-click it, Extract All), then double-click "Install Train Tracker" (the train icon).
   If Windows says it protected your PC: More info > Run anyway.
2. Choose where to install it (or keep the suggested folder), whether phones on your Wi-Fi may open the map,
   whether it starts when you sign in and whether Start and Stop go on your Desktop, then click Install. If this PC doesn't have Python 3.11 or newer, it installs Python from python.org for you too
   (no admin permission needed).
   If you chose phones, a note comes up before Windows asks to allow Windows PowerShell to make changes:
   click Yes (that opens the firewall for them).
3. Click Finish. Leave "Open the map now" ticked to see the map.

While it runs, its green train icon is by the clock (click ^ if it's hidden): click it for the map,
right-click for the API keys or Stop.
Afterwards use Start Train Tracker and Stop Train Tracker in the Start menu (and on your Desktop, if you chose that).
To remove it, double-click "Uninstall Train Tracker" in this folder or in the folder you installed it in, click
"Remove Train Tracker" in the Start menu, or use Settings > Apps.
You can delete this folder once it's installed. The full guide is "US Train Tracker - Installation Guide.pdf".
""",
}


# "Install Train Tracker.app": opens the installer's window (installer/mac/window.py) with no Terminal window, as the
# M.O.S.S. RPi SD Card Creator and SkyScope's installer do. If the Mac has no Python that can draw it (3.11 or newer,
# with Tk), it offers to install python.org's (macOS's own progress window while it downloads; the Mac's password to
# install it), then opens the window.
INSTALLER_SCRIPT = """set here to POSIX path of (path to me)
set mac to here & "Contents/Resources/train-tracker/installer/mac/"
try
    do shell script quoted form of (mac & "launch.sh")
on error errMsg number errNum
    if errNum is 3 then
        set pyv to do shell script quoted form of (mac & "get_python.sh") & " version"
        set b to button returned of (display dialog "Train Tracker runs on Python 3.11 or newer, which isn't on this Mac yet." & return & return & "Install Python " & pyv & " from python.org now? It's free, about 75 MB, and your Mac asks for your password to install it. Then the installer opens." buttons {"Cancel", "Install Python"} default button "Install Python" with title "Install Train Tracker" with icon note)
        if b is "Install Python" then
            try
                set progress total steps to -1
                set progress description to "Installing Python " & pyv & " for Train Tracker"
                set progress additional description to "Downloading it from python.org..."
                set pkg to do shell script quoted form of (mac & "get_python.sh") & " download"
                set progress additional description to "Installing it (your Mac asks for your password)..."
                do shell script quoted form of (mac & "get_python.sh") & " install " & quoted form of pkg with prompt "Install Train Tracker wants to install Python " & pyv & " from python.org." with administrator privileges
                do shell script quoted form of (mac & "launch.sh")
            on error errMsg2 number errNum2
                if errNum2 is not -128 then display dialog "Python wasn't installed: " & errMsg2 buttons {"OK"} default button "OK" with title "Install Train Tracker" with icon stop
            end try
        end if
    else
        display dialog "The installer couldn't start: " & errMsg buttons {"OK"} default button "OK" with title "Install Train Tracker" with icon stop
    end if
end try
"""


def build_mac_app(dest, files):
    """Install Train Tracker.app in `dest`: an AppleScript app (osacompile) with the train icon, holding the program and
    the Mac installer in Contents/Resources/train-tracker/, laid out as the project folder."""
    app = dest / "Install Train Tracker.app"
    script = dest / "installer.applescript"
    script.write_text(INSTALLER_SCRIPT)
    subprocess.run(["osacompile", "-o", str(app), str(script)], check=True)
    script.unlink()
    res = app / "Contents" / "Resources"
    for f in files:
        to = res / "train-tracker" / f.relative_to(ROOT)
        to.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, to)
        if f.suffix == ".sh":
            to.chmod(0o755)
    shutil.copy2(ROOT / "installer/icons/app.icns", res / "applet.icns")
    (res / "Assets.car").unlink(missing_ok=True)
    plist = app / "Contents" / "Info.plist"
    subprocess.run(["plutil", "-remove", "CFBundleIconName", str(plist)], capture_output=True)
    for key, value in (("CFBundleName", "Install Train Tracker"),
                       ("CFBundleDisplayName", "Install Train Tracker"),
                       ("CFBundleIdentifier", "com.projectmoonpi.train-tracker.installer"),
                       ("CFBundleShortVersionString", VERSION),
                       ("NSHumanReadableCopyright", "Designed and Created by Project Moon Pi"),
                       ("NSDesktopFolderUsageDescription", "To put Start and Stop Train Tracker on your Desktop.")):
        subprocess.run(["plutil", "-replace", key, "-string", value, str(plist)], check=True)
    # sealed (ad hoc: no Apple developer certificate), so macOS sees the app whole after the download
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True, capture_output=True)
    return app


def build(platform):
    top = f"US Train Tracker for {platform}"
    out = DIST / f"US-Train-Tracker-for-{platform}.zip"
    windows = platform == "Windows"
    files = [ROOT / f for f in COMMON]
    files += [p for p in sorted((ROOT / "src").rglob("*"))
              if p.is_file() and "__pycache__" not in p.parts and ".egg-info" not in str(p)]
    files.append(ROOT / "installer/filecheck.py")   # (Repair and Update check the installed files with it)
    if windows:
        files += sorted((ROOT / "installer/windows").glob("*.ps1")) + [ROOT / "installer/windows/brand_exe.py",
                                                                         ROOT / "installer/windows/Uninstall Train Tracker.exe"]
        files += sorted((ROOT / "installer/icons").glob("*.ico"))
    else:
        files += sorted(f for f in (ROOT / "installer/mac").iterdir() if f.suffix in (".sh", ".py"))
        files += sorted((ROOT / "installer/icons").glob("*.icns")) + sorted((ROOT / "installer/icons").glob("*.png"))

    def add(z, name, data, mode=0o644):
        info = zipfile.ZipInfo(f"{top}/{name}", date_time=time.localtime()[:6])
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = (mode | stat.S_IFREG) << 16
        z.writestr(info, data)

    DIST.mkdir(exist_ok=True)
    count = 0
    with zipfile.ZipFile(out, "w") as z:
        if windows:
            for f in files:
                data = f.read_bytes()
                if f.suffix in (".bat", ".ps1"):              # Windows line endings, whatever the checkout has
                    data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
                add(z, f.relative_to(ROOT).as_posix(), data)
                count += 1
            # the launchers (train and trash-can icons) open the installer's and uninstaller's windows
            for exe in ("Install Train Tracker.exe", "Uninstall Train Tracker.exe"):
                add(z, exe, (ROOT / "installer/windows" / exe).read_bytes())
                count += 1
        else:
            with tempfile.TemporaryDirectory() as tmp:
                app = build_mac_app(Path(tmp), files)
                for f in sorted(app.rglob("*")):
                    if f.is_file():
                        add(z, f.relative_to(tmp).as_posix(), f.read_bytes(), stat.S_IMODE(f.stat().st_mode))
                        count += 1
        add(z, "US Train Tracker - Installation Guide.pdf", GUIDE.read_bytes())
        note = READ_ME[platform].format(v=VERSION)
        add(z, "READ ME FIRST.txt", note.replace("\n", "\r\n") if windows else note)
    print(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB, {count + 2} files)")
    return out


if __name__ == "__main__":
    for p in (sys.argv[1:] or ["Mac", "Windows"]):
        build(p)
