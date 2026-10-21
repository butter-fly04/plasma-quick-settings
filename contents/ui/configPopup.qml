/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Config tab: popup contents (sliders, tiles, buttons).

    Each `cfg_<key>` property mirrors a key in main.xml's Sliders/Tiles/
    Buttons groups.  Plasma's config framework binds these to
    Plasmoid.configuration automatically.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents3

KCM.SimpleKCM {
    // Sliders group
    property bool cfg_showVolumeSlider
    property bool cfg_showMicSlider
    property bool cfg_showBrightnessSlider
    // Tiles group
    property bool cfg_showWifiTile
    property bool cfg_showBluetoothTile
    property bool cfg_showPowerModeTile
    property bool cfg_showNightLightTile
    property bool cfg_showDarkStyleTile
    property bool cfg_showDoNotDisturbTile
    property bool cfg_showAirplaneModeTile
    property bool cfg_showClipboardTile
    property bool cfg_showKdeConnectTile
    property bool cfg_showDevicesTile
    property bool cfg_showInputMethodTile
    // Buttons group
    property bool cfg_showScreenshotButton
    property bool cfg_showSettingsButton
    property bool cfg_showLockButton
    property bool cfg_showPowerButton
    property bool cfg_showMediaCard
    property bool cfg_mediaOnTop
    property bool cfg_showTrayFooter
    property bool cfg_showDndInNotifications
    // Tray pills group
    property bool cfg_showSniPills

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Sliders")
            text: i18n("Output volume")
            checked: cfg_showVolumeSlider
            onToggled: cfg_showVolumeSlider = checked
        }
        QQC2.CheckBox {
            text: i18n("Microphone volume")
            checked: cfg_showMicSlider
            onToggled: cfg_showMicSlider = checked
        }
        QQC2.CheckBox {
            text: i18n("Screen brightness")
            checked: cfg_showBrightnessSlider
            onToggled: cfg_showBrightnessSlider = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Tiles")
            text: i18n("Wi-Fi")
            checked: cfg_showWifiTile
            onToggled: cfg_showWifiTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Bluetooth")
            checked: cfg_showBluetoothTile
            onToggled: cfg_showBluetoothTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Power Mode")
            checked: cfg_showPowerModeTile
            onToggled: cfg_showPowerModeTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Night Light")
            checked: cfg_showNightLightTile
            onToggled: cfg_showNightLightTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Dark Style")
            checked: cfg_showDarkStyleTile
            onToggled: cfg_showDarkStyleTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Do Not Disturb")
            checked: cfg_showDoNotDisturbTile
            onToggled: cfg_showDoNotDisturbTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Airplane Mode")
            checked: cfg_showAirplaneModeTile
            onToggled: cfg_showAirplaneModeTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Clipboard")
            checked: cfg_showClipboardTile
            onToggled: cfg_showClipboardTile = checked
        }
        QQC2.CheckBox {
            text: i18n("KDE Connect")
            checked: cfg_showKdeConnectTile
            onToggled: cfg_showKdeConnectTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Disks & Devices")
            checked: cfg_showDevicesTile
            onToggled: cfg_showDevicesTile = checked
        }
        QQC2.CheckBox {
            text: i18n("Input Method")
            checked: cfg_showInputMethodTile
            onToggled: cfg_showInputMethodTile = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Top-right buttons")
            text: i18n("Screenshot")
            checked: cfg_showScreenshotButton
            onToggled: cfg_showScreenshotButton = checked
        }
        QQC2.CheckBox {
            text: i18n("System Settings")
            checked: cfg_showSettingsButton
            onToggled: cfg_showSettingsButton = checked
        }
        QQC2.CheckBox {
            text: i18n("Lock Screen")
            checked: cfg_showLockButton
            onToggled: cfg_showLockButton = checked
        }
        QQC2.CheckBox {
            text: i18n("Shut Down / Restart / Log Out")
            checked: cfg_showPowerButton
            onToggled: cfg_showPowerButton = checked
        }
        QQC2.CheckBox {
            text: i18n("Media player card (when a player is running)")
            checked: cfg_showMediaCard
            onToggled: cfg_showMediaCard = checked
        }
        QQC2.CheckBox {
            text: i18n("Tray & Background Apps footer")
            checked: cfg_showTrayFooter
            onToggled: cfg_showTrayFooter = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Tray pills")
            text: i18n("Show all system tray apps as pills")
            checked: cfg_showSniPills
            onToggled: cfg_showSniPills = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Notifications page")
            text: i18n("Show the Do Not Disturb switch")
            checked: cfg_showDndInNotifications
            onToggled: cfg_showDndInNotifications = checked
        }

        // SNI pill hint — actual editing happens via the Tray page's right-click
        // action ("Pin to Quick Settings"), but we mention it here so the user
        // knows where to look.
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.8
            text: i18n("With this off, only icons pinned from the Tray page (right-click an item there and choose \"Pin to Quick Settings\") show as pills in the main grid.")
        }
    }
}
