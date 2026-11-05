"""The Windows icon by the clock (Train Tracker.exe --tray): green while Train Tracker runs, red when it's stopped.
Drawn as the Mac menu bar's (tray.py's train_icon), at the sizes Windows uses for it.

    python3 installer/icons/make_tray_icons.py     # writes tray-on.ico and tray-off.ico here

Designed and Created by Project Moon Pi.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "src"))
from train_tracker.tray import train_icon, GREEN  # noqa: E402

RED = (235, 64, 52)
for name, colour in (("on", GREEN), ("off", RED)):
    train_icon(colour, 256).save(HERE / f"tray-{name}.ico", sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (48, 48), (64, 64)])
    print(f"wrote tray-{name}.ico")
