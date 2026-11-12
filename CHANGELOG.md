# Changelog

All notable changes to this project are listed here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.12] - 2026-11-12

- Updates are signed: every release's downloads carry a signature made with Project Moon Pi's private key, and
  **Update to <version>** installs only a download whose signature checks out against the key built into Train
  Tracker (Ed25519, checked in plain Python). Anything unsigned, changed or signed by another key is refused.
- **Update to <version>** installs with no questions: the installer runs in update mode, keeping the answers from
  the last install (phones, start at log-in, Desktop icons), shows its progress and closes by itself.
- **Phones and tablets** on or off in Settings (the API keys page, now called Settings), from the computer running
  Train Tracker only. It takes effect straight away; on Windows, turning it on makes sure the firewall lets phones
  in (Windows asks an administrator once, if needed). Updates keep the choice.
- Releases: the Release workflow builds a draft; tools/sign_release.py signs it on the developer's Mac, publishes it
  and removes the older releases.

## [1.0.11] - 2026-11-11

- Told when there's a newer Train Tracker: a note at the top of the map's panel (dismissed per version), a
  **Get Train Tracker <version>…** item in the Mac menu bar icon's menu, and on Windows a notice from the icon by
  the clock, once per version (click it to update), with **Update to Train Tracker <version>...** in its menu. Each
  opens About › Updates, whose **Update to <version>** does the rest.

## [1.0.10] - 2026-11-11

- Windows installer: it no longer installs into the Desktop, Documents, Downloads or OneDrive folders. Ransomware
  protection (Bitdefender's Safe Files, Windows' Controlled folder access) and OneDrive syncing kept Train Tracker
  from saving its settings there ("Permission denied"); it says so and suggests the usual folder. An update of a copy
  already in one of those folders suggests the usual folder too.

## [1.0.9] - 2026-11-10

- The new Project Moon Pi badge: the patch without the red swoosh, everywhere it appears (the start-up splash and
  its light show, whose lens flare now runs round the badge's outer ring and bursts on the π, the map's panel and
  About, the browser and home-screen icons, the installer and its progress bar, the Start, Stop, Uninstall and app
  icons, and the installation guide).

## [1.0.8] - 2026-11-06

- Help and contact by email and on Project Moon Pi's website: **support@projectmoonpi.com** for help and bug
  reports, **sales@projectmoonpi.com** for anything else, and **www.projectmoonpi.com** (where the downloads are
  too). They're in the map's About and credits, the README (a new Help and contact section), the installation
  guide and its PDF (cover, footer and "Still stuck?"), and the READ ME FIRST in the Mac download. When the Mac or
  Windows installer can't finish, its message says where to get help (on the Mac, with Email support and Help
  page buttons). Settings > Apps on Windows links to the website and the support page.

## [1.0.7] - 2026-11-05

- Windows installer: its progress bar now matches the Mac installer's: the Project Moon Pi patch rides the bar's
  leading edge, and a little train (turning wheels, puffs of smoke) lays its track and runs into the patch.

## [1.0.6] - 2026-11-05

- Windows installer: while it opens the firewall for phones, it says **Finishing setting up Train Tracker...** (the
  longer line was cut off).

## [1.0.5] - 2026-11-05

- **Windows: the firewall note matches what Windows will do.** Before opening the firewall for phones, the
  installer checks Windows' User Account Control setting: no "click Yes" note when Windows gives admin rights
  without asking ("Never notify", or UAC off); the usual note on a normal PC; an administrator's-password note on an
  account that isn't an administrator; and "If Windows asks…" when it can't tell. The uninstaller's note too.

## [1.0.4] - 2026-11-05

- **Windows: the train icon by the clock stays.** It's green while Train Tracker runs and turns red when it's
  stopped, instead of going away, so you can start it again from there. Click it for the map; right-click it for
  **Open the map**, **Start Train Tracker Service** and **Stop Train Tracker Service**. (It's now part of Train
  Tracker.exe, so pystray and Pillow are no longer installed on Windows.)
- **Windows: Open, Start and Stop.** The Start menu (and the Desktop, if you choose) has **Open Train Tracker**
  (opens the map, starting the service first if needed), **Start Train Tracker Service** and **Stop Train Tracker
  Service** (they only start and stop it in the background).
- **Windows: no Remove shortcut.** Train Tracker is uninstalled from Settings › Apps, like other programs.

## [1.0.3] - 2026-11-05

- **One file to download, as with Aviator Trail.** On Windows the download is the installer itself
  (**Install-US-Train-Tracker-for-Windows-v<version>.exe**), carrying Train Tracker inside it: no zip to extract,
  just double-click it. On a Mac it's a disk image (**US-Train-Tracker-for-Mac-v<version>.dmg**) with **Install
  Train Tracker**, the guide and a READ ME. Uninstalling is unchanged. **Update to <version>** uses the new files;
  zips are still attached for 1.0.2's Update button.
- The Windows installer's last page never cuts its text off (the window grows if it needs to), and shows an &.

## [1.0.2] - 2026-11-04

- **Update from inside Train Tracker.** The map's *About and credits* now has **Updates**: it says when there's a
  newer version (**Check now** asks GitHub at once), and on the computer running Train Tracker, **Update to
  <version>** downloads it in the background, checks it's the file GitHub published (its SHA-256), unpacks it and
  opens its installer in front, ready for you to click **Update**. Your settings, maps and API keys are kept.
- The Windows installer's window opens in front of the browser and stays on top until it's clicked.

## [1.0.1] - 2026-11-04

- The downloads now have the version in their names, so you can tell which Train Tracker you have:
  **US-Train-Tracker-for-Mac-v1.0.1.zip**, **US-Train-Tracker-for-Windows-v1.0.1.zip** and
  **US-Train-Tracker-Install-Guide-v1.0.1.pdf**, and the folder inside each zip is **US Train Tracker 1.0.1 for
  Mac** (or Windows). The download links in the README and the guide go to each new release's files.

## [1.0.0] - 2026-11-04

- **1.0.0: Train Tracker's first production release.** It's out of testing.
- Windows installer rewritten as compiled programs (Install Train Tracker.exe, Uninstall Train Tracker.exe and
  Train Tracker.exe), with no PowerShell: Bitdefender Free's Advanced Threat Defense blocked the old hidden
  PowerShell installer as malware. The window, pages and Update / Repair / Reinstall from scratch work as
  before. Train Tracker.exe starts and stops Train Tracker and is what Task Manager shows; the firewall rule
  for phones is set without PowerShell. Tested with Bitdefender and Windows Defender: no detections.

- Installers (Mac and Windows): the three ways to install over an existing Train Tracker now each do their own
  job. **Update** compares the installed files with the new installer's (listing what changed, what's new and
  what's no longer needed) and updates those; the parts it runs on change only where the new version needs them
  to. **Repair** checks every installed file against the fingerprint pip recorded when it installed it, installs
  again only the packages with damaged or missing files (its whole Python set-up, if that doesn't fix them), then
  sets up the apps, shortcuts and service again. **Reinstall from scratch** removes everything Train Tracker put
  on the computer (program, Python set-up, settings, apps and shortcuts, service, log, the downloaded maps and
  schedules) except the saved API keys, then installs it new. The last page says what Repair and Update found. On the Mac, Update, Repair and Reinstall are buttons on a page of their own, each with what it does,
  before the page with the phones, login and Desktop choices.
  (installer/filecheck.py does the checking.)

- Mac installer: **Install Train Tracker** is now an app with the train icon and its own window, made like the
  M.O.S.S. RPi SD Card Creator's and SkyScope's. No more Terminal window. It checks the Mac first (macOS, Python,
  internet, disk space, what's installed); offers **Update**, **Repair** or **Reinstall from scratch** when Train
  Tracker is already there; asks about phones, start at login and Desktop icons on one page; then shows each step
  on a progress bar that a little train runs along, into the Project Moon Pi patch. Train Tracker starts as the
  last step, and the map opens only from Finish. Without Python 3.11 or newer with Tk, it offers python.org's
  first. Uninstall Train Tracker uses the same window, with a tick box to also delete the maps and API keys. The
  installer app is no longer changed by installing (pip builds from a copy).
- Windows: if the installer stops before its window opens, Install Train Tracker says why (the end of its log)
  instead of seeming to do nothing.
- The release's downloads are built on macOS (the Mac installer app needs macOS's own tools).

- In a virtual machine on its program's own private network (VMware's NAT, VirtualBox's, Parallels' Shared
  network, Hyper-V's Default Switch), phones on the Wi-Fi can't reach Train Tracker's address: "Open on your
  phone" now says so instead of showing a QR code that can't work, and how to put the virtual machine on the home
  network (Bridged) in that VM program. A virtual machine on the home network still gets its QR code, with a
  note in case the phone can't connect.

- The map page no longer downloads anything to start: MapLibre GL JS 6.16.0 and the QR code maker come with
  Train Tracker (web/vendor). With no internet the page still opens and says live trains and the background
  map need it (and says so again if the connection drops, and when it's back).
- Clearer messages instead of "This browser is too old": if the browser can't draw the map because its WebGL
  graphics are off (Firefox on a virtual machine without graphics support, for example), it says so and what to
  do, in a steady box under the logo (a heading, what's wrong and numbered steps; no pulsing small print). The
  logo plays either way.
- Windows installer: when Train Tracker is already installed it says which version, and offers **Update** (this
  one's newer), **Repair** (the same version: installs it again and rebuilds its Python set-up) or **Reinstall
  from scratch** (removes the program first; your maps and API keys are kept); for an older installer it warns
  and Cancel keeps the newer one. The tick boxes start as the installed copy has them.
- Firefox's real fix for "can't draw the map" (about:config › webgl.force-enabled), instead of a Settings option
  current Firefox doesn't have.
- Windows installer: checks for the internet before changing anything; without it, it says installing needs
  the internet and nothing was changed. If an update fails after stopping a running Train Tracker, that copy is
  started again. Updating pip no longer stops the install.

- Mac: Uninstall Train Tracker now removes its icons from the Desktop too. macOS silently stopped it before; it
  now asks once for your OK (Start, Stop and Uninstall are small AppleScript apps that macOS knows by name).
- Mac: Start, Stop and Uninstall are in the main **Applications › Train Tracker** folder (the one Finder shows),
  or your own Applications folder if your account can't add to the main one. An older install's folder in your
  own Applications folder is removed when you update.
- No more setuptools warning about the licence field during install.
- Windows: the installer is a proper window with the Project Moon Pi logo: choose phones and start-at-sign-in
  with tick boxes, watch a smooth progress bar (with the Python download's real progress), and click Finish to
  open the map (it no longer pops up over everything). No console window. It's started by **Install Train
  Tracker.exe**, which has the train icon (a .bat file can't have one); the .bat is gone. Uninstall uses the
  same window, with a progress bar until it's done. The installer logs to %TEMP%\Train Tracker install.log.
- Choose where it's installed on Windows (Install in, with Browse...). New installs suggest
  `%LOCALAPPDATA%\Programs\Project Moon Pi\Train Tracker`, where Windows keeps one user's programs, with Project
  Moon Pi's other apps; an update goes back where it was. A folder that already holds other things gets a Train Tracker folder
  inside it, so uninstalling can't take anything else with it.
- Desktop icons are optional (a tick box on Windows, a question on the Mac), and Uninstall is no longer on the
  Desktop: it's in Applications › Train Tracker on the Mac; on Windows it's **Remove Train Tracker** in the
  Start menu (Windows hides Start menu items named Uninstall), and **Uninstall Train Tracker.exe** in the
  install folder and beside the installer in the downloaded folder (it finds the installed copy).
  The Start menu's Remove shortcut gets a fresh command on every install, as Windows otherwise kept hiding it
  after an uninstall and reinstall.
- Windows: uninstalling now removes the install folder itself (an empty folder used to stay behind, held by the
  uninstaller's own process), and the Project Moon Pi folder once it's empty.
- Windows: before Windows asks "Do you want to allow this app to make changes to your device?" for Windows
  PowerShell (opening the firewall for phones when installing, or closing it when uninstalling), a note says
  what it's for and to click Yes.

## [0.5.0] - 2026-10-31

- You can see when it's running: a train icon in the Mac menu bar or by the Windows clock while Train Tracker
  runs (`--tray`, needs pystray and Pillow, which the installers add). Its menu shows the version, since when
  and how many trains are on the map, and the address for phones, and opens the map or the API keys page, or
  stops Train Tracker. It fades (Mac) or turns grey (Windows) if the server stops answering, and goes away when
  it stops. On Windows it says once where the icon is.
- Activity Monitor and Task Manager list it as **Train Tracker** instead of Python.
- Start Train Tracker says if it's already running; Stop Train Tracker says if it wasn't.
- `/api/info` also gives when the server started and how many trains are on the map.
- An **Uninstall Train Tracker** icon on the Desktop too (a grey trash-can badge), beside Start and Stop. On
  Windows it's also listed in **Settings › Apps** (US Train Tracker, Project Moon Pi), whose Uninstall button
  runs the same clean uninstaller.
- Windows: installs in `%LOCALAPPDATA%\Train Tracker` (was `TrainTracker`); an install in the old folder is
  moved over by running the installer.
- Windows installer: finds Python even when it was installed after the window you started the installer from
  was opened (it used to offer to install Python again).

## [0.4.1] - 2026-10-31

- No Python yet? The Mac and Windows installers now offer to install Python 3.14 from python.org, after
  checking it's the expected download, signed by the Python Software Foundation (and notarized by Apple on a
  Mac). On Windows it installs just for the user, with no admin permission needed. `TT_PYTHON=yes|no` answers
  the question ahead for unattended installs.
- Running the installer again rebuilds Train Tracker's own Python environment if the Python it was set up with
  has been removed or is older than 3.11, instead of failing.
- The Installation Guide no longer has a separate "Install Python" step.

## [0.4.0] - 2026-10-30

- The map runs on MapLibre GL JS 6.16 (from 4.7.1), loaded as a module. It needs a browser with WebGL 2:
  any current Safari, Chrome, Edge or Firefox (iPhone and iPad: iOS 16.4 or newer). An older browser now gets
  a message saying so instead of a blank map.
- Needs Python 3.11 or newer (3.10 is out of security support). Tested on Python 3.11 to 3.15.

## [0.3.0] - 2026-10-29

- Installation Guide (docs/INSTALL.md and a printable PDF): Mac, Windows, Raspberry Pi, iPhone and Android,
  with machine requirements and how it works; the README now leads with both.
- Installers for Mac (`Install Train Tracker.command`) and Windows (`Install Train Tracker.bat`): set it up as a
  background service, ask about phones and starting at log-in, and add **Start Train Tracker** and **Stop Train
  Tracker** icons (Desktop, and Applications or the Start menu) plus an uninstaller. Run again to update.
- `--open` opens the browser once the server is up; `--log-file` writes messages to a file.
- "Open on your phone" in the panel: the address and a QR code, when the server listens on the network.
- Add to Home Screen: app icon and web app manifest, so the map opens full screen like an app on iPhone.
- Windows: with phones allowed, the installer opens the firewall for Train Tracker's port on home (Private)
  networks, asking for admin permission only if a change is needed, and warns when the network is set to
  Public; the uninstaller closes it again. Tested in a Windows 10 VM.
- Separate **Download for Mac** and **Download for Windows** zips on every release (permanent links in the
  README), each with its installer, the app, a READ ME FIRST note and the printable guide.
- Raspberry Pi service file (tools/train-tracker@.service) to start at power-on.
- Works with python.org's Python on macOS without its "Install Certificates" step (certificates from certifi).
- Separate prediction feeds are fetched once a minute, cutting data use to about 130 MB an hour.
- Next stop, predicted time and how late each train is running, from each railroad's trip updates (worked
  out against the timetable where the feed only gives times).
- Stations from every railroad's schedule; click one for its next trains. Search finds stations.
- Service alerts in the panel and in train and station popups.
- Follow a train, and share links to a train (`#train=`) or the current view (`#map=`).
- Trails: where each train has been over the last 15 minutes.
- Colour trains by lateness.
- New railroads: MARC, VRE, RTD Denver commuter rail and CapMetro Rail (Austin), no keys needed.
- Each railroad's schedule loads in the background (rail only, parsed copy cached), so start-up no longer waits.
- The map opens with the lower 48 fitted beside the panel (or above it on a phone) at any window size, and
  stays fitted while the window settles or is resized, until you move the map.
- A "More" prompt with a bobbing arrow at the bottom of the side panel and the API keys page while there's
  more to read below; click it to scroll down.

## [0.2.0] - 2026-10-28

- Freight and other active track (main lines, industrial track, sidings, yards) from NARN, loaded by area
  from city-level zoom and cached on disk.
- Map layers filters: turn each kind of passenger or freight line on or off, and hide individual railroads
  from the list of railroads in view; remembered between visits.
- Click any track for its type, owner, subdivision, yard and number of tracks.
- Track geometry is sent gzip-compressed.
- Metra key is also sent as a Bearer header; corrected the Metrolink signup link; API key steps in the README.
- API keys page (panel → API keys…): signup link per agency, Test a key against the live feed before saving,
  Save to start the feed without a restart, Remove to switch it off. Only changeable from the server's own
  computer unless started with `--allow-remote-settings`.
- Feed errors in the panel are in plain English (e.g. "Metra turned this key down (HTTP 401)").
- Brighter train colours, with Amtrak moved from blue to orange so its trains no longer blend into the
  blue Amtrak track; zoomed-out arrows and dots get a dark outline.
- Animated start-up logo: a lens flare runs along the red swoosh and bursts at its tip, the lander's engines
  flicker, the stars twinkle and light sweeps across the rings. The splash stays up until it has played
  (click to skip); still for anyone who has reduced motion turned on.

## [0.1.0] - 2026-10-28

First release.

- Live Amtrak positions from the Transitdocs GTFS-RT feed, with route, train number, destination and
  station names from Amtrak's static GTFS (refreshed daily).
- Amtraker API as an automatic fallback while the Transitdocs feed is down.
- Commuter rail: MBTA, LIRR, Metro-North and SEPTA (no key needed); Metra, Caltrain, Metrolink and
  NJ Transit when their API keys are set in `.env`.
- One normalized vehicle model, cached on the server and pushed to browsers over WebSocket.
- MapLibre map over FRA NARN passenger track, downloaded on first start.
- Agency filters, feed-health lights, search by train number or route, light and dark themes.
- Trains change with zoom: arrows, then a top-down train icon, then the full train drawn to scale car by
  car along the real track, gliding between updates. Detailed track (ballast, ties, rails, multiple tracks).
- SEPTA and LIRR train numbers from trip IDs; SEPTA trains drawn with their live car count.
- Designed and Created by Project Moon Pi: logo on the start-up splash, header, favicon, About section and README.
- Credits for every data feed, library, font and the basemap, in the README and the in-app About section.
- Trains that have not departed yet (future-stamped positions at their origin) are hidden.
- `train-tracker` command: `--port` (default 7500), `--host`, `--data-dir`, `--config`, `fetch-track`.
