# Ring semantic invariant

Across every quota provider, **ring fill means remaining available
allowance.** Full means more allowance remains.

```
ring fill = remaining / 100
```

When the documented field direction is `used` (Claude), ring fill is:

```
ring fill = (100 - used) / 100
```

with the label `Remaining: <percent>` so the user sees the remaining
direction.

## Per-provider table

| provider | documented field | direction | ring fill = | label = |
|---|---|---|---|---|
| Claude | `five_hour.utilization` | used | (100 - used) / 100 | `Remaining: <percent>` |
| Claude | `seven_day.utilization` | used | (100 - used) / 100 | `Remaining: <percent>` |
| Claude | `seven_day_opus.utilization` | used | (100 - used) / 100 | `Remaining: <percent>` |
| MiniMax | `current_interval_remaining_percent` | remaining | remaining / 100 | `Remaining: <percent>` |
| MiniMax | `current_weekly_remaining_percent` | remaining | remaining / 100 | `Remaining: <percent>` |

Other providers do not render a ring fill because their documented
surface is not a remaining-allowance percentage.

## Regression test

`tests/unit/run_tests.js` group "MiniMax ring-fill invariant" has an
explicit assertion:

```js
const result = normalize.normalizeProvider('minimax', false);
assert.ok(Math.abs(result.ringFill - 0.96) < 1e-9);
assert.ok(result.ringFill > 0.5,
    'REGRESSION: MiniMax ring fill must be remaining/100, not (100-remaining)/100');
```

If the invariant is broken (e.g., the implementation is reverted to
`(100 - remaining) / 100`), the assertion fails with the message
"REGRESSION: MiniMax ring fill must be remaining/100, not
(100-remaining)/100". This is the explicit guard against the
inversion error that was previously identified.

## What the invariant forbids

- A ring with fill = `(100 - remaining) / 100` while the label says
  `Remaining: <percent>` — this would show a near-empty ring for a
  provider with most of its allowance left.
- A ring with fill = `remaining / 100` while the label says
  `Used: <percent>` — this would show a near-full ring for a
  provider that has used most of its allowance.
- Any ring fill derived from `usage.total_tokens` (Grok) — it is
  aggregate used, not remaining against a documented denominator.
- Any ring fill derived from `creditLimit` (Fireworks) without an
  audit-logged per-`type` semantic.
- Any ring fill derived from the Codex 720h-window `limits[].percent`
  — direction is unknown from public OpenAI Codex docs.

## What the invariant permits

- Stale ring fill: the ring is rendered in a desaturated state with
  `Last checked Nm ago · stale`. The fill amount itself is unchanged
  from the last fresh value — the visual treatment changes, the
  number does not.
- Connection-state and gateway-state dots (these are not rings).
- Capacity labeled cap lines (these are not rings).
- Balance labeled currency values (these are not rings).
