# MiniMax — `/v1/token_plan/remains`

- **Official URL:** https://platform.minimax.io/docs/api-reference/token-plan/remains
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** `Authorization: Bearer <SUBSCRIPTION_KEY>` (Token Plan key shape; pay-as-you-go key has separate quota and is NOT accepted by this endpoint).
- **Region pairing:** intl endpoint `https://api.minimax.io/v1/token_plan/remains`; CN endpoint `https://api.minimaxi.com/v1/token_plan/remains`. Key + base URL must be from the same region; mismatch returns 401.
- **Field semantics:**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `model_remains[].model_name` | identifier | string | `"general"` or `"video"` |
  | `model_remains[].current_interval_remaining_percent` | **remaining** | 0..100 | percentage of interval allowance remaining |
  | `model_remains[].current_interval_status` | enum | int | status code (1=active, 2=cooldown, 3=reset — per docs) |
  | `model_remains[].current_weekly_remaining_percent` | **remaining** | 0..100 | percentage of weekly allowance remaining |
  | `model_remains[].current_weekly_status` | enum | int | status code |
  | `model_remains[].remains_time` | duration | milliseconds | time until interval reset (despite field name, values > 7 days indicate ms not s) |
  | `model_remains[].weekly_remains_time` | duration | milliseconds | time until weekly reset |

- **Minimal schema for tests:**

  ```json
  {
    "model_remains": [
      {
        "model_name": "general",
        "current_interval_remaining_percent": 96,
        "current_weekly_remaining_percent": 100
      }
    ]
  }
  ```

- **Ring semantic invariant:** ring fill = `remaining / 100`; label = `Remaining: <percent>`. Full means more allowance remains.
- **Notes:** The field name `current_interval_remaining_percent` literally contains `remaining` — direction is unambiguous from the field name. The audit-log entry is for completeness only.
