import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: netPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-network"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property string mode:  "none"   // wifi | ethernet | none
    property string ssid:  ""
    property int    signal: 0
    property string iface: ""
    property string ipAddr: ""
    property string freq:  ""

    property string wdev:   ""      // wifi device name (e.g. wlan0)
    property bool   hasWifi: false
    property bool   scanning: false
    property var    networks: []    // [{conn, ssid, sec, sig}]
    property var    known:   []     // known ssids
    property bool   savedOnly: false
    property string selectedNetworkKey: ""
    property string pendingForgetKey: ""
    property int    keyboardIndex: -1
    readonly property var shownNetworks: networks.filter(function(entry) {
        return savedOnly ? entry.known === true : entry.visible !== false
    })
    readonly property int savedCount: {
        var count = 0
        for (var i = 0; i < networks.length; i++)
            if (networks[i].known === true) count++
        return count
    }

    function networkKey(entry) {
        if (!entry)
            return ""
        return entry.entryKey || "ssid:" + (entry.ssid || "")
    }

    property string nmPasswordSsid: ""
    property string nmPasswordText: ""
    property var    nmPasswordNetwork: null
    property string nmConnectionError: ""
    property bool   nmConnecting: false
    property string networkActionError: ""
    property bool   nmProfilesLoaded: false

    // ── wifi radio ──
    property bool   wifiBlocked: false

    // ── link speed (negotiated connection rate) ──
    property string linkSpeed:   ""

    // ── live details, from Omarchy's own `omarchy-network-status --verbose`
    //    (same source + math as the stock Omarchy network panel) ──
    property var  info: ({})
    readonly property bool hasTransferStats: info.rx_bytes !== undefined
    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real prevSampleTime: 0
    property string prevIface: ""
    property real downloadRate: 0   // bytes/sec
    property real uploadRate: 0     // bytes/sec

    // internet ping: rolling window of samples (null = lost), latency shown as
    // the mean of the most recent few — mirrors the stock panel's Model.js
    property string pingIface: ""
    property var  internetPingSamples: []
    readonly property int pingHistoryWindow: 24
    readonly property int pingAverageWindow: 5
    readonly property bool hasInternetPing: internetPingSamples.length > 0
    readonly property real internetPingLatency: {
        var s = internetPingSamples, total = 0, count = 0
        for (var i = Math.max(0, s.length - pingAverageWindow); i < s.length; i++) {
            if (typeof s[i] !== "number") continue
            total += s[i]; count++
        }
        return count > 0 ? total / count : -1
    }
    readonly property int internetPingPacketLoss: {
        var s = internetPingSamples, lost = 0
        if (s.length === 0) return 0
        for (var i = 0; i < s.length; i++) if (s[i] === null) lost++
        return Math.round(lost / s.length * 100)
    }

    // ── DNS provider (omarchy-dns) ──
    readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]
    property string dnsProvider: ""
    property string pendingDnsProvider: ""

    // rotating subtitle under the connection name, as in the stock panel
    readonly property var connectionPhrases: [
        "Wiring bits", "Handling packets", "Sorting frames", "Hauling bytes",
        "Routing crumbs", "Counting collisions", "Bending light"
    ]
    property int connectionPhraseIndex: 0
    readonly property string connectionPhrase: connectionPhrases[connectionPhraseIndex % connectionPhrases.length]

    function formatBytes(bytes) {
        var n = Number(bytes)
        if (!isFinite(n) || n < 0) n = 0
        if (n < 1024) return Math.round(n) + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatPingLatency(ms) {
        if (!hasInternetPing) return "--"
        if (!(ms >= 0)) return "Timeout"
        return ms.toFixed(ms > 0 && ms < 10 ? 1 : 0) + " ms"
    }

    function formatHeaderSpeed(mbps) {
        var v = parseInt(mbps, 10)
        if (!v || v < 0) return ""
        if (v >= 1000) return (v / 1000).toFixed(v % 1000 === 0 ? 0 : 1) + "gbit"
        return v + "mbit"
    }

    function heroIconText() {
        if (mode === "ethernet") return "󰈀"
        if (mode === "wifi") {
            var icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
            return icons[Math.max(0, Math.min(4, Math.ceil(signal / 20) - 1))]
        }
        return "󰤮"
    }

    function heroTitle() {
        if (mode === "wifi") return ssid || "Wi-Fi"
        if (mode === "ethernet") {
            var detail = formatHeaderSpeed(info.speed || "")
            return detail !== "" ? "Ethernet (" + detail + ")" : "Ethernet"
        }
        return "Disconnected"
    }

    function updateDetails(raw) {
        var next = {}
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var idx = lines[i].indexOf("\t")
            if (idx === -1) continue
            next[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
        }
        info = next

        // connection summary used by the hero + wifi section
        var type = next.iface ? (next.type || "") : ""
        mode = type === "wifi" ? "wifi" : type === "ethernet" ? "ethernet" : "none"
        iface = next.iface || ""
        ipAddr = next.ip || ""
        ssid = mode === "wifi" ? (next.ssid || "") : ""
        freq = mode === "wifi" && next.freq ? next.freq + " MHz" : ""
        if (mode === "wifi" && next.signal_dbm) {
            var q = Math.round((parseInt(next.signal_dbm) + 110) * 100 / 70)
            signal = Math.max(0, Math.min(100, q))
        }
        if (mode === "ethernet") {
            var mb = parseInt(next.speed) || 0
            linkSpeed = mb >= 1000 ? (mb / 1000).toFixed(1).replace(/\.0$/, "") + " Gbit/s"
                                   : (mb > 0 ? mb + " Mbit/s" : "")
        } else {
            linkSpeed = mode === "wifi" ? (next.bitrate || "") : ""
        }

        // throughput: byte-counter deltas between samples
        var rx = parseFloat(next.rx_bytes || "0"), tx = parseFloat(next.tx_bytes || "0")
        var now = Date.now() / 1000
        if (iface !== prevIface || prevSampleTime === 0) {
            downloadRate = 0; uploadRate = 0
        } else {
            var dt = now - prevSampleTime
            if (dt > 0) {
                downloadRate = Math.max(0, (rx - prevRxBytes) / dt)
                uploadRate = Math.max(0, (tx - prevTxBytes) / dt)
            }
        }
        prevIface = iface; prevRxBytes = rx; prevTxBytes = tx; prevSampleTime = now

        // internet ping window (reset when the interface changes)
        var samples = (iface === "" || iface !== pingIface) ? [] : internetPingSamples.slice()
        pingIface = iface
        if (next.internet_ping_ms === undefined) {
            samples = []
        } else {
            var v = parseFloat(next.internet_ping_ms)
            samples.push(isFinite(v) && v >= 0 ? v : null)
            while (samples.length > pingHistoryWindow) samples.shift()
        }
        internetPingSamples = samples
    }

    // The speed test is Omarchy's own standalone panel (omarchy.speedtest),
    // summoned over omarchy-shell IPC — same thing the stock panel's button does.
    function summonSpeedTest() {
        root.networkVisible = false
        var connection = mode === "wifi" ? (ssid || "Wi-Fi") : mode === "ethernet" ? "Ethernet" : ""
        Quickshell.execDetached(["omarchy-shell", "-q", "shell", "summon", "omarchy.speedtest",
            connection ? JSON.stringify({ connection: connection }) : "{}"])
    }

    // Closes the panel first (as the stock panel does) so a privilege prompt
    // isn't stuck behind this overlay's exclusive keyboard grab.
    function setDns(provider) {
        if (!provider || dnsAction.running) return
        root.networkVisible = false
        if (provider === "Custom") {
            Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-dns Custom"])
            return
        }
        pendingDnsProvider = provider
        dnsAction.command = ["omarchy-dns", provider]
        dnsAction.running = true
    }

    readonly property bool nmAdapterReady: root.useNM
        && nmAdapter.status === Loader.Ready
        && nmAdapter.item !== null
        && nmAdapter.item.available

    function flagForCountry(code) {
        var value = (code || "").toUpperCase()
        if (!/^[A-Z]{2}$/.test(value)) return ""
        return String.fromCharCode(
            0xD83C, 0xDDE6 + value.charCodeAt(0) - 65,
            0xD83C, 0xDDE6 + value.charCodeAt(1) - 65)
    }


    function toggleWifi() {
        if (nmAdapterReady) {
            nmAdapter.item.toggleWifi()
            return
        }
        if (root.useNM) {
            root.networkVisible = false
            openWifiSettings()
            return
        }

        var wasBlocked = netPanel.wifiBlocked
        rfkillToggle.command = ["bash", "-c", wasBlocked ? "rfkill unblock wifi" : "rfkill block wifi"]
        rfkillToggle.running = false; rfkillToggle.running = true
        netPanel.wifiBlocked = !wasBlocked      // optimistic; rfkillState corrects
        Qt.callLater(function() {
            rfkillState.running = false; rfkillState.running = true
            netData.running = false; netData.running = true
            if (wasBlocked) netPanel.scan()     // just turned ON → look for networks
        })
    }

    function scan() {
        if (nmAdapterReady) {
            nmAdapter.item.scan()
            return
        }
        if (scanning || wifiBlocked || root.useNM) return   // NM fallback: no iwctl scan
        scanning = true
        scanProc.running = false
        scanProc.running = true
        scanWatchdog.restart()        // never stay stuck in "scanning"
    }

    function connectTo(entryOrSsid, sec) {
        if (nmAdapterReady) {
            nmAdapter.item.connectTo(entryOrSsid)
            return
        }

        var ssid = typeof entryOrSsid === "object" && entryOrSsid !== null ? entryOrSsid.ssid : entryOrSsid
        var isKnown = known.indexOf(ssid) >= 0
        if (sec === "open" || isKnown) {
            if (!netPanel.wdev) return
            // argv form (no shell) → a crafted SSID cannot inject commands
            connectProc.command = ["iwctl", "station", netPanel.wdev, "connect", ssid]
            connectProc.running = false
            connectProc.running = true
            // re-scan shortly to reflect new connection
            rescanTimer.restart()
        } else {
            // unknown secured network — needs passphrase → open impala
            root.networkVisible = false
            wifiRunner.running = false
            wifiRunner.running = true
        }
    }

    function activateNetwork(entry) {
        if (!entry)
            return

        networkActionError = ""

        if (entry.conn) {
            if (nmAdapterReady && entry.network)
                entry.network.disconnect()
            else if (wdev !== "") {
                connectProc.command = ["iwctl", "station", wdev, "disconnect"]
                connectProc.running = false
                connectProc.running = true
            }
            rescanTimer.restart()
            return
        }

        connectTo(entry, entry.sec)
    }

    function forgetNetwork(entry) {
        if (!entry || !entry.known)
            return

        cancelForget()
        selectedNetworkKey = ""
        if (nmAdapterReady) {
            nmAdapter.item.forgetNetwork(entry)
            refreshNmNetworks()
        } else {
            forgetProc.command = ["iwctl", "known-networks", entry.ssid, "forget"]
            forgetProc.running = false
            forgetProc.running = true
        }
    }

    function selectNetwork(entry) {
        if (!entry)
            return
        cancelForget()
        var key = networkKey(entry)
        selectedNetworkKey = selectedNetworkKey === key ? "" : key
    }

    function isNeverConnected(entry) {
        return root.useNM && nmProfilesLoaded && entry && entry.known
            && !(Number(entry.lastSuccessful || 0) > 0)
    }

    function protectionLabel(entry) {
        if (!entry)
            return "Unknown"
        if (entry.securityLabel)
            return entry.securityLabel
        switch (entry.sec || "") {
        case "open": return "Open"
        case "psk": return "PSK"
        case "8021x": return "802.1X"
        case "wep": return "WEP"
        case "saved": return "Saved Wi-Fi profile"
        default: return "Unknown"
        }
    }

    function cancelForget() {
        pendingForgetKey = ""
        forgetConfirmTimer.stop()
    }

    function requestForget(entry) {
        if (!entry || !entry.known)
            return
        var key = networkKey(entry)
        if (pendingForgetKey === key) {
            cancelForget()
            forgetNetwork(entry)
            return
        }
        pendingForgetKey = key
        forgetConfirmTimer.restart()
    }

    function resetNetworkSelection() {
        cancelForget()
        selectedNetworkKey = ""
        keyboardIndex = -1
    }

    function ensureKeyboardNetworkVisible() {
        if (keyboardIndex < 0 || keyboardIndex >= networkRepeater.count)
            return
        var item = networkRepeater.itemAt(keyboardIndex)
        if (!item)
            return
        var top = item.y
        var bottom = top + item.height
        if (top < networkFlick.contentY)
            networkFlick.contentY = top
        else if (bottom > networkFlick.contentY + networkFlick.height)
            networkFlick.contentY = Math.min(networkFlick.contentHeight - networkFlick.height,
                                            bottom - networkFlick.height)
    }

    onSavedOnlyChanged: resetNetworkSelection()

    function openWifiSettings() {
        wifiRunner.running = false
        wifiRunner.running = true
    }

    function refreshNmNetworks() {
        if (nmAdapterReady)
            nmAdapter.item.syncNetworks()
    }

    function beginNmPassword(entry) {
        if (!entry || !entry.network)
            return

        nmPasswordSsid = entry.ssid || ""
        nmPasswordNetwork = entry.network
        nmPasswordText = ""
        nmConnectionError = ""
        nmConnecting = false
        nmConnectTimeout.stop()
        Qt.callLater(function() {
            if (nmPasswordInput.visible)
                nmPasswordInput.forceActiveFocus()
        })
    }

    function clearNmPassword() {
        nmPasswordSsid = ""
        nmPasswordText = ""
        nmPasswordNetwork = null
        nmConnectionError = ""
        nmConnecting = false
        nmConnectTimeout.stop()
    }

    function submitNmPassword() {
        if (!nmAdapterReady || !nmPasswordNetwork || nmPasswordText === "" || nmConnecting)
            return

        nmConnectionError = ""
        nmConnecting = true
        nmConnectTimeout.restart()
        nmAdapter.item.connectWithPsk(nmPasswordNetwork, nmPasswordText)
    }

    function handleNmConnected(network) {
        if (!network)
            return

        var name = network.name || ""
        if (name === nmPasswordSsid)
            clearNmPassword()
    }

    function handleNmConnectionFailed(network, reason) {
        if (!network)
            return

        var name = network.name || ""
        if (name !== nmPasswordSsid)
            return

        nmConnecting = false
        nmConnectTimeout.stop()
        nmConnectionError = "Connection failed"
        Qt.callLater(function() {
            if (nmPasswordInput.visible)
                nmPasswordInput.forceActiveFocus()
        })
    }

    property real reveal: root.networkVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.networkVisible ? 160 : 120
            easing.type: root.networkVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.networkVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.networkVisible = false }

    Rectangle {
        id: card
        width: 380
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.networkBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: netPanel.reveal
        focus: root.networkVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (netPanel.pendingForgetKey !== "")
                    netPanel.cancelForget()
                else if (netPanel.selectedNetworkKey !== "")
                    netPanel.selectedNetworkKey = ""
                else
                    root.networkVisible = false
                event.accepted = true
                return
            }

            if (netPanel.nmPasswordSsid !== "")
                return

            var entries = netPanel.shownNetworks
            if (entries.length === 0)
                return

            if (event.key === Qt.Key_Down) {
                netPanel.keyboardIndex = (netPanel.keyboardIndex + 1) % entries.length
                Qt.callLater(netPanel.ensureKeyboardNetworkVisible)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                netPanel.keyboardIndex = netPanel.keyboardIndex <= 0
                    ? entries.length - 1 : netPanel.keyboardIndex - 1
                Qt.callLater(netPanel.ensureKeyboardNetworkVisible)
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (netPanel.keyboardIndex >= 0)
                    netPanel.selectedNetworkKey = netPanel.networkKey(entries[netPanel.keyboardIndex])
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                netPanel.cancelForget()
                netPanel.selectedNetworkKey = ""
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (netPanel.keyboardIndex >= 0)
                    netPanel.activateNetwork(entries[netPanel.keyboardIndex])
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── hero: icon · "Ethernet (1gbit)" · rotating phrase · speed test ──
            Item {
                width: parent.width
                height: 46

                UiText {
                    id: heroIcon
                    anchors.left: parent.left; anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: netPanel.heroIconText()
                    color: netPanel.mode === "none" ? root.sumi : root.ink
                    font.family: root.mono; font.pixelSize: 28
                }

                UiText {
                    id: speedAction
                    anchors.right: parent.right; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: netPanel.mode !== "none"
                    text: "󰓅"
                    color: speedActionMa.containsMouse ? root.seal : root.ink
                    font.family: root.mono; font.pixelSize: 20
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: speedActionMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: netPanel.summonSpeedTest()
                    }
                }

                Column {
                    anchors.left: heroIcon.right; anchors.leftMargin: 14
                    anchors.right: speedAction.left; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    UiText {
                        width: parent.width
                        text: netPanel.heroTitle()
                        color: root.ink
                        font.family: root.mono; font.pixelSize: 14; font.bold: true
                        elide: Text.ElideRight
                    }
                    UiText {
                        id: heroMeta
                        width: parent.width
                        text: netPanel.mode === "none" ? "NOT CONNECTED" : netPanel.connectionPhrase.toUpperCase()
                        color: root.sumi
                        font.family: root.mono; font.pixelSize: 10; font.bold: true
                        font.letterSpacing: 1.2
                        elide: Text.ElideRight
                    }
                }
            }

            // ── connection details: transfer metrics first, then IP/Gateway ──
            Grid {
                id: statsGrid
                visible: !!netPanel.info.iface
                width: parent.width
                columns: 2
                columnSpacing: 20
                rowSpacing: 4
                readonly property real cellW: (width - columnSpacing) / 2

                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "Ping"
                    value: netPanel.formatPingLatency(netPanel.internetPingLatency)
                    valueColor: netPanel.internetPingPacketLoss > 0 ? root.seal : root.ink
                }
                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "Packet Loss"
                    value: netPanel.hasInternetPing ? netPanel.internetPingPacketLoss + "%" : "--"
                    valueColor: netPanel.internetPingPacketLoss > 0 ? root.seal : root.ink
                }
                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "Receiving"
                    value: netPanel.hasTransferStats ? netPanel.formatBytes(netPanel.downloadRate) + "/s" : "--"
                }
                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "Sending"
                    value: netPanel.hasTransferStats ? netPanel.formatBytes(netPanel.uploadRate) + "/s" : "--"
                }
                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "Downloaded"
                    value: netPanel.hasTransferStats ? netPanel.formatBytes(parseFloat(netPanel.info.rx_bytes || "0")) : "--"
                }
                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "Uploaded"
                    value: netPanel.hasTransferStats ? netPanel.formatBytes(parseFloat(netPanel.info.tx_bytes || "0")) : "--"
                }
                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "IP Address"
                    value: netPanel.info.ip || "--"; copyable: true
                }
                NetStatCell {
                    root: netPanel.root; width: statsGrid.cellW; label: "Gateway"
                    value: netPanel.info.gateway || "--"; copyable: true
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── DNS provider ──
            UiText {
                text: "DNS PROVIDER"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                font.bold: true; font.letterSpacing: 1
            }

            Row {
                id: dnsRow
                width: parent.width
                spacing: 6
                readonly property real cellWidth: (width - spacing * (netPanel.dnsProviders.length - 1)) / netPanel.dnsProviders.length

                Repeater {
                    model: netPanel.dnsProviders
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool active: netPanel.dnsProvider === modelData
                        width: dnsRow.cellWidth
                        height: 30
                        radius: root.tileRadius
                        color: active ? root.fillActive : dnsMa.containsMouse ? root.fillHover : "transparent"
                        border.color: active || dnsMa.containsMouse ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        UiText {
                            anchors.centerIn: parent
                            text: modelData
                            color: root.ink
                            font.family: root.mono; font.pixelSize: 11
                            font.bold: parent.active
                        }
                        MouseArea {
                            id: dnsMa
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: netPanel.setDns(modelData)
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: netPanel.hasWifi }

            // ── wifi radio toggle ──
            Item {
                width: parent.width
                height: 24
                visible: netPanel.hasWifi
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 50; height: 22; radius: 11
                    color: !netPanel.wifiBlocked ? root.fillActive
                                                 : wifiToggleMa.containsMouse ? root.fillHover
                                                 : root.fillIdle
                    border.color: (wifiToggleMa.containsMouse || !netPanel.wifiBlocked) ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: netPanel.wifiBlocked ? "OFF" : "ON"
                        color: !netPanel.wifiBlocked ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 10; font.weight: Font.Medium
                    }
                    MouseArea {
                        id: wifiToggleMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: netPanel.toggleWifi()
                    }
                }
            }

            // Available / saved profiles. Both views use the native
            // NetworkManager objects on Omarchy 4 and the iwctl snapshot on
            // legacy installations.
            Row {
                width: parent.width
                height: 28
                spacing: 6
                visible: netPanel.hasWifi && !netPanel.wifiBlocked && (!root.useNM || netPanel.nmAdapterReady)

                Repeater {
                    model: [
                        { label: "Available", saved: false },
                        { label: "Saved" + (netPanel.savedCount > 0 ? " (" + netPanel.savedCount + ")" : ""), saved: true }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 6) / 2
                        height: 28
                        radius: root.tileRadius
                        readonly property bool active: netPanel.savedOnly === modelData.saved
                        color: active ? root.fillActive : tabMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: active || tabMa.containsMouse ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        UiText {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.active ? root.seal : root.ink
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                netPanel.savedOnly = modelData.saved
                                if (!modelData.saved) netPanel.scan()
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 16
                visible: netPanel.hasWifi && !netPanel.wifiBlocked && (!root.useNM || netPanel.nmAdapterReady)
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: netPanel.savedOnly ? "SAVED NETWORKS" : "AVAILABLE NETWORKS"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    visible: !netPanel.savedOnly
                    text: netPanel.scanning ? "scanning…" : "rescan"
                    color: rescanMa.containsMouse ? root.fillPrimaryHover : root.seal
                    font.family: root.mono; font.pixelSize: 10
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: rescanMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: netPanel.scan() }
                }
            }

            // scrollable network list
            Flickable {
                id: networkFlick
                width: parent.width
                height: Math.min(netList.implicitHeight, 180)
                contentHeight: netList.implicitHeight
                clip: true
                visible: netPanel.hasWifi && !netPanel.wifiBlocked && (!root.useNM || netPanel.nmAdapterReady)
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: netList
                    width: parent.width
                    spacing: 4

                    Repeater {
                        id: networkRepeater
                        model: netPanel.shownNetworks
                        delegate: Column {
                            id: netTile
                            required property var modelData
                            required property int index
                            width: netList.width
                            spacing: 4
                            readonly property bool expanded: netPanel.selectedNetworkKey === netPanel.networkKey(modelData)
                            readonly property bool keyboardSelected: netPanel.keyboardIndex === index
                            readonly property bool confirmingForget: netPanel.pendingForgetKey === netPanel.networkKey(modelData)

                            Connections {
                                target: root.useNM && modelData.network ? modelData.network : null
                                function onConnectedChanged() {
                                    if (modelData.network && modelData.network.connected)
                                        netPanel.handleNmConnected(modelData.network)
                                    netPanel.refreshNmNetworks()
                                }
                                function onKnownChanged() { netPanel.refreshNmNetworks() }
                                function onStateChangingChanged() { netPanel.refreshNmNetworks() }
                                function onSignalStrengthChanged() { netPanel.refreshNmNetworks() }
                                function onConnectionFailed(reason) {
                                    netPanel.handleNmConnectionFailed(modelData.network, reason)
                                    netPanel.refreshNmNetworks()
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 30
                                radius: root.tileRadius
                                readonly property bool active: nma.containsMouse || netTile.expanded || netTile.keyboardSelected
                                color: modelData.conn ? root.fillActive : active ? root.fillHover : root.fillIdle
                                border.color: modelData.conn || active ? root.seal : root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    IconText {
                                        text: modelData.sec === "open" ? "\uE898" : "\uE897"
                                        font.pixelSize: 12
                                        color: root.sumiHi
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    UiText {
                                        text: modelData.ssid
                                        color: (nma.containsMouse || modelData.conn) ? root.seal : root.ink
                                        font.family: root.mono; font.pixelSize: 11
                                        font.weight: modelData.conn ? Font.Medium : Font.Normal
                                        width: modelData.conn ? 116 : 170; elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    UiText {
                                        visible: modelData.conn
                                        text: "· Connected"
                                        color: root.seal
                                        font.family: root.mono; font.pixelSize: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    anchors.right: detailButton.left; anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    UiText {
                                        visible: modelData.known && !modelData.conn
                                        text: netPanel.isNeverConnected(modelData) ? "profile" : "saved"
                                        color: root.sumiHi
                                        font.family: root.mono
                                        font.pixelSize: 9
                                    }
                                    Row {
                                        spacing: 2
                                        Repeater {
                                            model: 4
                                            delegate: Rectangle {
                                                required property int index
                                                width: 3; height: 4 + index * 2; radius: 1
                                                anchors.bottom: parent.bottom
                                                color: index < modelData.sig
                                                    ? (modelData.conn ? root.seal : root.ink)
                                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: nma
                                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    anchors.right: detailButton.left
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: netPanel.keyboardIndex = netTile.index
                                    onClicked: netPanel.activateNetwork(modelData)
                                }

                                UiText {
                                    id: detailButton
                                    anchors.right: parent.right; anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    text: netTile.expanded ? "⌃" : "›"
                                    color: detailMa.containsMouse || netTile.expanded ? root.seal : root.sumiHi
                                    font.family: root.mono; font.pixelSize: 13
                                    MouseArea {
                                        id: detailMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: netPanel.keyboardIndex = netTile.index
                                        onClicked: netPanel.selectNetwork(modelData)
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: netTile.expanded ? detailColumn.implicitHeight + 16 : 0
                                visible: height > 0
                                clip: true
                                radius: root.tileRadius
                                color: root.fillIdle
                                border.color: root.sep
                                border.width: netTile.expanded ? 1 : 0
                                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                Column {
                                    id: detailColumn
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 6

                                    UiText {
                                        width: parent.width
                                        text: {
                                            var details = [
                                                netPanel.protectionLabel(modelData),
                                                modelData.visible === false
                                                    ? "Not currently visible"
                                                    : "Signal " + (modelData.sig * 25) + "%"
                                            ]
                                            if (modelData.known)
                                                details.push(netPanel.isNeverConnected(modelData)
                                                    ? "Never connected" : "Saved")
                                            return details.join(" · ")
                                        }
                                        color: root.sumiHi
                                        font.family: root.mono; font.pixelSize: 10
                                        wrapMode: Text.Wrap
                                    }

                                    Row {
                                        width: parent.width
                                        height: 26
                                        spacing: 6

                                        Rectangle {
                                            width: modelData.known ? (parent.width - 6) / 2 : parent.width
                                            height: parent.height
                                            radius: root.tileRadius
                                            color: networkActionMa.containsMouse ? root.fillHover : root.fillIdle
                                            border.color: networkActionMa.containsMouse ? root.seal : root.sep
                                            border.width: 1
                                            UiText {
                                                anchors.centerIn: parent
                                                text: netTile.confirmingForget
                                                    ? "Cancel"
                                                    : modelData.conn ? "Disconnect" : modelData.known ? "Reconnect" : "Connect"
                                                color: root.ink
                                                font.family: root.mono; font.pixelSize: 10
                                            }
                                            MouseArea {
                                                id: networkActionMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (netTile.confirmingForget)
                                                        netPanel.cancelForget()
                                                    else
                                                        netPanel.activateNetwork(modelData)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: modelData.known
                                            width: (parent.width - 6) / 2
                                            height: parent.height
                                            radius: root.tileRadius
                                            color: forgetMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18) : root.fillIdle
                                            border.color: forgetMa.containsMouse ? root.seal : root.sep
                                            border.width: 1
                                            UiText {
                                                anchors.centerIn: parent
                                                text: netTile.confirmingForget ? "Confirm" : "Forget"
                                                color: forgetMa.containsMouse ? root.seal : root.ink
                                                font.family: root.mono; font.pixelSize: 10
                                            }
                                            MouseArea {
                                                id: forgetMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: netPanel.requestForget(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiText {
                        visible: !netPanel.scanning && netPanel.shownNetworks.length === 0
                        width: netList.width; horizontalAlignment: Text.AlignHCenter
                        text: netPanel.savedOnly ? "No saved networks" : "No networks found"
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                        font.family: root.mono; font.pixelSize: 11
                    }
                    UiText {
                        visible: netPanel.networkActionError !== ""
                        width: netList.width
                        text: netPanel.networkActionError
                        color: root.seal
                        wrapMode: Text.Wrap
                        font.family: root.mono; font.pixelSize: 10
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: visible ? 92 : 0
                visible: root.useNM && netPanel.nmAdapterReady && netPanel.nmPasswordSsid !== ""
                radius: root.tileRadius
                color: root.fillIdle
                border.color: netPanel.nmConnectionError !== "" ? root.sealRaw : root.seal
                border.width: 1
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    UiText {
                        width: parent.width
                        text: netPanel.nmConnectionError !== ""
                            ? netPanel.nmConnectionError
                            : "Password for " + netPanel.nmPasswordSsid
                        color: netPanel.nmConnectionError !== "" ? root.sealRaw : root.ink
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: parent.width
                        height: 24
                        radius: root.tileRadius
                        color: root.bg
                        border.color: nmPasswordInput.activeFocus ? root.seal : root.sep
                        border.width: 1

                        TextInput {
                            id: nmPasswordInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: netPanel.nmPasswordText
                            echoMode: TextInput.Password
                            color: root.ink
                            selectionColor: root.seal
                            selectedTextColor: root.paper
                            font.family: root.mono
                            font.pixelSize: 11
                            clip: true
                            enabled: !netPanel.nmConnecting
                            onTextChanged: netPanel.nmPasswordText = text
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    netPanel.submitNmPassword()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    netPanel.clearNmPassword()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 22
                        spacing: 6

                        Rectangle {
                            width: (parent.width - 6) / 2
                            height: parent.height
                            radius: root.tileRadius
                            color: passwordSubmitMa.enabled
                                ? (passwordSubmitMa.containsMouse ? root.fillPrimaryHover : root.seal)
                                : root.fillIdle
                            border.color: passwordSubmitMa.enabled ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: netPanel.nmConnecting ? "connecting…" : "connect"
                                color: passwordSubmitMa.enabled ? root.paper : root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: passwordSubmitMa
                                anchors.fill: parent
                                enabled: netPanel.nmPasswordText !== "" && !netPanel.nmConnecting
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: netPanel.submitNmPassword()
                            }
                        }

                        Rectangle {
                            width: (parent.width - 6) / 2
                            height: parent.height
                            radius: root.tileRadius
                            color: passwordCancelMa.containsMouse ? root.fillHover : root.fillIdle
                            border.color: passwordCancelMa.containsMouse ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: "cancel"
                                color: passwordCancelMa.containsMouse ? root.seal : root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: passwordCancelMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: netPanel.clearNmPassword()
                            }
                        }
                    }
                }
            }

            // NetworkManager (Omarchy 4.0): the iwctl scan/connect don't apply here →
            // show an nmtui shortcut if the Quickshell.Networking adapter is unavailable.
            Rectangle {
                width: parent.width
                height: 52; radius: 6
                visible: root.useNM && netPanel.hasWifi && !netPanel.nmAdapterReady
                color: nmMa.containsMouse ? root.fillHover : root.fillIdle
                border.color: nmMa.containsMouse ? root.seal : root.sep; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Column {
                    anchors.centerIn: parent; spacing: 3; width: parent.width - 24
                    UiText {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: "Managed by NetworkManager"
                        color: root.ink; font.family: root.mono; font.pixelSize: 11
                    }
                    UiText {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: "click to open nmtui"
                        color: root.seal; font.family: root.mono; font.pixelSize: 10
                    }
                }
                MouseArea {
                    id: nmMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.networkVisible = false; netPanel.openWifiSettings() }
                }
            }

        }
    }

    Loader {
        id: nmAdapter
        active: root.useNM
        source: "NetworkManagerAdapter.qml"
        onLoaded: {
            item.panel = netPanel
            item.panelOpen = Qt.binding(function() { return root.networkVisible })
            item.refresh()
        }
    }

    Process {
        id: netData
        command: ["bash", "-c", "omarchy-network-status --verbose 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: netPanel.updateDetails(this.text)
        }
    }

    // poll details while the panel is open (stock panel: 1.5 s)
    Timer {
        interval: 1500
        running: root.networkVisible
        repeat: true
        onTriggered: if (!netData.running) netData.running = true
    }

    Process {
        id: dnsProc
        command: ["bash", "-c", "omarchy-dns 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: netPanel.dnsProvider = this.text.trim() || "DHCP"
        }
    }

    Process {
        id: dnsAction
        command: ["true"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0 && netPanel.pendingDnsProvider !== "")
                netPanel.dnsProvider = netPanel.pendingDnsProvider
            netPanel.pendingDnsProvider = ""
        }
    }

    Timer {
        interval: 2800
        running: root.networkVisible && netPanel.mode !== "none"
        repeat: true
        onTriggered: phraseSwap.restart()
    }

    SequentialAnimation {
        id: phraseSwap
        NumberAnimation { target: heroMeta; property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutQuad }
        ScriptAction { script: netPanel.connectionPhraseIndex = (netPanel.connectionPhraseIndex + 1) % netPanel.connectionPhrases.length }
        NumberAnimation { target: heroMeta; property: "opacity"; to: 1; duration: 260; easing.type: Easing.InQuad }
    }

    Process { id: wifiRunner; command: ["bash", "-c", root.launchWifiCmd] }

    // detect wifi device presence
    Process {
        id: devProbe
        command: ["bash", "-c", "for d in /sys/class/net/*/wireless; do [ -e \"$d\" ] || continue; basename \"$(dirname \"$d\")\"; break; done 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var d = this.text.trim()
                netPanel.wdev = d
                netPanel.hasWifi = d !== ""
                if (netPanel.hasWifi) netPanel.scan()
            }
        }
    }

    // scan + list available networks (and known networks)
    Process {
        id: scanProc
        command: ["bash", "-c",
            "DEV=$(for d in /sys/class/net/*/wireless; do [ -e \"$d\" ] || continue; basename \"$(dirname \"$d\")\"; break; done); " +
            "[ -z \"$DEV\" ] && exit; " +
            "iwctl station \"$DEV\" scan >/dev/null 2>&1; sleep 1.5; " +
            "iwctl known-networks list 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g; s/\\r//g' | " +
            "  awk '/^[[:space:]]*-+[[:space:]]*$/ {s++; next} s>=2 && NF>0 { sub(/^[[:space:]]+/,\"\"); sub(/[[:space:]][[:space:]]+.*$/,\"\"); if(length) print \"KNOWN\\t\" $0 }'; " +
            "iwctl station \"$DEV\" get-networks 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g; s/\\r//g' | " +
            "  awk '" +
            "    /^[[:space:]]*-+[[:space:]]*$/ { seps++; next } " +
            "    seps>=2 && NF>0 { " +
            "      line=$0; conn=0; " +
            "      if (line ~ /^[[:space:]]*>/) conn=1; " +
            "      sub(/^[[:space:]]*>?[[:space:]]*/, \"\", line); " +
            "      if (match(line, /[[:space:]]+(open|psk|8021x|wep)[[:space:]]+\\*+[[:space:]]*$/)) { " +
            "        tail=substr(line, RSTART); ssid=substr(line, 1, RSTART-1); " +
            "        gsub(/[[:space:]]+$/, \"\", ssid); " +
            "        n=split(tail, a, /[[:space:]]+/); sec=\"\"; sig=0; " +
            "        for(i=1;i<=n;i++){ if(a[i] ~ /^(open|psk|8021x|wep)$/) sec=a[i]; if(a[i] ~ /^\\*+$/) sig=length(a[i]) } " +
            "        print \"NET\\t\" conn \"\\t\" ssid \"\\t\" sec \"\\t\" sig " +
            "      } " +
            "    }'"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var nets = [], kn = []
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")
                    if (p[0] === "KNOWN" && p[1]) {
                        kn.push(p[1].trim())
                    } else if (p[0] === "NET" && p.length >= 5) {
                        nets.push({ conn: p[1] === "1", ssid: p[2], sec: p[3], sig: parseInt(p[4]) || 0, known: false, visible: true })
                    }
                }
                for (var j = 0; j < nets.length; j++)
                    nets[j].known = kn.indexOf(nets[j].ssid) >= 0
                for (var k = 0; k < kn.length; k++) {
                    var found = false
                    for (var n = 0; n < nets.length; n++) {
                        if (nets[n].ssid === kn[k]) {
                            found = true
                            break
                        }
                    }
                    if (!found)
                        nets.push({ conn: false, ssid: kn[k], sec: "saved", sig: 0, known: true, visible: false })
                }
                // connected first, then by signal
                nets.sort(function(a, b) { return (b.conn - a.conn) || (b.sig - a.sig) })
                netPanel.networks = nets
                netPanel.known = kn
                netPanel.scanning = false
                scanWatchdog.stop()
            }
        }
    }

    Process { id: connectProc; command: ["bash", "-c", "true"] }
    Process {
        id: forgetProc
        command: ["true"]
        running: false
        onExited: rescanTimer.restart()
    }

    Timer { id: rescanTimer; interval: 1500; onTriggered: { netData.running = false; netData.running = true; netPanel.scan() } }
    Timer { id: forgetConfirmTimer; interval: 5000; onTriggered: netPanel.pendingForgetKey = "" }
    // safety: if a scan hangs, don't block future rescans forever
    Timer { id: scanWatchdog; interval: 8000; onTriggered: netPanel.scanning = false }
    Timer {
        id: nmConnectTimeout
        interval: 20000
        onTriggered: {
            if (!netPanel.nmConnecting)
                return

            netPanel.nmConnecting = false
            netPanel.nmConnectionError = "Connection timed out"
            Qt.callLater(function() {
                if (nmPasswordInput.visible)
                    nmPasswordInput.forceActiveFocus()
            })
        }
    }

    // ── wifi radio (rfkill) ──
    Process {
        id: rfkillState
        command: ["bash", "-c", "rfkill list wifi 2>/dev/null | grep -qi 'Soft blocked: yes' && echo BLOCKED || echo OK"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { netPanel.wifiBlocked = this.text.trim() === "BLOCKED" }
        }
    }
    Process { id: rfkillToggle; command: ["bash", "-c", "true"] }

    onVisibleChanged: {
        if (visible) {
            if (!root.useNM) {
                rfkillState.running = false; rfkillState.running = true
            } else if (nmAdapterReady) {
                nmAdapter.item.refresh()
            }
            // fresh throughput/ping baseline for this opening
            prevSampleTime = 0
            internetPingSamples = []
            netData.running = false; netData.running = true
            dnsProc.running = false; dnsProc.running = true
            devProbe.running = false; devProbe.running = true
        } else {
            phraseSwap.stop()
            heroMeta.opacity = 1
            clearNmPassword()
            resetNetworkSelection()
        }
    }
}
