#!/usr/bin/env bash
# openclaw-integration uninstaller — reverses install.sh.
# Does NOT uninstall OpenClaw itself — that has its own uninstall.
set -euo pipefail

ASSET_DST_DIR="/usr/share/omarchy/shell/plugins/agents/assets"
PANEL_DST="/usr/share/omarchy/shell/plugins/agents/Panel.qml"
MAIN_DST="/usr/share/omarchy/shell/plugins/agents/Main.qml"
MANIFEST_DST="/usr/share/omarchy/shell/plugins/agents/manifest.json"
PANEL_BACKUP="${PANEL_DST}.openclaw-backup"
MAIN_BACKUP="${MAIN_DST}.openclaw-backup"
MANIFEST_BACKUP="${MANIFEST_DST}.openclaw-backup"
MENU_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc"
DEFAULT_AGENT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/defaults/agent"

echo "openclaw-integration uninstaller"
echo "============================="
echo

# --- 1. Restore Panel.qml + Main.qml + manifest.json from backups ---
echo "[1/5] Restoring Panel.qml + Main.qml + manifest.json..."
for entry in \
  "$PANEL_DST:$PANEL_BACKUP" \
  "$MAIN_DST:$MAIN_BACKUP" \
  "$MANIFEST_DST:$MANIFEST_BACKUP"; do
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

# --- 2. Remove collectors ---
echo
echo "[2/5] Removing collectors..."
for collector in omarchy-agent-usage-openclaw omarchy-agent-usage-grok omarchy-agent-usage-gemini; do
    dst="/usr/bin/$collector"
    if [ -f "$dst" ]; then
        sudo rm -f "$dst"
        echo "    Removed $dst"
    fi
done

# --- 3. Remove SVG assets ---
echo
echo "[3/5] Removing SVG assets..."
# Only remove SVGs that this package added. Brand SVGs (claude / codex /
# codex-light / fireworks) originally came from Omarchy base — even if we
# overwrote them with greied versions during install, leave them rather than
# risk removing Omarchy's icons.
for svg in openclaw.svg openclaw-light.svg grok.svg gemini.svg; do
    if [ -f "$ASSET_DST_DIR/$svg" ]; then
        sudo rm -f "$ASSET_DST_DIR/$svg"
        echo "    Removed $svg"
    fi
done

# --- 4. Remove menu entry ---
echo
echo "[4/5] Removing super space menu entry..."
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

# --- 5. Reload Quickshell ---
echo
echo "[5/5] Reloading Quickshell..."
QSPID=$(pgrep -f "quickshell -n -p /usr/share/omarchy/shell" | head -1 || true)
if [ -n "$QSPID" ]; then
    kill -TERM "$QSPID" 2>/dev/null || true
    sleep 3
    echo "    Quickshell reloaded (Hyprland auto-restarts it)"
else
    echo "    Quickshell not running."
fi

echo
echo "═══════════════════════════════════════════════════════"
echo "Done. Your default agent preference is preserved. To reset:"
echo "  rm $DEFAULT_AGENT_FILE"
echo
echo "Note: this uninstaller does NOT uninstall OpenClaw itself."
echo "If you want to remove OpenClaw too, follow its own uninstall steps."
echo
echo "If you had set XAI_API_KEY or GEMINI_API_KEY, those env vars are"
echo "still in your environment — unset them if you no longer want Grok or"
echo "Gemini collectors to write data:"
echo "  unset XAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY"
echo "═══════════════════════════════════════════════════════"
