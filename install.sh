#!/bin/bash
# Taxi Meter — project billing timer for Claude Code
# Installs into the current project's .claude/ directory
#
# Usage: curl -sL <raw-url>/install.sh | bash
#    or: bash install.sh [project-dir]

set -e

PROJECT="${1:-.}"
PROJECT=$(cd "$PROJECT" && pwd)
CLAUDE_DIR="$PROJECT/.claude"

echo "🚕 Installing taxi meter into $PROJECT"

# --- 1. Session timer hook ---
mkdir -p "$CLAUDE_DIR/hooks"
cat > "$CLAUDE_DIR/hooks/taxi-start.sh" << 'HOOK'
#!/bin/bash
# Taxi meter — create/reset session timer on start
SID="${CLAUDE_CODE_SESSION_ID:-unknown}"
DIR="$(pwd)/.claude/sessions"
TIMER="$DIR/$SID.json"

mkdir -p "$DIR"

if [ -f "$TIMER" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, time
with open('$TIMER') as f:
    timer = json.load(f)
timer['start'] = int(time.time())
with open('$TIMER', 'w') as f:
    json.dump(timer, f, indent=2)
"
  echo '{"result":"⏱ Taxi meter reset (resumed)"}'
else
  python3 -c "
import json, time
timer = {
    'start': int(time.time()),
    'session_id': '$SID',
    'completions': []
}
with open('$TIMER', 'w') as f:
    json.dump(timer, f, indent=2)
"
  echo '{"result":"⏱ Taxi meter started"}'
fi
HOOK
chmod +x "$CLAUDE_DIR/hooks/taxi-start.sh"

# --- 2. Register hook in settings ---
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  # Check if SessionStart hooks already exist
  HAS_HOOK=$(jq '.hooks.SessionStart // empty' "$SETTINGS" 2>/dev/null)
  if [ -z "$HAS_HOOK" ]; then
    jq '.hooks.SessionStart = [{"hooks":[{"type":"command","command":"bash .claude/hooks/taxi-start.sh"}]}]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  ✓ Added SessionStart hook to settings.json"
  else
    echo "  ⚠ SessionStart hook already exists — add taxi-start.sh manually if needed"
  fi
else
  # No settings.json yet — create minimal one
  mkdir -p "$CLAUDE_DIR"
  cat > "$SETTINGS" << 'SETTINGS_JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/taxi-start.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS_JSON
  echo "  ✓ Created settings.json with SessionStart hook"
fi

# --- 3. Statusline config ---
SL_CONFIG="$CLAUDE_DIR/statusline.json"
if [ ! -f "$SL_CONFIG" ]; then
  echo '{"modules":["taxi"]}' > "$SL_CONFIG"
  echo "  ✓ Created statusline.json with taxi module"
else
  echo "  ⚠ statusline.json already exists — ensure 'taxi' is in modules array"
fi

# --- 4. Gitignore sessions ---
GITIGNORE="$CLAUDE_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
  grep -q "sessions/" "$GITIGNORE" 2>/dev/null || echo "sessions/" >> "$GITIGNORE"
else
  echo "sessions/" > "$GITIGNORE"
fi
echo "  ✓ Added sessions/ to .claude/.gitignore"

# --- 5. Statusline module check ---
STATUSLINE_SCRIPT="$HOME/.claude/scripts/statusline.sh"
if [ -f "$STATUSLINE_SCRIPT" ]; then
  if grep -q "mod_taxi" "$STATUSLINE_SCRIPT"; then
    echo "  ✓ Statusline script already has taxi module"
  else
    echo ""
    echo "  ⚠ Your statusline script needs the taxi module."
    echo "    Add this function to $STATUSLINE_SCRIPT:"
    echo ""
    echo '    mod_taxi() {'
    echo '        local sid="${CLAUDE_CODE_SESSION_ID:-}"'
    echo '        [ -z "$sid" ] && return'
    echo '        local timer="${CWD}/.claude/sessions/${sid}.json"'
    echo '        [ ! -f "$timer" ] && return'
    echo '        command -v jq &>/dev/null || return'
    echo '        local start=$(jq -r ".start" "$timer" 2>/dev/null)'
    echo '        [ -z "$start" ] || [ "$start" = "null" ] && return'
    echo '        local now=$(date +%s)'
    echo '        local elapsed=$((now - start))'
    echo '        local mins=$((elapsed / 60))'
    echo '        local secs=$((elapsed % 60))'
    echo '        local fare=$(python3 -c "print(f\x27{2.50 * $mins + 2.50 * $secs / 60:.2f}\x27)" 2>/dev/null || echo "0.00")'
    echo '        echo "🚕 ${mins}m${secs}s \$${fare} (\$150/hr)"'
    echo '    }'
  fi
else
  echo ""
  echo "  ⚠ No statusline script found at $STATUSLINE_SCRIPT"
  echo "    The taxi meter needs a modular statusline to display."
  echo "    See README.md for setup instructions."
fi

echo ""
echo "🚕 Taxi meter installed! Restart Claude Code to activate."
echo "   Rate: \$150/hr (\$2.50/min)"
echo "   Timer resets each session. Disable: remove 'taxi' from .claude/statusline.json"
