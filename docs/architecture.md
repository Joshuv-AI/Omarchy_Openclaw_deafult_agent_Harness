# Architecture

## What this is

A drop-in Omarchy extension that integrates the OpenClaw agent into
Omarchy's native agents panel, plus two optional collectors (Grok, Gemini)
that extend the same panel with xAI and Google AI providers. After
`./install.sh`:

- The dock shows one circle per connected provider, each with a
  brand-colored progress ring around a greied-out center icon
- The popup shows live status, rate limits, and usage for the selected
  provider
- OpenClaw specifically gets a dedicated block (gateway state, runtime,
  Discord, MiniMax token plan) on top of the standard provider display
- A lobster OpenClaw entry appears in the super-space menu under
  **agents**

The collectors shipped here (`openclaw`, `grok`, `gemini`) are
**opt-in**: `openclaw` is the centerpiece, `grok` and `gemini` activate
only when the corresponding API key env var is set.

## Components

```
openclaw-integration/
├── manifest.json              Plugin metadata (entry points, security boundaries, per-provider outputSchema)
├── README.md                   Quick start + verify + uninstall + extending
├── LICENSE                     AGPL-3.0
├── install.sh                  Idempotent installer
├── uninstall.sh                Reversible uninstaller (restores backups)
├── bin/
│   ├── omarchy-agent-usage-openclaw
│   │                          Collector for the OpenClaw provider
│   ├── omarchy-agent-usage-grok
│   │                          Collector for xAI Grok (requires XAI_API_KEY)
│   ├── omarchy-agent-usage-gemini
│   │                          Collector for Google Gemini (requires GEMINI_API_KEY)
│   └── omarchy-agent-usage-hermes
│                              Collector for Nous Hermes (requires install.sh + setup --portal)
│   ├── omarchy-agent-usage-minimax
│   │                          Collector for MiniMax token plan (auto-active when OpenClaw is using minimax/* models)
│   ├── omarchy-agent-usage-kimi
│   │                          Collector for Kimi (Moonshot AI) — two-stage probe: /v1/users/me for token-usage, /v1/models for connection fallback
│   ├── omarchy-set-kimi-key
│   │                          Shell-only key-update wrapper for users who want to set MOONSHOT_API_KEY from a script (no panel surface — panel does NOT prompt)
│   ├── omarchy-agent-usage-qwen
│   │                          Collector for Qwen (Alibaba DashScope) — single Bearer-auth /models probe; auto-detects DASHSCOPE_API_KEY + QWEN_BASE_URL from 5 locations
│   └── (no Qwen setup wrapper — display-only policy)
├── assets/
│   ├── claude.svg              Anthropic brand mark (greyed for dock center)
│   ├── codex.svg               OpenAI brand mark (greyed for dock center)
│   ├── codex-light.svg         Light-theme variant (greyed)
│   ├── fireworks.svg           Fireworks brand mark (greyed)
│   ├── grok.svg                xAI Grok stylized X (greyed)
│   ├── gemini.svg              Google Gemini interlocking diamond (greyed)
│   ├── openclaw.svg            Lobster emoji with grayscale filter
│   └── openclaw-light.svg      Same, light-theme variant
├── targets/
│   ├── Panel.qml               Omarchy stock + multi-provider dock + OpenClaw display block
│   ├── Main.qml                Omarchy stock + displayProvider() forwards
│   └── manifest.json           Agent panel manifest with 6 enabled providers + 60s refresh default
├── docs/
│   ├── architecture.md         This file
│   ├── security.md             Threat model + explicit non-goals
│   ├── telemetry.md            Data flow + cache contract
│   ├── panel.md                Panel UX, refresh model, dock design, color toggle
│   └── troubleshooting.md      Common issues + fixes
└── skill/
```

## Provider model

The Omarchy agents panel auto-discovers any JSON file under
`~/.local/state/omarchy/agents/usage/*.json`. Each collector writes one
file. The set of files = the set of providers that appear in the dock
(after `providerHasData()` filtering in `Main.qml`).

This package ships three collectors. Omarchy's base install already
ships three more (claude/codex/fireworks) — those continue to work
unchanged. Total up to six providers:

| Provider | Origin | Activation |
|---|---|---|
| claude, codex, fireworks | Omarchy base | CLI tools installed + authenticated |
| openclaw | this package | `openclaw onboard` |
| hermes | this package | `curl .../install.sh | bash` + `hermes setup --portal` |
| grok | this package | `XAI_API_KEY` env var |
| gemini | this package | `GEMINI_API_KEY` or `GOOGLE_API_KEY` env var |
| minimax | this package | `MINIMAX_API_KEY` in `~/.openclaw/.env` (shared with OpenClaw) |

`targets/manifest.json` enables all six by default in the panel's
`defaults.providers`. The dock only shows a provider once its
collector has written usable data — so providers without configured
CLIs / API keys stay hidden until set up.

## Multi-auth coverage per provider

Each provider exposes a **single ring** in the dock, even when it has
multiple auth surfaces or endpoint environments. Collectors write one
JSON file per provider to `~/.local/state/omarchy/agents/usage/`;
`providerHasData()` filters at the panel level, so additional auth
paths share the same ring rather than spawning extra circles.

| Provider | Auth paths covered | Endpoints covered |
| --- | --- | --- |
| OpenClaw | local daemon + various auth profiles | n/a (connection-based) |
| Grok | OAuth (SuperGrok / X Premium) + API key | xAI |
| Gemini | API key (`GEMINI_API_KEY` / `GOOGLE_API_KEY`) | Google |
| **MiniMax** | **API key + OAuth portal token** | **international + China fallback** |
| **Kimi** | **Moonshot API key + Kimi Coding** | **international, balance ≤0 USD = empty ring** |
| **Qwen** | **Qwen Cloud + Qwen Portal OAuth + Alibaba** | **international + China fallback** |

### Collector behavior notes

- **MiniMax** reads `MINIMAX_API_KEY`, `MINIMAX_PORTAL_TOKEN`, and
  `MINIMAX_PORTAL_API_KEY` in priority order. When the international
  endpoint returns 401 / 403, the collector transparently retries
  against the China endpoint before declaring the ring empty.
- **Kimi** parses `available_balance` from `/v1/users/me/balance` and
  flips the ring to its empty state when the value is ≤ 0 USD — this
  distinguishes "no key configured" from "key present but credit
  exhausted".
- **Qwen** triggers its ring when model refs in the request stream
  carry `qwen-oauth/` or `alibaba/` prefixes, covering portal-OAuth
  and Alibaba-routed traffic in addition to direct Qwen Cloud keys.

## Dock design

The dock icon area is a horizontal row of circles, one per provider:

```
   ┌──┐  ┌──┐  ┌──┐
   │  │  │  │  │  │   <- provider icon (greied)
   │  │  │  │  │  │
   └──┘  └──┘  └──┘
   ╲╱╲   ╲╱╲   ╲╱╲  <- progress ring (brand color)
```

The ring fill shows the most-urgent rate-limit usage. Double-clicking
anywhere on the row toggles all rings to dim grey `#666`. Single
click on a circle opens the panel focused on that provider. Right-click
launches the agent in a terminal (OpenClaw only — other providers
don't have a CLI launcher). Middle-click cycles through providers.

## Data flow (per minute)

```
1. QML Timer in Main.qml fires every 60s
2. Spawns omarchy-agent-usage-update
3. That dispatcher iterates bin/omarchy-agent-usage-* scripts
4. Each collector queries its source (OpenClaw local files; xAI HTTP;
   Google HTTP)
5. Each writes a JSON record to ~/.local/state/omarchy/agents/usage/<id>.json
6. Main.qml detects the file change → updates agents[] → enabledProviders
7. Panel.qml's Repeater rebuilds the dock row
8. dock.requestPaint() redraws the rings every 30s
```

Per-collector schemas are documented in `manifest.json`'s
`entryPoints.<provider>.outputSchema`.

## Boundaries

This package does **not**:

- Replace Omarchy's core shell, bar, or panel code outside the agents
  plugin
- Bundle or install the Claude/Codex/Fireworks CLIs (Omarchy ships
  those)
- Modify anything outside `/usr/bin/omarchy-agent-usage-*`,
  `/usr/share/omarchy/shell/plugins/agents/`, and the user's
  `~/.config/omarchy/`
- Make outbound network calls itself (only the grok/gemini collectors
  do, and only when their API keys are set)
