// US Train Tracker's own details for the Windows programs (Install Train Tracker.exe, Uninstall Train Tracker.exe,
// Train Tracker.exe). App.cs, Install.cs and Uninstall.cs are the app's own; Common.cs, Ui.cs, Runner.cs, Firewall.cs,
// Shortcuts.cs and Program.cs are the same in every Project Moon Pi app (Train Tracker, SkyScope, Aviator Trail):
// change them in all. Designed and Created by Project Moon Pi.
using System;
using System.IO;
using System.Reflection;

[assembly: AssemblyTitle("US Train Tracker")]
[assembly: AssemblyDescription("US Train Tracker, live US passenger trains on a map")]
[assembly: AssemblyProduct("US Train Tracker")]
[assembly: AssemblyCompany("Project Moon Pi")]
[assembly: AssemblyCopyright("Designed and Created by Project Moon Pi")]
[assembly: AssemblyVersion("2.0.0.0")]

static partial class App
{
    public const string Name = "Train Tracker";            // folders, shortcuts, programs (<Name>.exe), the log
    public const string Display = "US Train Tracker";      // the window's header, Settings > Apps
    public const string Id = "ProjectMoonPi.TrainTracker"; // Settings > Apps, the stop signal
    public const string Slug = "train-tracker";            // <slug>.log and <slug>.pid in the install folder
    public const string Url = "https://github.com/projectmoonpi/train-tracker";
    public const string InfoFile = "settings.json";        // what the installer wrote: port, choices, version
    // where earlier versions installed it (worked out when asked: a static field here can't rely on Common.cs's)
    public static string[] OldDirs { get { return new[] {
        Path.Combine(LocalAppData, "Train Tracker"),         // 0.5's default
        Path.Combine(LocalAppData, "TrainTracker"),          // before 0.5
    }; } }

    // its web pages: where Start opens, and the address that says it's running
    public const int DefaultPort = 7500;
    public const string OpenPath = "/";
    public const string ProbePath = "/api/info";
    public const string PageName = "the map";
    public static readonly string StopHeader = null;        // no shutdown request: Stop ends its program
    public const int StartSeconds = 240;                    // (the very first start downloads maps and schedules)
    public const string StartingNote = "Starting... The very first start takes a minute or two while it downloads maps and schedules.";

    // its shortcuts in the Start menu (and on the Desktop if wanted): name, <App>.exe's arguments, icon, description
    public static readonly string[][] Links = {
        new[] { "Open Train Tracker", "", "app", "Open the map (starting Train Tracker first if it isn't running)" },
        new[] { "Start Train Tracker Service", "--no-browser", "start", "Start US Train Tracker's service in the background (the map opens with Open Train Tracker)" },
        new[] { "Stop Train Tracker Service", "--stop", "stop", "Stop US Train Tracker's service" },
    };

    // what rides the installer's progress bar (MoonBar.cs): a train, as on the Mac
    public const string BarRider = "train";

    // the Python that runs it: its own Python set-up's (venv), without a console window
    public static string PythonW(string dir) { return Path.Combine(dir, @"venv\Scripts\pythonw.exe"); }

    // the icons in the install folder (copied from installer\icons)
    public static string Icon(string kind) { return kind + ".ico"; }      // "app", "start", "stop", "uninstall", "tray-on", "tray-off"

    // Python: the oldest it runs on, and the one installed when there's none (python.org, for this user only)
    public static readonly Version PythonMin = new Version(3, 11);
    public const string PyVersion = "3.14.10";
    public const string PySize = "about 30 MB";
    public static readonly string[][] PyFiles = {        // the installer for each kind of PC, and its SHA-256
        new[] { "AMD64", "python-3.14.10-amd64.exe", "92480239264744fe0386a1bd8275786fefa126e3129e56a68e22b52c73329965" },
        new[] { "ARM64", "python-3.14.10-arm64.exe", "5b9547e4edae2f6fb2fbfec5e26cf91b4ea191e3b07f7727d5a2c5c2cca93ed3" },
        new[] { "x86", "python-3.14.10.exe", "c8f1a16db9afd76ca74b5f8e28eeaad408bca10894c9d080443bde83def3ed09" },
    };

    // phones on the home network: the firewall rule and what the pages say about it
    public const string FirewallRule = "US Train Tracker (phones on your network)";
    public const string PhonesText = "Let phones and tablets on my Wi-Fi open the map";
    public const string PhonesWho = "phones and tablets";
    public const string PhonesShort = "phones";

    // the Python program, run hidden by Train Tracker.exe --run: venv\Scripts\pythonw.exe <these arguments>
    public static string RunArgs(string dir)
    {
        bool phones = InstalledFlag(dir, "phones", true);
        return "-m train_tracker --port " + InstalledPort(dir) + " --log-file " + Proc.Quote(AppLog(dir)) +     // (its icon by the clock is Train Tracker.exe --tray)
               (phones ? " --host 0.0.0.0" : "");
    }

    // ---- Train Tracker's own, used by its Install.cs and Uninstall.cs

    // its downloaded maps and schedules, and the API keys (.env), outside the program's folder
    public static readonly string DataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".train-tracker");
}
