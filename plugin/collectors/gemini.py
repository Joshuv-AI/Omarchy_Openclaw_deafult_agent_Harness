#!/usr/bin/env python3
"""User-owned Gemini collector.

Per audit-log (docs/audit/gemini_rate_limits.md): /v1beta/models has no
documented quota, balance, or fixed-capacity fields. Rate-limit headers
on `generateContent` are opt-in v2 and deferred. Connection probe only.
"""
# omarchy:summary=Probe Gemini connection
# omarchy:args=[--force]
# omarchy:hidden=true

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

AGENT_ID = "gemini"
AGENT_NAME = "Gemini"
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
        "provider": "gemini",
        "ready": False,
        "installed": True,
        "version": "",
        "activeModel": "",
        "limits": [],
        "recentDays": [],
        "modelUsage": {},
        "todayPrompts": 0,
        "todaySessions": 0,
        "todayTotalTokens": 0,
        "totalPrompts": 0,
        "totalSessions": 0,
        "activeDays": 0,
        "activeDates": [],
        "avgContext": 0,
        "cacheRatio": 0,
        "balance": None,
        "authHelpText": "",
        "updatedAt": "",
    }

    api_key = os.environ.get("GEMINI_API_KEY", "") or os.environ.get("GOOGLE_API_KEY", "")
    if not api_key:
        record["authHelpText"] = "Configuration not detected."
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    try:
        req = urllib.request.Request(
            "https://generativelanguage.googleapis.com/v1beta/models"
            + "?key=" + api_key,
        )
        with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            data = json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        record["authHelpText"] = "Connection rejected (HTTP " + str(e.code) + ")"
        record["updatedAt"] = __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat()
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return
    except Exception as e:
        record["authHelpText"] = "Connection probe failed."
        record["updatedAt"] = __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat()
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    record["ready"] = True
    models = data.get("models") if isinstance(data, dict) else None
    record["balance"] = {
        "models_count": len(models) if isinstance(models, list) else None,
    }
    record["updatedAt"] = __import__("datetime").datetime.now(
        __import__("datetime").timezone.utc
    ).isoformat()
    USAGE_FILE.write_text(json.dumps(record, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("omarchy-agent-usage-gemini: " + repr(e), file=sys.stderr)
        sys.exit(0)
