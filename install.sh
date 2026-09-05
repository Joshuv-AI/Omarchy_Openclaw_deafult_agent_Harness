#!/usr/bin/env bash
# My Agents — user-plugin install.
#
# Architecture: this repo is a user-owned Omarchy plugin that replaces
# omarchy.agents via the supported `omarchy plugin clone` path.
#
# What this script does:
#   1. Verifies the omarchy CLI is available.
#   2. Clones the built-in omarchy.agents plugin into a user-owned
#      plugin directory (`~/.config/omarchy/plugins/<id>/`) via
#      `omarchy plugin clone omarchy.agents`. The user's plugin ID
#      is xensei.agents.
#   3. Copies the plugin code (BarWidget.qml, Panel.qml, adapters/,
#      collectors/, drivers/, providers/, audit/) into the cloned folder.
#   4. Installs the user-owned driver at
#      `~/.local/share/omarchy/agent-providers/omarchy-refresh`.
#   5. Installs the user-owned sweeper + a systemd --user timer that
#      refreshes every detected provider on the configured cooldown
#      cadence. The timer lives at
#      `~/.config/systemd/user/omarchy-agent-sweeper.{service,timer}`.
#   6. Validates the plugin manifest via `omarchy plugin validate`.
#
# What this script does NOT do:
#   - No writes to /usr/share/omarchy/
#   - No writes to /usr/bin/
#   - No sudo
#   - No symlinks to system paths
#   - No Quickshell restart (the shell hot-reloads on file save)
#   - No remote provider calls
#   - No real credential reads
#   - No git mutations
#
# Idempotent: re-running this script after the plugin is already
# installed will update the user plugin in place.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="xensei.agents"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
PLUGIN_SRC="$SCRIPT_DIR/plugin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
DRIVER_DST="$HOME/.local/share/omarchy/agent-providers"

echo "My Agents — user-plugin installer"
echo "═══════════════════════════════════════"
echo

# --- 0. omarchy CLI availability ---
echo "[0/6] Verifying omarchy CLI..."
if ! command -v omarchy >/dev/null 2>&1; then
    echo "    omarchy CLI not found. Install Omarchy before installing this plugin."
    exit 1
fi
echo "    ok"

# --- 1. Clone the built-in ---
echo
echo "[1/6] Cloning built-in omarchy.agents into user-owned plugin..."
if [ -d "$PLUGIN_DIR" ]; then
    echo "    $PLUGIN_DIR already exists. Skipping clone (will overlay plugin code)."
else
    omarchy plugin clone omarchy.agents
fi

# --- 2. Overlay plugin code ---
echo
echo "[2/6] Installing plugin code into $PLUGIN_DIR..."
mkdir -p "$PLUGIN_DIR/adapters" "$PLUGIN_DIR/collectors" "$PLUGIN_DIR/drivers" "$PLUGIN_DIR/providers/first-class" "$PLUGIN_DIR/providers/generic-fallback" "$PLUGIN_DIR/qml"
cp "$PLUGIN_SRC/BarWidget.qml"     "$PLUGIN_DIR/BarWidget.qml"
cp "$PLUGIN_SRC/Panel.qml"         "$PLUGIN_DIR/Panel.qml"
cp "$PLUGIN_SRC/Main.qml"          "$PLUGIN_DIR/Main.qml"
cp "$PLUGIN_SRC/Qt/ProviderCircle.qml"     "$PLUGIN_DIR/qml/ProviderCircle.qml"
cp "$PLUGIN_SRC/Qt/ProvidersAdapter.qml"   "$PLUGIN_DIR/qml/ProvidersAdapter.qml"
cp "$PLUGIN_SRC/adapters/normalize.js" "$PLUGIN_DIR/adapters/normalize.js"
cp "$PLUGIN_SRC/adapters/fields.js"   "$PLUGIN_DIR/adapters/fields.js"
cp "$PLUGIN_SRC/providers/registry.json" "$PLUGIN_DIR/providers/registry.json"
cp "$PLUGIN_SRC/collectors/"*.py "$PLUGIN_DIR/collectors/" 2>/dev/null || true
cp "$PLUGIN_SRC/collectors/"*.sh "$PLUGIN_DIR/collectors/" 2>/dev/null || true
cp "$PLUGIN_SRC/drivers/omarchy-refresh" "$PLUGIN_DIR/drivers/omarchy-refresh"
cp "$PLUGIN_SRC/drivers/omarchy-sweeper" "$PLUGIN_DIR/drivers/omarchy-sweeper"
chmod +x "$PLUGIN_DIR/drivers/omarchy-refresh" "$PLUGIN_DIR/drivers/omarchy-sweeper"
chmod +x "$PLUGIN_DIR/collectors/"*.sh 2>/dev/null || true
echo "    installed"

# --- 3. User-owned driver + collectors + sweeper ---
echo
echo "[3/6] Installing user-owned driver + collectors + sweeper..."
mkdir -p "$DRIVER_DST/collectors"
cp "$PLUGIN_SRC/drivers/omarchy-refresh" "$DRIVER_DST/omarchy-refresh"
cp "$PLUGIN_SRC/drivers/omarchy-sweeper" "$DRIVER_DST/omarchy-sweeper"
cp "$PLUGIN_SRC/collectors/"*.py "$DRIVER_DST/collectors/" 2>/dev/null || true
cp "$PLUGIN_SRC/collectors/"*.sh "$DRIVER_DST/collectors/" 2>/dev/null || true
chmod +x "$DRIVER_DST/omarchy-refresh" "$DRIVER_DST/omarchy-sweeper"
chmod +x "$DRIVER_DST/collectors/"*.sh 2>/dev/null || true
echo "    driver at $DRIVER_DST/omarchy-refresh"
echo "    sweeper at $DRIVER_DST/omarchy-sweeper"

# --- 4. systemd --user timer ---
echo
echo "[4/6] Installing systemd --user sweeper timer..."
mkdir -p "$SYSTEMD_USER_DIR"
cp "$PLUGIN_SRC/systemd/omarchy-agent-sweeper.service" "$SYSTEMD_USER_DIR/omarchy-agent-sweeper.service"
cp "$PLUGIN_SRC/systemd/omarchy-agent-sweeper.timer"   "$SYSTEMD_USER_DIR/omarchy-agent-sweeper.timer"
# Reload systemd user daemon, enable + start the timer. If systemd is not
# available for the user session (e.g., headless), skip silently.
if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable omarchy-agent-sweeper.timer
    systemctl --user restart omarchy-agent-sweeper.timer
    echo "    timer enabled and started"
else
    echo "    systemd --user not available — skipping timer enable. Sweeper can still be invoked manually via $DRIVER_DST/omarchy-sweeper"
fi

# --- 5. Validate plugin ---
echo
echo "[5/6] Validating plugin manifest..."
if ! omarchy plugin validate "$PLUGIN_DIR"; then
    echo "    Validation failed. Inspect $PLUGIN_DIR/manifest.json."
    exit 1
fi
echo "    ok"

# --- 6. Initial probe (best-effort) ---
echo
echo "[6/6] Running initial sweeper pass (best-effort, may skip on cooldown)..."
"$DRIVER_DST/omarchy-sweeper" 2>&1 | tail -5 || echo "    (sweeper exited non-zero; will retry on next timer tick)"

echo
echo "════════════════════════════════════════════════════════"
echo "Done! The user plugin '$PLUGIN_ID' is now installed."
echo
echo "  Plugin code:        $PLUGIN_DIR"
echo "  User-owned driver:  $DRIVER_DST/omarchy-refresh"
echo "  User-owned sweeper: $DRIVER_DST/omarchy-sweeper"
echo "  Systemd timer:      $SYSTEMD_USER_DIR/omarchy-agent-sweeper.timer"
echo
echo "The Omarchy shell hot-reloads automatically — no Quickshell restart."
echo
echo "Detected providers appear in the dock as icons. The sweeper timer"
echo "refreshes every detected provider every 15 minutes (configurable"
echo "in the plugin's manifest defaults). Click an icon, then click the"
echo "Refresh button in the popup to refresh on demand."
echo
echo "To uninstall: ./uninstall.sh"
echo "════════════════════════════════════════════════════════"
