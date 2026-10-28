import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

// World clock: a pinned list of cities' current time + offset from local.
// Concept ported from the "io.github.olivoil.world-clock" Omarchy plugin
// (github.com/olivoil/omarchy-world-clock, MIT) — that plugin is a compiled
// Rust binary with its own native popup UI, so only the idea (pinned city
// list, time + day/offset readout) is ported; this is a fresh QML build
// using this bar's own card/grid idioms. Data comes from Theme.qml's
// worldClockData (one `date` process call per refresh, TZ env per city).
PanelWindow {
    id: wcPopup
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-world-clock"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property real reveal: root.worldClockVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.worldClockVisible ? 160 : 120
            easing.type: root.worldClockVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.worldClockVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.worldClockVisible = false }

    function offsetLabel(mins) {
        if (mins === 0) return "same time"
        const sign = mins > 0 ? "+" : "-"
        const abs = Math.abs(mins)
        const h = Math.floor(abs / 60), m = abs % 60
        return sign + h + "h" + (m > 0 ? " " + m + "m" : "")
    }

    function dayLabel(dayDiff) {
        if (dayDiff === 0) return "Today"
        if (dayDiff === 1) return "Tomorrow"
        if (dayDiff === -1) return "Yesterday"
        return dayDiff > 0 ? ("+" + dayDiff + "d") : (dayDiff + "d")
    }

    Rectangle {
        id: card
        width: 460
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: wcPopup.reveal
        focus: root.worldClockVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.worldClockVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Item {
                width: parent.width
                height: 20
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "WORLD CLOCK"
                    color: root.ink; font.family: root.mono; font.pixelSize: 12
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: wcCloseMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: wcCloseMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.worldClockVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Grid {
                width: parent.width
                columns: 3
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: root.worldClockCities.length
                    delegate: Item {
                        required property int index
                        readonly property var city: root.worldClockCities[index]
                        readonly property var entry: index < root.worldClockData.length ? root.worldClockData[index] : null
                        width: (parent.width - 24) / 3
                        height: 52

                        Item {
                            width: parent.width; height: 14
                            Image {
                                id: flagImg
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 10
                                source: Qt.resolvedUrl("../assets/flags/" + city.flag + ".svg")
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                            }
                            Rectangle {
                                anchors.fill: flagImg
                                radius: 2
                                color: "transparent"
                                border.color: root.pillBorder
                                border.width: 1
                            }
                            UiText {
                                anchors.left: flagImg.right; anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: city.name
                                color: root.ink; font.family: root.mono; font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width - flagImg.width - 6 - abbrevLbl.width - 6
                            }
                            UiText {
                                id: abbrevLbl
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: entry ? entry.abbrev : ""
                                color: root.sumiHi; font.family: root.mono; font.pixelSize: 9
                            }
                        }

                        UiText {
                            anchors.top: parent.top; anchors.topMargin: 16
                            text: entry ? entry.time : "--:--"
                            color: root.seal
                            font.family: root.mono; font.pixelSize: 20; font.weight: Font.Medium
                        }

                        UiText {
                            anchors.bottom: parent.bottom
                            text: entry ? (wcPopup.dayLabel(entry.dayDiff) + "  ·  " + wcPopup.offsetLabel(entry.diffMinutes)) : ""
                            color: root.sumi
                            font.family: root.mono; font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: if (visible) root.worldClockRefresh()
}
