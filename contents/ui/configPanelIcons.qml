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
    }
}
