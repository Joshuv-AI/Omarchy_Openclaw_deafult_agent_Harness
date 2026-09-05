# OpenClaw — gateway state

- **Source:** local systemd user service (`systemctl --user is-active openclaw-gateway.service`) + OpenClaw's local session record.
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Field semantics:**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `gatewayState` | identifier | enum | `active` / `stopped` / `not-installed` / `unknown` |
  | `activeModel` | identifier | string | currently-active model identifier |
  | `version` | identifier | string | OpenClaw version |
  | `gatewayStartedAt` | timestamp | human string | gateway start time |
  | `openclawUptime` | identifier | human string | uptime |

- **Minimal schema for tests:**

  ```json
  { "gatewayState": "active", "activeModel": "minimax/MiniMax-M3" }
  ```

- **Ring semantic invariant:** gateway state only — `running`/`active` → full fill; `stopped`/`inactive` → empty; `unknown` → gray dot. Label: `Gateway <state> · model: <activeModel>`.
- **Notes:** No remote probe required. Detection via `systemctl --user is-active openclaw-gateway.service` is the primary signal; `~/.openclaw/` directory presence is a fallback.
