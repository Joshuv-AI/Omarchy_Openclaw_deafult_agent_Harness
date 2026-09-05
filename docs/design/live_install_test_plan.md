# Live install test plan — separate document, separate execution

This document is a proposed test plan for the live install. It is NOT
executed as part of the automated test suite. Live install is a manual
gate that requires explicit authorization.

## Pre-flight (do not skip)

1. The repo working copy is at
   `/run/media/xensei/7868D91368D8D14C/AI/OpenClaw/workspace/projects/omarchy-agent-panel-repo/`.
2. All automated tests pass:
   - `node tests/unit/run_tests.js` exits 0.
   - `bash tests/integration/no_omarchy_write_test.sh` exits 0.
   - `bash tests/integration/install_rollback_test.sh` exits 0.
3. `git status` shows all changes; `git diff --stat` is reviewed.
4. The repo is committed locally (commit but do not push) so a rollback
   point is clear.
5. SHA-256 baseline of `/usr/share/omarchy/` and
   `/usr/bin/omarchy-agent-usage-*` is captured and saved to
   `tests/integration/baseline.sha256`.

## Steps (in order)

1. **Run the validation milestone first** (clone → validate → disable →
   remove → cleanup → hash recheck). Confirm the SHA-256 of
   `/usr/share/omarchy/` and `/usr/bin/omarchy-agent-usage-*` matches
   the baseline after the cycle.
2. **Run `./install.sh`** with explicit user authorization. Confirm
   - `omarchy plugin validate ~/.config/omarchy/plugins/xensei.agents` exits 0.
   - No writes to `/usr/share/omarchy/` or `/usr/bin/`.
   - The user-owned driver exists at `~/.local/share/omarchy/agent-providers/omarchy-refresh`.
3. **Visual check** (with screen capture available):
   - Open the panel; confirm tier-aware rendering.
   - Confirm first-click is select-only (no refresh triggered).
   - Hover an icon; confirm the visible opacity change.
   - Click the labeled Refresh button; confirm the driver invocation
     (without `--force` it should refuse inside the cooldown; with
     `--force` it should invoke the collector).
4. **Detection-only verification**: confirm that providers without
   configured credentials do NOT show an icon (CodeX shows because
   `~/.codex/` is present; Claude does not because
   `~/.claude/.credentials.json` is absent; Hermes does not because
   no config file or binary).
5. **Generic-fallback verification**: simulate detection of an
   undocumented provider (e.g., `opencode` binary on PATH) and
   confirm a labeled card with `Configuration detected` /
   `Active model detected` / `No limit data exposed`.
6. **Stale verification**: write a fixture with `updatedAt` older
   than 15 minutes and confirm the icon stays but the ring is
   desaturated and the label says `Last checked Nm ago · stale`.
7. **Ring-fill invariant (visual)**: install a fixture that would
   trigger the regression. MiniMax with `intervalRemainingPct: 96`
   must render a 96%-full ring. If the ring renders as 4% full, the
   invariant has been broken.
8. **No-write verification** (Gate H repeat):
   - SHA-256 of `/usr/share/omarchy/` and `/usr/bin/omarchy-agent-usage-*`
     matches the baseline.
9. **Rollback** (Gate F/G repeat):
   - `omarchy plugin disable xensei.agents` — built-in returns.
   - `omarchy plugin remove xensei.agents --yes` — clone folder
     removed; any leftover `.bak.*` folder is cleaned up.
   - `./uninstall.sh` removes the user-owned driver at
     `~/.local/share/omarchy/agent-providers/`.
   - SHA-256 still matches the baseline.

## What this test plan does NOT do

- It does NOT install on the live machine without explicit authorization.
- It does NOT make real provider API calls (all probes are gated on
  user opt-in via the setup view).
- It does NOT use real credentials — the live install test uses
  non-existent env var names to verify the "configuration not detected"
  path, not real keys.
- It does NOT restart Quickshell (the shell hot-reloads automatically).
- It does NOT commit or push any changes.

## Stop point

After Step 9, the live install test plan ends. Any further work
(integration with the OpenClaw gateway, additional providers, etc.)
is a separate proposal requiring explicit authorization.
