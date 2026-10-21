/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Config tab: screenshot backend & default mode.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents3

KCM.SimpleKCM {
    property string cfg_screenshotBackend
    property string cfg_screenshotDefaultMode

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Screenshot tool")
            model: [
                { display: i18n("Automatic (use the first available)"), value: "auto" },
                { display: i18n("Spectacle (KDE)"), value: "spectacle" },
                { display: i18n("grim + slurp (Wayland)"), value: "grim" },
                { display: i18n("Flameshot"), value: "flameshot" },
                { display: i18n("GNOME Screenshot"), value: "gnome-screenshot" },
                { display: i18n("maim (X11)"), value: "maim" }
            ]
            textRole: "display"
            currentIndex: {
                const v = cfg_screenshotBackend
                for (let i = 0; i < model.length; i++) {
                    if (model[i].value === v) return i
                }
                return 0
            }
            onActivated: cfg_screenshotBackend = model[currentIndex].value
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Default mode")
            model: [
                { display: i18n("Full screen"), value: "fullscreen" },
                { display: i18n("Rectangular region"), value: "region" },
                { display: i18n("Window under cursor"), value: "window" }
            ]
            textRole: "display"
            currentIndex: {
                const v = cfg_screenshotDefaultMode
                for (let i = 0; i < model.length; i++) {
                    if (model[i].value === v) return i
                }
                return 0
            }
            onActivated: cfg_screenshotDefaultMode = model[currentIndex].value
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            text: i18n("Clicking the screenshot button in the popup will use the tool above.  Right-click the screenshot button for the other modes (region / window).")
        }
    }
}
