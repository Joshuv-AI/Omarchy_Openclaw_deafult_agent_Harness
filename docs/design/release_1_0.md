# Release 1.0 — My Agents user plugin

This document describes the Release 1.0 architecture for the My Agents
user plugin that replaces Omarchy's `omarchy.agents` dock icon via the
supported `omarchy plugin clone` path. It supersedes the previous
package-file patching installer.

## Architecture summary

| layer | location | role |
|---|---|---|
| Plugin code | `~/.config/omarchy/plugins/xensei.agents/` | QML entry points, adapter layer, providers registry |
| User-owned driver | `~/.local/share/omarchy/agent-providers/omarchy-refresh` | Subprocess driver that invokes collectors |
| User-owned collectors | `~/.local/share/omarchy/agent-providers/collectors/` | Per-provider probes (MiniMax, Kimi, Qwen, Grok, Gemini, Hermes) |
| Cache | `~/.cache/omarchy/agent-providers/` | Per-provider cooldown + last-probe state |
| Usage JSON (read) | `~/.local/state/omarchy/agents/usage/*.json` | Omarchy collectors + our collectors write here |

**No file is ever written to `/usr/share/omarchy/` or `/usr/bin/`.**

## Dock-visibility invariant

`showInDock = detectedLocally && userEnabled`.

- `detectedLocally` is set by non-secret presence/configuration signals
  in priority order (active service → harness config → usage record →
  credential file → env var name).
- `userEnabled` defaults to true for detected providers; the user can
  hide a provider in the setup view.
- **Stale telemetry never removes the icon.** A provider with stale
  remote data stays in the dock with a desaturated ring and a
  `Last checked Nm ago · stale` label.

## Tier-aware rendering

Each provider renders into one of seven tier categories:

| tier | visual | label |
|---|---|---|
| `remainingQuota` | green ring | `Remaining: <percent>` |
| `balance` | gold ring or labeled value | `Balance: <amount> <currency>` |
| `capacity` | blue ring or labeled cap line | `Capacity: <model> RPM <N> · RPD <N> · TPM <N> · TPD <N>` |
| `connection` | gray-blue dot | `Connection valid` / `Connection rejected` |
| `gateway` | purple dot | `Gateway active` / `Gateway stopped` / `Gateway unknown` |
| `localHistory` | gray ring (small) | `History: <N> tokens today` |
| `genericDetected` | labeled card | `Configuration detected` / `Active model detected` / `No limit data exposed` |
| `unavailable` | labeled card | `Unavailable: <reason>` |

These tiers never conflate. A balance provider does not render a quota
ring; a connection provider does not render a balance bar; a quota
provider does not render a connection dot. Each tier has its own visual
grammar (ring color, dot color, label form).

## Ring-fill invariant (the regression test target)

For every quota tier, ring fill means remaining allowance.

```
ring fill = remaining / 100
```

When the documented field direction is `used` (Claude), ring fill is
`(100 - used) / 100` and the label still says `Remaining: <percent>`.

The unit test `tests/unit/run_tests.js` has a regression assertion that
rejects any inversion. A MiniMax record with `intervalRemainingPct: 96`
must yield `ringFill = 0.96`, not `0.04`.

## Refresh interaction

- First click on a provider icon: select/open (no refresh).
- Refresh button inside the panel popup: invokes the user-owned driver.
- Cooldown: 15 minutes default, 5-minute hard floor. Documented as a
  product policy, not as provider documentation.
- Cooldown gate refuses refreshes inside the window unless `--force`.

## Detection signals (non-secret presence only)

For each provider, detection inspects:

1. Active gateway/session/model state (e.g., `systemctl --user is-active`).
2. Harness provider/profile configuration (e.g., OpenClaw's config dir).
3. Existing local usage records at `~/.local/state/omarchy/agents/usage/`.
4. Documented credential/config-file presence.
5. Process env var NAME presence (never the value).

The detection never reads env var values, never reads credential file
contents, and never transmits any signal off-machine.

## Per-provider release status

| provider | first-class? | release 1.0 capability | gating condition |
|---|---|---|---|
| Claude | yes | `Remaining: <percent>` ring fill from OAuth usage | audit-logged direction (used → remaining) |
| Codex | yes | local-history only; 720h-window as labeled value | direction unknown from public docs; no ring fill |
| Fireworks | yes | labeled balance; no ring fill | `creditLimit` semantics per `type` not audit-logged |
| OpenClaw | yes | gateway state + active model | local systemd service check |
| Hermes | yes | gateway state only (`running` / `stopped` / `unknown`) | deferred `agent` / `auth` / `platform` / `version` until redacted fixtures committed |
| MiniMax | yes | `Remaining: <percent>` ring fill from `/v1/token_plan/remains` | audit-logged direction (remaining) |
| Kimi | yes | labeled balance; no ring fill | no documented denominator |
| Qwen | yes | `Connection valid` / `Connection rejected` | no documented quota surface |
| Grok | yes | `Capacity: <model> ...` labeled cap line | `usage.total_tokens` is aggregate-used, not remaining against a documented denominator |
| Gemini | yes | `Connection valid` / `Connection rejected` | rate-limit headers opt-in v2, deferred |
| OpenCode, Pi, OMP, Copilot, Crush, AGY, Ori | generic-fallback | labeled card with honest status | none — first-class surface TBD |

## Deferred / non-claims

- Visual hot-reload proof is deferred (no screen-capture tool available
  in the test environment).
- `Quickshell.Io.Process` runtime proof is deferred.
- Codex `limits[].percent` direction is unknown — no ring fill ships
  for Codex in Release 1.0.
- Kimi, Fireworks ring fills from `creditLimit` are gated on audit-log
  entries that lock the per-`type` semantics.
- Gemini rate-limit header fill is gated on a future audit pass.
- MiniMax ships only if the audit-log + fixture-based parser pass.

## Update survival

The plugin, its data, and its driver live entirely outside
`/usr/share/omarchy/`. `omarchy-update` cannot affect any of these paths.
The plugin survives any upstream Omarchy upgrade.
