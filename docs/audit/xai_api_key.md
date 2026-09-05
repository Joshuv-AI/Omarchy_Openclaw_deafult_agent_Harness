# xAI / Grok — `/v1/api-key`

- **Official URL:** https://docs.x.ai/docs/developers/api-key-information
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** `Authorization: Bearer <XAI_API_KEY>`.
- **Field semantics:**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `id` | identifier | string | key id |
  | `name` | identifier | string | key name |
  | `user_id` | identifier | string | owner |
  | `api_key_blocked` | boolean | bool | true if blocked |
  | `api_key_flags` | array | array of strings | flags |
  | `usage.total_tokens` | **used (aggregate, NOT remaining)** | int | tokens used in current period |
  | `usage.time_period` | identifier | string | e.g. `calendar_month` |
  | `usage.period_start` | timestamp | ISO-8601 | period start |
  | `usage.period_end` | timestamp | ISO-8601 | period end |
  | `per_resource[].resource` | identifier | string | model id |
  | `per_resource[].rpm` | **capacity cap (NOT remaining)** | int | requests/min cap |
  | `per_resource[].rpd` | **capacity cap (NOT remaining)** | int | requests/day cap |
  | `per_resource[].tpm` | **capacity cap (NOT remaining)** | int | tokens/min cap |
  | `per_resource[].tpd` | **capacity cap (NOT remaining)** | int | tokens/day cap |

- **Minimal schema for tests:**

  ```json
  {
    "id": "key-xxx",
    "api_key_blocked": false,
    "usage": { "total_tokens": 12345, "time_period": "calendar_month" },
    "per_resource": [ { "resource": "grok-4", "rpm": 60, "rpd": 1000, "tpm": 60000, "tpd": 1000000 } ]
  }
  ```

- **Ring semantic invariant:** NO ring fill from `usage.total_tokens` (it is aggregate used, not remaining against a documented matching denominator). Capacity caps render as labeled values: `Capacity: <model> RPM <N> · RPD <N> · TPM <N> · TPD <N>`.
- **Notes:** No documented remaining-percent field exists on this endpoint.
