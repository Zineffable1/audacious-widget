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
    }
}
