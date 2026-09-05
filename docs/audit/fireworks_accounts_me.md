# Fireworks — `/v1/accounts/me`

- **Official URL:** https://docs.fireworks.ai/api-reference/get-account-information
- **Fetched on:** 2026-09-04 22:00 EDT
- **Reviewer:** Konan (auto-audit)
- **Auth path:** `Authorization: Bearer <FIREWORKS_API_KEY>`.
- **Field semantics:**

  | field | direction | unit | meaning |
  |---|---|---|---|
  | `account_id` | identifier | string | account id |
  | `accountBalance` | **remaining monetary** | float USD | remaining balance |
  | `creditLimit` | capacity (semantics per `type` — NOT audit-logged) | float USD | semantics depend on `type` |
  | `currency` | identifier | string | `"USD"` |
  | `type` | identifier | string | `"PREPAID"` or `"POSTPAID"` |

- **Minimal schema for tests:**

  ```json
  { "account_id": "acct-xxx", "accountBalance": 12.34, "creditLimit": 50.00, "type": "PREPAID" }
  ```

- **Ring semantic invariant:** NO ring fill from `creditLimit`. The semantics of `creditLimit` per `type` are not audit-logged in this pass; for `POSTPAID` it is a credit-line ceiling, not a prepaid allowance. Render as labeled value `Balance: <amount> <currency> · <account type>` only. If the user wants a fill, they configure a threshold in settings.
- **Notes:** This audit pass did NOT lock `creditLimit` semantics per `type`. A future audit pass that explicitly documents the semantics may allow a ring fill for `PREPAID` accounts.
