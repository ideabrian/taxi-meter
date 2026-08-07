# Taxi Meter

A project billing timer for Claude Code. Tracks elapsed session time and running fare in the statusline.

Every time you start a Claude Code session, a timer starts:

`~/my-project | 🚕 12m30s $31.25 ($150/hr)`

Timer resets when you resume a session. Each project has its own timer.

## Install

`cd` into your project, then run:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ideabrian/taxi-meter/main/install.sh)
```

Custom rate:

```bash
bash <(curl -sL https://raw.githubusercontent.com/ideabrian/taxi-meter/main/install.sh) --rate 200
```

That's it. Restart Claude Code. The installer handles everything — project hooks, global statusline script, global settings. If you already have a statusline script, it adds `mod_taxi()` without touching the rest.

## What gets installed

**In your project:**
```
.claude/
  hooks/taxi-start.sh     — starts/resets timer on session start
  statusline.json         — opts this project into the taxi module
  taxi-config.json        — rate config (default $150/hr)
  sessions/               — timer files (gitignored)
```

**Globally (if not already present):**
```
~/.claude/scripts/statusline.sh   — modular statusline with taxi module
~/.claude/settings.json           — statusLine command entry
```

## Requirements

- Claude Code with statusline support
- `jq` and `python3` on your PATH

The installer checks for both upfront and exits with install instructions if either is missing.

## Configuration

**Change the rate:** Re-run with `--rate N` or edit `.claude/taxi-config.json`:
```json
{"rate": 200, "rate_per_min": 3.3333}
```

**Disable for a project:** Remove `"taxi"` from `.claude/statusline.json` or delete the file.

## Uninstall

```bash
bash <(curl -sL https://raw.githubusercontent.com/ideabrian/taxi-meter/main/install.sh) --uninstall
```

Removes all project-level taxi files and the hook from settings.json. Global statusline script is left untouched.

## How it works

1. `SessionStart` hook writes `.claude/sessions/<session-id>.json` with a Unix timestamp
2. Statusline script reads the timestamp and rate from `.claude/taxi-config.json`
3. Calculates elapsed time and fare, renders in the statusline
4. Project-level `.claude/statusline.json` controls whether the taxi module renders

Per-session, not cumulative. Each new Claude Code session starts fresh.
