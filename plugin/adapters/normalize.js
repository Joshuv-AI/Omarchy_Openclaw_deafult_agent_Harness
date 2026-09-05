// adapters/normalize.js — pure-function adapter from installed JSON
// records to canonical provider model. Tier-aware: classifies each
// provider into one of:
//   remainingQuota | balance | capacity | connection | gateway |
//   localHistory | genericDetected | unavailable
//
// Ring fill = remaining / 100. Full = more allowance remains. Label
// always says `Remaining: <percent>` for quota tiers. Stale telemetry
// does not change tier — it only adds `isStale: true`.
//
// We never fabricate values. If a field direction is unknown, the tier
// is `unavailable` and the label explains why. The CodeX `limits[].percent`
// direction is unknown from public OpenAI Codex docs; Codex renders
// as a labeled value, not as a ring fill.

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

// Usage JSON dir: ~/.local/state/omarchy/agents/usage (existing path).
function usageDir() {
  const xdg = process.env.XDG_STATE_HOME;
  const base = xdg && xdg.length > 0 ? xdg : path.join(os.homedir(), '.local', 'state');
  return path.join(base, 'omarchy', 'agents', 'usage');
}

function readUsageJson(providerId) {
  const p = path.join(usageDir(), providerId + '.json');
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch (_) {
    return null;
  }
}

// Tier classification per provider. Each branch returns:
//   { tier, ringLabel, ringFill, isStale, record, lastRemoteProbeAt }
//
// isStale is set when lastRemoteProbeAt is older than the cooldown
// (default 15 min). The dock icon stays in either case; only the visual
// treatment changes (desaturated ring, `Last checked Nm ago · stale`).

function classifyClaude(record, now, cooldownMs) {
  // Direction per audit-log: five_hour.utilization, seven_day.utilization,
  // seven_day_opus.utilization are `used` (NOT remaining). Ring fill =
  // (100 - used) / 100. Label = `Remaining: <percent>`.
  if (!record) return null;
  if (!record.limits || record.limits.length === 0) {
    return {
      tier: 'localHistory',
      ringLabel: historyLabel(record),
      ringFill: 0.0,
      isStale: false,
      record: record,
      lastRemoteProbeAt: 0
    };
  }
  const lim = record.limits[0];
  // Omarchy's on-disk record stores percent as a 0..1 fraction (verified in
  // Gate A on codex.json where percent: 0.85 means 85%). The Claude
  // collector preserves the documented `used` direction. We accept either
  // 0..1 fraction or 0..100 percentage and normalize to 0..100.
  let used = Number(lim.percent);
  if (!isFinite(used)) {
    return {
      tier: 'unavailable',
      ringLabel: 'Unavailable: limit value unreadable',
      ringFill: 0.0,
      isStale: false,
      record: record,
      lastRemoteProbeAt: 0
    };
  }
  if (used > 0 && used <= 1) {
    used = used * 100;
  }
  const remaining = 100 - used;
  const updatedAt = Date.parse(record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  return {
    tier: 'remainingQuota',
    ringLabel: 'Remaining: ' + Math.round(remaining) + '%',
    ringFill: remaining / 100,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyCodex(record, now, cooldownMs) {
  // CodeX `limits[].percent` direction is UNKNOWN from public OpenAI docs.
  // No ring fill. Render as labeled value + local-history sparkline.
  if (!record) return null;
  const updatedAt = Date.parse(record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  const limit = (record.limits && record.limits[0]) || null;
  const label = limit
    ? ('720h window: ' + limit.label + ' = ' + String(limit.percent))
    : historyLabel(record);
  return {
    tier: 'localHistory',
    ringLabel: label,
    ringFill: 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyFireworks(record, now, cooldownMs) {
  // No documented creditLimit semantics per type in this audit pass.
  // Render balance as labeled value. No ring fill from creditLimit.
  if (!record) return null;
  const updatedAt = Date.parse(record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  const tier = record.tierLabel ? record.tierLabel : 'unknown';
  return {
    tier: 'balance',
    ringLabel: 'Balance: configuration ' + tier.toLowerCase() + ' — remote probe disabled',
    ringFill: 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyOpenclaw(record, now, cooldownMs) {
  if (!record) return null;
  const updatedAt = Date.parse(record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  const state = record.gatewayState || 'unknown';
  return {
    tier: 'gateway',
    ringLabel: 'Gateway ' + state + ' · model: ' + (record.activeModel || '—'),
    ringFill: state === 'active' ? 1.0 : 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyHermes(record, now, cooldownMs) {
  if (!record) return null;
  const updatedAt = Date.parse(record.updatedAt || 0);
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  // Release 1.0: gateway state only. Three states: running, stopped, unknown.
  const raw = (record.gatewayState || 'unknown').toLowerCase();
  let state = 'unknown';
  if (raw === 'running' || raw === 'active') state = 'running';
  else if (raw === 'stopped' || raw === 'inactive') state = 'stopped';
  return {
    tier: 'gateway',
    ringLabel: 'Hermes gateway ' + state,
    ringFill: state === 'running' ? 1.0 : 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyMiniMax(record, now, cooldownMs) {
  // intervalRemainingPct is `remaining` per the audit-log entry.
  // Ring fill = remaining / 100. Label = `Remaining: <percent>`.
  if (!record) return null;
  const updatedAt = Date.parse(record.minimaxFetchedAt || record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  const plan = record.minimaxTokenPlan || {};
  const general = plan.general || {};
  const intervalRemaining = Number(general.intervalRemainingPct);
  if (!isFinite(intervalRemaining)) {
    return {
      tier: 'unavailable',
      ringLabel: 'Unavailable: interval remaining percentage not present',
      ringFill: 0.0,
      isStale: isStale,
      record: record,
      lastRemoteProbeAt: updatedAt
    };
  }
  return {
    tier: 'remainingQuota',
    ringLabel: 'Remaining: ' + Math.round(intervalRemaining) + '% · 5h',
    ringFill: intervalRemaining / 100,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyKimi(record, now, cooldownMs) {
  // No documented denominator. Render balance as labeled value if remote probe enabled.
  if (!record) return null;
  const updatedAt = Date.parse(record.kimiFetchedAt || record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  return {
    tier: 'balance',
    ringLabel: 'Balance: configuration ' + ((record.kimiAvailable ? 'detected' : 'missing')) + ' — remote probe disabled',
    ringFill: 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyQwen(record, now, cooldownMs) {
  if (!record) return null;
  const updatedAt = Date.parse(record.fetchedAt || record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  return {
    tier: 'connection',
    ringLabel: 'Connection ' + (record.qwenAvailable ? 'valid' : 'rejected') + ' · region ' + (record.qwenBaseUrl ? new URL(record.qwenBaseUrl).hostname : 'unknown'),
    ringFill: record.qwenAvailable ? 1.0 : 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyGrok(record, now, cooldownMs) {
  // No documented remaining-percent. Render capacity caps as labeled values only.
  if (!record) return null;
  const updatedAt = Date.parse(record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  return {
    tier: 'capacity',
    ringLabel: 'Capacity: connection ' + (record.ready ? 'valid' : 'rejected') + ' — see Grok per-resource caps',
    ringFill: 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyGemini(record, now, cooldownMs) {
  // No documented remaining-percent on /v1beta/models. Connection only.
  if (!record) return null;
  const updatedAt = Date.parse(record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  return {
    tier: 'connection',
    ringLabel: 'Connection ' + (record.ready ? 'valid' : 'rejected') + ' · /v1beta/models',
    ringFill: 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function classifyGeneric(providerId, record, now, cooldownMs) {
  // Generic detected-provider fallback. Pick the highest-priority local
  // signal available. No ring fill, no quota, no balance.
  if (!record) return null;
  const updatedAt = Date.parse(record.updatedAt || '');
  const isStale = !isFinite(updatedAt) || (now - updatedAt) > cooldownMs;
  let label;
  if (record.activeModel && String(record.activeModel).length > 0) {
    label = 'Active model detected: ' + record.activeModel;
  } else if (record.installed || record.ready) {
    label = 'Configuration detected';
  } else {
    label = 'No limit data exposed';
  }
  return {
    tier: 'genericDetected',
    ringLabel: label,
    ringFill: 0.0,
    isStale: isStale,
    record: record,
    lastRemoteProbeAt: updatedAt
  };
}

function historyLabel(record) {
  if (!record) return 'History: no data';
  const today = record.todayTotalTokens || 0;
  return 'History: ' + today.toLocaleString() + ' tokens today';
}

const CLASSIFIERS = {
  claude:    classifyClaude,
  codex:     classifyCodex,
  fireworks: classifyFireworks,
  openclaw:  classifyOpenclaw,
  hermes:    classifyHermes,
  minimax:   classifyMiniMax,
  kimi:      classifyKimi,
  qwen:      classifyQwen,
  grok:      classifyGrok,
  gemini:    classifyGemini,
};

function normalizeProvider(providerId, isGeneric) {
  const record = readUsageJson(providerId);
  const now = Date.now();
  const cooldownMs = 900 * 1000;  // 15 min default; matches manifest default
  if (isGeneric) {
    return classifyGeneric(providerId, record, now, cooldownMs) || {
      tier: 'unavailable',
      ringLabel: 'Unavailable: provider not detected',
      ringFill: 0.0,
      isStale: false,
      record: null,
      lastRemoteProbeAt: 0
    };
  }
  const fn = CLASSIFIERS[providerId];
  if (!fn) return {
    tier: 'unavailable',
    ringLabel: 'Unavailable: unknown provider ' + providerId,
    ringFill: 0.0,
    isStale: false,
    record: null,
    lastRemoteProbeAt: 0
  };
  const result = fn(record, now, cooldownMs);
  if (!result) return {
    tier: 'unavailable',
    ringLabel: 'Unavailable: usage record not present on this machine',
    ringFill: 0.0,
    isStale: false,
    record: null,
    lastRemoteProbeAt: 0
  };
  return result;
}

module.exports = {
  normalizeProvider: normalizeProvider,
  usageDir: usageDir,
  readUsageJson: readUsageJson
};
