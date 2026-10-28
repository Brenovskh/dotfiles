import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calPopup
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-calendar"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property real reveal: root.calendarVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.calendarVisible ? 160 : 120
            easing.type: root.calendarVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarVisible = false
    }

    // Grid geometry copied verbatim from Omarchy Quattro's stock clock
    // Panel.qml (its cellWidth/cellHeight/cellSpacing/weekColumnWidth/
    // gutterWidth, which resolve to these pixels at the default font scale)
    // so the calendar reads at the same size, width and proportions.
    readonly property int cellW: 52
    readonly property int cellH: 34
    readonly property int cellGap: 2
    readonly property int weekColW: 32
    readonly property int gutterW: 14
    readonly property int gridW: weekColW + cellGap + gutterW + cellGap + 7 * cellW + 6 * cellGap  // 426

    // ── year overview (right-click the card to toggle) ──
    property bool yearView: false
    property int yearOffset: 0
    readonly property var monthShortNames: ["JAN","FEB","MAR","APR","MAY","JUN",
                                             "JUL","AUG","SEP","OCT","NOV","DEC"]
    property string newEventTitle: ""
    property string newEventTime: ""

    Connections {
        target: root
        function onCalendarVisibleChanged() {
            if (!root.calendarVisible) {
                calPopup.yearView = false;
                calPopup.yearOffset = 0;
                calPopup.newEventTitle = "";
                calPopup.newEventTime = "";
            }
        }
    }

    function startAddEvent() {
        root.calendarAddingEvent = true;
        calPopup.newEventTitle = "";
        calPopup.newEventTime = "";
        root.calendarNewEventNotify = false;
        Qt.callLater(function() { titleInput.forceActiveFocus(); });
    }

    function cancelAddEvent() {
        root.calendarAddingEvent = false;
    }

    function saveNewEvent() {
        if (String(calPopup.newEventTitle).trim() === "") return;
        root.calendarAddEvent(root.calendarSelectedDateKey, calPopup.newEventTitle, calPopup.newEventTime, root.calendarNewEventNotify);
        root.calendarAddingEvent = false;
    }

    function formatSelectedDayLabel() {
        const parts = root.calendarSelectedDateKey.split("-");
        if (parts.length !== 3) return "";
        const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
        return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear();
    }

    // "Fri 6 · 09:30" — weekday + day-of-month + local start time for one
    // F1 session, used in the race-weekend schedule below the grid.
    function f1SessionWhen(s) {
        const parts = String(s.dateKey).split("-");
        if (parts.length !== 3) return s.time;
        const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
        const wd = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()];
        return wd + " " + d.getDate() + " · " + s.time;
    }

    Rectangle {
        id: card
        width: calPopup.gridW + 140          // grid centered with stock-sized side margins
        height: col.implicitHeight + 32
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: calPopup.reveal
        focus: root.calendarVisible

        Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.calendarVisible = false;
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) calPopup.yearView = !calPopup.yearView;
            }
        }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // ── hero: calendar glyph + today's date, centered. Clicking it
            //    steps the grid back to the current month. Same composition
            //    and scale as Omarchy Quattro's stock clock calendar; month/
            //    year navigation lives in the footer row below the grid. ──
            Item {
                width: parent.width
                height: 66
                visible: !calPopup.yearView

                Row {
                    id: heroRow
                    anchors.centerIn: parent
                    spacing: 20

                    readonly property bool dirty: root.calendarMonthOffset !== 0
                    readonly property color heroColor: heroMa.containsMouse && heroRow.dirty ? root.seal : root.ink

                    UiText {
                        anchors.baseline: heroDate.baseline
                        text: "󰃭"   // 󰃭  nf-md-calendar
                        color: heroRow.heroColor
                        font.family: root.mono
                        font.pixelSize: 44
                    }
                    UiText {
                        id: heroDate
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            calPopup.root.calendarTick;
                            const d = new Date();
                            const mn = ["January","February","March","April","May","June",
                                        "July","August","September","October","November","December"];
                            return mn[d.getMonth()] + " " + d.getDate();
                        }
                        color: heroRow.heroColor
                        font.family: root.mono
                        font.pixelSize: 48
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: heroMa
                    anchors.fill: parent
                    hoverEnabled: root.calendarMonthOffset !== 0
                    cursorShape: root.calendarMonthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.calendarMonthOffset = 0
                }
            }

            // ── year progress, doubling as the rule under the hero.
            //    Spans the grid width, centered. ──
            Item {
                width: parent.width
                height: 16
                visible: !calPopup.yearView

                Item {
                    id: yearRail
                    width: calPopup.gridW
                    height: parent.height
                    anchors.horizontalCenter: parent.horizontalCenter

                    UiText {
                        id: yearLabel
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: String((new Date()).getFullYear())
                        color: root.inkDeep
                        opacity: 0.75
                        font.family: root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                    UiText {
                        id: yearPct
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: root.calendarYearProgressPercent + "%"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                    Rectangle {
                        anchors.left: yearLabel.right; anchors.leftMargin: 12
                        anchors.right: yearPct.left; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6; radius: 3
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)
                        Rectangle {
                            width: Math.round(parent.width * root.calendarYearProgress)
                            height: parent.height; radius: 3; color: root.seal
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            // ── month grid: week-number gutter, then seven day columns.
            //    Fixed width (calPopup.gridW), centered. Scroll wheel over it
            //    steps the month. ──
            Item {
                width: parent.width
                height: gridBlock.implicitHeight + 18
                visible: !calPopup.yearView

                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y === 0) return
                        root.calendarMonthOffset += event.angleDelta.y > 0 ? -1 : 1
                    }
                }

                Column {
                    id: gridBlock
                    y: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: calPopup.cellGap

                    // weekday header — "W" doubles as the week-start toggle
                    Row {
                        id: headerRow
                        spacing: calPopup.cellGap

                        Rectangle {
                            width: calPopup.weekColW
                            height: 16
                            radius: root.tileRadius
                            color: weekStartMa.containsMouse ? root.pillBorder : "transparent"
                            UiText {
                                anchors.centerIn: parent
                                text: "W"
                                color: weekStartMa.containsMouse ? root.seal : root.inkDeep
                                opacity: weekStartMa.containsMouse ? 1.0 : 0.7
                                font.family: root.mono
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: weekStartMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleCalendarWeekStart()
                            }
                        }

                        Item { width: calPopup.gutterW; height: 16 }

                        Repeater {
                            model: root.calendarWeekdayLabels
                            delegate: Item {
                                required property string modelData
                                required property int index
                                width: calPopup.cellW
                                height: 16
                                readonly property bool isWeekendCol: root.calendarWeekStart === 1 ? index >= 5 : (index === 0 || index === 6)
                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: isWeekendCol ? root.seal : root.inkDeep
                                    opacity: isWeekendCol ? 0.85 : 0.7
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    Repeater {
                        model: 6
                        delegate: Row {
                            required property int index
                            readonly property int rowIndex: index
                            spacing: calPopup.cellGap

                            Item {
                                width: calPopup.weekColW
                                height: calPopup.cellH
                                UiText {
                                    anchors.centerIn: parent
                                    text: root.calendarWeekNumbers[rowIndex] !== undefined ? root.calendarWeekNumbers[rowIndex] : ""
                                    color: root.inkDeep
                                    opacity: 0.55
                                    font.family: root.mono
                                    font.pixelSize: 10
                                }
                            }

                            Item { width: calPopup.gutterW; height: calPopup.cellH }

                            Repeater {
                                model: root.calendarCells.slice(rowIndex * 7, rowIndex * 7 + 7)
                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: calPopup.cellW
                                    height: calPopup.cellH

                                    readonly property int dayOfWeek: index
                                    readonly property bool isCurrentMonth: modelData.day !== 0
                                    readonly property bool isToday: modelData.today
                                    readonly property bool isSelected: isCurrentMonth && root.calendarSelectedDateKey === modelData.dateKey
                                    readonly property bool isWeekendCol: root.calendarWeekStart === 1 ? dayOfWeek >= 5 : (dayOfWeek === 0 || dayOfWeek === 6)

                                    readonly property color textColor: {
                                        if (!isCurrentMonth) return root.inkDeep;
                                        if (modelData.f1Gp) return root.f1Accent;
                                        if (isToday) return root.ink;
                                        return isWeekendCol ? root.seal : root.ink;
                                    }

                                    // Today is the whole cell outlined, not filled —
                                    // matches Omarchy Quattro.
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: root.tileRadius
                                        color: "transparent"
                                        border.color: root.seal; border.width: 1
                                        visible: isToday
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: root.tileRadius
                                        border.color: root.pillBorder; border.width: 1
                                        color: "transparent"
                                        visible: isSelected && !isToday
                                    }

                                    UiText {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: modelData.hasEvent ? -2 : 0
                                        text: modelData.day === 0 ? "" : modelData.day
                                        color: textColor
                                        opacity: isCurrentMonth ? 1.0 : 0.3
                                        font.family: root.mono
                                        font.pixelSize: 12
                                        font.weight: (isToday || modelData.f1Gp) ? Font.Bold : Font.Light
                                    }

                                    Rectangle {
                                        width: 3; height: 3; radius: 1.5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        visible: modelData.hasEvent
                                        color: root.seal
                                    }

                                    // F1 race-weekend marker: a small red dot top-right;
                                    // a touch bigger and filled on the actual race day.
                                    Rectangle {
                                        readonly property int sz: modelData.f1Gp ? 5 : 3
                                        width: sz; height: sz; radius: sz / 2
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.rightMargin: 5
                                        anchors.topMargin: 5
                                        visible: modelData.f1 && isCurrentMonth
                                        color: root.f1Accent
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: isCurrentMonth
                                        enabled: isCurrentMonth
                                        cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.calendarSelectDay(modelData.day, modelData.dateKey)
                                    }
                                }
                            }
                        }
                    }
                }

                // hairline centered in the gutter, spanning only the day rows
                Rectangle {
                    x: gridBlock.x + calPopup.weekColW + calPopup.cellGap + Math.round((calPopup.gutterW - width) / 2)
                    y: gridBlock.y + headerRow.height + gridBlock.spacing
                    width: 1
                    height: gridBlock.implicitHeight - headerRow.height - gridBlock.spacing
                    color: root.ink
                    opacity: 0.1
                }
            }

            // ── footer: month stepper spanning the grid, ‹ AUGUST 2026 ›.
            //    Chevrons sit on the grid's outer bounds; the label is
            //    centered and fixed-width so it holds still between months.
            //    In year-overview mode (right-click the card) it steps the
            //    year instead. Matches Omarchy Quattro. ──
            Item {
                width: parent.width
                height: 34

                Item {
                    id: footerNav
                    width: calPopup.gridW
                    height: parent.height
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        anchors.left: parent.left; anchors.leftMargin: -6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26; radius: root.tileRadius
                        color: navPrevMa.containsMouse ? root.pillBorder : "transparent"
                        UiText {
                            anchors.centerIn: parent
                            text: "‹"
                            color: navPrevMa.containsMouse ? root.seal : root.sumi
                            font.family: root.mono; font.pixelSize: 16
                        }
                        MouseArea {
                            id: navPrevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.yearView ? calPopup.yearOffset-- : root.calendarMonthOffset--
                        }
                    }

                    UiText {
                        id: footerLabel
                        anchors.centerIn: parent
                        width: 140
                        horizontalAlignment: Text.AlignHCenter
                        readonly property bool dirty: calPopup.yearView ? calPopup.yearOffset !== 0 : root.calendarMonthOffset !== 0
                        text: calPopup.yearView
                            ? String((new Date()).getFullYear() + calPopup.yearOffset)
                            : (root.calendarMonthName + " " + root.calendarYear)
                        color: footerMa.containsMouse && footerLabel.dirty ? root.seal : root.inkDeep
                        opacity: 0.9
                        font.family: root.mono
                        font.pixelSize: 12
                        font.letterSpacing: 1

                        MouseArea {
                            id: footerMa
                            anchors.fill: parent; anchors.margins: -6
                            enabled: footerLabel.dirty
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: calPopup.yearView ? calPopup.yearOffset = 0 : root.calendarMonthOffset = 0
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: -6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26; radius: root.tileRadius
                        color: navNextMa.containsMouse ? root.pillBorder : "transparent"
                        UiText {
                            anchors.centerIn: parent
                            text: "›"
                            color: navNextMa.containsMouse ? root.seal : root.sumi
                            font.family: root.mono; font.pixelSize: 16
                        }
                        MouseArea {
                            id: navNextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.yearView ? calPopup.yearOffset++ : root.calendarMonthOffset++
                        }
                    }
                }
            }

            // ── Formula 1: when the selected day is part of a race weekend,
            //    show that Grand Prix and its full session schedule (local
            //    time). Data source: f1calendar.com (sportstimes/f1). ──
            Item {
                width: parent.width
                height: f1Section.visible ? f1Section.height : 0
                visible: !calPopup.yearView
                clip: true

                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Column {
                    id: f1Section
                    readonly property var race: root.f1ForDay(root.calendarSelectedDateKey)
                    visible: race !== null && race !== undefined
                    width: parent.width
                    spacing: 6

                    Rectangle { width: parent.width; height: 1; color: root.sep }

                    Row {
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: f1Badge.implicitWidth + 12; height: 16
                            radius: root.tileRadius
                            color: root.f1Accent
                            UiText {
                                id: f1Badge
                                anchors.centerIn: parent
                                text: "F1"
                                color: "#ffffff"
                                font.family: root.mono; font.pixelSize: 10
                                font.weight: Font.Bold; font.letterSpacing: 1
                            }
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: f1Section.visible ? ("R" + f1Section.race.round + " · " + f1Section.race.name) : ""
                            color: root.ink
                            font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                        }
                    }

                    UiText {
                        width: parent.width
                        text: f1Section.visible ? (f1Section.race.circuit + " · " + f1Section.race.location) : ""
                        color: root.inkDeep; opacity: 0.75
                        font.family: root.mono; font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    UiText {
                        visible: f1Section.visible && f1Section.race.sprint
                        text: "SPRINT WEEKEND"
                        color: root.f1Accent; opacity: 0.9
                        font.family: root.mono; font.pixelSize: 9
                        font.weight: Font.Bold; font.letterSpacing: 1
                    }

                    Repeater {
                        model: f1Section.visible ? f1Section.race.sessions : []
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: 18
                            readonly property bool onDay: modelData.dateKey === root.calendarSelectedDateKey

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                width: 3; height: 14; radius: 1.5
                                color: onDay ? root.f1Accent : root.pillBorder
                            }
                            UiText {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: onDay ? root.ink : root.inkDeep
                                opacity: onDay ? 1.0 : 0.7
                                font.family: root.mono; font.pixelSize: 10
                                font.weight: onDay ? Font.Medium : Font.Light
                            }
                            UiText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: calPopup.f1SessionWhen(modelData)
                                color: onDay ? root.ink : root.inkDeep
                                opacity: onDay ? 0.9 : 0.6
                                font.family: root.mono; font.pixelSize: 10
                            }
                        }
                    }

                    UiText {
                        width: parent.width
                        text: "local time · f1calendar.com"
                        color: root.inkDeep; opacity: 0.45
                        font.family: root.mono; font.pixelSize: 8
                    }
                }
            }

            // ── events for the selected day: list + add-event form.
            //    Feature ported from the "calendar-activity" Omarchy plugin
            //    (github.com/archlatam/omarchy-calendar-activity), MIT. ──
            Item {
                width: parent.width
                height: eventsSection.visible ? eventsSection.height : 0
                visible: !calPopup.yearView

                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Column {
                    id: eventsSection
                    visible: root.calendarSelectedDateKey !== ""
                    width: parent.width
                    spacing: 8

                    Rectangle { width: parent.width; height: 1; color: root.sep }

                    UiText {
                        text: calPopup.formatSelectedDayLabel()
                        color: root.ink
                        font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }

                    Repeater {
                        model: root.calendarEventsForDay(root.calendarSelectedDateKey)
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: 28

                            Rectangle {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                width: 3; height: 22; radius: 1.5
                                color: modelData.notify ? root.seal : root.pillBorder
                            }
                            Column {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.right: delBtn.left; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                UiText {
                                    width: parent.width
                                    text: modelData.title
                                    color: root.ink
                                    font.family: root.mono; font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Row {
                                    spacing: 6
                                    visible: modelData.time !== "" || modelData.notify
                                    UiText {
                                        visible: modelData.time !== ""
                                        text: modelData.time
                                        color: root.inkDeep; opacity: 0.7
                                        font.family: root.mono; font.pixelSize: 9
                                    }
                                    UiText {
                                        visible: modelData.notify
                                        text: "notify"
                                        color: root.seal; opacity: 0.8
                                        font.family: root.mono; font.pixelSize: 9
                                    }
                                }
                            }
                            Rectangle {
                                id: delBtn
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 18; height: 18; radius: 9
                                color: delMa.containsMouse ? root.pillBorder : "transparent"
                                UiText {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: delMa.containsMouse ? root.seal : root.inkDeep
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.calendarDeleteEvent(modelData.id)
                                }
                            }
                        }
                    }

                    UiText {
                        visible: root.calendarEventsForDay(root.calendarSelectedDateKey).length === 0 && !root.calendarAddingEvent
                        text: "No events"
                        color: root.inkDeep; opacity: 0.6
                        font.family: root.mono; font.pixelSize: 10
                        font.italic: true
                    }

                    Rectangle {
                        width: parent.width; height: 26; radius: root.tileRadius
                        visible: !root.calendarAddingEvent
                        color: addEvMa.containsMouse ? root.pillBorder : "transparent"
                        UiText {
                            anchors.centerIn: parent
                            text: "+ Add event"
                            color: addEvMa.containsMouse ? root.seal : root.inkDeep
                            font.family: root.mono; font.pixelSize: 11
                        }
                        MouseArea {
                            id: addEvMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.startAddEvent()
                        }
                    }

                    Column {
                        visible: root.calendarAddingEvent
                        width: parent.width
                        spacing: 6

                        Rectangle {
                            width: parent.width; height: 24; radius: root.tileRadius
                            color: root.bg
                            border.color: titleInput.activeFocus ? root.seal : root.sep
                            border.width: 1
                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                text: calPopup.newEventTitle
                                color: root.ink
                                selectionColor: root.seal
                                selectedTextColor: root.paper
                                font.family: root.mono; font.pixelSize: 11
                                clip: true
                                onTextChanged: calPopup.newEventTitle = text
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { calPopup.saveNewEvent(); event.accepted = true }
                                    else if (event.key === Qt.Key_Escape) { calPopup.cancelAddEvent(); event.accepted = true }
                                }
                            }
                            UiText {
                                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                text: "Event title"
                                color: root.inkDeep; opacity: 0.5
                                font.family: root.mono; font.pixelSize: 11
                                visible: titleInput.text.length === 0 && !titleInput.activeFocus
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width * 0.5; height: 24; radius: root.tileRadius
                                color: root.bg
                                border.color: timeInput.activeFocus ? root.seal : root.sep
                                border.width: 1
                                TextInput {
                                    id: timeInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: calPopup.newEventTime
                                    color: root.ink
                                    selectionColor: root.seal
                                    selectedTextColor: root.paper
                                    font.family: root.mono; font.pixelSize: 11
                                    clip: true
                                    onTextChanged: calPopup.newEventTime = text
                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { calPopup.saveNewEvent(); event.accepted = true }
                                        else if (event.key === Qt.Key_Escape) { calPopup.cancelAddEvent(); event.accepted = true }
                                    }
                                }
                                UiText {
                                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                    text: "HH:MM"
                                    color: root.inkDeep; opacity: 0.5
                                    font.family: root.mono; font.pixelSize: 11
                                    visible: timeInput.text.length === 0 && !timeInput.activeFocus
                                }
                            }

                            Item {
                                width: parent.width * 0.5 - 8; height: 24
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    UiText {
                                        text: "Notify"
                                        color: root.ink
                                        font.family: root.mono; font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle {
                                        width: 30; height: 16; radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.calendarNewEventNotify ? root.seal : root.pillBorder
                                        Rectangle {
                                            x: root.calendarNewEventNotify ? parent.width - width - 2 : 2
                                            y: 2
                                            width: 12; height: 12; radius: 6
                                            color: root.bg
                                            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.calendarNewEventNotify = !root.calendarNewEventNotify
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 12
                            UiText {
                                text: "Save"
                                color: root.seal
                                font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.saveNewEvent() }
                            }
                            UiText {
                                text: "Cancel"
                                color: root.inkDeep
                                font.family: root.mono; font.pixelSize: 11
                                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.cancelAddEvent() }
                            }
                        }
                    }
                }
            }

            // ── year overview: 12 months, right-click the card to toggle ──
            Item {
                id: monthGridWrap
                width: parent.width
                height: monthCol.implicitHeight
                visible: calPopup.yearView

                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y === 0) return
                        calPopup.yearOffset += event.angleDelta.y > 0 ? -1 : 1
                    }
                }

                Column {
                    id: monthCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: 3
                        delegate: Row {
                            required property int index
                            readonly property int rowIndex: index
                            width: monthCol.width

                            Repeater {
                                model: 4
                                delegate: Item {
                                    required property int index
                                    readonly property int monthIndex: rowIndex * 4 + index
                                    width: monthCol.width / 4
                                    height: 40

                                    readonly property var nowD: new Date()
                                    readonly property int targetYear: nowD.getFullYear() + calPopup.yearOffset
                                    readonly property bool isActualCurrent: targetYear === nowD.getFullYear() && monthIndex === nowD.getMonth()
                                    readonly property var viewedDate: new Date(nowD.getFullYear(), nowD.getMonth() + root.calendarMonthOffset, 1)
                                    readonly property bool isViewed: targetYear === viewedDate.getFullYear() && monthIndex === viewedDate.getMonth()

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 56; height: 30; radius: root.tileRadius
                                        color: isActualCurrent ? root.seal : (monthMa2.containsMouse ? root.pillBorder : "transparent")
                                        border.color: root.seal
                                        border.width: (isViewed && !isActualCurrent) ? 1 : 0

                                        UiText {
                                            anchors.centerIn: parent
                                            text: calPopup.monthShortNames[monthIndex]
                                            color: isActualCurrent ? (root.seal.hsvValue < 0.5 ? root.ink : root.paper) : (isViewed ? root.seal : root.ink)
                                            font.family: root.mono
                                            font.pixelSize: 11
                                            font.letterSpacing: 1
                                            font.weight: (isActualCurrent || isViewed) ? Font.Medium : Font.Light
                                        }

                                        MouseArea {
                                            id: monthMa2
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const now = new Date();
                                                root.calendarMonthOffset = (targetYear - now.getFullYear()) * 12 + (monthIndex - now.getMonth());
                                                calPopup.yearView = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
