#!/usr/bin/env bash
# User-owned Hermes collector. Invokes `hermes status` (local CLI),
# parses the `gateway:` field as `running|stopped|unknown`, writes the
# result to ~/.local/state/omarchy/agents/usage/hermes.json.
#
# No remote calls from this collector. The Hermes CLI is local.

set -euo pipefail

AGENT_ID="hermes"
AGENT_NAME="Hermes"
USAGE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage"
USAGE_FILE="$USAGE_DIR/$AGENT_ID.json"

mkdir -p "$USAGE_DIR"

state="unknown"
uptime=""
pid=""
version=""
if command -v hermes >/dev/null 2>&1; then
    # `hermes status` is human-readable; we grep for the documented
    # `gateway:` and `version:` fields. Per audit-log, only `gateway:`
    # ships in Release 1.0.
    out="$(hermes status 2>/dev/null || true)"
    gw="$(printf '%s' "$out" | awk '/^gateway:/ {print $2; exit}')"
    case "$gw" in
        running|active) state="running" ;;
        stopped|inactive) state="stopped" ;;
        *) state="unknown" ;;
    esac
    version="$(printf '%s' "$out" | awk '/^version:/ {print $2; exit}')"
fi

now_iso=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

cat > "$USAGE_FILE" <<JSON
{
  "id": "$AGENT_ID",
  "name": "$AGENT_NAME",
  "schemaVersion": 1,
  "provider": "hermes",
  "ready": true,
  "installed": $(command -v hermes >/dev/null 2>&1 && echo true || echo false),
  "version": "$version",
  "activeModel": "",
  "gatewayState": "$state",
  "currentSessionId": "",
  "currentSessionUpdatedAt": 0,
  "gatewayStartedAt": "",
  "nodeVersion": "",
  "hermesPid": "",
  "hermesUptime": "",
  "discordStatus": "unknown",
  "todayPrompts": 0,
  "todaySessions": 0,
  "todayTotalTokens": 0,
  "totalPrompts": 0,
  "totalSessions": 0,
  "activeDays": 0,
  "activeDates": [],
  "modelUsage": {},
  "avgContext": 0,
  "cacheRatio": 0,
  "balance": null,
  "authHelpText": "",
  "recentDays": [],
  "limits": [],
  "updatedAt": "$now_iso"
}
JSON

echo "$USAGE_FILE"
