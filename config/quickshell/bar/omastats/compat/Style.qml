pragma Singleton
import QtQuick
import "." as Commons

// Stand-in for omarchy-shell's Commons.Style: the omarchy defaults (12px base
// font, 1.0 spacing scale), with the font family, corner radius and bar size
// taken from quickshell-dots' Theme.qml.
QtObject {
  id: root
  readonly property var theme: Commons.Color.theme

  readonly property int cornerRadius: (theme && theme.tileRadius !== undefined) ? Math.max(2, theme.tileRadius) : 4
  readonly property int normalBorderWidth: 1
  readonly property var easeOut: [0.22, 1, 0.36, 1, 1, 1]

  function duration(ms) { return ms }
  function spaceReal(px) {
    var n = Number(px)
    return (!isFinite(n) || n <= 0) ? 0 : n
  }
  function space(px) {
    var n = spaceReal(px)
    return n <= 0 ? 0 : Math.max(1, Math.round(n))
  }

  function _a(c, a) { c = Qt.color(c); return Qt.rgba(c.r, c.g, c.b, a) }
  function normalFillFor(fg, accent) { return _a(fg, 0.04) }
  function hoverFillFor(fg, accent) { return _a(fg, 0.10) }
  function selectedFillFor(fg, accent) { return _a(accent || fg, 0.16) }
  function focusFillFor(fg, accent) { return _a(accent || fg, 0.12) }
  function controlFill(focused, hot, fg, accent) {
    if (focused) return focusFillFor(fg, accent)
    if (hot) return hoverFillFor(fg, accent)
    return normalFillFor(fg, accent)
  }

  readonly property QtObject spacing: QtObject {
    readonly property int hairline: 1
    readonly property int xxs: 2
    readonly property int xs: 3
    readonly property int sm: 4
    readonly property int md: 6
    readonly property int controlPaddingX: 10
    readonly property int controlPaddingY: 6
    readonly property int inputPaddingY: 7
    readonly property int popupPadding: 14
  }

  readonly property QtObject font: QtObject {
    readonly property string family: (root.theme && root.theme.mono) ? root.theme.mono : "monospace"
    readonly property int baseSize: 12
    readonly property int caption: 10
    readonly property int bodySmall: 11
    readonly property int body: 12
    readonly property int subtitle: 13
    readonly property int title: 14
    readonly property int heading: 16
    readonly property int display: 24
    readonly property int displayLarge: 28
    readonly property int iconSmall: 11
    readonly property int icon: 14
    readonly property int iconLarge: 18
  }

  readonly property QtObject bar: QtObject {
    readonly property int sizeHorizontal: (root.theme && root.theme.pillH) ? root.theme.pillH : 24
    readonly property int iconSlot: 24
    readonly property int iconCanvas: 16
    readonly property int iconFont: 12
    readonly property int iconSize: 12
  }
}
