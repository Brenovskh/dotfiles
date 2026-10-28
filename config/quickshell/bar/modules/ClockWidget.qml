import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property date now: new Date()

    function pad(n) { return n < 10 ? "0" + n : String(n) }

    // Active bar-label text, driven by Theme.qml's clock format ring
    // (right-click walks it). Qt has no ISO-week token, so 'ww' is replaced
    // with the real ISO week before Qt.formatDateTime runs — same trick the
    // stock Omarchy clock plugin uses.
    readonly property string labelStr: {
        var fmt = String(root.clockFormat)
        if (fmt.indexOf("ww") !== -1)
            fmt = fmt.replace(/ww/g, pad(root.isoWeekNumber(now)))
        return Qt.formatDateTime(now, fmt)
    }

    implicitWidth: label.implicitWidth
    implicitHeight: 28

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: rootMod.now = new Date()
    }

    UiText {
        id: label
        anchors.centerIn: parent
        text: rootMod.labelStr
        color: root.ink
        font.family: root.mono
        font.pixelSize: 12
        font.letterSpacing: 1
    }

    Process {
        id: tzRunner
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation omarchy-menu-timezone 2>/dev/null"]
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (e) => {
            if (e.button === Qt.LeftButton) {
                root.toggleCalendar();                   // open/close the calendar
            } else if (e.button === Qt.RightButton) {
                if (e.modifiers & Qt.ControlModifier) {
                    tzRunner.running = false;            // Ctrl+right: system timezone picker
                    tzRunner.running = true;
                } else {
                    root.cycleClockFormat();             // right: walk the label format ring
                }
            } else if (e.button === Qt.MiddleButton) {
                root.worldClockVisible = !root.worldClockVisible;   // world clock
            }
        }
    }
}
