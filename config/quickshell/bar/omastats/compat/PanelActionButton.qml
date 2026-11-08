import QtQuick
import "." as Commons

Rectangle {
  id: root
  property string iconText: ""
  property string tooltipText: ""
  property color foreground: Commons.Color.foreground
  property color hoverColor: foreground
  property string fontFamily: Commons.Style.font.family
  property real fontSize: Commons.Style.font.icon
  property real size: Math.round(Math.max(Commons.Style.space(22), fontSize + Commons.Style.spacing.sm * 2)) | 1
  property bool focusable: false
  property bool hasCursor: false
  property bool bordered: false

  signal clicked()
  signal hovered(bool isHovered)

  readonly property bool _hot: (mouse.containsMouse || root.hasCursor) && root.enabled

  implicitWidth: size
  implicitHeight: size
  radius: Commons.Style.cornerRadius
  color: _hot ? Commons.Style.hoverFillFor(hoverColor, hoverColor) : "transparent"
  border.width: bordered ? 1 : 0
  border.color: Commons.Util.alpha(foreground, _hot ? 0.35 : 0.18)
  Behavior on color { ColorAnimation { duration: 60 } }

  Text {
    textFormat: Text.PlainText
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    text: root.iconText
    color: root.enabled ? (root._hot ? root.hoverColor : root.foreground) : Qt.darker(root.foreground, 2.0)
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: root.enabled
    onContainsMouseChanged: root.hovered(containsMouse)
    onClicked: root.clicked()
  }

  Commons.PanelToolTip {
    visible: root.tooltipText !== "" && mouse.containsMouse
    text: root.tooltipText
    fontFamily: root.fontFamily
  }
}
