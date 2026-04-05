import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import "../layouts"
import "."

PanelWindow {
    id: root

    // --- SETTINGS ---
    property string layoutAlgorithm: "smartgrid"
    property string lastLayoutAlgorithm: "smartgrid"
    property bool liveCapture: false
    property bool moveCursorToActiveWindow: false

    // --- INTERNAL STATE ---
    property bool isActive: false
    property bool specialActive: false
    property bool animateWindows: false
    property var lastPositions: {}
    property int activeWorkspaceId: 1
    property int draggingTargetWorkspace: -1
    property int draggingFromWorkspace: -1

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: isActive

    // LayerShell Configs
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isActive ? 1 : 0
    WlrLayershell.namespace: "quickshell:expose"

    // --- IPC & EVENTS ---
    IpcHandler {
        target: "expose"
        function toggle(layout: string) {
            root.layoutAlgorithm = "smartgrid"
            root.toggleExpose()
        }

        function open(layout: string) {
            root.layoutAlgorithm = "smartgrid"
            if (root.isActive) return
            root.toggleExpose()
        }

        function close() {
            if (!root.isActive) return
            root.toggleExpose()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!root.isActive && ev.name !== "activespecial") return

            switch (ev.name) {
                case "openwindow":
                case "closewindow":
                case "changefloatingmode":
                case "movewindow":
                    Hyprland.refreshToplevels()
                    refreshThumbs()
                    return

                case "activespecial":
                    var dataStr = String(ev.data)
                    var namePart = dataStr.split(",")[0]
                    root.specialActive = (namePart.length > 0)
                    return
                case "workspacev2":
                    var wsData = String(ev.data).split(",")
                    var wsId = parseInt(wsData[0], 10)
                    if (!isNaN(wsId)) root.activeWorkspaceId = wsId
                    return

                default:
                    return
            }
        }
    }

    // Update thumbs every 125ms if liveCapture = false
    Timer {
        id: screencopyTimer
        interval: 125
        repeat: true
        running: !root.liveCapture && root.isActive
        onTriggered: root.refreshThumbs()
    }


    function toggleExpose() {
        root.isActive = !root.isActive
        if (root.isActive) {
            root.lastLayoutAlgorithm = "smartgrid"

            exposeArea.currentIndex = -1
            searchBox.reset()
            Hyprland.refreshToplevels()
            refreshThumbs()
        } else {
            root.animateWindows = false
            root.lastPositions = {}
        }
    }

    function refreshThumbs() {
        if (!root.isActive) return
        for (var i = 0; i < winRepeater.count; ++i) {
            var it = winRepeater.itemAt(i)
            if (it && it.visible && it.refreshThumb) {
                it.refreshThumb()
            }
        }
    }

    function moveWindowToWorkspace(address, workspaceId) {
        if (!address || workspaceId < 1) return
        var addr = String(address).trim()
        if (!addr.startsWith("0x")) addr = "0x" + addr
        Hyprland.dispatch(`movetoworkspacesilent ${workspaceId},address:${addr}`)
        Qt.callLater(function() {
            Hyprland.refreshToplevels()
            Hyprland.refreshWorkspaces()
            root.refreshThumbs()
        })
    }

    // --- USER INTERFACE ---
    FocusScope {
        id: mainScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (!root.isActive) return

            if (event.key === Qt.Key_Escape) {
                root.toggleExpose()
                event.accepted = true
                return
            }

            const total = winRepeater.count
            if (total <= 0) return

            // Helper for horizontal navigation
            function moveSelectionHorizontal(delta) {
                var start = exposeArea.currentIndex
                for (var step = 1; step <= total; ++step) {
                    var candidate = (start + delta * step + total) % total
                    var it = winRepeater.itemAt(candidate)
                    if (it && it.visible) {
                        exposeArea.currentIndex = candidate
                        return
                    }
                }
            }

            // Helper for vertical navigation
            function moveSelectionVertical(dir) {
                var startIndex = exposeArea.currentIndex
                var currentItem = winRepeater.itemAt(startIndex)

                if (!currentItem || !currentItem.visible) {
                    moveSelectionHorizontal(dir > 0 ? 1 : -1)
                    return
                }

                var curCx = currentItem.x + currentItem.width  / 2
                var curCy = currentItem.y + currentItem.height / 2

                var bestIndex = -1
                var bestDy = 99999999
                var bestDx = 99999999

                for (var i = 0; i < total; ++i) {
                    var it = winRepeater.itemAt(i)
                    if (!it || !it.visible || i === startIndex) continue

                    var cx = it.x + it.width  / 2
                    var cy = it.y + it.height / 2
                    var dy = cy - curCy

                    // Direction filtering
                    if (dir > 0 && dy <= 0) continue
                    if (dir < 0 && dy >= 0) continue

                    var absDy = Math.abs(dy)
                    var absDx = Math.abs(cx - curCx)

                    // Search for nearest thumb (first in vertical, then horizontal distance)
                    if (absDy < bestDy || (absDy === bestDy && absDx < bestDx)) {
                        bestDy = absDy
                        bestDx = absDx
                        bestIndex = i
                    }
                }

                if (bestIndex >= 0) {
                    exposeArea.currentIndex = bestIndex
                }
            }

            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                moveSelectionHorizontal(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                moveSelectionHorizontal(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                moveSelectionVertical(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                moveSelectionVertical(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var item = winRepeater.itemAt(exposeArea.currentIndex)
                if (item && item.activateWindow) {
                    item.activateWindow()
                    event.accepted = true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            z: -1
            onClicked: root.toggleExpose()
        }

        Item {
            id: layoutContainer
            anchors.fill: parent
            anchors.margins: 12

                Column {
                    id: layoutRoot
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    anchors.topMargin: 0
                    anchors.bottomMargin: 12
                    spacing: 12
                    property int workspaceBottomPadding: 18

                SearchBox {
                    id: searchBox
                    width: Math.min(layoutRoot.width * 0.68, 760)
                    onTextChanged: function(text) {
                        root.animateWindows = true
                        exposeArea.searchText = text
                    }
                }

                // thumbs area
                Item {
                    id: exposeArea
                    width: layoutRoot.width
                    height: layoutRoot.height - searchBox.implicitHeight - workspaceStrip.implicitHeight - workspacePad.implicitHeight - (layoutRoot.spacing * 2)

                    property int currentIndex: 0
                    property string searchText: ""

                    // Reset active thumb on searchText change
                    onSearchTextChanged: {
                        currentIndex = (windowLayoutModel.count > 0) ? 0 : -1
                    }

                    ScriptModel {
                        id: windowLayoutModel

                        property int areaW: exposeArea.width
                        property int areaH: exposeArea.height
                        property string query: exposeArea.searchText
                        property string algo: root.lastLayoutAlgorithm
                        property var rawToplevels: Hyprland.toplevels.values

                        values: {
                            // Bailout on wrong screen size
                            if (areaW <= 0 || areaH <= 0) return []

                            var q = (query || "").toLowerCase()
                            var windowList = []
                            var idx = 0

                            if (!rawToplevels) return []

                            for (var it of rawToplevels) {
                                var w = it
                                var clientInfo = w && w.lastIpcObject ? w.lastIpcObject : {}
                                var workspace = clientInfo && clientInfo.workspace ? clientInfo.workspace : null
                                var workspaceId = workspace && workspace.id !== undefined ? workspace.id : undefined

                                // Filter invalid workspace or offscreen windows
                                if (workspaceId === undefined || workspaceId === null) continue
                                var size = clientInfo && clientInfo.size ? clientInfo.size : [0, 0]
                                var at = clientInfo && clientInfo.at ? clientInfo.at : [-1000, -1000]
                                if (at[1] + size[1] <= 0) continue

                                // Text filtering
                                var title = (w.title || clientInfo.title || "").toLowerCase()
                                var clazz = (clientInfo["class"] || "").toLowerCase()
                                var ic = (clientInfo.initialClass || "").toLowerCase()
                                var app = (w.appId || clientInfo.initialClass || "").toLowerCase()

                                if (q.length > 0) {
                                    var match = title.indexOf(q) !== -1 || clazz.indexOf(q) !== -1 ||
                                                ic.indexOf(q) !== -1 || app.indexOf(q) !== -1
                                    if (!match) continue
                                }

                                windowList.push({
                                    win: w,
                                    clientInfo: clientInfo,
                                    workspaceId: workspaceId,
                                    width: size[0],
                                    height: size[1],
                                    originalIndex: idx++,
                                    lastIpcObject: w.lastIpcObject
                                })
                            }

                            // Sort by workspaceId, then originalIndex
                            windowList.sort(function(a, b) {
                                if (a.workspaceId < b.workspaceId) return -1
                                if (a.workspaceId > b.workspaceId) return 1
                                if (a.originalIndex < b.originalIndex) return -1
                                if (a.originalIndex > b.originalIndex) return 1
                                return 0
                            })

                            return LayoutsManager.doLayout(algo, windowList, areaW, areaH)
                        }
                    }

                    Repeater {
                        id: winRepeater
                        model: windowLayoutModel

                        delegate: WindowThumbnail {
                            // Model data
                            hWin: modelData.win
                            wHandle: hWin.wayland
                            winKey: String(hWin.address)
                            thumbW: modelData.width
                            thumbH: modelData.height
                            clientInfo: hWin.lastIpcObject

                            // Layout-generated coordinates
                            targetX: modelData.x
                            targetY: modelData.y
                            targetZ: (visible && (exposeArea.currentIndex === index)) ? 1000: modelData.zIndex || 0
                            targetRotation: modelData.rotation || 0

                            hovered: visible && (exposeArea.currentIndex === index)
                            moveCursorToActiveWindow: root.moveCursorToActiveWindow
                            exposeRoot: root
                        }
                    }
                }

                Rectangle {
                    id: workspaceStrip
                    property int workspaceRows: workspaceRepeater.count <= 3 ? 1 : 2
                    property int gridSpacing: 10
                    property int cardHeightSingleRow: 108
                    property int cardHeightDoubleRow: 92
                    readonly property int cardHeightDynamic: workspaceRows === 1 ? cardHeightSingleRow : cardHeightDoubleRow
                    implicitWidth: Math.min(layoutRoot.width, 1360)
                    implicitHeight: (workspaceRows * cardHeightDynamic) + ((workspaceRows - 1) * gridSpacing) + 28
                    radius: 18
                    anchors.horizontalCenter: layoutRoot.horizontalCenter
                    color: "#73101420"
                    border.width: 1
                    border.color: "#335b6780"

                    ScriptModel {
                        id: workspaceModel
                        property var rawToplevels: Hyprland.toplevels ? Hyprland.toplevels.values : []

                        values: {
                            if (!rawToplevels) return []

                            function friendlyAppName(rawClass, rawTitle) {
                                var cls = String(rawClass || "").trim()
                                if (cls.length > 0) {
                                    cls = cls.split(".").pop()
                                    cls = cls.split("-").pop()
                                    cls = cls.replace(/[_-]+/g, " ")
                                    if (cls.length > 0) {
                                        return cls.charAt(0).toUpperCase() + cls.slice(1)
                                    }
                                }
                                var title = String(rawTitle || "").trim()
                                if (title.length > 0) {
                                    return title.split(" - ")[0].slice(0, 18)
                                }
                                return "App"
                            }

                            var workspaceWindows = {}
                            var occupiedIds = []
                            var maxWorkspaceId = Math.max(1, root.activeWorkspaceId)

                            for (var w of rawToplevels) {
                                var clientInfo = w && w.lastIpcObject ? w.lastIpcObject : {}
                                var workspace = clientInfo && clientInfo.workspace ? clientInfo.workspace : null
                                var workspaceId = workspace && workspace.id !== undefined ? workspace.id : null
                                if (workspaceId === null || workspaceId < 1) continue

                                if (!workspaceWindows[workspaceId]) {
                                    workspaceWindows[workspaceId] = []
                                    occupiedIds.push(workspaceId)
                                }

                                var atX = Number(clientInfo.at && clientInfo.at[0] !== undefined ? clientInfo.at[0] : 0)
                                var atY = Number(clientInfo.at && clientInfo.at[1] !== undefined ? clientInfo.at[1] : 0)
                                var sizeW = Math.max(1, Number(clientInfo.size && clientInfo.size[0] !== undefined ? clientInfo.size[0] : 1))
                                var sizeH = Math.max(1, Number(clientInfo.size && clientInfo.size[1] !== undefined ? clientInfo.size[1] : 1))

                                workspaceWindows[workspaceId].push({
                                    address: w.address,
                                    title: String(w.title || clientInfo.title || ""),
                                    clazz: String(clientInfo["class"] || clientInfo.initialClass || w.appId || ""),
                                    appName: friendlyAppName(clientInfo["class"] || clientInfo.initialClass || w.appId || "", w.title || clientInfo.title || ""),
                                    atX: atX,
                                    atY: atY,
                                    sizeW: sizeW,
                                    sizeH: sizeH
                                })
                                if (workspaceId > maxWorkspaceId) maxWorkspaceId = workspaceId
                            }

                            if (root.activeWorkspaceId > 0 && occupiedIds.indexOf(root.activeWorkspaceId) === -1) {
                                occupiedIds.push(root.activeWorkspaceId)
                            }

                            occupiedIds.sort(function(a, b) { return a - b })
                            var extraWorkspaceId = maxWorkspaceId + 1
                            if (occupiedIds.indexOf(extraWorkspaceId) === -1) {
                                occupiedIds.push(extraWorkspaceId)
                            }

                            var result = []
                            for (var id of occupiedIds) {
                                var wins = workspaceWindows[id] || []
                                var layoutTiles = []

                                if (wins.length > 0) {
                                    var minX = wins[0].atX
                                    var minY = wins[0].atY
                                    var maxX = wins[0].atX + wins[0].sizeW
                                    var maxY = wins[0].atY + wins[0].sizeH

                                    for (var i = 1; i < wins.length; ++i) {
                                        var win = wins[i]
                                        minX = Math.min(minX, win.atX)
                                        minY = Math.min(minY, win.atY)
                                        maxX = Math.max(maxX, win.atX + win.sizeW)
                                        maxY = Math.max(maxY, win.atY + win.sizeH)
                                    }

                                    var spanX = Math.max(1, maxX - minX)
                                    var spanY = Math.max(1, maxY - minY)

                                    for (var j = 0; j < Math.min(wins.length, 8); ++j) {
                                        var iw = wins[j]
                                        layoutTiles.push({
                                            appName: iw.appName,
                                            x: Math.max(0, Math.min(1, (iw.atX - minX) / spanX)),
                                            y: Math.max(0, Math.min(1, (iw.atY - minY) / spanY)),
                                            w: Math.max(0.1, Math.min(1, iw.sizeW / spanX)),
                                            h: Math.max(0.1, Math.min(1, iw.sizeH / spanY))
                                        })
                                    }
                                }

                                result.push({
                                    id: id,
                                    name: String(id),
                                    windows: wins,
                                    layoutTiles: layoutTiles,
                                    occupied: wins.length > 0,
                                    extra: id === extraWorkspaceId
                                })
                            }
                            return result.slice(0, 6)
                        }
                    }

                    Item {
                        id: workspacePanel
                        anchors.fill: parent
                        anchors.margins: 10

                        Grid {
                            id: workspaceGrid
                            readonly property int itemCount: Math.max(1, Math.min(workspaceRepeater.count, 6))
                            readonly property int usedColumns: itemCount <= 3 ? itemCount : (itemCount === 4 ? 2 : 3)
                            readonly property int rows: itemCount <= 3 ? 1 : 2
                            property int cardWidth: Math.max(230, Math.floor((workspacePanel.width - ((usedColumns - 1) * spacing)) / usedColumns))
                            property int cardHeight: workspaceStrip.cardHeightDynamic
                            spacing: workspaceStrip.gridSpacing
                            columns: usedColumns
                            width: Math.min(workspacePanel.width, (usedColumns * cardWidth) + ((usedColumns - 1) * spacing))
                            height: Math.min(workspacePanel.height, (rows * cardHeight) + ((rows - 1) * spacing))
                            anchors.centerIn: parent

                            Repeater {
                                id: workspaceRepeater
                                model: workspaceModel

                                delegate: Rectangle {
                                    required property var modelData
                                    property int workspaceId: modelData.id
                                    property string workspaceName: modelData.name
                                    property var workspaceWindows: modelData.windows || []
                                    property var workspaceLayoutTiles: modelData.layoutTiles || []
                                    property bool isExtra: modelData.extra || false

                                    width: Math.max(128, (workspaceGrid.width - (workspaceGrid.spacing * Math.max(workspaceGrid.columns - 1, 0))) / Math.max(workspaceGrid.columns, 1))
                                    height: workspaceGrid.cardHeight
                                    radius: 14
                                    color: root.activeWorkspaceId === workspaceId ? "#AA2A4365" : (isExtra ? "#44333a46" : "#5524262a")
                                    border.width: root.draggingTargetWorkspace === workspaceId ? 2 : 1
                                    border.color: root.draggingTargetWorkspace === workspaceId ? "#FF77B8FF" : "#557f8ea3"

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        Row {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                text: "Workspace " + workspaceName
                                                color: "white"
                                                font.pixelSize: 14
                                                font.bold: root.activeWorkspaceId === workspaceId
                                            }

                                            Text {
                                                text: isExtra ? "+ new" : (workspaceWindows.length + " win")
                                                color: "#b8d8ff"
                                                font.pixelSize: 13
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: Math.max(58, parent.height - 30)
                                            radius: 10
                                            color: "#33000000"
                                            border.width: 1
                                            border.color: "#33556677"

                                            Item {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                clip: true

                                                Repeater {
                                                    model: workspaceLayoutTiles

                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        readonly property var tile: modelData || ({})
                                                        x: Math.max(0, Math.round(tile.x * (parent.width - 4)))
                                                        y: Math.max(0, Math.round(tile.y * (parent.height - 4)))
                                                        width: Math.max(42, Math.round(tile.w * parent.width) - 5)
                                                        height: Math.max(26, Math.round(tile.h * parent.height) - 5)
                                                        radius: 10
                                                        color: "#6E5E7A9A"
                                                        border.width: 1
                                                        border.color: "#77a2c5ef"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: String(tile.appName || "?").slice(0, 10)
                                                            color: "white"
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }

                                                Text {
                                                    visible: workspaceLayoutTiles.length === 0
                                                    anchors.centerIn: parent
                                                    text: isExtra ? "Drop here to create" : "No windows"
                                                    color: "#8fa8c8"
                                                    font.pixelSize: 12
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Hyprland.dispatch(`workspace ${parent.workspaceId}`)
                                    }

                                    DropArea {
                                        anchors.fill: parent
                                        onEntered: root.draggingTargetWorkspace = parent.workspaceId
                                        onExited: {
                                            if (root.draggingTargetWorkspace === parent.workspaceId) {
                                                root.draggingTargetWorkspace = -1
                                            }
                                        }
                                        onDropped: {
                                            var source = drag.source
                                            if (!source || !source.windowAddress) return
                                            source.dropHandled = true
                                            root.moveWindowToWorkspace(source.windowAddress, parent.workspaceId)
                                            root.draggingTargetWorkspace = -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: workspacePad
                    implicitWidth: layoutRoot.width
                    implicitHeight: layoutRoot.workspaceBottomPadding
                }
            }
        }
    }
}
