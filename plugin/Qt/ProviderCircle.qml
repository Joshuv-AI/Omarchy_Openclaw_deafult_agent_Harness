// ProviderCircle.qml — single dock icon. Tier-aware rendering.
// Ring fill = remaining / 100 (full = more allowance remains).
// STALE TELEMETRY DOES NOT DRAW A CONSUMER FILL ARC — a stale ring
// renders only a desaturated gray "no fresh data" outline. Stale values
// are NEVER rendered as fresh quota fills, even when desaturated, because
// a stale percentage could be wildly wrong. Click selects the provider
// (first-click behavior, not refresh).

import QtQuick
import QtQuick.Shapes

Item {
    id: circle
    width: 32
    height: 32

    property string providerId: ""
    property string displayName: ""
    property var record: null
    property real lastRemoteProbeAt: 0
    property real lastDetectedAt: 0
    property bool showInDock: false
    property string ringLabel: ""
    property real ringFill: 0.0     // 0..1
    property string tier: "unavailable"
    property bool isStale: false
    property bool enabled: false

    // Invisible if not detected or disabled.
    visible: showInDock && enabled

    // Ring color by tier.
    property color ringColor: {
        switch (tier) {
            case "remainingQuota": return "#22cc88";  // green
            case "balance":        return "#ddaa44";  // gold
            case "capacity":       return "#7799cc";  // blue
            case "connection":     return "#88aabb";  // gray-blue
            case "gateway":        return "#bb88cc";  // purple
            case "localHistory":   return "#aaaaaa";  // gray
            case "genericDetected":return "#999999";  // neutral gray
            case "unavailable":    return "#555555";  // dark gray
            default:               return "#555555";
        }
    }

    // Stale visual treatment: when isStale is true and the tier is
    // remainingQuota, balance, capacity, connection, or gateway — we do
    // NOT draw the consumer fill arc. We draw only a desaturated gray
    // "no fresh data" outline plus a small badge dot. The user can see
    // the icon exists but cannot mistake stale for fresh.
    property bool suppressFill: isStale && (
        tier === "remainingQuota" ||
        tier === "balance" ||
        tier === "capacity" ||
        tier === "connection" ||
        tier === "gateway"
    )

    property real hoverOpacity: 1.0
    Behavior on hoverOpacity { NumberAnimation { duration: 120 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: circle.hoverOpacity = 1.15
        onExited:  circle.hoverOpacity = 1.0
        onClicked: {
            panelRoot.selectedProviderId = circle.providerId;
        }
    }

    Shape {
        anchors.fill: parent
        antialiasing: true

        // Background ring outline (always visible — identifies the slot).
        ShapePath {
            strokeColor: suppressFill ? "#666666" : circle.ringColor
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            opacity: circle.suppressFill ? 0.4 : 0.25

            PathAngleArc {
                centerX: circle.width / 2
                centerY: circle.height / 2
                radius: circle.width / 2 - 3
                startAngle: -90
                sweepAngle: 360
            }
        }

        // Consumer fill arc — only drawn when data is fresh AND tier
        // supports it. Stale data shows only the outline above.
        ShapePath {
            visible: !circle.suppressFill
            strokeColor: circle.ringColor
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: circle.width / 2
                centerY: circle.height / 2
                radius: circle.width / 2 - 3
                startAngle: -90
                sweepAngle: circle.ringFill * 360
            }
        }

        // Stale badge — small dot at the top-right indicating "no fresh
        // data" without claiming a fill amount.
        ShapePath {
            visible: circle.suppressFill
            strokeColor: "transparent"
            fillColor: "#cc4444"

            PathMove { x: circle.width - 6; y: 6 }
            PathArc {
                x: circle.width - 6; y: 6
                radiusX: 3; radiusY: 3
                direction: PathArc.Clockwise
            }
        }
    }

    // Center icon: provider name first letter.
    Text {
        anchors.centerIn: parent
        text: circle.displayName.length > 0 ? circle.displayName.charAt(0).toUpperCase() : "?"
        font.pixelSize: 12
        font.bold: true
        color: circle.suppressFill ? "#888888" : circle.ringColor
        opacity: circle.hoverOpacity >= 1.1 ? 1.0 : 0.85
    }
}
