#!/usr/bin/env bash
# My Agents — user-plugin uninstall.
#
# Reverses install.sh by removing the user-owned plugin folder, the
# user-owned driver, and the systemd --user sweeper timer. Restores the
# built-in omarchy.agents plugin.
#
# What this script does:
#   1. `omarchy plugin remove xensei.agents` — restores built-in.
#   2. Disables and removes the systemd --user sweeper timer.
#   3. Removes the user-owned driver at ~/.local/share/omarchy/agent-providers/.
#
# What this script does NOT do:
#   - No writes to /usr/share/omarchy/
#   - No writes to /usr/bin/
#   - No sudo

set -euo pipefail

PLUGIN_ID="xensei.agents"
DRIVER_DST="$HOME/.local/share/omarchy/agent-providers"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "My Agents — user-plugin uninstaller"
echo "═══════════════════════════════════════"

# --- 1. Disable + remove systemd --user timer ---
echo "[1/3] Disabling systemd --user sweeper timer..."
if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    systemctl --user disable --now omarchy-agent-sweeper.timer 2>/dev/null || true
    echo "    timer disabled"
else
    echo "    systemd --user not available; skipping"
fi
rm -f "$SYSTEMD_USER_DIR/omarchy-agent-sweeper.service" \
      "$SYSTEMD_USER_DIR/omarchy-agent-sweeper.timer"
echo "    timer files removed"

# --- 2. Remove user plugin ---
echo
echo "[2/3] Removing user plugin '$PLUGIN_ID'..."
if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin remove "$PLUGIN_ID" --yes || true
fi
rm -rf "$HOME/.config/omarchy/plugins/.${PLUGIN_ID}.bak."* 2>/dev/null || true
echo "    done"

# --- 3. Remove user-owned driver + sweeper ---
echo
echo "[3/3] Removing user-owned driver + sweeper..."
if [ -d "$DRIVER_DST" ]; then
    rm -rf "$DRIVER_DST"
fi
echo "    done"

echo
echo "════════════════════════════════════════════════════════"
echo "Uninstall complete. The built-in omarchy.agents is restored."
echo "════════════════════════════════════════════════════════"
