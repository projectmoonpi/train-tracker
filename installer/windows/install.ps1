# Install US Train Tracker on this PC, in a window (started by "Install Train Tracker.exe"; run it again later to
# update).
#
# Installs the program in %LOCALAPPDATA%\Programs\Project Moon Pi\Train Tracker (or a folder you choose), with Uninstall Train Tracker.exe in it;
# puts Start, Stop and Remove Train Tracker (the uninstaller) in the Start menu, and Start and Stop on the Desktop if you like; and
# lists it in Windows' Settings > Apps (with its Uninstall button).
# (Before 0.5 the folder was %LOCALAPPDATA%\TrainTracker; an install there is moved over.) Needs Python 3.11 or
# newer; if it isn't there, it installs Python from python.org for this user only (checked: the expected download,
# signed by the Python Software Foundation). What it does is logged in %TEMP%\Train Tracker install.log.
# Designed and Created by Project Moon Pi.
#
# For unattended installs, answer the questions ahead: TT_PHONES=yes|no TT_AUTOSTART=yes|no TT_DESKTOP=yes|no
# TT_DIR=<folder> TT_OPEN=no TT_PYTHON=yes|no (install Python if needed) TT_MODE=update|repair|fresh (when it's
# already installed; otherwise the suggested choice); the window then needs no clicks.
$ErrorActionPreference = 'Stop'
$Src = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# (Project Moon Pi's apps go together under %LOCALAPPDATA%\Programs\Project Moon Pi, where Windows keeps programs installed
# for one user; earlier installs elsewhere stay where they are when updated)
$DefaultDir = Join-Path $env:LOCALAPPDATA 'Programs\Project Moon Pi\Train Tracker'
$AppDir = $DefaultDir       # (the folder chosen on the first page)
$OldDir = Join-Path $env:LOCALAPPDATA 'TrainTracker'      # before 0.5
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProjectMoonPi.TrainTracker'
$Port = 7500
$Log = Join-Path $env:TEMP 'Train Tracker install.log'
$UI_Unattended = [bool]$env:TT_PHONES
"== $(Get-Date) US Train Tracker installer" | Out-File $Log -Append -Encoding utf8    # (Install Train Tracker.exe reads from here)
# anything that stops it before its window is up goes in the log too; "Install Train Tracker.exe" then shows it (a
# hidden PowerShell has no other way to tell anyone)
trap {
    "$(Get-Date -Format 'HH:mm:ss') ERROR before the window opened: $_ $($_.InvocationInfo.PositionMessage)" |
        Out-File $Log -Append -Encoding utf8
    exit 2
}
. (Join-Path $PSScriptRoot 'ui.ps1')

function Log($text) { "$(Get-Date -Format 'HH:mm:ss') $text" | Out-File $Log -Append -Encoding utf8 }

function Run($exe, $argv, $what, $upTo, $seconds = 60, $ok = @(0)) {
    # a program run hidden, its output in the log, while the window keeps going ($ok: the exit codes that aren't a
    # failure; the code is left in $LastCode)
    Log "$what`: $exe $($argv -join ' ')"
    $out = Join-Path $env:TEMP "tt-step-$PID.txt"
    $p = Start-Process $exe -ArgumentList ($argv | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) `
        -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError "$out.err"
    $code = UI-Wait $p $upTo $seconds
    $text = (Get-Content $out, "$out.err" -Raw -ErrorAction SilentlyContinue) -join ''
    Remove-Item $out, "$out.err" -ErrorAction SilentlyContinue
    if ($text) { Log $text.Trim() }
    $script:LastCode = $code
    if ($code -notin $ok) { throw "$what didn't work (exit code $code)." }
    return $text
}

# Python 3.11 or newer: the "py" launcher from python.org, python on the PATH, or a Python that Windows has on
# record as installed (a window opened before Python was installed still has the old PATH)
function Find-Python {
    $env:Path = (@($env:Path, [Environment]::GetEnvironmentVariable('Path', 'User'),
                   [Environment]::GetEnvironmentVariable('Path', 'Machine')) | Where-Object { $_ }) -join ';'
    $check = @('-c', 'import sys; sys.exit(sys.version_info < (3, 11))')
    $found = @(@{exe = 'py'; pre = @('-3')}, @{exe = 'python'; pre = @()})
    foreach ($key in 'HKCU:\Software\Python\PythonCore', 'HKLM:\Software\Python\PythonCore',
                     'HKLM:\Software\WOW6432Node\Python\PythonCore') {
        Get-ChildItem $key -ErrorAction SilentlyContinue | ForEach-Object {
            $exe = (Get-ItemProperty (Join-Path $_.PSPath 'InstallPath') -ErrorAction SilentlyContinue).ExecutablePath
            if ($exe -and (Test-Path $exe)) { $found += @{exe = $exe; pre = @()} }
        }
    }
    foreach ($c in $found) {
        if (-not (Get-Command $c.exe -ErrorAction SilentlyContinue)) { continue }
        $argv = $c.pre + $check
        try { & $c.exe @argv 2>$null } catch { continue }    # e.g. the Microsoft Store's "python" placeholder
        if ($LASTEXITCODE -eq 0) { return $c }
    }
    return $null
}

# otherwise Python from python.org, installed for this user only (no admin needed)
$PyVersion = '3.14.10'
$PyFiles = @{    # the installer for each kind of PC, and its SHA-256 from python.org
    AMD64 = @{file = "python-$PyVersion-amd64.exe"; sha256 = '92480239264744fe0386a1bd8275786fefa126e3129e56a68e22b52c73329965'}
    ARM64 = @{file = "python-$PyVersion-arm64.exe"; sha256 = '5b9547e4edae2f6fb2fbfec5e26cf91b4ea191e3b07f7727d5a2c5c2cca93ed3'}
    x86   = @{file = "python-$PyVersion.exe";       sha256 = 'c8f1a16db9afd76ca74b5f8e28eeaad408bca10894c9d080443bde83def3ed09'}
}

function Install-Python {
    $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $want = $PyFiles[$arch]
    if (-not $want) { $want = $PyFiles['x86'] }
    $exe = Join-Path $env:TEMP $want.file
    $url = "https://www.python.org/ftp/python/$PyVersion/$($want.file)"
    Log "downloading $url"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    # downloaded in the background, the bar following the file's size (Windows PowerShell can't run script code on
    # the download's own progress events, so they're only used to say it's finished)
    try {
        $head = [Net.WebRequest]::Create($url); $head.Method = 'HEAD'
        $r = $head.GetResponse(); $total = $r.ContentLength; $r.Close()
    } catch { throw "Python couldn't be downloaded. Check the internet connection, then run the installer again." }
    $wc = New-Object System.Net.WebClient
    $null = Register-ObjectEvent $wc DownloadFileCompleted -SourceIdentifier 'tt-python-download'
    $wc.DownloadFileAsync([Uri]$url, $exe)
    $finished = $null
    while (-not $finished) {
        $have = (Get-Item $exe -ErrorAction SilentlyContinue).Length
        $pc = if ($total -gt 0 -and $have) { [Math]::Min(100, [int](100 * $have / $total)) } else { 0 }
        UI-Progress "Downloading Python $PyVersion from python.org..." (2 + 18 * $pc / 100) "$pc% of $([Math]::Round($total / 1MB)) MB"
        Start-Sleep -Milliseconds 60
        $finished = Get-Event -SourceIdentifier 'tt-python-download' -ErrorAction SilentlyContinue
    }
    $err = $finished.SourceEventArgs.Error
    Unregister-Event -SourceIdentifier 'tt-python-download'; Remove-Event -SourceIdentifier 'tt-python-download'
    if ($err) { Log "download: $err"; throw "Python couldn't be downloaded. Check the internet connection, then run the installer again." }
    try {
        UI-Progress 'Checking the Python download...' 21
        if ((Get-FileHash $exe -Algorithm SHA256).Hash -ne $want.sha256) {
            throw "The Python download wasn't the expected file, so it wasn't installed."
        }
        $sig = Get-AuthenticodeSignature $exe
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O="?Python Software Foundation') {
            throw "The Python download isn't signed by the Python Software Foundation, so it wasn't installed."
        }
        UI-Progress "Installing Python $PyVersion for you..." 22 'This takes a minute or two.'
        $p = Start-Process $exe -PassThru -ArgumentList @('/quiet', 'InstallAllUsers=0', 'PrependPath=1',
            'Include_launcher=1', 'InstallLauncherAllUsers=0', 'Include_test=0', 'Include_doc=0')
        $code = UI-Wait $p 40 90
        Log "Python installer exit code $code"
        if ($code -notin 0, 3010) { throw "Python's installer stopped (exit code $code)." }
    } finally { Remove-Item $exe -Force -ErrorAction SilentlyContinue }
}

# Where it's installed now, if anywhere (Settings > Apps knows), so an update goes to the same place
function Installed-Dir {
    $at = (Get-ItemProperty $UninstallKey -ErrorAction SilentlyContinue).InstallLocation
    if ($at -and (Test-Path (Join-Path $at 'settings.json'))) { return $at }
    $before = Join-Path $env:LOCALAPPDATA 'Train Tracker'      # (0.5's default)
    if (Test-Path (Join-Path $before 'settings.json')) { return $before }
    return $null
}

# The folder Train Tracker goes in: the one chosen, unless that already holds other things (then a Train Tracker
# folder inside it), so uninstalling can never take anything else with it
function Resolve-AppDir($chosen) {
    $chosen = [Environment]::ExpandEnvironmentVariables($chosen).TrimEnd('\')
    if ((Test-Path $chosen) -and (Get-ChildItem $chosen -Force -ErrorAction SilentlyContinue | Select-Object -First 1) -and
        -not (Test-Path (Join-Path $chosen 'settings.json')) -and (Split-Path $chosen -Leaf) -ne 'Train Tracker') {
        return Join-Path $chosen 'Train Tracker'
    }
    return $chosen
}

function Check-Folder($path) {
    # an error to show, or nothing if Train Tracker can go there
    if (-not $path -or -not [IO.Path]::IsPathRooted([Environment]::ExpandEnvironmentVariables($path))) { return 'Choose a whole folder path, such as C:\Users\you\Apps.' }
    $dir = Resolve-AppDir $path
    foreach ($bad in $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:SystemRoot) {
        if ($bad -and $dir.StartsWith($bad, [StringComparison]::OrdinalIgnoreCase)) {
            return "Train Tracker installs just for you, without asking for admin permission, so it can't go in $bad. Choose a folder of your own, such as the one it suggests."
        }
    }
    try {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $probe = Join-Path $dir ".write-test-$PID"
        Set-Content $probe 'ok'; Remove-Item $probe
    } catch { return "Train Tracker can't write to $dir. Choose another folder." }
    return $null
}

# Installing needs the internet (Python from python.org, Train Tracker's packages from pypi.org): check first, before
# anything is changed
function Test-Internet {
    foreach ($url in 'https://pypi.org/simple/pip/', 'https://www.python.org/') {
        try {
            $r = [Net.WebRequest]::Create($url); $r.Method = 'HEAD'; $r.Timeout = 10000
            $r.GetResponse().Close()
            return $true
        } catch { Log "no answer from $url`: $($_.Exception.InnerException.Message)" }
    }
    return $false
}

function Newer($a, $b) {
    # is version $a newer than $b? (1 newer, 0 the same, -1 older)
    try { return ([version]$a).CompareTo([version]$b) } catch { return [string]::Compare("$a", "$b") }
}

function Main {
    UI-Open 'Install US Train Tracker' (Join-Path $Src 'src\train_tracker\web\img\moon-pi-logo-128.png') (Join-Path $Src 'installer\icons\app.ico') 'US Train Tracker'
    Log 'window shown'

    $py = Find-Python
    $intro = "Live US passenger trains on a map, in your web browser. This installs Train Tracker for you on this PC; it runs quietly in the background, with a train icon by the clock."
    if (-not $py) { $intro += "`n`nIt also installs Python $PyVersion from python.org (about 30 MB), which Train Tracker runs on." }
    $was = Installed-Dir
    $suggest = if ($env:TT_DIR) { $env:TT_DIR } elseif ($was) { $was } else { $DefaultDir }

    # already installed? Then update (this one's newer), repair (the same) or reinstall from scratch; the choices
    # start as the installed copy has them
    $newVersion = (Select-String -Path (Join-Path $Src 'src\train_tracker\__init__.py') -Pattern '__version__ = "([^"]+)"').Matches[0].Groups[1].Value
    $have = if ($was) { (Get-ItemProperty $UninstallKey -ErrorAction SilentlyContinue).DisplayVersion } else { $null }
    $prev = $null
    if ($was) { try { $prev = Get-Content (Join-Path $was 'settings.json') -Raw | ConvertFrom-Json } catch { } }
    # the choices: Update, Repair or Reinstall from scratch as buttons on a page of their own (when it's installed),
    # then the page with the folder and tick boxes (Back returns to the buttons)
    $fresh = @{ label = 'Reinstall from scratch'; note = 'Removes everything Train Tracker put on this PC, its settings and downloaded maps too, then installs it new. Only your saved API keys are kept.' }
    $compare = 'Compares the installed files with this installer''s and updates the ones that differ. Your settings, maps and API keys are kept.'
    $modes = @(); $buttons = @()
    if ($have) {
        switch (Newer $newVersion $have) {
            1 { $modeIntro = "US Train Tracker $have is installed on this PC. This installer has version $newVersion. What would you like to do?"
                $buttons = @(@{ label = "Update to $newVersion"; note = $compare }, $fresh); $modes = @('update', 'fresh') }
            0 { $modeIntro = "US Train Tracker $have is already installed on this PC. What would you like to do?"
                $buttons = @(@{ label = 'Repair'; note = 'Checks every installed file and fixes any that are damaged or missing, then sets up its shortcuts again. Your settings, maps and API keys are kept.' }, $fresh)
                $modes = @('repair', 'fresh') }
            default { $modeIntro = "A newer US Train Tracker ($have) is installed on this PC than this installer's version ($newVersion). Cancel keeps the newer one."
                $buttons = @(@{ label = "Install $newVersion"; note = $compare }, $fresh); $modes = @('update', 'fresh') }
        }
        if (-not $py) { $modeIntro += " (It also installs Python $PyVersion from python.org, which Train Tracker runs on.)" }
    }
    $wasPhones = if ($prev) { [bool]$prev.phones } else { $true }
    $wasAuto = if ($prev) { [bool]$prev.autostart } else { $false }
    $wasDesk = if ($prev -and $null -ne $prev.desktop) { [bool]$prev.desktop } else { $true }
    $mode = 'install'
    while ($true) {
        $text = $intro; $okText = 'Install'
        if ($have) {
            $pick = UI-Modes $modeIntro $buttons
            if ($null -eq $pick) { UI-Close; return }
            $mode = $modes[$pick]
            if ($UI_Unattended -and $env:TT_MODE) { $mode = $env:TT_MODE }
            $okText = @{ update = 'Update'; repair = 'Repair'; fresh = 'Reinstall' }[$mode]
            $text = @{ update = "Updating Train Tracker $have to $newVersion"; repair = "Repairing Train Tracker $have"; fresh = "Reinstalling Train Tracker $newVersion from scratch" }[$mode] +
                ": " + $buttons[[Math]::Max(0, [array]::IndexOf($modes, $mode))].note + "`n`nChoose below, then click $okText (or Back to choose differently)."
        }
        $choices = UI-Choices $text @(
            @{ text = "Let phones and tablets on my Wi-Fi open the map"; checked = $(if ($env:TT_PHONES) { $env:TT_PHONES -ne 'no' } else { $wasPhones }) },
            @{ text = "Start Train Tracker when I sign in to Windows"; checked = $(if ($env:TT_AUTOSTART) { $env:TT_AUTOSTART -eq 'yes' } else { $wasAuto }) },
            @{ text = "Put Start and Stop Train Tracker on the Desktop"; checked = $(if ($env:TT_DESKTOP) { $env:TT_DESKTOP -ne 'no' } else { $wasDesk }) }) $okText `
            -Folder $suggest -FolderCheck { param($path) Check-Folder $path } -Back:([bool]$have)
        if (-not $UI_Back) { break }
    }
    if ($null -eq $choices) { UI-Close; return }
    $phones, $autostart, $onDesktop = $choices
    if ($UI_Unattended) { $phones = $env:TT_PHONES -eq 'yes'; $autostart = $env:TT_AUTOSTART -eq 'yes'; $onDesktop = $env:TT_DESKTOP -ne 'no' }
    $problem = Check-Folder $UI_Folder
    if ($problem) { throw $problem }
    $script:AppDir = Resolve-AppDir $UI_Folder
    Log "mode=$mode ($have -> $newVersion) folder=$AppDir phones=$phones autostart=$autostart desktop=$onDesktop"

    UI-Progress 'Checking the internet connection...' 1
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (-not (Test-Internet)) {
        throw ("Installing needs an internet connection, to download what Train Tracker runs on from python.org and " +
               "pypi.org, and this PC can't reach them. Nothing was changed" + $(if ($was) { ': the Train Tracker you have keeps working' } else { '' }) +
               ". Connect to the internet, then run the installer again.")
    }

    if (-not $py) {
        if ($env:TT_PYTHON -eq 'no') { throw 'Train Tracker needs Python 3.11 or newer, and this PC doesn''t have it.' }
        Install-Python
        $py = Find-Python
        if (-not $py) { throw 'Python was installed but can''t be found. Restart the PC and run the installer again.' }
    }

    # an update: stop the running service first (also an install in the old folder)
    UI-Progress 'Getting ready...' 42
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $others = @($OldDir, $was) | Where-Object { $_ -and $_ -ne $AppDir -and (Test-Path $_) }    # older installs elsewhere
    foreach ($d in @($AppDir) + $others) {
        if (Test-Path (Join-Path $d 'stop.ps1')) {
            # (if this install goes wrong after this, the copy that was running is started again)
            try { $null = Invoke-WebRequest "http://127.0.0.1:$Port/api/info" -UseBasicParsing -TimeoutSec 2; $script:WasRunning = $d } catch { }
            $null = Run $ps @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $d 'stop.ps1'), '-Quiet') 'Stopping Train Tracker' 45 10
        }
    }

    $notes = @()
    if ($mode -eq 'fresh') {
        # from scratch: everything Train Tracker put on this PC goes (the program, its Python set-up and settings,
        # its shortcuts, its Settings > Apps entry, the downloaded maps and schedules), except the saved API keys,
        # which can't be downloaded again
        UI-Progress 'Removing everything Train Tracker put on this PC...' 44
        foreach ($d in @($AppDir) + $others) {
            if (Test-Path (Join-Path $d 'settings.json')) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; Log "removed $d" }
        }
        $desktop = [Environment]::GetFolderPath('Desktop')
        Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'Train Tracker') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $desktop 'Start Train Tracker.lnk'), (Join-Path $desktop 'Stop Train Tracker.lnk'),
            (Join-Path $desktop 'Uninstall Train Tracker.lnk'), (Join-Path ([Environment]::GetFolderPath('Startup')) 'Train Tracker.lnk') -ErrorAction SilentlyContinue
        Remove-Item $UninstallKey -Recurse -Force -ErrorAction SilentlyContinue
        $data = Join-Path $env:USERPROFILE '.train-tracker'
        if (Test-Path $data) {
            Get-ChildItem $data -Force | Where-Object Name -ne '.env' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Log "removed the downloaded maps and schedules in $data (kept .env, the API keys)"
            if (Test-Path (Join-Path $data '.env')) { $notes += 'Everything was removed and installed new, except your saved API keys. The maps and schedules download again on its first start.' }
        }
    }
    New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
    $venvPy = Join-Path $AppDir 'venv\Scripts\python.exe'
    $pipArgs = @('--disable-pip-version-check', '--no-input', '--progress-bar', 'off')
    function New-Venv {
        UI-Progress 'Setting up Python for Train Tracker...' 45
        Remove-Item (Join-Path $AppDir 'venv') -Recurse -Force -ErrorAction SilentlyContinue
        $null = Run $py.exe ($py.pre + @('-m', 'venv', (Join-Path $AppDir 'venv'))) 'Setting up Python' 50 20
        try { $null = Run $venvPy (@('-m', 'pip', 'install', '--quiet', '--upgrade', 'pip') + $pipArgs) 'Updating pip' 52 20 }
        catch { Log "$_ - carrying on with the pip it has" }
    }
    # a fresh environment if there's none, its Python was removed or is too old, or it can't run its own pip (as
    # when Repair finds it broken)
    $venvOk = $false
    if (Test-Path $venvPy) {
        try { & $venvPy -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>$null; $venvOk = $LASTEXITCODE -eq 0 } catch { }
        if ($venvOk) { try { & $venvPy -m pip --version 2>$null | Out-Null; $venvOk = $LASTEXITCODE -eq 0 } catch { $venvOk = $false } }
        if (-not $venvOk) { Log "Train Tracker's Python set-up can't run: making it again" }
    }
    if (-not $venvOk) { New-Venv }

    # Train Tracker, built from this installer into a wheel, so its files can be compared with the installed ones
    UI-Progress 'Building Train Tracker from this installer...' 52
    $work = Join-Path $env:TEMP "tt-install-$PID"
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    $null = Run $venvPy (@('-m', 'pip', 'wheel', '--quiet', '--no-deps', '-w', $work, $Src) + $pipArgs) 'Building Train Tracker' 56 60
    $wheel = (Get-ChildItem $work -Filter *.whl | Select-Object -First 1).FullName
    $check = Join-Path $Src 'installer\filecheck.py'
    $env:FC_APP = 'Train Tracker'
    function Summary($text) { (($text -split "`r?`n") | Where-Object { $_ } | Select-Object -Last 1) -creplace '^Checked', 'checked' }
    if ($mode -eq 'repair') {
        # every installed file against the fingerprint pip wrote down for it; packages with damaged or missing
        # files are installed again (all of Python's set-up, if that doesn't fix them)
        UI-Progress 'Checking Train Tracker''s files...' 57
        $found = Run $venvPy @($check, 'check') 'Checking the installed files' 62 120 @(0, 1)
        if ($LastCode -eq 0) {
            $notes += "Repair $(Summary $found)"
        } else {
            UI-Progress 'Fixing the damaged files...' 62
            $fixed = $true
            foreach ($want in @(($found -split "`r?`n") | Where-Object { $_ -match '^REPAIR ' } | ForEach-Object { $_.Substring(7).Trim() })) {
                $what = if ($want -like 'train-tracker==*') { $wheel } else { $want }
                try { $null = Run $venvPy (@('-m', 'pip', 'install', '--force-reinstall', '--no-deps', $what) + $pipArgs) "Installing $want again" 66 60 }
                catch { Log $_; $fixed = $false }
            }
            if ($fixed) { $null = Run $venvPy @($check, 'check') 'Checking the files again' 67 120 @(0, 1); $fixed = $LastCode -eq 0 }
            if ($fixed) {
                $notes += "Repair $(Summary $found) It fixed them."
            } else {
                Log 'some files could not be fixed in place: making the Python set-up again'
                New-Venv
                $notes += "Repair $(Summary $found) It set up Train Tracker's Python parts again to fix them."
            }
        }
        UI-Progress 'Installing Train Tracker...' 68 'Adding any part that is missing.'
    } else {
        # an update: only the files that differ from the installed ones are replaced
        # (asked without an error message: in PowerShell 5.1 a program's error output stops this script)
        $null = & $venvPy -c "import importlib.util, sys; sys.exit(importlib.util.find_spec('train_tracker') is None)"
        if ($LASTEXITCODE -eq 0) { UI-Progress 'Comparing the installed files with this installer''s...' 57 }
        $diff = Run $venvPy @($check, 'compare', $wheel) 'Comparing the files' 60 60 @(0, 1)
        if ($LastCode -ne 0) {
            UI-Progress 'Installing Train Tracker...' 60 'Downloading what it needs; about a minute.'
            $null = Run $venvPy (@('-m', 'pip', 'install', '--force-reinstall', '--no-deps', $wheel) + $pipArgs) 'Replacing the files that differ' 64 60
        }
        if ($mode -eq 'update') { $notes += (($diff -split "`r?`n") | Where-Object { $_ } | Select-Object -Last 1) }
    }
    # the parts it runs on: pip adds only what's missing, or what this version needs newer
    $null = Run $venvPy (@('-m', 'pip', 'install', $wheel) + $pipArgs) 'Installing the parts Train Tracker runs on' 72 90
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    $version = (& $venvPy -c 'import train_tracker; print(train_tracker.__version__)').Trim()
    # pystray and Pillow put Train Tracker's icon by the clock; without them it runs without the icon
    UI-Progress 'Installing the icon by the clock...' 72
    try { $null = Run $venvPy (@('-m', 'pip', 'install', 'pystray', 'pillow') + $pipArgs) 'Installing pystray and Pillow' 80 30 }
    catch { Log "$_ - no icon by the clock" }

    UI-Progress 'Adding the shortcuts...' 81
    foreach ($f in 'start.ps1', 'stop.ps1', 'uninstall.ps1', 'firewall.ps1', 'ui.ps1', 'Uninstall Train Tracker.exe') { Copy-Item (Join-Path $PSScriptRoot $f) $AppDir -Force }
    foreach ($f in 'start.ico', 'stop.ico', 'uninstall.ico', 'app.ico') { Copy-Item (Join-Path $Src "installer\icons\$f") $AppDir -Force }
    Copy-Item (Join-Path $Src 'src\train_tracker\web\img\moon-pi-logo-128.png') (Join-Path $AppDir 'logo.png') -Force
    Get-ChildItem $AppDir -File | Unblock-File      # drop the "downloaded from the internet" mark on our own copies
    # TrainTracker.exe: Python under Train Tracker's own name and icon, so Task Manager shows "Train Tracker"
    # (pythonw.exe if not)
    $exe = $null
    try { $exe = ((Run $venvPy @((Join-Path $PSScriptRoot 'brand_exe.py'), $AppDir) 'Naming Train Tracker' 85 20) -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1) } catch { Log $_ }
    if (-not $exe -or -not (Test-Path $exe)) { $exe = Join-Path $AppDir 'venv\Scripts\pythonw.exe' }
    @{ port = $Port; phones = $phones; autostart = $autostart; desktop = $onDesktop; version = "$version"; exe = "$exe" } | ConvertTo-Json |
        Set-Content (Join-Path $AppDir 'settings.json')

    # shortcuts: Start menu (Start, Stop, Remove), the Desktop if chosen (Start, Stop; never Uninstall), plus the
    # Startup folder when it should start at sign-in
    $shell = New-Object -ComObject WScript.Shell
    function New-Shortcut($path, $script, $icon, $desc, $extra = '') {
        $s = $shell.CreateShortcut($path)
        $s.TargetPath = $ps
        $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $AppDir $script)`" $extra"
        $s.IconLocation = "$(Join-Path $AppDir $icon),0"
        $s.WorkingDirectory = $AppDir
        $s.Description = $desc
        $s.WindowStyle = 7
        $s.Save()
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Train Tracker'
    New-Item -ItemType Directory -Force -Path $menu | Out-Null
    $places = @($menu)
    if ($onDesktop) { $places += $desktop }
    else { Remove-Item (Join-Path $desktop 'Start Train Tracker.lnk'), (Join-Path $desktop 'Stop Train Tracker.lnk') -ErrorAction SilentlyContinue }
    Remove-Item (Join-Path $desktop 'Uninstall Train Tracker.lnk') -ErrorAction SilentlyContinue    # (0.5.0 put one there)
    foreach ($dir in $places) {
        New-Shortcut (Join-Path $dir 'Start Train Tracker.lnk') 'start.ps1' 'start.ico' 'Start US Train Tracker and open the map'
        New-Shortcut (Join-Path $dir 'Stop Train Tracker.lnk') 'stop.ps1' 'stop.ico' 'Stop US Train Tracker'
    }
    # Remove runs the uninstaller's script through PowerShell, like Start and Stop. Two things keep Windows' Start
    # menu from hiding it (found in the Win11 VM): no description (one about removing the program hides it), and a
    # new command on every install (-Installed <time>, ignored by the script), made as a new shortcut: Windows
    # remembers a Remove shortcut that went with an uninstall and hides any later one with the same command.
    Remove-Item (Join-Path $menu 'Uninstall Train Tracker.lnk') -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $menu 'Remove Train Tracker.lnk') -ErrorAction SilentlyContinue
    New-Shortcut (Join-Path $menu 'Remove Train Tracker.lnk') 'uninstall.ps1' 'uninstall.ico' '' "-Installed $(Get-Date -Format yyyyMMddHHmmss)"
    $startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'Train Tracker.lnk'
    if ($autostart) { New-Shortcut $startupLink 'start.ps1' 'start.ico' 'Start US Train Tracker at sign-in' '-NoBrowser' }
    else { Remove-Item $startupLink -ErrorAction SilentlyContinue }

    # Settings > Apps (and Control Panel > Programs) list it, with an Uninstall button that runs uninstall.ps1
    UI-Progress 'Listing Train Tracker in Settings > Apps...' 87
    $size = [int]((Get-ChildItem $AppDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1KB)
    $uninstall = "`"$(Join-Path $AppDir 'Uninstall Train Tracker.exe')`""
    New-Item -Path $UninstallKey -Force | Out-Null
    foreach ($v in @(@('DisplayName', 'US Train Tracker'), @('DisplayVersion', "$version"), @('Publisher', 'Project Moon Pi'),
                     @('DisplayIcon', (Join-Path $AppDir 'app.ico')), @('InstallLocation', $AppDir),
                     @('UninstallString', $uninstall), @('QuietUninstallString', "$uninstall -Quiet"),
                     @('URLInfoAbout', 'https://github.com/projectmoonpi/train-tracker'),
                     @('InstallDate', (Get-Date -Format 'yyyyMMdd')))) {
        New-ItemProperty -Path $UninstallKey -Name $v[0] -Value $v[1] -PropertyType String -Force | Out-Null
    }
    foreach ($v in @(@('NoModify', 1), @('NoRepair', 1), @('EstimatedSize', $size))) {
        New-ItemProperty -Path $UninstallKey -Name $v[0] -Value $v[1] -PropertyType DWord -Force | Out-Null
    }

    # moved from an older folder: it's stopped and everything in it has been replaced, so it can go
    foreach ($d in $others) { if (Test-Path (Join-Path $d 'settings.json')) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue } }

    # phones: make sure the firewall lets them in on home networks (Windows asks for permission only if needed;
    # firewall.ps1 says so first, over this window)
    $fw = Join-Path $AppDir 'firewall.ps1'
    $networkNote = ''
    if ($phones) {
        UI-Progress 'Letting phones on your home network reach the map...' 89
        $state = & $fw -Allow -Port $Port -Program $exe -Quiet:$UI_Unattended
        Log "firewall: $state"
        $public = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object NetworkCategory -eq 'Public').Count
        if ($state -eq 'Declined') {
            $networkNote = "Windows didn't allow the firewall change, so phones can't reach the map yet. Run the installer again and click Yes when Windows asks."
        } elseif ($public -and $state -ne 'AllowedPublic') {
            $networkNote = "This PC's network is set to Public, where Windows keeps other devices out. For phones to reach the map, set your home Wi-Fi to Private: Settings > Network & Internet > (your connection) > Private."
        }
    } else {
        & $fw -Port $Port -Quiet:$UI_Unattended
    }
    if ($networkNote) { Log $networkNote }

    # start it (the first start downloads the rail map and schedules, which can take a minute or two)
    UI-Progress 'Starting Train Tracker...' 90 'The very first start downloads the rail map and schedules: a minute or two.'
    $env:TT_INSTALLING = '1'    # (Start doesn't need to say it's already running)
    $p = Start-Process $ps -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$(Join-Path $AppDir 'start.ps1')`"", '-NoBrowser') -WindowStyle Hidden -PassThru
    $null = UI-Wait $p 100 90
    $up = $false
    try { $null = Invoke-WebRequest "http://127.0.0.1:$Port/api/info" -UseBasicParsing -TimeoutSec 5; $up = $true } catch { }
    Log "installed $version, running=$up"

    $did = @{ install = 'is installed'; update = 'is installed (updated from ' + $have + ')'; repair = 'is repaired'; fresh = 'is reinstalled from scratch' }[$mode]
    $done = "US Train Tracker $version $did" + $(if ($up) { ' and running.' } else { ', but it didn''t start yet: use Start Train Tracker in the Start menu.' }) +
        "`n`nIts train icon is by the clock (click ^ if Windows has tucked it away there). Start and Stop Train Tracker are in the Start menu" + $(if ($onDesktop) { ', and on your Desktop' } else { '' }) + ". To remove it, use Remove Train Tracker in the Start menu, Uninstall Train Tracker in $AppDir, or Settings > Apps." +
        $(if ($networkNote) { "`n`n$networkNote" } else { '' }) + $(($notes | ForEach-Object { "`n`n$_" }) -join '')
    $open = UI-Done $done 'Finish' @(@{ text = 'Open the map now'; checked = ($up -and $env:TT_OPEN -ne 'no') })
    if ($up -and $open -and $open[0] -and -not $UI_Unattended) { Start-Process "http://127.0.0.1:$Port" }
}

$WasRunning = $null
try { Main }
catch {
    Log "ERROR: $_"
    # it was running before the update began: start that copy again
    $again = ''
    if ($WasRunning -and (Test-Path (Join-Path $WasRunning 'start.ps1'))) {
        Start-Process (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$(Join-Path $WasRunning 'start.ps1')`"", '-NoBrowser')
        $again = "`n`nThe Train Tracker you already had is running again."
        Log "restarted $WasRunning"
    }
    UI-Error "Train Tracker wasn't installed.`n`n$_$again`n`nWhat the installer did is in $Log."
    exit 1
}
