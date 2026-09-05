# Dock-visibility invariant

```
showInDock = detectedLocally && userEnabled
```

## Detected locally

A provider is considered "detected locally" when any of the following
non-secret presence/configuration signals returns positive:

1. **Active gateway / session / model state** — what is currently
   running or active right now.
   - OpenClaw: `systemctl --user is-active openclaw-gateway.service`.
   - Hermes: `hermes status` reports `gateway: running`.
   - Codex: a Codex session has activity within the freshness window.

2. **Documented harness provider/profile configuration** — what the
   harness has configured.
   - OpenClaw: `~/.openclaw/` directory present.
   - Mise: a provider stub is configured in `~/.config/mise/config.toml`.

3. **Existing local usage records** — what the harness has already
   written locally.
   - `~/.local/state/omarchy/agents/usage/<id>.json` exists.

4. **Documented credential/config-file presence** — what credential
   files exist on disk.
   - Claude: `~/.claude/.credentials.json` exists.
   - Codex: `~/.codex/` exists.
   - Hermes: `~/.hermes/config.yaml` exists.

5. **Process environment** — only as a final supplemental signal.
   - env var name is detected (presence only, never the value).

## User enabled

The user can hide a provider in the setup view. Default is enabled
for any auto-detected provider.

## What the invariant rejects

- A provider without a local detection signal must NOT show in the
  dock, regardless of any documentation, fixture, or registry entry.
- A provider hidden by the user must NOT show in the dock,
  regardless of detection.
- Stale telemetry (older than the configured cooldown) does NOT
  remove the icon — only expired detection does.
- A user-plugins folder alone is NOT a detection signal — the
  detection must come from the priority order above.

## Test

`tests/unit/run_tests.js` group "Dock-visibility invariant" verifies
the matrix:

| detected | userEnabled | result |
|---|---|---|
| true  | true  | showInDock = true |
| true  | false | showInDock = false |
| false | true  | showInDock = false |
| false | false | showInDock = false |
| true, stale data | true | showInDock = true |
| true, expired detection | true | showInDock = false |
