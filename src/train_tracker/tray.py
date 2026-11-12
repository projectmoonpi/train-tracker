"""Train Tracker's icon in the Mac menu bar or the Windows taskbar (by the clock), there while Train Tracker
runs in the background and gone when it stops. On a Mac it's drawn like the menu bar's other icons (black or
white to suit a light or dark menu bar), faint if Train Tracker stops answering; on Windows it's green, grey
if Train Tracker stops answering. Its menu opens the map or the API keys page, or stops Train Tracker.

Started by `train-tracker --tray` (the installed copies do this) and gone again when the server stops. Needs
pystray and Pillow (and PyObjC on a Mac), which the installers add; without them the server simply runs
without the icon.

    python -m train_tracker.tray --port 7500 --parent <the server's process id>

Designed and Created by Project Moon Pi.
"""
import argparse
import json
import os
import signal
import subprocess
import sys
import threading
import time
import urllib.request
import webbrowser
from datetime import datetime
from pathlib import Path

POLL_S = 3
GREEN = (61, 220, 132)
GREY = (138, 138, 138)
CLEAR = (0, 0, 0, 0)


def train_icon(color, size=64, opacity=1.0):
    """The front of a train: body, windscreen, two headlights and the legs down to the rails, on clear."""
    from PIL import Image, ImageDraw
    w = size * 4
    img = Image.new("RGBA", (w, w), CLEAR)
    d = ImageDraw.Draw(img)
    ink = tuple(color) + (255,)
    f = lambda *v: [round(x * w) for x in v]    # fractions of the icon -> pixels

    leg = round(w * 0.08)
    d.line(f(0.31, 0.74, 0.19, 0.96), fill=ink, width=leg)
    d.line(f(0.69, 0.74, 0.81, 0.96), fill=ink, width=leg)
    d.rounded_rectangle(f(0.17, 0.04, 0.83, 0.80), radius=round(w * 0.17), fill=ink)
    # cut-outs (drawing clear replaces the pixels)
    d.rounded_rectangle(f(0.28, 0.15, 0.72, 0.43), radius=round(w * 0.05), fill=CLEAR)
    for cx in (0.34, 0.66):
        d.ellipse(f(cx - 0.065, 0.585, cx + 0.065, 0.715), fill=CLEAR)
    if opacity < 1:
        img.putalpha(img.getchannel("A").point(lambda a: round(a * opacity)))
    return img.resize((size, size), Image.LANCZOS)


def sharp_on_retina(icon, points=18):
    """pystray gives the Mac menu bar a picture one pixel per point, which a Retina screen blurs; this gives
    it twice that, shown at the usual size."""
    import io
    import AppKit
    import Foundation
    from PIL import Image

    def assert_image():
        if icon._icon_image is not None:
            return
        b = io.BytesIO()
        icon._icon.resize((points * 2, points * 2), Image.LANCZOS).save(b, "png")
        image = AppKit.NSImage.alloc().initWithData_(Foundation.NSData(b.getvalue()))
        image.setSize_((points, points))
        image.setTemplate_(True)    # macOS colours it to suit a light or dark menu bar
        icon._icon_image = image
        icon._status_item.button().setImage_(image)

    icon._assert_image = assert_image


def alive(pid):
    if sys.platform == "win32":
        import ctypes
        k = ctypes.windll.kernel32
        h = k.OpenProcess(0x00100000, False, pid)    # SYNCHRONIZE
        if not h:
            return False
        try:
            return k.WaitForSingleObject(h, 0) == 0x102    # WAIT_TIMEOUT: still running
        finally:
            k.CloseHandle(h)
    try:
        os.kill(pid, 0)    # (on Windows this would end the process, hence the above)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    return True


def installed_dir():
    """The installed copy's folder (the one holding venv), or None when run some other way."""
    app = Path(sys.prefix).parent
    if sys.platform == "darwin" and app == Path.home() / "Library/Application Support/Train Tracker":
        return app
    if sys.platform == "win32" and ((app / "Train Tracker.exe").exists() or (app / "stop.ps1").exists()):
        return app
    return None


class Tray:
    def __init__(self, port, parent):
        self.port = port
        self.parent = parent
        self.base = f"http://127.0.0.1:{port}"
        self.info = None    # the last /api/info, or None if it didn't answer
        self.stopping = False
        self.icon = None
        self.marker = (installed_dir() or Path.home() / ".train-tracker") / "tray-shown"

    def fetch(self):
        try:
            with urllib.request.urlopen(self.base + "/api/info", timeout=2) as r:
                return json.load(r)
        except (OSError, ValueError):
            return None

    # menu text, worked out when the menu is shown
    def headline(self, _item=None):
        if self.stopping:
            return "Train Tracker is stopping…"
        if self.info is None:
            return "Train Tracker isn't answering"
        return f"Train Tracker {self.info.get('version', '')} is running"

    def detail(self, _item=None):
        s = self.info
        if not s or self.stopping:
            return "Its messages are in the log file"
        since = datetime.fromtimestamp(s.get("since", time.time()))
        since = since.strftime("%#I:%M %p" if sys.platform == "win32" else "%-I:%M %p").lower()
        n = s.get("trains", 0)
        return f"Since {since} · {n} train{'' if n == 1 else 's'} on the map"

    def phones(self, _item=None):
        url = (self.info or {}).get("phone_url")
        return f"Phones: {url}" if url else "This computer only (no phones)"

    def open_map(self, *_):
        webbrowser.open(self.base)

    def open_keys(self, *_):
        webbrowser.open(self.base + "/settings.html")

    def update_text(self, _item=None):
        return f"Get Train Tracker {(self.info or {}).get('update')}…"

    def has_update(self, _item=None):
        return bool((self.info or {}).get("update")) and not self.stopping

    def open_update(self, *_):
        webbrowser.open(self.base + "/#updates")     # (About › Updates: Update to <version>)

    def stop(self, *_):
        """As the Stop Train Tracker icon does (with its message), or just ends the server if this isn't an
        installed copy."""
        self.stopping = True
        self.icon.update_menu()
        app = installed_dir()
        mac_stop = next((p for p in (Path("/Applications"), Path.home() / "Applications")
                         if (p / "Train Tracker/Stop Train Tracker.app").exists()), Path("/Applications"))
        mac_stop = mac_stop / "Train Tracker/Stop Train Tracker.app/Contents/Resources/run.sh"
        if app and sys.platform == "darwin" and mac_stop.exists():
            subprocess.Popen([str(mac_stop)], start_new_session=True)
        elif app and sys.platform == "win32" and (app / "Train Tracker.exe").exists():
            # the installed copy's own program (Stop Train Tracker's shortcut opens it too); DETACHED_PROCESS: it
            # outlives this one
            subprocess.Popen([str(app / "Train Tracker.exe"), "--stop"], creationflags=0x00000008)
        else:
            try:
                os.kill(self.parent, signal.SIGTERM)
            except OSError:
                pass

    def first_time(self):
        """Once: say where the icon is (Windows tucks new ones under the ^ by the clock)."""
        if self.marker.exists():
            return
        try:
            self.icon.notify("Train Tracker is running in the background. Click its train icon by the clock for "
                             "the map, the API keys or to stop it.", "Train Tracker")
            self.marker.parent.mkdir(parents=True, exist_ok=True)
            self.marker.touch()
        except (OSError, NotImplementedError):
            pass

    def watch(self):
        """Keeps the icon and menu current; leaves when the server has gone."""
        lit = self.info is not None
        while alive(self.parent):
            self.info = self.fetch()
            if (self.info is not None) != lit:
                lit = self.info is not None
                self.icon.icon = self.on if lit else self.off
            self.icon.title = self.headline()
            self.icon.update_menu()
            time.sleep(POLL_S)
        self.icon.stop()

    def run(self):
        import pystray
        from pystray import Menu, MenuItem as Item
        if sys.platform == "darwin":
            self.on, self.off = train_icon((0, 0, 0)), train_icon((0, 0, 0), opacity=0.35)
        else:
            self.on, self.off = train_icon(GREEN), train_icon(GREY)
        self.info = self.fetch()
        menu = Menu(
            Item(self.headline, None, enabled=False),
            Item(self.detail, None, enabled=False),
            Item(self.phones, None, enabled=False),
            Menu.SEPARATOR,
            Item("Open the map", self.open_map, default=True),
            Item("Settings…", self.open_keys),
            Item(self.update_text, self.open_update, visible=self.has_update),   # (a newer Train Tracker)
            Menu.SEPARATOR,
            Item("Stop Train Tracker", self.stop, enabled=lambda _i: not self.stopping),
        )
        self.icon = pystray.Icon("Train Tracker", self.on if self.info is not None else self.off,
                                 self.headline(), menu)
        if sys.platform == "darwin":
            sharp_on_retina(self.icon)
            import AppKit
            # menu bar only: no Python icon in the Dock or the app switcher
            AppKit.NSApplication.sharedApplication().setActivationPolicy_(AppKit.NSApplicationActivationPolicyAccessory)

        def setup(icon):
            icon.visible = True
            if sys.platform == "win32":
                self.first_time()
            threading.Thread(target=self.watch, name="tray-watch", daemon=True).start()

        self.icon.run(setup)


def main(argv=None):
    p = argparse.ArgumentParser(prog="train-tracker-tray", description="Train Tracker's menu bar / taskbar icon")
    p.add_argument("--port", type=int, default=7500)
    p.add_argument("--parent", type=int, default=os.getppid(), help="leave when this process ends")
    a = p.parse_args(argv)
    try:
        import pystray  # noqa: F401
        import PIL  # noqa: F401
    except ImportError as exc:
        print(f"Train Tracker's menu bar icon isn't available ({exc.name} isn't installed)", file=sys.stderr)
        return 1
    Tray(a.port, a.parent).run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
