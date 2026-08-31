# Troubleshooting

Common issues and fixes. If your issue isn't here, check the cache file
for the affected provider:

```bash
ls -la ~/.local/state/omarchy/agents/usage/
cat ~/.local/state/omarchy/agents/usage/openclaw.json | python3 -m json.tool | head -20
```

## Panel doesn't show OpenClaw tab

**Symptom:** Open the agents panel (top-right). OpenClaw tab is missing.

**Causes / fixes:**

1. **Cache file is empty or missing.**
   ```bash
   ls -la ~/.local/state/omarchy/agents/usage/openclaw.json
   /usr/bin/omarchy-agent-usage-update --force  # regenerate
   ```
   Should produce a JSON file ≥ 1 KB.

2. **Collector exited with error.**
   ```bash
   /usr/bin/omarchy-agent-usage-openclaw --force 2>&1 | head -50
   ```
   Look for tracebacks. Most common cause: `omarchy-safe-io` permission
   issue (mode must be 755, not 644). Fix: `sudo chmod 755 /usr/bin/omarchy-safe-io`.

3. **Provider not in `providers` list.**
   Check the agent's `providerId`:
   ```bash
   cat ~/.local/state/omarchy/agents/usage/openclaw.json | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])"
   ```
   Should print `openclaw`.

4. **`installed: false` or `ready: false`.**
   The panel filters out providers that don't pass `providerHasData()`.
   Look at `authHelpText` in the JSON — it usually says exactly what's
   missing (OpenClaw not installed, API key missing, gateway not running).

## Grok / Gemini dock circle is missing

**Symptom:** Even after setting the API key env var, the Grok or Gemini
circle doesn't appear in the dock.

**Causes / fixes:**

1. **Env var not set in the right session.**
   The collector runs under `omarchy-agent-usage-update` which inherits
   the systemd user environment. Set the key in
   `~/.config/environment.d/` (systemd-readable) OR restart Quickshell
   after `export XAI_API_KEY=...` in your shell so the child collector
   inherits it:
   ```bash
   echo 'XAI_API_KEY=***' > ~/.config/environment.d/xai.conf
   systemctl --user import-environment XAI_API_KEY
   ```
   Then `pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'`.

2. **Collector not installed.**
   ```bash
   ls /usr/bin/omarchy-agent-usage-grok
   ls /usr/bin/omarchy-agent-usage-gemini
   ```
   Both should be present. If not, re-run `./install.sh`.

3. **API key invalid.**
   ```bash
   /usr/bin/omarchy-agent-usage-grok --force 2>&1 | head -10
   /usr/bin/omarchy-agent-usage-gemini --force 2>&1 | head -10
   ```
   If you see `xAI API returned HTTP 401` or `Gemini API returned HTTP
   400`, your key is wrong or revoked. Generate a new one and retry.

## Dock ring fills don't update

**Symptom:** OpenClaw dock circle's progress ring stays at 0 or stuck at
the same percent even though the panel popup shows correct percentages.

**Cause:** The `dock.requestPaint()` timer is paused (Quickshell panel
was never opened, or the timer was GC'd).

**Fix:** Open the panel once. The timer starts on `onOpenedChanged`.

## Double-click doesn't toggle colors

**Symptom:** Double-clicking the dock row does nothing.

**Cause:** The bar slot has eaten the TapHandler event because the click
hits a different child element first.

**Fix:** Try clicking on the empty space between circles (more reliable
than clicking directly on a circle). The TapHandler fires on any
non-MouseArea child of the dock Item.

## Refresh is too slow / too fast

**Symptom:** Panel takes too long to show updated rate limits, OR
collectors are hammering the network.

**Fix:** Override the refresh interval in `~/.config/omarchy/shell.json`:

```json
{
  "omarchy.agents": {
    "refreshIntervalSec": 120
  }
}
```

`refreshIntervalSec` accepts 30–3600. The dock ring redraws every 30s
regardless of this setting.

## Gateway state shows "offline" but the gateway is running

**Symptom:** Panel popup shows `○ Gateway offline` even though
`systemctl --user status openclaw-gateway.service` says it's active.

**Cause:** The collector reads the gateway state via
`systemctl --user is-active openclaw-gateway.service`. If the user's
session doesn't have D-Bus access to systemd (e.g., running as a
different user, or after a session restart), this returns `unknown` or
`inactive`.

**Fix:**
```bash
systemctl --user status openclaw-gateway.service  # should show "active"
loginctl show-user $USER  # confirm session is active
```
If the session is wrong, log out and back in to refresh the user D-Bus
session.

## MiniMax bar shows wrong percentages

**Symptom:** The 5h or weekly bar fills don't match what the OpenClaw
dashboard shows.

**Cause:** Stale token-plan cache. The collector reads from
`~/.local/state/omarchy/agents/usage/minimax-token-plan-cache.json`,
cached by OpenClaw with a 300s TTL.

**Fix:**
```bash
rm ~/.local/state/omarchy/agents/usage/minimax-token-plan-cache.json
/usr/bin/omarchy-agent-usage-openclaw --force
```

## Panel popup won't open

**Symptom:** Clicking the dock icon does nothing.

**Fix:**
```bash
pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'
# Hyprland auto-restarts Quickshell with fresh state
```

If that doesn't work, check the Quickshell journal for IPC errors:
```bash
journalctl --user -u quickshell --since "1 minute ago" | tail -20
```

## Uninstall didn't restore the dock

**Symptom:** After `./uninstall.sh`, the panel still shows the multi-
provider dock instead of the original Omarchy single-icon dock.

**Cause:** The restore only happens if `.openclaw-backup` exists in
`/usr/share/omarchy/shell/plugins/agents/`.

**Fix:**
```bash
ls /usr/share/omarchy/shell/plugins/agents/*.openclaw-backup
# If empty, install.sh wasn't able to back up on install (rare). Restore manually:
sudo cp /usr/share/omarchy/shell/plugins/agents/Panel.qml.openclaw-backup \
        /usr/share/omarchy/shell/plugins/agents/Panel.qml
sudo cp /usr/share/omarchy/shell/plugins/agents/Main.qml.openclaw-backup \
        /usr/share/omarchy/shell/plugins/agents/Main.qml
pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'
```


## Hermes dock circle is missing

**Symptom:** After installing Hermes, no circle appears in the agents dock.

**Causes / fixes:**

1. **Hermes isn't installed.**
   ```bash
   command -v hermes
   ls -la ~/.local/state/omarchy/agents/usage/hermes.json
   ```
   If the JSON shows `"installed": false`, re-run `./install.sh` and accept the
   Hermes install prompt.

2. **Hermes is installed but not set up.**
   ```bash
   hermes setup --portal
   ```
   One OAuth round-trip covers the portal account + Tool Gateway tools.

3. **Hermes gateway isn't running.**
   ```bash
   pgrep -f hermes
   /usr/bin/omarchy-agent-usage-hermes --force
   ```
   Start the gateway: `hermes gateway`.

## Hermes ring stays empty even though Hermes is connected

**Symptom:** Hermes circle is visible but the gold ring doesn't fill.

**Cause:** The ring is a *connection ring* (not a usage ring). It only fills
when `gatewayState: "active"`. Hermes's `gateway` service needs to be running:

```bash
hermes gateway     # starts the messaging gateway service
```

If the daemon is running but the ring still doesn't fill, force a refresh:
```bash
/usr/bin/omarchy-agent-usage-hermes --force
pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'
```


## MiniMax dock circle is missing or shows empty data

**Symptom:** MiniMax doesn't appear in the dock, or appears with no token-usage data.

**Causes / fixes:**

1. **MINIMAX_API_KEY not set in `~/.openclaw/.env`.**
   ```bash
   grep MINIMAX ~/.openclaw/.env
   /usr/bin/omarchy-agent-usage-minimax --force
   ```
   If the JSON shows `"ready": false` with `"authHelpText"` mentioning the key,
   the env var is missing. Fix by running `openclaw onboard` once.

2. **The MiniMax HTTP endpoint is unreachable.**
   ```bash
   curl -sS -H "Authorization: Bearer $MINIMAX_API_KEY"      https://www.minimax.io/v1/token_plan/remains | head -50
   ```
   Check MiniMax's status page if this fails.

3. **The provider is filtered by `providerHasData()` in Main.qml.**
   The collector must write `minimaxAvailable: true` AND non-empty
   `minimaxTokenPlan` for the dock to show the circle.
## See also

- `architecture.md` — how collectors fit together
- `panel.md` — what the user sees
- `telemetry.md` — what data flows where
