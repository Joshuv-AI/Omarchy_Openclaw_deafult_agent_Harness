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

When `XAI_API_KEY` is unset, the collector writes a minimal record with
`authHelpText` pointing to https://console.x.ai so the panel can
display a setup hint.

### `omarchy-agent-usage-gemini` (installed but no-op without key)

| Source | What it reads | Where it lives |
|---|---|---|
| `GEMINI_API_KEY` / `GOOGLE_API_KEY` env var | API key value | Process environment |
| `GET https://generativelanguage.googleapis.com/v1beta/models?key=***` | Available model list + rate-limit response headers | Google network |

When neither key is set, the collector writes a minimal record with
`authHelpText` pointing to https://aistudio.google.com/apikey.

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
