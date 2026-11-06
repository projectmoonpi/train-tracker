#!/usr/bin/env python3
"""Build the downloads attached to each GitHub release, one file for each computer (as Aviator Trail's):

  dist/US-Train-Tracker-for-Mac-v<version>.dmg            a disk image: Install Train Tracker.app (the program and the
                                                          Mac installer inside it: build_mac_app(); needs a Mac, for
                                                          osacompile, codesign and hdiutil), the guide, a READ ME
  dist/Install-US-Train-Tracker-for-Windows-v<version>.exe  the installer, carrying the program (Payload.cs)
  dist/US-Train-Tracker-Install-Guide-v<version>.pdf      the printable guide

and, for Train Tracker 1.0.2's Update button (it looks for zips), US-Train-Tracker-for-Mac-v<version>.zip and
-for-Windows-v<version>.zip. The version is in each file's name, so a download says which Train Tracker it is.
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
Once it's installed you can eject this disk image and delete the download. The full guide is "US Train Tracker - Installation Guide.pdf".

Need help? Email support@projectmoonpi.com or see www.projectmoonpi.com/support.
Anything else: sales@projectmoonpi.com.  Website: www.projectmoonpi.com
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


MARK = b"MOONPI-PAYLOAD-1"      # (installer/windows/src/Payload.cs reads it)


def program_files(windows):
    files = [ROOT / f for f in COMMON]
    files += [p for p in sorted((ROOT / "src").rglob("*"))
              if p.is_file() and "__pycache__" not in p.parts and ".egg-info" not in str(p)]
    files.append(ROOT / "installer/filecheck.py")   # (Repair and Update check the installed files with it)
    if windows:
        # the Windows programs (built from installer/windows/src by build.sh: compiled C#, no PowerShell)
        files += [ROOT / "installer/windows/Train Tracker.exe", ROOT / "installer/windows/Uninstall Train Tracker.exe"]
        files += sorted((ROOT / "installer/icons").glob("*.ico"))
    else:
        files += sorted(f for f in (ROOT / "installer/mac").iterdir() if f.suffix in (".sh", ".py"))
        files += sorted((ROOT / "installer/icons").glob("*.icns")) + sorted((ROOT / "installer/icons").glob("*.png"))
    return files


def zip_entry(z, name, data, mode=0o644):
    info = zipfile.ZipInfo(name, date_time=time.localtime()[:6])
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (mode | stat.S_IFREG) << 16
    z.writestr(info, data)


def build_windows():
    """The installer with the program's files (a zip) added to its end, as NSIS and Inno Setup installers carry theirs
    (Payload.cs unpacks them). One file: download it, double-click it."""
    out = DIST / f"Install-US-Train-Tracker-for-Windows-v{VERSION}.exe"
    with tempfile.SpooledTemporaryFile() as buf:
        with zipfile.ZipFile(buf, "w") as z:
            for f in program_files(True):
                zip_entry(z, f.relative_to(ROOT).as_posix(), f.read_bytes())
        buf.seek(0)
        payload = buf.read()
    exe = (ROOT / "installer/windows/Install Train Tracker.exe").read_bytes()
    out.write_bytes(exe + payload + len(payload).to_bytes(8, "little") + MARK)
    print(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)")
    return out


def build_mac():
    """A disk image holding Install Train Tracker.app, the guide and a READ ME. One file: download it, double-click
    it, double-click Install Train Tracker."""
    out = DIST / f"US-Train-Tracker-for-Mac-v{VERSION}.dmg"
    with tempfile.TemporaryDirectory() as tmp:
        stage = Path(tmp) / f"US Train Tracker {VERSION}"
        stage.mkdir()
        build_mac_app(stage, program_files(False))
        shutil.copy2(GUIDE, stage / "US Train Tracker - Installation Guide.pdf")
        (stage / "READ ME FIRST.txt").write_text(READ_ME["Mac"].format(v=VERSION))
        subprocess.run(["hdiutil", "create", "-quiet", "-volname", f"Install Train Tracker {VERSION}", "-srcfolder",
                        str(stage), "-fs", "HFS+", "-format", "UDZO", "-ov", str(out)], check=True)
    print(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)")
    return out


def build_old_zip(platform):
    """For Train Tracker 1.0.2's Update button, which looks for a zip holding a "US Train Tracker <version> ..."
    folder with the installer in it (the one-file installer, on Windows)."""
    top = f"US Train Tracker {VERSION} for {platform}"
    out = DIST / f"US-Train-Tracker-for-{platform}-v{VERSION}.zip"
    with zipfile.ZipFile(out, "w") as z:
        if platform == "Windows":
            zip_entry(z, f"{top}/Install Train Tracker.exe",
                      (DIST / f"Install-US-Train-Tracker-for-Windows-v{VERSION}.exe").read_bytes())
        else:
            with tempfile.TemporaryDirectory() as tmp:
                app = build_mac_app(Path(tmp), program_files(False))
                for f in sorted(app.rglob("*")):
                    if f.is_file():
                        zip_entry(z, f"{top}/{f.relative_to(tmp).as_posix()}", f.read_bytes(), stat.S_IMODE(f.stat().st_mode))
    print(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)")
    return out


def guide():
    """The printable guide, as the release attaches it (with the version in its name)."""
    DIST.mkdir(exist_ok=True)
    out = DIST / f"US-Train-Tracker-Install-Guide-v{VERSION}.pdf"
    shutil.copyfile(GUIDE, out)
    print(f"wrote {out.relative_to(ROOT)}")
    return out


if __name__ == "__main__":
    DIST.mkdir(exist_ok=True)
    for p in (sys.argv[1:] or ["Mac", "Windows"]):
        (build_mac if p == "Mac" else build_windows)()
        build_old_zip(p)
    if not sys.argv[1:]:
        guide()
