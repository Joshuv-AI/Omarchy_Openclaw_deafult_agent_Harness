#!/usr/bin/env bash
# My Agents — user-plugin uninstall.
#
# Reverses install.sh by removing the user-owned plugin folder and the
# user-owned driver. Restores the built-in omarchy.agents plugin.
#
# What this script does:
#   1. `omarchy plugin remove xensei.agents` — restores built-in.
#   2. Removes the user-owned driver at ~/.local/share/omarchy/agent-providers/.
#
# What this script does NOT do:
#   - No writes to /usr/share/omarchy/
#   - No writes to /usr/bin/
#   - No sudo

set -euo pipefail

PLUGIN_ID="xensei.agents"
DRIVER_DST="$HOME/.local/share/omarchy/agent-providers"

echo "My Agents — user-plugin uninstaller"
echo "═══════════════════════════════════════"

# --- 1. Remove user plugin ---
echo "[1/2] Removing user plugin '$PLUGIN_ID'..."
if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin remove "$PLUGIN_ID" --yes || true
fi
# Clean up any leftover backup folder that `omarchy plugin remove` may leave.
rm -rf "$HOME/.config/omarchy/plugins/.${PLUGIN_ID}.bak."* 2>/dev/null || true
echo "    done"

# --- 2. Remove user-owned driver ---
echo
echo "[2/2] Removing user-owned driver..."
if [ -d "$DRIVER_DST" ]; then
    rm -rf "$DRIVER_DST"
fi
echo "    done"

echo
echo "════════════════════════════════════════════════════════"
echo "Uninstall complete. The built-in omarchy.agents is restored."
echo "════════════════════════════════════════════════════════"
