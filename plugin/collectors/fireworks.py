#!/usr/bin/env python3
"""User-owned Fireworks collector.

Per audit-log (docs/audit/fireworks_accounts_me.md): accountBalance is
`remaining` monetary balance. creditLimit semantics per `type` are
NOT documented in the audit pass — no ring fill from creditLimit.
We render the balance as a labeled value only.
"""
# omarchy:summary=Print Fireworks account balance as JSON
# omarchy:args=[--force]
# omarchy:hidden=true

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

AGENT_ID = "fireworks"
AGENT_NAME = "Fireworks"
USAGE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
) / "omarchy" / "agents" / "usage"
USAGE_FILE = USAGE_DIR / f"{AGENT_ID}.json"
API_TIMEOUT_SECONDS = 8


def main():
    USAGE_DIR.mkdir(parents=True, exist_ok=True)
    record = {
        "id": AGENT_ID,
        "name": AGENT_NAME,
        "schemaVersion": 1,
        "provider": "fireworks",
        "ready": False,
        "installed": True,
        "version": "",
        "scope": "account",
        "hasPromptStats": False,
        "tierLabel": "unknown",
        "usageStatusText": "",
        "authHelpText": "",
        "limits": [],
        "todayPrompts": 0,
        "todaySessions": 0,
        "todayTotalTokens": 0,
        "todayTokensByModel": {},
        "recentDays": [],
        "totalPrompts": 0,
        "totalSessions": 0,
        "activeDays": 0,
        "activeDates": [],
        "modelUsage": {},
        "balance": None,
        "updatedAt": "",
    }

    api_key = os.environ.get("FIREWORKS_API_KEY", "")
    if not api_key:
        record["tierLabel"] = "unknown"
        record["usageStatusText"] = "Configuration not detected."
        record["authHelpText"] = "Configuration not detected."
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    try:
        req = urllib.request.Request(
            "https://api.fireworks.ai/v1/accounts/me",
            headers={"Authorization": f"Bearer {api_key}"},
        )
        with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            data = json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        record["tierLabel"] = "unknown"
        record["usageStatusText"] = "Connection rejected (HTTP " + str(e.code) + ")"
        record["authHelpText"] = "Connection rejected."
        record["updatedAt"] = __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat()
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return
    except Exception as e:
        record["tierLabel"] = "unknown"
        record["usageStatusText"] = "Connection probe failed"
        record["authHelpText"] = "Connection probe failed."
        record["updatedAt"] = __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat()
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    record["ready"] = True
    record["tierLabel"] = (data.get("type") or "unknown")
    record["balance"] = {
        "account_id": data.get("account_id"),
        "accountBalance": data.get("accountBalance"),
        "creditLimit": data.get("creditLimit"),
        "currency": data.get("currency"),
        "type": data.get("type"),
    }
    record["usageStatusText"] = "Balance: see labeled value"
    record["updatedAt"] = __import__("datetime").datetime.now(
        __import__("datetime").timezone.utc
    ).isoformat()
    USAGE_FILE.write_text(json.dumps(record, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("omarchy-agent-usage-fireworks: " + repr(e), file=sys.stderr)
        sys.exit(0)
