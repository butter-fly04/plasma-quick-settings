/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Configuration page for Quick Settings.  Three tabs:
      1. Panel icons — what to show in the panel (CompactRepresentation).
      2. Popup contents — which sliders, tiles, and buttons to show in
         the popup (FullRepresentation), plus the SNI pill picker.
      3. Screenshot — which backend to use, and the default mode.

    Pattern copied from plasma-workspace's systemmonitor config.qml.
    NOTE: ConfigCategory must be qualified with the PlasmaConfig namespace
    (it's not auto-imported); using bare `ConfigCategory {}` silently
    fails to load the tab.  Each tab page must expose its config keys as
    `cfg_<keyName>` properties for the KConfig binding to work.
*/
import QtQuick
import org.kde.plasma.configuration as PlasmaConfig

PlasmaConfig.ConfigModel {
    PlasmaConfig.ConfigCategory {
        name: i18n("Panel Icons")
        icon: "preferences-desktop-icons"
        source: "configPanelIcons.qml"
    }
    PlasmaConfig.ConfigCategory {
        name: i18n("Popup Contents")
        icon: "preferences-desktop-notification"
        source: "configPopup.qml"
    }
    PlasmaConfig.ConfigCategory {
        name: i18n("Screenshot")
        icon: "camera-photo"
        source: "configScreenshot.qml"
    }
}
