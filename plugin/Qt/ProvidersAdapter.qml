// ProvidersAdapter.qml — exposed to QML via require('adapters/normalize.js').
// Re-evaluates the provider model on every timer tick and on every
// collector write. Keeps presence and freshness as separate timestamps:
//
//   lastDetectedAt      — updated only by detection polling (no remote calls)
//   lastRemoteProbeAt   — updated only by successful remote probes
//
// `showInDock = detectedLocally && userEnabled` — stale never removes icon.

import QtQuick

QtObject {
    id: adapter

    // The current provider model. Each entry contains:
    //   { id, displayName, tier, ringLabel, ringFill, isStale,
    //     showInDock, userEnabled, remoteProbe, lastDetectedAt,
    //     lastRemoteProbeAt, record }
    property var model: []

    // Bumped on every model write; Quickshell repaints the dock via binding.
    property int dataRevision: 0

    // Detection polling cadence. 60s default.
    property int detectIntervalSec: 60

    Timer {
        interval: adapter.detectIntervalSec * 1000
        running: true
        repeat: true
        onTriggered: adapter.refresh()
    }

    function refresh() {
        // Re-read provider state. The actual file parsing happens in
        // plugin/adapters/normalize.js, which is loaded as a module.
        // From QML we call into JS via Qt.include(). The result is a
        // fresh model array.
        try {
            var raw = Qt.include("adapters/normalize.js");
            var fields = Qt.include("adapters/fields.js");
            var providers = computeProviders(raw, fields);
            adapter.model = providers;
            adapter.dataRevision = adapter.dataRevision + 1;
        } catch (e) {
            // Don't crash the dock; keep the previous model and surface
            // the error in diagnostics only.
            console.warn("ProvidersAdapter refresh failed:", e);
        }
    }

    function computeProviders(raw, fields) {
        // Per-provider list of (id, displayName, record, lastDetectedAt,
        // lastRemoteProbeAt, userEnabled, remoteProbe). See § 4–7 of
        // the decision document for the rules.
        var providers = [
            { id: "openclaw",  displayName: "OpenClaw"  },
            { id: "hermes",    displayName: "Hermes"    },
            { id: "minimax",   displayName: "MiniMax"   },
            { id: "kimi",      displayName: "Kimi"      },
            { id: "qwen",      displayName: "Qwen"      },
            { id: "claude",    displayName: "Claude"    },
            { id: "codex",     displayName: "Codex"     },
            { id: "fireworks", displayName: "Fireworks" },
            { id: "grok",      displayName: "Grok"      },
            { id: "gemini",    displayName: "Gemini"    },
            // Generic fallback entries: only appear when something detects them.
            { id: "opencode",  displayName: "OpenCode",  generic: true },
            { id: "pi",        displayName: "Pi",        generic: true },
            { id: "omp",       displayName: "OMP",       generic: true },
            { id: "copilot",   displayName: "Copilot",   generic: true },
            { id: "crush",     displayName: "Crush",     generic: true },
            { id: "agy",       displayName: "AGY",       generic: true },
            { id: "ori",       displayName: "Ori",       generic: true }
        ];

        // Apply normalize + classify + dock-visibility rules per provider.
        var out = [];
        for (var i = 0; i < providers.length; i++) {
            var p = providers[i];
            var classified = raw.normalizeProvider(p.id, p.generic === true);
            var det = fields.detectionStateFor(p.id);
            var detectedLocally = det.detected;
            var userEnabled = true;     // user override lives in setup; default true for detected providers
            var remoteProbe = false;    // opt-in only; default off
            var showInDock = detectedLocally && userEnabled;
            out.push({
                id: p.id,
                displayName: p.displayName,
                tier: classified.tier,
                ringLabel: classified.ringLabel,
                ringFill: classified.ringFill,
                isStale: classified.isStale,
                showInDock: showInDock,
                userEnabled: userEnabled,
                remoteProbe: remoteProbe,
                lastDetectedAt: det.lastDetectedAt,
                lastRemoteProbeAt: classified.lastRemoteProbeAt,
                record: classified.record
            });
        }
        return out;
    }
}
