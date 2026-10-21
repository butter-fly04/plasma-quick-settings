/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The popup. Two levels: the main grid, and a detail page that opens when a
    tile's arrow is pressed (Wi-Fi list, Bluetooth devices, ...).

    Resizing: Plasma 6 lets the user drag the popup's edges (the ones facing
    away from the panel) and stores the size itself. For that to work this item
    only sets *minimum* sizes and a preferred starting size, never a maximum,
    and everything inside reflows (see `tileColumns`).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: full

    required property PlasmoidItem plasmoidItem
    required property var backend

    // Close the popup, then run an action (so e.g. Spectacle doesn't capture it).
    function closeAnd(action) {
        plasmoidItem.expanded = false
        action()
    }

    // "main" or the id of a detail page
    property string page: "main"

    readonly property int margin: Kirigami.Units.largeSpacing
    // 2 columns by default, more when the popup is dragged wider.
    readonly property int tileColumns: Math.max(2, Math.floor(width / (Kirigami.Units.gridUnit * 11)))

    // The popup follows the active page: pages that opt in with
    // `sizedToContent: true` (NotificationsPage while it is empty) shrink
    // the popup to their own implicit height, everything else keeps the
    // main page's height (list pages rely on the spare room for scrolling).
    readonly property int mainPageMinHeight: mainColumn.implicitHeight + margin * 2
    readonly property bool pageSizedToContent: full.page !== "main"
        && detailLoader.item && detailLoader.item.sizedToContent === true
    readonly property int activePageMinHeight: pageSizedToContent
        ? Math.max(detailLoader.item.implicitHeight + margin * 2,
                   Kirigami.Units.gridUnit * 6)
        : mainPageMinHeight

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: activePageMinHeight
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: activePageMinHeight
    // No Layout.maximumWidth/Height on purpose: that is what keeps it resizable.

    // ------------------------------------------------------------ main page
    ColumnLayout {
        id: mainColumn
        anchors {
            fill: parent
            margins: full.margin
        }
        spacing: Kirigami.Units.largeSpacing
        enabled: opacity > 0.5
        scale: 1

        // Media player card (M11) — two placements: the very top of the
        // popup (above the battery pill and system buttons) or, default,
        // right below the header row.  The setting toggles which wrapper
        // shows; both use the same animated-height pattern.
        Item {
            id: topMediaWrap
            visible: Plasmoid.configuration.showMediaCard
                && Plasmoid.configuration.mediaOnTop
            clip: true
            Layout.fillWidth: true
            implicitHeight: backend.mediaAvailable ? topMediaCard.implicitHeight : 0
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            MediaCard {
                id: topMediaCard
                anchors.fill: parent
                backend: full.backend
            }
        }

        // Top row: battery pill + system buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                visible: full.backend.hasBattery
                implicitHeight: Kirigami.Units.gridUnit * 2.2
                implicitWidth: batteryRow.implicitWidth + Kirigami.Units.largeSpacing * 2
                radius: height / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.1)

                // M7: make the pill open a battery detail page (per-battery
                // list, charge threshold, "keep display awake" toggle).
                // Same click affordance the stock batterymonitor applet has
                // (clicking the panel icon opens its popup).
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: full.page = "battery"
                }

                RowLayout {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: full.backend.batteryIcon
                        fallback: "battery"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    PlasmaComponents3.Label {
                        text: full.backend.batteryPercent + " %"
                        font.bold: true
                    }
                    // Show a small "coffee cup" emblem when the user has
                    // inhibited sleep & screen locking (the stock batterymonitor
                    // sets Plasmoid.status = ActiveStatus in this state; we use
                    // an emblem instead so the pill stays compact).
                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        visible: full.backend.batteryInhibited
                        source: "video-television-symbolic"
                        fallback: "preferences-system-power-management"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.8
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Screenshot button — left-click uses the configured default
            // mode + backend; right-click opens a small menu with the
            // three modes.
            //
            // We wrap the RoundButton in an Item with a transparent
            // MouseArea on top that only accepts Qt.RightButton.  The
            // RoundButton itself keeps its normal onClicked for left-
            // clicks.  (RoundButton doesn't expose `acceptedButtons` —
            // that's a MouseArea property — so we can't just set it on
            // the button directly.)
            Item {
                visible: Plasmoid.configuration.showScreenshotButton
                implicitWidth: ssButton.implicitWidth
                implicitHeight: ssButton.implicitHeight
                Layout.preferredWidth: ssButton.implicitWidth
                Layout.preferredHeight: ssButton.implicitHeight

                PlasmaComponents3.RoundButton {
                    id: ssButton
                    anchors.fill: parent
                    icon.name: "camera-photo"
                    PlasmaComponents3.ToolTip.text: i18n("Screenshot")
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: full.closeAnd(() => full.backend.screenshot())
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            screenshotMenu.popup()
                    }
                }
                PlasmaComponents3.Menu {
                    id: screenshotMenu
                    PlasmaComponents3.MenuItem {
                        text: i18n("Full Screen")
                        icon.name: "camera-photo"
                        onTriggered: full.closeAnd(() => full.backend.screenshot("fullscreen"))
                    }
                    PlasmaComponents3.MenuItem {
                        text: i18n("Rectangular Region")
                        icon.name: "edit-select-rectangular"
                        onTriggered: full.closeAnd(() => full.backend.screenshot("region"))
                    }
                    PlasmaComponents3.MenuItem {
                        text: i18n("Window Under Cursor")
                        icon.name: "window"
                        onTriggered: full.closeAnd(() => full.backend.screenshot("window"))
                    }
                }
            }
            PlasmaComponents3.RoundButton {
                visible: Plasmoid.configuration.showSettingsButton
                icon.name: "configure"
                PlasmaComponents3.ToolTip.text: i18n("System Settings")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: full.closeAnd(() => full.backend.openSettings())
            }
            PlasmaComponents3.RoundButton {
                visible: Plasmoid.configuration.showLockButton
                icon.name: "system-lock-screen"
                PlasmaComponents3.ToolTip.text: i18n("Lock Screen")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: full.closeAnd(() => full.backend.lockScreen())
            }
            PlasmaComponents3.RoundButton {
                visible: Plasmoid.configuration.showPowerButton
                icon.name: "system-shutdown"
                PlasmaComponents3.ToolTip.text: i18n("Shut Down / Restart / Log Out")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: full.closeAnd(() => full.backend.powerMenu())
            }
        }

        // Media card below the header (M11, default placement).
        Item {
            id: mediaWrap
            visible: Plasmoid.configuration.showMediaCard
                && !Plasmoid.configuration.mediaOnTop
            clip: true
            Layout.fillWidth: true
            implicitHeight: backend.mediaAvailable ? backendCard.implicitHeight : 0
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            MediaCard {
                id: backendCard
                anchors.fill: parent
                backend: full.backend
            }
        }

        // Sliders.  The volume and microphone rows carry a device-picker
        // arrow (GNOME quick settings style); their backend shares the
        // qs.sh/pactl plumbing with the mute/volume commands above.
        SliderRow {
            visible: Plasmoid.configuration.showVolumeSlider
            Layout.fillWidth: true
            enabled: full.backend.audioAvailable
            icon: full.backend.volumeIcon
            value: full.backend.volume
            dimmed: full.backend.muted || !full.backend.audioAvailable
            devices: full.backend.audioSinks
            picker: true
            onMoved: value => full.backend.setVolume(value)
            onIconClicked: full.backend.toggleMute()
            onDevicesRequested: full.backend.refreshAudioSinks()
            onDevicePicked: name => full.backend.setDefaultSink(name)
        }
        SliderRow {
            visible: Plasmoid.configuration.showMicSlider && full.backend.micAvailable
            Layout.fillWidth: true
            icon: full.backend.micIcon
            value: full.backend.micVolume
            dimmed: full.backend.micMuted
            deviceIcon: "audio-input-microphone"
            devices: full.backend.audioSources
            picker: true
            onMoved: value => full.backend.setMicVolume(value)
            onIconClicked: full.backend.toggleMicMute()
            onDevicesRequested: full.backend.refreshAudioSources()
            onDevicePicked: name => full.backend.setDefaultSource(name)
        }
        SliderRow {
            visible: Plasmoid.configuration.showBrightnessSlider && full.backend.brightnessAvailable
            Layout.fillWidth: true
            icon: "brightness-high"
            value: full.backend.brightness
            onMoved: value => full.backend.setBrightness(value)
        }

        // SNI pills row (M7) — StatusNotifierItems shown as QuickTile-style
        // pills above the main tiles grid.  Either the user-pinned items
        // only, or (M11) every live tray app when the setting is on.  Each
        // pill's arrow opens the item's own context menu.  Hidden when
        // nothing qualifies.
        GridLayout {
            visible: full.backend.pillSniItems.length > 0
            Layout.fillWidth: true
            columns: full.tileColumns
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: full.backend.pillSniItems
                delegate: SniTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    sni: modelData
                    backend: full.backend
                }
            }
        }

        // Tiles (GNOME-style grid; gains columns when the popup is widened)
        GridLayout {
            Layout.fillWidth: true
            columns: full.tileColumns
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            QuickTile {
                visible: Plasmoid.configuration.showWifiTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "network-wireless"
                title: i18n("Wi-Fi")
                subtitle: full.backend.wifiSubtitle
                wired: full.backend.wifiAvailable
                active: full.backend.wifiEnabled
                expandable: true
                onToggled: full.backend.setWifiEnabled(!full.backend.wifiEnabled)
                onExpanded: full.page = "wifi"
            }
            QuickTile {
                visible: Plasmoid.configuration.showBluetoothTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "preferences-system-bluetooth"
                title: i18n("Bluetooth")
                subtitle: full.backend.bluetoothSubtitle
                wired: full.backend.bluetoothAvailable
                active: full.backend.bluetoothEnabled
                expandable: true
                onToggled: full.backend.setBluetoothEnabled(!full.backend.bluetoothEnabled)
                onExpanded: full.page = "bluetooth"
            }
            QuickTile {
                visible: Plasmoid.configuration.showPowerModeTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "speedometer"
                title: i18n("Power Mode")
                subtitle: full.backend.powerProfileAvailable
                    ? full.backend.powerProfileLabel
                    : i18n("Unavailable")
                wired: full.backend.powerProfileAvailable
                active: full.backend.powerProfile !== "balanced"
                       && full.backend.powerProfile !== ""
                expandable: true
                onToggled: full.backend.cyclePowerProfile()
                onExpanded: full.page = "power"
            }
            QuickTile {
                visible: Plasmoid.configuration.showNightLightTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                // "redshift-status-on" exists in many Breeze variants; the
                // tile's `active` fill (highlight color) shows on/off, so we
                // use the same icon for both states and avoid relying on a
                // matching "-off" variant that may not be installed.
                icon: "redshift-status-on"
                title: i18n("Night Light")
                subtitle: full.backend.nightColorSubtitle
                wired: full.backend.nightColorAvailable
                active: full.backend.nightLight
                onToggled: full.backend.toggleNightLight()
            }
            QuickTile {
                visible: Plasmoid.configuration.showDarkStyleTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                // Same icon for both states; the tile fill changes with `active`.
                icon: "preferences-desktop-color"
                title: i18n("Dark Style")
                subtitle: full.backend.colorSchemeSubtitle
                wired: full.backend.colorSchemeAvailable
                       && full.backend.colorSchemePartner.length > 0
                active: full.backend.darkStyle
                onToggled: full.backend.toggleDarkStyle()
            }
            QuickTile {
                visible: Plasmoid.configuration.showDoNotDisturbTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: full.backend.doNotDisturb
                    ? "notifications-disabled"
                    : "preferences-desktop-notification"
                title: i18n("Do Not Disturb")
                subtitle: {
                    if (!full.backend.dndAvailable) return i18n("Unavailable")
                    if (full.backend.doNotDisturb)
                        return full.backend.dndByApplication
                            ? i18n("On (by an app)")
                            : i18n("On")
                    return i18n("Off")
                }
                wired: full.backend.dndAvailable
                active: full.backend.doNotDisturb
                onToggled: full.backend.toggleDoNotDisturb()
            }
            QuickTile {
                visible: Plasmoid.configuration.showAirplaneModeTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                // Breeze only ships the "on" variant of the airplane icon;
                // the active fill indicates the state.
                icon: "network-flightmode-on"
                title: i18n("Airplane Mode")
                subtitle: full.backend.airplaneSubtitle
                wired: full.backend.airplaneAvailable && !full.backend.airplaneHardBlocked
                active: full.backend.airplaneMode
                onToggled: full.backend.toggleAirplaneMode()
            }
            // ---- M5 extras -------------------------------------------------
            QuickTile {
                visible: Plasmoid.configuration.showClipboardTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "klipper-symbolic"
                title: i18n("Clipboard")
                subtitle: full.backend.clipboardAvailable
                    ? (full.backend.clipboardEmpty
                        ? i18n("Empty")
                        : i18np("One item", "%1 items", full.backend.clipboardCount))
                    : i18n("Unavailable")
                wired: full.backend.clipboardAvailable
                active: !full.backend.clipboardEmpty
                expandable: true
                onToggled: {
                    // Clicking the tile when there's history opens the page;
                    // when empty, fall through to opening the page anyway so
                    // the user can configure klipper.
                    full.page = "clipboard"
                }
                onExpanded: full.page = "clipboard"
            }
            QuickTile {
                visible: Plasmoid.configuration.showKdeConnectTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "kdeconnect"
                title: i18n("KDE Connect")
                subtitle: full.backend.kdeconnectSubtitle
                wired: full.backend.kdeconnectAvailable
                active: full.backend.kdeconnectConnectedCount > 0
                expandable: true
                onToggled: full.page = "kdeconnect"
                onExpanded: full.page = "kdeconnect"
            }
            QuickTile {
                visible: Plasmoid.configuration.showDevicesTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: "drive-removable-media"
                title: i18n("Devices")
                subtitle: full.backend.devicesSubtitle
                wired: full.backend.devicesAvailable
                active: full.backend.devicesCount > 0
                expandable: true
                onToggled: full.page = "devices"
                onExpanded: full.page = "devices"
            }
            QuickTile {
                visible: Plasmoid.configuration.showInputMethodTile
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: full.backend.inputMethodVisible
                    ? "input-keyboard-virtual-show-symbolic"
                    : "input-keyboard-virtual-off-symbolic"
                title: i18n("Input Method")
                subtitle: full.backend.inputMethodSubtitle
                wired: full.backend.inputMethodAvailable
                active: full.backend.inputMethodVisible
                expandable: true
                onToggled: full.backend.inputMethodToggle()
                onExpanded: full.page = "inputmethod"
            }
        }

        // Extra height from resizing goes here, so the footer stays at the bottom.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Footer row: opens the Notifications page (M7) — same shape as the
        // Tray & Background Apps footer below it.
        MouseArea {
            visible: Plasmoid.configuration.showTrayFooter
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 2.2
            hoverEnabled: true
            onClicked: full.page = "notifications"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    isMask: true
                    color: Kirigami.Theme.textColor
                    source: full.backend.doNotDisturb
                        ? "notifications-disabled"
                        : "preferences-desktop-notification"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents3.Label {
                    text: i18n("Notifications")
                    font.bold: true
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    visible: full.backend.notifUnreadCount > 0
                    text: i18np("One unread", "%1 unread", full.backend.notifUnreadCount)
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                Kirigami.Icon {
                    isMask: true
                    color: Kirigami.Theme.textColor
                    source: "go-next"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
            }
        }

        // Footer row: opens the Tray & Background Apps page (Milestone 6)
        MouseArea {
            visible: Plasmoid.configuration.showTrayFooter
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 2.2
            hoverEnabled: true
            onClicked: full.page = "tray"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing
                PlasmaComponents3.Label {
                    text: i18n("Tray & Background Apps")
                    font.bold: true
                    Layout.fillWidth: true
                }
                // Live subtitle (item count) so the user can see at a glance
                // whether anything is running without opening the page.
                PlasmaComponents3.Label {
                    visible: full.backend.trayCount > 0
                    text: full.backend.traySubtitle
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                Kirigami.Icon {
                    isMask: true
                    color: Kirigami.Theme.textColor
                    source: "go-next"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
            }
        }
    }

    // ---------------------------------------------------------- detail page
    // Both pages stay mounted and cross-fade (with a slight scale settle)
    // when switching; `enabled` hands interaction to the opaque page.
    ColumnLayout {
        id: detailColumn
        anchors {
            fill: parent
            margins: full.margin
        }
        spacing: Kirigami.Units.largeSpacing
        opacity: 0
        scale: 0.96
        enabled: !mainColumn.enabled
        transformOrigin: Item.Top

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.ToolButton {
                icon.name: "go-previous"
                onClicked: full.page = "main"
            }
            Kirigami.Heading {
                level: 3
                text: {
                    switch (full.page) {
                    case "wifi": return i18n("Wi-Fi")
                    case "bluetooth": return i18n("Bluetooth")
                    case "power": return i18n("Power Mode")
                    case "battery": return i18n("Battery & Power")
                    case "clipboard": return i18n("Clipboard")
                    case "kdeconnect": return i18n("KDE Connect")
                    case "devices": return i18n("Disks & Devices")
                    case "inputmethod": return i18n("Input Method")
                    case "notifications": return i18n("Notifications")
                    case "tray": return i18n("Tray & Background Apps")
                    default: return ""
                    }
                }
                Layout.fillWidth: true
            }
            // Notifications page: "clear all history" lives on the heading
            // bar (M11) instead of a row of its own below the header.
            PlasmaComponents3.ToolButton {
                visible: full.page === "notifications"
                enabled: full.backend.notifHistoryCount > 0
                icon.name: "trash-empty"
                PlasmaComponents3.ToolTip.text: i18n("Clear All Notifications")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: full.backend.notifClearExpired()
            }
        }

        Component {
            id: wifiPage
            WifiPage { backend: full.backend }
        }
        Component {
            id: bluetoothPage
            BluetoothPage { backend: full.backend }
        }
        Component {
            id: powerPage
            PowerModePage { backend: full.backend }
        }
        Component {
            id: batteryPage
            BatteryPage { backend: full.backend }
        }
        Component {
            id: clipboardPage
            ClipboardPage { backend: full.backend }
        }
        Component {
            id: kdeconnectPage
            KDEConnectPage { backend: full.backend }
        }
        Component {
            id: devicesPage
            DevicesPage { backend: full.backend }
        }
        Component {
            id: inputMethodPage
            InputMethodPage { backend: full.backend }
        }
        Component {
            id: notificationsPage
            NotificationsPage { backend: full.backend }
        }
        Component {
            id: trayPage
            TrayPage { backend: full.backend }
        }
        // Placeholder kept for any future page that hasn't been built yet.
        Component {
            id: comingSoonPage
            Kirigami.PlaceholderMessage {
                icon.name: "view-list-details"
                text: i18n("Coming in a later milestone")
            }
        }

        Loader {
            id: detailLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: full.page !== "main"
            sourceComponent: full.page === "wifi" ? wifiPage
                : full.page === "bluetooth" ? bluetoothPage
                : full.page === "power" ? powerPage
                : full.page === "battery" ? batteryPage
                : full.page === "clipboard" ? clipboardPage
                : full.page === "kdeconnect" ? kdeconnectPage
                : full.page === "devices" ? devicesPage
                : full.page === "inputmethod" ? inputMethodPage
                : full.page === "notifications" ? notificationsPage
                : full.page === "tray" ? trayPage
                : comingSoonPage
        }
    }

    // Page transitions: main <-> detail cross-fade with a subtle scale
    // settle (same durations/curves the rest of plasma uses).
    states: [
        State {
            name: "mainPage"
            when: full.page === "main"
            PropertyChanges {
                target: mainColumn
                opacity: 1
                scale: 1
            }
            PropertyChanges {
                target: detailColumn
                opacity: 0
                scale: 0.96
            }
        },
        State {
            name: "detailPage"
            when: full.page !== "main"
            PropertyChanges {
                target: detailColumn
                opacity: 1
                scale: 1
            }
            PropertyChanges {
                target: mainColumn
                opacity: 0
                scale: 0.96
            }
        }
    ]
    transitions: [
        Transition {
            NumberAnimation {
                properties: "opacity,scale"
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    ]

    // Tell the backend which page is open (it refreshes that page's list)...
    onPageChanged: backend.activePage = page

    // ...and always reopen on the main page.
    Connections {
        target: full.plasmoidItem
        function onExpandedChanged() {
            if (!full.plasmoidItem.expanded)
                full.page = "main"
        }
    }
}
