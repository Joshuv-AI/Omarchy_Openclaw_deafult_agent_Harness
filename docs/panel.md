# Panel

The agents panel (`omarchy.agents` in the Omarchy bar) is the user-facing
surface for this integration. This document covers what the panel does,
how it's wired, and the parts that change with this version of the
OpenClaw harness.

## What the panel shows

The panel is a multi-provider status dashboard. Each **enabled provider**
gets:

- A dock circle in the bar with the provider's brand-colored progress
  ring around a greied-out center icon
- A tab in the panel popup with live data (active model, runtime,
  rate-limit window, daily usage, etc.)
- A `today` and a `weekly` meter when the collector emits those fields

The dock grows horizontally as more providers are enabled — one circle
per provider. With a single provider, the dock shows one circle. Adding
Grok or Gemini (via their collectors) makes the row grow.

The **OpenClaw tab** additionally shows:

- Gateway state (`active` / `stopped` / `unknown`)
- Runtime line (Node version, PID, uptime)
- Discord status (active / not running)
- Total sessions (lifetime)
- MiniMax token plan: 5h + weekly bars, percent left, reset countdown

When the gateway is offline, OpenClaw's dock circle still shows, but the
popup collapses to three lines: `○ Gateway offline`, `Runtime: offline`,
`Discord: offline`. The MiniMax block, version, model, and sessions
lines are hidden until the gateway comes back.

## Dock color toggle

Double-click anywhere on the dock row toggles the ring colors between
**brand-colored** (the default) and **dim grey** (`#666`). This is useful
on light backgrounds or when you want a cleaner look.

The toggle is per-state, not persisted — it resets to colored on bar
reload.

## How providers are discovered

`Main.qml` scans `~/.local/state/omarchy/agents/usage/*.json` every minute
(via `omarchy-agent-usage-update`). Whatever JSON files exist = the set
of providers that show up. No config required to add a provider — just
drop a collector that writes the right JSON shape.

`providerHasData()` then filters out records with no usable data
(`ready: false` AND no daily/limit fields). This is why Grok and Gemini
**don't show in the dock when their API keys aren't set** — they write a
minimal "no key" record that gets filtered. Once you set the env var and
the collector re-runs, the provider appears.

## Collector schema

All collectors (`omarchy-agent-usage-<provider>`) write one JSON file to
`~/.local/state/omarchy/agents/usage/<id>.json`. The expected schema is
documented in `manifest.json` (the integration root) under
`entryPoints.<provider>.outputSchema`.

Required fields:

```json
{
  "id": "openclaw",            // matches filename basename, drives providerId
  "name": "OpenClaw",          // display name in popup
  "ready": true,               // false → filtered out by providerHasData()
  "installed": true,           // false → also filtered
  "schemaVersion": 1,
  "version": "...",            // optional, shown in popup
  "activeModel": "...",        // shown in popup
  "recentDays": [...],         // drives today/weekly meters
  "limits": [...],             // drives the Limits section in popup
  "modelUsage": {},            // drives the Tokens-by-model section
  "balance": null,             // prepaid balance display (optional)
  "provider": "xai"            // tag for the panel's source attribution
}
```

For OpenClaw specifically, additional fields are read by the panel's
OpenClaw-specific block (gateway state, runtime, Discord status, total
sessions, MiniMax token plan). See `manifest.json` for the full list.

## Provider list (this version)

| ID | Brand color | SVG asset | Collector | API key env var |
|---|---|---|---|---|
| `claude` | `#D97757` | `claude.svg` | ships with Omarchy | (via `claude` CLI) |
| `codex` | `#10A37F` | `codex.svg` | ships with Omarchy | (via `codex` CLI) |
| `fireworks` | `#FF6B35` | `fireworks.svg` | ships with Omarchy | (via `fireworks` CLI) |
| `openclaw` | `#7C3AED` | `openclaw.svg` | **ships with this package** | (handled by `openclaw onboard`) |
| `grok` | `#8B8B8B` | `grok.svg` | **ships with this package** | `XAI_API_KEY` |
| `gemini` | `#4285F4` | `gemini.svg` | **ships with this package** | `GEMINI_API_KEY` or `GOOGLE_API_KEY` |

The first three (claude/codex/fireworks) are managed by Omarchy itself —
this package doesn't replace them, just ships alongside. The last three
(openclaw/grok/gemini) are bundled in `bin/`. Grok and Gemini are
**opt-in** — they're available in the package but the user chooses to
install them by setting the corresponding API key in their environment.

## Manifest defaults

`targets/manifest.json` overrides Omarchy's `manifest.json` defaults to
enable all six providers out of the box:

```json
"defaults": {
  "providers": {
    "claude":    {"enabled": true},
    "codex":     {"enabled": true},
    "fireworks": {"enabled": true},
    "grok":      {"enabled": true},
    "gemini":    {"enabled": true},
    "openclaw":  {"enabled": true}
  },
  "refreshIntervalSec": 60
}
```

This is so a fresh install shows all dock circles immediately — but the
display is still gated by `providerHasData()`, so providers without
configured CLIs / API keys still stay hidden until they're set up.

`refreshIntervalSec: 60` (down from Omarchy default of 900) means the
panel updates every minute instead of every 15 minutes. Override in
`~/.config/omarchy/shell.json` if you need a different interval.

## Refresh model

| Refresh target | Cadence | Mechanism |
|---|---|---|
| Panel popup counters ("Resets in 2h") | every 30s | QML Timer, only when popup is open |
| Collector data (rate limits, usage) | every 60s | `Main.qml` Timer → `omarchy-agent-usage-update` |
| Dock progress ring fill | every 30s | QML Timer in `dock.requestPaint()` |
| Bar icon activity state | reactive | `alarming: root.alarming` re-binds on demand |

The 60s collector cadence applies to **all** collectors through the
single `omarchy-agent-usage-update` dispatcher. There is no per-provider
stagger.

## Files this package touches

`install.sh` copies these into the system:

| Source | Destination |
|---|---|
| `bin/omarchy-agent-usage-openclaw` | `/usr/bin/` |
| `bin/omarchy-agent-usage-grok` | `/usr/bin/` |
| `bin/omarchy-agent-usage-gemini` | `/usr/bin/` |
| `assets/claude.svg` … `openclaw-light.svg` | `/usr/share/omarchy/shell/plugins/agents/assets/` |
| `targets/Panel.qml` | `/usr/share/omarchy/shell/plugins/agents/Panel.qml` |
| `targets/Main.qml` | `/usr/share/omarchy/shell/plugins/agents/Main.qml` |
| `targets/manifest.json` | `/usr/share/omarchy/shell/plugins/agents/manifest.json` |

Backups of the Omarchy originals land next to each as `.openclaw-backup`
so `uninstall.sh` can restore them.

## See also

- `architecture.md` — how the package fits together at a higher level
- `telemetry.md` — what data flows where (specifically what each collector
  reads and writes)
- `troubleshooting.md` — common panel-side issues
