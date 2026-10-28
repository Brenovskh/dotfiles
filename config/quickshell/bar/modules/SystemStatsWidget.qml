import QtQuick
import Quickshell
import Quickshell.Io

// Combined CPU + Memory bar pill, replacing the separate CpuWidget/MemoryWidget.
// Usage % comes from Theme.qml's existing /proc/stat & /proc/meminfo pollers
// (unchanged, shared with the old widgets); temp/freq/power/GPU/storage detail
// lives in SystemStatsPanel.qml and is only polled while that panel is open.
Item {
    id: rootMod
    required property var root

    visible: implicitWidth > 0.5
    implicitWidth: root.modSystemStats ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modSystemStats ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property int cpuPercent: root.systemCpuPercent
    readonly property int memPercent: root.systemMemPercent
    readonly property var cpuHistory: root.systemCpuHistory
    readonly property int maxSamples: 30
    readonly property string tooltipText: "CPU " + cpuPercent + "%  ·  MEM " + memPercent + "%"

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.barPillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Canvas {
            id: wave
            width: 30
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            property color tint: root.seal
            onTintChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var h = rootMod.cpuHistory
                if (h.length < 2) return

                var maxV = 0.25
                for (var n = 0; n < h.length; n++) if (h[n] > maxV) maxV = h[n]
                maxV = Math.min(1, Math.max(0.25, maxV * 1.15))

                var pts = []
                for (var i = 0; i < h.length; i++) {
                    pts.push({
                        x: (i / (rootMod.maxSamples - 1)) * width,
                        y: height - (h[i] / maxV) * height
                    })
                }

                ctx.beginPath()
                ctx.moveTo(pts[0].x, height)
                ctx.lineTo(pts[0].x, pts[0].y)
                for (var j = 1; j < pts.length; j++) {
                    var cx = (pts[j-1].x + pts[j].x) / 2
                    ctx.bezierCurveTo(cx, pts[j-1].y, cx, pts[j].y, pts[j].x, pts[j].y)
                }
                ctx.lineTo(pts[pts.length-1].x, height)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.12)
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var k = 1; k < pts.length; k++) {
                    var mx = (pts[k-1].x + pts[k].x) / 2
                    ctx.bezierCurveTo(mx, pts[k-1].y, mx, pts[k].y, pts[k].x, pts[k].y)
                }
                ctx.strokeStyle = tint
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"; ctx.lineJoin = "round"
                ctx.stroke()
            }

            Component.onCompleted: requestPaint()
            Connections {
                target: rootMod
                function onCpuHistoryChanged() { wave.requestPaint() }
            }
        }

        // stacked CPU/MEM rows: percent glued right in front of its own
        // bar, same pixel row — color (seal/indigo) is the only label,
        // matching the tooltip's CPU/MEM order
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Row {
                height: 11
                spacing: 4
                UiText {
                    width: 22; height: 11
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: rootMod.cpuPercent + "%"
                    color: root.seal
                    font.family: root.mono; font.pixelSize: 9
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 3; radius: 1.5
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                    Rectangle {
                        width: parent.width * rootMod.cpuPercent / 100
                        height: parent.height; radius: 1.5; color: root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }
            Row {
                height: 11
                spacing: 4
                UiText {
                    width: 22; height: 11
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: rootMod.memPercent + "%"
                    color: root.indigo
                    font.family: root.mono; font.pixelSize: 9
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 3; radius: 1.5
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                    Rectangle {
                        width: parent.width * rootMod.memPercent / 100
                        height: parent.height; radius: 1.5; color: root.indigo
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.systemStatsVisible = !root.systemStatsVisible }
    }
}
