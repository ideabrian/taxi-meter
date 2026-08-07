#!/bin/bash
# Taxi Meter — clean uninstall
# Removes only what install.sh added. Does not delete .claude/ itself.
#
# Usage: bash uninstall.sh [project-dir]

set -e

PROJECT="${1:-.}"
PROJECT=$(cd "$PROJECT" && pwd)
CLAUDE_DIR="$PROJECT/.claude"

echo "🚕 Uninstalling taxi meter from $PROJECT"
echo ""

# --- 1. Downloaded files ---
echo "  Removing downloaded files:"
if [ -f "$CLAUDE_DIR/hooks/taxi-start.sh" ]; then
  rm "$CLAUDE_DIR/hooks/taxi-start.sh"
  echo "    ✓ .claude/hooks/taxi-start.sh"
else
  echo "    · .claude/hooks/taxi-start.sh (not found)"
fi

# --- 2. Created files ---
echo "  Removing created files:"
if [ -f "$CLAUDE_DIR/taxi-config.json" ]; then
  rm "$CLAUDE_DIR/taxi-config.json"
  echo "    ✓ .claude/taxi-config.json"
else
  echo "    · .claude/taxi-config.json (not found)"
fi

if [ -f "$CLAUDE_DIR/statusline.json" ]; then
  rm "$CLAUDE_DIR/statusline.json"
  echo "    ✓ .claude/statusline.json"
else
  echo "    · .claude/statusline.json (not found)"
fi

if [ -d "$CLAUDE_DIR/sessions" ]; then
  rm -rf "$CLAUDE_DIR/sessions"
  echo "    ✓ .claude/sessions/"
else
  echo "    · .claude/sessions/ (not found)"
fi

# --- 3. Restore or surgically clean modified files ---
BACKUP_DIR="$CLAUDE_DIR/taxi-backup"

echo "  Restoring modified files:"

SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$BACKUP_DIR/settings.json" ]; then
  cp "$BACKUP_DIR/settings.json" "$SETTINGS"
  echo "    ✓ .claude/settings.json (restored from backup)"
elif [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  HAS_TAXI=$(jq '.hooks.SessionStart[]?.hooks[]? | select(.command | contains("taxi-start"))' "$SETTINGS" 2>/dev/null)
  if [ -n "$HAS_TAXI" ]; then
    jq '
      .hooks.SessionStart |= [
        .[] | .hooks |= [.[] | select(.command | contains("taxi-start") | not)]
      ] |
      .hooks.SessionStart |= [.[] | select(.hooks | length > 0)] |
      if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
      if .hooks == {} then del(.hooks) else . end
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "    ✓ .claude/settings.json (surgically removed taxi hook)"
  else
    echo "    · .claude/settings.json (no taxi hook found)"
  fi
else
  echo "    · .claude/settings.json (no backup, not found, or jq missing)"
fi

GITIGNORE="$CLAUDE_DIR/.gitignore"
if [ -f "$BACKUP_DIR/.gitignore" ]; then
  cp "$BACKUP_DIR/.gitignore" "$GITIGNORE"
  echo "    ✓ .claude/.gitignore (restored from backup)"
elif [ -f "$GITIGNORE" ]; then
  grep -v -E "sessions/|taxi-backup/" "$GITIGNORE" | sed '/^$/d' > "$GITIGNORE.tmp"
  if [ -s "$GITIGNORE.tmp" ]; then
    mv "$GITIGNORE.tmp" "$GITIGNORE"
    echo "    ✓ .claude/.gitignore (removed taxi lines)"
  else
    rm -f "$GITIGNORE.tmp" "$GITIGNORE"
    echo "    ✓ .claude/.gitignore (was taxi-only, removed)"
  fi
else
  echo "    · .claude/.gitignore (not found)"
fi

SL_CONFIG="$CLAUDE_DIR/statusline.json"
if [ -f "$BACKUP_DIR/statusline.json" ]; then
  cp "$BACKUP_DIR/statusline.json" "$SL_CONFIG"
  echo "    ✓ .claude/statusline.json (restored from backup)"
fi

# --- 4. Clean up backup dir ---
if [ -d "$BACKUP_DIR" ]; then
  rm -rf "$BACKUP_DIR"
  echo "    ✓ .claude/taxi-backup/ (removed)"
fi

# --- 5. Clean up empty dirs ---
rmdir "$CLAUDE_DIR/hooks" 2>/dev/null && echo "    ✓ .claude/hooks/ (empty, removed)" || true

echo ""
echo "🚕 Taxi meter removed. No files left behind."
echo "   Your .claude/ directory and other settings are untouched."
