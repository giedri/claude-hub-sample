#!/bin/bash
# deploy-macos.sh — Jamf Pro / macOS MDM deployment for claude-hub
# Installs the claude-hub plugin, deploys org CLAUDE.md to the managed policy
# path, and configures team membership.
#
# Claude Code reads the managed policy CLAUDE.md from:
#   /Library/Application Support/ClaudeCode/CLAUDE.md
# This file cannot be excluded by individual users and is always loaded.
#
# Jamf script parameters:
#   $4 — Team name (e.g., "platform")
#   $5 — Central repo URL (e.g., "https://github.com/myorg/claude-hub.git")
#
# Environment variable overrides:
#   CLAUDE_HUB_TEAM     — Team name (fallback if $4 is empty)
#   CLAUDE_HUB_REPO_URL — Repo URL  (fallback if $5 is empty)

set -euo pipefail

LOG_TAG="claude-hub-deploy"

log() {
    logger -t "$LOG_TAG" "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    logger -t "$LOG_TAG" "ERROR: $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

die() {
    log_error "$1"
    exit 1
}

# --- Resolve parameters ---
TEAM="${4:-${CLAUDE_HUB_TEAM:-}}"
REPO_URL="${5:-${CLAUDE_HUB_REPO_URL:-}}"

[ -n "$TEAM" ]     || die "Team name is required (Jamf \$4 or CLAUDE_HUB_TEAM)"
[ -n "$REPO_URL" ] || die "Repo URL is required (Jamf \$5 or CLAUDE_HUB_REPO_URL)"

# --- Detect logged-in user (not root) ---
CONSOLE_USER=$(/usr/bin/stat -f "%Su" /dev/console 2>/dev/null || echo "")
if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ]; then
    CONSOLE_USER=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && !/loginwindow/ { print $3 }')
fi
[ -n "$CONSOLE_USER" ] || die "Could not detect logged-in user"

USER_HOME=$(dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory | awk '{ print $2 }')
[ -d "$USER_HOME" ] || die "Home directory $USER_HOME does not exist"

log "Deploying claude-hub for user=$CONSOLE_USER home=$USER_HOME team=$TEAM"

# --- Directory structure ---
CLAUDE_DIR="$USER_HOME/.claude"
HUB_DIR="$CLAUDE_DIR/claude-hub"
PLUGIN_DEST="$CLAUDE_DIR/plugins/local/claude-hub"
INSTALLED_JSON="$CLAUDE_DIR/plugins/installed_plugins.json"

mkdir -p "$HUB_DIR"
mkdir -p "$PLUGIN_DEST"
mkdir -p "$(dirname "$INSTALLED_JSON")"

# --- Write config files ---
echo "$TEAM" > "$HUB_DIR/team"
echo "$REPO_URL" > "$HUB_DIR/repo_url"
log "Wrote team=$TEAM and repo_url to $HUB_DIR"

# --- Clone or update central repo ---
REPO_CLONE_DIR="$HUB_DIR/repo"
if [ -d "$REPO_CLONE_DIR/.git" ]; then
    log "Repo already cloned, pulling latest..."
    git -C "$REPO_CLONE_DIR" fetch --depth=1 origin 2>&1 | while read -r line; do log "git: $line"; done
    git -C "$REPO_CLONE_DIR" reset --hard origin/HEAD 2>&1 | while read -r line; do log "git: $line"; done
else
    log "Cloning repo $REPO_URL..."
    rm -rf "$REPO_CLONE_DIR"
    git clone --depth=1 "$REPO_URL" "$REPO_CLONE_DIR" 2>&1 | while read -r line; do log "git: $line"; done
fi

# --- Deploy org files to managed policy path ---
MANAGED_POLICY_DIR="/Library/Application Support/ClaudeCode"
mkdir -p "$MANAGED_POLICY_DIR"

ORG_CLAUDE_MD="$REPO_CLONE_DIR/org/CLAUDE.md"
if [ -f "$ORG_CLAUDE_MD" ]; then
    cp "$ORG_CLAUDE_MD" "$MANAGED_POLICY_DIR/CLAUDE.md"
    chmod 644 "$MANAGED_POLICY_DIR/CLAUDE.md"
    log "Deployed org CLAUDE.md to $MANAGED_POLICY_DIR/CLAUDE.md"
else
    log "Warning: org/CLAUDE.md not found in repo, skipping managed policy CLAUDE.md"
fi

ORG_SETTINGS="$REPO_CLONE_DIR/org/settings.json"
if [ -f "$ORG_SETTINGS" ]; then
    cp "$ORG_SETTINGS" "$MANAGED_POLICY_DIR/managed-settings.json"
    chmod 644 "$MANAGED_POLICY_DIR/managed-settings.json"
    log "Deployed org settings.json to $MANAGED_POLICY_DIR/managed-settings.json (MCP servers, marketplaces, plugins)"
else
    log "Warning: org/settings.json not found in repo, skipping managed policy settings"
fi

# --- Copy plugin files ---
PLUGIN_SRC="$REPO_CLONE_DIR/plugin"
if [ -d "$PLUGIN_SRC" ]; then
    log "Copying plugin files from $PLUGIN_SRC to $PLUGIN_DEST"
    rsync -a --delete "$PLUGIN_SRC/" "$PLUGIN_DEST/"
else
    die "Plugin source directory not found at $PLUGIN_SRC"
fi

# --- Patch installed_plugins.json ---
PLUGIN_ENTRY="$PLUGIN_DEST/.claude-plugin"
if [ -f "$INSTALLED_JSON" ]; then
    # Check if already registered
    if python3 -c "
import json, sys
with open('$INSTALLED_JSON') as f:
    data = json.load(f)
plugins = data if isinstance(data, list) else data.get('plugins', [])
for p in plugins:
    if p.get('path') == '$PLUGIN_ENTRY' or p.get('name') == 'claude-hub':
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        log "Plugin already registered in installed_plugins.json"
    else
        log "Adding plugin entry to existing installed_plugins.json"
        python3 -c "
import json
path = '$INSTALLED_JSON'
with open(path) as f:
    data = json.load(f)
plugins = data if isinstance(data, list) else data.get('plugins', [])
plugins.append({'name': 'claude-hub', 'path': '$PLUGIN_ENTRY'})
if isinstance(data, list):
    data = plugins
else:
    data['plugins'] = plugins
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
"
    fi
else
    log "Creating installed_plugins.json"
    python3 -c "
import json
data = [{'name': 'claude-hub', 'path': '$PLUGIN_ENTRY'}]
with open('$INSTALLED_JSON', 'w') as f:
    json.dump(data, f, indent=2)
"
fi

# --- Fix ownership ---
chown -R "$CONSOLE_USER" "$CLAUDE_DIR"
log "Fixed ownership of $CLAUDE_DIR"

# --- Run initial sync ---
SYNC_SCRIPT="$PLUGIN_DEST/scripts/sync.sh"
if [ -x "$SYNC_SCRIPT" ]; then
    log "Running initial sync..."
    CLAUDE_PLUGIN_ROOT="$PLUGIN_DEST" sudo -u "$CONSOLE_USER" bash "$SYNC_SCRIPT" 2>&1 | while read -r line; do log "sync: $line"; done
    log "Initial sync completed"
elif [ -f "$SYNC_SCRIPT" ]; then
    chmod +x "$SYNC_SCRIPT"
    log "Running initial sync..."
    CLAUDE_PLUGIN_ROOT="$PLUGIN_DEST" sudo -u "$CONSOLE_USER" bash "$SYNC_SCRIPT" 2>&1 | while read -r line; do log "sync: $line"; done
    log "Initial sync completed"
else
    log "Warning: sync script not found at $SYNC_SCRIPT, skipping initial sync"
fi

log "claude-hub deployment completed successfully"
exit 0
