# Stop Train Tracker: shuts down the background service. The map stops updating until it's started again.
# -Quiet: no message afterwards (used by the installer and uninstaller).
# Designed and Created by Project Moon Pi.
param([switch]$Quiet)
$AppDir = $PSScriptRoot
$cfg = Get-Content (Join-Path $AppDir 'settings.json') -Raw | ConvertFrom-Json
$port = $cfg.port
$pidFile = Join-Path $AppDir 'train-tracker.pid'

function Test-Up {
    try { $null = Invoke-WebRequest "http://127.0.0.1:$port/api/info" -UseBasicParsing -TimeoutSec 1; return $true }
    catch { return $false }
}

function Stop-IfPython($id) {
    # TrainTracker.exe is Python under Train Tracker's name (see brand_exe.py)
    $p = Get-Process -Id $id -ErrorAction SilentlyContinue
    if ($p -and ($p.ProcessName -like 'python*' -or $p.ProcessName -eq 'TrainTracker')) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
}
$wasUp = Test-Up
if (Test-Path $pidFile) {
    Stop-IfPython ([int](Get-Content $pidFile))
    Remove-Item $pidFile -ErrorAction SilentlyContinue
}
# also whatever Python program is serving the map on our port (started some other way)
Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-IfPython $_.OwningProcess }
# and its icon by the clock: it goes by itself within a few seconds of the server (closing it by force would
# leave a dead icon there until the mouse passes over it), so only if it hasn't
for ($i = 0; $i -lt 16; $i++) {
    $icon = @(Get-Process -Name TrainTracker -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$AppDir\*" })
    if (-not $icon) { break }
    Start-Sleep -Milliseconds 500
}
$icon | Stop-Process -Force -ErrorAction SilentlyContinue

$still = $true
for ($i = 0; $i -lt 20; $i++) {
    if (-not (Test-Up)) { $still = $false; break }
    Start-Sleep -Milliseconds 500
}
if (-not $Quiet) {
    $shell = New-Object -ComObject WScript.Shell
    if ($still) { $null = $shell.Popup("Train Tracker is still running: something else may be using port $port.", 0, 'Train Tracker', 48) }
    elseif ($wasUp) { $null = $shell.Popup('Train Tracker has stopped.', 4, 'Train Tracker', 64) }
    else { $null = $shell.Popup("Train Tracker wasn't running.", 4, 'Train Tracker', 64) }
}
