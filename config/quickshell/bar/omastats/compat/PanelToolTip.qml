import QtQuick
import QtQuick.Controls
import "." as Commons

ToolTip {
  id: root
  property color panelForeground: Commons.Color.tooltip.text
  property color panelBackground: Commons.Color.tooltip.background
  property color panelBorder: Commons.Color.tooltip.border
  property string fontFamily: Commons.Style.font.family
  property real fontSize: Commons.Style.font.bodySmall

  delay: 400
  padding: 0

  background: Rectangle {
    color: root.panelBackground
    border.color: root.panelBorder
    border.width: 1
    radius: Commons.Style.cornerRadius
  }

  contentItem: Text {
    textFormat: Text.PlainText
    text: root.text
    color: root.panelForeground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    wrapMode: Text.WordWrap
    leftPadding: Commons.Style.spacing.controlPaddingX
    rightPadding: Commons.Style.spacing.controlPaddingX
    topPadding: Commons.Style.spacing.controlPaddingY
    bottomPadding: Commons.Style.spacing.controlPaddingY
  }
}
