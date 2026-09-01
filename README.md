# OpenClaw + Hermes for Omarchy

A drop-in Omarchy integration that puts a **modified agent dock icon** in the Omarchy bar — a row of brand-colored progress rings that show what's actually happening with your agents and the models they're using.

The headline: **OpenClaw and Hermes rings show gateway activity** (state, runtime, model, sessions). Every other icon (MiniMax, Kimi, Qwen, Grok, Gemini) shows **usage / rate-limit** data. Click any ring to open the agents panel focused on that provider.

After running `./install.sh`:

- The dock shows **one colored ring per connected provider** — OpenClaw and Hermes rings are gateway-activity rings, sub-provider rings (MiniMax, Kimi, Qwen) are usage rings
- The popup shows live data for the selected provider (gateway state for OpenClaw/Hermes; token plan / connection mode for sub-providers)
- OpenClaw and Hermes entries appear in the super-space **agents** menu

## The modified agent dock icon — what it is

This integration replaces Omarchy's default single-icon agent entry with a **horizontal dock of colored rings**, one per provider:

```
   ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
   │  │  │  │  │  │  │  │  │  │   <- provider icon (greied-out center)
   │  │  │  │  │  │  │  │  │  │
   └──┘  └──┘  └──┘  └──┘  └──┘
   ╲╱╲   ╲╱╲   ╲╱╲   ╲╱╲   ╲╱╲  <- progress ring (brand color)
```

The ring fill amount and color encoding **differ by provider type**:

| Ring type | Providers | What the fill means |
|---|---|---|
| **Gateway ring** | **OpenClaw, Hermes** | Ring fills when the agent's gateway is `active`. Empty = gateway stopped. This is **unique to OpenClaw and Hermes** — no other icon in the dock reports gateway state. |
| **Usage ring** | MiniMax, Kimi, Qwen | Ring fills with token-usage percent (5h + weekly). Empty = no API key, no quota, or probe failed. |
| **Connection ring** | Grok, Gemini | Ring fills when the API key is accepted by the provider. Empty = key missing or rejected. |

Double-clicking the dock row toggles all rings between **brand-colored** (default) and **dim grey** (`#666`).

## What shows when you click OpenClaw or Hermes

**OpenClaw ring** (purple `#7C3AED`):
- Gateway state (active / stopped / unknown) with colored dot
- Version (OpenClaw build string)
- Active model (e.g. `minimax/MiniMax-M3`)
- Runtime line: Node version, PID, uptime
- Discord status (active / not running)
- Total sessions (lifetime)

**Hermes ring** (gold `#D4AF37`):
- Hermes version
- Hermes CLI status (agent, auth, platform, gateway)
- Gateway uptime
- Hermes process PID

When the OpenClaw gateway is offline, the popup collapses to three lines (`○ Gateway offline`, `Runtime: offline`, `Discord: offline`); the rest stays hidden until the gateway comes back.

When Hermes is connected but its `gateway` service isn't running, the ring stays empty — start the gateway with `hermes gateway` to fill it.

## Quick start

```
git clone https://github.com/Joshuv-AI/Omarchy_modified_agent_dock_icon-OC_Hermes_harness.git
cd Omarchy_modified_agent_dock_icon-OC_Hermes_harness
./install.sh
```

The installer:
1. Detects OpenClaw and Hermes — fetches from official sources if missing
2. Runs `openclaw onboard` for OpenClaw API key setup (auto-sets `MINIMAX_API_KEY` in `~/.openclaw/.env`)
3. Optionally prompts for Hermes setup (`hermes setup --portal`)
4. Copies the collectors (`bin/omarchy-agent-usage-*`) and SVG assets to `/usr/share/omarchy/shell/plugins/agents/`
5. Patches Omarchy's `Panel.qml` and `Main.qml` (backing up originals as `.openclaw-backup`)
6. Registers OpenClaw + Hermes entries in the super-space agents submenu
7. Optionally sets OpenClaw as the default agent

## Verify

Open the agents panel (top-right dock row). You should see:

- **OpenClaw ring** (purple) — fills when OpenClaw's gateway is active; click to see gateway state, runtime, Discord, sessions, model
- **Hermes ring** (gold) — fills when Hermes's gateway is active; click to see Hermes CLI status, gateway uptime, PID
- **Sub-provider rings** — appear only when OpenClaw/Hermes is using that model:
  - MiniMax (red `#FF0000`) — 5h + weekly token plan
  - Kimi (orange) — token-usage or connection-mode probe
  - Qwen (purple `#8B5CF6`) — single Bearer-auth `/models` probe
- **Optional Grok / Gemini rings** — appear when the corresponding API key env var is set

If anything looks wrong, see [`docs/troubleshooting.md`](docs/troubleshooting.md).

## Why the gateway-ring feature is unique

Other icons in the dock (Bluetooth, Wi-Fi, volume, etc.) are passive system indicators. The OpenClaw and Hermes rings are **active agent status** — they reflect whether your AI agent's gateway (the long-running process that handles requests) is up or down at a glance. This is the dock-level signal that nothing else in your bar provides.

When the ring is empty:
- **OpenClaw ring empty** → OpenClaw's gateway isn't running. Start it: `omarchy start` (or `systemctl --user start openclaw-gateway.service`).
- **Hermes ring empty** → Hermes's gateway isn't running. Start it: `hermes gateway`.
- **Sub-provider ring empty** → API key missing or account blocked (check the provider's console — the panel won't prompt).

## Uninstall

```
./uninstall.sh
```

Restores the original Omarchy panel files from `.openclaw-backup`. Reverses everything except your explicit default-agent choice.

## After Omarchy updates

Omarchy updates can overwrite the panel files we patch. The installer keeps `.openclaw-backup` copies of the originals. Just re-run `./install.sh` to re-apply.

## Repo structure

```
omarchy-agent-panel-repo/
  LICENSE                              AGPL-3.0
  README.md                            this file
  manifest.json                        plugin metadata, schema, permissions
  install.sh                           idempotent installer
  uninstall.sh                         reversible uninstaller
  bin/
    omarchy-agent-usage-openclaw       collector: OpenClaw gateway + telemetry
    omarchy-agent-usage-hermes         collector: Hermes CLI status + gateway
    omarchy-agent-usage-minimax        collector: MiniMax 5h + weekly token plan
    omarchy-agent-usage-kimi           collector: Kimi token-usage / connection probe
    omarchy-agent-usage-qwen           collector: Qwen Bearer-auth /models probe
    omarchy-agent-usage-grok           collector (opt-in): xAI Grok rate limits
    omarchy-agent-usage-gemini         collector (opt-in): Google Gemini rate limits
    omarchy-set-kimi-key               shell-only MOONSHOT_API_KEY updater (display-only panel never prompts)
  assets/
    openclaw.svg                       lobster icon (dark)
    openclaw-light.svg                 lobster icon (light)
    hermes.svg                          wing icon (dark) — Nous Hermes messenger symbol
    minimax.svg, kimi.svg, qwen.svg    sub-provider brand icons
    grok.svg, gemini.svg, claude.svg, codex.svg, codex-light.svg, fireworks.svg, omp.svg, opencode.svg, pi.svg, copilot.svg, crush.svg
  targets/
    Panel.qml                          Omarchy stock + gateway rings + MiniMax usage block
    Main.qml                           Omarchy stock + displayProvider() forwards for both agents
    manifest.json                      Agent panel manifest with 6+ enabled providers + 60s refresh default
  docs/
    architecture.md                    how the pieces fit together
    panel.md                           dock design, gateway ring details, refresh model
    security.md                        threat model + explicit non-goals
    telemetry.md                       what each collector reads/writes
    troubleshooting.md                  common failures and fixes
  skill/
    SKILL.md                           AI-agent maintenance guide (covers OpenClaw + Hermes)
```

## Adding your own provider usage

The panel deliberately does not include provider-specific token usage for non-MiniMax providers (see [`docs/security.md`](docs/security.md)). If you want to add your own (e.g. a per-provider quota display), the extension is set up to make this easy:

1. Add the data fields you want to the collector (`bin/omarchy-agent-usage-<provider>`). The collector emits whatever JSON you put in its `build_record` output.
2. Forward those fields in `Main.qml`'s `displayProvider` function.
3. Add a panel section in `Panel.qml` (inside the existing `usageSection` Column).

The pattern is documented in [`skill/SKILL.md`](skill/SKILL.md) under "Add a new field to the panel."

## Security

Collectors read user-local OpenClaw / Hermes state and emit JSON. They do not call external APIs (except `minimax`, `grok`, `gemini`, `kimi`, `qwen` which only call their own provider endpoints when their API key is set). They do not store credentials, do not run privileged operations. The full threat model is in [`docs/security.md`](docs/security.md).

## License

AGPL-3.0. See [`LICENSE`](LICENSE).