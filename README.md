# Taxi Meter

A project billing timer for Claude Code. Tracks elapsed session time and running fare in the statusline.

Every time you start a Claude Code session, a timer starts:

`~/my-project | 🚕 12m30s $31.25 ($150/hr)`

Timer resets when you resume a session. Each project has its own timer.

## Install

**[Configure your install](https://ideabrian.github.io/taxi-meter/configure.html)** — pick your rate, see what gets installed, view the source before you run it.

Or just run the default ($150/hr):

```bash
bash <(curl -sL https://raw.githubusercontent.com/ideabrian/taxi-meter/main/install.sh)
```

Custom rate:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ideabrian/taxi-meter/main/install.sh) --rate 200
```

## What gets installed

**Downloaded from repo:**
- `.claude/hooks/taxi-start.sh` — starts/resets timer on session start

**Created locally:**
- `.claude/taxi-config.json` — your rate config
- `.claude/statusline.json` — enables the taxi module
- `.claude/sessions/` — timer files (gitignored)

**Modified (if they exist):**
- `.claude/settings.json` — appends SessionStart hook
- `.claude/statusline.json` — adds "taxi" to modules
- `.claude/.gitignore` — adds `sessions/` line

Originals are backed up to `.claude/taxi-backup/` before any changes.

## Uninstall

Restores your original files from backup:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ideabrian/taxi-meter/main/uninstall.sh)
```

## Configuration

**Change the rate:** Edit `.claude/taxi-config.json` or re-run install with `--rate N`.

**Disable for a project:** Remove `"taxi"` from `.claude/statusline.json` or delete the file.

## Requirements

- Claude Code with statusline support
- `jq` and `python3` on your PATH
- A modular statusline script (see below)

## Statusline setup

The taxi meter displays via a `mod_taxi()` function in your statusline script (`~/.claude/scripts/statusline.sh`). If you don't have a modular statusline yet, copy `statusline.sh` from this repo to `~/.claude/scripts/` and set it in your global settings:

```json
{
  "statusLine": {
    "command": "~/.claude/scripts/statusline.sh"
  }
}
```

## How it works

1. `SessionStart` hook creates `.claude/sessions/<session-id>.json` with a Unix timestamp
2. Statusline script reads the timestamp and rate from `.claude/taxi-config.json`
3. Calculates elapsed time and fare, renders in the statusline
4. Project-level `.claude/statusline.json` controls whether the taxi module renders

The timer is per-session, not cumulative. Each new Claude Code session starts fresh.
