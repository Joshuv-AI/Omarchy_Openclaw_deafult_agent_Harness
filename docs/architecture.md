# Architecture

## What this is

A drop-in Omarchy extension that integrates [OpenClaw](https://openclaw.io) into Omarchy's native agents panel. After `./install.sh`, OpenClaw appears as a tab in the panel with live status, and a lobster OpenClaw entry in the super-space menu under **agents**.

## Components

```
openclaw-integration/
├── manifest.json              Plugin metadata (entry points, permissions, security boundaries)
├── README.md                   Quick start + verify + uninstall + extending
├── LICENSE                     AGPL-3.0
├── install.sh                  Idempotent installer
├── uninstall.sh                Reversible uninstaller (restores backups)
├── bin/
│   └── omarchy-agent-usage-openclaw
│                              Collector script — emits JSON for the panel
├── assets/
│   ├── openclaw.svg            Lobster icon (dark)
│   └── openclaw-light.svg      Lobster icon (light)
├── targets/
│   ├── Panel.qml               Omarchy stock + OpenClaw display block (panel body)
│   └── Main.qml                Omarchy stock + displayProvider() forwards
├── docs/
│   ├── architecture.md         This file
│   ├── security.md             Threat model + explicit non-goals
│   ├── telemetry.md            Data flow + cache contract
│   └── troubleshooting.md      Common issues + fixes
└── skill/
    └── SKILL.md                AI agent maintenance guide
```

## Runtime flow

```
        ┌─────────────────────────────────────┐
        │  Omarchy agent sweep (every ~30s)  │
        └──────────────┬──────────────────────┘
                       │ invokes
                       ▼
        ┌──────────────────────────────────────┐
        │  omarchy-agent-usage-update           │
        │  /usr/bin/omarchy-agent-usage-update  │
        └──────────────┬──────────────────────┘
                       │ forks per collector
                       ▼
        ┌──────────────────────────────────────┐
        │  omarchy-agent-usage-openclaw         │
        │  (our collector)                       │
        │                                        │
        │  1. Reads ~/.openclaw/.env (API keys)  │
        │  2. Runs `openclaw --version`          │
        │  3. systemctl is-active openclaw-      │
        │     gateway.service                    │
        │  4. Walks ~/.openclaw/crestodian/      │
        │     sessions/ for trajectory data       │
        │  5. Emits JSON to stdout                │
        └──────────────┬──────────────────────┘
                       │ JSON
                       ▼
        ┌──────────────────────────────────────┐
        │  openclaw.json (cache)                 │
        │  ~/.local/state/omarchy/agents/usage/  │
        └──────────────┬──────────────────────┘
                       │ watched by
                       ▼
        ┌──────────────────────────────────────┐
        │  Omarchy agents panel (Quickshell)    │
        │  Panel.qml + Main.qml                 │
        └──────────────────────────────────────┘
```

## Why we patch Omarchy-shipped files

Omarchy's agents panel reads from `Panel.qml` + `Main.qml` in `/usr/share/omarchy/shell/plugins/agents/`. There's no plugin override mechanism for these files today — agents can be added via the collector mechanism (what we do) but their visual integration requires patching.

We **minimize the patch surface**:
- `Panel.qml` gets a single block of OpenClaw-custom text + one visibility condition (`isOpenClaw`).
- `Main.qml` gets a small block of fields forwarded from `record` to `provider` in `displayProvider()`.

Both files are backed up before patching (`*.openclaw-backup`). `uninstall.sh` restores from backup.

## Why a state file for stale-data-fallback

OpenClaw's trajectory, gateway, and version checks can transiently fail (CLI not on PATH yet, service momentarily stopped, etc.). The collector wraps live checks with a state file:

```
~/.local/state/omarchy/agents/usage/openclaw.json       # current record (cache)
~/.local/state/omarchy/agents/usage/openclaw.state.json # last known good record
```

On success: write to `openclaw.json` AND `openclaw.state.json`.
On error (any live check fails): return contents of `openclaw.state.json` instead of zeros.

This means a transient failure shows stale-but-correct data instead of "0 sessions / 0 tokens / inactive". The user sees when their data is current vs stale via the `updatedAt` timestamp.

## Refresh semantics

- The Omarchy sweeper invokes our collector approximately every 30 seconds.
- The collector itself has a 20-second "fresh" window — if the sweeper runs more frequently, the collector returns the cached record without re-running live checks.
- The collector does NOT poll on its own — it's invoked by the sweeper. This keeps the integration passive and reversible.

## Why no Polkit / no service installation

The collector reads `systemctl --user is-active` (user-scope, no root needed) and `pgrep -f` (user-scope). It never creates services, never modifies `/etc/`, never escalates privileges. The panel is read-only over the user's OpenClaw installation.

## Security-relevant boundaries

See [`security.md`](security.md) for the full threat model and explicit non-goals. Short version:

- The integration never collects credentials.
- The integration never executes remote code.
- The integration never modifies files outside the install paths listed in `manifest.json`.
- The integration's "default agent" toggle is opt-in (user is prompted).
