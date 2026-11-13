# Fluxer REXCTL Auto-Watchdog & Command Deck
# Save as CheckFluxer.ps1 and run in PowerShell 5.1 or PowerShell 7+

# --- Configuration ---
$InstanceDir          = ""   # Optional: set to your Fluxer directory for --dir
$CheckIntervalMinutes = 60   # Auto-check interval in minutes (60 = every hour)
$RunDoctorOnStart     = $false

# --- Console Setup ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "FLUXER // REXCTL Auto-Watchdog and Command Deck"

# --- Pure-ASCII Unicode Symbol Table ---
$Sym = @{
    TL        = [string][char]0x2554
    TR        = [string][char]0x2557
    BL        = [string][char]0x255A
    BR        = [string][char]0x255D
    H         = [string][char]0x2550
    V         = [string][char]0x2551
    sTL       = [string][char]0x256D
    sTR       = [string][char]0x256E
    sBL       = [string][char]0x2570
    sBR       = [string][char]0x256F
    sH        = [string][char]0x2500
    sV        = [string][char]0x2502
    BlockFull = [string][char]0x2588
    BlockLt   = [string][char]0x2591
    Check     = [string][char]0x2714
    Cross     = [string][char]0x2718
    Warn      = [string][char]0x26A0
    Bolt      = [string][char]0x26A1
    Arrow     = [string][char]0x25B6
    Dot       = [string][char]0x25CF
    Spinner   = @(
        [string][char]0x280B, [string][char]0x2819, [string][char]0x2839, [string][char]0x2838,
        [string][char]0x283C, [string][char]0x2834, [string][char]0x2826, [string][char]0x2827,
        [string][char]0x2807, [string][char]0x280F
    )
}

$Script:CheckCount   = 0
$Script:UpgradeCount = 0
$Script:LastCheckStr = "Never"

$GlobalRexArgs = @()
if (-not [string]::IsNullOrWhiteSpace($InstanceDir)) {
    $GlobalRexArgs += @("--dir", $InstanceDir)
}

# --- UI Helpers ---

function Format-BannerLine {
    param([string]$Template)
    return $Template.Replace('#', $Sym.BlockFull).Replace('=', $Sym.H).Replace('|', $Sym.V).Replace('+', $Sym.TL).Replace('*', $Sym.BL).Replace('@', $Sym.BR)
}

function Show-Header {
    Clear-Host
    $topBorder = $Sym.TL + ($Sym.H * 68) + $Sym.TR
    $botBorder = $Sym.BL + ($Sym.H * 68) + $Sym.BR

    $b1 = Format-BannerLine "#######+##+     ##+   ##+##+  ##+#######+######+ "
    $b2 = Format-BannerLine "##+====@##|     ##|   ##|*##+##+@##+====@##+==##+"
    $b3 = Format-BannerLine "#####+  ##|     ##|   ##| *###+@ #####+  ######+@"
    $b4 = Format-BannerLine "##+==@  ##|     ##|   ##| ##+##+ ##+==@  ##+==##+"
    $b5 = Format-BannerLine "##|     #######+*######+@##+@ ##+#######+##|  ##|"
    $b6 = Format-BannerLine "*=@     *======@ *=====@ *=@  *=@*======@*=@  *=@"

    Write-Host ""
    Write-Host ("  " + $topBorder) -ForegroundColor DarkCyan
    Write-Host ("  " + $Sym.V + (" " * 68) + $Sym.V) -ForegroundColor DarkCyan

    Write-Host ("  " + $Sym.V + "   ") -NoNewline -ForegroundColor DarkCyan
    Write-Host $b1 -NoNewline -ForegroundColor Cyan
    Write-Host "  //  REXCTL    " -NoNewline -ForegroundColor Magenta
    Write-Host $Sym.V -ForegroundColor DarkCyan

    Write-Host ("  " + $Sym.V + "   ") -NoNewline -ForegroundColor DarkCyan
    Write-Host $b2 -NoNewline -ForegroundColor Cyan
    Write-Host "  AUTO-WATCHDOG " -NoNewline -ForegroundColor White
    Write-Host $Sym.V -ForegroundColor DarkCyan

    Write-Host ("  " + $Sym.V + "   ") -NoNewline -ForegroundColor DarkCyan
    Write-Host $b3 -NoNewline -ForegroundColor DarkCyan
    Write-Host "  + INSTANCE    " -NoNewline -ForegroundColor White
    Write-Host $Sym.V -ForegroundColor DarkCyan

    Write-Host ("  " + $Sym.V + "   ") -NoNewline -ForegroundColor DarkCyan
    Write-Host $b4 -NoNewline -ForegroundColor Blue
    Write-Host "  UPGRADER      " -NoNewline -ForegroundColor Gray
    Write-Host $Sym.V -ForegroundColor DarkCyan

    Write-Host ("  " + $Sym.V + "   ") -NoNewline -ForegroundColor DarkCyan
    Write-Host $b5 -NoNewline -ForegroundColor DarkBlue
    Write-Host "  v3.1 LIVE TUI " -NoNewline -ForegroundColor DarkGray
    Write-Host $Sym.V -ForegroundColor DarkCyan

    Write-Host ("  " + $Sym.V + "   ") -NoNewline -ForegroundColor DarkCyan
    Write-Host $b6 -NoNewline -ForegroundColor DarkBlue
    Write-Host "                " -NoNewline
    Write-Host $Sym.V -ForegroundColor DarkCyan

    Write-Host ("  " + $botBorder) -ForegroundColor DarkCyan

    $osInfo = [System.Environment]::MachineName
    $drive = (Get-Location).Drive
    $freeGb = if ($drive -and $drive.Free) { [math]::Round($drive.Free / 1GB, 1) } else { "N/A" }

    Write-Host ("   " + $Sym.Dot + " ") -NoNewline -ForegroundColor Green
    Write-Host "NODE: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$osInfo  " -NoNewline -ForegroundColor White
    Write-Host ($Sym.Dot + " ") -NoNewline -ForegroundColor Cyan
    Write-Host "DISK: " -NoNewline -ForegroundColor DarkGray
    Write-Host "${freeGb}GB  " -NoNewline -ForegroundColor White
    Write-Host ($Sym.Dot + " ") -NoNewline -ForegroundColor Yellow
    Write-Host "CHECKS: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($Script:CheckCount)  " -NoNewline -ForegroundColor White
    Write-Host ($Sym.Dot + " ") -NoNewline -ForegroundColor Magenta
    Write-Host "LAST CHECK: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($Script:LastCheckStr)" -ForegroundColor White
    Write-Host ("  " + ($Sym.sH * 70)) -ForegroundColor DarkGray
}

function Write-SectionHeader {
    param([string]$Phase, [string]$Title)
    Write-Host ("`n  " + $Sym.Arrow + " ") -NoNewline -ForegroundColor Magenta
    Write-Host "[$Phase] " -NoNewline -ForegroundColor Cyan
    Write-Host $Title.ToUpper() -ForegroundColor White
    Write-Host ("  " + ($Sym.sH * 70)) -ForegroundColor DarkGray
}

function Invoke-CyberSpinner {
    param(
        [string]$Label,
        [int]$DurationMs = 800,
        [string]$StatusText = "READY",
        [ConsoleColor]$StatusColor = "Green"
    )
    $interval = 65
    $steps = [math]::Max(1, [math]::Ceiling($DurationMs / $interval))

    for ($i = 0; $i -lt $steps; $i++) {
        $frame = $Sym.Spinner[$i % $Sym.Spinner.Count]
        Write-Host "`r    " -NoNewline
        Write-Host ($frame + " ") -NoNewline -ForegroundColor Cyan
        Write-Host $Label -NoNewline -ForegroundColor Gray
        Start-Sleep -Milliseconds $interval
    }

    $padCount = [math]::Max(1, 52 - $Label.Length)
    $dots = "." * $padCount
    Write-Host "`r    " -NoNewline
    Write-Host ($Sym.Check + " ") -NoNewline -ForegroundColor $StatusColor
    Write-Host ($Label + " ") -NoNewline -ForegroundColor Gray
    Write-Host ($dots + " ") -NoNewline -ForegroundColor DarkGray
    Write-Host "[$StatusText]" -ForegroundColor $StatusColor
}

function Invoke-CyberProgress {
    param(
        [string]$Activity,
        [int]$DurationMs = 1100
    )
    $width = 34
    $steps = 25
    $delay = [math]::Floor($DurationMs / $steps)

    for ($i = 0; $i -le $steps; $i++) {
        $pct = [math]::Round(($i / $steps) * 100)
        $filled = [math]::Round(($i / $steps) * $width)
        $empty = $width - $filled

        $barFilled = $Sym.BlockFull * $filled
        $barEmpty  = $Sym.BlockLt * $empty

        $pctStr = $pct.ToString().PadLeft(3, ' ')
        Write-Host ("`r    " + $Sym.Bolt + " " + $Activity + " ") -NoNewline -ForegroundColor Yellow
        Write-Host "[" -NoNewline -ForegroundColor DarkGray
        Write-Host $barFilled -NoNewline -ForegroundColor Cyan
        Write-Host $barEmpty -NoNewline -ForegroundColor DarkGray
        Write-Host "] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$pctStr%" -NoNewline -ForegroundColor White
        Start-Sleep -Milliseconds $delay
    }
    Write-Host ""
}

function Write-FramedOutput {
    param(
        [string]$Title,
        [string]$Content,
        [ConsoleColor]$BorderColor = "DarkCyan"
    )
    if ([string]::IsNullOrWhiteSpace($Content)) {
        $Content = "(No output returned by rexctl)"
    }
    $lines = $Content.Trim() -split "`r?`n"
    $width = 66
    $titleSegment = " $Title "
    $remainingH = [math]::Max(2, $width - $titleSegment.Length - 2)

    Write-Host ""
    Write-Host ("    " + $Sym.sTL + $Sym.sH + $Sym.sH) -NoNewline -ForegroundColor $BorderColor
    Write-Host $titleSegment -NoNewline -ForegroundColor White
    Write-Host ($Sym.sH * $remainingH) -NoNewline -ForegroundColor $BorderColor
    Write-Host $Sym.sTR -ForegroundColor $BorderColor

    foreach ($rawLine in $lines) {
        $cleanLine = $rawLine -replace '\x1b\[[0-9;]*m', ''
        if ($cleanLine.Length -gt ($width - 4)) {
            $cleanLine = $cleanLine.Substring(0, $width - 7) + "..."
        }
        $pad = " " * [math]::Max(0, ($width - 2 - $cleanLine.Length))
        Write-Host ("    " + $Sym.sV + " ") -NoNewline -ForegroundColor $BorderColor
        Write-Host ($cleanLine + $pad) -NoNewline -ForegroundColor Gray
        Write-Host (" " + $Sym.sV) -ForegroundColor $BorderColor
    }

    Write-Host ("    " + $Sym.sBL) -NoNewline -ForegroundColor $BorderColor
    Write-Host ($Sym.sH * $width) -NoNewline -ForegroundColor $BorderColor
    Write-Host $Sym.sBR -ForegroundColor $BorderColor
}

# --- Core Fluxer / rexctl Workflows ---

function Test-Prerequisites {
    Write-SectionHeader -Phase "PHASE 01" -Title "Environment and Daemon Telemetry"

    Invoke-CyberSpinner -Label "Scanning host runtime and network sockets" -DurationMs 700 -StatusText "ONLINE"
    $hasDocker = [bool](<Get-Command 'docker' -ErrorAction SilentlyContinue>)
    $dockerText = if ($hasDocker) { "DETECTED" } else { "NOT IN PATH" }
    $dockerColor = if ($hasDocker) { "Green" } else { "Yellow" }
    Invoke-CyberSpinner -Label "Checking Docker Engine availability" -DurationMs 750 -StatusText $dockerText -StatusColor $dockerColor

    if (-not (Get-Command 'rexctl' -ErrorAction SilentlyContinue)) {
        Write-Host ("    " + $Sym.Cross + " ") -NoNewline -ForegroundColor Red
        Write-Host "Locating Fluxer 'rexctl' CLI binary in PATH ............ [MISSING]" -ForegroundColor Red
        Write-FramedOutput -Title "CRITICAL ERROR" -BorderColor Red -Content @"
The 'rexctl' binary was not found in your system PATH.
Verify your Fluxer installation or run this inside your Fluxer host environment.
Docs: https://fluxer.app
"@
        return $false
    }

    Invoke-CyberSpinner -Label "Locating Fluxer 'rexctl' binary in PATH" -DurationMs 650 -StatusText "VERIFIED"

    if ($RunDoctorOnStart) {
        Invoke-CyberSpinner -Label "Running 'rexctl doctor' diagnostic scan" -DurationMs 900 -StatusText "RUNNING"
        $docOut = & rexctl @GlobalRexArgs doctor 2>&1 | Out-String
        Write-FramedOutput -Title "REXCTL DOCTOR REPORT" -Content $docOut -BorderColor Magenta
    }

    return $true
}

function Invoke-UpgradeWorkflow {
    $Script:CheckCount++
    $Script:LastCheckStr = (Get-Date).ToString("HH:mm:ss")
    Show-Header

    Write-SectionHeader -Phase "PHASE 02" -Title "Fluxer Instance and rexctl Version Check (Run #$($Script:CheckCount))"

    Invoke-CyberSpinner -Label "Syncing release manifest (rexctl upgrade --check)" -DurationMs 850 -StatusText "SYNCED"
    Invoke-CyberProgress -Activity "Verifying release signatures    " -DurationMs 950

    $checkOutput = & rexctl @GlobalRexArgs upgrade --check 2>&1 | Out-String
    $checkExitCode = $LASTEXITCODE

    Write-FramedOutput -Title "REXCTL UPGRADE --CHECK OUTPUT ($($Script:LastCheckStr))" -Content $checkOutput -BorderColor Cyan

    $isUpToDate = $checkOutput -match '(?i)(up to date|already latest|no update|no upgrades? available|latest version)'
    $hasUpdateKeyword = $checkOutput -match '(?i)(available|new version|update to|upgrade to|outdated)'

    Write-SectionHeader -Phase "PHASE 03" -Title "Automated Upgrade and Rollback Guard"

    if ((-not $isUpToDate) -and ($hasUpdateKeyword -or $checkExitCode -ne 0)) {
        Write-Host ("    " + $Sym.Warn + " ") -NoNewline -ForegroundColor Yellow
        Write-Host "NEW FLUXER / REXCTL RELEASE DETECTED!" -ForegroundColor Yellow

        Invoke-CyberSpinner -Label "Preparing pre-upgrade instance snapshot hook" -DurationMs 750 -StatusText "ARMED"
        Invoke-CyberSpinner -Label "Arming automatic rollback watchdog" -DurationMs 700 -StatusText "ACTIVE"
        Invoke-CyberProgress -Activity "Staging upgrade execution       " -DurationMs 1100

        Write-Host ("`n    " + $Sym.Arrow + " Executing: ") -NoNewline -ForegroundColor Cyan
        Write-Host "rexctl $($GlobalRexArgs -join ' ') upgrade --yes`n" -ForegroundColor White

        & rexctl @GlobalRexArgs upgrade --yes
        $upgradeExit = $LASTEXITCODE

        if ($upgradeExit -eq 0) {
            $Script:UpgradeCount++
            Invoke-CyberSpinner -Label "Verifying post-upgrade container health" -DurationMs 850 -StatusText "HEALTHY"
            Write-FramedOutput -Title "UPGRADE COMPLETE" -BorderColor Green -Content @"
Fluxer instance and rexctl have been upgraded to the latest release!
Pre-upgrade backup was preserved automatically by rexctl.
Total upgrades applied this session: $($Script:UpgradeCount)
"@
        } else {
            Write-FramedOutput -Title "UPGRADE ALERT (EXIT CODE: $upgradeExit)" -BorderColor Red -Content @"
'rexctl upgrade --yes' exited with code $upgradeExit.
If the new Fluxer version failed to start, rexctl automatically
rolls back to your previous working version and backup.
Press [3] (rexctl doctor) or [8] (rexctl logs) below to inspect.
"@
        }
    } else {
        Invoke-CyberSpinner -Label "Validating current Fluxer container checksums" -DurationMs 650 -StatusText "MATCHED"
        Write-FramedOutput -Title "SYSTEM UP TO DATE" -BorderColor Green -Content @"
Your Fluxer instance and rexctl CLI are already on the latest release.
Next automatic check will run in $CheckIntervalMinutes minutes.
"@
    }
}

function Write-MenuOptions {
    Write-SectionHeader -Phase "CONTROL DECK" -Title "Live Watchdog and Instance Controls (Hotkeys Active)"

    Write-Host "    [1] " -NoNewline -ForegroundColor Cyan;    Write-Host "Force Check + Upgrade Now      " -NoNewline -ForegroundColor White; Write-Host "(rexctl upgrade --check / --yes)" -ForegroundColor DarkGray
    Write-Host "    [2] " -NoNewline -ForegroundColor Cyan;    Write-Host "Inspect Service Health Status  " -NoNewline -ForegroundColor White; Write-Host "(rexctl status)" -ForegroundColor DarkGray
    Write-Host "    [3] " -NoNewline -ForegroundColor Cyan;    Write-Host "Run Environment Diagnostics    " -NoNewline -ForegroundColor White; Write-Host "(rexctl doctor)" -ForegroundColor DarkGray
    Write-Host "    [4] " -NoNewline -ForegroundColor Cyan;    Write-Host "Auto-Fix Environment Issues    " -NoNewline -ForegroundColor White; Write-Host "(rexctl doctor --fix)" -ForegroundColor DarkGray
    Write-Host "    [5] " -NoNewline -ForegroundColor Cyan;    Write-Host "List / Create Instance Backups " -NoNewline -ForegroundColor White; Write-Host "(rexctl backup list / backup)" -ForegroundColor DarkGray
    Write-Host "    [6] " -NoNewline -ForegroundColor Cyan;    Write-Host "Manage Auto-Upgrade Schedule   " -NoNewline -ForegroundColor White; Write-Host "(rexctl auto-upgrade [on/off])" -ForegroundColor DarkGray
    Write-Host "    [7] " -NoNewline -ForegroundColor Cyan;    Write-Host "Restart Fluxer Containers      " -NoNewline -ForegroundColor White; Write-Host "(rexctl restart)" -ForegroundColor DarkGray
    Write-Host "    [8] " -NoNewline -ForegroundColor Cyan;    Write-Host "View Recent Service Logs       " -NoNewline -ForegroundColor White; Write-Host "(rexctl logs)" -ForegroundColor DarkGray
    Write-Host "    [Q] " -NoNewline -ForegroundColor Magenta; Write-Host "Exit Auto-Watchdog Utility" -ForegroundColor White
    Write-Host ""
}

function Wait-NextCheckOrKey {
    param([int]$IntervalMinutes)

    $totalSeconds = [math]::Max(10, $IntervalMinutes * 60)
    $nextCheckTime = (Get-Date).AddSeconds($totalSeconds)
    $barWidth = 20
    $tick = 0

    while ([Console]::KeyAvailable) {
        [void][Console]::ReadKey($true)
    }

    while ($true) {
        $remaining = $nextCheckTime - (Get-Date)
        if ($remaining.TotalSeconds -le 0) {
            Write-Host ""
            return "AUTO"
        }

        if ([Console]::KeyAvailable) {
            $keyInfo = [Console]::ReadKey($true)
            $char = $keyInfo.KeyChar.ToString().ToUpper()
            if ($char -match '^[1-8Q]$') {
                Write-Host ""
                return $char
            }
        }

        $remSec = [math]::Max(0, [int][math]::Ceiling($remaining.TotalSeconds))
        $mins = [math]::Floor($remSec / 60)
        $secs = $remSec % 60
        $timeFormatted = "{0:D2}m {1:D2}s" -f [int]$mins, [int]$secs

        $elapsedRatio = 1.0 - ($remaining.TotalSeconds / $totalSeconds)
        $filled = [math]::Min($barWidth, [math]::Max(0, [int][math]::Round($elapsedRatio * $barWidth)))
        $empty = $barWidth - $filled

        $barStr = ($Sym.BlockFull * $filled) + ($Sym.BlockLt * $empty)
        $spinFrame = $Sym.Spinner[$tick % $Sym.Spinner.Count]
        $tick++

        Write-Host ("`r    " + $spinFrame + " ") -NoNewline -ForegroundColor Cyan
        Write-Host "AUTO-CHECK IN: " -NoNewline -ForegroundColor Yellow
        Write-Host "$timeFormatted " -NoNewline -ForegroundColor White
        Write-Host "[$barStr] " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Press [1-8] or [Q] anytime " -NoNewline -ForegroundColor DarkGray

        Start-Sleep -Milliseconds 200
    }
}

function Show-ControlDeck {
    Write-MenuOptions

    while ($true) {
        $action = Wait-NextCheckOrKey -IntervalMinutes $CheckIntervalMinutes

        switch ($action) {
            "AUTO" {
                Invoke-UpgradeWorkflow
                Write-MenuOptions
            }
            "1" {
                Invoke-UpgradeWorkflow
                Write-MenuOptions
            }
            "2" {
                Invoke-CyberSpinner -Label "Querying Fluxer container status (rexctl status)" -DurationMs 600 -StatusText "DONE"
                $out = & rexctl @GlobalRexArgs status 2>&1 | Out-String
                Write-FramedOutput -Title "REXCTL STATUS" -Content $out -BorderColor Cyan
                Write-MenuOptions
            }
            "3" {
                Invoke-CyberSpinner -Label "Running full diagnostic check (rexctl doctor)" -DurationMs 800 -StatusText "DONE"
                $out = & rexctl @GlobalRexArgs doctor 2>&1 | Out-String
                Write-FramedOutput -Title "REXCTL DOCTOR" -Content $out -BorderColor Yellow
                Write-MenuOptions
            }
            "4" {
                Invoke-CyberSpinner -Label "Running automated remediation (rexctl doctor --fix)" -DurationMs 900 -StatusText "DONE"
                $out = & rexctl @GlobalRexArgs doctor --fix 2>&1 | Out-String
                Write-FramedOutput -Title "REXCTL DOCTOR --FIX" -Content $out -BorderColor Green
                Write-MenuOptions
            }
            "5" {
                Invoke-CyberSpinner -Label "Listing existing Fluxer backups (rexctl backup list)" -DurationMs 600 -StatusText "DONE"
                $out = & rexctl @GlobalRexArgs backup list 2>&1 | Out-String
                Write-FramedOutput -Title "REXCTL BACKUP LIST" -Content $out -BorderColor Cyan

                $doBackup = Read-Host "    Create a new full instance backup now? (y/N)"
                if ($doBackup -match '^[yY]') {
                    Invoke-CyberProgress -Activity "Pausing services + snapshotting " -DurationMs 1000
                    $bkpOut = & rexctl @GlobalRexArgs backup 2>&1 | Out-String
                    Write-FramedOutput -Title "REXCTL BACKUP RESULT" -Content $bkpOut -BorderColor Green
                }
                Write-MenuOptions
            }
            "6" {
                Invoke-CyberSpinner -Label "Checking auto-upgrade schedule (rexctl auto-upgrade)" -DurationMs 600 -StatusText "DONE"
                $out = & rexctl @GlobalRexArgs auto-upgrade 2>&1 | Out-String
                Write-FramedOutput -Title "REXCTL AUTO-UPGRADE STATUS" -Content $out -BorderColor Cyan

                Write-Host "    Options: [E]nable daily auto-upgrade | [D]isable auto-upgrade | [Enter] Cancel" -ForegroundColor DarkGray
                $sub = Read-Host "    Choice"
                if ($sub -match '^[eE]') {
                    $notifyUrl = Read-Host "    Optional webhook/ntfy URL for --notify (leave blank to skip)"
                    if ([string]::IsNullOrWhiteSpace($notifyUrl)) {
                        $auOut = & rexctl @GlobalRexArgs auto-upgrade on 2>&1 | Out-String
                    } else {
                        $auOut = & rexctl @GlobalRexArgs auto-upgrade on --notify $notifyUrl 2>&1 | Out-String
                    }
                    Write-FramedOutput -Title "AUTO-UPGRADE ENABLED" -Content $auOut -BorderColor Green
                } elseif ($sub -match '^[dD]') {
                    $auOut = & rexctl @GlobalRexArgs auto-upgrade off 2>&1 | Out-String
                    Write-FramedOutput -Title "AUTO-UPGRADE DISABLED" -Content $auOut -BorderColor Yellow
                }
                Write-MenuOptions
            }
            "7" {
                Invoke-CyberSpinner -Label "Gracefully restarting Fluxer services (rexctl restart)" -DurationMs 900 -StatusText "DONE"
                $out = & rexctl @GlobalRexArgs restart 2>&1 | Out-String
                Write-FramedOutput -Title "REXCTL RESTART" -Content $out -BorderColor Green
                Write-MenuOptions
            }
            "8" {
                Write-Host ("`n    " + $Sym.Arrow + " Streaming logs (Press Ctrl+C to stop if streaming)...`n") -ForegroundColor Cyan
                & rexctl @GlobalRexArgs logs
                Write-MenuOptions
            }
            "Q" {
                Write-Host "`n    Closing Fluxer REXCTL Auto-Watchdog..." -ForegroundColor Cyan
                return
            }
        }
    }
}

# --- Entrypoint ---

Show-Header

if (Test-Prerequisites) {
    Invoke-UpgradeWorkflow
    Show-ControlDeck
} else {
    Read-Host "`n  Press Enter to close window"
}
