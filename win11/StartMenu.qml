import Quickshell
import Quickshell.Io
import QtQuick

PopupWindow {
    id: startMenuPopup

    required property PanelWindow barWindow

    anchor.window: barWindow
    anchor.rect.x: 0
    anchor.rect.y: -implicitHeight - 8
    implicitWidth: 660
    implicitHeight: 700
    visible: barWindow.startMenuOpen
    color: "transparent"

    // ── Persistent pinned state ──────────────────────────────────
    property var pinnedStart: []
    property var pinnedTaskbar: []

    FileView {
        id: pinnedStartFile
        path: Qt.resolvedUrl("pinned_start.json")
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            try { startMenuPopup.pinnedStart = JSON.parse(text) } catch(e) {}
        }
    }

    FileView {
        id: pinnedTaskbarFile
        path: Qt.resolvedUrl("pinned_taskbar.json")
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            try { startMenuPopup.pinnedTaskbar = JSON.parse(text) } catch(e) {}
        }
    }

    function savePinnedStart() { pinnedStartFile.setText(JSON.stringify(pinnedStart)) }
    function savePinnedTaskbar() { pinnedTaskbarFile.setText(JSON.stringify(pinnedTaskbar)) }

    function pinToStart(appIcon, appName) {
        for (var i = 0; i < pinnedStart.length; i++)
            if (pinnedStart[i].icon === appIcon) return
        var arr = pinnedStart.slice()
        arr.push({ icon: appIcon, label: appName })
        pinnedStart = arr
        savePinnedStart()
    }

    function unpinFromStart(appIcon) {
        pinnedStart = pinnedStart.filter(function(x) { return x.icon !== appIcon })
        savePinnedStart()
    }

    function pinToTaskbar(appIcon, appName) {
        for (var i = 0; i < pinnedTaskbar.length; i++)                             if (pinnedTaskbar[i].icon === appIcon) return
        var arr = pinnedTaskbar.slice()
        arr.push({ icon: appIcon, label: appName })
        pinnedTaskbar = arr                                                    savePinnedTaskbar()
    }

    function isPinnedToStart(appIcon) {
        for (var i = 0; i < pinnedStart.length; i++)
            if (pinnedStart[i].icon === appIcon) return true
        return false                                                       }

    // ── State ────────────────────────────────────────────────────       property string viewState: "home"
    property string searchQuery: ""

    // ── Shared context menu state ────────────────────────────────
    property string ctxAppIcon: ""
    property string ctxAppName: ""
    property bool ctxIsPinned: false
    property real ctxX: 0                                                  property real ctxY: 0
    property bool ctxVisible: false
    property bool ctxFromPinned: false  // true if opened from pinned grid

    function openContextMenu(appIcon, appName, mouseX, mouseY, fromPinned) {
        ctxAppIcon = appIcon
        ctxAppName = appName
        ctxIsPinned = isPinnedToStart(appIcon)
        ctxFromPinned = fromPinned || false
        // Clamp so menu doesn't go off right/bottom edge
        ctxX = Math.min(mouseX, implicitWidth - contextMenu.width - 4)
        ctxY = Math.min(mouseY, implicitHeight - contextMenu.implicitHeight - 4)
        ctxVisible = true
    }
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() { allAppsList.populate() })
        }
        if (!visible) {
            viewState = "home"
            searchQuery = ""
            searchInput.text = ""
            ctxVisible = false
        }                                                                  }

    // Close context menu when clicking outside                            MouseArea {
        anchors.fill: parent                                                   onClicked: {
            if (startMenuPopup.ctxVisible) {
                startMenuPopup.ctxVisible = false                                  } else {
                barWindow.startMenuOpen = false
            }
        }
        z: -1                                                              }

    Rectangle {                                                                anchors.fill: parent
        radius: 10
        color: "#f01c1c1c"
        border.color: "#3a3a3a"
        border.width: 1
        clip: true
        Column {
            id: mainColumn                                                         anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // ── SEARCH BAR ───────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 44
                radius: 22
                color: "#2a2a2a"
                border.color: searchInput.activeFocus ? "#4cc2ff" : "#555"
                border.width: 1

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 10

                    Item {
                        width: 16; height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: "transparent"
                            border.color: searchInput.activeFocus ? "#4cc2ff" : "#888"
                            border.width: 2
                        }
                        Rectangle {
                            width: 2; height: 6
                            color: searchInput.activeFocus ? "#4cc2ff" : "#888"
                            x: 11; y: 8; rotation: 135
                            transformOrigin: Item.Center
                        }
                    }

                    TextInput {
                        id: searchInput
                        width: 560
                        color: "#ffffff"
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                        selectByMouse: true

                        onTextChanged: {
                            startMenuPopup.searchQuery = text
                            startMenuPopup.viewState = text.length > 0 ? "search" : "home"
                            startMenuPopup.ctxVisible = false
                        }

                        Keys.onEscapePressed: {
                            text = ""
                            startMenuPopup.viewState = "home"
                            barWindow.startMenuOpen = false
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search for apps, settings, files"
                            color: "#888"; font.pixelSize: 13
                            visible: searchInput.text === ""
                        }
                    }
                }
            }

            // ── HOME VIEW ────────────────────────────────────────
            Item {
                width: parent.width
                height: parent.height - 44 - 14
                visible: opacity > 0
                opacity: startMenuPopup.viewState === "home" ? 1 : 0
                x: startMenuPopup.viewState === "home" ? 0 : -parent.width
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    spacing: 14

                    Item {
                        width: parent.width; height: 24

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            text: "Pinned"
                            color: "#ffffff"; font.pixelSize: 13; font.bold: true
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            width: allTxt.implicitWidth + 20; height: 24; radius: 12
                            color: allHover.containsMouse ? "#3d3d3d" : "#2a2a2a"
                            border.color: "#555"; border.width: 1

                            HoverHandler { id: allHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: startMenuPopup.viewState = "allapps"
                            }
                            Text {
                                id: allTxt
                                anchors.centerIn: parent
                                text: "All apps ›"
                                color: "#cccccc"; font.pixelSize: 12
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 6
                        columnSpacing: 0; rowSpacing: 0

                        Repeater {
                            model: startMenuPopup.pinnedStart.length > 0 ? startMenuPopup.pinnedStart : [
                                { icon: "firefox",              label: "Firefox"   },
                                { icon: "org.gnome.Nautilus",   label: "Files"     },
                                { icon: "kitty",                label: "Terminal"  },
                                { icon: "code-oss",             label: "VS Code"   },
                                { icon: "discord",              label: "Discord"   },
                                { icon: "spotify",              label: "Spotify"   },
                                { icon: "steam",                label: "Steam"     },
                                { icon: "gimp",                 label: "GIMP"      },
                                { icon: "vlc",                  label: "VLC"       },
                                { icon: "thunderbird",          label: "Mail"      },
                                { icon: "libreoffice-writer",   label: "Writer"    },
                                { icon: "org.gnome.Calculator", label: "Calc"      },
                            ]

                            delegate: Item {
                                required property var modelData
                                width: 100; height: 82
                                property bool hovered: false

                                HoverHandler { onHoveredChanged: parent.hovered = hovered }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            var pt = mapToItem(startMenuPopup.contentItem, mouse.x, mouse.y)
                                            startMenuPopup.openContextMenu(modelData.icon, modelData.label, pt.x, pt.y, true)
                                        } else {
                                            Quickshell.execDetached(["gtk-launch", modelData.icon])
                                            barWindow.startMenuOpen = false
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 3
                                    radius: 8
                                    color: parent.hovered ? "#333333" : "transparent"
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 36; height: 36

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label.charAt(0).toUpperCase()
                                            color: "#555"; font.pixelSize: 16; font.bold: true
                                        }
                                        Image {
                                            anchors.fill: parent
                                            source: Quickshell.iconPath(modelData.icon, true)
                                            smooth: true
                                            visible: source.toString() !== ""
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: "#dddddd"; font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        width: 88; elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#3a3a3a" }

                    Text {
                        text: "Recommended"
                        color: "#ffffff"; font.pixelSize: 13; font.bold: true
                    }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 8; rowSpacing: 4

                        Repeater {
                            model: [
                                { label: "README.md",      sub: "Just now"      },
                                { label: "notes.txt",      sub: "5 minutes ago" },
                                { label: "screenshot.png", sub: "1 hour ago"    },
                                { label: "config.json",    sub: "Yesterday"     },
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: 290; height: 48; radius: 6
                                property bool hovered: rh.containsMouse
                                color: hovered ? "#333333" : "transparent"

                                HoverHandler { id: rh }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    spacing: 10

                                    Rectangle {
                                        width: 32; height: 32; radius: 6; color: "#2a2a2a"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { anchors.centerIn: parent; text: modelData.label.charAt(0).toUpperCase(); color: "#888"; font.pixelSize: 13 }
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text { text: modelData.label; color: "#ddd"; font.pixelSize: 12 }
                                        Text { text: modelData.sub;   color: "#888"; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: userRow
                        width: parent.width; height: 36
                        property string username: "..."

                        Process {
                            command: ["whoami"]
                            running: true
                            stdout: StdioCollector {
                                onStreamFinished: userRow.username = text.trim()
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 30; height: 30; radius: 15; color: "#4cc2ff"
                                anchors.verticalCenter: parent.verticalCenter
                                Text { anchors.centerIn: parent; text: userRow.username.charAt(0).toUpperCase(); color: "#000"; font.pixelSize: 13; font.bold: true }
                            }
                            Text { text: userRow.username; color: "#fff"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34; height: 34; radius: 6
                            color: pwrHover.containsMouse ? "#3d3d3d" : "transparent"

                            HoverHandler { id: pwrHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                            }

                            Item {
                                anchors.centerIn: parent; width: 18; height: 18
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: 2; height: 8; color: "#ccc" }
                                Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: "transparent"; border.color: "#ccc"; border.width: 2 }
                            }
                        }
                    }
                }
            }

            // ── SEARCH VIEW ──────────────────────────────────────
            Item {
                width: parent.width
                height: parent.height - 44 - 14
                visible: startMenuPopup.viewState === "search"

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Text {
                        text: "Best match"
                        color: "#888"; font.pixelSize: 11
                        bottomPadding: 8
                    }

                    ListView {
                        id: searchResults
                        width: parent.width
                        height: parent.height - 40
                        clip: true
                        spacing: 2

                        model: ScriptModel {
                            values: {
                                var q = startMenuPopup.searchQuery.toLowerCase()
                                if (q === "") return []
                                var results = []
                                var appVals = DesktopEntries.applications.values
                                for (var i = 0; i < appVals.length; i++) {
                                    var e = appVals[i]
                                    if (!e.noDisplay && (
                                        e.name.toLowerCase().indexOf(q) !== -1 ||
                                        (e.comment && e.comment.toLowerCase().indexOf(q) !== -1) ||
                                        (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1)
                                    )) results.push(e)
                                    if (results.length >= 12) break
                                }
                                return results
                            }
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: searchResults.width
                            height: index === 0 ? 64 : 48
                            radius: 8
                            property bool hovered: false
                            color: hovered ? "#333333" : (index === 0 ? "#2a2a2a" : "transparent")
                            border.color: index === 0 ? "#4cc2ff" : "transparent"
                            border.width: index === 0 ? 1 : 0

                            HoverHandler { onHoveredChanged: parent.hovered = hovered }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        var pt = mapToItem(startMenuPopup.contentItem, mouse.x, mouse.y)
                                        startMenuPopup.openContextMenu(modelData.icon, modelData.name, pt.x, pt.y, false)
                                    } else {
                                        modelData.execute()
                                        barWindow.startMenuOpen = false
                                        searchInput.text = ""
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                spacing: 14

                                Item {
                                    width: index === 0 ? 40 : 32
                                    height: index === 0 ? 40 : 32
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name.charAt(0).toUpperCase()
                                        color: "#555"; font.pixelSize: index === 0 ? 18 : 14; font.bold: true
                                    }
                                    Image {
                                        anchors.fill: parent
                                        source: Quickshell.iconPath(modelData.icon, true)
                                        smooth: true
                                        visible: source.toString() !== ""
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        color: "#ffffff"
                                        font.pixelSize: index === 0 ? 14 : 13
                                        font.bold: index === 0
                                    }
                                    Text {
                                        text: index === 0 ? "App · " + (modelData.comment || modelData.genericName || "Application") : (modelData.comment || modelData.genericName || "")
                                        color: "#888"; font.pixelSize: 11
                                        visible: text !== ""
                                    }
                                }
                            }

                            Rectangle {
                                visible: index === 0 && parent.hovered
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 10
                                width: adminTxt.implicitWidth + 16; height: 28; radius: 6
                                color: adminHover.containsMouse ? "#4a4a4a" : "#333"
                                border.color: "#555"; border.width: 1

                                HoverHandler { id: adminHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached(["pkexec", "gtk-launch", modelData.icon])
                                        barWindow.startMenuOpen = false
                                        searchInput.text = ""
                                    }
                                }
                                Text {
                                    id: adminTxt
                                    anchors.centerIn: parent
                                    text: "Run as admin"
                                    color: "#ff9966"; font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }

            // ── ALL APPS VIEW ────────────────────────────────────
            Item {
                width: parent.width
                height: parent.height - 44 - 14
                visible: opacity > 0
                opacity: startMenuPopup.viewState === "allapps" ? 1 : 0
                x: startMenuPopup.viewState === "allapps" ? 0 : parent.width
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    spacing: 10

                    Item {
                        width: parent.width; height: 28

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: backTxt.implicitWidth + 24; height: 26; radius: 13
                            color: backHover.containsMouse ? "#3d3d3d" : "#2a2a2a"
                            border.color: "#555"; border.width: 1

                            HoverHandler { id: backHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: startMenuPopup.viewState = "home"
                            }
                            Text {
                                id: backTxt
                                anchors.centerIn: parent
                                text: "‹ Back"
                                color: "#cccccc"; font.pixelSize: 12
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "All apps"
                            color: "#ffffff"; font.pixelSize: 13; font.bold: true
                        }
                    }

                    ListView {
                        id: allAppsList
                        width: parent.width
                        height: parent.height - 38
                        clip: true
                        spacing: 1

                        model: ListModel { id: allAppsModel }

                        function populate() {
                            allAppsModel.clear()
                            var apps = []
                            var appVals = DesktopEntries.applications.values
                            for (var i = 0; i < appVals.length; i++) {
                                var e = appVals[i]
                                if (!e.noDisplay) apps.push(e)
                            }
                            apps.sort(function(a, b) { return a.name.localeCompare(b.name) })
                            var lastLetter = ""
                            for (var j = 0; j < apps.length; j++) {
                                var letter = apps[j].name.charAt(0).toUpperCase()
                                if (letter !== lastLetter) {
                                    allAppsModel.append({ isHeader: true, letter: letter, appName: "", appIcon: "" })
                                    lastLetter = letter
                                }
                                allAppsModel.append({ isHeader: false, letter: "", appName: apps[j].name, appIcon: apps[j].icon })
                            }
                        }

                        Connections {
                            target: startMenuPopup
                            function onViewStateChanged() {
                                if (startMenuPopup.viewState === "allapps")
                                    allAppsList.populate()
                            }
                        }

                        delegate: Item {
                            required property var model
                            required property int index
                            width: allAppsList.width
                            height: model.isHeader ? 32 : 44

                            Item {
                                anchors.fill: parent
                                visible: model.isHeader

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    text: model.letter
                                    color: "#4cc2ff"
                                    font.pixelSize: 14; font.bold: true
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1; color: "#2a2a2a"
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !model.isHeader
                                radius: 6
                                property bool hovered: false
                                color: hovered ? "#333333" : "transparent"

                                HoverHandler { onHoveredChanged: parent.hovered = hovered }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            var pt = mapToItem(startMenuPopup.contentItem, mouse.x, mouse.y)
                                            startMenuPopup.openContextMenu(model.appIcon, model.appName, pt.x, pt.y, false)
                                        } else {
                                            Quickshell.execDetached(["gtk-launch", model.appIcon])
                                            barWindow.startMenuOpen = false
                                        }
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    spacing: 12

                                    Item {
                                        width: 28; height: 28
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: model.appName ? model.appName.charAt(0).toUpperCase() : ""
                                            color: "#555"; font.pixelSize: 13; font.bold: true
                                        }
                                        Image {
                                            anchors.fill: parent
                                            source: model.appIcon ? Quickshell.iconPath(model.appIcon, true) : ""
                                            smooth: true
                                            visible: source.toString() !== ""
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.appName || ""
                                        color: "#dddddd"; font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }

        // ── SHARED CONTEXT MENU (on top of everything) ───────────
        Rectangle {
            id: contextMenu
            x: startMenuPopup.ctxX
            y: startMenuPopup.ctxY
            width: 210
            implicitHeight: ctxItems.implicitHeight + 16
            height: implicitHeight
            radius: 8
            color: "#252525"
            border.color: "#505050"
            border.width: 1
            visible: startMenuPopup.ctxVisible
            z: 10000

            Column {
                id: ctxItems
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 2

                // App name header
                Item {
                    width: parent.width
                    height: 36

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        spacing: 8

                        Item {
                            width: 22; height: 22
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                anchors.fill: parent
                                source: Quickshell.iconPath(startMenuPopup.ctxAppIcon, true)
                                smooth: true
                                visible: source.toString() !== ""
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: startMenuPopup.ctxAppName
                            color: "#ffffff"; font.pixelSize: 12; font.bold: true
                            elide: Text.ElideRight
                            width: 150
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#3a3a3a" }

                Repeater {
                    model: {
                        var items = ["Open", "Run as administrator"]
                        if (startMenuPopup.ctxFromPinned)
                            items.push("Unpin from Start")
                        else
                            items.push("Pin to Start")
                        items.push("Pin to taskbar")
                        return items
                    }

                    delegate: Rectangle {
                        required property var modelData
                        width: ctxItems.width; height: 34; radius: 6
                        color: itemHover.containsMouse ? "#3a3a3a" : "transparent"

                        HoverHandler { id: itemHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var icon = startMenuPopup.ctxAppIcon
                                var name = startMenuPopup.ctxAppName
                                if (modelData === "Open") {
                                    Quickshell.execDetached(["gtk-launch", icon])
                                    barWindow.startMenuOpen = false
                                } else if (modelData === "Run as administrator") {
                                    Quickshell.execDetached(["pkexec", "gtk-launch", icon])
                                    barWindow.startMenuOpen = false
                                } else if (modelData === "Pin to Start") {
                                    startMenuPopup.pinToStart(icon, name)
                                } else if (modelData === "Unpin from Start") {
                                    startMenuPopup.unpinFromStart(icon)
                                } else if (modelData === "Pin to taskbar") {
                                    startMenuPopup.pinToTaskbar(icon, name)
                                }
                                startMenuPopup.ctxVisible = false
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 12
                            text: modelData
                            color: modelData === "Run as administrator" ? "#ff9966" : "#dddddd"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
