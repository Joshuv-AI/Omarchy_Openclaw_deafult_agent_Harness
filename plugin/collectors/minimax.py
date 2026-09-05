#!/usr/bin/env python3
"""User-owned MiniMax collector.

Lives at ~/.local/share/omarchy/agent-providers/collectors/minimax.py
after install. Mirrors the existing /usr/bin/omarchy-agent-usage-minimax
behavior but is invoked by the user-owned driver, not by Omarchy's
collector driver. No symlinks, no /usr/share/omarchy writes, no sudo.

Reads:  ~/.openclaw/.env (for MINIMAX_API_KEY — shared with OpenClaw onboard)
Writes: ~/.local/state/omarchy/agents/usage/minimax.json

Direction per audit-log entry (docs/audit/minimax_token_plan_remains.md):
  current_interval_remaining_percent and current_weekly_remaining_percent
  are `remaining` (NOT used). Ring fill = remaining / 100.
  Label = `Remaining: <percent>`.
"""
# omarchy:summary=Print MiniMax token usage as JSON
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

AGENT_ID = "minimax"
AGENT_NAME = "MiniMax"
USAGE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
) / "omarchy" / "agents" / "usage"
USAGE_FILE = USAGE_DIR / f"{AGENT_ID}.json"
ENV_FILE = Path.home() / ".openclaw" / ".env"
API_BASE = "https://www.minimax.io/v1"
API_BASE_CN = "https://api.minimaxi.com/v1"
API_TIMEOUT_SECONDS = 8

API_KEY_VARS = ("MINIMAX_API_KEY", "MINIMAX_PORTAL_TOKEN", "MINIMAX_PORTAL_API_KEY")


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


def fetch_token_plan(api_key):
    bases = (API_BASE, API_BASE_CN)
    last_err = None
    for base in bases:
        req = urllib.request.Request(
            f"{base}/token_plan/remains",
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
    raise urllib.error.URLError("All MiniMax endpoints unreachable")


def _humanize_seconds(value):
    try:
        s = int(value)
    except Exception:
        return ""
    if s <= 0:
        return ""
    if s > 604800:
        s = s // 1000
    if s <= 0:
        return ""
    days, rem = divmod(s, 86400)
    hours, rem = divmod(rem, 3600)
    minutes = rem // 60
    if days > 0:
        return f"{days}d {hours}h"
    if hours > 0:
        return f"{hours}h {minutes}m"
    if minutes > 0:
        return f"{minutes}m"
    return f"{s}s"


def normalize_plan(raw):
    out = {"general": None, "video": None}
    if not isinstance(raw, dict):
        return out
    items = raw.get("model_remains")
    if not isinstance(items, list):
        return out
    for entry in items:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("model_name") or "").strip()
        if name not in ("general", "video"):
            continue
        interval_pct = entry.get("current_interval_remaining_percent")
        weekly_pct = entry.get("current_weekly_remaining_percent")
        try:
            interval_pct = float(interval_pct) if interval_pct is not None else None
        except Exception:
            interval_pct = None
        try:
            weekly_pct = float(weekly_pct) if weekly_pct is not None else None
        except Exception:
            weekly_pct = None
        out[name] = {
            "intervalRemainingPct": interval_pct,
            "weeklyRemainingPct": weekly_pct,
            "intervalResetHuman": _humanize_seconds(entry.get("remains_time")),
            "weeklyResetHuman": _humanize_seconds(entry.get("weekly_remains_time")),
            "intervalStatus": entry.get("current_interval_status"),
            "weeklyStatus": entry.get("weekly_status"),
        }
    return out


def main():
    USAGE_DIR.mkdir(parents=True, exist_ok=True)
    record = {
        "id": AGENT_ID,
        "name": AGENT_NAME,
        "schemaVersion": 1,
        "provider": "minimax",
        "ready": False,
        "installed": True,
        "version": "",
        "activeModel": "",
        "minimaxAvailable": False,
        "minimaxError": "",
        "minimaxTokenPlan": {"general": None, "video": None},
        "minimaxSummary5h": "",
        "minimaxSummaryWeekly": "",
        "minimaxSummaryReset": "",
        "minimaxFetchedAt": "",
        "authHelpText": "",
    }

    api_key = read_api_key()
    if not api_key:
        record["authHelpText"] = "Configuration not detected."
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    try:
        raw = fetch_token_plan(api_key)
    except urllib.error.HTTPError as e:
        record["authHelpText"] = "MiniMax API error: HTTP " + str(e.code)
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return
    except Exception as e:
        record["authHelpText"] = "MiniMax API error: " + str(e)
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    plan = normalize_plan(raw)
    record["minimaxAvailable"] = bool(plan["general"] or plan["video"])
    general = plan["general"] or {}
    video = plan["video"] or {}
    record["minimaxTokenPlan"] = plan

    def _pct_str(v):
        try:
            return str(int(round(float(v)))) + "%" if v is not None else ""
        except Exception:
            return ""

    record["minimaxSummary5h"] = _pct_str(general.get("intervalRemainingPct"))
    record["minimaxSummaryWeekly"] = _pct_str(general.get("weeklyRemainingPct"))
    record["minimaxSummaryReset"] = (
        "5h: " + (general.get("intervalResetHuman") or "—") +
        " · wk: " + (general.get("weeklyResetHuman") or "—")
    )
    record["minimaxFetchedAt"] = __import__("datetime").datetime.now(
        __import__("datetime").timezone.utc
    ).isoformat()
    record["ready"] = record["minimaxAvailable"]
    USAGE_FILE.write_text(json.dumps(record, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("omarchy-agent-usage-minimax: " + repr(e), file=sys.stderr)
        sys.exit(0)
