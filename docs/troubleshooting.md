# Troubleshooting

Common issues and fixes. If your issue isn't here, check `~/.local/state/omarchy/agents/usage/openclaw.json` first — it should always be valid JSON.

## Panel doesn't show OpenClaw tab

**Symptom:** Open the agents panel (top-right). OpenClaw tab is missing.

**Causes / fixes:**

1. **Cache file is empty or missing.**
   ```bash
   ls -la ~/.local/state/omarchy/agents/usage/openclaw.json
   /usr/bin/omarchy-agent-usage-update  # regenerate
   ```
   Should produce a JSON file ≥ 1 KB.

2. **Collector exited with error.**
   ```bash
   /usr/bin/omarchy-agent-usage-openclaw --force 2>&1 | head -50
   ```
   Look for tracebacks. Most common cause: `omarchy-safe-io` permission issue (mode must be 755, not 644). Fix: `sudo chmod 755 /usr/bin/omarchy-safe-io`.

3. **Provider not in `providers` list.**
   Check the agent's `providerId`:
   ```bash
   cat ~/.local/state/omarchy/agents/usage/openclaw.json | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])"
   ```
   Should print `openclaw`.

4. **Quickshell didn't reload after install.**
   ```bash
   pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'
   ```
   Hyprland auto-restarts it.

## OpenClaw tab is in panel but values are stale

**Symptom:** "Total sessions" or "active model" don't match reality.

**Causes / fixes:**

1. **Sweeper not running.**
   ```bash
   /usr/bin/omarchy-agent-usage-update
   ```
   Should regenerate `openclaw.json` within seconds.

2. **Stale-data-fallback active.**
   Check the `updatedAt` field in `openclaw.json`. If it's older than a minute, the collector has been failing. Look at `~/.local/state/omarchy/agents/usage/openclaw.state.json` — that's the last-known-good record.

3. **OpenClaw gateway is down.**
   The collector reads `systemctl --user is-active openclaw-gateway.service`. If that's `inactive`, `gatewayState` will reflect it.
   ```bash
   systemctl --user status openclaw-gateway.service
   ```

## "codex not found in path" red bar (or similar)

**Symptom:** Red bar in the panel showing `<cli> not found in PATH`.

**Cause:** An orphan collector script is still installed in `/usr/bin/` for an agent whose CLI is no longer installed (e.g., you uninstalled `codex` but `/usr/bin/omarchy-agent-usage-codex` is still there).

**Fix:**
```bash
# Identify the orphan
ls /usr/bin/omarchy-agent-usage-*
# Remove the broken one (replace <cli> with the name)
sudo rm /usr/bin/omarchy-agent-usage-<cli>
rm ~/.local/state/omarchy/agents/usage/<cli>.json
```

After removal, restart Quickshell:
```bash
pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'
```

## "0 / 0 / inactive" everywhere

**Symptom:** Panel shows `Gateway: inactive`, `Model: —`, `Total sessions: 0`.

**Causes / fixes:**

1. **OpenClaw binary not installed.**
   ```bash
   command -v openclaw || echo "MISSING"
   ```
   If missing: `curl -fsSL https://openclaw.io/install.sh | bash`

2. **No trajectory data yet.**
   OpenClaw writes trajectory entries when you make API calls. If you've never called OpenClaw from this account, there's no data. Make a call and refresh.

3. **Permissions issue on trajectory dir.**
   ```bash
   ls -la ~/.openclaw/crestodian/sessions/
   ```
   If unreadable: `chmod -R u+rwX ~/.openclaw/crestodian/sessions/`

## After `omarchy-update`

**Symptom:** Panel reverts to Omarchy stock (no OpenClaw tab, or stock layout).

**Cause:** Omarchy updates can overwrite `/usr/share/omarchy/shell/plugins/agents/Panel.qml` and `Main.qml`.

**Fix:**
```bash
cd /path/to/openclaw-integration
./install.sh
```

`install.sh` re-applies the patches. Backups (`*.openclaw-backup`) are preserved across updates, so uninstall always works cleanly.

## Uninstall doesn't restore files

**Symptom:** After `./uninstall.sh`, Panel.qml is missing or in a broken state.

**Cause:** Backup file is missing (e.g., never created because the original install errored mid-way).

**Fix:**
```bash
# Reinstall Omarchy's stock files from the package or git
sudo pacman -S omarchy
# Or restore from git
cd /usr/share/omarchy
sudo git checkout shell/plugins/agents/Panel.qml shell/plugins/agents/Main.qml
```

If neither works, your Omarchy install has lost the original files. Reach out to the Omarchy community for a fresh copy.

## Collector always returns `id: "openclaw"` but other fields empty

**Symptom:** `openclaw.json` has `id`, `name`, but `gatewayState: "unknown"`, `openclawPid: ""`, etc.

**Cause:** The live checks all failed. Check the stderr of the collector:
```bash
/usr/bin/omarchy-agent-usage-openclaw --force 2>&1
```

Common causes:
- `openclaw` not installed → install OpenClaw first.
- `systemctl --user` not available → check that you're running in a user systemd session.
- `pgrep -f` permissions issue → unusual; should "just work".

## "openclaw onboard" doesn't run interactively

**Symptom:** `openclaw onboard` errors with "Onboarding needs an interactive TTY."

**Cause:** The install script was run non-interactively (e.g., via `curl | bash` without a TTY).

**Fix:** Run `./install.sh` from a real terminal. The install script will detect the missing TTY and skip onboard — run `openclaw onboard` yourself afterward in a terminal.

## Permission denied when running install.sh

**Symptom:** `sudo: unable to resolve host` or `Permission denied` errors.

**Cause:** The current user doesn't have sudo access.

**Fix:**
```bash
sudo -v  # verify sudo works
./install.sh
```

If `sudo` isn't configured for your user, contact your system administrator (or, on Omarchy, run `omarchy apply hardware` to ensure the user is set up with sudo).

## Logs

The collector doesn't write logs by default. To debug, run it manually and capture stderr:
```bash
/usr/bin/omarchy-agent-usage-openclaw --force 2>&1 | tee /tmp/openclaw-debug.log
```

The sweeper runs every ~30 seconds and overwrites `openclaw.json`. To watch live, in another terminal:
```bash
watch -n 2 'cat ~/.local/state/omarchy/agents/usage/openclaw.json | python3 -m json.tool'
```
