import QtQuick
import Quickshell
import "compat" as Commons
import "Model.js" as Model
import "ui" as UI
import "../modules"

// Bar pill: the OmaStats readouts (crmne/omastats, MIT) inside a quickshell-
// dots pill. Left click opens the panel on that module's tab (a second click
// on the same module closes it), right click opens btop.
Item {
  id: rootMod
  required property var root

  readonly property var service: root.omaStats
  readonly property var settings: service ? service.settings : ({})
  readonly property var snapshot: service ? service.snapshot : ({})
  readonly property bool hasBattery: !!(service && service.hasBattery)

  readonly property var gpuReadouts: Model.selectedGpus(snapshot, Model.settingValue(settings, "barGpus"))
  readonly property var diskReadouts: {
    var perDisk = snapshot && snapshot.disks ? (snapshot.disks.perDisk || {}) : {}
    var known = Object.keys(perDisk).length > 0
    var list = Model.barDisksHere(snapshot, settings)
    var out = []
    for (var i = 0; i < list.length; i++) {
      var name = Model.resolveDisk(snapshot, list[i].disk)
      if (name === "" && known) continue
      out.push({ disk: name || list[i].disk, show: list[i].show })
    }
    return out
  }
  readonly property var barModules: {
    var configured = Model.parseModules(Model.settingValue(settings, "modules"))
    var out = []
    for (var i = 0; i < configured.length; i++) {
      var id = configured[i]
      if (id === "battery" && !hasBattery) continue
      if (Model.moduleDef(id).tabOnly) continue
      if (id === "gpu") {
        for (var g = 0; g < gpuReadouts.length; g++)
          out.push({ id: "gpu", gpuId: Model.gpuId(gpuReadouts[g]), disk: "", diskShow: "",
                     label: gpuReadouts.length > 1 ? Model.gpuShort(gpuReadouts[g]) : "" })
        continue
      }
      if (id === "disks") {
        for (var d = 0; d < diskReadouts.length; d++)
          out.push({ id: "disks", gpuId: "", disk: diskReadouts[d].disk, diskShow: diskReadouts[d].show,
                     label: diskReadouts.length > 1 ? Model.diskShort(diskReadouts[d].disk) : "" })
        continue
      }
      out.push({ id: id, gpuId: "", disk: "", diskShow: "", label: "" })
    }
    return out.length > 0 ? out : [{ id: "cpu", gpuId: "", disk: "", diskShow: "", label: "" }]
  }

  function toggleModule(id) {
    var tab = Model.tabFor(id)
    if (root.systemStatsVisible && root.omaStatsTab === tab) { root.systemStatsVisible = false; return }
    root.omaStatsTab = tab
    root.systemStatsVisible = true
  }

  visible: implicitWidth > 0.5
  implicitWidth: root.modSystemStats ? readouts.implicitWidth + 12 : 0
  implicitHeight: 28
  opacity: root.modSystemStats ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  Rectangle {
    x: 0; anchors.verticalCenter: parent.verticalCenter
    width: Math.round(readouts.implicitWidth) + 12
    height: root.pillH
    radius: root.pillRadius
    color: root.pill
    border.color: root.barPillBorder
    border.width: root.pillBorderW
    PillShadow { theme: root }
  }

  Row {
    id: readouts
    anchors.centerIn: parent
    spacing: 0

    Repeater {
      model: rootMod.barModules

      delegate: UI.BarReadout {
        required property var modelData
        module: modelData.id
        gpuId: modelData.gpuId
        shortLabel: modelData.label
        service: rootMod.service
        mode: Model.moduleStyle(rootMod.settings, modelData.id === "gpuMemory" ? "gpu" : modelData.id)
        graphWidth: Math.round(Model.clamp(Model.settingValue(rootMod.settings, "graphWidth"), 16, 120))
        temperatureUnit: "Celsius"
        disksSource: modelData.disk || "all"
        diskShow: modelData.diskShow || "speed"
        barSensors: String(Model.settingValue(rootMod.settings, "barSensors") || "cpu")
        settings: rootMod.settings
        labelMode: Model.barLabelMode(Model.settingValue(rootMod.settings, "barLabels"))
        onActivated: function(id, button) {
          if (button === Qt.LeftButton) rootMod.toggleModule(id)
          else if (button === Qt.RightButton) {
            root.systemStatsVisible = false
            Quickshell.execDetached(["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"])
          }
        }
      }
    }
  }
}
