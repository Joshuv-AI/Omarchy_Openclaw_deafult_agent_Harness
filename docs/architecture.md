# Architecture

## What this is

A drop-in Omarchy integration that puts a **modified agent dock icon** in the Omarchy bar — a horizontal row of brand-colored progress rings, one per connected provider. Each ring's behavior depends on the provider type:

- **OpenClaw + Hermes rings** → **gateway-activity rings** (unique to these two agents). Ring fills when the agent's gateway is `active`; empty means the gateway is stopped.
- **Sub-provider rings** (MiniMax, Kimi, Qwen, future DeepSeek) → **usage rings**. Ring fills with token-usage percent or connection-mode signal.
- **Optional Grok / Gemini rings** → **connection rings**. Ring fills when the API key is accepted by the provider.

This is the centerpiece of the integration: a single glance at the dock row tells you whether each agent's gateway is up and whether the models behind it are healthy.

After `./install.sh`:

- The dock shows one circle per connected provider, each with a brand-colored progress ring around a greyed-out center icon
- The popup shows live status for the selected provider (gateway + runtime for OpenClaw/Hermes; token plan for sub-providers)
- OpenClaw gets a dedicated block (gateway state, runtime, Discord, MiniMax token plan) on top of the standard provider display
- Hermes gets a dedicated block (Hermes CLI status, gateway uptime) with the same treatment
- Lobster (OpenClaw) + wing (Hermes) entries appear in the super-space **agents** menu

The collectors shipped here are all **opt-in**: `openclaw` and `hermes` are the centerpiece (always active once installed); `grok` and `gemini` activate only when the corresponding API key env var is set; `minimax`, `kimi`, `qwen` activate when their parent agent (OpenClaw or Hermes) is using their model.

## Components

```
omarchy-agent-panel-repo/
├── manifest.json              Plugin metadata (entry points, security boundaries, per-provider outputSchema)
├── README.md                   Quick start + verify + uninstall + extending
├── LICENSE                     AGPL-3.0
├── install.sh                  Idempotent installer (handles OpenClaw + Hermes setup)
├── uninstall.sh                Reversible uninstaller (restores Omarchy backups)
├── bin/
│   ├── omarchy-agent-usage-openclaw
│   │                          Collector for OpenClaw: gateway state, runtime, Discord, sessions, MiniMax token plan
│   ├── omarchy-agent-usage-hermes
│   │                          Collector for Hermes: CLI status, gateway state, PID, uptime
│   ├── omarchy-agent-usage-minimax
│   │                          Collector for MiniMax token plan (auto-active when OpenClaw/Hermes uses minimax/* models)
│   ├── omarchy-agent-usage-kimi
│   │                          Collector for Kimi (Moonshot AI) — two-stage probe: /v1/users/me for token-usage, /v1/models for connection fallback
│   ├── omarchy-agent-usage-qwen
│   │                          Collector for Qwen (Alibaba DashScope) — single Bearer-auth /models probe; auto-detects DASHSCOPE_API_KEY + QWEN_BASE_URL from 5 locations
│   ├── omarchy-agent-usage-grok
│   │                          Collector (opt-in) for xAI Grok — requires XAI_API_KEY
│   ├── omarchy-agent-usage-gemini
│   │                          Collector (opt-in) for Google Gemini — requires GEMINI_API_KEY or GOOGLE_API_KEY
│   └── omarchy-set-kimi-key   Shell-only key-update wrapper for users who want to set MOONSHOT_API_KEY from a script (no panel surface — panel does NOT prompt)
├── assets/
│   ├── openclaw.svg            Lobster emoji with grayscale filter (OpenClaw dock center)
│   ├── openclaw-light.svg      Same, light-theme variant
│   ├── hermes.svg              Wing icon — Nous Hermes messenger symbol (Hermes dock center)
│   ├── minimax.svg             MiniMax brand mark (red `#FF0000`)
│   ├── kimi.svg, qwen.svg      Sub-provider brand marks
│   ├── grok.svg, gemini.svg, claude.svg, codex.svg, codex-light.svg, fireworks.svg, omp.svg, opencode.svg, pi.svg, copilot.svg, crush.svg  Other provider icons
├── targets/
│   ├── Panel.qml               Omarchy stock + dock row + OpenClaw gateway block + Hermes gateway block + MiniMax usage block
│   ├── Main.qml                Omarchy stock + displayProvider() forwards for OpenClaw and Hermes
│   └── manifest.json           Agent panel manifest with 6 enabled providers + 60s refresh default
├── docs/
│   ├── architecture.md         This file
│   ├── panel.md                Dock design, gateway ring details, click behaviors, refresh model
│   ├── security.md             Threat model + explicit non-goals
│   ├── telemetry.md            Data flow + cache contract
│   └── troubleshooting.md      Common issues + fixes
└── skill/
    └── SKILL.md                AI-agent maintenance guide (OpenClaw + Hermes)
```

## The modified agent dock icon

The dock row is the primary user-facing surface. It replaces Omarchy's default single-icon agent entry with **a horizontal row of colored rings**:

```
   ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
   │  │  │  │  │  │  │  │  │  │   <- provider icon (greyed center)
   │  │  │  │  │  │  │  │  │  │
   └──┘  └──┘  └──┘  └──┘  └──┘
   ╲╱╲   ╲╱╲   ╲╱╲   ╲╱╲   ╲╱╲  <- progress ring (brand color)
```

**Ring behavior differs by provider type** — this is the key design decision:

| Ring type | Providers | Fill meaning |
|---|---|---|
| **Gateway ring** | **OpenClaw, Hermes** | Full = `gatewayState: "active"`. Empty = stopped / not running. **Unique to OpenClaw + Hermes.** |
| **Usage ring** | MiniMax, Kimi, Qwen | Numeric percent of token plan / connection-mode fallback |
| **Connection ring** | Grok, Gemini | Full = API key accepted by provider |

The ring fill is computed by `providerIntervalFraction()` in `Panel.qml`, which dispatches on provider ID:
- For OpenClaw and Hermes, returns 1.0 when gateway is active, 0 otherwise (gateway-ring path)
- For MiniMax, uses `1 - minimaxTokenPlan.general.intervalRemainingPct / 100` (used-percent of 5h window)
- For Kimi, dispatches on `kimiUsageMode` (token-usage numeric vs connection fallback)
- For Qwen, returns 1.0 on successful `/models` probe, 0 otherwise
- For Grok/Gemini, returns 1.0 on successful auth probe

Double-clicking anywhere on the dock row toggles all rings between **brand-colored** (default) and **dim grey** (`#666`). The toggle is per-state, not persisted.

Single click on a circle opens the panel focused on that provider. Right-click launches the agent in a terminal (OpenClaw + Hermes — these are the agents with CLI launchers; sub-providers don't have launchers). Middle-click cycles through providers.

## Provider model

The Omarchy agents panel auto-discovers any JSON file under `~/.local/state/omarchy/agents/usage/*.json`. Each collector writes one file. The set of files = the set of providers that appear in the dock (after `providerHasData()` filtering in `Main.qml`).

This package ships **two centerpiece agents** (OpenClaw + Hermes) and **three sub-providers** (MiniMax + Kimi + Qwen), plus two opt-in collectors (Grok + Gemini). Omarchy's base install ships claude/codex/fireworks — those continue to work unchanged.

| Provider | Origin | Activation |
|---|---|---|
| claude, codex, fireworks | Omarchy base | CLI tools installed + authenticated |
| **openclaw** | **this package** | **`openclaw onboard`** |
| **hermes** | **this package** | **`curl .../install.sh \| bash` + `hermes setup --portal`** |
| minimax | this package | `MINIMAX_API_KEY` in `~/.openclaw/.env` (shared with OpenClaw + Hermes) |
| kimi | this package | Auto-appears when OpenClaw or Hermes uses kimi/* or moonshot/* model |
| qwen | this package | Auto-appears when OpenClaw or Hermes uses qwen/* or dashscope/* model |
| grok | this package | `XAI_API_KEY` env var |
| gemini | this package | `GEMINI_API_KEY` or `GOOGLE_API_KEY` env var |

`targets/manifest.json` enables all six centerpiece providers (openclaw, hermes, minimax, kimi, qwen, grok, gemini, plus omarchy's claude/codex/fireworks) by default. The dock only shows a provider once its collector has written usable data — so providers without configured CLIs / API keys stay hidden until set up.

## Multi-auth coverage per provider

Each provider exposes a **single ring** in the dock, even when it has multiple auth surfaces or endpoint environments. Collectors write one JSON file per provider to `~/.local/state/omarchy/agents/usage/`; `providerHasData()` filters at the panel level, so additional auth paths share the same ring rather than spawning extra circles.

| Provider | Auth paths covered | Endpoints covered | Ring type |
|---|---|---|---|
| **OpenClaw** | local daemon + various auth profiles | n/a (connection-based) | **Gateway ring** |
| **Hermes** | OAuth portal + Nous Tool Gateway | n/a (connection-based) | **Gateway ring** |
| Grok | OAuth (SuperGrok / X Premium) + API key | xAI | Connection ring |
| Gemini | API key (`GEMINI_API_KEY` / `GOOGLE_API_KEY`) | Google | Connection ring |
| MiniMax | API key + OAuth portal token | international + China fallback | Usage ring |
| Kimi | Moonshot API key + Kimi Coding | international, balance ≤0 USD = empty ring | Usage ring |
| Qwen | Qwen Cloud + Qwen Portal OAuth + Alibaba | international + China fallback | Usage ring |

### Collector behavior notes

- **OpenClaw** reads `~/.openclaw/crestodian/sessions/*.trajectory.jsonl` for sessions, `systemctl --user is-active openclaw-gateway.service` for gateway state, `pgrep -f openclaw` and `pgrep -f discord` for PID/Discord presence. Never reads API key values.
- **Hermes** reads `command -v hermes`, `hermes --version`, `hermes status`, and `pgrep -f hermes`. Deliberately writes **no `recentDays`, no `limits`, no `modelUsage`** — Hermes has no token-usage tracking; the ring is purely a gateway-activity signal.
- **MiniMax** reads `MINIMAX_API_KEY`, `MINIMAX_PORTAL_TOKEN`, and `MINIMAX_PORTAL_API_KEY` in priority order. When the international endpoint returns 401 / 403, the collector transparently retries against the China endpoint before declaring the ring empty.
- **Kimi** parses `available_balance` from `/v1/users/me/balance` and flips the ring to its empty state when the value is ≤ 0 USD — this distinguishes "no key configured" from "key present but credit exhausted".
- **Qwen** triggers its ring when model refs in the request stream carry `qwen-oauth/` or `alibaba/` prefixes, covering portal-OAuth and Alibaba-routed traffic in addition to direct Qwen Cloud keys.

## Data flow (per minute)

```
1. QML Timer in Main.qml fires every 60s
2. Spawns omarchy-agent-usage-update
3. That dispatcher iterates bin/omarchy-agent-usage-* scripts
4. Each collector queries its source:
   - OpenClaw: local files (~/.openclaw/...), systemd status, /proc
   - Hermes: hermes CLI binary
   - MiniMax/Kimi/Qwen/Grok/Gemini: HTTP endpoints when key is set
5. Each writes a JSON record to ~/.local/state/omarchy/agents/usage/<id>.json
6. Main.qml detects the file change → updates agents[] → enabledProviders
7. Panel.qml's Repeater rebuilds the dock row
8. dock.requestPaint() redraws the rings every 30s
```

Per-collector schemas are documented in `manifest.json`'s
`entryPoints.<provider>.outputSchema`.

## Boundaries

This package does **not**:

- Replace Omarchy's core shell, bar, or panel code outside the agents plugin
- Bundle or install the Claude/Codex/Fireworks CLIs (Omarchy ships those)
- Modify anything outside `/usr/bin/omarchy-agent-usage-*`,
  `/usr/share/omarchy/shell/plugins/agents/`, and the user's
  `~/.config/omarchy/`
- Make outbound network calls itself (only the minimax/kimi/qwen/grok/gemini collectors do, and only when their API keys are set)
- Launch or stop the OpenClaw or Hermes gateway (display-only — shows state, doesn't change it)

The OpenClaw and Hermes rings display gateway state but never invoke `systemctl start/stop/restart` on either gateway. Users control their own agents via `omarchy start` / `hermes gateway` from their own shell.