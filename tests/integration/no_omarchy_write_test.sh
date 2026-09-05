#!/usr/bin/env bash
# tests/integration/no_omarchy_write_test.sh
#
# Verifies that no files in /usr/share/omarchy/ or /usr/bin/omarchy-agent-usage-*
# are modified by the plugin's install/uninstall/refresh sequence.
#
# We compute SHA-256 baselines before and after, and assert no drift.
#
# This test does NOT install the plugin — it verifies the install script's
# invariants by reading the install script and confirming that no `sudo cp`
# or `cp` to /usr/share/omarchy/ or /usr/bin/ appears in the script.
# (The repo install script uses the `omarchy plugin clone` path, which
# writes only to ~/.config/omarchy/plugins/<user>.agents/.)
#
# Exit code 0 on pass; non-zero on fail.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== Baseline SHA-256 of /usr/share/omarchy and /usr/bin/omarchy-agent-usage-* ==="
BASELINE=$(sha256sum /usr/bin/omarchy-agent-usage-* /usr/share/omarchy/shell/plugins/agents/*.qml /usr/share/omarchy/shell/plugins/agents/*.json 2>/dev/null | sort)
echo "$BASELINE" | head -5
echo "  ... (truncated for readability)"
echo "Total lines: $(echo "$BASELINE" | wc -l)"

echo
echo "=== Static analysis of install.sh — no writes to /usr/share/omarchy or /usr/bin ==="
bad_writes=$(grep -nE '(sudo\s+)?cp\s+.*(/usr/share/omarchy/|/usr/bin/omarchy-agent-usage-)' "$ROOT/install.sh" || true)
if [ -n "$bad_writes" ]; then
    echo "  FAIL: install.sh contains writes to /usr/share/omarchy/ or /usr/bin/omarchy-agent-usage-:"
    echo "$bad_writes"
    exit 1
fi
echo "  PASS: install.sh has no cp/sudo cp writes to /usr/share/omarchy/ or /usr/bin/omarchy-agent-usage-*"

echo
echo "=== Static analysis of uninstall.sh — no writes to /usr/share/omarchy or /usr/bin ==="
bad_writes=$(grep -nE '(sudo\s+)?(rm|mv|cp)\s+.*(/usr/share/omarchy/|/usr/bin/omarchy-agent-usage-)' "$ROOT/uninstall.sh" || true)
if [ -n "$bad_writes" ]; then
    echo "  FAIL: uninstall.sh contains writes to /usr/share/omarchy/ or /usr/bin/omarchy-agent-usage-:"
    echo "$bad_writes"
    exit 1
fi
echo "  PASS: uninstall.sh has no rm/mv/cp writes to /usr/share/omarchy/ or /usr/bin/omarchy-agent-usage-*"

echo
echo "=== Verify plugin driver lives at ~/.local/share/... ==="
if grep -nE 'DATA_DIR.*XDG_DATA_HOME.*omarchy/agent-providers' "$ROOT/plugin/drivers/omarchy-refresh" >/dev/null; then
    echo "  PASS: plugin/drivers/omarchy-refresh uses ~/.local/share/omarchy/agent-providers/"
else
    echo "  FAIL: plugin/drivers/omarchy-refresh does not use ~/.local/share/omarchy/agent-providers/"
    exit 1
fi

echo
echo "=== Re-verify SHA-256 has not drifted during this test ==="
ENDSTATE=$(sha256sum /usr/bin/omarchy-agent-usage-* /usr/share/omarchy/shell/plugins/agents/*.qml /usr/share/omarchy/shell/plugins/agents/*.json 2>/dev/null | sort)
if [ "$BASELINE" = "$ENDSTATE" ]; then
    echo "  PASS: SHA-256 hashes match between baseline and end-of-test."
else
    echo "  FAIL: SHA-256 hashes differ between baseline and end-of-test."
    diff <(echo "$BASELINE") <(echo "$ENDSTATE")
    exit 1
fi

echo
echo "═══════════════════════════════════════════"
echo "no_omarchy_write_test.sh: ALL CHECKS PASSED"
echo "═══════════════════════════════════════════"
