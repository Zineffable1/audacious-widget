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
    
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        
        onNewData: (sourceName, data) => {
            let stdout = data["stdout"].trim()
            let exitCode = data["exit code"]
            
            console.log("DataSource got:", sourceName, "stdout:", stdout, "exitCode:", exitCode)
            
            if (sourceName.includes("pgrep -x audacious")) {
                // Double-click triggered: check if audacious is running
                if (exitCode === 0) {
                    // Running, now check window state
                    console.log("Audacious running, checking window state")
                    executable.exec("audtool mainwin-show")
                } else {
                    // Not running, start it
                    console.log("Audacious not running, starting")
                    executable.exec("audacious")
                }
            } else if (sourceName.includes("audtool mainwin-show") && !sourceName.includes("tuple") && !sourceName.includes("get-")) {
                // Got window state, toggle it
                console.log("Window state is:", stdout)
                if (stdout === "on") {
                    console.log("Hiding window")
                    executable.exec("audtool mainwin-show off")
                } else {
                    console.log("Showing window")
                    executable.exec("audtool mainwin-show on")
                }
            } else if (sourceName.includes("get-volume")) {
                if (stdout.length > 0) {
                    currentVolume = parseInt(stdout)
                }
            } else if (sourceName.includes("tuple-data title")) {
                trackTitle = stdout || "Not playing"
            } else if (sourceName.includes("tuple-data artist")) {
                trackArtist = stdout
            } else if (sourceName.includes("tuple-data album")) {
                trackAlbum = stdout
            } else if (sourceName.includes("tuple-data year")) {
                trackYear = stdout
            } else if (sourceName.includes("playback-status")) {
                isPlaying = (stdout === "playing")
            }
            
            disconnectSource(sourceName)
        }
        
        function exec(cmd) {
            connectSource(cmd)
        }
    }
    
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            executable.exec("audtool get-volume")
            executable.exec("audtool current-song-tuple-data title")
            executable.exec("audtool current-song-tuple-data artist")
            executable.exec("audtool current-song-tuple-data album")
            executable.exec("audtool current-song-tuple-data year")
            executable.exec("audtool playback-status")
        }
    }
    
    function adjustVolume(delta) {
        console.log("adjustVolume called, delta:", delta, "currentVolume:", currentVolume)
        let newVol = Math.max(0, Math.min(100, currentVolume + delta))
        console.log("newVol:", newVol)
        let cmd = "audtool set-volume " + newVol
        console.log("executing:", cmd)
        executable.exec(cmd)
        currentVolume = newVol
    }
    
    function togglePlayPause() {
        executable.exec("audtool playback-playpause")
    }
    
    function nextTrack() {
        executable.exec("audtool playlist-advance")
    }
    
    function prevTrack() {
        executable.exec("audtool playlist-reverse")
    }
    
    function seekTrack(seconds) {
        if (isPlaying) {
            // Get current position and seek relative to it
            if (seconds > 0) {
                executable.exec("audtool playback-seek-relative +" + seconds)
            } else {
                executable.exec("audtool playback-seek-relative " + seconds)
            }
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
        info += "<br/>" + (prefix ? "🔊 " : "") + "Volume: " + currentVolume + "%"
        return info
    }
    
    // Context menu
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: isPlaying ? "Pause" : "Play"
            icon.name: isPlaying ? "media-playback-pause" : "media-playback-start"
            onTriggered: togglePlayPause()
        },
        PlasmaCore.Action {
            text: "Stop"
            icon.name: "media-playback-stop"
            onTriggered: executable.exec("audtool playback-stop")
        },
        PlasmaCore.Action {
            text: "Previous"
            icon.name: "media-skip-backward"
            onTriggered: prevTrack()
        },
        PlasmaCore.Action {
            text: "Next"
            icon.name: "media-skip-forward"
            onTriggered: nextTrack()
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: "Quit Audacious"
            icon.name: "application-exit"
            onTriggered: executable.exec("audtool shutdown")
        }
    ]
    
    // Compact representation (system tray icon)
    compactRepresentation: Item {
        id: compactRoot
        
        property bool tapPending: false
        
        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            source: "audacious"
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
                console.log("Double click - checking Audacious state")
                
                // First check if running, store result and act on it
                executable.exec("pgrep -x audacious")
            }
        }
        
        Timer {
            id: singleTapTimer
            interval: 300
            onTriggered: {
                if (compactRoot.tapPending) {
                    compactRoot.tapPending = false
                    console.log("Single click - toggle play/pause")
                    togglePlayPause()
                }
            }
        }
        
        WheelHandler {
            id: wheelHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            
            onWheel: (event) => {
                console.log("=== WHEEL EVENT ===")
                console.log("angleDelta.y:", event.angleDelta.y)
                console.log("angleDelta.x:", event.angleDelta.x)
                console.log("modifiers:", event.modifiers)
                
                // Check for shift modifier OR horizontal scroll
                let isShiftOrHorizontal = (event.modifiers & Qt.ShiftModifier) || (event.angleDelta.x !== 0)
                let delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                
                if (delta === 0) return
                
                // Choose action based on whether shift/horizontal
                let action = isShiftOrHorizontal ? plasmoid.configuration.shiftScrollAction : plasmoid.configuration.scrollAction
                console.log("action:", action, "(0=track, 1=volume, 2=seek)")
                
                // Execute the action
                if (action === 0) {
                    // Change track
                    if (delta > 0) {
                        console.log("Next track")
                        nextTrack()
                    } else {
                        console.log("Previous track")
                        prevTrack()
                    }
                } else if (action === 1) {
                    // Change volume
                    let volumeDelta = delta > 0 ? 5 : -5
                    console.log("Adjusting volume:", volumeDelta)
                    adjustVolume(volumeDelta)
                } else if (action === 2) {
                    // Seek
                    if (root.isPlaying) {
                        let seekAmount = (delta > 0 ? 1 : -1) * plasmoid.configuration.seekStepSeconds
                        console.log("Seeking:", seekAmount, "seconds")
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
