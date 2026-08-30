---
name: openclaw-omarchy-integration-maintenance
description: >
  Maintain, debug, and extend the OpenClaw for Omarchy integration. Use when
  the user reports issues with the OpenClaw tab in Omarchy's agents panel,
  asks to modify the integration, or wants to understand how it fits into
  the Omarchy shell. Covers collector behavior, panel patch points, menu
  registration, and reinstall/uninstall flows.
---

# OpenClaw for Omarchy — Maintenance Skill

When a user asks about this integration, follow this skill. The integration is small (~3000 lines) but touches multiple Omarchy subsystems.

## When this skill applies

- "The OpenClaw tab is missing" / "panel doesn't show OpenClaw"
- "OpenClaw tab shows wrong values" / "stale data"
- "How do I uninstall?" / "How do I reinstall?"
- "I want to add a new field to the panel"
- "After `omarchy-update`, the integration broke"
- "The red bar is back"
- "How do I add a custom provider's token usage?"

## What this integration does

Single-line summary: install OpenClaw and integrate it into Omarchy's agents panel so OpenClaw appears as a tab with live status.

Full architecture: see [`docs/architecture.md`](../docs/architecture.md).

## File map (the maintainable parts)

| Path | Role | Safe to edit? |
|---|---|---|
| `bin/omarchy-agent-usage-openclaw` | Collector script (Python) | Yes — see "Modifying the collector" below |
| `targets/Panel.qml` | Omarchy's panel with OpenClaw block inserted | Yes — but only the OpenClaw section (lines ~680-720) |
| `targets/Main.qml` | Omarchy's displayProvider with OpenClaw fields forwarded | Yes — only inside the `displayProvider()` function |
| `assets/openclaw.svg` | Lobster icon (dark) | Yes |
| `assets/openclaw-light.svg` | Lobster icon (light) | Yes |
| `install.sh` | Idempotent installer | Yes — but test on a clean VM first |
| `uninstall.sh` | Reversible uninstaller | Yes — but test on a clean VM first |
| `manifest.json` | Plugin metadata | Yes — bump version on changes |
| `docs/*.md` | Documentation | Yes |
| `~/.openclaw/.env` | API keys (managed by `openclaw onboard`, NOT us) | Never touch |

## Common user requests

### "The panel doesn't show OpenClaw"

1. Run `./install.sh` to verify it's installed.
2. Check `~/.local/state/omarchy/agents/usage/openclaw.json` — should be valid JSON ≥ 1 KB.
3. If empty: `sudo /usr/bin/omarchy-agent-usage-update` to regenerate.
4. If error in JSON: run `/usr/bin/omarchy-agent-usage-openclaw --force 2>&1` to see the traceback.
5. Restart Quickshell: `pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'`.

Full troubleshooting: [`docs/troubleshooting.md`](../docs/troubleshooting.md).

### "Add a new field to the panel"

The collector emits JSON. The panel reads specific fields. To add a field:

1. **In the collector** (`bin/omarchy-agent-usage-openclaw`):
   - Compute the value in `build_record()`.
   - Add it to the returned dict (e.g., `"myField": compute_my_field()`).
   - Update the schema in `manifest.json`.

2. **In `Main.qml`** (`targets/Main.qml`):
   - Inside `displayProvider()`, add the field to the returned object:
     ```javascript
     myField: String(record.myField || ""),
     ```

3. **In `Panel.qml`** (`targets/Panel.qml`):
   - Inside the OpenClaw custom block (after the existing Text elements), add:
     ```qml
     Text {
       visible: usageSection.isOpenClaw
       text: root.provider ? ("My field: " + (root.provider.myField || "")) : ""
       color: root.dim
       font.family: root.fontFamily
       font.pixelSize: Style.font.caption
     }
     ```

4. **Test on a fresh VM** before publishing.

### "After omarchy-update, the integration broke"

`omarchy-update` overwrites `/usr/share/omarchy/shell/plugins/agents/Panel.qml` and `Main.qml`. Re-run `./install.sh` to re-apply.

### "I want to add a custom provider's token usage"

The panel deliberately does NOT include provider-specific token usage — see "Explicit non-goals" in [`docs/security.md`](../docs/security.md). The integration is OpenClaw-native only.

To add your own:
1. Fork `targets/Panel.qml`.
2. Add a section that calls your provider's API (or reads from a local cache).
3. Display the data in the existing OpenClaw custom block.
4. Bump the version in `manifest.json`.

## Modifying the collector

The collector (`bin/omarchy-agent-usage-openclaw`) is a Python 3 script with no third-party dependencies. It runs as the user, reads from `~/.openclaw/`, and emits JSON.

When modifying:
- Keep the output schema stable. Bump the version in `manifest.json` if you break it.
- The collector is idempotent — running it twice in a row produces the same output (modulo live checks).
- The state file at `~/.local/state/omarchy/agents/usage/openclaw.state.json` is the last-known-good record. On live-check failure, the collector returns this instead of zeros.
- Test on a non-production machine first. The collector runs as the user; it can read your keys, your trajectory, your PID list.

## Modifying the panel

The panel (`targets/Panel.qml`) is Omarchy's stock QML with our OpenClaw block inserted. The OpenClaw block is marked with `// === OPENCLAW_INTEGRATION_V1 ===` at the top of the file.

When modifying:
- Use QML helpers (extract complex bindings to helper functions in the top of the file).
- Test brace balance: `O=$(grep -o '{' $file | wc -l); C=$(grep -o '}' $file | wc -l); [ "$O" = "$C" ] && echo OK`
- Don't add `var` declarations inside inline binding expressions — QML JS treats them as object literals in some contexts, which breaks parsing. Always extract to helper functions.
- Test that Quickshell parses the file: `pkill -TERM -f 'quickshell -n -p /usr/share/omarchy/shell'; sleep 2; pgrep quickshell`

## Security notes

- The collector never reads API key VALUES — only presence.
- The collector never executes remote commands.
- The collector never modifies files outside the install paths in `manifest.json`.
- The collector never escalates privileges.

If a user wants you to do something outside these bounds, push back. See [`docs/security.md`](../docs/security.md) for the full threat model.

## Distribution checklist (before publishing a release)

- [ ] All `*.sh` scripts pass `bash -n` syntax check
- [ ] Python collector passes `python3 -m py_compile`
- [ ] QML brace balance verified for both `targets/Panel.qml` and `targets/Main.qml`
- [ ] Zero matches for any personal or proprietary identifiers anywhere in the package (run a grep yourself to set the pattern)
- [ ] `manifest.json` version bumped
- [ ] `CHANGELOG.md` updated (if you create one)
- [ ] Fresh VM test passed (install + verify + uninstall round-trip)
