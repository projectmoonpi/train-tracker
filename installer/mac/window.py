"""US Train Tracker's Mac installer and uninstaller window, made like the M.O.S.S. RPi SD Card Creator's (and SkyScope's):
one window, a page at a time (Back, Next, Cancel), the Project Moon Pi patch in the corner, and the work shown step by
step on a bar that a little train runs along.

    window.py               install, update, repair or reinstall (run by "Install Train Tracker.app", from the
                            program's files inside it)
    window.py --uninstall   remove it (run by "Uninstall Train Tracker.app", from Train Tracker's own folder)
    window.py --dry-run     every page, with pretend work: nothing is installed or removed (for testing; with --auto
                            it also clicks Next / Install / Uninstall by itself; --as <version> pretends that version
                            is installed, to see the Update / Repair choices)

The work itself is install.sh / uninstall.sh beside this file; they print "@@ <percent> <text>" for each step and
"@! <note>" for the last page, and everything else goes to the log. Train Tracker is started as the installer's very
last step, and the map opens only when you click Finish (with "Open the map now" ticked).
Needs Python 3.11 or newer with Tk (python.org's has it). Designed and Created by Project Moon Pi.
"""
import glob
import math
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request

try:
    import tkinter as tk
    from tkinter import ttk
except ImportError:                                 # Apple's own python3 can lack Tk
    sys.exit("This needs Python with Tk: install Python from python.org, then try again.")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))       # the program's files: in the installer app, or Train Tracker's folder
UNINSTALL = "--uninstall" in sys.argv
DRY = "--dry-run" in sys.argv
AUTO = DRY and "--auto" in sys.argv
# Train Tracker's own Update (updates.py, once the download's signature checked out): no questions, the answers from
# the last install kept (phones, start at login, Desktop icons), the window showing its progress and closing itself
# when it's done (it stays, saying why, only if something went wrong)
UPDATE = os.environ.get("TT_UPDATE") == "1" and not UNINSTALL
APP = "Train Tracker"
TITLE = f"Uninstall {APP}" if UNINSTALL else f"Install {APP}"
CREDIT = "Designed and Created by Project Moon Pi"
SUPPORT = "support@projectmoonpi.com"              # help, on the "went wrong" page
HELP_PAGE = "https://www.projectmoonpi.com/support/"
APPDIR = os.path.expanduser("~/Library/Application Support/Train Tracker")
DATA = os.path.expanduser("~/.train-tracker")       # maps, schedules and API keys (kept unless the uninstaller deletes them)
LOG = os.path.expanduser(f"~/Library/Logs/{TITLE}.log")
WIDTH, WRAP = 580, 520                              # the window (points), the text's width
INSTALL_STEPS = [3, 8, 18, 30, 40, 55, 74, 78, 82, 86, 93, 96, 100]   # install.sh's steps (the bar creeps to the next)
UNINSTALL_STEPS = [10, 35, 70, 95, 100]


def settings():
    """What the last install wrote in settings.sh (PORT, PHONES, AUTOSTART, DESKTOP, VERSION), or {}."""
    try:
        return dict(re.findall(r"^(\w+)=\"?([^\"\n]*)\"?$", open(os.path.join(APPDIR, "settings.sh")).read(), re.M))
    except OSError:
        return {}


def version_in(path):
    try:
        return re.search(r'__version__ = "([^"]+)"', open(path).read()).group(1)
    except (OSError, AttributeError):
        return None


def installed_version():
    """The installed Train Tracker's version: settings.sh says (0.6 on), else the package in its Python environment."""
    if not os.path.isdir(APPDIR):
        return None
    if settings().get("VERSION"):
        return settings()["VERSION"]
    for f in glob.glob(os.path.join(APPDIR, "venv/lib/python3.*/site-packages/train_tracker/__init__.py")):
        return version_in(f)
    return None


def key(v):
    return tuple(int(n) for n in re.findall(r"\d+", v or "0"))


VERSION = version_in(os.path.join(ROOT, "src/train_tracker/__init__.py")) or ""
INSTALLED = installed_version()
if DRY and "--as" in sys.argv[:-1]:
    INSTALLED = sys.argv[sys.argv.index("--as") + 1]


def image(*names):
    """The first of these files that's there (they're in a different place in the installer and in Train Tracker's
    folder), or None."""
    return next((os.path.join(ROOT, n) for n in names if os.path.exists(os.path.join(ROOT, n))), None)


LOGO = image("src/train_tracker/web/img/moon-pi-logo-128.png", "installer/mac/moon-pi-logo-128.png")
ICON = image("installer/icons/uninstall-256.png") if UNINSTALL else image("installer/icons/app-256.png")


# ---- the welcome page's checks: (state, text), state ok / warn / fail
def check_mac():
    v = subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True).stdout.strip()
    major = int(v.split(".")[0] or 0)
    return ("ok", f"macOS {v}") if major >= 11 else ("fail", f"macOS {v}: Train Tracker needs macOS 11 (Big Sur) or newer")


def check_python():
    v = ".".join(map(str, sys.version_info[:3]))
    where = "python.org" if sys.executable.startswith("/Library/Frameworks/Python.framework") else sys.executable
    return ("ok", f"Python {v} ({where})") if sys.version_info >= (3, 11) else ("fail", f"Python {v}: 3.11 or newer is needed")


def check_internet():
    for url in ("https://pypi.org/simple/aiohttp/", "https://www.python.org/"):
        try:
            req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "Train Tracker installer"})
            urllib.request.urlopen(req, timeout=10).close()
            return "ok", "connected (it downloads the parts Train Tracker needs, then the train feeds)"
        except Exception:
            continue
    return "fail", "no connection: installing downloads Train Tracker's parts from the internet. Connect, then Check again."


def check_space():
    free = shutil.disk_usage(os.path.expanduser("~")).free / 1e9
    return ("ok", f"{free:.0f} GB free") if free >= 0.5 else ("fail", f"only {free * 1000:.0f} MB free: it needs about 300 MB")


def check_installed():
    if not INSTALLED:
        return "ok", "not yet: this installs it"
    if key(INSTALLED) == key(VERSION):
        return "ok", f"Train Tracker {INSTALLED} is installed: you can repair it or reinstall it from scratch"
    if key(INSTALLED) < key(VERSION):
        return "ok", f"Train Tracker {INSTALLED} is installed: this updates it to {VERSION} (your settings are kept)"
    return "warn", f"Train Tracker {INSTALLED} is installed: that's newer than this installer's {VERSION}"


CHECKS = [("This Mac", check_mac), ("Python", check_python), ("Internet", check_internet), ("Disk space", check_space),
          ("Train Tracker", check_installed)]


def modes():
    """The ways to install over the installed copy, for their own page: [(mode, button, what it does)], the
    suggested one first. Empty when it isn't installed (then it's simply installed)."""
    fresh = ("fresh", "Reinstall from scratch",
             "Removes everything Train Tracker put on this Mac, its settings and the downloaded maps and schedules too "
             "(they download again), then installs it new. Only your saved API keys are kept.")
    compare = ("Compares the installed files with this installer's and updates the ones that differ; the parts it "
               "runs on change only if this version needs them to. Your settings, maps and API keys are kept.")
    if not INSTALLED:
        return []
    if key(INSTALLED) < key(VERSION):
        return [("update", f"Update to {VERSION}", compare), fresh]
    if key(INSTALLED) == key(VERSION):
        return [("repair", "Repair",
                 "Checks every installed file and fixes any that are damaged or missing, then sets up its apps and "
                 "service again. Your settings, maps and API keys are kept."), fresh]
    return [("install", f"Install {VERSION}", compare), fresh]


class TrainBar(tk.Canvas):
    """The work's progress, 0 to 100 %: a green track with the Project Moon Pi patch riding its leading edge, and a
    little train (turning wheels, puffs of smoke) running along the part already done and into the patch, as into a
    tunnel (as the card creator's skid steer drives over its bar). It glides towards its target, and creeps on while a
    long step runs."""
    H, BAR_H, PATCH = 70, 10, 32
    SPEED, TICK = 1.4, 30
    TRAIN = 70                                      # the train's length (engine and two coaches)

    def __init__(self, master, width, dark):
        bg = ttk.Style().lookup("TFrame", "background") or "systemWindowBackgroundColor"
        super().__init__(master, width=width, height=self.H, bg=bg, highlightthickness=0)
        self.w, self.f, self.target, self.creep_to, self.since = width, 0.0, 0.0, 0.0, time.monotonic()
        self.bar_y = self.H - self.PATCH / 2 - 2
        self.top = self.bar_y - self.BAR_H / 2          # the rail the train runs on
        y1 = self.bar_y + self.BAR_H / 2
        self.create_rectangle(0, self.top, width, y1, fill="#8e8e93", outline="", stipple="gray50")   # still to go
        self.fill = self.create_rectangle(0, self.top, 0, y1, fill="#12b76a", outline="")             # done
        self.rail = self.create_line(0, self.top, 0, self.top, fill="#0b7a47", width=2)
        self.ties = []                                   # sleepers on the done part
        self.x = 0.0                                     # the engine's nose
        self.turn = 0.0                                  # the wheels' angle
        self.ticks = 0
        self.puffs = []                                  # [item, age]
        self.cars = []                                   # [(tag, left, right)] relative to the nose
        self.spokes = []                                 # [(item, cx, cy, r)] relative to the nose
        self.smoke = "#b8bcc4" if dark else "#9aa0a8"
        self.build_train(dark)
        try:
            self.patch = tk.PhotoImage(file=LOGO).subsample(4) if LOGO else None
        except tk.TclError:
            self.patch = None
        self.pt = self.create_image(self.PATCH / 2, self.bar_y, image=self.patch) if self.patch else None
        self.after(self.TICK, self.tick)

    def build_train(self, dark):
        """The engine (nose at x = 0, facing right) and two coaches behind it, drawn at x = 0; tick() moves them."""
        t = self.top
        body, cab, coach, trim = "#2e6be6", "#1d3f91", "#3b82f6", "#f5c542"
        wheel = "#d0d5dd" if dark else "#344054"
        window = "#dbeafe"

        def car(tag, left, right, parts):
            for kind, coords, opts in parts:
                getattr(self, "create_" + kind)(*coords, tags=("train", tag), **opts)
            self.cars.append((tag, left, right))

        def wheels(tag, xs):
            for cx in xs:
                cy, r = t - 3.2, 3.2
                self.create_oval(cx - r, cy - r, cx + r, cy + r, fill=wheel, outline="", tags=("train", tag))
                s = self.create_line(cx - r, cy, cx + r, cy, fill=self["bg"] if isinstance(self["bg"], str) else "#fff",
                                     width=1, tags=("train", tag))
                self.spokes.append((s, cx, cy, r - 0.6))

        # the engine: boiler, cab with a window, funnel, a cow-catcher at the nose, a yellow stripe
        car("engine", -28, 0, [
            ("rectangle", (-24, t - 15, -5, t - 6), {"fill": body, "outline": ""}),
            ("rectangle", (-28, t - 21, -18, t - 6), {"fill": cab, "outline": ""}),
            ("rectangle", (-26, t - 19, -20, t - 15), {"fill": window, "outline": ""}),
            ("rectangle", (-30, t - 23, -16, t - 21), {"fill": cab, "outline": ""}),
            ("rectangle", (-11, t - 21, -7, t - 15), {"fill": cab, "outline": ""}),
            ("polygon", (-5, t - 9, 0, t - 3, -5, t - 3), {"fill": "#d92d20", "outline": ""}),
            ("rectangle", (-24, t - 9, -5, t - 8), {"fill": trim, "outline": ""}),
        ])
        wheels("engine", (-22, -14, -8))
        # two coaches, each with windows and a stripe, coupled behind the cab
        for n, left in enumerate((-50, -72)):
            tag = f"coach{n}"
            parts = [("rectangle", (left, t - 17, left + 19, t - 6), {"fill": coach, "outline": ""}),
                     ("rectangle", (left - 0.5, t - 18, left + 19.5, t - 17), {"fill": cab, "outline": ""}),
                     ("rectangle", (left, t - 9, left + 19, t - 8), {"fill": trim, "outline": ""}),
                     ("line", (left + 19, t - 7, left + 22, t - 7), {"fill": cab, "width": 2})]
            parts += [("rectangle", (wx, t - 15, wx + 3.5, t - 11), {"fill": window, "outline": ""})
                      for wx in (left + 2.5, left + 7.8, left + 13)]
            car(tag, left, left + 22, parts)
            wheels(tag, (left + 4, left + 15))
        self.nose = 0.0                                  # where the drawing's nose is now (move() is relative)
        self.funnel = -9                                 # the funnel's middle, from the nose

    PUFF_LIFE = 44

    def fade(self, k):
        """The smoke's colour, a fraction k of the way into the window's background."""
        a = [v / 257 for v in self.winfo_rgb(self.smoke)]
        b = [v / 257 for v in self.winfo_rgb(self["bg"])]
        return "#%02x%02x%02x" % tuple(int(x + (y - x) * min(1.0, k)) for x, y in zip(a, b))

    def set(self, fraction, creep_to=None):
        """Head for `fraction`; until the next set(), creep slowly towards `creep_to` (never quite reaching it)."""
        self.target = max(self.target, min(1.0, fraction))
        self.creep_to = max(self.target, creep_to or self.target)
        self.since = time.monotonic()

    def tick(self):
        if not self.winfo_exists():
            return
        self.ticks += 1
        t = time.monotonic() - self.since
        goal = self.target + (self.creep_to - self.target) * (1 - math.exp(-t / 25)) * 0.9
        self.f += max(0.0, goal - self.f) * 0.12
        edge = self.f * self.w
        self.coords(self.fill, 0, self.top, edge, self.top + self.BAR_H)
        self.coords(self.rail, 0, self.top + 1, edge, self.top + 1)
        while len(self.ties) * 9 + 4 < edge:             # sleepers appear as the track is laid
            x = len(self.ties) * 9 + 4
            self.ties.append(self.create_line(x, self.top + 3, x, self.top + self.BAR_H - 2, fill="#0b7a47", width=2))
        if self.pt:
            self.coords(self.pt, min(max(edge, self.PATCH / 2), self.w - self.PATCH / 2), self.bar_y)

        # the train: once there's room for it, it runs from the left into the patch, then round again
        running = edge > self.TRAIN + self.PATCH
        if running:
            self.x += self.SPEED
            if self.x + min(c[1] for c in self.cars) > edge:   # all of it in the tunnel: round again
                self.x = 0.0
        else:
            self.x = 0.0
        self.move("train", self.x - self.nose, 0)
        self.nose = self.x
        tunnel = edge + self.PATCH / 2 - 3               # past here a coach would show beyond the patch
        for tag, left, right in self.cars:
            self.itemconfig(tag, state="normal" if running and self.x + right < tunnel else "hidden")
        self.turn += self.SPEED / 3.0
        for s, cx, cy, r in self.spokes:
            dx, dy = r * math.cos(self.turn), r * math.sin(self.turn)
            self.coords(s, self.x + cx - dx, cy - dy, self.x + cx + dx, cy + dy)

        # smoke: a puff from the funnel now and then, rising, spreading and fading behind the train
        fx = self.x + self.funnel
        if running and self.ticks % 9 == 0 and fx < edge - self.PATCH / 2:
            p = self.create_oval(fx - 1.5, self.top - 24, fx + 1.5, self.top - 21, fill=self.smoke, outline="")
            self.puffs.append([p, 0])
            self.tag_lower(p, "train")
        for puff in self.puffs[:]:
            item, age = puff
            puff[1] = age = age + 1
            x0, y0, x1, y1 = self.coords(item)
            grow = 0.13
            self.coords(item, x0 - grow - 0.35, y0 - grow - 0.45, x1 + grow - 0.35, y1 + grow - 0.45)
            if age % 3 == 0:                             # fading into the window (Tk on the Mac has no see-through)
                self.itemconfig(item, fill=self.fade(age / self.PUFF_LIFE))
            if age > self.PUFF_LIFE or y1 < 0:
                self.delete(item)
                self.puffs.remove(puff)
        if self.pt:
            self.tag_raise(self.pt)
        self.after(self.TICK, self.tick)


class Installer:
    def __init__(self, root):
        self.root = root
        root.withdraw()                                 # hidden until it's built and centred: no jump on opening
        root.title(f"{TITLE}  {VERSION}".strip() + ("  (dry run: nothing is changed)" if DRY else ""))
        root.geometry(f"{WIDTH}x420")
        self.events = queue.Queue()                     # from the worker threads, handled on the window's own thread
        self.working = False
        self.notes = []
        self.phones, self.autostart, self.desktop = (tk.BooleanVar(value=v) for v in self.answers())
        self.mode = tk.StringVar(value=(modes() or [("install", "")])[0][0])
        self.open_map = tk.BooleanVar(value=True)
        self.delete_data = tk.BooleanVar(value=False)

        style = ttk.Style()
        style.configure("Head.TLabel", font=("Helvetica", 18, "bold"))
        try:                                            # the Mac in dark mode? (the notes' grey must read on both)
            self.dark = bool(int(root.tk.call("tk::unsupported::MacWindowStyle", "isdark", root)))
        except (tk.TclError, ValueError):
            self.dark = False
        style.configure("Note.TLabel", foreground="#c8c8cd" if self.dark else "#3c3c43")
        style.configure("Err.TLabel", foreground="#ff453a", font=("Helvetica", 13, "bold"))
        top = ttk.Frame(root)                           # the heading, with the Project Moon Pi patch on the right
        top.pack(fill="x", padx=24, pady=(16, 6))
        self.head = ttk.Label(top, style="Head.TLabel")
        self.head.pack(side="left", anchor="s")
        try:
            if LOGO:
                self.logo = tk.PhotoImage(file=LOGO).subsample(2)
                ttk.Label(top, image=self.logo).pack(side="right")
            if ICON:
                root.iconphoto(True, tk.PhotoImage(file=ICON))   # the Dock
        except tk.TclError:                             # no picture: the window works without it
            pass
        self.body = ttk.Frame(root)
        self.body.pack(fill="both", expand=True, padx=24)
        self.msg = ttk.Label(root, style="Err.TLabel", wraplength=WRAP)
        self.msg.pack(anchor="w", padx=24, pady=(0, 6))
        bar = ttk.Frame(root)
        bar.pack(fill="x", padx=24, pady=(0, 18))
        self.cancel_b = ttk.Button(bar, text="Cancel", command=self.cancel)
        self.cancel_b.pack(side="left")
        self.next_b = ttk.Button(bar, text="Next", default="active")
        self.next_b.pack(side="right")
        self.back_b = ttk.Button(bar, text="Back")
        self.back_b.pack(side="right", padx=6)
        root.bind("<Return>", lambda e: self.next_b.instate(["!disabled"]) and self.next_b.invoke())
        root.protocol("WM_DELETE_WINDOW", self.cancel)

        if UPDATE:
            self.mode.set("update" if INSTALLED and key(INSTALLED) < key(VERSION) else "repair" if INSTALLED else "install")
            self.open_map.set(False)                    # (the map that asked for the update reconnects itself)
            self.install()
        else:
            (self.p_confirm if UNINSTALL else self.p_welcome)()
        root.update_idletasks()                         # centred on the screen (a little above the middle)
        h = max(420, root.winfo_reqheight())
        x = (root.winfo_screenwidth() - WIDTH) // 2
        y = max(30, (root.winfo_screenheight() - h) // 3)
        root.geometry(f"{WIDTH}x{h}+{x}+{y}")
        root.deiconify()
        root.after(100, self.poll)
        root.lift(); root.attributes("-topmost", True)  # in front, as it opens
        root.after(400, lambda: root.attributes("-topmost", False))
        root.focus_force()

    @staticmethod
    def answers():
        """The tick boxes as the last install left them (settings.sh), else phones yes, at login no, Desktop yes."""
        got = settings()
        return (got.get("PHONES", "yes") == "yes", got.get("AUTOSTART", "no") == "yes", got.get("DESKTOP", "yes") == "yes")

    # ---- plumbing
    def page(self, head, back=None, next_text="Next", next_cmd=None):
        self.head.config(text=head)
        for w in self.body.winfo_children():
            w.destroy()
        self.msg.config(text="")
        if not self.next_b.winfo_ismapped():            # (hidden while working)
            self.next_b.pack(side="right", **({"before": self.back_b} if self.back_b.winfo_ismapped() else {}))
        self.back_b.config(state="normal" if back else "disabled", command=back or (lambda: None))
        self.next_b.config(text=next_text, state="normal", command=next_cmd or (lambda: None))
        if AUTO and next_cmd and next_text not in ("Finish", "Close"):
            here = head
            def go():
                if self.head.cget("text") != here:
                    return
                if self.next_b.instate(["!disabled"]):
                    self.next_b.invoke()
                else:
                    self.root.after(500, go)
            self.root.after(2500, go)

    def text(self, s, style=None, pady=(0, 10)):
        ttk.Label(self.body, text=s, wraplength=WRAP, justify="left", **({"style": style} if style else {})).pack(
            anchor="w", pady=pady)

    def fit(self):
        """Tall enough for this page: grows when a page needs more room, never shrinks (the buttons stay put)."""
        self.root.update_idletasks()
        need, have = self.root.winfo_reqheight(), self.root.winfo_height()
        if need > have:
            self.root.geometry(f"{WIDTH}x{need}")

    def poll(self):
        """Run what the worker threads sent (a window can only be changed from its own thread)."""
        try:
            while True:
                self.events.get_nowait()()
        except queue.Empty:
            pass
        self.root.after(80, self.poll)

    def later(self, fn):
        self.events.put(fn)

    def cancel(self):
        if not self.working:                            # (while it's working, it finishes first)
            self.root.destroy()

    # ---- installing
    def p_welcome(self):
        self.page(TITLE, next_cmd=self.p_mode if modes() else self.p_choices)
        self.text(f"US Train Tracker {VERSION}: a live map of America's passenger trains (Amtrak, commuter rail and "
                  "metros) in your web browser. It runs quietly in the background, with a train icon in the menu bar, "
                  "and phones and tablets on your Wi-Fi can open the map too.")
        ttk.Label(self.body, text="This Mac", font=("Helvetica", 14, "bold")).pack(anchor="w", pady=(6, 2))
        self.check_box = ttk.Frame(self.body)
        self.check_box.pack(anchor="w", fill="x")
        self.recheck_b = ttk.Button(self.body, text="Check again", command=self.run_checks)
        self.recheck_b.pack(anchor="w", pady=(6, 0))
        self.text(CREDIT, "Note.TLabel", pady=(14, 0))
        self.run_checks()

    def run_checks(self):
        """Each check on its own thread (one goes over the network), its row filled in as it finishes. Next stays
        off until nothing has failed."""
        self.next_b.config(state="disabled")
        self.recheck_b.config(state="disabled")
        self.msg.config(text="")
        for w in self.check_box.winfo_children():
            w.destroy()
        self.results, self.rows = {}, {}
        for name, fn in CHECKS:
            r = ttk.Frame(self.check_box)
            r.pack(anchor="w", fill="x", pady=1)
            mark = ttk.Label(r, text="…", width=2, font=("Helvetica", 14, "bold"))
            mark.pack(side="left", anchor="n")
            ttk.Label(r, text=name, width=12, font=("Helvetica", 12, "bold")).pack(side="left", anchor="n")
            info = ttk.Label(r, text="checking...", style="Note.TLabel", wraplength=WRAP - 150, justify="left")
            info.pack(side="left", anchor="n")
            self.rows[name] = (mark, info)
            threading.Thread(target=lambda n=name, f=fn: self.later(lambda res=self.safe(f): self.show_check(n, res)),
                             daemon=True).start()
        self.fit()

    @staticmethod
    def safe(fn):
        try:
            return fn()
        except Exception as e:                          # a check that breaks says so; it doesn't stop the window
            return "fail", f"couldn't check: {e}"

    def show_check(self, name, result):
        if name not in self.rows or not self.rows[name][0].winfo_exists():
            return
        state, text = result
        mark, info = self.rows[name]
        mark.config(text={"ok": "✓", "warn": "!", "fail": "✗"}[state],
                    foreground={"ok": "#30d158", "warn": "#ff9f0a", "fail": "#ff453a"}[state])
        info.config(text=text, style="Note.TLabel" if state == "ok" else "TLabel")
        self.results[name] = state
        if len(self.results) == len(CHECKS):
            self.recheck_b.config(state="normal")
            if "fail" in self.results.values():
                self.msg.config(text="Fix the ✗ above, then Check again.")
            else:
                self.next_b.config(state="normal")
        self.fit()

    def p_mode(self):
        """Already installed: Update, Repair or Reinstall, each a button with what it does, on a page of its own."""
        self.page("Train Tracker is already installed", back=self.p_welcome)
        self.next_b.pack_forget()                        # (a button below goes on; page() brings Next back)
        if key(INSTALLED) > key(VERSION):
            self.text(f"This Mac has Train Tracker {INSTALLED}, which is newer than this installer's {VERSION}. "
                      "Cancel keeps the newer one.")
        elif key(INSTALLED) == key(VERSION):
            self.text(f"This Mac already has Train Tracker {INSTALLED}. What would you like to do?")
        else:
            self.text(f"This Mac has Train Tracker {INSTALLED}. This installer has {VERSION}. What would you like to do?")
        grid = ttk.Frame(self.body)
        grid.pack(anchor="w", fill="x", pady=(6, 0))
        first = None
        for row, (mode, label, note) in enumerate(modes()):
            b = ttk.Button(grid, text=label, width=19, command=lambda m=mode: self.chose(m),
                           default="active" if row == 0 else "normal")
            b.grid(row=row, column=0, sticky="nw", pady=(0, 16), padx=(0, 14))
            ttk.Label(grid, text=note, style="Note.TLabel", wraplength=WRAP - 215, justify="left").grid(
                row=row, column=1, sticky="nw", pady=(3, 16))
            first = first or b
        self.text("Next you choose about phones, starting at login and Desktop icons.", "Note.TLabel", pady=(0, 0))
        self.text(CREDIT, "Note.TLabel", pady=(14, 0))
        if AUTO:
            self.root.after(2500, lambda: self.head.cget("text").startswith("Train Tracker is already") and first.invoke())
        self.fit()

    def chose(self, mode):
        self.mode.set(mode)
        self.p_choices()

    def p_choices(self):
        ways = {m: (label, note) for m, label, note in modes()}
        verb = {"update": "Update", "repair": "Repair", "fresh": "Reinstall"}.get(self.mode.get(), "Install")
        self.page("Your choices", back=self.p_mode if ways else self.p_welcome, next_text=verb, next_cmd=self.install)
        if ways:
            label, note = ways[self.mode.get()]
            ttk.Label(self.body, text={"update": f"Updating Train Tracker {INSTALLED} to {VERSION}",
                                       "repair": f"Repairing Train Tracker {INSTALLED}",
                                       "fresh": f"Reinstalling Train Tracker {VERSION} from scratch"}.get(
                self.mode.get(), f"Installing Train Tracker {VERSION} over {INSTALLED}"),
                font=("Helvetica", 13, "bold")).pack(anchor="w", pady=(4, 0))
            ttk.Label(self.body, text=note + " (Back to choose differently.)", style="Note.TLabel",
                      wraplength=WRAP).pack(anchor="w")
            ttk.Separator(self.body).pack(fill="x", pady=(12, 0))
        for var, label, note in (
                (self.phones, "Phones and tablets on my Wi-Fi can open the map",
                 "Otherwise only this Mac can. The map's phone panel shows the address and a QR code."),
                (self.autostart, "Start Train Tracker by itself when I log in",
                 "Otherwise use Start Train Tracker when you want it."),
                (self.desktop, "Put Start and Stop Train Tracker on my Desktop",
                 "They're in Applications › Train Tracker either way, with Uninstall Train Tracker.")):
            ttk.Checkbutton(self.body, text="  " + label, variable=var).pack(anchor="w", pady=(8, 0))
            ttk.Label(self.body, text=note, style="Note.TLabel", wraplength=WRAP - 30).pack(anchor="w", padx=(28, 0))
        self.text("It takes a minute or two. Train Tracker starts when it's done; its first start downloads the maps "
                  "and schedules.", pady=(16, 0))
        self.fit()

    def install(self):
        mode = self.mode.get() if modes() else "install"
        self.done_mode = mode
        env = dict(os.environ, TT_PY=sys.executable, TT_MODE=mode, TT_PHONES="yes" if self.phones.get() else "no",
                   TT_AUTOSTART="yes" if self.autostart.get() else "no", TT_DESKTOP="yes" if self.desktop.get() else "no")
        head = {"update": f"Updating Train Tracker to {VERSION}", "repair": "Repairing Train Tracker",
                "fresh": f"Reinstalling Train Tracker {VERSION}"}.get(mode, f"Installing Train Tracker {VERSION}")
        self.work(head, os.path.join(HERE, "install.sh"), env, INSTALL_STEPS, self.p_installed)

    def p_installed(self, ok, tail):
        if not ok:
            return self.p_failed("Train Tracker wasn't installed", tail)
        mode = self.done_mode
        head, was = {"update": ("Train Tracker is updated", f"updated from {INSTALLED} to {VERSION}"),
                     "repair": ("Train Tracker is repaired", "repaired"),
                     "fresh": ("Train Tracker is reinstalled", "reinstalled from scratch")}.get(
            mode, ("Train Tracker is installed", "installed"))
        self.page(head, next_text="Finish", next_cmd=self.finish)
        self.back_b.pack_forget()
        self.cancel_b.pack_forget()
        self.text(f"US Train Tracker {VERSION} is {was}, and running.")
        self.text("While it runs, its train icon is in the menu bar at the top of the screen: click it for the map, the "
                  "API keys or Stop Train Tracker. Start, Stop and Uninstall Train Tracker are in Applications › Train "
                  "Tracker" + (", and Start and Stop on your Desktop." if self.desktop.get() else "."))
        if self.phones.get():
            self.text("If macOS asks whether Train Tracker may accept incoming network connections, click Allow, so "
                      "phones can reach it.", "Note.TLabel")
        for n in self.notes:
            self.text(n, "TLabel")
        self.text("You can delete the downloaded installer now.", "Note.TLabel")
        ttk.Checkbutton(self.body, text="  Open the map now", variable=self.open_map).pack(anchor="w", pady=(8, 0))
        self.text(CREDIT, "Note.TLabel", pady=(16, 0))
        self.fit()
        if UPDATE:
            self.root.after(4000, self.finish)          # (an update from Train Tracker: nothing to click)

    def finish(self):
        if not UNINSTALL and self.open_map.get() and not DRY:
            subprocess.run(["open", f"http://127.0.0.1:{settings().get('PORT', '7500')}"])
        self.root.destroy()

    # ---- uninstalling
    def p_confirm(self):
        self.page(TITLE, next_text="Uninstall", next_cmd=self.uninstall)
        self.text("Remove US Train Tracker from this Mac?")
        self.text("It stops Train Tracker and removes the program, its settings, Start, Stop and Uninstall Train "
                  "Tracker, and their Desktop icons. Python stays, for anything else that uses it.")
        if os.path.isdir(DATA) or DRY:
            ttk.Checkbutton(self.body, text="  Also delete the downloaded maps and schedules, and any API keys I saved",
                            variable=self.delete_data).pack(anchor="w", pady=(4, 0))
            self.text("Leave it unticked to keep them: installing Train Tracker again uses them.", "Note.TLabel")
        self.text("The first time, macOS may ask whether Uninstall Train Tracker may access your Desktop folder: click "
                  "Allow, so it can remove the icons there.", "Note.TLabel")
        self.text(CREDIT, "Note.TLabel", pady=(14, 0))
        self.fit()

    def uninstall(self):
        env = dict(os.environ, TT_WINDOW="1", TT_DELETE_DATA="yes" if self.delete_data.get() else "no")
        if os.path.isdir(DATA) and not self.delete_data.get():
            self.notes.append("Your maps, schedules and API keys are kept (in ~/.train-tracker): installing Train "
                              "Tracker again uses them.")
        self.work("Removing Train Tracker", os.path.join(HERE, "uninstall.sh"), env, UNINSTALL_STEPS, self.p_removed)

    def p_removed(self, ok, tail):
        if not ok:
            return self.p_failed("Train Tracker wasn't fully removed", tail)
        self.page("Train Tracker is removed", next_text="Close", next_cmd=self.root.destroy)
        self.back_b.pack_forget()
        self.cancel_b.pack_forget()
        self.text("US Train Tracker has been removed from this Mac. Python is still installed.")
        for n in self.notes:
            self.text(n, "TLabel")
        self.text(CREDIT, "Note.TLabel", pady=(16, 0))
        self.fit()

    # ---- the work, either way
    def work(self, head, script, env, steps, then):
        self.page(head)
        self.working = True
        self.cancel_b.config(state="disabled")          # from here on, nothing to click until it's done
        self.back_b.pack_forget()
        self.next_b.pack_forget()
        self.status = ttk.Label(self.body, text="Getting ready...", wraplength=WRAP)
        self.status.pack(anchor="w", pady=(4, 8))
        self.bar = TrainBar(self.body, WRAP, self.dark)
        self.bar.pack(anchor="w", pady=4)
        self.bar.set(0.0, steps[0] / 100)
        self.details_b = ttk.Button(self.body, text="Show details", command=self.toggle_details)
        self.details_b.pack(anchor="w", pady=(10, 0))
        self.details = ttk.Frame(self.body)
        self.log = tk.Text(self.details, height=10, width=76, font=("Menlo", 9), relief="flat", bg="#1e1e1e",
                           fg="#9a9a9a", padx=8, pady=6, highlightthickness=0)   # a quiet console: small, grey
        sb = ttk.Scrollbar(self.details, command=self.log.yview)
        self.log.config(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        self.log.pack(side="left", fill="both", expand=True)
        self.log.tag_config("step", foreground="#e8e8e8", font=("Menlo", 9, "bold"))   # each step's heading
        self.log.tag_config("note", foreground="#ffcc00")
        ttk.Label(self.body, text=f"Everything is also kept in the log: {LOG.replace(os.path.expanduser('~'), '~')}",
                  style="Note.TLabel", wraplength=WRAP).pack(anchor="w", side="bottom", pady=(6, 0))
        self.fit()
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write(f"\n===== {time.strftime('%Y-%m-%d %H:%M:%S')}  {TITLE} {VERSION} =====\n")
        threading.Thread(target=self.run, args=(script, env, steps, then), daemon=True).start()

    def toggle_details(self):
        if self.details.winfo_ismapped():
            self.details.pack_forget()
            self.details_b.config(text="Show details")
        else:
            self.details.pack(anchor="w", fill="both", pady=(6, 0), after=self.details_b)
            self.details_b.config(text="Hide details")
        self.fit()

    def show(self, text, tag=None):
        """A line in the details box (the steps' headings stand out; the work under them is grey)."""
        if self.log.index("end-1c") == "1.0":
            text = text.lstrip("\n")
        self.log.insert("end", text + "\n", tag or ())
        self.log.see("end")

    def run(self, script, env, steps, then):
        tail = []
        try:
            if DRY:                                     # pretend: each step, a moment apiece
                env = dict(env, TT_STEPS=" ".join(map(str, steps)))
                cmd = ["/bin/bash", "-c", 'for s in $TT_STEPS; do echo "@@ $s Pretending (dry run): step $s%..."; '
                       'echo "nothing is changed"; sleep 1.6; done']
            else:
                cmd = ["/bin/bash", script]
            p = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 stdin=subprocess.DEVNULL, text=True, bufsize=1, cwd=os.path.expanduser("~"))
            with open(LOG, "a") as log:
                for line in p.stdout:
                    line = line.rstrip("\n")
                    log.write(line + "\n"); log.flush()
                    m = re.match(r"@@ (\d+) (.*)", line)
                    if m:
                        pct, what = int(m.group(1)), m.group(2)
                        nxt = next((s for s in steps if s > pct), 100)
                        self.later(lambda w=what, a=pct, b=nxt: (self.status.config(text=w), self.bar.set(a / 100, b / 100),
                                                                 self.show(f"\n▸ {w}", "step")))
                    elif line.startswith("@! "):
                        self.notes.append(line[3:])
                        self.later(lambda t=line[3:]: self.show(f"  Note: {t}", "note"))
                    else:
                        tail = (tail + [line])[-12:]
                        self.later(lambda t=line: self.show("  " + t))
            ok = p.wait() == 0
        except Exception as e:
            tail, ok = tail + [str(e)], False
        self.later(lambda: self.done(ok, tail, then))

    def done(self, ok, tail, then):
        self.working = False
        self.cancel_b.config(state="normal")
        if ok:
            self.bar.set(1.0)
            self.root.after(700, lambda: then(ok, tail))  # (a moment to see the bar full)
        else:
            then(ok, tail)

    def p_failed(self, head, tail):
        self.page(head, next_text="Close", next_cmd=self.root.destroy)
        self.back_b.pack_forget()
        self.text("Something went wrong:" if tail else "Something went wrong.")
        if tail:
            box = tk.Text(self.body, height=8, width=76, font=("Menlo", 9), relief="flat", bg="#1e1e1e", fg="#d0d0d0",
                          padx=8, pady=6, highlightthickness=0)
            box.insert("end", "\n".join(tail))
            box.config(state="disabled")
            box.pack(anchor="w", fill="x", pady=(0, 10))
        self.text(f"The whole story is in {LOG.replace(os.path.expanduser('~'), '~')}. "
                  + ("Check the internet connection, then run the installer again." if not UNINSTALL else
                     "You can run Uninstall Train Tracker again."))
        ttk.Button(self.body, text="Show the log", command=lambda: subprocess.run(["open", "-R", LOG])).pack(anchor="w")
        self.text(f"Need help? Email {SUPPORT} (with the log, if you can) or see www.projectmoonpi.com/support.",
                  pady=(12, 0))
        row = ttk.Frame(self.body)
        row.pack(anchor="w")
        ttk.Button(row, text="Email support", command=lambda: subprocess.run(
            ["open", f"mailto:{SUPPORT}?subject={TITLE.replace(' ', '%20')}%20problem"])).pack(side="left")
        ttk.Button(row, text="Help page", command=lambda: subprocess.run(["open", HELP_PAGE])).pack(side="left", padx=(8, 0))
        self.fit()


def main():
    root = tk.Tk()
    Installer(root)
    root.mainloop()


if __name__ == "__main__":
    main()
