# Codex — local CLI scan

- **Official URL:** https://github.com/openai/codex
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Source of data:** local scan of `~/.codex/sessions/*.jsonl` and `~/.codex/history.jsonl` by the Omarchy-installed `omarchy-agent-usage-codex` collector.
- **Field semantics:**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `todayTotalTokens` | used (cumulative for the day) | int | tokens used today |
  | `todayTokensByModel` | used (per-model) | object<string, int> | tokens by model |
  | `modelUsage[].inputTokens` | used | int | cumulative input tokens |
  | `modelUsage[].outputTokens` | used | int | cumulative output tokens |
  | `modelUsage[].cacheReadInputTokens` | used | int | cumulative cache-read tokens |
  | `modelUsage[].cacheCreationInputTokens` | used | int | cumulative cache-creation tokens |
  | `limits[].label` | identifier | string | label of the limit window |
  | `limits[].percent` | **UNKNOWN** | 0..1 | direction (used vs remaining) NOT documented in OpenAI Codex public docs; NOT specified by the collector source. Render as labeled value, NOT ring fill. |
  | `limits[].resetsAt` | timestamp | ISO-8601 | window reset |

- **Minimal schema for tests:**

  ```json
  {
    "todayTotalTokens": 4421022,
    "limits": [ { "label": "720h window", "percent": 0.85 } ]
  }
  ```

- **Ring semantic invariant:** NO ring fill. The 720h-window `limits[].percent` direction is unknown. Render as labeled value `720h window: <value>` with a panel-body note: `field direction not documented by OpenAI Codex public docs`.
- **Notes:** This audit pass CANNOT ship a Codex ring fill. A future pass that captures a real Codex local-scan with hand-reviewed redacted contents may document the direction and enable a ring fill.
