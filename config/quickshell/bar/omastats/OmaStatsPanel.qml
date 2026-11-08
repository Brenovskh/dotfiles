import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "compat" as Commons
import "Model.js" as Model
import "ui" as UI
import "../modules"

// The OmaStats panel (crmne/omastats, MIT) as a quickshell-dots popup:
// tabs across the top, one page per module, scrolling only when the page is
// taller than the screen allows. Opens under the bar pill (systemStatsBarX).
// Keys: ←/→ or Tab switch tabs, 1-6 jump, ↑/↓ scroll, / searches processes, Esc closes.
PanelWindow {
  id: panelWin
  required property var root

  readonly property var service: root.omaStats
  readonly property var settings: service ? service.settings : ({})
  readonly property bool opened: root.systemStatsVisible
  readonly property bool hasGpu: !!(service && service.hasGpu)
  readonly property bool hasBattery: !!(service && service.hasBattery)
  readonly property var moduleTabs: Model.panelTabs(hasBattery, Model.settingValue(settings, "tabs"), hasGpu)
  readonly property string currentTab: moduleTabs.indexOf(root.omaStatsTab) !== -1 ? root.omaStatsTab : moduleTabs[0]
  readonly property color fg: Commons.Color.foreground
  readonly property string fontFamily: Commons.Style.font.family
  readonly property int barBottom: 35
  readonly property int gap: 8
  readonly property int pad: 14

  // ── host API used by the pages (ProcessList, DisksPage) ──
  property bool processesExpanded: false
  property string processQuery: ""
  property bool searchActive: false
  property var searchField: null
  property bool fullHeld: false
  property bool detailHeld: false

  function close() { root.systemStatsVisible = false }

  function setProcessesExpanded(value) {
    processesExpanded = value === true
    if (!processesExpanded) { processQuery = ""; searchActive = false }
    syncFull()
  }
  function syncFull() {
    var want = opened && processesExpanded
    if (!service || want === fullHeld) return
    fullHeld = want
    if (want) service.acquireFull(); else service.releaseFull()
  }
  function focusSearch() {
    if (!processesExpanded) setProcessesExpanded(true)
    Qt.callLater(function() { if (panelWin.searchField) panelWin.searchField.forceActiveFocus() })
  }
  function showTab(tab) {
    if (moduleTabs.indexOf(tab) === -1) tab = moduleTabs[0]
    if (root.omaStatsTab !== tab) { root.omaStatsTab = tab; scroller.contentY = 0 }
  }
  function cycleTab(delta) {
    var idx = moduleTabs.indexOf(currentTab)
    if (idx < 0) idx = 0
    showTab(moduleTabs[(idx + delta + moduleTabs.length) % moduleTabs.length])
  }
  function scrollBy(steps) {
    var max = Math.max(0, scroller.contentHeight - scroller.height)
    scroller.contentY = Math.max(0, Math.min(max, scroller.contentY + steps * 48))
  }

  onOpenedChanged: {
    if (!service) return
    if (opened && !detailHeld) {
      detailHeld = true
      service.acquireDetail()
      service.setFocus(currentTab)
      scroller.contentY = 0
    } else if (!opened && detailHeld) {
      detailHeld = false
      service.releaseDetail()
      service.setFocus("")
      searchActive = false
    }
    syncFull()
  }
  onCurrentTabChanged: if (opened && service) service.setFocus(currentTab)
  Component.onDestruction: {
    if (service && detailHeld) service.releaseDetail()
    if (service && fullHeld) service.releaseFull()
  }

  screen: root.activePopupScreen
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omarchy-system-stats"

  property real reveal: opened ? 1 : 0
  Behavior on reveal {
    NumberAnimation { duration: panelWin.opened ? 160 : 120; easing.type: panelWin.opened ? Easing.OutCubic : Easing.InCubic }
  }
  visible: reveal > 0.001
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  MouseArea { anchors.fill: parent; onClicked: panelWin.close() }

  Rectangle {
    id: card
    readonly property real maxH: panelWin.height - panelWin.barBottom - panelWin.gap * 2
    width: Math.max(372, Math.ceil(tabs.spelledWidth) + panelWin.pad * 2)
    height: Math.min(maxH, tabs.height + statusLine.height + 10 + pageLoader.implicitHeight + panelWin.pad * 2)
    radius: panelWin.reveal > 0.001 ? root.pillRadius : 0
    // near-opaque: dense text pages are unreadable over windows at bar opacity
    color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, Math.max(0.94, root.bg.a))
    border.color: root.pillBorder
    border.width: root.pillBorderW
    PillShadow { theme: root }

    x: Math.round(Math.max(6, Math.min(root.systemStatsBarX - width / 2, parent.width - width - 6)))
    y: root.barPosition === "bottom" ? (parent.height - panelWin.barBottom - panelWin.gap - height) : (panelWin.barBottom + panelWin.gap)
    opacity: panelWin.reveal
    focus: panelWin.opened

    Keys.onPressed: function(event) {
      if (panelWin.searchActive) {
        if (event.key === Qt.Key_Escape) { card.forceActiveFocus(); event.accepted = true }
        return
      }
      var k = event.key
      if (k === Qt.Key_Escape) panelWin.close()
      else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) panelWin.cycleTab(-1)
      else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) panelWin.cycleTab(1)
      else if (k === Qt.Key_Down || k === Qt.Key_J) panelWin.scrollBy(1)
      else if (k === Qt.Key_Up || k === Qt.Key_K) panelWin.scrollBy(-1)
      else if (event.text === "/") panelWin.focusSearch()
      else {
        var digit = parseInt(event.text, 10)
        if (isFinite(digit) && digit >= 1 && digit <= panelWin.moduleTabs.length) panelWin.showTab(panelWin.moduleTabs[digit - 1])
        else return
      }
      event.accepted = true
    }

    // swallow clicks so they don't reach the dismiss layer
    MouseArea { anchors.fill: parent; onClicked: card.forceActiveFocus() }

    Item {
      anchors.fill: parent
      anchors.margins: panelWin.pad

      UI.ModuleTabs {
        id: tabs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        tabs: panelWin.moduleTabs
        settingsTab: ""
        current: panelWin.currentTab
        foreground: panelWin.fg
        fontFamily: panelWin.fontFamily
        onActivated: function(id) { panelWin.showTab(id) }
      }

      Text {
        id: statusLine
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        textFormat: Text.PlainText
        readonly property string message: {
          if (!panelWin.service) return "OmaStats service not loaded."
          if (!panelWin.service.ready) return "Starting the sampler…"
          return panelWin.service.samplerError ? "Sampler: " + panelWin.service.samplerError : ""
        }
        visible: message !== ""
        height: visible ? implicitHeight + 10 : 0
        verticalAlignment: Text.AlignBottom
        text: message
        color: panelWin.fg
        opacity: 0.6
        font.family: panelWin.fontFamily
        font.pixelSize: Commons.Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Flickable {
        id: scroller
        anchors.top: statusLine.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: width
        contentHeight: pageLoader.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: scroller.contentHeight > scroller.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        Loader {
          id: pageLoader
          width: scroller.width
          active: panelWin.opened || panelWin.visible
          source: Qt.resolvedUrl("ui/" + Model.pageFile(panelWin.currentTab))
        }

        Binding { target: pageLoader.item; property: "service"; value: panelWin.service; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "settings"; value: panelWin.settings; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "host"; value: panelWin; when: pageLoader.status === Loader.Ready && pageLoader.item && pageLoader.item.hasOwnProperty("host") }
        Binding { target: pageLoader.item; property: "temperatureUnit"; value: "Celsius"; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "publicIpEnabled"; value: false; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "foreground"; value: panelWin.fg; when: pageLoader.status === Loader.Ready }
        Binding { target: pageLoader.item; property: "fontFamily"; value: panelWin.fontFamily; when: pageLoader.status === Loader.Ready }
      }
    }
  }
}
