import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    
    property int currentVolume: 50
    property string trackTitle: "Not playing"
    property string trackArtist: ""
    property string trackAlbum: ""
    property string trackYear: ""
    property bool isPlaying: false
    property bool isAudaciousRunning: false  // Track if Audacious is running
    property int pendingSeek: 0  // Milliseconds to seek when we get Position
    property int trackPosition: 0  // Current position in seconds
    property int trackLength: 0  // Total track length in seconds
    property int tooltipTicker: 0  // Increments every second to force tooltip refresh
    
    Plasma5Support.DataSource {
    id: executable
    engine: "executable"
    connectedSources: []

    onNewData: (sourceName, data) => {
        let stdout = (data["stdout"] || "").trim()
        let exitCode = data["exit code"]

        let cunt = sourceName
   
        
        // Handle periodic check for context menu
        if (sourceName.includes("echo 'running'") || sourceName.includes("echo 'stopped'")) {
            root.isAudaciousRunning = (stdout === "running")
        
        // 1️⃣ Check if Audacious is running (from double-click)
        } else if (sourceName.includes("pgrep -x audacious")) {
                
            if (stdout.length > 0) {
                // Running → update state and check if window is visible via DBus
                root.isAudaciousRunning = true
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.MainWinVisible")
            } else {
                // Not running → update state and start it
                executable.exec("audacious")
                root.isAudaciousRunning = true  // Set immediately for instant menu update
            }

        // 2️⃣ Window visibility check via DBus
        } else if (sourceName.includes("MainWinVisible")) {

            if (stdout === "true") {
                // Window visible → hide it
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.ShowMainWin false")
            } else {
                // Window hidden → show it
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.ShowMainWin true")
            }

        } else if (sourceName.includes("org.atheme.audacious.Volume")) {

            // Volume returns "left_vol right_vol", we just need one value
            if (stdout.length > 0) {
                let vol = parseInt(stdout.split(' ')[0])
                currentVolume = vol
            }

        } else if (sourceName.includes("SongTuple") && sourceName.includes("title")) {

            trackTitle = stdout || "Not playing"

        } else if (sourceName.includes("SongTuple") && sourceName.includes("artist")) {

            trackArtist = stdout

        } else if (sourceName.includes("SongTuple") && sourceName.includes("album")) {

            trackAlbum = stdout

        } else if (sourceName.includes("SongTuple") && sourceName.includes("year")) {

            trackYear = stdout

        } else if (sourceName.includes("org.atheme.audacious.Status")) {

            isPlaying = (stdout === "playing")
            
        } else if (sourceName.includes("org.atheme.audacious.Time")) {
            
            // Check if this is for seeking or for tooltip updates
            if (root.pendingSeek !== 0) {
                // This was called for seeking - Time returns milliseconds
                let currentTimeMs = parseInt(stdout)
                let newTimeMs = currentTimeMs + root.pendingSeek
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Seek " + newTimeMs)
                root.pendingSeek = 0
            } else {
                // This is for tooltip - convert milliseconds to seconds
                trackPosition = Math.floor(parseInt(stdout) / 1000)
            }
            
        } else if (sourceName.includes("SongLength")) {
            
            // SongLength returns length in SECONDS already (not milliseconds!)
            trackLength = parseInt(stdout)
            
        } else if (sourceName.includes("org.atheme.audacious.Position")) {
            
            // Check if this is for seeking or for getting current track
            if (root.pendingSeek !== 0) {
                // This was for seeking
                let currentPos = parseInt(stdout)
                let newPos = currentPos + root.pendingSeek
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Seek " + newPos)
                root.pendingSeek = 0
            } else {
                // This is for getting current track info - Position() returns current track index
                let trackPos = parseInt(stdout)
                if (trackPos !== root.currentTrackIndex) {
                    root.currentTrackIndex = trackPos
                }
                // Always fetch track info for current position
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.SongTuple " + trackPos + " title")
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.SongTuple " + trackPos + " artist")
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.SongTuple " + trackPos + " album")
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.SongTuple " + trackPos + " year")
                executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.SongLength " + trackPos)
            }
        }

        disconnectSource(sourceName)
    }

    function exec(cmd) {
        connectSource(cmd)
    }
}
    
    Timer {
        id: updateTimer
        interval: 1000  // Update every second for smooth progress bar
        running: false  // Don't run by default, only when hovering
        repeat: true
        onTriggered: {
            executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Volume")
            executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Position")
            executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Status")
            executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Time")
            tooltipTicker++  // Force tooltip refresh
        }
    }
    
    // Timer to periodically check if Audacious is running (for dynamic context menu)
    Timer {
        id: audaciousCheckTimer
        interval: 3000  // Check every 3 seconds
        running: true
        repeat: true
        onTriggered: {
            // Use a simple pgrep check without triggering window actions
            executable.exec("pgrep -x audacious > /dev/null && echo 'running' || echo 'stopped'")
        }
    }
    
    // Handle the periodic check differently from double-click
    property bool lastCheckResult: false
    
    property int currentTrackIndex: 0  // Track which song is playing
    
    function formatTime(seconds) {
        let mins = Math.floor(seconds / 60)
        let secs = seconds % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    
    function adjustVolume(delta) {
        let newVol = Math.max(0, Math.min(100, currentVolume + delta))
        // SetVolume takes left and right channel volumes
        executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.SetVolume " + newVol + " " + newVol)
        currentVolume = newVol
    }
    
    function togglePlayPause() {
        executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.PlayPause")
    }
    
    function nextTrack() {
        executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Advance")
    }
    
    function prevTrack() {
        executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Reverse")
    }
    
    function seekTrack(seconds) {
        if (isPlaying) {
            // Get current time position (in ms) and add/subtract
            executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Time")
            // Store seek amount for when we get Time back
            root.pendingSeek = seconds * 1000  // Convert to milliseconds
        }
    }
    
    // Simple rich text tooltip
    toolTipTextFormat: Text.RichText
    toolTipMainText: (plasmoid.configuration.showEmojis ? "🎵 " : "") + trackTitle
    toolTipSubText: {
        let info = ""
        let prefix = plasmoid.configuration.showEmojis
        if (trackArtist) info += (prefix ? "🎤 " : "") + trackArtist + "<br/>"
        if (trackAlbum) info += (prefix ? "💿 " : "") + trackAlbum + (trackYear ? " (" + trackYear + ")" : "") + "<br/>"
        
        // Add time if playing
        if (isPlaying && trackLength > 0) {
            info += formatTime(trackPosition) + " / " + formatTime(trackLength) + "<br/>"
        }
        
        info += (prefix ? "🔊 " : "") + "Volume: " + currentVolume + "%"
        return info
    }
    
    // Dynamic context menu
    Component.onCompleted: {
        updateContextMenu()
    }
    
    onIsAudaciousRunningChanged: {
        updateContextMenu()
    }
    
    onIsPlayingChanged: {
        if (isAudaciousRunning) {
            updateContextMenu()
        }
    }
    
    Connections {
        target: plasmoid.configuration
        function onMenuOrderChanged() {
            updateContextMenu()
        }
        function onHiddenMenuItemsChanged() {
            updateContextMenu()
        }
    }
    
    function updateContextMenu() {
        if (isAudaciousRunning) {
            let order = plasmoid.configuration.menuOrder || "play,stop,prev,next,separator,close,quit"
            let items = order.split(',')
            let hiddenItems = (plasmoid.configuration.hiddenMenuItems || "").split(',')
            let actions = []
            
            let actionMap = {
                'play': playPauseAction,
                'stop': stopAction,
                'prev': previousAction,
                'next': nextAction,
                'separator': separatorAction,
                'close': closeWindowAction,
                'quit': quitAction
            }
            
            for (let i = 0; i < items.length; i++) {
                let itemId = items[i]
                // Skip hidden items
                if (hiddenItems.includes(itemId)) {
                    continue
                }
                
                let action = actionMap[itemId]
                if (action) {
                    actions.push(action)
                }
            }
            
            Plasmoid.contextualActions = actions
        } else {
            Plasmoid.contextualActions = [openAction]
        }
    }
    
    PlasmaCore.Action {
        id: openAction
        text: "Open Audacious"
        icon.name: "audacious"
        onTriggered: {
            executable.exec("audacious")
            root.isAudaciousRunning = true
        }
    }
    
    PlasmaCore.Action {
        id: playPauseAction
        text: isPlaying ? "Pause" : "Play"
        icon.name: isPlaying ? "media-playback-pause" : "media-playback-start"
        onTriggered: togglePlayPause()
    }
    
    PlasmaCore.Action {
        id: stopAction
        text: "Stop"
        icon.name: "media-playback-stop"
        onTriggered: executable.exec("audtool playback-stop")
    }
    
    PlasmaCore.Action {
        id: previousAction
        text: "Previous"
        icon.name: "media-skip-backward"
        onTriggered: prevTrack()
    }
    
    PlasmaCore.Action {
        id: nextAction
        text: "Next"
        icon.name: "media-skip-forward"
        onTriggered: nextTrack()
    }
    
    PlasmaCore.Action {
        id: separatorAction
        isSeparator: true
    }
    
    PlasmaCore.Action {
        id: closeWindowAction
        text: "Close Window"
        icon.name: "window-close"
        onTriggered: {
            executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.ShowMainWin false")
        }
    }
    
    PlasmaCore.Action {
        id: quitAction
        text: "Quit Audacious"
        icon.name: "application-exit"
        onTriggered: {
            executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Quit")
            root.isAudaciousRunning = false
        }
    }
    
    // Compact representation (system tray icon)
    compactRepresentation: Item {
        id: compactRoot
        
        property bool tapPending: false
        
        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            source: "audacious"
        }
        
        HoverHandler {
            id: hoverHandler
            
            onHoveredChanged: {
                if (hovered) {
                    // Fetch data immediately via DBus (use Position() to get current playing track)
                    executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Volume")
                    executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Position")
                    executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Status")
                    executable.exec("qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Time")
                    // Start timer for continuous updates
                    updateTimer.start()
                } else {
                    updateTimer.stop()
                }
            }
        }
        
        TapHandler {
            acceptedButtons: Qt.LeftButton
            
            onTapped: {
                if (!tapPending) {
                    tapPending = true
                    singleTapTimer.restart()
                }
            }
            
            onDoubleTapped: {
                singleTapTimer.stop()
                tapPending = false
                
                // Check if running, then use DBus to check/toggle visibility
                executable.exec("pgrep -x audacious")
            }
        }
        
        Timer {
            id: singleTapTimer
            interval: 300
            onTriggered: {
                if (compactRoot.tapPending) {
                    compactRoot.tapPending = false
                    togglePlayPause()
                }
            }
        }
        
        WheelHandler {
            id: wheelHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            
            onWheel: (event) => {
                
                // Check for shift modifier OR horizontal scroll
                let isShiftOrHorizontal = (event.modifiers & Qt.ShiftModifier) || (event.angleDelta.x !== 0)
                let delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                
                if (delta === 0) return
                
                // Choose action based on whether shift/horizontal
                let action = isShiftOrHorizontal ? plasmoid.configuration.shiftScrollAction : plasmoid.configuration.scrollAction
                
                // Execute the action
                if (action === 0) {
                    // Change track
                    if (delta > 0) {
                        nextTrack()
                    } else {
                        prevTrack()
                    }
                } else if (action === 1) {
                    // Change volume
                    let volumeDelta = delta > 0 ? 5 : -5
                    adjustVolume(volumeDelta)
                } else if (action === 2) {
                    // Seek
                    if (root.isPlaying) {
                        let seekAmount = (delta > 0 ? 1 : -1) * plasmoid.configuration.seekStepSeconds
                        seekTrack(seekAmount)
                    }
                }
            }
        }
    }
    
    // Full representation (popup)
    fullRepresentation: Item {
        Layout.minimumWidth: PlasmaCore.Units.gridUnit * 15
        Layout.minimumHeight: PlasmaCore.Units.gridUnit * 8
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: PlasmaCore.Units.smallSpacing
            
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: "Audacious Volume"
            }
            
            Item {
                Layout.fillHeight: true
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Kirigami.Icon {
                    Layout.preferredWidth: PlasmaCore.Units.iconSizes.small
                    Layout.preferredHeight: PlasmaCore.Units.iconSizes.small
                    source: "audio-volume-high"
                }
                
                PlasmaComponents.Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: currentVolume
                    
                    onMoved: {
                        adjustVolume(value - currentVolume)
                    }
                }
                
                PlasmaComponents.Label {
                    text: currentVolume + "%"
                    Layout.minimumWidth: PlasmaCore.Units.gridUnit * 3
                }
            }
            
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: "Scroll on the icon to adjust volume"
                font.pointSize: PlasmaCore.Theme.smallestFont.pointSize
                opacity: 0.6
            }
        }
    }
}
