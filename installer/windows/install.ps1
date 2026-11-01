# Install US Train Tracker on this PC (run by "Install Train Tracker.bat"; run it again later to update).
#
# Installs the program in %LOCALAPPDATA%\Train Tracker and puts Start, Stop and Uninstall Train Tracker on the
# Desktop and in the Start menu, and lists it in Windows' Settings > Apps (with its Uninstall button).
# (Before 0.5 the folder was %LOCALAPPDATA%\TrainTracker; an install there is moved over.) Needs Python 3.11 or newer; if it isn't there, it offers to install Python
# from python.org for this user only (checked: the expected download, signed by the Python Software Foundation).
# Designed and Created by Project Moon Pi.
#
# For unattended installs, answer the questions ahead: TT_PHONES=yes|no TT_AUTOSTART=yes|no TT_OPEN=no
# TT_PYTHON=yes|no (install Python if needed)
$ErrorActionPreference = 'Stop'
$Src = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$AppDir = Join-Path $env:LOCALAPPDATA 'Train Tracker'
$OldDir = Join-Path $env:LOCALAPPDATA 'TrainTracker'      # before 0.5
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProjectMoonPi.TrainTracker'
$Port = 7500
Add-Type -AssemblyName System.Windows.Forms

function Ask($preset, $text) {
    if ($preset) { return $preset -eq 'yes' }
    return [System.Windows.Forms.MessageBox]::Show($text, 'Install Train Tracker', 'YesNo', 'Question') -eq 'Yes'
}

function Run($exe, $argv, $what) {
    & $exe @argv
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)" }
}

Write-Host 'US Train Tracker installer - Designed and Created by Project Moon Pi'

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

function No-Python($why) {
    Write-Host 'Train Tracker needs Python 3.11 or newer from https://www.python.org/downloads/'
    $go = [System.Windows.Forms.MessageBox]::Show(
        "$why`n`nClick OK to open python.org. In its installer, tick `"Add python.exe to PATH`", then run Install Train Tracker again.",
        'Install Train Tracker', 'OKCancel', 'Information')
    if ($go -eq 'OK') { Start-Process 'https://www.python.org/downloads/' }
    exit 1
}

function Install-Python {
    $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $want = $PyFiles[$arch]
    if (-not $want) { $want = $PyFiles['x86'] }
    $exe = Join-Path $env:TEMP $want.file
    Write-Host "Downloading Python $PyVersion from python.org (about 30 MB)..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'    # the progress bar makes downloads very slow in Windows PowerShell
        Invoke-WebRequest "https://www.python.org/ftp/python/$PyVersion/$($want.file)" -OutFile $exe -UseBasicParsing
    } catch { No-Python "Python couldn't be downloaded. Check the internet connection." }
    try {
        if ((Get-FileHash $exe -Algorithm SHA256).Hash -ne $want.sha256) {
            No-Python "The Python download wasn't the expected file, so it wasn't installed."
        }
        $sig = Get-AuthenticodeSignature $exe
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O="?Python Software Foundation') {
            No-Python "The Python download isn't signed by the Python Software Foundation, so it wasn't installed."
        }
        Write-Host "Installing Python $PyVersion for this user (a minute or two)..."
        $p = Start-Process $exe -Wait -PassThru -ArgumentList @('/quiet', 'InstallAllUsers=0', 'PrependPath=1',
            'Include_launcher=1', 'InstallLauncherAllUsers=0', 'Include_test=0', 'Include_doc=0')
        if ($p.ExitCode -notin 0, 3010) { No-Python "Python's installer stopped (exit code $($p.ExitCode))." }
    } finally { Remove-Item $exe -Force -ErrorAction SilentlyContinue }
}

$py = Find-Python
if (-not $py) {
    $yes = Ask $env:TT_PYTHON "Train Tracker needs Python 3.11 or newer, and this PC doesn't have it.`n`nInstall Python $PyVersion from python.org now? It's free, about 30 MB, and installs just for you (no admin permission needed)."
    if (-not $yes) { No-Python 'Train Tracker needs Python 3.11 or newer.' }
    Install-Python
    $py = Find-Python
    if (-not $py) { No-Python 'Python was installed but can''t be found. Restart the PC and run Install Train Tracker again.' }
}

$phones = Ask $env:TT_PHONES "Should phones and tablets on your Wi-Fi be able to open the train map?`n`nThey'll find the address and a QR code in the map's panel. If the firewall needs opening for them, Windows asks for permission once (click Yes)."
$autostart = Ask $env:TT_AUTOSTART "Start Train Tracker by itself whenever you sign in to Windows?`n`nOtherwise, use the Start Train Tracker icon when you want it."

# an update: stop the running service first (also an install in the old folder)
foreach ($d in $AppDir, $OldDir) { if (Test-Path (Join-Path $d 'stop.ps1')) { & (Join-Path $d 'stop.ps1') -Quiet } }

Write-Host "Installing into $AppDir (about a minute)..."
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
$venvPy = Join-Path $AppDir 'venv\Scripts\python.exe'
# a fresh environment if there's none, or its Python was removed or is too old
$venvOk = $false
if (Test-Path $venvPy) {
    try { & $venvPy -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>$null; $venvOk = $LASTEXITCODE -eq 0 } catch { }
}
if (-not $venvOk) {
    Remove-Item (Join-Path $AppDir 'venv') -Recurse -Force -ErrorAction SilentlyContinue
    Run $py.exe ($py.pre + @('-m', 'venv', (Join-Path $AppDir 'venv'))) 'Setting up Python'
}
Run $venvPy @('-m', 'pip', 'install', '--quiet', '--upgrade', 'pip') 'Updating pip'
Run $venvPy @('-m', 'pip', 'install', '--quiet', '--upgrade', $Src) 'Installing Train Tracker'
$version = & $venvPy -c 'import train_tracker; print(train_tracker.__version__)'
# pystray and Pillow put Train Tracker's icon by the clock; without them it runs without the icon
try { Run $venvPy @('-m', 'pip', 'install', '--quiet', '--disable-pip-version-check', '--upgrade', 'pystray', 'pillow') 'Installing pystray and Pillow' }
catch { Write-Host "$_ - Train Tracker will run without its icon by the clock." }

foreach ($f in 'start.ps1', 'stop.ps1', 'uninstall.ps1', 'firewall.ps1') { Copy-Item (Join-Path $PSScriptRoot $f) $AppDir -Force }
foreach ($f in 'start.ico', 'stop.ico', 'uninstall.ico', 'app.ico') { Copy-Item (Join-Path $Src "installer\icons\$f") $AppDir -Force }
Get-ChildItem $AppDir -File | Unblock-File      # drop the "downloaded from the internet" mark on our own copies
# TrainTracker.exe: Python under Train Tracker's own name and icon, so Task Manager shows "Train Tracker"
# (pythonw.exe if not)
$ErrorActionPreference = 'Continue'
$exe = & $venvPy (Join-Path $PSScriptRoot 'brand_exe.py') $AppDir | Select-Object -Last 1
$ErrorActionPreference = 'Stop'
if (-not $exe -or -not (Test-Path $exe)) { $exe = Join-Path $AppDir 'venv\Scripts\pythonw.exe' }
@{ port = $Port; phones = $phones; autostart = $autostart; version = "$version"; exe = "$exe" } | ConvertTo-Json |
    Set-Content (Join-Path $AppDir 'settings.json')

# shortcuts: Desktop and Start menu, plus the Startup folder when it should start at sign-in
$shell = New-Object -ComObject WScript.Shell
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function New-Shortcut($path, $script, $icon, $desc, $extra = '') {
    $s = $shell.CreateShortcut($path)
    $s.TargetPath = $powershell
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
foreach ($dir in $desktop, $menu) {
    New-Shortcut (Join-Path $dir 'Start Train Tracker.lnk') 'start.ps1' 'start.ico' 'Start US Train Tracker and open the map'
    New-Shortcut (Join-Path $dir 'Stop Train Tracker.lnk') 'stop.ps1' 'stop.ico' 'Stop US Train Tracker'
    New-Shortcut (Join-Path $dir 'Uninstall Train Tracker.lnk') 'uninstall.ps1' 'uninstall.ico' 'Remove US Train Tracker from this PC'
}
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'Train Tracker.lnk'
if ($autostart) { New-Shortcut $startupLink 'start.ps1' 'start.ico' 'Start US Train Tracker at sign-in' '-NoBrowser' }
else { Remove-Item $startupLink -ErrorAction SilentlyContinue }

# Settings > Apps (and Control Panel > Programs) list it, with an Uninstall button that runs uninstall.ps1
$size = [int]((Get-ChildItem $AppDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1KB)
$uninstall = "`"$powershell`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $AppDir 'uninstall.ps1')`""
New-Item -Path $UninstallKey -Force | Out-Null
foreach ($v in @(@('DisplayName', 'US Train Tracker'), @('DisplayVersion', "$version"), @('Publisher', 'Project Moon Pi'),
                 @('DisplayIcon', (Join-Path $AppDir 'app.ico')), @('InstallLocation', $AppDir),
                 @('UninstallString', $uninstall), @('QuietUninstallString', "$uninstall -Quiet"),
                 @('URLInfoAbout', 'https://github.com/ricsne2010/train-tracker'),
                 @('InstallDate', (Get-Date -Format 'yyyyMMdd')))) {
    New-ItemProperty -Path $UninstallKey -Name $v[0] -Value $v[1] -PropertyType String -Force | Out-Null
}
foreach ($v in @(@('NoModify', 1), @('NoRepair', 1), @('EstimatedSize', $size))) {
    New-ItemProperty -Path $UninstallKey -Name $v[0] -Value $v[1] -PropertyType DWord -Force | Out-Null
}

# moved from the old folder: it's stopped and everything in it has been replaced, so it can go
if (Test-Path $OldDir) { Remove-Item $OldDir -Recurse -Force -ErrorAction SilentlyContinue }

# phones: make sure the firewall lets them in on home networks (Windows asks for permission only if needed)
$fw = Join-Path $AppDir 'firewall.ps1'
$networkNote = ''
if ($phones) {
    Write-Host 'Checking that phones on your home network can reach Train Tracker...'
    $state = & $fw -Allow -Port $Port -Program $exe      # the program that listens
    $public = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object NetworkCategory -eq 'Public').Count
    if ($state -eq 'Declined') {
        $networkNote = "Windows didn't allow the firewall change, so phones can't reach the map yet. Run the installer again and click Yes when Windows asks."
    } elseif ($public -and $state -ne 'AllowedPublic') {
        $networkNote = "This PC's network is set to Public, where Windows keeps other devices out. For phones to reach the map, set your home Wi-Fi to Private: Settings > Network & Internet > (your connection) > Private."
    }
} else {
    & $fw -Port $Port
}
if ($networkNote) { Write-Host $networkNote }

Write-Host "Installed US Train Tracker $version. Starting it..."
$env:TT_INSTALLING = '1'    # (Start doesn't need to say it's already running)
if ($env:TT_OPEN -eq 'no') { & (Join-Path $AppDir 'start.ps1') -NoBrowser } else { & (Join-Path $AppDir 'start.ps1') }
Write-Host 'Done. Use Start Train Tracker and Stop Train Tracker on your Desktop (also in the Start menu); Uninstall Train Tracker is there too, and in Settings > Apps.'
if (-not $env:TT_PHONES) {
    [System.Windows.Forms.MessageBox]::Show(
        "Train Tracker is installed and running.`n`nWhile it runs, its green train icon sits by the clock (click ^ if it's hidden there). Click it for the map, or right-click for the API keys or to stop Train Tracker.`n`nUse Start Train Tracker and Stop Train Tracker on your Desktop (also in the Start menu, under Train Tracker). To remove it, use Uninstall Train Tracker there, or Settings > Apps.`n`nYou can delete the downloaded folder now." + $(if ($networkNote) { "`n`n$networkNote" } else { '' }),
        'Install Train Tracker', 'OK', 'Information') | Out-Null
}
