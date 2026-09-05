# My Agents — Omarchy user plugin (v3.0)

A user-owned Omarchy plugin that replaces the `omarchy.agents` dock
icon via the supported `omarchy plugin clone` path. Detected-only
provider registry with first-class adapters and a generic
detected-provider fallback.

## What this is

This is the v3 architecture: a true user plugin installed via
`omarchy plugin clone omarchy.agents`. It replaces the previous v2
package-file patching installer.

| what | where |
|---|---|
| Plugin code | `~/.config/omarchy/plugins/xensei.agents/` |
| User-owned driver | `~/.local/share/omarchy/agent-providers/omarchy-refresh` |
| User-owned collectors | `~/.local/share/omarchy/agent-providers/collectors/` |
| Cache | `~/.cache/omarchy/agent-providers/` |
| Usage JSON | `~/.local/state/omarchy/agents/usage/*.json` (Omarchy collectors + ours) |

**No writes to `/usr/share/omarchy/` or `/usr/bin/`. No sudo. No
symlinks to system paths. No Quickshell restart.**

## Detected-only providers

A provider shows in the dock only when it is detected locally AND
the user has not hidden it. Stale telemetry does not remove the
icon; only expired detection does.

Detection uses non-secret presence/configuration signals in priority
order: active service → harness config → usage record → credential
file → env var NAME (never value).

## Tier-aware rendering

Each provider renders into one of seven tier categories, never
conflated:

| tier | visual |
|---|---|
| remaining quota | green ring, label `Remaining: <percent>` |
| balance | labeled currency value (no ring) |
| capacity | labeled cap line (no ring) |
| connection | gray-blue dot |
| gateway | purple dot |
| local history | small gray ring + `History: <N> tokens today` |
| generic detected | labeled card with honest status |
| unavailable | labeled card with reason |

## Ring-fill invariant

For every quota tier, ring fill means remaining allowance. Full
means more allowance remains. A regression test in
`tests/unit/run_tests.js` rejects any inversion.

## Install

```bash
./install.sh
```

The install script:

1. Verifies the `omarchy` CLI is available.
2. Clones `omarchy.agents` into `~/.config/omarchy/plugins/xensei.agents/`.
3. Overlays the plugin code (QML, adapters, collectors, driver).
4. Installs the user-owned driver at `~/.local/share/omarchy/agent-providers/`.
5. Validates the manifest via `omarchy plugin validate`.

The Omarchy shell hot-reloads automatically — no Quickshell restart.

## Uninstall

```bash
./uninstall.sh
```

Removes the user plugin and the user-owned driver. The built-in
`omarchy.agents` is restored.

## Tests

```bash
node tests/unit/run_tests.js
bash tests/integration/no_omarchy_write_test.sh
bash tests/integration/install_rollback_test.sh
```

Unit tests exercise the adapter layer against fixtures shipped under
`tests/fixtures/`. Integration tests verify install/uninstall
invariants and SHA-256 drift of `/usr/share/omarchy/` and
`/usr/bin/omarchy-agent-usage-*`.

## Live install test plan

`docs/design/live_install_test_plan.md` describes the manual gate for
installing on a live machine. Live install is NOT executed as part
of the automated test suite.

## License

AGPL-3.0 — see LICENSE.

## Historical context

The previous v2 architecture patched package files in
`/usr/share/omarchy/` and `/usr/bin/`. That architecture is preserved
under `legacy/` for historical reference only; it is not used by
this version of the plugin.
