import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Combined CPU + GPU + Memory + Storage detail panel, replacing the separate
// CpuPanel/MemoryPanel. CPU/Memory usage % come from Theme.qml's existing
// pollers; temp/freq/power/GPU/storage come from system_stats_scanner.py,
// vendored from the "dizziee.system-stats" Omarchy plugin (MIT license) and
// only polled while this panel is open.
PanelWindow {
    id: statsPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-system-stats"

    readonly property int barBottom: 35
    readonly property int gap: 8

    // ── CPU: usage from Theme.qml, everything else from the scanner ──
    readonly property int cpuPct: root.systemCpuPercent
    property string cpuName: ""
    property int cpuTemp: 0
    property real cpuFreq: 0
    property real cpuPower: 0
    property int cpuCores: 0
    property int cpuThreads: 0
    property string cpuGovernor: ""

    // ── GPU ──
    property bool gpuAvailable: false
    property string gpuName: ""
    property int gpuUtil: 0
    property int gpuTemp: 0
    property real gpuVramUsed: 0
    property real gpuVramTotal: 0
    property real gpuPower: 0

    // ── Memory: usage from Theme.qml, type/speed from the scanner ──
    readonly property int memPct: root.systemMemPercent
    readonly property real memUsedGiB: root.systemMemUsedMiB / 1024
    readonly property real memAvailGiB: root.systemMemAvailMiB / 1024
    readonly property real memTotalGiB: root.systemMemTotalMiB / 1024
    property string ramInfo: ""

    // ── CPU per-core (Theme.qml central sampler) ──
    readonly property var cpuPerCore: root.systemCpuPerCore

    // ── Storage ──
    property var storageMounts: []

    function refresh() { scanProc.running = false; scanProc.running = true }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/system_stats_scanner.py",
            "--compartments", "cpu,gpu,storage,memory"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text || "{}")
                    if (data.cpu) {
                        statsPanel.cpuName = data.cpu.name || ""
                        statsPanel.cpuTemp = data.cpu.temp || 0
                        statsPanel.cpuFreq = data.cpu.freq || 0
                        statsPanel.cpuPower = data.cpu.power || 0
                        statsPanel.cpuCores = data.cpu.cores || 0
                        statsPanel.cpuThreads = data.cpu.threads || 0
                        statsPanel.cpuGovernor = data.cpu.governor || ""
                    }
                    if (data.gpu) {
                        statsPanel.gpuAvailable = data.gpu.available === true
                        statsPanel.gpuName = data.gpu.name || ""
                        statsPanel.gpuUtil = data.gpu.usagePct || 0
                        statsPanel.gpuTemp = data.gpu.temp || 0
                        statsPanel.gpuVramUsed = data.gpu.vramUsedGb || 0
                        statsPanel.gpuVramTotal = data.gpu.vramTotalGb || 0
                        statsPanel.gpuPower = data.gpu.power || 0
                    }
                    if (data.storage) statsPanel.storageMounts = data.storage.mounts || []
                    if (data.memory) statsPanel.ramInfo = data.memory.info || ""
                } catch (e) { /* mid-write or python missing; keep last-known values */ }
            }
        }
    }

    Timer {
        interval: 5000
        running: root.systemStatsVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: statsPanel.refresh()
    }

    property real reveal: root.systemStatsVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.systemStatsVisible ? 160 : 120
            easing.type: root.systemStatsVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.systemStatsVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.systemStatsVisible = false }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.systemStatsBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: statsPanel.reveal
        focus: root.systemStatsVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.systemStatsVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "System"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.systemStatsVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ═══ CPU ═══
            UiText {
                text: statsPanel.cpuName !== "" ? statsPanel.cpuName : "CPU"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                elide: Text.ElideRight; width: parent.width
            }
            Item {
                width: parent.width; height: 16
                UiText {
                    id: cpuLbl
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                }
                UiText {
                    id: cpuVal
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: statsPanel.cpuPct + "%"; color: root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.left: cpuLbl.right; anchors.leftMargin: 8
                    anchors.right: cpuVal.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8; radius: 4; color: root.fillActive
                    Rectangle {
                        width: parent.width * statsPanel.cpuPct / 100
                        height: parent.height; radius: 4; color: root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }
            Row {
                width: parent.width
                visible: statsPanel.cpuTemp > 0 || statsPanel.cpuFreq > 0 || statsPanel.cpuPower > 0
                UiText { text: "Temp / Freq / Power"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5 }
                UiText {
                    text: (statsPanel.cpuTemp > 0 ? statsPanel.cpuTemp + "°C" : "—")
                        + "  " + (statsPanel.cpuFreq > 0 ? statsPanel.cpuFreq.toFixed(2) + "GHz" : "—")
                        + "  " + (statsPanel.cpuPower > 0 ? statsPanel.cpuPower.toFixed(1) + "W" : "—")
                    color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5; elide: Text.ElideRight
                }
            }
            Row {
                width: parent.width
                visible: statsPanel.cpuCores > 0
                UiText { text: "Cores / Governor"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5 }
                UiText {
                    text: statsPanel.cpuCores + "C/" + statsPanel.cpuThreads + "T"
                        + (statsPanel.cpuGovernor !== "" ? "  " + statsPanel.cpuGovernor : "")
                    color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5; elide: Text.ElideRight
                }
            }
            Grid {
                width: parent.width
                visible: statsPanel.cpuPerCore.length > 0
                columns: statsPanel.cpuPerCore.length > 8 ? 4 : 2
                columnSpacing: 10
                rowSpacing: 4
                Repeater {
                    model: statsPanel.cpuPerCore
                    delegate: Item {
                        required property int index
                        required property var modelData
                        width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
                        height: 14
                        UiText {
                            id: coreLbl
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            text: "C" + index; color: root.sumiHi; font.family: root.mono; font.pixelSize: 9
                        }
                        UiText {
                            id: coreVal
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: 26; horizontalAlignment: Text.AlignRight
                            text: modelData + "%"; color: root.ink; font.family: root.mono; font.pixelSize: 9
                        }
                        Rectangle {
                            anchors.left: coreLbl.right; anchors.leftMargin: 4
                            anchors.right: coreVal.left; anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4; radius: 2; color: root.fillActive
                            Rectangle {
                                width: parent.width * modelData / 100
                                height: parent.height; radius: 2; color: root.seal
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                    }
                }
            }

            // ═══ GPU ═══
            Rectangle { width: parent.width; height: 1; color: root.sep; visible: statsPanel.gpuAvailable }
            UiText {
                visible: statsPanel.gpuAvailable
                text: statsPanel.gpuName !== "" ? statsPanel.gpuName : "GPU"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                elide: Text.ElideRight; width: parent.width
            }
            Item {
                width: parent.width; height: 16
                visible: statsPanel.gpuAvailable
                UiText {
                    id: gpuLbl
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "GPU"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                }
                UiText {
                    id: gpuVal
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: statsPanel.gpuUtil + "%"; color: root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.left: gpuLbl.right; anchors.leftMargin: 8
                    anchors.right: gpuVal.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8; radius: 4; color: root.fillActive
                    Rectangle {
                        width: parent.width * statsPanel.gpuUtil / 100
                        height: parent.height; radius: 4; color: root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }
            Row {
                width: parent.width
                visible: statsPanel.gpuAvailable
                UiText { text: "Temp / VRAM / Power"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5 }
                UiText {
                    text: (statsPanel.gpuTemp > 0 ? statsPanel.gpuTemp + "°C" : "—")
                        + "  " + statsPanel.gpuVramUsed.toFixed(1) + "/" + statsPanel.gpuVramTotal.toFixed(1) + "G"
                        + "  " + (statsPanel.gpuPower > 0 ? statsPanel.gpuPower.toFixed(1) + "W" : "—")
                    color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5; elide: Text.ElideRight
                }
            }

            // ═══ Memory ═══
            Rectangle { width: parent.width; height: 1; color: root.sep }
            UiText {
                text: "MEMORY"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Item {
                width: parent.width; height: 16
                UiText {
                    id: memLbl
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "MEM"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                }
                UiText {
                    id: memVal
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: statsPanel.memPct + "%"; color: root.indigo
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.left: memLbl.right; anchors.leftMargin: 8
                    anchors.right: memVal.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8; radius: 4; color: root.fillActive
                    Rectangle {
                        width: parent.width * statsPanel.memPct / 100
                        height: parent.height; radius: 4; color: root.indigo
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }
            Row {
                width: parent.width
                UiText { text: "Used / Available / Total"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5 }
                UiText {
                    text: statsPanel.memUsedGiB.toFixed(1) + " / " + statsPanel.memAvailGiB.toFixed(1) + " / " + statsPanel.memTotalGiB.toFixed(1) + " GiB"
                    color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.5; elide: Text.ElideRight
                }
            }
            UiText {
                visible: statsPanel.ramInfo !== ""
                text: statsPanel.ramInfo
                color: root.sumi; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width
            }

            // ═══ Storage ═══
            Rectangle { width: parent.width; height: 1; color: root.sep; visible: statsPanel.storageMounts.length > 0 }
            UiText {
                visible: statsPanel.storageMounts.length > 0
                text: "STORAGE"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Repeater {
                model: statsPanel.storageMounts
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 2

                    Item {
                        width: parent.width; height: 14
                        visible: modelData.model !== ""
                        UiText {
                            anchors.left: parent.left; anchors.right: pctLbl.left; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.model; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        UiText {
                            id: pctLbl
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.usagePct.toFixed(0) + "%"
                            color: modelData.usagePct >= 90 ? root.warn : root.seal
                            font.family: root.mono; font.pixelSize: 10; font.weight: Font.Medium
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: root.fillActive
                        Rectangle {
                            width: parent.width * Math.min(100, modelData.usagePct) / 100
                            height: parent.height; radius: 3
                            color: modelData.usagePct >= 90 ? root.warn : root.seal
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    UiText {
                        text: modelData.path + "  ·  " + modelData.usedGb.toFixed(1) + " / " + modelData.totalGb.toFixed(1) + " GiB"
                        color: root.sumi; font.family: root.mono; font.pixelSize: 10
                        elide: Text.ElideRight; width: parent.width
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── button ──
            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                color: btopMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: root.paper
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.systemStatsVisible = false
                        btopRunner.running = false; btopRunner.running = true
                    }
                }
            }
        }
    }

    Process {
        id: btopRunner
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"]
    }

    onVisibleChanged: { if (visible) refresh() }
}
