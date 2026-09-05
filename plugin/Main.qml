// Main.qml — plugin root. Pulls the provider model from the adapter
// layer and exposes it to the BarWidget. We re-evaluate the model
// whenever the adapter writes new data, by binding to its `dataRevision`
// property.

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

    // The BarWidget is the entry point per the manifest. We hand it the
    // providersModel so it can iterate. Refresh cadence comes from the
    // adapter's polling.
    BarWidget {
        anchors.fill: parent
        providersModel: pluginRoot.providersModel
        refreshIntervalSec: 60
    }
}
