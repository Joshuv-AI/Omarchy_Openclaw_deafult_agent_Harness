# Panel

The agents panel (`omarchy.agents` in the Omarchy bar) is the user-facing surface for this integration. This document covers what the panel does, how it's wired, and the parts that change with this version of the OpenClaw + Hermes harness.

## The modified agent dock icon — the centerpiece

The primary user-facing element is the **dock row of colored rings** at the top-right of the Omarchy bar. One ring per provider, brand-colored, showing either gateway activity (OpenClaw, Hermes) or token usage / connection state (sub-providers, Grok, Gemini).

```
   ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
   │  │  │  │  │  │  │  │  │  │   <- provider icon (greyed center)
   │  │  │  │  │  │  │  │  │  │
   └──┘  └──┘  └──┘  └──┘  └──┘
   ╲╱╲   ╲╱╲   ╲╱╲   ╲╱╲   ╲╱╲  <- progress ring (brand color)
```

The ring fill amount + color differ by provider type:

| Ring type | Providers | Fill meaning | Color |
|---|---|---|---|
| **Gateway ring** | **OpenClaw, Hermes** | Full = gateway active. Empty = gateway stopped. | OpenClaw: purple `#7C3AED`. Hermes: gold `#D4AF37`. |
| **Usage ring** | MiniMax, Kimi, Qwen | Numeric percent of token plan / connection-mode fallback | MiniMax: red `#FF0000`. Kimi: orange. Qwen: purple `#8B5CF6`. |
| **Connection ring** | Grok, Gemini | Full = API key accepted. Empty = key missing or rejected. | Grok: grey `#8B8B8B`. Gemini: blue `#4285F4`. |

**The gateway ring is the unique feature** of this dock — OpenClaw and Hermes are the only entries that report whether the agent's long-running gateway process is up or down. Every other icon in your bar is either a system indicator (Bluetooth, Wi-Fi, etc.) or a usage/connection ring for sub-providers.

## What the panel shows — by provider type

### Two kinds of entries

**Agents** (OpenClaw, Hermes) — full model clients. Always appear in the dock and in the default agent selector menu. Each agent gets:
- A dock ring in the bar with the agent's brand-colored progress ring around a greyed-out center icon
- A tab in the panel popup with live data — but **gateway data**, not usage data (gateway state, runtime, model, sessions)
- A `today` meter when the collector emits those fields

**Sub-providers** (MiniMax, Kimi, Qwen, future DeepSeek) — model backends. Appear in the dock ONLY when their parent agent (OpenClaw or Hermes) is active AND that agent's `activeModel` identifies the sub-provider. Never appear in the default agent selector menu. Each sub-provider gets:
- A dock ring in the bar with the sub-provider's brand color ring
- A usage/availability ring that reflects the sub-provider's data mode (token-usage numeric, connection fallback, or empty when unconfigured)

The dock is the concatenation of `usage.enabledProviders` (OpenClaw, Hermes, Grok, Gemini) and `usage.subProviders` (MiniMax, Kimi, Qwen). The dock grows horizontally as either type grows. With OpenClaw + Hermes installed and no sub-providers active, the dock shows two rings. Adding Kimi as a model choice in OpenClaw/Hermes makes the Kimi sub-provider ring appear next to its parent.

### What shows when you click the OpenClaw ring

The OpenClaw tab additionally shows:

- **Gateway state** (`active` / `stopped` / `unknown`) — colored dot indicator
- **Version** (OpenClaw build string, e.g. `OpenClaw 2026.7.1-2 (0790d9f)`)
- **Active model** (e.g. `minimax/MiniMax-M3`)
- **Runtime line**: Node version, PID, uptime
- **Discord status** (active / not running)
- **Total sessions** (lifetime)
- **MiniMax token plan** (5h + weekly bars, percent left, reset countdown) — only if OpenClaw is using a minimax/* model

When the gateway is offline, OpenClaw's dock ring still shows, but the popup collapses to three lines: `○ Gateway offline`, `Runtime: offline`, `Discord: offline`. The MiniMax block, version, model, and sessions lines are hidden until the gateway comes back.

### What shows when you click the Hermes ring

The Hermes tab shows:

- **Hermes version** (from `hermes --version`)
- **Hermes CLI status** — agent, auth, platform, gateway state
- **Gateway uptime** (from `ps -o etime= -p <pid>`)
- **Hermes process PID**

Hermes has **no token usage tracking** — no rate limits, no API quotas. Its dock ring is therefore a **connection ring, not a usage ring**:

- Gateway active (`gatewayState: "active"`) → ring fully filled (gold `#D4AF37`)
- Gateway stopped (`gatewayState: "stopped"`) → ring empty
- Hermes not installed → panel filters it out via `providerHasData()`

The collector writes no `intervalRemainingPct`, so `providerIntervalFraction()` falls through to the connection-state fallback in `Panel.qml`. Other providers with token data are unaffected.

### What shows when you click sub-provider rings

Sub-provider tabs (MiniMax, Kimi, Qwen) show token-usage data in the panel's standard provider block: token-usage bars, daily usage, model breakdown, limits. They don't show gateway state — that's only for OpenClaw and Hermes.

### What shows when you click Grok / Gemini rings

Standard provider blocks (rate limits, models, daily usage). These are connection rings — full = API key accepted, empty = key missing or rejected.

## Click behaviors on the dock rings

The mouse cursor switches to a pointing hand on hover (set via `cursorShape: Qt.PointingHandCursor` and `hoverEnabled: true` on the dock row MouseArea). Click behaviors:

| Click | Effect |
|---|---|
| **Left click** on a ring | Select that provider and toggle the panel popup open/closed |
| **Right click** on OpenClaw or Hermes ring | Launch that agent in a terminal (uses the agent's CLI launcher) |
| **Right click** on sub-provider ring | No launcher (no-op — sub-providers don't have CLI binaries) |
| **Middle click** | Cycle to the next provider in the dock row |
| **Double click anywhere** on the dock row | Toggle all rings between brand colors and dim grey `#666` (per-state, not persisted) |

When the gateway is offline (OpenClaw or Hermes ring empty), clicking the ring still opens the popup — you can see the `○ Gateway offline` status line.

## Display-only policy

**Universal rule (Josh 2026-08-31 9:51 PM EDT):** The agents panel is strictly a **display-only** surface for every provider it shows. It does not configure, troubleshoot, suggest fixes for, or otherwise intervene in any provider's setup.

**What this means concretely:**
- If a provider is detected (icon appears in dock), we pull whatever data is available and display it
- If the data pull fails (no key, bad key, expired plan, network down, agent offline), the ring is empty and we stop
- The user is responsible for fixing their own setup if anything is wrong

**Applies to all providers** — OpenClaw, Hermes, Grok, Gemini, MiniMax, Kimi, Qwen, and any future sub-provider added. No exceptions.

The display-only rule applies even when the user has the diagnostic info at hand — the panel is for seeing status, not for acting on it. The user clicks `omarchy start` or `hermes gateway` from their own shell; the panel never invokes those commands.

## Dock color toggle

Double-click anywhere on the dock row toggles the ring colors between **brand-colored** (the default) and **dim grey** (`#666`). This is useful on light backgrounds or when you want a cleaner look.

The toggle is per-state, not persisted — it resets to colored on bar reload.

## How providers are discovered

`Main.qml` scans `~/.local/state/omarchy/agents/usage/*.json` every minute (via `omarchy-agent-usage-update`). Whatever JSON files exist = the set of providers that show up. No config required to add a provider — just drop a collector that writes the right JSON shape.

`providerHasData()` then filters out records with no usable data (`ready: false` AND no daily/limit fields). This is why Grok and Gemini **don't show in the dock when their API keys aren't set** — they write a minimal "no key" record that gets filtered. Once you set the env var and the collector re-runs, the provider appears. The same applies to OpenClaw and Hermes when their gateways are down — but in their case, the ring still shows (with empty fill), just the popup content changes to the offline state.

## Collector schema

All collectors (`omarchy-agent-usage-<provider>`) write one JSON file to `~/.local/state/omarchy/agents/usage/<id>.json`. The expected schema is documented in `manifest.json` (the integration root) under `entryPoints.<provider>.outputSchema`.

**Common fields** (all providers):

```json
{
  "id": "openclaw",            // matches filename basename, drives providerId
  "name": "OpenClaw",          // display name in popup
  "ready": true,               // false → filtered out by providerHasData()
  "installed": true,           // false → also filtered
  "schemaVersion": 1,
  "version": "...",            // optional, shown in popup
  "activeModel": "...",        // shown in popup
  "recentDays": [...],         // drives today/weekly meters (some agents)
  "limits": [...],             // drives the Limits section in popup
  "modelUsage": {},            // drives the Tokens-by-model section
  "balance": null,             // prepaid balance display (optional)
  "provider": "xai"            // tag for the panel's source attribution
}
```

**OpenClaw-specific fields** (gateway block): `gatewayState`, `nodeVersion`, `openclawPid`, `openclawUptime`, `discordStatus`, `totalSessions`, `minimaxTokenPlan`. See `manifest.json` for the full schema.

**Hermes-specific fields** (gateway block): `version`, `agent`, `auth`, `platform`, `gatewayState`, `hermesUptime`, `hermesPid`. Hermes writes no `recentDays`, `limits`, or `modelUsage` — by design, since Hermes has no token-usage tracking.

## Provider list (this version)

| ID | Brand color | SVG asset | Collector | Ring type | API key env var |
|---|---|---|---|---|---|
| `claude` | `#D97757` | `claude.svg` | ships with Omarchy | usage | (via `claude` CLI) |
| `codex` | `#10A37F` | `codex.svg` | ships with Omarchy | usage | (via `codex` CLI) |
| `fireworks` | `#FF6B35` | `fireworks.svg` | ships with Omarchy | usage | (via `fireworks` CLI) |
| **`openclaw`** | **`#7C3AED`** | `openclaw.svg` | **ships with this package** | **gateway** | (handled by `openclaw onboard`) |
| **`hermes`** | **`#D4AF37`** | `hermes.svg` | **ships with this package** | **gateway** | (handled by `hermes setup --portal`) |
| `minimax` | `#FF0000` | `minimax.svg` | **ships with this package** | usage | `MINIMAX_API_KEY` in `~/.openclaw/.env` (auto-set by `openclaw onboard`) |
| `kimi` | orange | `kimi.svg` | **ships with this package** | usage | `MOONSHOT_API_KEY` (5-detect locations) |
| `qwen` | `#8B5CF6` | `qwen.svg` | **ships with this package** | usage | `DASHSCOPE_API_KEY` (5-detect locations) |
| `grok` | `#8B8B8B` | `grok.svg` | **ships with this package** | connection | `XAI_API_KEY` |
| `gemini` | `#4285F4` | `gemini.svg` | **ships with this package** | connection | `GEMINI_API_KEY` or `GOOGLE_API_KEY` |

The first three (claude/codex/fireworks) are managed by Omarchy itself — this package doesn't replace them, just ships alongside. **OpenClaw and Hermes are the centerpiece agents** — their rings are gateway rings (unique to this integration). The rest (minimax/kimi/qwen/grok/gemini) are opt-in sub-providers or connection rings.

## Manifest defaults

`targets/manifest.json` overrides Omarchy's `manifest.json` defaults to enable all providers out of the box:

```json
"defaults": {
  "providers": {
    "claude":    {"enabled": true},
    "codex":     {"enabled": true},
    "fireworks": {"enabled": true},
    "openclaw":  {"enabled": true},
    "hermes":    {"enabled": true},
    "grok":      {"enabled": true},
    "gemini":    {"enabled": true}
  },
  "refreshIntervalSec": 60
}
```

This is so a fresh install shows the OpenClaw + Hermes rings immediately (assuming their collectors have run). Sub-provider rings appear automatically once the parent agent is using their model. The display is still gated by `providerHasData()`, so providers without configured CLIs / API keys stay hidden until they're set up.

`refreshIntervalSec: 60` (down from Omarchy default of 900) means the panel updates every minute instead of every 15 minutes. Override in `~/.config/omarchy/shell.json` if you need a different interval.

## Refresh model

| Refresh target | Cadence | Mechanism |
|---|---|---|
| Panel popup counters ("Resets in 2h") | every 30s | QML Timer, only when popup is open |
| Collector data (gateway state, usage) | every 60s | `Main.qml` Timer → `omarchy-agent-usage-update` |
| Dock progress ring fill | every 30s | QML Timer in `dock.requestPaint()` |
| Bar icon activity state | reactive | `alarming: root.alarming` re-binds on demand |

The 60s collector cadence applies to **all** collectors through the single `omarchy-agent-usage-update` dispatcher. There is no per-provider stagger.

## Files this package touches

`install.sh` copies these into the system:

| Source | Destination |
|---|---|
| `bin/omarchy-agent-usage-openclaw` | `/usr/bin/` |
| `bin/omarchy-agent-usage-hermes` | `/usr/bin/` |
| `bin/omarchy-agent-usage-minimax` | `/usr/bin/` |
| `bin/omarchy-agent-usage-kimi` | `/usr/bin/` |
| `bin/omarchy-agent-usage-qwen` | `/usr/bin/` |
| `bin/omarchy-agent-usage-grok` | `/usr/bin/` (installed; active when key set) |
| `bin/omarchy-agent-usage-gemini` | `/usr/bin/` (installed; active when key set) |
| `bin/` | `/usr/bin/` |
| `assets/openclaw.svg`, `assets/hermes.svg`, `assets/minimax.svg`, etc. | `/usr/share/omarchy/shell/plugins/agents/assets/` |
| `targets/Panel.qml` | `/usr/share/omarchy/shell/plugins/agents/Panel.qml` |
| `targets/Main.qml` | `/usr/share/omarchy/shell/plugins/agents/Main.qml` |
| `targets/manifest.json` | `/usr/share/omarchy/shell/plugins/agents/manifest.json` |

Backups of the Omarchy originals land next to each as `.openclaw-backup` so `uninstall.sh` can restore them.

## See also

- `architecture.md` — how the package fits together at a higher level
- `telemetry.md` — what data flows where (specifically what each collector reads and writes)
- `troubleshooting.md` — common panel-side issues