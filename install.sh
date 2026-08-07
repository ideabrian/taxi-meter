#!/bin/bash
# Taxi Meter — project billing timer for Claude Code
#
# Usage: bash install.sh [project-dir] [--rate N]
#    or: curl -sL <raw-url>/install.sh | bash
#    or: bash install.sh --uninstall [project-dir]

set -e

# --- Parse flags ---
RATE=150
PROJECT=""
UNINSTALL=false
while [ $# -gt 0 ]; do
  case "$1" in
    --rate) RATE="$2"; shift 2 ;;
    --rate=*) RATE="${1#*=}"; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    *) [ -z "$PROJECT" ] && PROJECT="$1"; shift ;;
  esac
done
PROJECT="${PROJECT:-.}"
PROJECT=$(cd "$PROJECT" && pwd)
CLAUDE_DIR="$PROJECT/.claude"

# --- Uninstall ---
if [ "$UNINSTALL" = true ]; then
  echo "🚕 Uninstalling taxi meter from $PROJECT"
  rm -f "$CLAUDE_DIR/hooks/taxi-start.sh"
  rm -f "$CLAUDE_DIR/statusline.json"
  rm -f "$CLAUDE_DIR/taxi-config.json"
  rm -rf "$CLAUDE_DIR/sessions/"
  if [ -f "$CLAUDE_DIR/settings.json" ] && command -v jq &>/dev/null; then
    jq 'if .hooks.SessionStart then .hooks.SessionStart = [.hooks.SessionStart[] | select(.hooks | any(.command | contains("taxi-start")) | not)] | if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end else . end' "$CLAUDE_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp" && mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
    echo "  ✓ Removed taxi hook from settings.json"
  fi
  echo "  ✓ Removed taxi-start.sh, statusline.json, taxi-config.json, sessions/"
  echo ""
  echo "🚕 Uninstalled. Global statusline script untouched."
  exit 0
fi

# --- Prereq check ---
MISSING=""
command -v jq &>/dev/null || MISSING="jq"
command -v python3 &>/dev/null || MISSING="$MISSING python3"
if [ -n "$MISSING" ]; then
  echo "  ✗ Missing required tools:$MISSING"
  echo "    Install them first:"
  [ -n "$(echo "$MISSING" | grep jq)" ] && echo "      brew install jq    # or: apt install jq"
  [ -n "$(echo "$MISSING" | grep python3)" ] && echo "      brew install python3"
  exit 1
fi

echo "🚕 Installing taxi meter into $PROJECT"

# --- 1. Session timer hook ---
mkdir -p "$CLAUDE_DIR/hooks"
cat > "$CLAUDE_DIR/hooks/taxi-start.sh" << 'HOOK'
#!/bin/bash
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
  echo '{"result":"timer reset"}'
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
  echo '{"result":"timer started"}'
fi
HOOK
chmod +x "$CLAUDE_DIR/hooks/taxi-start.sh"
echo "  ✓ Hook: .claude/hooks/taxi-start.sh"

# --- 2. Register hook in project settings ---
SETTINGS="$CLAUDE_DIR/settings.json"
TAXI_CMD="bash .claude/hooks/taxi-start.sh"
if [ -f "$SETTINGS" ]; then
  HAS_TAXI=$(jq '[.hooks.SessionStart[]?.hooks[]?.command // empty] | any(contains("taxi-start"))' "$SETTINGS" 2>/dev/null)
  if [ "$HAS_TAXI" = "true" ]; then
    echo "  ✓ Hook already registered in settings.json"
  elif jq -e '.hooks.SessionStart' "$SETTINGS" &>/dev/null; then
    jq --arg cmd "$TAXI_CMD" '.hooks.SessionStart += [{"hooks":[{"type":"command","command":$cmd}]}]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  ✓ Appended taxi hook to existing SessionStart hooks"
  else
    jq --arg cmd "$TAXI_CMD" '.hooks.SessionStart = [{"hooks":[{"type":"command","command":$cmd}]}]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  ✓ Added SessionStart hook to settings.json"
  fi
else
  cat > "$SETTINGS" << SETTINGS_JSON
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$TAXI_CMD"
          }
        ]
      }
    ]
  }
}
SETTINGS_JSON
  echo "  ✓ Created settings.json with SessionStart hook"
fi

# --- 3. Project statusline config ---
SL_CONFIG="$CLAUDE_DIR/statusline.json"
if [ ! -f "$SL_CONFIG" ]; then
  echo '{"modules":["taxi"]}' > "$SL_CONFIG"
  echo "  ✓ Created .claude/statusline.json"
elif [ "$(jq '.modules // [] | index("taxi")' "$SL_CONFIG" 2>/dev/null)" = "null" ]; then
  jq '.modules = (.modules // []) + ["taxi"]' "$SL_CONFIG" > "$SL_CONFIG.tmp" && mv "$SL_CONFIG.tmp" "$SL_CONFIG"
  echo "  ✓ Added taxi to existing statusline.json"
else
  echo "  ✓ statusline.json already has taxi"
fi

# --- 4. Rate config ---
RATE_PER_MIN=$(python3 -c "print(round($RATE / 60, 4))" 2>/dev/null)
echo "{\"rate\": $RATE, \"rate_per_min\": $RATE_PER_MIN}" > "$CLAUDE_DIR/taxi-config.json"
echo "  ✓ Rate: \$$RATE/hr"

# --- 5. Gitignore ---
GITIGNORE="$CLAUDE_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
  grep -q "sessions/" "$GITIGNORE" 2>/dev/null || echo "sessions/" >> "$GITIGNORE"
else
  echo "sessions/" > "$GITIGNORE"
fi
echo "  ✓ Gitignore: .claude/sessions/"

# --- 6. Global statusline script ---
GLOBAL_SCRIPTS="$HOME/.claude/scripts"
STATUSLINE_SCRIPT="$GLOBAL_SCRIPTS/statusline.sh"
SCRIPT_SOURCE="$(cd "$(dirname "$0")" && pwd)/statusline.sh"

if [ -f "$STATUSLINE_SCRIPT" ]; then
  if grep -q "mod_taxi" "$STATUSLINE_SCRIPT"; then
    echo "  ✓ Global statusline already has mod_taxi()"
  else
    # Append mod_taxi before the "# --- Assemble ---" line, or at end
    MOD_TAXI='
mod_taxi() {
    local sid="${CLAUDE_CODE_SESSION_ID:-}"
    [ -z "$sid" ] && return
    local timer="${CWD}/.claude/sessions/${sid}.json"
    [ ! -f "$timer" ] && return
    local config="${CWD}/.claude/taxi-config.json"
    local rate_per_min=2.50
    local rate_per_hr=150
    if [ -f "$config" ]; then
        rate_per_min=$(jq -r ".rate_per_min // 2.50" "$config" 2>/dev/null)
        rate_per_hr=$(jq -r ".rate // 150" "$config" 2>/dev/null)
    fi
    local start=$(jq -r ".start" "$timer" 2>/dev/null)
    [ -z "$start" ] || [ "$start" = "null" ] && return
    local now=$(date +%s)
    local elapsed=$((now - start))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local fare=$(python3 -c "print(f'\''{ '"$rate_per_min"' * '"$mins"' + '"$rate_per_min"' * '"$secs"' / 60:.2f}'\'')" 2>/dev/null || echo "0.00")
    echo "🚕 ${mins}m${secs}s \$${fare} (\$${rate_per_hr}/hr)"
}'
    if grep -q "# --- Assemble ---" "$STATUSLINE_SCRIPT"; then
      # Insert before the assemble section
      python3 -c "
import re
with open('$STATUSLINE_SCRIPT') as f:
    content = f.read()
content = content.replace('# --- Assemble ---', '''$MOD_TAXI

# --- Assemble ---''')
with open('$STATUSLINE_SCRIPT', 'w') as f:
    f.write(content)
"
    else
      echo "$MOD_TAXI" >> "$STATUSLINE_SCRIPT"
    fi
    echo "  ✓ Added mod_taxi() to global statusline script"
  fi
else
  mkdir -p "$GLOBAL_SCRIPTS"
  if [ -f "$SCRIPT_SOURCE" ]; then
    cp "$SCRIPT_SOURCE" "$STATUSLINE_SCRIPT"
    chmod +x "$STATUSLINE_SCRIPT"
    echo "  ✓ Installed global statusline script from repo"
  else
    # Minimal statusline with taxi support
    cat > "$STATUSLINE_SCRIPT" << 'SLSCRIPT'
#!/bin/bash
input=$(cat)
if command -v jq &> /dev/null; then
    CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
else
    CWD=$(pwd)
fi
[ -z "$CWD" ] && CWD=$(pwd)

GLOBAL_CONFIG="$HOME/.claude/statusline.json"
PROJECT_CONFIG="${CWD}/.claude/statusline.json"

if [ -f "$GLOBAL_CONFIG" ] && command -v jq &>/dev/null; then
    MODULES=$(jq -r '.modules // ["cwd"] | .[]' "$GLOBAL_CONFIG" 2>/dev/null)
    SEP=$(jq -r '.separator // " | "' "$GLOBAL_CONFIG" 2>/dev/null)
else
    MODULES="cwd"
    SEP=" | "
fi

if [ -f "$PROJECT_CONFIG" ] && command -v jq &>/dev/null; then
    PROJECT_MODULES=$(jq -r '.modules // [] | .[]' "$PROJECT_CONFIG" 2>/dev/null)
    [ -n "$PROJECT_MODULES" ] && MODULES="$MODULES $PROJECT_MODULES"
fi

mod_cwd() {
    local display="${CWD/$HOME/~}"
    if [ ${#display} -gt 50 ]; then
        display="${display:0:20}...${display: -27}"
    fi
    echo "$display"
}

mod_taxi() {
    local sid="${CLAUDE_CODE_SESSION_ID:-}"
    [ -z "$sid" ] && return
    local timer="${CWD}/.claude/sessions/${sid}.json"
    [ ! -f "$timer" ] && return
    local config="${CWD}/.claude/taxi-config.json"
    local rate_per_min=2.50
    local rate_per_hr=150
    if [ -f "$config" ]; then
        rate_per_min=$(jq -r '.rate_per_min // 2.50' "$config" 2>/dev/null)
        rate_per_hr=$(jq -r '.rate // 150' "$config" 2>/dev/null)
    fi
    local start=$(jq -r '.start' "$timer" 2>/dev/null)
    [ -z "$start" ] || [ "$start" = "null" ] && return
    local now=$(date +%s)
    local elapsed=$((now - start))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local fare=$(python3 -c "print(f'{$rate_per_min * $mins + $rate_per_min * $secs / 60:.2f}')" 2>/dev/null || echo "0.00")
    echo "🚕 ${mins}m${secs}s \$${fare} (\$${rate_per_hr}/hr)"
}

OUTPUT=""
for mod in $MODULES; do
    val=$(mod_$mod 2>/dev/null)
    if [ -n "$val" ]; then
        [ -n "$OUTPUT" ] && OUTPUT="${OUTPUT}${SEP}${val}" || OUTPUT="$val"
    fi
done
echo "$OUTPUT"
SLSCRIPT
    chmod +x "$STATUSLINE_SCRIPT"
    echo "  ✓ Created global statusline script"
  fi
fi

# --- 7. Global statusLine setting ---
GLOBAL_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$GLOBAL_SETTINGS" ]; then
  HAS_SL=$(jq -e '.statusLine' "$GLOBAL_SETTINGS" 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "  ✓ Global statusLine setting already configured"
  else
    jq '. + {"statusLine":{"type":"command","command":"~/.claude/scripts/statusline.sh"}}' "$GLOBAL_SETTINGS" > "$GLOBAL_SETTINGS.tmp" && mv "$GLOBAL_SETTINGS.tmp" "$GLOBAL_SETTINGS"
    echo "  ✓ Added statusLine to global settings.json"
  fi
else
  mkdir -p "$HOME/.claude"
  cat > "$GLOBAL_SETTINGS" << 'GSETTINGS'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/scripts/statusline.sh"
  }
}
GSETTINGS
  echo "  ✓ Created global settings.json with statusLine"
fi

echo ""
echo "🚕 Installed! Restart Claude Code to activate."
echo "   Rate: \$$RATE/hr — change with: bash install.sh --rate 200"
echo "   Disable: remove 'taxi' from .claude/statusline.json"
echo "   Uninstall: bash install.sh --uninstall"
