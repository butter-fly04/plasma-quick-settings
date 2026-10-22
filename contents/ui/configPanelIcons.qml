/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Config tab: panel icon visibility.

    Each `cfg_<key>` property mirrors a key in main.xml's PanelIcons group.
    Plasma's config framework binds these to Plasmoid.configuration
    automatically — CheckBoxes read `checked: cfg_showFoo` and write back
    via `onToggled: cfg_showFoo = checked`.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    // Mirror every key in the PanelIcons group of main.xml.
    property bool cfg_showCameraIndicator
    property bool cfg_showMicIndicator
    property bool cfg_showNetworkIcon
    property bool cfg_showVolumeIcon
    property bool cfg_showBatteryIcon
    property bool cfg_showBatteryPercent
    // Tray per-icon pass-through (keys live in the Tray group).
    property bool cfg_showPanelTrayIcons
    property var cfg_hiddenPanelSni
    property var cfg_panelTrayIconList

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Panel icons")
            text: i18n("Camera in-use indicator")
            checked: cfg_showCameraIndicator
            onToggled: cfg_showCameraIndicator = checked
        }
        QQC2.CheckBox {
            text: i18n("Microphone in-use indicator")
            checked: cfg_showMicIndicator
            onToggled: cfg_showMicIndicator = checked
        }
        QQC2.CheckBox {
            text: i18n("Network (Wi-Fi / Ethernet)")
            checked: cfg_showNetworkIcon
            onToggled: cfg_showNetworkIcon = checked
        }
        QQC2.CheckBox {
            text: i18n("Volume")
            checked: cfg_showVolumeIcon
            onToggled: cfg_showVolumeIcon = checked
        }
        QQC2.CheckBox {
            text: i18n("Battery")
            checked: cfg_showBatteryIcon
            onToggled: cfg_showBatteryIcon = checked
        }
        QQC2.CheckBox {
            text: i18n("Battery percentage (horizontal panels only)")
            checked: cfg_showBatteryPercent
            onToggled: cfg_showBatteryPercent = checked
            enabled: cfg_showBatteryIcon
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("System tray")
            text: i18n("Show each tray app as its own icon in the panel")
            checked: cfg_showPanelTrayIcons
            onToggled: cfg_showPanelTrayIcons = checked
        }

        // Per-icon panel visibility: one checkbox per running tray app.
        // The list comes from the snapshot the applet keeps in the
        // configuration (Backend.qml applyTrayPoll); unchecked = hidden
        // from the panel, the icon still shows in the popup's tray page.
        PlasmaComponents3.Label {
            visible: cfg_showPanelTrayIcons && (cfg_panelTrayIconList || []).length > 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.8
            text: i18n("Choose which tray app icons appear in the panel:")
        }

        Repeater {
            model: cfg_showPanelTrayIcons ? (cfg_panelTrayIconList || []) : 0

            delegate: QQC2.CheckBox {
                required property string modelData

                readonly property string sniKey: modelData.split("|").slice(0, 2).join("|")
                readonly property string sniTitle: modelData.split("|").slice(2).join("||") || sniKey

                text: sniTitle
                visible: cfg_showPanelTrayIcons
                checked: !((cfg_hiddenPanelSni || []).indexOf(sniKey) !== -1)
                onToggled: {
                    const hidden = (cfg_hiddenPanelSni || []).slice()
                    const i = hidden.indexOf(sniKey)
                    if (!checked && i === -1)
                        hidden.push(sniKey)
                    else if (checked && i !== -1)
                        hidden.splice(i, 1)
                    cfg_hiddenPanelSni = hidden
                }
            }
        }
    }
}
