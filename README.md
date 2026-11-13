# Fluxer REXCTL Auto-Watchdog & Command Deck

> [!WARNING]
> **Disclaimer:** This project was written with **Google Gemini 4 Hydrogen** and is **100% vibecoded**. Review the script before running it in production environments.

A PowerShell terminal UI (TUI) watchdog and management console for self-hosted **Fluxer** instances using `rexctl`. It automatically checks for updates every hour, applies upgrades when available, and gives you an interactive control deck with live hotkeys.

---

## Features

- **Automatic Hourly Update Checks:** Runs `rexctl upgrade --check` on startup and repeats every 60 minutes (configurable) with a live countdown bar.
- **Auto-Upgrade on Detection:** Automatically runs `rexctl upgrade --yes` when a new release is detected.
- **Non-Blocking Hotkey Control Deck:** Press `[1]`–`[8]` or `[Q]` at any time during the countdown without needing to press `Enter`:
  - `[1]` Force an immediate `rexctl upgrade --check` / `rexctl upgrade --yes`
  - `[2]` Inspect service health (`rexctl status`)
  - `[3]` Run environment diagnostics (`rexctl doctor`)
  - `[4]` Auto-fix detected issues (`rexctl doctor --fix`)
  - `[5]` List or create instance backups (`rexctl backup list` / `rexctl backup`)
  - `[6]` Manage scheduled auto-upgrades (`rexctl auto-upgrade on/off`, with optional `--notify` webhook/ntfy URL)
  - `[7]` Restart Fluxer containers (`rexctl restart`)
  - `[8]` Stream service logs (`rexctl logs`)
  - `[Q]` Exit utility
- **PowerShell 5.1 & 7+ Safe:** Written in pure 7-bit ASCII source with runtime Unicode rendering so box-drawing characters, spinners, and progress bars display cleanly without encoding errors.

---

## Requirements

- Windows PowerShell **5.1** or PowerShell **7+**
- [`rexctl`](https://fluxer.app) installed and available in your system `PATH`
- Docker (optional, checked during pre-flight telemetry)

---

## Usage

1. Download or copy `CheckFluxer.ps1`.
2. *(Optional)* Edit the configuration block at the top of `CheckFluxer.ps1`:
   ```powershell
   $InstanceDir          = ""     # Optional: path to your Fluxer directory (--dir)
   $CheckIntervalMinutes = 60     # Auto-check interval in minutes
   $RunDoctorOnStart     = $false # Set to $true to run 'rexctl doctor' on startup
   ```
3. Run it in PowerShell:
   ```powershell
   .\CheckFluxer.ps1
   ```
   If script execution is restricted on your system, run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\CheckFluxer.ps1
   ```

---

## Credits

- Built with **Google Gemini 4 Hydrogen** (100% vibecoded).
- Powered by Fluxer's `rexctl` CLI.
