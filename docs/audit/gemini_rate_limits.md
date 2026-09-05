# Gemini — `/v1beta/models` and `generateContent` rate-limit headers

- **Official URL:** https://ai.google.dev/gemini-api/docs/models
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** `?key=<GEMINI_API_KEY>` query parameter OR `GOOGLE_API_KEY` env var.
- **Field semantics (`/v1beta/models`):**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `models[].name` | identifier | string | model id (e.g. `models/gemini-2.0-flash`) |
  | `models[].version` | identifier | string | model version |
  | `models[].displayName` | identifier | string | display name |

- **Field semantics (rate-limit headers on `generateContent` — opt-in v2, deferred):**

  | header | direction | unit | meaning |
  |---|---|---|---|
  | `x-ratelimit-remaining-requests` | remaining | int | remaining requests in current window |
  | `x-ratelimit-limit-requests` | capacity | int | request cap |
  | `x-ratelimit-remaining-tokens` | remaining | int | remaining tokens in current window |
  | `x-ratelimit-limit-tokens` | capacity | int | token cap |

  Headers are present ONLY on successful `generateContent` calls, NOT on `/v1beta/models`.

- **Minimal schema for tests:**

  ```json
  { "models": [ { "name": "models/gemini-2.0-flash", "version": "2.0" } ] }
  ```

- **Ring semantic invariant (Release 1.0):** NO ring fill from `/v1beta/models` (no quota, balance, or fixed-capacity field documented). The opt-in v2 rate-limit headers are deferred — `Release 1.0` ships Gemini as connection-state only.
- **Notes:** The rate-limit headers require an actual generation call (cost-bearing). Deferred until a documented cheap-source is available.
