# Claude — OAuth usage API

- **Official URL:** https://docs.claude.com/en/api/usage-cost-api
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** OAuth Bearer; the Omarchy collector reads the OAuth cookie from `~/.claude/.credentials.json`.
- **Field semantics:**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `five_hour.utilization` | **used (NOT remaining)** | 0..100 | percent used in 5-hour window |
  | `five_hour.resets_at` | timestamp | ISO-8601 | window reset |
  | `seven_day.utilization` | **used (NOT remaining)** | 0..100 | percent used in 7-day window |
  | `seven_day.resets_at` | timestamp | ISO-8601 | window reset |
  | `seven_day_opus.utilization` | **used (NOT remaining)** | 0..100 | Opus-tier only |
  | `seven_day_opus.resets_at` | timestamp | ISO-8601 | window reset |

- **Minimal schema for tests:**

  ```json
  { "five_hour": { "utilization": 12.5 }, "seven_day": { "utilization": 23.4 } }
  ```

- **Ring semantic invariant:** ring fill = `(100 - used) / 100`; label = `Remaining: <percent>`. The Omarchy-installed collector preserves the `used` direction, so the panel's ring fill is the inverse of `utilization`.
- **Notes:** Documented refresh rate limit is 1 req/min per the docs page.
