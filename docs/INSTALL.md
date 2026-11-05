<p align="center"><img src="../src/train_tracker/web/img/moon-pi-logo.png" alt="Project Moon Pi" width="140"></p>

# US Train Tracker: Installation Guide

**Designed and Created by Project Moon Pi**

This guide takes you from nothing to a live train map on your computer, phone or tablet. It covers macOS,
Windows and a Raspberry Pi, and how to open the map on an iPhone or Android phone. No programming is needed.

## 1. How it works

US Train Tracker has two parts:

1. **The server**: a small program that runs on a computer (a Mac, a Windows PC or a Raspberry Pi). It
   collects live train positions, predictions and alerts from Amtrak and the commuter railroads every 20–60
   seconds, along with each railroad's schedule and the federal rail map.
2. **The map**: a web page the server provides. You open it in a web browser on the same computer, or on any
   phone, tablet or computer on the same Wi-Fi. Trains move on the map as the server receives new positions.

```
  Amtrak, MBTA, LIRR, Metro-North,       ┌──────────────────────────┐      Web browser on
  SEPTA, MARC, VRE, RTD, CapMetro …  ──► │  Server (your Mac, PC    │ ──►  the same computer,
  (live feeds, schedules, alerts)        │  or Raspberry Pi)        │      or a phone or tablet
  FRA rail map (track)               ──► │  port 7500               │      on the same Wi-Fi
                                         └──────────────────────────┘
```

Phones can't run the server themselves: the server is a Python program, and iPhones and Android phones
can't run it as an app. A phone shows the map from a server running on a computer at home. For a map
that's always available, run the server on a Raspberry Pi that stays on (section 6).

Nothing is sent anywhere except requests to the railroads' public data feeds. There's no account, and the
map is only visible on your own network unless you set up remote access (section 7).

## 2. What you need

| | Requirement |
|---|---|
| **Computer for the server** | A Mac (macOS 11 Big Sur or newer), a Windows 10 or 11 PC, a Linux computer, or a Raspberry Pi 4 or 5 (a Pi 3B+ works, more slowly) |
| **Python** | Version 3.11 or newer, from [python.org](https://www.python.org/downloads/). 3.12 or newer is recommended. On a Mac or Windows PC the installer installs it for you if it's missing |
| **Memory** | About 150–200 MB while running |
| **Disk space** | About 200 MB: the app (~40 MB) and its downloaded maps and schedules (~140 MB) |
| **Internet** | Always on while the server runs. The first start downloads about 140 MB; after that it uses about 130 MB an hour (about 3 GB a day if left running all day) |
| **To view the map** | A current web browser: Safari, Chrome, Edge or Firefox. Phones and tablets: iPhone or iPad with iOS 16.4 or newer, or Android with current Chrome. The map needs WebGL 2, which every browser from 2023 on has |
| **Phones and tablets** | Must be on the same Wi-Fi as the server (or connected through remote access, section 7) |

The server is light: it sits at almost no CPU between updates. It runs in the background as a service, with
**Start** and **Stop** icons to control it; while it's stopped, the map doesn't update.

## 3. Install on a Mac

### Step 1: Download US Train Tracker

1. Download **[US Train Tracker for Mac](https://github.com/projectmoonpi/train-tracker/releases/download/v1.0.3/US-Train-Tracker-for-Mac-v1.0.3.dmg)** (it's also on the
   [Releases page](https://github.com/projectmoonpi/train-tracker/releases/latest), as **US-Train-Tracker-for-Mac-v1.0.3.dmg**):
   one file, a disk image.
2. Double-click the downloaded disk image. A window opens with **Install Train Tracker**, a READ ME FIRST note
   and this guide.

### Step 2: Run the installer

1. In that window, double-click **Install Train Tracker** (the train icon).
2. macOS may say it can't verify the developer, because the installer isn't from the App Store. To allow it:
   open **System Settings → Privacy & Security**, scroll down to the message about "Install Train Tracker",
   and click **Open Anyway**. (On macOS 14 or older you can instead Control-click it, choose **Open**, then
   **Open** again.)
3. Train Tracker runs on Python 3.11 or newer. If this Mac doesn't have it, the installer offers to install it
   first: click **Install Python**, and enter your Mac password when macOS asks. It downloads Python 3.14 from
   [python.org](https://www.python.org/) (about 75 MB), checks it's the genuine installer signed by the Python
   Software Foundation, and installs it. If Python is already installed, you won't see this question.
4. The installer's window opens, with the Project Moon Pi patch in the corner. Its first page checks this Mac
   (macOS, Python, the internet, disk space, and whether Train Tracker is already installed). Click **Next**.
   If something has a red ✗, fix it and click **Check again**.
5. If Train Tracker is already installed, the next page says which version, with a button for each way to go on
   (the Windows installer has the same page):
   - **Update** (from an older version): compares the installed files with the new installer's and updates the
     ones that differ. Your settings, maps and API keys are kept.
   - **Repair** (the same version): checks every installed file and fixes any that are damaged or missing, then
     sets up its apps and service again. Your settings, maps and API keys are kept.
   - **Reinstall from scratch**: removes everything Train Tracker put on the computer, its settings and the
     downloaded maps and schedules too (they download again on its first start), then installs it new. Only
     your saved API keys are kept. Use it when something's wrong that Repair doesn't fix.
6. Make your choices:
   - **Phones and tablets on my Wi-Fi can open the map**: tick it if you'll open the map on a phone or tablet.
   - **Start Train Tracker by itself when I log in**: tick it to have it always running while you're logged in.
   - **Put Start and Stop Train Tracker on my Desktop**: they're in Applications › Train Tracker either way.
7. Click **Install** (or **Update**, **Repair** or **Reinstall**) and watch the train run along the progress bar
   (about a minute; **Show details** shows each step). Train Tracker starts as the last step.
8. Click **Finish**. With **Open the map now** ticked, the map opens in your browser. The very first start
   downloads the rail map and schedules, so trains can take another minute or two to appear. You can eject the
   disk image and delete the download now.

### Start and stop

Train Tracker runs quietly in the background: there's no window to keep open. Two icons control it, in
**Applications › Train Tracker** and, if you chose that, on your **Desktop** (a third, **Uninstall Train
Tracker**, in Applications › Train Tracker, removes it: see section 9):

- **Start Train Tracker** (green ▶): starts it if it isn't running, and opens the map.
- **Stop Train Tracker** (red ■): shuts it down. The map stops updating until you start it again.

### Is it running?

While Train Tracker runs, its **train icon** is in the menu bar at the top of the screen (black or white, like
the icons beside it). Click it to see that it's running, since when, how many trains are on the map and the
address for phones, and to **Open the map**, change the **API keys…** or **Stop Train Tracker**. The icon fades
if Train Tracker stops answering, and goes away when it stops. Activity Monitor lists it as **Train Tracker**.

Start Train Tracker says so if it's already running, and Stop Train Tracker if it wasn't.

If you chose **Phones too** and macOS asks whether Train Tracker (or Python) may accept incoming network
connections, click **Allow**. Then see section 5.

## 4. Install on Windows

### Step 1: Download US Train Tracker

1. Download **[US Train Tracker for Windows](https://github.com/projectmoonpi/train-tracker/releases/download/v1.0.3/Install-US-Train-Tracker-for-Windows-v1.0.3.exe)** (it's also on the
   [Releases page](https://github.com/projectmoonpi/train-tracker/releases/latest), as
   **Install-US-Train-Tracker-for-Windows-v1.0.3.exe**): one file, the installer. Nothing to extract.

### Step 2: Run the installer

1. In your Downloads folder, double-click **Install-US-Train-Tracker-for-Windows** (the train icon).
2. Windows may show "Windows protected your PC" because the installer isn't signed. Click **More info**, then
   **Run anyway**.
3. The installer's window opens. Choose, then click **Install**:
   - If Train Tracker is already installed, a page before this one has a button for each way to go on:
     **Update**, **Repair** or **Reinstall from scratch** (what each does is in section 3, step 5). **< Back**
     returns to it.
   - **Install in**: where Train Tracker goes. Keep the suggested folder (in your user folder), or click
     **Browse...** to pick another (Program Files needs admin permission, so it can't go there).
   - **Let phones and tablets on my Wi-Fi open the map**: tick it if you'll use a phone or tablet.
   - **Start Train Tracker when I sign in to Windows**: tick it to have it always running while you're signed in.
   - **Put Open Train Tracker, and Start and Stop Train Tracker Service, on the Desktop**: untick it to keep them
     in the Start menu only.

   Train Tracker runs on Python 3.11 or newer. If this PC doesn't have it, the window says so and the installer
   downloads Python 3.14 from [python.org](https://www.python.org/) (about 30 MB), checks it's the genuine
   installer signed by the Python Software Foundation, and installs it just for you, with no admin permission
   needed.
4. A progress bar shows each step (about a minute). If you chose phones and the firewall needs opening, a note
   says Windows is about to ask whether **Install Train Tracker.exe** may make changes: click **Yes**.
5. Click **Finish**. Leave **Open the map now** ticked to see the map in your browser. The very first start
   downloads the rail map and schedules, so trains can take another minute or two to appear. You can delete
   the download now.

### Start and stop

Train Tracker runs quietly in the background as a service, with no window. Three shortcuts are in the **Start
menu › Train Tracker** and, if you chose that, on your **Desktop** (it's removed from Settings › Apps: see
section 9):

- **Open Train Tracker** (the train): opens the map, starting the service first if it isn't running.
- **Start Train Tracker Service** (green ▶): starts it in the background, without opening the map.
- **Stop Train Tracker Service** (red ■): shuts it down. The map stops updating until you start it again.

### Is it running?

Look at the **train icon** by the clock at the bottom right: **green** while Train Tracker runs, **red** when it's
stopped. It stays there once Train Tracker has started, until you sign out, so you can start it again from it.
Windows may tuck new icons away under the **^** arrow: drag it down onto the taskbar to keep it in sight. Click it
to open the map (starting Train Tracker first if it's stopped), or right-click it for **Open the map**, **Start
Train Tracker Service** and **Stop Train Tracker Service**. A notice says when it has started or stopped. Task
Manager lists it as **Train Tracker**.

If you chose phones, the installer makes sure Windows Firewall lets them in, on home (Private) networks only.
If it needs to change the firewall, Windows asks *"Do you want to allow this app to make changes to your
device?"*: click **Yes**. If your Wi-Fi is set as a Public network, the installer tells you: set it to Private
(Settings → Network & Internet → Wi-Fi → your network → **Private network**) so phones can connect. Then see
section 5.

### Updates

Open the map's panel, then **About and credits**: **Updates** says which version you have and whether there's a
newer one (Train Tracker asks GitHub a few times a day; **Check now** asks at once). On the computer running Train
Tracker, **Update to <version>** downloads the new version in the background, checks it's the file GitHub
published, unpacks it and opens its installer in front of everything: click **Update** there. Train Tracker is
stopped, updated and started again, and your settings, maps and API keys are kept. (Phones and other devices are
told to update from that computer. **Or download it yourself** gets the installer to run by hand.)

## 5. Use it on an iPhone, iPad or Android phone

1. Install with **Phones too** (sections 3 and 4; run the installer again to change your answer), or use a
   Raspberry Pi (section 6), and start Train Tracker.
2. On the computer, open the map and look at the bottom of the panel for **Open on your phone**. It shows
   the address to use, such as `http://192.168.1.20:7500`, and a QR code.
3. On the phone, connected to the **same Wi-Fi**, scan the QR code with the camera, or type the address into
   Safari or Chrome.

The map fits small screens: the panel sits along the bottom; tap ☰ to fold it away.

### Put it on your home screen

- **iPhone or iPad (Safari):** tap the **Share** button, then **Add to Home Screen**, then **Add**. The
  Train Tracker icon opens the map full screen, like an app.
- **Android (Chrome):** tap **⋮**, then **Add to Home screen**. The icon opens the map in Chrome. (A full
  "installed app" window needs a secure https address, such as the remote access in section 7.)

When you're away from your Wi-Fi the icon can't reach the server, unless you've set up section 7.

## 6. Always on: a Raspberry Pi at home

A Raspberry Pi is a small, quiet, low-power computer that can run the server all the time, so the map is
always ready on your phones and computers.

**You need:** a Raspberry Pi 4 or 5 (2 GB or more), its power supply, a microSD card (16 GB or more), and
your home Wi-Fi or a network cable.

### Step 1: Set up the Pi

1. On your computer, install **Raspberry Pi Imager** from [raspberrypi.com/software](https://www.raspberrypi.com/software/).
2. Choose your Pi model and **Raspberry Pi OS (64-bit)** (the Lite version is enough), and your microSD card.
3. When it offers to edit settings, set a **hostname** (`raspberrypi` is fine), a **username and password**,
   your **Wi-Fi**, and turn on **SSH**. Write the card.
4. Put the card in the Pi and power it on. After a couple of minutes, open Terminal (Mac) or PowerShell
   (Windows) and connect: `ssh yourusername@raspberrypi.local`

### Step 2: Install US Train Tracker

Type these on the Pi, one line at a time. Replace `0.3.0` with the newest version on the
[Releases page](https://github.com/projectmoonpi/train-tracker/releases/latest).

```
sudo apt update && sudo apt install -y python3-venv
python3 -m venv ~/train-tracker
~/train-tracker/bin/pip install https://github.com/projectmoonpi/train-tracker/releases/download/v0.3.0/train_tracker-0.3.0-py3-none-any.whl
~/train-tracker/bin/train-tracker --host 0.0.0.0
```

Wait for the line *On a phone or tablet on this network, open http://…*, then open
**http://raspberrypi.local:7500** on your phone or computer. If that works, press **Ctrl+C** on the Pi to
stop it, and continue.

### Step 3: Start it automatically at power-on

```
curl -LO https://raw.githubusercontent.com/projectmoonpi/train-tracker/main/tools/train-tracker@.service
sudo cp train-tracker@.service /etc/systemd/system/
sudo systemctl enable --now train-tracker@$USER
```

The map is now at **http://raspberrypi.local:7500** whenever the Pi is on. Check on it with
`systemctl status train-tracker@$USER`, and see its messages with `journalctl -u train-tracker@$USER -f`.

**To update** the Pi later: run the `pip install` line again with the new version, adding `--upgrade`, then
`sudo systemctl restart train-tracker@$USER`.

**API keys on a Pi:** the API keys page only accepts changes from the server's own computer. Either type
keys into `~/.train-tracker/.env` on the Pi (see `.env.example` in the project), or add
`--allow-remote-settings` to the `ExecStart` line of the service file to manage them from your phone.

## 7. Seeing it away from home

The simplest safe way is **Tailscale**, a free private network between your own devices:

1. Install Tailscale on the server (Mac, PC or Pi) and on your phone from [tailscale.com](https://tailscale.com/download),
   and sign in on both with the same account.
2. On the phone, open `http://<the server's Tailscale name>:7500`, for example `http://raspberrypi:7500`.

Please **don't** open port 7500 on your router to the whole internet. The map has no password, and it isn't
built to face the open internet.

## 8. API keys (optional)

Amtrak, MBTA, LIRR, Metro-North, SEPTA, MARC, VRE, RTD Denver and CapMetro work with no setup. Metra,
Caltrain, Metrolink and NJ Transit hand out free developer keys. On the map, open the panel and click **API
keys…**: each railroad has a **Get a key** link, a **Test** button and a **Save** button. Saved keys start
that railroad straight away.

## 9. Updating and removing

**Updating (Mac or Windows):** download the new version for your computer and run its installer, just like the
first time. It stops Train Tracker, compares the installed files with the new ones and updates those that
differ, and keeps your settings, API keys and downloaded data. Running the installer again is also how you
change your answers (phones, start at log-in, Desktop icons), and how you **Repair** it (checks every file and
fixes damaged or missing ones) or **Reinstall from scratch** (removes everything except your saved API keys,
then installs it new): see section 2.

**Removing:**

- **Mac:** double-click **Uninstall Train Tracker** in **Applications › Train Tracker**. Its window asks
  whether to delete your data too (a tick box), then shows its progress until it's done. The first time, macOS
  asks whether Uninstall Train Tracker may access files in your Desktop folder: click **Allow**, so it can
  remove its icons from the Desktop. (If you don't, it tells you to drag them to the Trash.)
- **Windows:** open **Settings › Apps › Installed apps**, find **US Train Tracker** and click **Uninstall**, as for
  any program (**Uninstall Train Tracker** is also in the folder you installed it in). A window asks
  whether to delete your data too, then shows its progress until it's done.

It removes the service, the icons and the program. Python stays, for anything else that uses it. Your data
(the downloaded maps and schedules, and any API keys you saved) is kept unless you ticked the box to delete it,
so installing again picks up where you left off. That data lives in `~/.train-tracker` (Mac and Raspberry Pi)
or `C:\Users\<your name>\.train-tracker` (Windows).

## 10. Troubleshooting

| What you see | What to do |
|---|---|
| "Needs Python 3.11 or newer" | Run the installer again and let it install Python. Or install Python yourself from [python.org](https://www.python.org/downloads/) (on Windows, tick **Add python.exe to PATH**), then run the installer again |
| "Train Tracker didn't start" | Its messages say why: on a Mac in `~/Library/Logs/Train Tracker.log`, on Windows in `train-tracker.log` in the folder it's installed in (normally `%LOCALAPPDATA%\Programs\Project Moon Pi\Train Tracker`). A common cause is another program using port 7500 |
| Stop says it's still running | Another program is serving on port 7500 (perhaps a copy started by hand). Close it, or restart the computer |
| The browser didn't open | Open **http://127.0.0.1:7500** yourself |
| No train icon in the menu bar or by the clock | Train Tracker isn't running: use Start Train Tracker (on Windows, Open Train Tracker). On Windows, also look under the **^** by the clock. If it's running (the map opens) but there's still no icon, run the installer again |
| The phone can't open the address | Check the phone is on the same Wi-Fi (not mobile data or a guest network), and that you installed with **Phones too**. On Windows, run the installer again and click **Yes** if Windows asks for permission, and make sure your network is set to Private. On a Mac, if macOS asked whether Train Tracker (or Python) may accept incoming connections, choose **Allow**. Some routers keep devices apart ("client isolation" or "AP isolation"): turn that off for your home network |
| `raspberrypi.local` doesn't work | Use the Pi's numbered address instead: run `hostname -I` on the Pi |
| Map shows but no track | The first start is still downloading the rail map: wait a minute and reload |
| A railroad shows a red or amber dot | Its feed is down or its key was refused: the panel says why. Feeds come back by themselves |
| VRE shows 0 trains | Normal outside weekday rush hours |
| Metra, Caltrain, Metrolink or NJ Transit say "needs an API key" | See section 8 |

Still stuck? Open an issue on the [GitHub page](https://github.com/projectmoonpi/train-tracker/issues).

---

US Train Tracker is free software (MIT licence). Train data comes from each railroad's public feeds under
their terms; see the Credits in the [README](../README.md). Built with Claude Code (Anthropic).
**Designed and Created by Project Moon Pi.**
