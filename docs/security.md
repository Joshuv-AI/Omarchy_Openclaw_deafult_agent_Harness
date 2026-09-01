# Security

This document describes the security model, threat surface, and explicit non-goals for the **OpenClaw + Hermes for Omarchy** integration. The aim is to make clear what this integration does, what it doesn't do, and what an attacker could realistically do to a user who installs it.

## Threat model

A user installs this integration on their personal Omarchy machine. They trust:
- The OpenClaw binary is legitimate.
- The Hermes binary is legitimate (fetched via Nous Research's official installer).
- Omarchy's Quickshell bar and panel system is legitimate.
- The integration only displays status and provides quick-launch actions.

The attacker might attempt to:
- Trick the user into running the install script with malicious options.
- Exploit a bug in the install/uninstall scripts to persist beyond uninstall.
- Inject content into the collector's JSON output to influence the panel.
- Abuse the panel's click handlers to launch unintended commands.

## What we DO

### Filesystem writes (via `sudo` only for /usr/* and /usr/share/omarchy/*)

| Path | Owner | Mode |
|---|---|---|
| `/usr/bin/omarchy-agent-usage-openclaw` | root | 755 |
| `/usr/bin/omarchy-agent-usage-grok` | root | 755 (only installed; active when XAI_API_KEY set) |
| `/usr/bin/omarchy-agent-usage-gemini` | root | 755 (only installed; active when GEMINI_API_KEY set) |
| `/usr/bin/omarchy-agent-usage-hermes` | root | 755 (only installed; active after `` completes) |
| `/usr/bin/omarchy-agent-usage-minimax` | root | 755 (only installed; active when MINIMAX_API_KEY set) |
| `/usr/bin/omarchy-agent-usage-kimi` | root | 755 (only installed; auto-appears when OpenClaw/Hermes uses kimi/* model) |
| `/usr/bin/omarchy-agent-usage-qwen` | root | 755 (only installed; auto-appears when OpenClaw/Hermes uses qwen/* or dashscope/* model — display-only, no setup UI) |
|  | root | 755 (shell-only key-update wrapper for users who want to set MOONSHOT_API_KEY from a script — no panel surface, the panel does not prompt; writes ~/.openclaw/.env atomically via os.replace) |
| `/usr/share/omarchy/shell/plugins/agents/Panel.qml` | root | 644 (overwritten; original backed up as `.openclaw-backup`) |
| `/usr/share/omarchy/shell/plugins/agents/Panel.qml` | root | 644 (overwritten; original backed up as `.openclaw-backup`) |
| `/usr/share/omarchy/shell/plugins/agents/Main.qml` | root | 644 (overwritten; original backed up as `.openclaw-backup`) |
| `/usr/share/omarchy/shell/plugins/agents/assets/openclaw.svg` | root | 644 |
| `/usr/share/omarchy/shell/plugins/agents/assets/openclaw-light.svg` | root | 644 |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | user | 644 |
| `~/.config/omarchy/defaults/agent` | user | 644 |
| `~/.local/state/omarchy/agents/usage/openclaw.json` | user | 600 |
| `~/.local/state/omarchy/agents/usage/openclaw.state.json` | user | 600 |
| `~/.local/state/omarchy/agents/usage/openclaw-token-plan-cache.json` | user | 600 (legacy, currently unused) |

No writes occur outside these paths. `uninstall.sh` reverses everything except user preferences (`~/.config/omarchy/defaults/agent`).

### Subprocess execution (no `sudo`, no remote calls)

## What we NEVER do

- **No sudo escalation tricks.** `install.sh` uses `sudo cp` only for the documented file paths. It does not modify `/etc/sudoers`, `/etc/polkit-1/`, or any other privilege-related config.
- **No service creation.** The collector reads from `systemctl --user is-active` but never invokes `systemctl --user start` or creates new units. Omarchy manages its own services.
- **No /etc/ modifications.** Outside of `/usr/share/omarchy/` (which is owned by Omarchy), we write nothing to `/etc/`.
- **No credential display.** The panel deliberately renders auth text only when `authHelpText` is non-empty (after deleting the orphan `claude/codex/fireworks` collectors, it stays empty). API keys never appear in the UI.
- **No remote command execution.** The collector never reaches out to remote hosts. The only network call (`MiniMax /v1/token_plan/remains`) was removed in v1.0 to keep the integration purely local.
- **No background processes.** The collector is invoked by Omarchy's sweeper. It does not spawn daemons, install launchd/systemd units, or poll on its own.
- **No file outside the documented paths.** No `/tmp/`, no `/var/`, no hidden dotfiles in `$HOME` except `~/.config/omarchy/...` and `~/.local/state/omarchy/...`.

## Explicit non-goals

The following are deliberately NOT supported by this package, and there are no plans to add them:

- **Provider-specific token usage displays for non-sub-provider agents.** OpenClaw's native fields (version, model, gateway, sessions) and Hermes's native fields (CLI status, gateway, uptime) are shown. Sub-providers (MiniMax/Kimi/Qwen) get token-usage displays because they have a public token-plan API. Users who want token-usage display for other agents should fork `targets/Panel.qml` and add their own section.
- **Other agents beyond OpenClaw and Hermes.** This package ships OpenClaw + Hermes as the two centerpiece agents. Codex, Claude, Fireworks are managed by Omarchy itself. Grok / Gemini are opt-in collectors (single-purpose API key probes, no full integration). We don't attempt to integrate any other agent's full CLI surface beyond these.
- **Background services or daemons.** The collectors are invoked by Omarchy's sweeper, period. If we needed to poll more often, we still wouldn't add a daemon — that's a different architectural choice that should belong to a separate package.
- **Privileged operations.** No sudo tricks, no capability escalation, no setuid wrappers.
- **API key storage or transmission.** All API key setup is delegated to `openclaw onboard`. We never read, store, or transmit API keys. `~/.openclaw/.env` is owned by OpenClaw's installer (chmod 600).
- **Gateway control.** We display gateway state but never invoke `systemctl start/stop/restart` on the gateway. The user can do that themselves.
- **Model switching.** We display the active model from the user's OpenClaw telemetry but never override it.

## What an attacker controlling the GitHub source could do

If an attacker compromises this repository and pushes a malicious release:

- They could add malicious code to the collector script (which runs as the user and reads from `~/.openclaw/`).
- They could add malicious code to the patched Panel.qml / Main.qml (which runs as the user inside Quickshell).
- They could modify `install.sh` to execute arbitrary code during install.

**Mitigations:**

- The package is small (~3000 lines). Code review is feasible.
- The collector has no `sudo` in its hot path — `install.sh` uses sudo only for the documented file copies.
- The patched QML files are sandboxed by Quickshell (no arbitrary shell from QML bindings).
- API keys are managed by `openclaw onboard`, not by us — the attacker would still need to phish the user for the key.

**What we recommend:**

- Read the install script before running it.
- Pin to a known-good commit (`git checkout <sha>`).
- The collector's output is a plain JSON file at a known path — review it periodically.

## Reporting vulnerabilities

If you find a security issue in this integration, please open a GitHub issue with the `security` label or contact the maintainers privately. We will respond within 72 hours.

## License

AGPL-3.0. See [`LICENSE`](../LICENSE).
