// Main.qml — plugin root. Pulls the provider model from the adapter
// layer and exposes it to the BarWidget. We re-evaluate the model
// whenever the adapter writes new data, by binding to its `dataRevision`
// property. The Panel's refresh action calls back into the adapter so
// the on-disk JSON change is reflected immediately.

import QtQuick
import Quickshell

Item {
    id: pluginRoot

    // Adapter is loaded once. Its `dataRevision` increments on every
    // refresh, triggering the dock to repaint via the binding.
    property var adapter: providersAdapterComp.createObject(null)
    property var providersModel: adapter ? adapter.model : []
    property int dataRevision: adapter ? adapter.dataRevision : 0

    Component {
        id: providersAdapterComp
        ProvidersAdapter {}
    }

    // BarWidget is the entry point per the manifest. We hand it the
    // providersModel so it can iterate. Refresh cadence comes from the
    // adapter's polling.
    BarWidget {
        anchors.fill: parent
        providersModel: pluginRoot.providersModel
        refreshIntervalSec: 60
    }

    // Panel popup. The Panel binds to providersModel for the tier-aware
    // body. After a successful Refresh probe, we bump the adapter's
    // dataRevision so the ring repaints immediately.
    Panel {
        id: panel
        // Hook the panel's refresh callback into the adapter so a
        // successful probe causes an immediate re-read of on-disk JSON.
        Component.onCompleted: {
            panel.refreshAdapterModel = function() {
                if (pluginRoot.adapter && typeof pluginRoot.adapter.refresh === "function") {
                    pluginRoot.adapter.refresh();
                }
            };
        }
    }
}
