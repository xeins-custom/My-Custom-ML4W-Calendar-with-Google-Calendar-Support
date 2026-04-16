import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.CustomTheme

PanelWindow {
    id: root
    
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore
    
    implicitWidth: 340
    implicitHeight: 1014
    color: "transparent"

    anchors {
        right: true
        top: true
    }

    property string primaryCalendar: "your_email@gmail.com"

    HyprlandFocusGrab {
        windows: [root]
        active: root.isOpen && root.showWindow
        onCleared: {
            if (root.isOpen) {
                root.isOpen = false
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.isOpen) {
                root.isOpen = false
            }
        }
    }

    // --- ANIMATION & CACHE LOGIC ---
    property bool isOpen: false
    property bool showWindow: false
    visible: showWindow
    
    property var tempEvents: []
    property bool isSyncing: false
    property string cachedMonthKey: ""
    property double lastSyncTime: 0
    property string currentDisplayedMonthKey: ""
    
    property string quickAddErrStr: ""
    property string quickAddOutStr: ""
    property string deleteErrStr: ""
    property string deleteOutStr: ""
    
    property string selTitle: ""
    property string selDate: ""
    property string selTime: ""
    property bool selIsHoliday: false
    
    onIsOpenChanged: {
        if (isOpen) {
            showWindow = true
            var now = new Date()
            if (now.getDate() !== todayDate || now.getMonth() !== todayMonth || now.getFullYear() !== todayYear) {
                todayDate = now.getDate()
                todayMonth = now.getMonth()
                todayYear = now.getFullYear()
                currentMonth = todayMonth
                currentYear = todayYear
                updateCalendar(currentYear, currentMonth)
            } else {
                fetchEvents(currentYear, currentMonth, false)
            }
        }
    }
    
    // --- HORIZONTAL SLIDE ANIMATION ---
    // Lebar panel 340, jadi -360 berarti bersembunyi sepenuhnya di luar layar kanan
    property real currentRightMargin: isOpen ? 8 : -360 

    margins { 
        top: 58 // Jarak statis dari atas (untuk Waybar)
        right: root.currentRightMargin
    }

    Behavior on currentRightMargin {
        NumberAnimation {
            id: slideAnim
            duration: 350
            easing.type: Easing.OutQuint // Efek geseran yang mulus dan natural
            onRunningChanged: {
                if (!running && !root.isOpen) {
                    root.showWindow = false
                }
            }
        }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { root.isOpen = !root.isOpen }
        function open(): void { root.isOpen = true }   
        function close(): void { root.isOpen = false } 
    }

    function formatDisplayDate(isoDate) {
        if (!isoDate) return ""
        var parts = isoDate.split("-")
        if (parts.length !== 3) return isoDate
        return parts[2] + "/" + parts[1] + "/" + parts[0]
    }

    // --- REUSABLE COMPONENTS ---
    component ActionIcon: Button {
        id: iconControl
        property string iconTxt: ""
        property color iconColor: Theme.primary
        implicitWidth: 28
        implicitHeight: 28
        text: iconControl.iconTxt
        font.family: "monospace"
        background: Rectangle { 
            color: "transparent" 
        }
        contentItem: Text { 
            text: iconControl.text
            color: iconControl.iconColor
            font.pixelSize: 18
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter 
        }
    }

    component ML4WButton: Button {
        id: ml4wControl
        property color btnColor: Theme.primary
        background: Rectangle { 
            color: "transparent"
            border.color: ml4wControl.btnColor
            border.width: 1
            radius: 6 
        }
        contentItem: Text { 
            text: ml4wControl.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: ml4wControl.btnColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            padding: 4 
        }
    }

    component PrimaryButton: Button {
        id: primaryControl
        property color btnBgColor: Theme.primary
        property color btnTextColor: Theme.background
        background: Rectangle { 
            color: primaryControl.btnBgColor
            radius: 6 
        }
        contentItem: Text { 
            text: primaryControl.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            color: primaryControl.btnTextColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            padding: 4 
        }
    }

    // --- PROCESS RUNNERS ---
    ListModel { 
        id: eventsModel 
    }

    Process {
        id: openBrowserProcess
    }

    Process {
        id: deleteProcess
        stdout: SplitParser { 
            onRead: function(data) { 
                if (data) {
                    root.deleteOutStr += data.trim() + " "
                }
            } 
        }
        stderr: SplitParser { 
            onRead: function(data) { 
                if (data) {
                    root.deleteErrStr += data.trim() + " "
                }
            } 
        }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                eventDetailOverlay.visible = false
                detailStatusText.text = ""
                fetchEvents(currentYear, currentMonth, true)
            } else {
                var err = root.deleteErrStr.trim()
                if (err === "") {
                    err = root.deleteOutStr.trim()
                }
                if (err === "") {
                    err = "Failed (Exit: " + exitCode + ")"
                }
                detailStatusText.text = "Err: " + err.substring(0, 45)
                detailStatusText.color = "#e06c75"
            }
        }
    }

    Process {
        id: quickAddProcess
        stdout: SplitParser { 
            onRead: function(data) { 
                if (data) {
                    root.quickAddOutStr += data.trim() + " "
                }
            } 
        }
        stderr: SplitParser { 
            onRead: function(data) { 
                if (data) {
                    root.quickAddErrStr += data.trim() + " "
                }
            } 
        }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                eventInput.text = ""
                addEventOverlay.visible = false
                addStatusText.text = ""
                fetchEvents(currentYear, currentMonth, true)
            } else {
                var err = root.quickAddErrStr.trim()
                if (err === "") {
                    err = root.quickAddOutStr.trim()
                }
                if (err === "") {
                    err = "Silently failed (Exit: " + exitCode + ")"
                }
                addStatusText.text = "Err: " + err.substring(0, 45)
                addStatusText.color = "#e06c75"
            }
        }
    }

    Process {
        id: gcalcliProcess
        stdout: SplitParser {
            onRead: function(data) {
                if (!data) return
                var line = data.trim()
                if (line === "" || !line.match(/^\d{4}-\d{2}-\d{2}/)) return
                
                var parts = line.split('\t')
                if (parts.length >= 5) {
                    var isHoliday = (parts[1].trim() === "")
                    root.tempEvents.push({
                        startDate: parts[0].trim(),
                        startTime: parts[1].trim(),
                        endDate: parts[2].trim(),
                        endTime: parts[3].trim(),
                        title: parts.slice(4).join(' ').trim(),
                        isHoliday: isHoliday
                    })
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                eventsModel.clear()
                for (var i = 0; i < root.tempEvents.length; i++) {
                    eventsModel.append(root.tempEvents[i])
                }
            }
            root.isSyncing = false
        }
    }

    function fetchEvents(year, month, forceSync) {
        var targetKey = year + "-" + month
        var currentTime = new Date().getTime()
        
        if (!forceSync && targetKey === cachedMonthKey && (currentTime - lastSyncTime) < 900000) {
            return 
        }
        
        if (targetKey !== currentDisplayedMonthKey) { 
            eventsModel.clear()
            currentDisplayedMonthKey = targetKey 
        }
        
        cachedMonthKey = targetKey
        lastSyncTime = currentTime
        root.isSyncing = true
        root.tempEvents = [] 
        
        var startMonth = String(month + 1).padStart(2, '0')
        var startStr = year + "-" + startMonth + "-01"
        var endObj = new Date(year, month + 1, 0)
        var endStr = endObj.getFullYear() + "-" + String(endObj.getMonth() + 1).padStart(2, '0') + "-" + String(endObj.getDate()).padStart(2, '0')
        
        gcalcliProcess.command = ["gcalcli", "--nocolor", "agenda", startStr, endStr, "--tsv"]
        gcalcliProcess.running = true
    }

    function hasHoliday(isCurrentMonth, dayNum) {
        if (!isCurrentMonth) return false
        var dateStr = currentYear + "-" + String(currentMonth + 1).padStart(2, '0') + "-" + String(dayNum).padStart(2, '0')
        for (var i = 0; i < eventsModel.count; i++) {
            if (dateStr >= eventsModel.get(i).startDate && dateStr <= eventsModel.get(i).endDate && eventsModel.get(i).isHoliday) {
                return true
            }
        }
        return false
    }

    function hasPersonalEvent(isCurrentMonth, dayNum) {
        if (!isCurrentMonth) return false
        var dateStr = currentYear + "-" + String(currentMonth + 1).padStart(2, '0') + "-" + String(dayNum).padStart(2, '0')
        for (var i = 0; i < eventsModel.count; i++) {
            if (dateStr >= eventsModel.get(i).startDate && dateStr <= eventsModel.get(i).endDate && !eventsModel.get(i).isHoliday) {
                return true
            }
        }
        return false
    }

    // --- CALENDAR DATA ---
    property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    property var dayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    property int todayDate: new Date().getDate()
    property int todayMonth: new Date().getMonth()
    property int todayYear: new Date().getFullYear()
    
    ListModel { 
        id: dayModel 
    }
    
    ListModel { 
        id: weekModel 
    }
    
    Component.onCompleted: updateCalendar(currentYear, currentMonth)

    function prevMonth() { 
        if (currentMonth === 0) { 
            currentMonth = 11
            currentYear-- 
        } else { 
            currentMonth-- 
        } 
        updateCalendar(currentYear, currentMonth) 
    }
    
    function nextMonth() { 
        if (currentMonth === 11) { 
            currentMonth = 0
            currentYear++ 
        } else { 
            currentMonth++ 
        } 
        updateCalendar(currentYear, currentMonth) 
    }

    function updateCalendar(year, month) {
        dayModel.clear()
        weekModel.clear()
        fetchEvents(year, month, false)
        
        var firstDay = new Date(year, month, 1)
        var startCell = firstDay.getDay() === 0 ? 6 : firstDay.getDay() - 1
        var daysInMonth = new Date(year, month + 1, 0).getDate()
        var daysInPrevMonth = new Date(year, month, 0).getDate()
        
        for (var row = 0; row < 6; row++) {
            var dateInRow = new Date(year, month, 1 + (row * 7) - startCell)
            var d = new Date(Date.UTC(dateInRow.getFullYear(), dateInRow.getMonth(), dateInRow.getDate()))
            d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay()||7))
            weekModel.append({ weekNumber: Math.ceil(( ( (d - new Date(Date.UTC(d.getUTCFullYear(),0,1))) / 86400000) + 1)/7) })
        }
        
        for (var i = 0; i < 42; i++) {
            if (i < startCell) {
                dayModel.append({ day: daysInPrevMonth - startCell + i + 1, isCurrentMonth: false, isToday: false })
            } else if (i >= startCell && i < startCell + daysInMonth) {
                var dNum = i - startCell + 1
                dayModel.append({ day: dNum, isCurrentMonth: true, isToday: (dNum === todayDate && month === todayMonth && year === todayYear) })
            } else {
                dayModel.append({ day: i - startCell - daysInMonth + 1, isCurrentMonth: false, isToday: false })
            }
        }
    }

    // --- UI LAYOUT ---
    Item {
        anchors.fill: parent
        
        Rectangle { 
            anchors.fill: parent
            color: Theme.background
            border.color: "transparent"
            border.width: 2
            radius: 6
            opacity: 0.95 
        }
        
        ColumnLayout {
            id: topSection
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 15
            
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                
                ActionIcon { 
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    iconTxt: ""
                    opacity: root.isSyncing ? 0.3 : 1.0
                    onClicked: {
                        if (!root.isSyncing) {
                            fetchEvents(currentYear, currentMonth, true)
                        }
                    }
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    ActionIcon { 
                        iconTxt: ""
                        onClicked: prevMonth() 
                    }
                    
                    Text { 
                        Layout.preferredWidth: 120
                        text: monthNames[currentMonth] + " " + currentYear
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter 
                    }
                    
                    ActionIcon { 
                        iconTxt: ""
                        onClicked: nextMonth() 
                    }
                }
                
                ML4WButton { 
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Today"
                    opacity: (currentMonth !== todayMonth || currentYear !== todayYear) ? 1.0 : 0.0
                    enabled: opacity > 0
                    onClicked: { 
                        currentMonth = todayMonth
                        currentYear = todayYear
                        updateCalendar(currentYear, currentMonth) 
                    } 
                }
            }
            
            Rectangle { 
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.primary
                opacity: 0.3 
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                
                ColumnLayout {
                    spacing: 5
                    
                    Text { 
                        Layout.fillWidth: true
                        Layout.preferredHeight: 25
                        text: "Wk"
                        color: Theme.on_background
                        opacity: 0.5
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter 
                    }
                    
                    Repeater { 
                        model: weekModel
                        Text { 
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                            text: model.weekNumber
                            color: Theme.primary
                            opacity: 0.7
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter 
                        } 
                    }
                }
                
                Rectangle { 
                    Layout.fillHeight: true
                    implicitWidth: 1
                    color: Theme.primary
                    opacity: 0.3 
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    RowLayout { 
                        Layout.fillWidth: true
                        Repeater { 
                            model: root.dayNames
                            Text { 
                                Layout.fillWidth: true
                                Layout.preferredHeight: 25
                                text: modelData
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter 
                            } 
                        } 
                    }
                    
                    GridLayout {
                        columns: 7
                        Layout.fillWidth: true
                        rowSpacing: 5
                        columnSpacing: 5
                        
                        Repeater { 
                            model: dayModel
                            
                            Rectangle { 
                                Layout.fillWidth: true
                                Layout.preferredHeight: 35
                                radius: 6
                                color: model.isToday ? Theme.primary : "transparent"
                                
                                Text { 
                                    anchors.centerIn: parent
                                    text: model.day
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: model.isToday
                                    color: model.isToday ? Theme.background : Theme.on_background
                                    opacity: (model.isCurrentMonth || model.isToday) ? 1.0 : 0.3 
                                }
                                
                                Row {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 3
                                    
                                    Rectangle { 
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: "#e06c75"
                                        visible: root.hasHoliday(model.isCurrentMonth, model.day) 
                                    }
                                    
                                    Rectangle { 
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: Theme.primary
                                        visible: root.hasPersonalEvent(model.isCurrentMonth, model.day) 
                                    }
                                }
                            } 
                        }
                    }
                }
            }
            
            Rectangle { 
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.primary
                opacity: 0.3 
            }
            
            Text { 
                text: "Event"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.bold: true
                Layout.topMargin: 1 
                Layout.bottomMargin: 5 
            }
        }

        Item {
            id: bottomSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            height: 35
            
            PrimaryButton { 
                anchors.fill: parent
                text: "+ Add Event"
                onClicked: { 
                    addEventOverlay.visible = true
                    eventInput.forceActiveFocus() 
                } 
            }
        }

        ListView {
            id: agendaList
            anchors.top: topSection.bottom
            anchors.bottom: bottomSection.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            clip: true
            spacing: 8
            model: eventsModel
            
            delegate: Rectangle { 
                width: ListView.view.width
                implicitHeight: eventCol.implicitHeight + 10
                color: "transparent"
                border.color: model.isHoliday ? "#e06c75" : Theme.primary
                border.width: 1
                radius: 6
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selTitle = model.title
                        root.selDate = model.startDate
                        root.selTime = model.startTime
                        root.selIsHoliday = model.isHoliday
                        detailStatusText.text = ""
                        eventDetailOverlay.visible = true
                    }
                }
                
                ColumnLayout { 
                    id: eventCol
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 2
                    
                    Text { 
                        Layout.fillWidth: true
                        text: model.title
                        color: model.isHoliday ? "#e06c75" : Theme.on_background
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight 
                    }
                    
                    Text { 
                        Layout.fillWidth: true
                        text: {
                            var dispDate = root.formatDisplayDate(model.startDate)
                            if (model.startDate !== model.endDate) {
                                return dispDate + "  " + root.formatDisplayDate(model.endDate)
                            }
                            if (model.isHoliday) {
                                return dispDate
                            }
                            return dispDate + "   " + model.startTime
                        }
                        color: Theme.on_background
                        opacity: 0.7
                        font.family: Theme.fontFamily
                        font.pixelSize: 11 
                    } 
                } 
            }
            
            Text { 
                anchors.centerIn: parent
                text: root.isSyncing && eventsModel.count === 0 ? "Syncing..." : "No events this month"
                color: Theme.on_background
                opacity: 0.5
                font.family: Theme.fontFamily
                font.pixelSize: 12
                visible: eventsModel.count === 0 
            }
        }

        // ==========================================
        // DIALOG OVERLAY QUICK ADD EVENT
        // ==========================================
        Rectangle {
            id: addEventOverlay
            anchors.fill: parent
            color: Theme.background
            opacity: 0.98
            visible: false
            radius: 6
            z: 999
            
            MouseArea { 
                anchors.fill: parent 
            }
            
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 15
                
                Text { 
                    text: "Quick Add Event"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter 
                }
                
                TextField { 
                    id: eventInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    leftPadding: 10
                    color: Theme.on_background
                    font.family: Theme.fontFamily
                    background: Rectangle { 
                        color: "transparent"
                        border.color: Theme.primary
                        border.width: 1
                        radius: 6 
                    }
                    onAccepted: {
                        addEventOverlay.submitEvent()
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    ML4WButton { 
                        text: "Cancel"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 35
                        onClicked: { 
                            addEventOverlay.visible = false
                            eventInput.text = ""
                            addStatusText.text = "" 
                        } 
                    }
                    
                    ML4WButton { 
                        text: "Detailed"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 35
                        onClicked: { 
                            addEventOverlay.visible = false
                            var url = "https://accounts.google.com/AccountChooser?Email=" + root.primaryCalendar + "&continue=https://calendar.google.com/calendar/r/eventedit"
                            openBrowserProcess.command = ["xdg-open", url]
                            openBrowserProcess.running = true 
                        } 
                    }
                    
                    PrimaryButton { 
                        text: "Save"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 35
                        onClicked: {
                            addEventOverlay.submitEvent()
                        } 
                    }
                }
                
                Text { 
                    id: addStatusText
                    text: ""
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter 
                }
            }
            
            function submitEvent() {
                if (eventInput.text.trim() === "") return
                addStatusText.text = "Sending..."
                addStatusText.color = Theme.primary
                root.quickAddErrStr = ""
                root.quickAddOutStr = ""
                
                var input = eventInput.text.trim()
                var timeRegex = /(\d{1,2}:\d{2})/
                if (timeRegex.test(input) && !/\bat\s+\d{1,2}:\d{2}/i.test(input)) {
                    input = input.replace(timeRegex, "at $1")
                }
                
                var cmd = "yes | gcalcli --nocolor --calendar '" + root.primaryCalendar + "' quick '" + input + "'"
                quickAddProcess.command = ["bash", "-c", cmd]
                quickAddProcess.running = true
            }
        }

        // ==========================================
        // DIALOG OVERLAY DETAIL & DELETE EVENT
        // ==========================================
        Rectangle {
            id: eventDetailOverlay
            anchors.fill: parent
            color: Theme.background
            opacity: 0.98
            visible: false
            radius: 6
            z: 999
            
            MouseArea { 
                anchors.fill: parent 
            }
            
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 15
                
                Text { 
                    Layout.fillWidth: true
                    text: root.selTitle
                    color: root.selIsHoliday ? "#e06c75" : Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap 
                }
                
                Text { 
                    Layout.fillWidth: true
                    text: root.formatDisplayDate(root.selDate) + (root.selTime !== "" ? "   " + root.selTime : "")
                    color: Theme.on_background
                    opacity: 0.7
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter 
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    ML4WButton { 
                        text: "Cancel"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 35
                        onClicked: { 
                            eventDetailOverlay.visible = false
                            detailStatusText.text = ""
                        } 
                    }
                    
                    PrimaryButton { 
                        text: "Edit in Web"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 35
                        onClicked: { 
                            eventDetailOverlay.openWebDay()
                        } 
                    }
                    
                    PrimaryButton { 
                        text: "Delete"
                        btnBgColor: "#e06c75"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 35
                        visible: !root.selIsHoliday
                        onClicked: {
                            eventDetailOverlay.executeDelete()
                        } 
                    }
                }
                
                Text { 
                    id: detailStatusText
                    text: ""
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter 
                }
            }
            
            function executeDelete() {
                detailStatusText.text = "Deleting..."
                detailStatusText.color = Theme.primary
                root.deleteErrStr = ""
                root.deleteOutStr = ""
                
                var safeTitle = root.selTitle.replace(/'/g, "")
                var cmd = "yes | gcalcli --nocolor --calendar '" + root.primaryCalendar + "' delete '" + safeTitle + "'"
                deleteProcess.command = ["bash", "-c", cmd]
                deleteProcess.running = true
            }
            
            function openWebDay() {
                var parts = root.selDate.split("-")
                if (parts.length === 3) {
                    var url = "https://accounts.google.com/AccountChooser?Email=" + root.primaryCalendar + "&continue=https://calendar.google.com/calendar/r/day/" + parts[0] + "/" + parts[1] + "/" + parts[2]
                    openBrowserProcess.command = ["xdg-open", url]
                    openBrowserProcess.running = true
                }
                eventDetailOverlay.visible = false
                detailStatusText.text = ""
            }
        }
    }
}