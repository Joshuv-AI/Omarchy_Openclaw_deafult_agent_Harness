#!/usr/bin/env bash
# openclaw-integration installer for Omarchy.
#
# What it does:
#   1. Detects OpenClaw; if missing, runs the official OpenClaw installer
#   2. Runs `openclaw onboard` for API key setup (handled by OpenClaw itself)
#   3. Copies the collector script + lobster SVG assets
#   4. Backs up + patches Panel.qml + Main.qml (OpenClaw display block)
#   5. Adds OpenClaw entry to the super space menu (agents submenu)
#   6. Asks if you want OpenClaw as your default agent
#   7. Reloads Quickshell
#
# Idempotent — safe to re-run. Re-run after `omarchy-update`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === Paths ===
COLLECTOR_SRC="$SCRIPT_DIR/bin/omarchy-agent-usage-openclaw"
COLLECTOR_DST="/usr/bin/omarchy-agent-usage-openclaw"
ASSET_SRC_DIR="$SCRIPT_DIR/assets"
ASSET_DST_DIR="/usr/share/omarchy/shell/plugins/agents/assets"
PANEL_DST="/usr/share/omarchy/shell/plugins/agents/Panel.qml"
MAIN_DST="/usr/share/omarchy/shell/plugins/agents/Main.qml"
PANEL_BACKUP="${PANEL_DST}.openclaw-backup"
MAIN_BACKUP="${MAIN_DST}.openclaw-backup"
PANEL_TARGET="$SCRIPT_DIR/targets/Panel.qml"
MAIN_TARGET="$SCRIPT_DIR/targets/Main.qml"
MENU_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc"
DEFAULT_AGENT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/defaults/agent"

echo "openclaw-integration installer"
echo "==========================="
echo

# --- 0. OpenClaw presence check + official install if missing ---
echo "[0/6] OpenClaw installation check..."
if ! command -v openclaw >/dev/null 2>&1; then
    echo "    OpenClaw not found."
    echo
    read -r -p "    Install OpenClaw now? (runs the official installer) [Y/n] " resp
    resp=${resp:-Y}
    if [[ "$resp" =~ ^[Yy]$ ]]; then
        echo "    Running official OpenClaw installer..."
        # The official install script — pinned to a stable URL pattern.
        # OpenClaw's installer handles API key setup interactively.
        if curl -fsSL https://openclaw.io/install.sh | bash; then
            echo "    OpenClaw installed"
        else
            echo "    Official installer failed. Install OpenClaw manually: https://openclaw.io"
            echo "    Then re-run this script."
            exit 1
        fi
    else
        echo "    Skipped. Install OpenClaw manually: https://openclaw.io"
        echo "    Then re-run this script."
        exit 1
    fi
else
    openclaw --version 2>/dev/null | head -1 | sed 's/^/    Version: /'
fi

# --- 1. OpenClaw onboarding (API key setup) ---
echo
echo "[1/6] Running openclaw onboard (API key setup)..."
if command -v openclaw >/dev/null 2>&1; then
    # openclaw onboard is interactive — runs in the user's terminal.
    # It walks through API key configuration and any other setup.
    # If the user has already onboarded (env file exists with keys), it's a no-op.
    if [ -f "$HOME/.openclaw/.env" ]; then
        echo "    ~/.openclaw/.env already exists — skipping onboard."
        echo "    (Run \`openclaw onboard\` manually to update your keys.)"
    else
        openclaw onboard || {
            echo "    openclaw onboard exited non-zero. Continuing anyway."
            echo "    (You can run \`openclaw onboard\` manually later.)"
        }
    fi
fi

# --- 2. Collector script ---
echo
echo "[2/6] Collector script..."
if [ -f "$COLLECTOR_DST" ] && cmp -s "$COLLECTOR_SRC" "$COLLECTOR_DST"; then
    echo "    Already installed and current. Skipping."
else
    sudo cp "$COLLECTOR_SRC" "$COLLECTOR_DST"
    sudo chown root:root "$COLLECTOR_DST"
    sudo chmod 755 "$COLLECTOR_DST"
    echo "    Installed at $COLLECTOR_DST"
fi

# --- 3. SVG assets ---
echo
echo "[3/6] Lobster SVG assets..."
for svg in openclaw.svg openclaw-light.svg; do
    if [ -f "$ASSET_DST_DIR/$svg" ] && cmp -s "$ASSET_SRC_DIR/$svg" "$ASSET_DST_DIR/$svg"; then
        echo "    $svg: already current."
    else
        sudo cp "$ASSET_SRC_DIR/$svg" "$ASSET_DST_DIR/$svg"
        sudo chown root:root "$ASSET_DST_DIR/$svg"
        sudo chmod 644 "$ASSET_DST_DIR/$svg"
        echo "    Installed $svg"
    fi
done

# --- 4. Panel.qml + Main.qml (backup + replace) ---
echo
echo "[4/6] Panel.qml + Main.qml (backup + integrate)..."
for entry in "$PANEL_DST:$PANEL_BACKUP:$PANEL_TARGET" "$MAIN_DST:$MAIN_BACKUP:$MAIN_TARGET"; do
    IFS=':' read -r dst backup src <<< "$entry"
    name=$(basename "$dst")
    if [ ! -f "$dst" ]; then
        echo "    $name: not found at $dst. Skipping."
        continue
    fi
    if [ ! -f "$backup" ]; then
        sudo cp "$dst" "$backup"
        sudo chown root:root "$backup"
        sudo chmod 644 "$backup"
        echo "    Backed up $name to $(basename $backup)"
    fi
    sudo cp "$src" "$dst"
    sudo chown root:root "$dst"
    sudo chmod 644 "$dst"
    echo "    Replaced $name with integrated version"
done

# --- 5. Super space menu entry (agents → OpenClaw) ---
echo
echo "[5/6] Super space menu entry..."
mkdir -p "$(dirname "$MENU_CONFIG")"
if [ ! -f "$MENU_CONFIG" ]; then
    cat > "$MENU_CONFIG" <<'EOF'
{
  // Quickshell Omarchy menu extensions (JSONC).
  // Managed by omarchy extensions — safe to hand-edit; re-running the
  // adding extension leaves existing entries untouched.
}
EOF
fi
# Idempotent: skip if OpenClaw already listed
if grep -q '"openclaw"' "$MENU_CONFIG" 2>/dev/null; then
    echo "    OpenClaw entry already present."
else
    python3 - "$MENU_CONFIG" <<'PYEOF'
import json, sys, re
path = sys.argv[1]
with open(path) as f:
    raw = f.read()
clean = re.sub(r'//.*$', '', raw, flags=re.MULTILINE)
clean = re.sub(r'/\*.*?\*/', '', clean, flags=re.DOTALL)
data = json.loads(clean) if clean.strip() else {}
data.setdefault('super', {})
data.setdefault('submenus', {})
agents = data['super']['submenus'].setdefault('agents', {})
agents['openclaw'] = {
    'icon': '🦞',
    'label': 'OpenClaw',
    'action': 'omarchy-agent openclaw',
    'description': 'Launch OpenClaw',
}
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
    echo "    Added OpenClaw entry to $MENU_CONFIG"
fi

# --- 6. Default agent (interactive) ---
echo
echo "[6/6] Default agent (optional)..."
mkdir -p "$(dirname "$DEFAULT_AGENT_FILE")"
current_default=$(cat "$DEFAULT_AGENT_FILE" 2>/dev/null || echo "")
if [ "$current_default" = "openclaw" ]; then
    echo "    OpenClaw is already the default agent."
else
    read -r -p "    Set OpenClaw as the default agent? [y/N] " resp
    if [[ "$resp" =~ ^[Yy]$ ]]; then
        echo "openclaw" > "$DEFAULT_AGENT_FILE"
        echo "    Default agent set to OpenClaw (was: ${current_default:-unset})"
    else
        echo "    Skipped. To set later: echo openclaw > $DEFAULT_AGENT_FILE"
    fi
fi

# --- Reload Quickshell ---
echo
echo "Reloading Quickshell..."
QSPID=$(pgrep -f "quickshell -n -p /usr/share/omarchy/shell" | head -1 || true)
if [ -n "$QSPID" ]; then
    kill -TERM "$QSPID" 2>/dev/null || true
    sleep 3
    echo "    Quickshell reloaded (Hyprland auto-restarts it)"
else
    echo "    Quickshell not running. Will pick up changes on next start."
fi

echo
echo "═══════════════════════════════════════"
echo "Done! Open the agents panel (top-right):"
echo "  - You should see an 'OpenClaw' tab in the provider switcher"
echo "  - Inside the tab: Gateway active, version, model, runtime, Discord,"
echo "    Total sessions (all live)"
echo "  - Super space, agents, OpenClaw (in the Quickshell menu)"
echo
echo "If the panel doesn't update, restart Quickshell manually:"
echo "  pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'"
echo "  (Hyprland will auto-restart it)"
echo
echo "To uninstall: ./uninstall.sh"
echo "═══════════════════════════════════════"