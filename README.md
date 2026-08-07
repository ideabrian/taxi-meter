# 🚕 Taxi Meter

A project billing timer for Claude Code. Tracks elapsed session time and running fare in the statusline.

## What it does

Every time you start a Claude Code session, a timer starts. The statusline shows: `~/my-project | 🚕 12m30s $31.25 ($150/hr)`

Timer resets when you resume a session. Each project has its own timer — other projects are unaffected.

## Install

`cd` into your project, then run:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ideabrian/taxi-meter/main/install.sh)
```

Or clone and run:

```bash
git clone https://github.com/ideabrian/taxi-meter.git /tmp/taxi-meter
bash /tmp/taxi-meter/install.sh ~/path/to/your-project
```

## What gets added

```
your-project/.claude/
  hooks/taxi-start.sh     — starts/resets timer on session start
  statusline.json         — opts this project into the taxi module
  sessions/               — timer files (gitignored)
```

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

## Configuration

**Change the rate:** Edit `mod_taxi()` in your statusline script. Default is $150/hr ($2.50/min).

**Disable for a project:** Remove `"taxi"` from `.claude/statusline.json` or delete the file.

**Enable for a project:** Create `.claude/statusline.json`:
```json
{"modules": ["taxi"]}
```

## How it works

1. `SessionStart` hook creates `.claude/sessions/<session-id>.json` with a Unix timestamp
2. Statusline script reads the timestamp, calculates elapsed time and fare
3. Project-level `.claude/statusline.json` controls whether the taxi module renders

The timer is per-session, not cumulative. Each new Claude Code session starts fresh.

## Uninstall

```bash
rm .claude/hooks/taxi-start.sh
rm .claude/statusline.json
rm -rf .claude/sessions/
# Remove the SessionStart hook entry from .claude/settings.json
```
