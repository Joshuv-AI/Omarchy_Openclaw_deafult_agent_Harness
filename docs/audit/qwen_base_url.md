# DashScope / Qwen — base URL and `/v1/models`

- **Official URL:** https://help.aliyun.com/en/model-studio/base-url
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** `Authorization: Bearer <DASHSCOPE_API_KEY>`. Env var accepted: `DASHSCOPE_API_KEY`.
- **Region pairing (CRITICAL):**

  | plan | base URL | key shape |
  |---|---|---|
  | Pay-as-you-go (intl) | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` | intl `sk-...` |
  | Pay-as-you-go (CN)   | `https://dashscope.aliyuncs.com/compatible-mode/v1`     | CN `sk-...` |
  | Token Plan / Coding Plan (CN only) | `https://dashscope.aliyuncs.com/compatible-mode/v1` | CN `sk-...` |

  **Pairing mismatch → 401.**

- **Field semantics (`/v1/models`, OpenAI-compatible):**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `data[].id` | identifier | string | model id |
  | `data[].owned_by` | identifier | string | owner (`alibaba`) |
  | `data[].object` | identifier | string | always `"model"` |
  | `data[].created` | timestamp | int | unix ts |

- **Minimal schema for tests:**

  ```json
  { "object": "list", "data": [ { "id": "qwen-turbo", "owned_by": "alibaba" } ] }
  ```

- **Ring semantic invariant:** NO ring fill. The model-list endpoint has no documented quota, balance, or fixed-capacity fields. Release 1.0 ships Qwen as `Connection valid` / `Connection rejected` only.
- **Notes:** Region-pairing rules are the documented semantic. No documented remaining-percent endpoint exists for DashScope public consumers.
