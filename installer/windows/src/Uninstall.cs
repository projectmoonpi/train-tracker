// Uninstall <App>.exe: removes the app, its shortcuts and its settings, in a window. Python stays.
//   In the install folder (Settings > Apps, Remove <App>): it copies itself to a folder in %TEMP% and carries on from
//   there (--from <install folder>), as a program can't remove the folder it's running from.
//   Beside the installer (the downloaded folder): it removes the copy Windows has on record (Settings > Apps).
//   -Quiet (or TT_UNATTENDED=1): no window, no questions.
// Designed and Created by Project Moon Pi.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using Microsoft.Win32;

static class Uninstall
{
    public static int Begin(string[] args)
    {
        bool quiet = args.Any(a => a.Equals("-Quiet", StringComparison.OrdinalIgnoreCase) || a == "--quiet")
                     || Environment.GetEnvironmentVariable("TT_UNATTENDED") == "1";
        int at = Array.IndexOf(args, "--from");
        string dir = at >= 0 && at + 1 < args.Length ? args[at + 1] : null;
        if (dir == null)
        {
            if (App.IsInstalledIn(App.Here))
            {
                // in the install folder: carry on from a copy in %TEMP%
                string tmp = Path.Combine(Path.GetTempPath(), App.Name + " uninstall " + Process.GetCurrentProcess().Id);
                Directory.CreateDirectory(tmp);
                string copy = Path.Combine(tmp, Path.GetFileName(App.Exe));
                File.Copy(App.Exe, copy, true);
                var more = new List<string> { "--from", App.Here };
                if (quiet) more.Add("-Quiet");
                Process.Start(new ProcessStartInfo(copy, Proc.Join(more)) { UseShellExecute = false, WorkingDirectory = tmp });
                return 0;
            }
            dir = App.InstalledDir();
            if (dir == null)
            {
                if (!quiet) Ui.Say(App.Name + " isn't installed on this PC.");
                return 1;
            }
        }
        Ui.Unattended = quiet;
        App.LogHeader("uninstaller");
        try { return Steps(dir.TrimEnd('\\'), quiet); }
        catch (Exception e)
        {
            App.Log("ERROR: " + e);
            if (quiet) return 1;
            Ui.Error(App.Name + " wasn't fully removed.\n\n" + e.Message + "\n\n" + App.HelpLine);
            return 1;
        }
    }

    static int Steps(string dir, bool quiet)
    {
        // the downloaded maps and schedules, and any saved API keys: kept unless the box is ticked
        bool deleteData = false;
        if (!quiet)
        {
            Ui.Open("Uninstall " + App.Display, Path.Combine(dir, "logo.png"), Path.Combine(dir, App.Icon("uninstall")), App.Display);
            var answers = Ui.Choices("Remove " + App.Display + " from this PC? It stops Train Tracker and removes the program and its shortcuts. Python stays, for anything else that uses it.",
                                     new[] { new Box("Also delete the downloaded maps and schedules, and any API keys you saved", false) }, "Uninstall");
            if (answers == null) { Ui.Close(); return 0; }
            deleteData = answers[0];
        }

        Ui.Progress("Stopping Train Tracker...", 10);
        Runner.Stop(dir, true, true);
        int port = App.InstalledPort(dir);

        // close the port for phones (Windows asks for permission only if there's a rule to remove)
        Ui.Progress("Closing the firewall for phones...", 50);
        Firewall.Remove(port, quiet);

        Ui.Progress("Removing the shortcuts...", 65);
        Shortcuts.RemoveAll();
        Registry.CurrentUser.DeleteSubKeyTree(App.UninstallKey, false);      // Settings > Apps

        if (deleteData)
        {
            Ui.Progress("Deleting the downloaded maps, schedules and API keys...", 75);
            Files.TryDeleteDir(App.DataDir);
        }
        Ui.Progress("Removing the program...", 90);
        Directory.SetCurrentDirectory(Path.GetTempPath());
        // (a program that has just been ended can hold its files a moment longer)
        for (int i = 0; i < 40 && Directory.Exists(dir); i++)
        {
            Files.TryDeleteDir(dir);
            if (Directory.Exists(dir)) Ui.Breathe(250);
        }
        // and the Project Moon Pi folder it was in, once it's empty (no other Project Moon Pi app left there)
        string parent = Path.GetDirectoryName(dir);
        try
        {
            if (Path.GetFileName(parent) == "Project Moon Pi" && !Directory.EnumerateFileSystemEntries(parent).Any()) Directory.Delete(parent);
        }
        catch { }
        bool left = Directory.Exists(dir);
        App.Log("removed " + dir + (left ? " (some files were in use)" : "") + (deleteData ? ", and " + App.DataDir : ""));
        if (!quiet)
            Ui.Done(App.Display + " has been removed." +
                    (left ? "\n\nA few files in " + dir + " were in use; they go when you restart the PC, or you can delete that folder." : "") +
                    (!deleteData && Directory.Exists(App.DataDir) ? "\n\nYour downloaded maps and any API keys are still in " + App.DataDir + ", for if you install it again." : ""),
                    "Close");
        return 0;
    }
}
