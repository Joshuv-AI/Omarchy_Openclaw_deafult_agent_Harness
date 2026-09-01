# Telemetry

This document describes the data each collector reads, writes, and
displays. The aim is transparency — a user should know exactly what their
machine is reporting to the panel.

## Data sources per collector

### `omarchy-agent-usage-openclaw` (always installed)

| Source | What it reads | Where it lives |
|---|---|---|
| `~/.openclaw/.env` | API key variable NAMES (presence only — never the values) | User's home |
| `~/.openclaw/crestodian/sessions/*.trajectory.jsonl` | Per-step OpenClaw trajectory entries (model usage, prompts, sessions) | User's home |

Note: OpenClaw's collector no longer queries MiniMax directly. Token-usage
data moved to `omarchy-agent-usage-minimax` so the model data lives with
the model, not the agent.
| `~/.openclaw/tui/last-session.json` | Most recently updated session ID | User's home |
| `systemctl --user is-active openclaw-gateway.service` | Active/inactive state | User systemd |
| `systemctl --user show openclaw-gateway.service --property=ActiveEnterTimestamp` | Gateway start time | User systemd |
| `openclaw --version` | Version string (first line only) | `$PATH` |
| `node --version` | Node version | `$PATH` |
| `pgrep -f openclaw` | OpenClaw PID | `/proc` |
| `pgrep -f discord` | Discord presence | `/proc` |

The collector never reads:
- API key VALUES (only presence — checks if `MINIMAX_API_KEY=` exists, not its value)
- Files outside the paths above
- Remote endpoints (OpenClaw's MiniMax data is fetched by OpenClaw itself
  via `~/.openclaw/.env` — this collector just reads the local cache)

### `omarchy-agent-usage-grok` (installed but no-op without key)

| Source | What it reads | Where it lives |
|---|---|---|
| `XAI_API_KEY` env var | API key value | Process environment |
| `GET https://api.x.ai/v1/api-key` | Per-model rate limits (rpm/rpd/tpm/tpd) | xAI network |

### `omarchy-agent-usage-minimax` (installed but no-op without key)

| Source | What it reads | Where it lives |
|---|---|---|
| `MINIMAX_API_KEY` env var | API key value | Process environment |
| `GET https://www.minimax.io/v1/token_plan/remains` | Per-model current interval + weekly remaining % + reset ms | MiniMax network |

When `MINIMAX_API_KEY` is unset, the collector writes a minimal record with
`ready: false`. When set, it parses `model_remains[]` and writes:
- `minimaxAvailable: true/false`
- `minimaxTokenPlan: { general: { intervalRemainingPct, weeklyRemainingPct, intervalResetMs, weeklyResetMs }, video: {...} }`
- `activeModel`, `version`, `gatewayState`, `discordState`

### `omarchy-agent-usage-kimi` (installed but invisible without Kimi activeModel)

| Source | What it reads | Where it lives |
|---|---|---|
| `MOONSHOT_API_KEY` env var | API key value | Process environment |
| `GET https://api.moonshot.ai/v1/users/me` | Bearer-auth identity (numeric usage fields if Moonshot returns them — currently undocumented) | Moonshot network |
| `GET https://api.moonshot.ai/v1/models` | Authenticated availability check (connection-mode fallback) | Moonshot network |
| `journalctl --user --since "5 min ago"` | Recent OpenClaw/Hermes logs — scans for `kimi|moonshot|MOONSHOT_API_KEY|api.moonshot.ai` patterns to flag API errors | User systemd journal |

**Two-stage probe logic:**

1. Try `/v1/users/me` with the bearer key:
   - 200 OK → record `kimiUsageMode: "token-usage"`, attempt to parse
     any numeric remaining fields from the response body (current
     implementation only sets `kimiAvailable: true`; numeric
     extraction will be added when Moonshot documents the schema)
   - 401/403 → key is missing or invalid; record
     `kimiAvailable: false`, set `authHelpText`
   - 404 / other error → connection-mode fallback (step 2)

2. If step 1 returned non-numeric or 404, fall back to `/v1/models`:
   - 200 OK → record `kimiUsageMode: "connection"`, full ring
   - 401/403 → same as step 1
   - other → record `kimiAvailable: false`, full error in
     `kimiError` field

3. Regardless of mode, set `kimiRingEmpty: true` if recent logs
   mention any Kimi/Moonshot API errors within the last 5 min.
   Numeric token-usage data overrides log-based empty ring if
   both are present.

Output: `~/.local/state/omarchy/agents/usage/kimi.json` with fields:
`id`, `name`, `schemaVersion`, `provider`, `ready`, `installed`,
`version`, `activeModel`, `kimiAvailable`, `kimiUsageMode`,
`kimiRingEmpty`, `kimiAccountInfo`, `kimiFetchedAt`, `authHelpText`.

The Kimi icon never appears in the dock unless OpenClaw or Hermes
is currently using `kimi/*` or `moonshot/*` — see `architecture.md`
"Sub-providers" section and `Main.qml` `subProviders` property.

When `MOONSHOT_API_KEY` is unset, the collector writes a minimal record with
`authHelpText` pointing to https://console.x.ai so the panel can
display a setup hint.

### `omarchy-agent-usage-gemini` (installed but no-op without key)

| Source | What it reads | Where it lives |
|---|---|---|
| `GEMINI_API_KEY` / `GOOGLE_API_KEY` env var | API key value | Process environment |
| `GET https://generativelanguage.googleapis.com/v1beta/models?key=***` | Available model list + rate-limit response headers | Google network |

When neither key is set, the collector writes a minimal record with
`authHelpText` pointing to https://aistudio.google.com/apikey.


### `omarchy-agent-usage-hermes` (installed but no-op without setup)

| Source | What it reads | Where it lives |
|---|---|---|
| `command -v hermes` | Hermes binary path | `$PATH` |
| `hermes --version` | Version string | Hermes CLI |
| `hermes status` | Agent, auth, platform, gateway state | Hermes CLI |
| `pgrep -f hermes` | Hermes process PID (fallback) | `/proc` |
| `ps -o etime= -p <pid>` | Gateway process uptime | `/proc` |

The collector deliberately writes **no `recentDays`, no `limits`, no `modelUsage`** —
Hermes has no token-usage tracking. The dock ring fill falls through to the
connection-state fallback in `Panel.qml` (full when `gatewayState: "active"`).


### `omarchy-agent-usage-minimax` (only writes when API key is set)

| Source | What it reads | Where it lives |
|---|---|---|
| `~/.openclaw/.env` | `MINIMAX_API_KEY=*** | User's home (managed by `openclaw onboard`) |
| `GET https://www.minimax.io/v1/token_plan/remains` | 5h + weekly token plan (remaining %, reset times) | MiniMax network |

No subprocess calls. Pure HTTP. The collector writes to a SEPARATE
JSON file (`minimax.json`) so the MiniMax panel tab is independent of
the OpenClaw tab.

## Data outputs

Every collector emits JSON to stdout. Omarchy's sweeper writes this to
`~/.local/state/omarchy/agents/usage/<id>.json`:

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
  "limits": [...],             // drives the Limits section
  "modelUsage": {},            // drives Tokens-by-model section
  "balance": null,             // prepaid balance display (optional)
  "provider": "xai"            // source attribution tag
}
```

OpenClaw's record additionally has gateway state, runtime, Discord
status, total sessions, and `minimaxTokenPlan` fields (see
`manifest.json`'s `outputSchema` for the full schema).

## Network calls

Only two collectors make outbound network calls, and only when their
respective API key is set:

| Collector | Endpoint | When |
|---|---|---|
| grok | `https://api.x.ai/v1/api-key` | `XAI_API_KEY` is set |
| gemini | `https://generativelanguage.googleapis.com/v1beta/models` | `GEMINI_API_KEY` or `GOOGLE_API_KEY` is set |

No other network calls are made by this package. No telemetry is sent
anywhere. The collectors do not phone home.

## What the panel displays

The panel reads the JSON files and renders them in three places:

1. **Dock row** — one circle per enabled provider with `providerHasData() = true`
2. **Popup hero** — `providerName`, `version`, `activeModel`
3. **Popup status block** — provider-specific data (OpenClaw gateway/runtime/Discord/MiniMax block; other providers get the standard recentDays/limits/models block)

Detailed panel behavior is in `panel.md`.

## See also

- `architecture.md` — components and provider model
- `panel.md` — what the user sees
- `security.md` — threat model around these data flows
