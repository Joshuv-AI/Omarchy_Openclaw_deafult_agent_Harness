# Hermes — `hermes status`

- **Official URL:** https://hermes-agent.nousresearch.com/docs
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** none from `hermes status` itself. Hermes's own auth state is in `~/.hermes/.env` / `~/.hermes/config.yaml`.
- **Output format:** plain text, not JSON. `key: value` lines.
- **Documented fields (Release 1.0 USED):**

  | field | values | meaning |
  |---|---|---|
  | `gateway` | `running` / `stopped` | gateway process state |

- **Documented fields (Release 1.0 DEFERRED):**

  | field | values | meaning |
  |---|---|---|
  | `agent` | `running` / `stopped` | agent process state |
  | `auth` | `authenticated` / `required` / `unknown` | auth state |
  | `platform` | hostname string | running platform |
  | `version` | semver string | installed version |

- **Minimal schema for tests:**

  ```
  gateway: running
  ```

- **Ring semantic invariant (Release 1.0):** gateway state only — three states: `running`, `stopped`, `unknown`. Render as labeled value. No fill for stopped/unknown; full fill for running. Label: `Hermes gateway <state>`.
- **Notes:** The deferred fields may be added in a future release after their `hermes status` field semantics are independently verified (e.g., by capturing a real local invocation and committing a redacted fixture).
