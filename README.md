# OpenClaw for Omarchy

A single-command installer that puts [OpenClaw](https://openclaw.io) inside Omarchy's native agents panel. After running `./install.sh`, an OpenClaw tab appears in the agents panel with live status, and a lobster entry shows up in super space under agents.

## Quick start

```
git clone https://github.com/YOUR_ORG/omarchy-openclaw-harness.git
cd omarchy-openclaw-harness
./install.sh
```

The installer handles everything: detects OpenClaw, fetches it from the official source if missing, runs `openclaw onboard` for API key setup, copies the collector and assets, patches Omarchy's panel files with backups, and registers OpenClaw in the super-space menu.

## Verify

Open the agents panel (top-right). You should see:

- An "OpenClaw" tab in the provider switcher
- Inside: gateway state, version, active model, runtime, Discord status, total sessions (all live)
- A lobster entry under super space, agents

If anything looks wrong, see [`docs/troubleshooting.md`](docs/troubleshooting.md).

## Uninstall

```
./uninstall.sh
```

Restores the original Omarchy panel files from backup. Reverses everything except your explicit default-agent choice.

## After Omarchy updates

Omarchy updates can overwrite the panel files we patch. The installer keeps `.openclaw-backup` copies of the originals. Just re-run `./install.sh` to re-apply.

## Repo structure

```
omarchy-openclaw-harness/
  LICENSE                              AGPL-3.0
  README.md                            this file
  manifest.json                        plugin metadata, schema, permissions
  install.sh                           idempotent installer
  uninstall.sh                         reversible uninstaller
  bin/
    omarchy-agent-usage-openclaw       collector script (Python, no deps)
  assets/
    openclaw.svg                       lobster icon (dark)
    openclaw-light.svg                 lobster icon (light)
  targets/
    Panel.qml                          Omarchy stock + OpenClaw display block
    Main.qml                           Omarchy stock + displayProvider wiring
  docs/
    architecture.md                    how the pieces fit together
    security.md                        threat model + explicit non-goals
    telemetry.md                       what data flows where
    troubleshooting.md                  common failures and fixes
  skill/
    SKILL.md                           AI-agent maintenance guide
```

## Adding your own provider usage

The panel deliberately does not include provider-specific token usage (see `docs/security.md`). If you want to add your own (e.g. a per-provider quota display), the extension is set up to make this easy:

1. Add the data fields you want to the collector (`bin/omarchy-agent-usage-openclaw`). The collector emits whatever JSON you put in its `build_record` output.
2. Forward those fields in `Main.qml`'s `displayProvider` function.
3. Add a panel section in `Panel.qml`'s OpenClaw custom block (inside the existing `usageSection` Column).

The pattern is documented in `skill/SKILL.md` under "Add a new field to the panel."

## Security

The collector reads user-local OpenClaw state and emits JSON. It does not call external APIs, does not store credentials, does not run privileged operations. The full threat model is in [`docs/security.md`](docs/security.md).

## License

AGPL-3.0. See [`LICENSE`](LICENSE).