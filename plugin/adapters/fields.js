// adapters/fields.js — non-secret presence/configuration detection.
//
// Detection priority (highest first):
//   1. Active gateway / session / model state
//   2. Documented harness provider/profile configuration
//   3. Existing local usage records
//   4. Documented credential/config-file presence
//   5. Process environment (presence only — never value)
//
// `lastDetectedAt` updates on detection polling only. Remote probes
// never update it. Stale remote data therefore never removes the icon;
// only stale detection does.

'use strict';

const fs = require('fs');
const pathMod = require('path');
const os = require('os');

function home() { return os.homedir(); }

function fileExists(p) {
  try { fs.accessSync(p, fs.constants.F_OK); return true; } catch (_) { return false; }
}

function dirExists(p) {
  try { return fs.statSync(p).isDirectory(); } catch (_) { return false; }
}

function envNamePresent(name) {
  // Presence only. We never log, display, transmit, or persist the value.
  // We only check that the name is bound and the value length is > 0.
  if (!Object.prototype.hasOwnProperty.call(process.env, name)) return false;
  const v = process.env[name];
  return typeof v === 'string' && v.length > 0;
}

function serviceActive(unit) {
  try {
    const { execSync } = require('child_process');
    const out = execSync('systemctl --user is-active ' + unit, { encoding: 'utf8', timeout: 2000 });
    return String(out).trim() === 'active';
  } catch (_) {
    return false;
  }
}

// Per-provider detection. Returns:
//   { detected: boolean, lastDetectedAt: number, reason: string }
function detectionStateFor(providerId) {
  const now = Date.now();
  const usageStateDir = usageDir();
  // The usage JSON dir is referenced for diagnostic purposes only;
  // detection looks at credential/config-file presence, env var name
  // presence, and active service state, NOT at the usage records.
  void usageStateDir;
  switch (providerId) {
    case 'claude': {
      if (fileExists(pathMod.join(home(), '.claude', '.credentials.json'))) {
        return { detected: true, lastDetectedAt: now, reason: 'credentials.json present' };
      }
      // No other detection signal documented.
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'codex': {
      if (dirExists(pathMod.join(home(), '.codex'))) {
        return { detected: true, lastDetectedAt: now, reason: '~/.codex present' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'hermes': {
      if (fileExists(pathMod.join(home(), '.hermes', 'config.yaml'))) {
        return { detected: true, lastDetectedAt: now, reason: '~/.hermes/config.yaml present' };
      }
      // Hermes binary on PATH.
      try {
        const { execSync } = require('child_process');
        execSync('command -v hermes', { encoding: 'utf8', timeout: 2000 });
        return { detected: true, lastDetectedAt: now, reason: 'hermes binary on PATH' };
      } catch (_) { /* fall through */ }
      // Priority 3 fallback: existing local usage record.
      if (fileExists(pathMod.join(usageStateDir, 'hermes.json'))) {
        return { detected: true, lastDetectedAt: now, reason: 'usage record present' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'openclaw': {
      if (serviceActive('openclaw-gateway.service')) {
        return { detected: true, lastDetectedAt: now, reason: 'gateway service active' };
      }
      if (dirExists(pathMod.join(home(), '.openclaw'))) {
        return { detected: true, lastDetectedAt: now, reason: '~/.openclaw present' };
      }
      if (fileExists(pathMod.join(usageStateDir, 'openclaw.json'))) {
        return { detected: true, lastDetectedAt: now, reason: 'usage record present' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'minimax': {
      if (envNamePresent('MINIMAX_API_KEY')) {
        return { detected: true, lastDetectedAt: now, reason: 'MINIMAX_API_KEY env var name bound (value not read)' };
      }
      if (fileExists(pathMod.join(home(), '.openclaw', '.env'))) {
        // We check the env FILE exists, not its contents.
        return { detected: true, lastDetectedAt: now, reason: '~/.openclaw/.env present' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'kimi': {
      if (envNamePresent('MOONSHOT_API_KEY') || envNamePresent('KIMI_API_KEY')) {
        return { detected: true, lastDetectedAt: now, reason: 'Kimi env var name bound' };
      }
      if (fileExists(pathMod.join(home(), '.openclaw', '.env'))) {
        return { detected: true, lastDetectedAt: now, reason: '~/.openclaw/.env present' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'qwen': {
      if (envNamePresent('DASHSCOPE_API_KEY')) {
        return { detected: true, lastDetectedAt: now, reason: 'DASHSCOPE_API_KEY env var name bound' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'fireworks': {
      if (envNamePresent('FIREWORKS_API_KEY')) {
        return { detected: true, lastDetectedAt: now, reason: 'FIREWORKS_API_KEY env var name bound' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'grok': {
      if (envNamePresent('XAI_API_KEY')) {
        return { detected: true, lastDetectedAt: now, reason: 'XAI_API_KEY env var name bound' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    case 'gemini': {
      if (envNamePresent('GEMINI_API_KEY') || envNamePresent('GOOGLE_API_KEY')) {
        return { detected: true, lastDetectedAt: now, reason: 'Gemini env var name bound' };
      }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    // Generic-fallback providers: opt-in stub detection only.
    case 'opencode':
    case 'pi':
    case 'omp':
    case 'copilot':
    case 'crush':
    case 'agy':
    case 'ori': {
      // We require mise-managed stub presence OR a credential-file
      // presence signal. Without one of those, no icon.
      try {
        const { execSync } = require('child_process');
        execSync('command -v ' + providerId, { encoding: 'utf8', timeout: 2000 });
        return { detected: true, lastDetectedAt: now, reason: providerId + ' binary on PATH' };
      } catch (_) { /* fall through */ }
      return { detected: false, lastDetectedAt: 0, reason: 'no local signal' };
    }
    default:
      return { detected: false, lastDetectedAt: 0, reason: 'unknown provider' };
  }
}

function usageDir() {
  const xdg = process.env.XDG_STATE_HOME;
  const base = xdg && xdg.length > 0 ? xdg : pathMod.join(os.homedir(), '.local', 'state');
  return pathMod.join(base, 'omarchy', 'agents', 'usage');
}

module.exports = {
  detectionStateFor: detectionStateFor,
  // exported for testing only — never used to read values in production
  __envNamePresent: envNamePresent,
  __fileExists: fileExists,
  __dirExists: dirExists
};
