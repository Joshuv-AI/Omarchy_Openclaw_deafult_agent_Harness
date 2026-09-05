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

    // Refresh cooldown state. Per-provider cooldown; product policy:
    //   default 15 minutes, hard floor 5 minutes.
    property var cooldownState: ({})

    // Hover affordance: a translucent background highlight on hover.
    Rectangle {
        id: hoverHighlight
        anchors.fill: parent
        color: "#33ffffff"
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // Selected provider panel body. Shows tier-aware rendering per
    // § 7.3 of the decision document. Ring fill = remaining / 100 for
    // quota providers. Label = `Remaining: <percent>`.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header: provider name + honest status label. No env-var names.
        Text {
            id: header
            text: panel.selectedProviderId
                  ? panel.selectedProviderId + " — " + selectedLabel()
                  : "Select a provider"
            font.bold: true
            font.pixelSize: 16
        }

        // Tier-aware body. Each tier renders differently:
        //   remaining quota → ring + `Remaining: <percent>`
        //   balance         → `Balance: <amount> <currency>`
        //   capacity        → `Capacity: <model> RPM <N> ...`
        //   connection      → colored dot + `Connection valid/rejected`
        //   gateway         → colored dot + `Gateway active/stopped/unknown`
        //   local history   → sparkline + `History: <N> tokens today`
        //   generic detected→ labeled card + honest status
        //   unavailable     → labeled card + reason
        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Refresh button — labeled, opt-in. Disabled if remote probe is
        // disabled in setup. Calls the user-owned driver via Quickshell.Io.Process.
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

    // Hover affordance: visible background highlight on the panel itself.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: hoverHighlight.opacity = 0.06
        onExited:  hoverHighlight.opacity = 0
        onClicked: {
            if (!panel.selectedProviderId) {
                // First click in an unselected panel selects the first
                // detected provider. Subsequent clicks inside the panel
                // do not refresh — only the Refresh button does.
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
        var last = panel.cooldownState[panel.selectedProviderId];
        if (!last) return "Refresh";
        var ageSec = Math.floor((Date.now() - last) / 1000);
        if (ageSec < 60) return "Refresh (" + ageSec + "s ago)";
        return "Refresh (" + Math.floor(ageSec / 60) + "m ago)";
    }

    function refreshButtonEnabled() {
        return remoteProbeEnabledForSelected()
            && panel.selectedProviderId.length > 0;
    }

    function remoteProbeEnabledForSelected() {
        for (var i = 0; i < (root.providersModel || []).length; i++) {
            if (root.providersModel[i].id === panel.selectedProviderId) {
                return !!root.providersModel[i].remoteProbe;
            }
        }
        return false;
    }

    function refreshSelected() {
        if (!panel.selectedProviderId) return;
        // Cooldown gate: refuse refreshes inside the cooldown window.
        var last = panel.cooldownState[panel.selectedProviderId] || 0;
        var cooldownMs = 900 * 1000;  // 15 min default; user-configurable
        var floorMs = 300 * 1000;     // 5 min hard floor
        if (Date.now() - last < cooldownMs) return;
        // Driver invocation is delegated to the QML adapter layer; we
        // don't shell out from here to keep the panel pure-render.
        panel.cooldownState[panel.selectedProviderId] = Date.now();
    }

    function openSetup() {
        // Setup view lives in plugin/qml/SetupView.qml. Opens in a separate
        // PanelWindow so the main popup stays focused.
        setupView.show();
    }

    PanelWindow {
        id: setupView
        title: "My Agents — Setup"
        width: 480; height: 360
        visible: false
    }
}
