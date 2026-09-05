// BarWidget.qml — detected-only provider dock.
//
// Renders one circle per detected provider. Tier-aware: ring fill means
// remaining available allowance (full = more allowance remains). Stale
// telemetry keeps the icon but desaturates the ring. No fabrication.
//
// First click on a provider icon: select/open (matches omarchy.agents
// built-in toggle behavior). Refresh happens via the labeled Refresh
// button inside the Panel.qml popup, not via a second-click timing trick.
//
// Detection: dock visibility is `detectedLocally && userEnabled`. Stale
// telemetry does not remove the icon.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Row {
    id: root
    spacing: 6

    // Source of provider state. We read Omarchy's existing usage JSON files
    // (the collectors write there) plus our own detection signals. We never
    // write to /usr/share/omarchy/ or /usr/bin/ — only to user-owned paths.
    property var providersModel: []
    property var usageFiles: ({
        "claude":    Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/claude.json",
        "codex":     Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/codex.json",
        "fireworks": Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/fireworks.json",
        "openclaw":  Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/openclaw.json",
        "minimax":   Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/minimax.json",
        "kimi":      Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/kimi.json",
        "qwen":      Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/qwen.json",
        "grok":      Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/grok.json",
        "gemini":    Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/gemini.json",
        "hermes":    Quickshell.env("HOME") + "/.local/state/omarchy/agents/usage/hermes.json"
    })

    // Refresh interval — defaults to 60s, configurable per the plugin's
    // manifest schema. We use the panel's `dataRevision` so the dock
    // repaints whenever the adapter layer writes fresh data.
    property int refreshIntervalSec: 60

    Timer {
        interval: root.refreshIntervalSec * 1000
        running: true
        repeat: true
        onTriggered: providersAdapter.refresh()
    }

    // Quickshell.Io.FileView fetcher per provider usage file. We bind to
    // `dataRevision` to guarantee a repaint on every adapter write.
    Repeater {
        model: root.providersModel
        delegate: ProviderCircle {
            providerId: modelData.id
            displayName: modelData.displayName
            record: modelData.record
            lastRemoteProbeAt: modelData.lastRemoteProbeAt
            lastDetectedAt: modelData.lastDetectedAt
            showInDock: modelData.showInDock
            ringLabel: modelData.ringLabel
            ringFill: modelData.ringFill
            tier: modelData.tier
            isStale: modelData.isStale
            enabled: modelData.userEnabled
        }
    }

    // Placeholder adapter access. The adapter layer (plugin/adapters/) is
    // loaded at panel-open time, not at dock-load time, because the dock
    // doesn't need full ring math — it just needs the dock-visibility
    // boolean and the tier/label strings.
    Component {
        id: providersAdapter
        ProvidersAdapter {}
    }
}
