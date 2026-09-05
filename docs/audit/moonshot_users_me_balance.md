# Moonshot / Kimi Coding — `/v1/users/me/balance`

- **Official URL:** https://platform.moonshot.ai/docs/api-reference/api-overview
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** `Authorization: Bearer <KIMI_API_KEY>` (Kimi Coding) OR `Authorization: Bearer <MOONSHOT_API_KEY>` (Moonshot Open Platform). Distinct quota; same platform.
- **Region pairing:** intl `https://api.moonshot.ai/v1`; CN `https://api.moonshot.cn/v1`.
- **Field semantics:**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `data.available_balance` | **remaining monetary** | float | sum of cash + voucher remaining |
  | `data.cash_balance` | remaining monetary | float | cash portion |
  | `data.voucher_balance` | remaining monetary | float | voucher portion |
  | `data.currency` | identifier | string | currency code (default CNY) |

- **Minimal schema for tests:**

  ```json
  { "code": 0, "data": { "available_balance": 12.34, "currency": "CNY" } }
  ```

- **Ring semantic invariant:** NO ring fill. The balance is monetary with no documented denominator. Render as labeled value `Balance: <amount> <currency>`. If the user wants a fill, they configure a threshold in `~/.config/omarchy/agent-providers/settings.json` — default is no threshold, no fill.
- **Notes:** There is no documented token-allowance endpoint for Moonshot/Kimi. The only documented data surface is the monetary balance.
