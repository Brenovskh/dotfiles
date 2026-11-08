import QtQuick
import "." as Commons

// Bar-side stand-in for omarchy-shell's WidgetButton: sizing, press feedback,
// clicks, and hover tooltips routed through quickshell-dots' own tooltip
// (Theme.showTooltip), so OmaStats' BarReadout runs unchanged.
Item {
  id: root

  property var bar: null
  property string text: ""
  property string fontFamily: Commons.Style.font.family
  property real fontSize: Commons.Style.font.body
  property color foreground: Commons.Color.theme ? Commons.Color.theme.ink : Commons.Color.foreground
  property color activeColor: Commons.Color.urgent
  property bool active: false
  property real horizontalMargin: 8.5
  property real verticalPadding: 6
  property real fixedWidth: -1
  property real fixedHeight: -1
  property bool labelVisible: true
  property bool hasVisualContent: text !== ""
  property bool interactive: true
  property bool pressable: true
  property string tooltipText: ""

  signal pressed(int button)
  signal wheelMoved(int delta)

  readonly property var theme: Commons.Color.theme
  readonly property bool vertical: false
  readonly property int barSize: Commons.Style.bar.sizeHorizontal
  readonly property real scaledHorizontalMargin: Commons.Style.spaceReal(horizontalMargin)
  readonly property real scaledVerticalPadding: Commons.Style.spaceReal(verticalPadding)
  readonly property bool tooltipHovered: mouseArea.containsMouse
  property real pressScale: root.pressable && mouseArea.pressed ? 0.9 : 1
  Behavior on pressScale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  implicitWidth: fixedWidth > 0 ? fixedWidth : Math.max(12, scaledHorizontalMargin * 2)
  implicitHeight: fixedHeight > 0 ? fixedHeight : barSize

  function hideTip() {
    tipTimer.stop()
    if (theme && theme.hideTooltip) theme.hideTooltip(root)
  }

  // Keep a visible tooltip live while the figures under it change.
  onTooltipTextChanged: if (theme && theme.tooltipOwner === root) theme.tooltipText = tooltipText
  onVisibleChanged: if (!visible) hideTip()
  Component.onDestruction: hideTip()

  Timer {
    id: tipTimer
    interval: 320
    onTriggered: {
      if (!root.tooltipText || !root.theme || !root.theme.showTooltip) return
      var top = root.mapToItem(null, root.width / 2, 0)
      var bottom = root.mapToItem(null, root.width / 2, root.height)
      root.theme.showTooltip(root.tooltipText, top.x, top.y, bottom.y, root)
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    enabled: root.interactive
    hoverEnabled: true
    cursorShape: root.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: if (root.tooltipText) tipTimer.restart()
    onExited: root.hideTip()
    onClicked: function(mouse) { root.hideTip(); if (root.pressable) root.pressed(mouse.button) }
    onWheel: function(wheel) { root.wheelMoved(wheel.angleDelta.y) }
  }
}
