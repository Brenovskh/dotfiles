import QtQuick
import Quickshell
import Quickshell.Io

// Bar pill for the Bitcoin price, idea ported from the "gpatkinson.btc-price"
// Omarchy plugin (MIT) — CoinGecko poll + ₿-prefixed label + bitcoin-orange
// accent — but the actual fetch/format logic lives centrally in Theme.qml
// (see the "BTC price" section there) since both this pill and BtcPricePanel
// need the same data.
Item {
    id: rootMod
    required property var root

    readonly property string tooltipText: root.btcPriceLabel !== ""
        ? "Bitcoin · " + root.btcFormatPrice(root.btcPriceUsd)
            + (root.btcPriceChange24h !== 0 ? "  ·  24h " + root.btcFormatChange(root.btcPriceChange24h) : "")
        : (root.btcPriceLoading ? "Bitcoin · loading…" : "Open Bitcoin price")

    visible: implicitWidth > 0.5
    implicitWidth: (root.modBtcPrice && root.btcPriceLabel !== "") ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: (root.modBtcPrice && root.btcPriceLabel !== "") ? 1 : 0
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
            text: root.btcPriceLabel
            color: root.btcPriceColor
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) root.btcPriceRefresh(true)
            else root.btcPriceVisible = !root.btcPriceVisible
        }
    }
}
