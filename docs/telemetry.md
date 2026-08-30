# Telemetry

This document describes the data the integration reads, writes, and displays. The aim is to make the data flow transparent — a user should know exactly what their machine is reporting to the panel.

## Data sources

The collector (`bin/omarchy-agent-usage-openclaw`) reads:

| Source | What it reads | Where it lives |
|---|---|---|
| `~/.openclaw/.env` | API key variable names (presence only — never the values) | User's home |
| `~/.openclaw/crestodian/sessions/*.trajectory.jsonl` | Per-step OpenClaw trajectory entries (model usage, prompts, sessions) | User's home |
| `~/.openclaw/tui/last-session.json` | Most recently updated session ID | User's home |
| `systemctl --user is-active openclaw-gateway.service` | Active/inactive state | User systemd |
| `systemctl --user show openclaw-gateway.service --property=ActiveEnterTimestamp` | Gateway start time | User systemd |
| `openclaw --version` | Version string (first line only) | $PATH |
| `node --version` | Node version | $PATH |
| `pgrep -f openclaw` | OpenClaw PID | /proc |
| `pgrep -f discord` | Discord presence | /proc |

The collector never reads:
- API key VALUES (only presence — checks if `MINIMAX_API_KEY=` exists, not its value).
- Files outside the paths above.
- `/etc/` for anything except via `systemctl --user` (which is a user-scope systemd query).
- Remote endpoints.

## Data outputs

The collector emits JSON to stdout. The Omarchy sweeper writes this to:

```
~/.local/state/omarchy/agents/usage/openclaw.json
```

with `chmod 600` (user-only readable).

### Schema

| Field | Type | Source |
|---|---|---|
| `id` | string | Static — always `"openclaw"` |
| `name` | string | Static — always `"OpenClaw"` |
| `version` | string | `openclaw --version` first line |
| `gatewayState` | enum | `systemctl --user is-active` |
| `activeModel` | string | Latest trajectory entry's `provider/modelId` |
| `currentSessionId` | string | `~/.openclaw/tui/last-session.json` |
| `currentSessionTitle` | string | Same |
| `gatewayStartedAt` | string | `systemctl --user show ... --property=ActiveEnterTimestamp` |
| `nodeVersion` | string | `node --version` |
| `openclawPid` | string | `pgrep -f openclaw` |
| `openclawUptime` | string | Computed from `gatewayStartedAt` and current time |
| `discordStatus` | enum | `pgrep -f discord` |
| `todayPrompts` | number | Trajectory aggregation for today |
| `todaySessions` | number | Trajectory aggregation for today |
| `todayTotalTokens` | number | Trajectory aggregation for today |
| `recentDays` | array | Last 7 days of (date, tokens, messageCount) |
| `totalPrompts` | number | Trajectory aggregation all-time |
| `totalSessions` | number | Trajectory aggregation all-time |
| `activeDays` | number | Days with non-zero token activity |
| `modelUsage` | object | Per-model token breakdown |
| `cacheRatio` | number | Cache hit ratio across trajectory |
| `usageStatusText` | string | Human-readable status for PanelHero |
| `authHelpText` | string | Empty (we deleted the orphan-claude/codex/fireworks path) |

### State file (stale-data-fallback)

```
~/.local/state/omarchy/agents/usage/openclaw.state.json
```

On successful collector run: write the same JSON as `openclaw.json`.
On collector failure (any live check fails): read this file and return its contents.

This ensures the panel never shows "0 / 0 / inactive" when the issue is transient (e.g., openclaw briefly not on PATH during an update).

## Panel display

The panel reads `openclaw.json` (via Quickshell's panel plugin) and displays:
- Gateway state (green/yellow/red dot)
- OpenClaw version
- Active model
- Runtime (Node version + PID + uptime)
- Discord status
- Total sessions (cumulative)

These are the only fields the panel shows. **No provider-specific token usage** (that section was removed for v1.0 — see `docs/security.md` "Explicit non-goals").

## Privacy

- All data stays on the user's machine.
- No telemetry leaves the device.
- No third-party services are contacted.
- The collector's stdout is JSON, captured by Omarchy's sweeper, written to a user-owned file.

## Versioning

The collector's output schema follows SemVer. Breaking changes to field names or types will trigger a major version bump. New fields may be added in minor versions.
