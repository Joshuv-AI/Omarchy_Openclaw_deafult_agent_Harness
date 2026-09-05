#!/usr/bin/env python3
"""User-owned Qwen collector.

Lives at ~/.local/share/omarchy/agent-providers/collectors/qwen.py
after install. Connection probe only — no quota surface documented
on /v1beta/models. Region pairing rules per audit-log entry.
"""
# omarchy:summary=Probe Qwen (DashScope) connection
# omarchy:args=[--force]
# omarchy:hidden=true

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

AGENT_ID = "qwen"
AGENT_NAME = "Qwen (DashScope)"
USAGE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")
) / "omarchy" / "agents" / "usage"
USAGE_FILE = USAGE_DIR / f"{AGENT_ID}.json"

API_TIMEOUT_SECONDS = 8


def main():
    USAGE_DIR.mkdir(parents=True, exist_ok=True)
    base_url = os.environ.get(
        "QWEN_BASE_URL",
        "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
    )

    record = {
        "id": AGENT_ID,
        "name": AGENT_NAME,
        "schemaVersion": 2,
        "provider": "dashscope",
        "ready": False,
        "installed": True,
        "version": "1.0.0",
        "fetchedAt": "",
        "qwenAvailable": False,
        "qwenUsageMode": "none",
        "qwenRingEmpty": True,
        "qwenBaseUrl": base_url,
        "qwenBaseUrlSource": "default",
        "qwenKeySource": "missing",
        "qwenModelCount": None,
        "qwenError": None,
        "authHelpText": "",
    }

    api_key = os.environ.get("DASHSCOPE_API_KEY", "")
    if not api_key:
        record["authHelpText"] = "Configuration not detected."
        USAGE_FILE.write_text(json.dumps(record, indent=2))
        return

    record["qwenKeySource"] = "process-env"
    record["qwenBaseUrlSource"] = "process-env" if os.environ.get("QWEN_BASE_URL") else "default"

    try:
        req = urllib.request.Request(
            f"{base_url}/models",
            headers={"Authorization": f"Bearer {api_key}"},
        )
        with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            data = json.loads(body) if body else {}
            count = len(data.get("data", [])) if isinstance(data, dict) else None
            record["qwenAvailable"] = True
            record["qwenUsageMode"] = "connection"
            record["qwenModelCount"] = count
    except urllib.error.HTTPError as e:
        record["qwenError"] = "HTTP " + str(e.code)
        record["authHelpText"] = "Connection rejected (HTTP " + str(e.code) + ")"
    except Exception as e:
        record["qwenError"] = str(e)
        record["authHelpText"] = "Connection probe failed"

    record["fetchedAt"] = __import__("datetime").datetime.now(
        __import__("datetime").timezone.utc
    ).isoformat()
    record["ready"] = record["qwenAvailable"]
    USAGE_FILE.write_text(json.dumps(record, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("omarchy-agent-usage-qwen: " + repr(e), file=sys.stderr)
        sys.exit(0)
