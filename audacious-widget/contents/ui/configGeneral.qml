import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_scrollAction: scrollActionCombo.currentIndex
    property alias cfg_shiftScrollAction: shiftScrollActionCombo.currentIndex
    property alias cfg_seekStepSeconds: seekStepSpinBox.value
    property alias cfg_showEmojis: showEmojisCheck.checked
    property string cfg_menuOrder

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: scrollActionCombo
            Kirigami.FormData.label: "Scroll:"
            model: ["Change track", "Change volume", "Seek"]
        }
        
        QQC2.ComboBox {
            id: shiftScrollActionCombo
            Kirigami.FormData.label: "Shift+Scroll / Horizontal scroll:"
            model: ["Change track", "Change volume", "Seek"]
        }
        
        QQC2.SpinBox {
            id: seekStepSpinBox
            Kirigami.FormData.label: "Seek step (seconds):"
            from: 1
            to: 60
            stepSize: 1
        }
        
        QQC2.CheckBox {
            id: showEmojisCheck
            Kirigami.FormData.label: "Show emojis in tooltip:"
        }
        
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Context Menu Order"
        }
        
        ColumnLayout {
            Kirigami.FormData.label: "Menu items:"
            spacing: 5
            
            Repeater {
                id: menuRepeater
                model: ListModel {
                    id: menuItemsModel
                }
                
                delegate: RowLayout {
                    spacing: 10
                    
                    QQC2.Label {
                        text: model.display
                        Layout.preferredWidth: 120
                    }
                    
                    QQC2.Button {
                        text: "↑"
                        enabled: index > 0
                        onClicked: {
                            if (index > 0) {
                                menuItemsModel.move(index, index - 1, 1)
                                updateMenuOrder()
                            }
                        }
                    }
                    
                    QQC2.Button {
                        text: "↓"
                        enabled: index < menuItemsModel.count - 1
                        onClicked: {
                            if (index < menuItemsModel.count - 1) {
                                menuItemsModel.move(index, index + 1, 1)
                                updateMenuOrder()
                            }
                        }
                    }
                }
            }
        }
        
        QQC2.Button {
            text: "Reset to Default"
            Kirigami.FormData.label: " "
            onClicked: {
                cfg_menuOrder = "play,stop,prev,next,separator,close,quit"
                loadMenuOrder()
            }
        }
    }
    
    Component.onCompleted: {
        loadMenuOrder()
    }
    
    function loadMenuOrder() {
        menuItemsModel.clear()
        let order = cfg_menuOrder || "play,stop,prev,next,separator,close,quit"
        let items = order.split(',')
        
        let displayNames = {
            'play': 'Play/Pause',
            'stop': 'Stop',
            'prev': 'Previous',
            'next': 'Next',
            'separator': '─────────',
            'close': 'Close Window',
            'quit': 'Quit Audacious'
        }
        
        for (let i = 0; i < items.length; i++) {
            menuItemsModel.append({
                'id': items[i],
                'display': displayNames[items[i]] || items[i]
            })
        }
    }
    
    function updateMenuOrder() {
        let order = []
        for (let i = 0; i < menuItemsModel.count; i++) {
            order.push(menuItemsModel.get(i).id)
        }
        cfg_menuOrder = order.join(',')
    }
}
