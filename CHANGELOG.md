# Changelog

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
