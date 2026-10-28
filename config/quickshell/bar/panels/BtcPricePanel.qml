import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Details panel for the Bitcoin price pill (G18). Fetch/format logic lives
// centrally in Theme.qml; this panel just displays it, mirroring
// WeatherPanel.qml's structure (own PanelWindow anchored under the pill).
PanelWindow {
    id: btcPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-btc-price"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property real reveal: root.btcPriceVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.btcPriceVisible ? 160 : 120
            easing.type: root.btcPriceVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.btcPriceVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.btcPriceVisible = false }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.btcPriceBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: btcPanel.reveal
        focus: root.btcPriceVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.btcPriceVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "BITCOIN"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.btcPriceVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            UiText {
                width: parent.width
                text: root.btcPriceUsd > 0 ? root.btcFormatPrice(root.btcPriceUsd) : (root.btcPriceLoading ? "Loading…" : "—")
                color: root.btcPriceColor
                font.family: root.mono
                font.pixelSize: 26
                font.weight: Font.Medium

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.btcToggleColor()
                }
            }

            UiText {
                width: parent.width
                text: root.btcUseOrange ? "Orange · click for default" : "Default · click for orange"
                color: root.ink
                opacity: 0.4
                font.family: root.mono
                font.pixelSize: 10
            }

            // 7-day sparkline (CoinGecko's own sparkline_7d.price series).
            Canvas {
                id: spark
                width: parent.width
                height: 40
                visible: root.btcSparkline.length > 1

                readonly property var pts: root.btcSparkline
                readonly property color tint: (pts.length > 1 && pts[pts.length - 1] < pts[0]) ? root.btcChangeColorDown : root.btcChangeColorUp
                onPtsChanged: requestPaint()
                onTintChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var h = pts
                    if (h.length < 2) return

                    var minV = Math.min.apply(null, h)
                    var maxV = Math.max.apply(null, h)
                    var span = Math.max(maxV - minV, 1)

                    var xs = []
                    for (var i = 0; i < h.length; i++) {
                        xs.push({
                            x: (i / (h.length - 1)) * width,
                            y: height - ((h[i] - minV) / span) * height
                        })
                    }

                    ctx.beginPath()
                    ctx.moveTo(xs[0].x, height)
                    ctx.lineTo(xs[0].x, xs[0].y)
                    for (var j = 1; j < xs.length; j++) ctx.lineTo(xs[j].x, xs[j].y)
                    ctx.lineTo(xs[xs.length - 1].x, height)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.12)
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(xs[0].x, xs[0].y)
                    for (var k = 1; k < xs.length; k++) ctx.lineTo(xs[k].x, xs[k].y)
                    ctx.strokeStyle = tint
                    ctx.lineWidth = 1.5
                    ctx.lineJoin = "round"
                    ctx.stroke()
                }
            }
            UiText {
                width: parent.width
                visible: spark.visible
                text: "7d"
                color: root.ink
                opacity: 0.4
                font.family: root.mono
                font.pixelSize: 10
            }

            Row {
                width: parent.width
                UiText {
                    text: "24h Change"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcPriceUsd > 0 ? root.btcFormatChange(root.btcPriceChange24h) : "—"
                    color: root.btcPriceUsd > 0 ? root.btcChangeColor : root.ink
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
            }

            Row {
                width: parent.width
                visible: root.btcPriceHigh24h > 0
                UiText {
                    text: "24h High"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcFormatPrice(root.btcPriceHigh24h)
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
            }

            Row {
                width: parent.width
                visible: root.btcPriceLow24h > 0
                UiText {
                    text: "24h Low"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcFormatPrice(root.btcPriceLow24h)
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
            }

            Row {
                width: parent.width
                visible: root.btcPriceVolume24h > 0
                UiText {
                    text: "24h Volume"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcFormatBtcAmount(root.btcPriceVolume24h)
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: root.btcPriceBid > 0 }

            Row {
                width: parent.width
                visible: root.btcPriceBid > 0
                UiText {
                    text: "Bid"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcFormatPrice(root.btcPriceBid)
                    color: root.btcChangeColorDown; font.family: root.mono; font.pixelSize: 11
                }
            }

            Row {
                width: parent.width
                visible: root.btcPriceAsk > 0
                UiText {
                    text: "Ask"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcFormatPrice(root.btcPriceAsk)
                    color: root.btcChangeColorUp; font.family: root.mono; font.pixelSize: 11
                }
            }

            Row {
                width: parent.width
                visible: root.btcPriceSpreadPct > 0
                UiText {
                    text: "Spread"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcPriceSpreadPct.toFixed(3) + "%"
                        + (root.btcSpreadExchange !== "" ? "  ·  " + root.btcSpreadExchange : "")
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
            }

            Row {
                width: parent.width
                visible: root.btcPriceUpdatedAt > 0
                UiText {
                    text: "Updated"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: root.btcFormatUpdated(root.btcPriceUpdatedAt)
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
            }

            UiText {
                width: parent.width
                text: "Source: CoinGecko · Bid/Ask/Vol via Bitfinex"
                color: root.ink
                opacity: 0.4
                font.family: root.mono
                font.pixelSize: 10
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Rectangle {
                width: parent.width
                height: 28
                radius: root.tileRadius
                color: root.btcAnyLoading ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.45)
                       : refreshMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: root.btcAnyLoading ? "Updating…" : "Refresh now"
                    color: root.paper; font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !root.btcAnyLoading
                    onClicked: root.btcPriceRefresh(true)
                }
            }
        }
    }

    onVisibleChanged: { if (visible && btcPanel.root.btcPriceUsd === 0) btcPanel.root.btcPriceRefresh(false) }
}
