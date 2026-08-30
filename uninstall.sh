#!/usr/bin/env bash
# openclaw-integration uninstaller — reverses install.sh.
# Does NOT uninstall OpenClaw itself — that has its own uninstall.
set -euo pipefail

COLLECTOR_DST="/usr/bin/omarchy-agent-usage-openclaw"
ASSET_DST_DIR="/usr/share/omarchy/shell/plugins/agents/assets"
PANEL_DST="/usr/share/omarchy/shell/plugins/agents/Panel.qml"
MAIN_DST="/usr/share/omarchy/shell/plugins/agents/Main.qml"
PANEL_BACKUP="${PANEL_DST}.openclaw-backup"
MAIN_BACKUP="${MAIN_DST}.openclaw-backup"
MENU_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc"
DEFAULT_AGENT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/defaults/agent"

echo "openclaw-integration uninstaller"
echo "============================="
echo

# --- 1. Restore Panel.qml + Main.qml from backups ---
echo "[1/4] Restoring Panel.qml + Main.qml..."
for entry in "$PANEL_DST:$PANEL_BACKUP" "$MAIN_DST:$MAIN_BACKUP"; do
    IFS=':' read -r dst backup <<< "$entry"
    name=$(basename "$dst")
    if [ -f "$backup" ]; then
        sudo mv "$backup" "$dst"
        sudo chown root:root "$dst"
        sudo chmod 644 "$dst"
        echo "    Restored $name from backup"
    else
        echo "    $name: no backup at $backup. Skipping."
    fi
done

# --- 2. Remove collector ---
echo
echo "[2/4] Removing collector..."
if [ -f "$COLLECTOR_DST" ]; then
    sudo rm -f "$COLLECTOR_DST"
    echo "    Removed $COLLECTOR_DST"
else
    echo "    Not present."
fi

# --- 3. Remove SVG assets ---
echo
echo "[3/4] Removing SVG assets..."
for svg in openclaw.svg openclaw-light.svg; do
    if [ -f "$ASSET_DST_DIR/$svg" ]; then
        sudo rm -f "$ASSET_DST_DIR/$svg"
        echo "    Removed $svg"
    fi
done

# --- 4. Remove menu entry (only if we added it) ---
echo
echo "[4/4] Removing super space menu entry..."
if [ -f "$MENU_CONFIG" ] && grep -q '"openclaw"' "$MENU_CONFIG" 2>/dev/null; then
    python3 - "$MENU_CONFIG" <<'PYEOF'
import json, sys, re
path = sys.argv[1]
with open(path) as f:
    raw = f.read()
clean = re.sub(r'//.*$', '', raw, flags=re.MULTILINE)
clean = re.sub(r'/\*.*?\*/', '', clean, flags=re.DOTALL)
data = json.loads(clean) if clean.strip() else {}
agents = data.get('super', {}).get('submenus', {}).get('agents', {})
if 'openclaw' in agents:
    del agents['openclaw']
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
    echo "    Removed OpenClaw entry from $MENU_CONFIG"
else
    echo "    No OpenClaw entry found."
fi

echo
echo "═══════════════════════════════════════════════════════"
echo "Done. Reload Quickshell for changes to take effect:"
echo "  pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'"
echo
echo "(Your default agent preference is preserved. To reset:"
echo "  rm $DEFAULT_AGENT_FILE)"
echo
echo "Note: this uninstaller does NOT uninstall OpenClaw itself."
echo "If you want to remove OpenClaw too, follow its own uninstall steps."
echo "═══════════════════════════════════════════════════════"