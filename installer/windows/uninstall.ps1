# Uninstall Train Tracker, in a window: removes the service, the shortcuts and the program, and your data too if you
# tick the box. Designed and Created by Project Moon Pi.
# -Quiet (or TT_UNATTENDED=1): no window; removes the program and keeps your data
param([switch]$Quiet, [string]$Installed)    # (-Installed: the Start menu shortcut's install time, only so Windows lists it)
$AppDir = $PSScriptRoot
$unattended = $Quiet -or [bool]$env:TT_UNATTENDED
$UI_Unattended = $unattended
. (Join-Path $AppDir 'ui.ps1')
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Main {
    $deleteData = $false
    if (-not $unattended) {
        UI-Open 'Uninstall US Train Tracker' (Join-Path $AppDir 'logo.png') (Join-Path $AppDir 'uninstall.ico') 'US Train Tracker'
        $choices = UI-Choices 'Remove US Train Tracker from this PC? It stops Train Tracker and removes the program and its shortcuts. Python stays, for anything else that uses it.' @(
            @{ text = 'Also delete the downloaded maps and schedules, and any API keys you saved'; checked = $false }) 'Uninstall'
        if ($null -eq $choices) { UI-Close; return }
        $deleteData = $choices[0]
    }

    if (-not $unattended) { UI-Progress 'Stopping Train Tracker...' 10 }
    $p = Start-Process $ps -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$(Join-Path $AppDir 'stop.ps1')`"", '-Quiet') -WindowStyle Hidden -PassThru
    if ($unattended) { $p.WaitForExit() } else { $null = UI-Wait $p 40 10 }
    $cfg = Get-Content (Join-Path $AppDir 'settings.json') -Raw | ConvertFrom-Json

    # close the port for phones (Windows asks for permission only if there's a rule to remove; firewall.ps1 says
    # so first)
    if (-not $unattended) { UI-Progress 'Closing the firewall for phones...' 50 }
    if (Test-Path (Join-Path $AppDir 'firewall.ps1')) { $null = & (Join-Path $AppDir 'firewall.ps1') -Port $cfg.port -Quiet:$unattended }

    if (-not $unattended) { UI-Progress 'Removing the shortcuts...' 65 }
    $desktop = [Environment]::GetFolderPath('Desktop')
    Remove-Item (Join-Path $desktop 'Start Train Tracker.lnk'), (Join-Path $desktop 'Stop Train Tracker.lnk'),
        (Join-Path $desktop 'Uninstall Train Tracker.lnk') -ErrorAction SilentlyContinue
    Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProjectMoonPi.TrainTracker' -Recurse -ErrorAction SilentlyContinue   # Settings > Apps
    Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'Train Tracker.lnk') -ErrorAction SilentlyContinue
    Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'Train Tracker') -Recurse -ErrorAction SilentlyContinue

    if ($deleteData) {
        UI-Progress 'Deleting the downloaded maps, schedules and API keys...' 75
        Remove-Item (Join-Path $env:USERPROFILE '.train-tracker') -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not $unattended) { UI-Progress 'Removing the program...' 95 }
    # Windows won't delete a folder a program is in: step out of it (PowerShell's location and the process's own)
    Set-Location $env:TEMP
    [Environment]::CurrentDirectory = $env:TEMP
    Remove-Item $AppDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $AppDir) {
        # something in it was still in use (Uninstall Train Tracker.exe, if it hadn't quite closed): a moment later
        # rmdir /s gets the rest, and the Project Moon Pi folder if that's then empty (rmdir without /s only removes an empty folder)
        $tidy = if ((Split-Path (Split-Path $AppDir) -Leaf) -eq 'Project Moon Pi') { " & rmdir `"$(Split-Path $AppDir)`" 2>nul" } else { '' }
        Start-Process -WindowStyle Hidden -FilePath (Join-Path $env:SystemRoot 'System32\cmd.exe') -WorkingDirectory $env:TEMP `
            -ArgumentList "/c ping -n 4 127.0.0.1 >nul & rmdir /s /q `"$AppDir`"$tidy"
        Start-Sleep -Seconds 4
    }
    # and the Project Moon Pi folder it was in, once it's empty (no other Project Moon Pi app left there)
    $parent = Split-Path $AppDir
    if ((Split-Path $parent -Leaf) -eq 'Project Moon Pi' -and -not (Get-ChildItem $parent -Force -ErrorAction SilentlyContinue)) {
        Remove-Item $parent -Force -ErrorAction SilentlyContinue
    }
    if (-not $unattended) {
        $left = Test-Path $AppDir
        $null = UI-Done ("US Train Tracker has been removed." + $(if ($left) { "`n`nA few files in $AppDir were in use; they go when you restart the PC, or you can delete that folder." } else { '' }) +
            $(if (-not $deleteData) { "`n`nYour downloaded maps and any API keys are still in $(Join-Path $env:USERPROFILE '.train-tracker'), for if you install it again." } else { '' })) 'Close'
    }
}

try { Main }
catch {
    if ($unattended) { throw }
    UI-Error "Train Tracker wasn't fully removed.`n`n$_"
}
