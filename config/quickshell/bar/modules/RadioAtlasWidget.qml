import QtQuick
import Quickshell
import Quickshell.Io

// Bar trigger for the akshar.radio-atlas Omarchy plugin. The actual globe UI
// is rendered by omarchy-shell (still running for menu/notifications/lock
// even with the omarchy bar hidden) as its own layer-shell surface, so this
// widget does not reimplement it — it only mirrors playback status and
// drives the same IPC / radio-player CLI the plugin's own bar pill uses.
Item {
    id: rootMod
    required property var root

    property bool   running: false
    property bool   paused:  false
    property bool   muted:   false
    property string title:   ""
    property int    volume:  0
    property bool   statusReady: false

    readonly property string statusPath: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-radio-atlas/status.json"
    readonly property string playerCmd: "\"$HOME/.config/omarchy/plugins/akshar.radio-atlas/radio-player\""

    readonly property string tooltipText: running
        ? (paused ? "Radio Atlas · pausado: " : "Radio Atlas · tocando: ") + (title !== "" ? title : "—")
            + "  ·  " + (muted ? "mudo" : volume + "%")
        : "Abrir Radio Atlas"

    function applyStatus(raw) {
        try {
            var s = JSON.parse(raw || "{}")
            rootMod.running = s.running === true
            rootMod.paused  = s.paused === true
            rootMod.muted   = s.muted === true
            var v = Math.round(Number(s.volume === undefined ? 0 : s.volume))
            rootMod.volume  = isFinite(v) ? Math.max(0, Math.min(100, v)) : 0
            rootMod.title   = String(s.title || (s.station && s.station.name) || "").slice(0, 160)
        } catch (e) { /* status file mid-write; keep last-known state */ }
    }

    function run(action) {
        runner.command = ["bash", "-c", playerCmd + " " + action]
        runner.running = false
        runner.running = true
    }

    function toggleGlobe() {
        toggleProc.running = false
        toggleProc.running = true
    }

    function randomStation() {
        randomProc.running = false
        randomProc.running = true
    }

    visible: implicitWidth > 0.5
    implicitWidth: root.modRadioAtlas ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modRadioAtlas ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.implicitWidth) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.barPillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0AC)   // nf-fa-globe
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
            font.family: root.mono
            font.pixelSize: 14
        }

        // playing/paused/stopped dot, same idiom as the sun in BrightnessWidget
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: rootMod.running && !rootMod.paused ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: rootMod.running
            text: rootMod.title !== "" ? rootMod.title : "…"
            color: root.ink
            font.family: root.mono
            font.pixelSize: 12
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 90)
        }
    }

    FileView {
        path: rootMod.statusReady ? rootMod.statusPath : ""
        watchChanges: true
        printErrors: false
        onLoaded: rootMod.applyStatus(text())
        onFileChanged: reload()
    }

    // The status file only appears after the player has started at least
    // once; poll for it lazily instead of assuming it is already there.
    Process {
        id: statusProbe
        command: ["bash", "-c", "[ -f " + rootMod.statusPath + " ] && echo yes || echo no"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { if (this.text.trim() === "yes") rootMod.statusReady = true }
        }
    }
    Timer {
        interval: 4000; running: !rootMod.statusReady; repeat: true
        onTriggered: { statusProbe.running = false; statusProbe.running = true }
    }

    Process { id: runner }
    Process { id: toggleProc; command: ["bash", "-c", "omarchy-shell shell toggle akshar.radio-atlas"] }
    Process { id: randomProc; command: ["bash", "-c", "omarchy-shell shell summon akshar.radio-atlas '{\"action\":\"random\"}'"] }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) rootMod.run("stop")
            else if (e.button === Qt.MiddleButton) rootMod.randomStation()
            else rootMod.toggleGlobe()
        }
        onWheel: (e) => {
            rootMod.run(e.angleDelta.y > 0 ? "volume-up" : "volume-down")
        }
    }
}
