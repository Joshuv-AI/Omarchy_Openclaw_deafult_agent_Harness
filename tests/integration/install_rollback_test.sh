#!/usr/bin/env bash
# tests/integration/install_rollback_test.sh
#
# Validates the install.sh and uninstall.sh SHELL-LEVEL invariants by
# parsing them statically. Does NOT execute the install. We do NOT
# install on the live machine during automated tests; live install is a
# separate manual gate (see docs/design/live_install_test_plan.md).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== install.sh: omarchy plugin clone path (NOT package-file patching) ==="
if grep -nE 'omarchy plugin clone' "$ROOT/install.sh" >/dev/null; then
    echo "  PASS: install.sh uses 'omarchy plugin clone'"
else
    echo "  FAIL: install.sh does not use 'omarchy plugin clone'"
    exit 1
fi

echo
echo "=== install.sh: NO writes to /usr/share/omarchy ==="
if grep -nE '(sudo\s+)?(cp|mv)\s+["$]?[^\n]*/usr/share/omarchy' "$ROOT/install.sh" >/dev/null; then
    echo "  FAIL: install.sh writes to /usr/share/omarchy"
    grep -nE '(sudo\s+)?(cp|mv)\s+["$]?[^\n]*/usr/share/omarchy' "$ROOT/install.sh"
    exit 1
fi
echo "  PASS: install.sh does not write to /usr/share/omarchy"

echo
echo "=== install.sh: NO writes to /usr/bin ==="
if grep -nE '(sudo\s+)?(cp|mv)\s+["$]?[^\n]*/usr/bin/' "$ROOT/install.sh" >/dev/null; then
    echo "  FAIL: install.sh writes to /usr/bin/"
    grep -nE '(sudo\s+)?(cp|mv)\s+["$]?[^\n]*/usr/bin/' "$ROOT/install.sh"
    exit 1
fi
echo "  PASS: install.sh does not write to /usr/bin/"

echo
echo "=== install.sh: NO sudo invocations ==="
if grep -nE '^\s*sudo\s+|[^A-Za-z0-9_]sudo\s+[A-Za-z]' "$ROOT/install.sh" >/dev/null; then
    echo "  FAIL: install.sh uses sudo"
    grep -nE '^\s*sudo\s+|[^A-Za-z0-9_]sudo\s+[A-Za-z]' "$ROOT/install.sh"
    exit 1
fi
echo "  PASS: install.sh has no sudo invocations"

echo
echo "=== install.sh: NO Quickshell restarts (no kill of quickshell process) ==="
if grep -nE '(kill|pkill).*quickshell' "$ROOT/install.sh" >/dev/null; then
    echo "  FAIL: install.sh kills quickshell (relies on omarchy's hot-reload)"
    grep -nE '(kill|pkill).*quickshell' "$ROOT/install.sh"
    exit 1
fi
echo "  PASS: install.sh does not kill Quickshell — relies on hot-reload"

echo
echo "=== install.sh: NO remote provider calls from install ==="
if grep -nE 'curl.*(minimax|moonshot|xai|gemini|dashscope|fireworks)' "$ROOT/install.sh" >/dev/null; then
    echo "  FAIL: install.sh makes remote provider calls"
    grep -nE 'curl.*(minimax|moonshot|xai|gemini|dashscope|fireworks)' "$ROOT/install.sh"
    exit 1
fi
echo "  PASS: install.sh does not call any provider API"

echo
echo "=== install.sh: NO real credential reads ==="
if grep -nE 'grep.*KEY|read.*KEY' "$ROOT/install.sh" >/dev/null; then
    echo "  FAIL: install.sh reads credentials"
    grep -nE 'grep.*KEY|read.*KEY' "$ROOT/install.sh"
    exit 1
fi
echo "  PASS: install.sh does not read any credentials"

echo
echo "=== uninstall.sh: clones are removed via omarchy plugin remove ==="
if grep -nE 'omarchy plugin remove' "$ROOT/uninstall.sh" >/dev/null; then
    echo "  PASS: uninstall.sh uses 'omarchy plugin remove'"
else
    echo "  FAIL: uninstall.sh does not use 'omarchy plugin remove'"
    exit 1
fi

echo
echo "═══════════════════════════════════════════"
echo "install_rollback_test.sh: ALL CHECKS PASSED"
echo "═══════════════════════════════════════════"
