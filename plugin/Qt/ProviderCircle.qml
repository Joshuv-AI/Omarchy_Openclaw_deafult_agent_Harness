// ProviderCircle.qml — single dock icon. Tier-aware rendering.
// Ring fill = remaining / 100 (full = more allowance remains). Stale
// telemetry desaturates the ring. Hover affordance is via opacity
// change. Click selects the provider (first-click behavior, not refresh).

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
    property string tier: "unavailable" // remainingQuota | balance | capacity | connection | gateway | localHistory | genericDetected | unavailable
    property bool isStale: false
    property bool enabled: false

    // Invisible if not detected or disabled. We use `visible: false`
    // rather than `opacity: 0` so the dock skips layout entirely.
    visible: showInDock && enabled

    // Ring color by tier. Distinct visual grammar per category.
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

    // Stale visual treatment: desaturate the ring. The icon stays, the
    // user can see it's stale; the value cannot be mistaken for fresh.
    property color effectiveRingColor: isStale
        ? Qt.hsla(ringColor.hslHue, ringColor.hslSaturation * 0.3, ringColor.hslLightness, 0.5)
        : ringColor

    // Hover affordance: opacity lift on hover.
    property real hoverOpacity: 1.0
    Behavior on hoverOpacity { NumberAnimation { duration: 120 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: circle.hoverOpacity = 1.15
        onExited:  circle.hoverOpacity = 1.0
        onClicked: {
            // First click selects. Refresh is via the labeled button
            // inside Panel.qml — not via a second-click timing trick.
            panelRoot.selectedProviderId = circle.providerId;
        }
    }

    // Ring (Shape with PathArc). Stale = desaturated. fill = ringFill.
    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeColor: circle.effectiveRingColor
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            // Background ring (full circle, low alpha)
            PathAngleArc {
                centerX: circle.width / 2
                centerY: circle.height / 2
                radius: circle.width / 2 - 3
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: circle.effectiveRingColor
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
    }

    // Center icon: provider name first letter, opacity modulated by hover.
    Text {
        anchors.centerIn: parent
        text: circle.displayName.length > 0 ? circle.displayName.charAt(0).toUpperCase() : "?"
        font.pixelSize: 12
        font.bold: true
        color: circle.effectiveRingColor
        opacity: circle.hoverOpacity >= 1.1 ? 1.0 : 0.85
    }
}
