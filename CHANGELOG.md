# Changelog

## 2026-08-07 (v2)

### Zero-friction global setup
- Install auto-creates `~/.claude/scripts/statusline.sh` if missing
- Auto-appends `mod_taxi()` to existing statusline scripts
- Auto-adds `statusLine` entry to `~/.claude/settings.json`
- No manual steps — one command, everything works

### Prereq check
- Validates `jq` and `python3` upfront before touching any files
- Exits with platform-specific install instructions if missing

### Auto-start current session
- If `CLAUDE_CODE_SESSION_ID` is set, triggers the hook immediately
- Meter appears without restarting Claude Code

### --uninstall flag
- `install.sh --uninstall` delegates to `uninstall.sh` if available
- Falls back to inline removal for curl-only users

### Docs
- `BILLING-FEATURES.md` — maps what taxi-meter does vs try-business billing engine
- `demo.html` — animated Claude session showing eye candy vs business value
- `install-flow.html` — interactive process map of every install step and error path

## 2026-08-07

### Web configurator
- `configure.html` — pick rate, get install command, copy-paste
- Live meter preview updates as you drag the slider
- Preset buttons ($50–$300) + custom input
- File manifest shows what gets downloaded vs created vs modified
- Uninstall command with copy button

### Configurable rate
- `install.sh` accepts `--rate N` flag (default $150/hr)
- Writes `.claude/taxi-config.json` with rate
- `statusline.sh` reads rate from config, falls back to $150 if missing
- Default install command omits `--rate` flag for cleanliness

### Backup & restore
- Install snapshots existing `settings.json`, `statusline.json`, `.gitignore` to `.claude/taxi-backup/` before modifying
- Install merges into existing files: appends hook to SessionStart array, adds "taxi" to existing statusline modules
- `uninstall.sh` restores originals from backup, falls back to surgical removal if no backup
- Backup dir is gitignored and cleaned up on uninstall

### Uninstall script
- `uninstall.sh` — clean removal of everything install.sh added
- Surgically removes taxi hook from settings.json (preserves other hooks/permissions)
- Strips taxi lines from .gitignore (preserves other entries)
- Removes empty `hooks/` dir only if empty
- Reports every action taken
