#!/bin/bash
# Modular Claude Code Statusline
#
# Global config: ~/.claude/statusline.json
#   { "modules": ["cwd", "project", "task"], "separator": " | " }
#
# Project config: <project>/.claude/statusline.json
#   { "modules": ["taxi"] }
#   Project modules are appended after global modules.
#
# Available modules:
#   cwd      — current working directory (shortened)
#   taxi     — session elapsed time + running fare
#   git      — current git branch
#   project  — project name from /statusline skill
#   task     — current task from /statusline skill
#   model    — active model display name
#
# No config = default global: ["cwd"]
# Projects opt into taxi via their own .claude/statusline.json

input=$(cat)

if command -v jq &> /dev/null; then
    CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
    MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name // empty')
else
    CWD=$(pwd)
    MODEL_DISPLAY=""
fi
[ -z "$CWD" ] && CWD=$(pwd)

# --- Load config (global + project) ---
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
    PROJECT_SEP=$(jq -r '.separator // empty' "$PROJECT_CONFIG" 2>/dev/null)
    [ -n "$PROJECT_SEP" ] && SEP="$PROJECT_SEP"
fi

# --- Modules ---

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
    command -v jq &>/dev/null || return
    local start=$(jq -r '.start' "$timer" 2>/dev/null)
    [ -z "$start" ] || [ "$start" = "null" ] && return
    local config="${CWD}/.claude/taxi-config.json"
    local rate=150
    local rpm=2.5
    if [ -f "$config" ]; then
        rate=$(jq -r '.rate // 150' "$config" 2>/dev/null)
        rpm=$(jq -r '.rate_per_min // 2.5' "$config" 2>/dev/null)
    fi
    local now=$(date +%s)
    local elapsed=$((now - start))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local fare=$(python3 -c "print(f'{$rpm * $mins + $rpm * $secs / 60:.2f}')" 2>/dev/null || echo "0.00")
    echo "🚕 ${mins}m${secs}s \$${fare} (\$${rate}/hr)"
}

mod_git() {
    local branch=$(git -C "$CWD" branch --show-current 2>/dev/null)
    [ -n "$branch" ] && echo "⎇ $branch"
}

mod_project() {
    local ctx="$HOME/.claude/statusline-context.json"
    [ -f "$ctx" ] && command -v jq &>/dev/null && jq -r '.project // empty' "$ctx" 2>/dev/null
}

mod_task() {
    local ctx="$HOME/.claude/statusline-context.json"
    [ -f "$ctx" ] && command -v jq &>/dev/null && jq -r '.task // empty' "$ctx" 2>/dev/null
}

mod_model() {
    [ -n "$MODEL_DISPLAY" ] && echo "$MODEL_DISPLAY"
}

# --- Assemble ---
OUTPUT=""
for mod in $MODULES; do
    val=$(mod_$mod 2>/dev/null)
    if [ -n "$val" ]; then
        [ -n "$OUTPUT" ] && OUTPUT="${OUTPUT}${SEP}${val}" || OUTPUT="$val"
    fi
done

echo "$OUTPUT"
