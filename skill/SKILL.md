---
name: openclaw-hermes-omarchy-integration-maintenance
description: >
  Maintain, debug, and extend the OpenClaw + Hermes for Omarchy integration. Use when
  the user reports issues with the OpenClaw or Hermes dock rings in Omarchy's agents panel,
  asks to modify the integration, or wants to understand how the modified agent dock icon
  fits into the Omarchy shell. Covers collector behavior for both agents, panel patch points,
  gateway-ring logic, menu registration, and reinstall/uninstall flows.
---

# OpenClaw + Hermes for Omarchy — Maintenance Skill

When a user asks about this integration, follow this skill. The integration is small (~3000 lines) but touches multiple Omarchy subsystems and supports two centerpiece agents.

## When this skill applies

- "The OpenClaw tab is missing" / "Hermes tab is missing"
- "OpenClaw tab shows wrong values" / "stale data"
- "Hermes dock ring is empty"
- "How do I uninstall?" / "How do I reinstall?"
- "I want to add a new field to the panel"
- "After `omarchy-update`, the integration broke"
- "The dock icon isn't showing the pointer cursor on hover"
- "How do I add a custom provider's token usage?"
- "I want to add another agent (like a third centerpiece)"

## What this integration does

Single-line summary: install OpenClaw and Hermes, integrate them into Omarchy's agents panel as **two centerpiece agents**, and add a **modified agent dock icon** — a horizontal row of brand-colored rings where OpenClaw and Hermes rings show gateway activity (state, runtime, model, sessions) while sub-provider rings (MiniMax, Kimi, Qwen) show token usage.

Full architecture: see [`docs/architecture.md`](../docs/architecture.md).

## The two centerpiece agents

**OpenClaw** and **Hermes** are the centerpiece agents of this integration. Both get:
- A dock ring in the bar with the agent's brand-colored progress ring around a greyed-out center icon
- A tab in the panel popup with live data — but **gateway data**, not usage data
- An entry in the super-space **agents** menu (lobster for OpenClaw, wing for Hermes)

**What shows when you click OpenClaw's ring:**
- Gateway state (active / stopped / unknown)
- Version
- Active model
- Runtime line: Node version, PID, uptime
- Discord status (active / not running)
- Total sessions (lifetime)
- MiniMax token plan (5h + weekly bars, percent left, reset countdown) — only when using a minimax/* model

**What shows when you click Hermes's ring:**
- Hermes version (from `hermes --version`)
- Hermes CLI status (agent, auth, platform, gateway state)
- Gateway uptime
- Hermes process PID

**The gateway ring is the unique feature** — these are the only entries in the dock that report whether an agent's long-running gateway process is up or down. Other icons report usage or connection state, not gateway state.

## File map (the maintainable parts)

| Path | Role | Safe to edit? |
|---|---|---|
| `bin/omarchy-agent-usage-openclaw` | Collector: OpenClaw gateway + telemetry (Python, no deps) | Yes |
| `bin/omarchy-agent-usage-hermes` | Collector: Hermes CLI status + gateway (Python, no deps) | Yes |
| `bin/omarchy-agent-usage-minimax` | Collector: MiniMax 5h + weekly token plan | Yes |
| `bin/omarchy-agent-usage-kimi` | Collector: Kimi token-usage / connection probe | Yes |
| `bin/omarchy-agent-usage-qwen` | Collector: Qwen Bearer-auth /models probe | Yes |
| `bin/omarchy-agent-usage-grok` | Collector (opt-in): xAI Grok rate limits | Yes |
| `bin/omarchy-agent-usage-gemini` | Collector (opt-in): Google Gemini rate limits | Yes |
| `bin/` | Shell-only MOONSHOT_API_KEY updater | Yes (no panel surface) |
| `targets/Panel.qml` | Omarchy's panel + OpenClaw gateway block + Hermes gateway block + MiniMax usage block | Yes — only the OpenClaw/Hermes sections |
| `targets/Main.qml` | Omarchy's displayProvider + OpenClaw + Hermes field forwarding | Yes — only inside `displayProvider()` |
| `assets/openclaw.svg`, `openclaw-light.svg` | OpenClaw dock icons (dark + light) | Yes |
| `assets/hermes.svg` | Hermes dock icon (wing — Nous Hermes messenger symbol) | Yes |
| `assets/minimax.svg`, `kimi.svg`, `qwen.svg`, etc. | Sub-provider brand icons | Yes |
| `install.sh` | Idempotent installer (handles OpenClaw + Hermes setup) | Yes — test on a clean VM first |
| `uninstall.sh` | Reversible uninstaller | Yes — test on a clean VM first |
| `manifest.json` | Plugin metadata | Yes — bump version on changes |
| `docs/*.md` | Documentation | Yes |
| `~/.openclaw/.env` | OpenClaw API keys (managed by `openclaw onboard`, NOT us) | Never touch |
| `~/.hermes/.env` (or equivalent) | Hermes config (managed by Hermes, NOT us) | Never touch |

## Common user requests

### "The panel doesn't show OpenClaw / Hermes"

1. Run `./install.sh` to verify it's installed.
2. Check `~/.local/state/omarchy/agents/usage/openclaw.json` and `hermes.json` — both should be valid JSON ≥ 1 KB.
3. If empty: `sudo /usr/bin/omarchy-agent-usage-update` to regenerate.
4. If error in JSON: run `/usr/bin/omarchy-agent-usage-openclaw --force 2>&1` (or `--hermes --force`) to see the traceback.
5. Restart Quickshell: `pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'`.

Full troubleshooting: [`docs/troubleshooting.md`](../docs/troubleshooting.md).

### "OpenClaw / Hermes ring stays empty even though the agent is connected"

**OpenClaw ring empty** → `openclaw-gateway.service` not running. Start it:
```bash
omarchy start
# or: systemctl --user start openclaw-gateway.service
```

**Hermes ring empty** → `hermes gateway` not running. Start it:
```bash
hermes gateway
```

Then force a refresh:
```bash
/usr/bin/omarchy-agent-usage-update --force
pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'
```

### "The dock icon doesn't show the pointing-hand cursor on hover"

This means the dock row MouseArea is missing `hoverEnabled: true` or `cursorShape: Qt.PointingHandCursor`. Fix:

```qml
MouseArea {
  anchors.fill: parent
  hoverEnabled: true                  // add
  cursorShape: Qt.PointingHandCursor  // add
  acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
  onClicked: function(mouse) { ... }
}
```

Edit `/usr/share/omarchy/shell/plugins/agents/Panel.qml` (installed) and `targets/Panel.qml` (source), then reload Quickshell.

### "Add a new field to the panel"

The collectors emit JSON. The panel reads specific fields. To add a field for **either** OpenClaw or Hermes:

1. **In the collector** (`bin/omarchy-agent-usage-openclaw` or `bin/omarchy-agent-usage-hermes`):
   - Compute the value in `build_record()`.
   - Add it to the returned dict (e.g., `"myField": compute_my_field()`).
   - Update the schema in `manifest.json`.

2. **In `Main.qml`** (`targets/Main.qml`):
   - Inside `displayProvider()`, add the field to the returned object:
     ```javascript
     myField: String(record.myField || ""),
     ```

3. **In `Panel.qml`** (`targets/Panel.qml`):
   - Inside the OpenClaw or Hermes custom block (after the existing Text elements), add:
     ```qml
     Text {
       visible: usageSection.isOpenClaw  // or usageSection.isHermes
       text: root.provider ? ("My field: " + (root.provider.myField || "")) : ""
       color: root.dim
       font.family: root.fontFamily
       font.pixelSize: Style.font.caption
     }
     ```

4. **Test on a fresh VM** before publishing.

### "After omarchy-update, the integration broke"

`omarchy-update` overwrites `/usr/share/omarchy/shell/plugins/agents/Panel.qml` and `Main.qml`. Re-run `./install.sh` to re-apply.

### "I want to add a third centerpiece agent"

This is a significant change. You'd need to:
1. Add a new collector (`bin/omarchy-agent-usage-<newagent>`) following the OpenClaw/Hermes pattern
2. Add its SVG asset to `assets/`
3. Add the new providerId to the `providerIntervalFraction()` dispatch in `targets/Panel.qml`
4. Add a custom block in `Panel.qml`'s `usageSection` (OpenClaw-style or Hermes-style)
5. Add fields to `displayProvider()` in `Main.qml`
6. Update `manifest.json` with the new entry point
7. Update all docs (README, architecture, panel, security, telemetry, troubleshooting) to include the third agent

Open an issue first to discuss scope before starting.

### "I want to add a custom sub-provider's token usage"

The panel includes token-usage displays for MiniMax, Kimi, Qwen (because they have public token-plan APIs). To add another sub-provider:

1. Fork `targets/Panel.qml`.
2. Add a section that calls your provider's API (or reads from a local cache).
3. Display the data in the existing sub-provider block (or add a new block).
4. Add your collector to `bin/`.
5. Update `manifest.json`.
6. Bump the version.

## Modifying the collectors

The collectors (`bin/omarchy-agent-usage-openclaw` and `bin/omarchy-agent-usage-hermes`) are Python 3 scripts with no third-party dependencies. They run as the user and emit JSON.

When modifying:
- Keep the output schema stable. Bump the version in `manifest.json` if you break it.
- The collector is idempotent — running it twice in a row produces the same output (modulo live checks).
- Each collector's state file at `~/.local/state/omarchy/agents/usage/<id>.state.json` is the last-known-good record. On live-check failure, the collector returns this instead of zeros.
- **OpenClaw collector** never reads API key VALUES — only presence.
- **Hermes collector** reads Hermes CLI status, NOT any credentials.
- Test on a non-production machine first. The collectors run as the user; they can read your keys, your trajectory, your PID list.

## Modifying the panel

The panel (`targets/Panel.qml`) is Omarchy's stock QML with our OpenClaw + Hermes blocks inserted. The blocks are marked with `// === OPENCLAW_INTEGRATION_V1 ===` and `// === HERMES_INTEGRATION_V1 ===` at the top of the file.

When modifying:
- Use QML helpers (extract complex bindings to helper functions in the top of the file).
- Test brace balance: `O=$(grep -o '{' $file | wc -l); C=$(grep -o '}' $file | wc -l); [ "$O" = "$C" ] && echo OK`
- Don't add `var` declarations inside inline binding expressions — QML JS treats them as object literals in some contexts, which breaks parsing. Always extract to helper functions.
- Test that Quickshell parses the file: `pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'; sleep 2; pgrep quickshell`
- When adding new clickable elements, always include `hoverEnabled: true` and `cursorShape: Qt.PointingHandCursor` on the MouseArea so they get the pointing-hand cursor like other dock icons.

## Security notes

- The collectors never read API key VALUES — only presence.
- The collectors never execute remote commands.
- The collectors never modify files outside the install paths in `manifest.json`.
- The collectors never escalate privileges.
- The OpenClaw and Hermes rings display gateway state but never invoke `systemctl start/stop/restart` on either gateway.

If a user wants you to do something outside these bounds, push back. See [`docs/security.md`](../docs/security.md) for the full threat model.

## Distribution checklist (before publishing a release)

- [ ] All `*.sh` scripts pass `bash -n` syntax check
- [ ] All Python collectors pass `python3 -m py_compile`
- [ ] QML brace balance verified for both `targets/Panel.qml` and `targets/Main.qml`
- [ ] Zero matches for any personal or proprietary identifiers anywhere in the package (run a grep yourself to set the pattern)
- [ ] `manifest.json` version bumped
- [ ] `CHANGELOG.md` updated (if you create one)
- [ ] Fresh VM test passed: install OpenClaw + Hermes → verify both gateway rings → uninstall round-trip