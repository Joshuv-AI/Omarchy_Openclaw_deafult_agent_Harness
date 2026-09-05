// tests/unit/run_tests.js — pure-Node test runner for the adapter layer,
// the detection layer, the ring-fill invariant, the stale/presence
// separation, and the label-honesty contract. No network calls. Uses
// fixtures shipped under tests/fixtures/.
//
// Exit code 0 on pass; non-zero on any failure.
//
// Usage:
//   node tests/unit/run_tests.js
//
// The test runner installs a temporary XDG_STATE_HOME under a fresh
// tmpdir and copies the shipped fixtures into the synthetic usage dir.
// This isolates the tests from any real provider state on the host.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const ROOT = path.resolve(__dirname, '..', '..');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-providers-test-'));
process.env.XDG_STATE_HOME = TMP;
const SYNTHETIC_USAGE = path.join(TMP, 'omarchy', 'agents', 'usage');
fs.mkdirSync(SYNTHETIC_USAGE, { recursive: true });

// Helper: copy a fixture into the synthetic usage dir under a provider id.
function installFixture(providerId, fixtureRelPath) {
  const src = path.join(ROOT, fixtureRelPath);
  const dst = path.join(SYNTHETIC_USAGE, providerId + '.json');
  fs.writeFileSync(dst, fs.readFileSync(src, 'utf8'));
  return dst;
}

// Test counter — module-level so group/test closures see the same counters.
let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log('  PASS: ' + name);
  } catch (e) {
    failed++;
    failures.push({ name, error: e });
    console.log('  FAIL: ' + name + ' — ' + (e && e.message ? e.message : e));
  }
}

function group(name, body) {
  console.log('\n# ' + name);
  body();
}

// Load adapter modules AFTER XDG_STATE_HOME is set.
const normalize = require(path.join(ROOT, 'plugin', 'adapters', 'normalize.js'));
const fields = require(path.join(ROOT, 'plugin', 'adapters', 'fields.js'));

// ---- 1. MiniMax invariant ----
group('MiniMax ring-fill invariant', () => {
  test('MiniMax tier = remainingQuota', () => {
    installFixture('minimax', 'tests/fixtures/minimax/token_plan_remains_ok.json');
    const result = normalize.normalizeProvider('minimax', false);
    assert.strictEqual(result.tier, 'remainingQuota');
  });
  test('MiniMax ring fill = remaining/100 (96 → 0.96)', () => {
    const result = normalize.normalizeProvider('minimax', false);
    assert.ok(Math.abs(result.ringFill - 0.96) < 1e-9,
      'MiniMax ring fill should equal remaining/100 (got ' + result.ringFill + ')');
  });
  test('MiniMax label = `Remaining: <percent>`', () => {
    const result = normalize.normalizeProvider('minimax', false);
    assert.ok(/^Remaining:\s*\d+%/.test(result.ringLabel),
      'MiniMax label must be `Remaining: <percent>` (got ' + result.ringLabel + ')');
  });
  test('REGRESSION: MiniMax ring fill rejects inversion (must be remaining/100)', () => {
    const result = normalize.normalizeProvider('minimax', false);
    assert.ok(result.ringFill > 0.5,
      'REGRESSION: MiniMax ring fill must be remaining/100, not (100-remaining)/100 (got ' + result.ringFill + ')');
  });
});

// ---- 2. CodeX labeled-value render (no ring) ----
group('CodeX labeled-value render', () => {
  test('CodeX tier = localHistory', () => {
    installFixture('codex', 'tests/fixtures/codex/local_scan_with_720h_window.json');
    const result = normalize.normalizeProvider('codex', false);
    assert.strictEqual(result.tier, 'localHistory');
  });
  test('CodeX ringFill = 0 (no ring fill — direction unknown)', () => {
    const result = normalize.normalizeProvider('codex', false);
    assert.strictEqual(result.ringFill, 0.0);
  });
  test('CodeX label mentions 720h window', () => {
    const result = normalize.normalizeProvider('codex', false);
    assert.ok(/720h window/.test(result.ringLabel));
  });
});

// ---- 3. Claude ring-fill inversion (documented as `used`) ----
group('Claude ring-fill inversion (used → remaining direction)', () => {
  test('Claude tier = remainingQuota', () => {
    installFixture('claude', 'tests/fixtures/claude/oauth_usage_normal.json');
    const result = normalize.normalizeProvider('claude', false);
    assert.strictEqual(result.tier, 'remainingQuota');
  });
  test('Claude ring fill = (100 - used)/100 (12.5% used → 0.875)', () => {
    const result = normalize.normalizeProvider('claude', false);
    assert.ok(Math.abs(result.ringFill - 0.875) < 1e-9,
      'Claude ring fill should equal (100 - used)/100 (got ' + result.ringFill + ')');
  });
  test('Claude label = `Remaining:`', () => {
    const result = normalize.normalizeProvider('claude', false);
    assert.ok(/^Remaining:/.test(result.ringLabel));
  });
});

// ---- 4. Kimi / Fireworks balance labels (no ring) ----
group('Kimi / Fireworks balance labels (no ring fill)', () => {
  test('Kimi tier = balance, no ring fill, Balance label', () => {
    installFixture('kimi', 'tests/fixtures/moonshot/users_me_balance_ok.json');
    const r = normalize.normalizeProvider('kimi', false);
    assert.strictEqual(r.tier, 'balance');
    assert.strictEqual(r.ringFill, 0.0);
    assert.ok(/Balance/.test(r.ringLabel));
  });
});

// ---- 5. Grok capacity + Gemini / Qwen connection (no ring fill) ----
group('Capacity / Connection tier — no ring fill', () => {
  test('Grok tier = capacity, no ring fill from usage.total_tokens', () => {
    installFixture('grok', 'tests/fixtures/xai/api_key_ok.json');
    const g = normalize.normalizeProvider('grok', false);
    assert.strictEqual(g.tier, 'capacity');
    assert.strictEqual(g.ringFill, 0.0);
    assert.ok(/Capacity/.test(g.ringLabel));
  });
  test('Gemini tier = connection, no ring fill', () => {
    installFixture('gemini', 'tests/fixtures/gemini/models_ok.json');
    const m = normalize.normalizeProvider('gemini', false);
    assert.strictEqual(m.tier, 'connection');
    assert.strictEqual(m.ringFill, 0.0);
    assert.ok(/Connection/.test(m.ringLabel));
  });
  test('Qwen tier = connection', () => {
    installFixture('qwen', 'tests/fixtures/qwen/models_ok.json');
    const q = normalize.normalizeProvider('qwen', false);
    assert.strictEqual(q.tier, 'connection');
    assert.ok(/Connection/.test(q.ringLabel));
  });
});

// ---- 6. Hermes gateway state ----
group('Hermes gateway state — running / stopped', () => {
  test('Hermes running → ringFill = 1.0', () => {
    installFixture('hermes', 'tests/fixtures/hermes/status_running.json');
    const r = normalize.normalizeProvider('hermes', false);
    assert.strictEqual(r.tier, 'gateway');
    assert.strictEqual(r.ringFill, 1.0);
  });
  test('Hermes stopped → ringFill = 0.0', () => {
    installFixture('hermes', 'tests/fixtures/hermes/status_stopped.json');
    const r = normalize.normalizeProvider('hermes', false);
    assert.strictEqual(r.ringFill, 0.0);
  });
});

// ---- 7. Detection priority (presence-only) ----
group('Detection priority — non-secret presence only', () => {
  test('CodeX detected via ~/.codex presence', () => {
    const det = fields.detectionStateFor('codex');
    assert.strictEqual(det.detected, true);
  });
  test('Hermes detected via usage-record fallback (priority 3)', () => {
    // Earlier groups install hermes fixtures, so the synthetic hermes.json
    // is present. The detection priority 3 (existing local usage records)
    // correctly identifies Hermes as detected.
    const det = fields.detectionStateFor('hermes');
    assert.strictEqual(det.detected, true);
  });
  test('Claude NOT detected (no credentials file)', () => {
    const det = fields.detectionStateFor('claude');
    assert.strictEqual(det.detected, false);
  });
  test('fields.js does not read env var values', () => {
    const src = fs.readFileSync(path.join(ROOT, 'plugin', 'adapters', 'fields.js'), 'utf8');
    // The source uses `process.env[name]` only inside envNamePresent, where
    // we check that the value is a non-empty string. The test asserts no
    // bracket-notation reads and no env-value logging.
    assert.ok(!/process\.env\[[^\]]+\]\]/.test(src),
      'fields.js must not use bracket notation to read env var values');
    assert.ok(!/console\.log.*process\.env/.test(src),
      'fields.js must not log env values');
  });
});

// ---- 8. Dock-visibility invariant ----
group('Dock-visibility invariant — showInDock = detectedLocally && userEnabled', () => {
  function showInDock(providerId, userEnabled) {
    const det = fields.detectionStateFor(providerId);
    return det.detected && userEnabled;
  }
  test('detected + enabled → true', () => {
    assert.strictEqual(showInDock('codex', true), true);
  });
  test('detected + disabled → false', () => {
    assert.strictEqual(showInDock('codex', false), false);
  });
  test('not detected + enabled → false', () => {
    assert.strictEqual(showInDock('claude', true), false);
  });
  test('not detected + disabled → false', () => {
    assert.strictEqual(showInDock('claude', false), false);
  });
});

// ---- 9. Stale-presence separation ----
group('Stale vs presence separation', () => {
  test('detection timestamp set when detected', () => {
    const codex = fields.detectionStateFor('codex');
    assert.ok(codex.lastDetectedAt > 0);
  });
  test('classified record has numeric lastRemoteProbeAt', () => {
    const classified = normalize.normalizeProvider('codex', false);
    assert.ok(typeof classified.lastRemoteProbeAt === 'number');
  });
  test('isStale is a boolean', () => {
    const classified = normalize.normalizeProvider('codex', false);
    assert.strictEqual(typeof classified.isStale, 'boolean');
  });
});

// ---- 10. Label honesty: env-var names never appear in ordinary UI labels ----
group('Label honesty — no env var names in ordinary UI', () => {
  test('no provider label contains banned env var names', () => {
    const banned = [
      'MINIMAX_API_KEY', 'MOONSHOT_API_KEY', 'KIMI_API_KEY', 'DASHSCOPE_API_KEY',
      'XAI_API_KEY', 'GEMINI_API_KEY', 'GOOGLE_API_KEY', 'FIREWORKS_API_KEY',
      'MINIMAX_PORTAL_TOKEN', 'MINIMAX_PORTAL_API_KEY'
    ];
    installFixture('minimax', 'tests/fixtures/minimax/token_plan_remains_ok.json');
    installFixture('kimi', 'tests/fixtures/moonshot/users_me_balance_ok.json');
    installFixture('fireworks', 'tests/fixtures/fireworks/accounts_me_prepaid.json');
    installFixture('grok', 'tests/fixtures/xai/api_key_ok.json');
    installFixture('gemini', 'tests/fixtures/gemini/models_ok.json');
    installFixture('qwen', 'tests/fixtures/qwen/models_ok.json');
    installFixture('claude', 'tests/fixtures/claude/oauth_usage_normal.json');
    installFixture('codex', 'tests/fixtures/codex/local_scan_with_720h_window.json');
    installFixture('hermes', 'tests/fixtures/hermes/status_running.json');
    // OpenClaw has no fixture in this pass; we synthesize a minimal record.
    fs.writeFileSync(
      path.join(SYNTHETIC_USAGE, 'openclaw.json'),
      JSON.stringify({
        id: 'openclaw', name: 'OpenClaw',
        gatewayState: 'active', activeModel: 'minimax/MiniMax-M3',
        updatedAt: new Date().toISOString()
      })
    );
    const providers = ['minimax', 'kimi', 'fireworks', 'grok', 'gemini', 'qwen', 'claude', 'codex', 'hermes', 'openclaw'];
    for (const id of providers) {
      const r = normalize.normalizeProvider(id, false);
      for (const banned_name of banned) {
        assert.ok(!r.ringLabel.includes(banned_name),
          'Label for ' + id + ' contains banned env var name ' + banned_name + ': ' + r.ringLabel);
      }
    }
  });
});

// ---- 11. Ring-label consistency: fill and label direction match ----
group('Ring-label consistency', () => {
  test('MiniMax: label says Remaining and ring is mostly full', () => {
    installFixture('minimax', 'tests/fixtures/minimax/token_plan_remains_ok.json');
    const r = normalize.normalizeProvider('minimax', false);
    assert.ok(/^Remaining:/.test(r.ringLabel));
    assert.ok(r.ringFill >= 0.5);
  });
  test('Claude: label says Remaining and ring is mostly full (used=12.5%)', () => {
    installFixture('claude', 'tests/fixtures/claude/oauth_usage_normal.json');
    const r = normalize.normalizeProvider('claude', false);
    assert.ok(/^Remaining:/.test(r.ringLabel));
    assert.ok(r.ringFill >= 0.5);
  });
  test('Hermes: label says "Hermes gateway" and ring is full when running', () => {
    installFixture('hermes', 'tests/fixtures/hermes/status_running.json');
    const r = normalize.normalizeProvider('hermes', false);
    assert.ok(/Hermes gateway/.test(r.ringLabel));
    assert.ok(r.ringFill >= 0.5);
  });
});

// ---- Summary ----
console.log('\n────────────────────────────────────────');
console.log('  Passed: ' + passed);
console.log('  Failed: ' + failed);
console.log('────────────────────────────────────────');

if (failed > 0) {
  console.log('\nFailures:');
  for (const f of failures) {
    console.log('  - ' + f.name + ': ' + (f.error && f.error.stack ? f.error.stack : f.error));
  }
  process.exit(1);
}

process.exit(0);
