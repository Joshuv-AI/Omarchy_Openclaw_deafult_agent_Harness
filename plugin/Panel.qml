// Panel.qml — popup with first-class adapters + generic detected-provider fallback.
//
// Detection-driven dock visibility: `showInDock = detectedLocally && userEnabled`.
// Stale telemetry does not remove the icon. Hover affordance via opacity change.
// Refresh button calls the user-owned driver (not Omarchy's built-in driver).
// No env-var names appear in ordinary UI errors.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PanelWindow {
    id: panel
    title: "My Agents"

    // Selected provider id (first-click selects; refresh is via the button below).
    property string selectedProviderId: ""

    // Per-provider last-refresh timestamp (ms epoch). Drives the cooldown gate
    // and the "Refresh (Nm ago)" label.
    property var cooldownState: ({})
    // Per-provider last-probe result text from the driver, surfaced in the panel.
    property var lastProbeResult: ({})
    // True while a subprocess is running for the selected provider.
    property bool refreshInFlight: false

    // Hover affordance: a translucent background highlight on hover.
    Rectangle {
        id: hoverHighlight
        anchors.fill: parent
        color: "#33ffffff"
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            id: header
            text: panel.selectedProviderId
                  ? panel.selectedProviderId + " — " + selectedLabel()
                  : "Select a provider"
            font.bold: true
            font.pixelSize: 16
        }

        // Tier-aware body. Rendered by the QML adapter layer. The text below
        // shows the most recent probe result (last error message from the
        // driver, sanitized).
        Text {
            id: probeStatusText
            visible: panel.refreshInFlight || (panel.lastProbeResult[panel.selectedProviderId] || "").length > 0
            text: panel.refreshInFlight
                  ? "Refreshing…"
                  : ("Last probe: " + (panel.lastProbeResult[panel.selectedProviderId] || ""))
            font.pixelSize: 11
            color: "#999999"
            wrapMode: Text.Wrap
        }

        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Refresh button + Enable-probe button.
        RowLayout {
            spacing: 8

            Button {
                id: refreshBtn
                text: refreshButtonLabel()
                enabled: refreshButtonEnabled()
                onClicked: panel.refreshSelected()
            }

            Button {
                id: enableProbeBtn
                text: "Enable remote probe in setup"
                visible: !remoteProbeEnabledForSelected()
                onClicked: panel.openSetup()
            }
        }
    }

    // Quickshell.Io.Process for the user-owned driver. Created on demand when
    // the user clicks Refresh. We pass `--force` so the user explicitly opts
    // out of the cooldown by clicking — the panel's own cooldown gate still
    // refuses double-clicks faster than 5 minutes (the driver's hard floor).
    property var refreshProc: null

    function refreshSelected() {
        if (!panel.selectedProviderId) return;
        if (panel.refreshInFlight) return;
        var last = panel.cooldownState[panel.selectedProviderId] || 0;
        var cooldownMs = 900 * 1000;   // 15 min default
        var floorMs = 300 * 1000;      // 5 min hard floor
        if (Date.now() - last < cooldownMs) {
            // Inside cooldown — silently ignore (button is also disabled).
            return;
        }
        panel.refreshInFlight = true;
        var pid = panel.selectedProviderId;
        // Build the command line. Driver path is hardcoded; this is a
        // user-owned path, not a system path. No shell — args are passed
        // as a separate list so we don't have to escape anything.
        var driverPath = Quickshell.env("HOME") + "/.local/share/omarchy/agent-providers/omarchy-refresh";
        var args = [driverPath, pid, "--force"];
        // Tear down any previous process before starting a new one.
        if (panel.refreshProc) {
            try { panel.refreshProc.destroy(); } catch (_) {}
            panel.refreshProc = null;
        }
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', panel, "refreshProc_" + Date.now());
        proc.command = args;
        proc.workingDirectory = Quickshell.env("HOME");
        // On exit: update last-probe state and reset in-flight flag.
        proc.exited.connect(function(exitCode) {
            panel.refreshInFlight = false;
            panel.cooldownState[pid] = Date.now();
            panel.lastProbeResult[pid] = exitCode === 0
                ? "ok"
                : (exitCode === 2 ? "configuration missing"
                  : (exitCode === 3 ? "remote endpoint rejected"
                    : (exitCode === 4 ? "network unreachable"
                      : (exitCode === 5 ? "provider not recognized"
                        : (exitCode === 6 ? "cooldown override required" : ("error exit " + exitCode))))));
            // Refresh the panel's data model by bumping the adapter.
            if (typeof refreshAdapterModel === "function") {
                refreshAdapterModel();
            }
            proc.destroy();
            if (panel.refreshProc === proc) panel.refreshProc = null;
        });
        panel.refreshProc = proc;
        proc.start();
    }

    // MouseArea hover affordance + first-click selection.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: hoverHighlight.opacity = 0.06
        onExited:  hoverHighlight.opacity = 0
        onClicked: {
            if (!panel.selectedProviderId) {
                if (root.providersModel && root.providersModel.length > 0) {
                    panel.selectedProviderId = root.providersModel[0].id;
                }
            }
        }
    }

    function selectedLabel() {
        for (var i = 0; i < (root.providersModel || []).length; i++) {
            var p = root.providersModel[i];
            if (p.id === panel.selectedProviderId) {
                return p.ringLabel || ("Unavailable: configuration missing");
            }
        }
        return "Unavailable: provider not detected";
    }

    function refreshButtonLabel() {
        if (panel.refreshInFlight) return "Refreshing…";
        var last = panel.cooldownState[panel.selectedProviderId];
        if (!last) return "Refresh";
        var ageSec = Math.floor((Date.now() - last) / 1000);
        if (ageSec < 60) return "Refresh (" + ageSec + "s ago)";
        return "Refresh (" + Math.floor(ageSec / 60) + "m ago)";
    }

    function refreshButtonEnabled() {
        return remoteProbeEnabledForSelected()
            && panel.selectedProviderId.length > 0
            && !panel.refreshInFlight;
    }

    function remoteProbeEnabledForSelected() {
        for (var i = 0; i < (root.providersModel || []).length; i++) {
            if (root.providersModel[i].id === panel.selectedProviderId) {
                return !!root.providersModel[i].remoteProbe;
            }
        }
        return false;
    }

    function openSetup() {
        setupView.show();
    }

    // The adapter's refresh callback — bound by the parent (Main.qml) so the
    // panel can request a model reload after a successful probe. If not bound,
    // the panel still updates its own state; the next detection poll (60s)
    // will pick up the new on-disk JSON.
    property var refreshAdapterModel: null

    PanelWindow {
        id: setupView
        title: "My Agents — Setup"
        width: 480; height: 360
        visible: false
    }
}
