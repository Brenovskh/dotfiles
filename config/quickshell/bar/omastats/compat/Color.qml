pragma Singleton
import QtQuick

// Stand-in for omarchy-shell's Commons.Color, so OmaStats' vendored ui/*.qml
// run unchanged inside quickshell-dots. `theme` is set to the bar's Theme.qml
// instance by OmaStatsService; every colour follows it live.
QtObject {
  id: root
  property var theme: null
  function v(x, d) { return (x === undefined || x === null) ? d : x }

  readonly property string currentThemePath: theme && theme.omarchyCurrentRoot ? String(theme.omarchyCurrentRoot) + "/theme" : ""
  readonly property color foreground: v(theme && theme.ink, "#cacccc")
  readonly property color background: v(theme && theme.paper, "#101315")
  readonly property color accent: v(theme && theme.seal, "#cacccc")
  readonly property color urgent: v(theme && theme.color01, "#a55555")
  readonly property color muted: v(theme && theme.sumi, "#707880")

  readonly property QtObject popups: QtObject {
    readonly property color text: root.foreground
    readonly property color background: root.background
  }
  readonly property QtObject bar: QtObject {
    readonly property color text: root.foreground
    readonly property color background: root.background
  }
  readonly property QtObject tooltip: QtObject {
    readonly property color text: root.foreground
    readonly property color background: root.background
    readonly property color border: root.v(root.theme && root.theme.pillBorder, Qt.rgba(1, 1, 1, 0.15))
  }
}
