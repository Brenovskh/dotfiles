import QtQuick
import "../modules"
import Quickshell

// One "Label ........ value" cell of the network panel's stats grid, laid out
// like the stock Omarchy network panel (muted label left, value right).
// A copyable cell copies its value to the clipboard on click.
Item {
    id: cell
    required property var root
    property string label: ""
    property string value: "--"
    property color valueColor: root.ink
    property bool copyable: false

    implicitHeight: 18

    UiText {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: cell.label
        color: cell.root.sumi
        font.family: cell.root.mono
        font.pixelSize: 11
    }

    UiText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: cell.value
        color: copyMa.containsMouse ? cell.root.seal : cell.valueColor
        font.family: cell.root.mono
        font.pixelSize: 11
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: copyMa
        anchors.fill: parent
        enabled: cell.copyable && cell.value !== "--"
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: Quickshell.execDetached(["wl-copy", "--", cell.value])
    }
}
