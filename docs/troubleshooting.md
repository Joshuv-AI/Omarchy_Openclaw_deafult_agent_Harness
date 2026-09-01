# Troubleshooting

Common issues and fixes. If your issue isn't here, check the cache file
for the affected provider:

```bash
ls -la ~/.local/state/omarchy/agents/usage/
cat ~/.local/state/omarchy/agents/usage/openclaw.json | python3 -m json.tool | head -20
```

## Panel doesn't show OpenClaw tab

## Panel doesn't show Kimi icon

**Symptom:** OpenClaw or Hermes is using a Kimi model (e.g.
`kimi-k3` or `moonshot-v1-8k`), but no Kimi circle appears in the
dock.

**Causes / fixes:**

1. **`activeModel` doesn't match the Kimi prefix mapping.**
   Kimi detection accepts both `kimi/*` and `moonshot/*` prefixes.
   Check what OpenClaw is actually configured to use:
   ```bash
   cat ~/.local/state/omarchy/agents/usage/openclaw.json | python3 -c "import json,sys; print(json.load(sys.stdin)['activeModel'])"
   ```
   The active model must contain `kimi/` or `moonshot/` as a
   path separator. Bare names like `kimi-k3` are NOT recognized.
   Configure OpenClaw properly: `minimax/MiniMax-M3` → `kimi/kimi-k3`
   (or whichever Kimi model is in your plan).

2. **Collector hasn't run yet / cache is empty.**
   ```bash
   ls -la ~/.local/state/omarchy/agents/usage/kimi.json
   /usr/bin/omarchy-agent-usage-update --force
   ```
   Should produce a JSON file. If missing, run the collector
   directly:
   ```bash
   /usr/bin/omarchy-agent-usage-kimi --force 2>&1 | head -30
   ```

3. **`MOONSHOT_API_KEY` not set.**
   The Kimi icon will appear with an empty ring when no key is
   configured (this is the click-to-setup state) — but the user
   must have set OpenClaw/Hermes to a Kimi model FIRST. If no
   key AND no Kimi model, nothing shows. Set the key via the
   dock dialog (click the empty-ring icon) or directly:
   ```bash
   echo "MOONSHOT_API_KEY=sk-..." >> ~/.openclaw/.env
   /usr/bin/omarchy-agent-usage-update --force
   ```

4. **Sub-provider detection not finding Kimi.**
   `Main.qml`'s `subProviders` property filters the active agent's
   `activeModel` against the prefix mapping in `subProviderPrefixes`.
   Verify by checking the file directly:
   ```bash
   grep -A 20 "subProviderPrefixes" /usr/share/omarchy/shell/plugins/agents/Main.qml
   ```

## Kimi dialog doesn't open when I click the empty-ring icon

**Symptom:** Clicking the Kimi icon (empty teal ring) does nothing.

**Causes / fixes:**

1. **Panel.qml dialog code not loaded.**
   Verify `KimiSetupDialog` is present:
   ```bash
   grep -c "KimiSetupDialog" /usr/share/omarchy/shell/plugins/agents/Panel.qml
   ```
   Should be ≥ 1. If 0, reinstall or pull the latest Panel.qml.

2. **Quickshell didn't reload the QML.**
   Kill and restart Quickshell:
   ```bash
   pkill -TERM -f "quickshell -n -p"
   sleep 4
   nohup quickshell -n -p >/tmp/quickshell.log 2>&1 &
   disown
   ```
   Wait ~5 seconds for the panel to come back. Check journal:
   ```bash
   journalctl --user --since "30 seconds ago" | grep -i "kimi|popup|qml"
   ```

3. **`kimiNeedsSetup` flag isn't being set.**
   Check the cache file:
   ```bash
   cat ~/.local/state/omarchy/agents/usage/kimi.json | python3 -c "import json,sys; d=json.load(sys.stdin); print('kimiAvailable:', d.get('kimiAvailable'))"
   ```
   If `kimiAvailable: true`, the click will toggle the panel (no
   dialog) — that's correct behavior, the key IS configured.

4. **QML errors in journal.**
   ```bash
   journalctl --user --since "1 min ago" | grep -iE "kimi|popup|cannot"
   ```
   Look for syntax errors or undefined references.

## Kimi ring shows full but Kimi API calls fail

**Symptom:** Kimi dock circle has a full ring, but OpenClaw/Hermes
reports API errors when calling Kimi.

**Causes / fixes:**

This is the gap between connection-mode (full ring = key accepted)
and real token usage. The collector's `kimiRingEmpty` journalctl
check SHOULD catch recent Kimi/Moonshot errors and force an empty
ring. If it's not catching them:

1. **Errors aren't in the user journal.**
   ```bash
   journalctl --user --since "10 min ago" | grep -iE "kimi|moonshot|api.moonshot.ai"
   ```
   If the errors are in OpenClaw's own log file instead of the
   journal, the collector's `kimiRingEmpty` heuristic won't see
   them. (This is a known limitation; can be tightened later by
   also reading `~/.openclaw/logs/` when present.)

2. **Moonshot endpoint returns 200 but is actually rate-limiting.**
   Some Moonshot responses return 200 with a body indicating the
   account has no usable balance. The collector doesn't currently
   parse response bodies beyond `/v1/users/me`. If you're hitting
   this, set `kimiRingEmpty: true` manually as a workaround:
   ```bash
   sudo python3 -c "import json; d=json.load(open('/root/.local/state/omarchy/agents/usage/kimi.json')); d['kimiRingEmpty']=True; json.dump(d, open('/root/.local/state/omarchy/agents/usage/kimi.json','w'), indent=2)"
   ```
   (Or open an issue so we can add specific body parsing.)


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

## Panel doesn't show Qwen icon

**Symptom:** OpenClaw or Hermes is using a Qwen model (e.g.
`qwen3-max` or `dashscope/qwen3-8b`), but no Qwen circle appears
in the dock.

**Causes / fixes (display-only — panel does not fix anything):**

1. **`activeModel` doesn't match the Qwen prefix mapping.**
   Qwen detection accepts both `qwen/*` and `dashscope/*` prefixes.
   Check what OpenClaw is actually configured to use:
   ```bash
   cat ~/.local/state/omarchy/agents/usage/openclaw.json | python3 -c "import json,sys; print(json.load(sys.stdin)['activeModel'])"
   ```
   The active model must contain `qwen/` or `dashscope/` as a
   path separator. Bare names like `qwen3-max` are NOT recognized.

2. **OpenClaw or Hermes itself is not active.**
   The panel only shows the Qwen icon when one of the parent
   agents (OpenClaw or Hermes) is running and using a Qwen model.
   No parent agent → no Qwen icon, regardless of collector state.

3. **`DASHSCOPE_API_KEY` not found in any detection location.**
   The panel shows the icon (because `activeModel` matched) but
   the ring is empty (because the collector couldn't pull data).
   This is the expected display-only behavior — the user fixes
   their own DashScope / Bailian setup.
   ```bash
   cat ~/.local/state/omarchy/agents/usage/qwen.json | python3 -m json.tool | head -25
   ```
   Look at `qwenKeySource` — if it's `"missing"`, set
   `DASHSCOPE_API_KEY` in any of the 5 detection locations:
     - process environment
     - `~/.openclaw/.env`
     - shell rc file (`~/.bashrc`, `~/.zshrc`, etc.)
     - running OpenClaw/Hermes process environment
     - systemd `EnvironmentFile=`

4. **Wrong region / endpoint.**
   The default is `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`
   (international). China-mainland accounts need
   `QWEN_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1`
   set in any of the 5 detection locations.

5. **Sub-provider detection not finding Qwen.**
   `Main.qml`'s `subProviders` property filters the active agent's
   `activeModel` against the prefix mapping in `subProviderPrefixes`.
   Verify by checking the file directly:
   ```bash
   grep -A 5 "subProviderPrefixes" /usr/share/omarchy/shell/plugins/agents/Main.qml
   ```

**What the panel will NOT do** (display-only policy):

  - Open a setup dialog prompting you to paste your API key
  - Show a "fix it" button or troubleshooting URL
  - Tell you to check your DashScope console
  - Suggest any configuration change

If the ring is empty, that's the only signal you get. Fix the
upstream setup (set the key, switch region, refresh the gateway)
and the ring will fill on the next collector refresh (~60s).

## Qwen ring shows empty but Qwen is configured correctly

**Symptom:** Qwen dock circle has an empty purple ring even though
you've set `DASHSCOPE_API_KEY` and the agent is actively using a
Qwen model.

**Causes / fixes:**

1. **Collector hasn't run yet / cache is stale.**
   ```bash
   ls -la ~/.local/state/omarchy/agents/usage/qwen.json
   /usr/bin/omarchy-agent-usage-update --force
   ```
   Should produce a JSON file ≥ 1 KB.

2. **Collector exited with error.**
   ```bash
   /usr/bin/omarchy-agent-usage-qwen --force 2>&1 | head -50
   ```
   Look for tracebacks. The collector writes `qwenError` to the
   JSON when the probe fails.

3. **Key found in one location, but probe still fails.**
   ```bash
   cat ~/.local/state/omarchy/agents/usage/qwen.json | python3 -c "import json,sys; d=json.load(sys.stdin); print('keySource:', d.get('qwenKeySource'), 'error:', d.get('qwenError'))"
   ```
   - `keySource: missing` → key not found anywhere; set it
   - `keySource: openclaw-env` (or any other) + `error: HTTP 401`
     → key was found but rejected. User fixes their own key.
   - `keySource: ...` + `error: network: ...` → endpoint
     unreachable. Check firewall / DNS / VPN. The panel will not
     diagnose or fix this.

4. **Wrong endpoint for region.**
   Set `QWEN_BASE_URL` in the same env location as the key:
   ```bash
   # China-mainland
   echo "QWEN_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1" >> ~/.openclaw/.env
   echo "DASHSCOPE_API_KEY=***" >> ~/.openclaw/.env
   /usr/bin/omarchy-agent-usage-update --force
   ```

The panel will display whatever state the collector reports. If
the collector reports `qwenAvailable: false`, the ring is empty.
That's it. User fixes the upstream issue.

