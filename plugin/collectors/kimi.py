#!/usr/bin/env python3
"""User-owned Kimi collector.

Lives at ~/.local/share/omarchy/agent-providers/collectors/kimi.py
after install. Invoked by the user-owned driver. No symlinks, no
/usr/share/omarchy writes, no sudo.

Per audit-log entry (docs/audit/moonshot_users_me_balance.md):
  /v1/users/me/balance returns monetary balance. There is no
  documented denominator for a "funded threshold." We render the
  balance as a labeled value only. No ring fill.
"""
# omarchy:summary=Print Kimi balance as JSON
# omarchy:args=[--force]
# omarchy:hidden=true

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

AGENT_ID = "kimi"
AGENT_NAME = "Kimi"
USAGE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
) / "omarchy" / "agents" / "usage"
USAGE_FILE = USAGE_DIR / f"{AGENT_ID}.json"
ENV_FILE = Path.home() / ".openclaw" / ".env"
API_BASE = "https://api.moonshot.ai/v1"
API_BASE_CN = "https://api.moonshot.cn/v1"
API_TIMEOUT_SECONDS = 8

API_KEY_VARS = ("MOONSHOT_API_KEY", "KIMI_API_KEY")


def read_api_key():
    candidates = []
    for var in API_KEY_VARS:
        v = os.environ.get(var)
        if v:
            candidates.append((var, v))
    if ENV_FILE.exists():
        try:
            text = ENV_FILE.read_text(errors="replace")
        except Exception:
            text = ""
        for var in API_KEY_VARS:
            pattern = re.compile(
                rf"^\s*(?:export\s+)?{re.escape(var)}\s*=\s*(\S+)\s*$",
                re.MULTILINE,
            )
            m = pattern.search(text)
            if m:
                candidates.append((var, m.group(1).strip().strip('"').strip("'")))
    for _var, value in candidates:
        if value:
            return value
    return ""


def fetch_balance(api_key):
    bases = (API_BASE, API_BASE_CN)
    last_err = None
    for base in bases:
        req = urllib.request.Request(
            f"{base}/users/me/balance",
            headers={"Authorization": f"Bearer {api_key}"},
        )
        try:
            with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as resp:
                body = resp.read().decode("utf-8", errors="replace")
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as e:
            last_err = e
            if e.code not in (401, 403):
                raise
            continue
        except Exception:
            last_err = None
            continue
    if last_err is not None:
        raise last_err
    raise urllib.error.URLError("All Kimi endpoints unreachable")


def main():
    USAGE_DIR.mkdir(parents=True, exist_ok=True)
    record = {
        "id": AGENT_ID,
        "name": AGENT_NAME,
        "schemaVersion": 1,
        "provider": "moonshot",
        "ready": False,
        "installed": True,
        "version": "",
        "activeModel": "",
        "kimiAvailable": False,
        "kimiError": "",
        "kimiUsageMode": "none",
        "kimiRingEmpty": False,
        "kimiAccountInfo": None,
        "kimiFetchedAt": "",
        "authHelpText": "",
    }

    api_key = read_api_key()
    if not api_key:
        record["authHelpText"] = "Configuration not detected."
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    try:
        raw = fetch_balance(api_key)
    except urllib.error.HTTPError as e:
        record["authHelpText"] = "Kimi API error: HTTP " + str(e.code)
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return
    except Exception as e:
        record["authHelpText"] = "Kimi API error: " + str(e)
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    data = raw.get("data") if isinstance(raw, dict) else None
    if not isinstance(data, dict):
        record["authHelpText"] = "Kimi API response did not contain a data block."
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    record["kimiAvailable"] = True
    record["kimiUsageMode"] = "balance"
    record["kimiAccountInfo"] = {
        "available_balance": data.get("available_balance"),
        "cash_balance": data.get("cash_balance"),
        "voucher_balance": data.get("voucher_balance"),
        "currency": data.get("currency"),
    }
    record["kimiFetchedAt"] = __import__("datetime").datetime.now(
        __import__("datetime").timezone.utc
    ).isoformat()
    record["ready"] = True
    USAGE_FILE.write_text(json.dumps(record, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("omarchy-agent-usage-kimi: " + repr(e), file=sys.stderr)
        sys.exit(0)
