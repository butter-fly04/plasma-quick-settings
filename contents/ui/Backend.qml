/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Single place that owns all state shown in the popup and panel.

    All system access goes through ../scripts/qs.sh, run with the Plasma5Support
    "executable" engine. That engine is deprecated in Plasma 6 (no official
    replacement yet), so it is wrapped in exactly one spot here (`exec` and
    `run()`): if it ever disappears only this file needs to change.

    Where Plasma already has the logic, we reuse Plasma's own QML modules instead of
    re-implementing it (each in its own file under backends/, loaded through a
    Loader so that a module missing on some system only disables that one feature):
      battery      backends/BatteryBackend.qml        org.kde.plasma.private.battery
      bluetooth    backends/BluetoothBackend.qml      org.kde.bluezqt + ...private.bluetooth
      powerprofile backends/PowerProfileBackend.qml   org.kde.plasma.private.batterymonitor
      dnd          backends/NotificationsBackend.qml  org.kde.notificationmanager
      nightcolor   backends/NightColorBackend.qml     (state only; D-Bus via qs.sh)
      colorscheme  backends/ColorSchemeBackend.qml    (state only; plasma-apply-colorscheme via qs.sh)
      airplane     backends/AirplaneModeBackend.qml   (state only; rfkill via qs.sh)
      media        backends/MediaPlayerBackend.qml    org.kde.plasma.private.mpris
      clipboard    backends/ClipboardBackend.qml      org.kde.plasma.private.clipboard
      kdeconnect   backends/KDEConnectBackend.qml     org.kde.kdeconnect
      devices      backends/DevicesBackend.qml        plasma.applet.org.kde.plasma.devicenotifier
      inputmethod  backends/InputMethodBackend.qml    org.kde.plasma.workspace.keyboardlayout
      camera       backends/CameraIndicatorBackend.qml  org.kde.pipewire.monitor
      mic          backends/MicrophoneInUseBackend.qml  org.kde.pipewire.monitor
      tray         backends/TrayBackend.qml           (live StatusNotifierModel
                                                       + Background Apps via qs.sh)

    Still on ../scripts/qs.sh (to be moved to Plasma's modules next): volume,
    microphone, brightness, Wi-Fi, Night Color, Color Scheme, Airplane Mode,
    Background Apps.
*/
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

Item {
    id: backend
    visible: false

    // Set from main.qml / FullRepresentation.qml
    property bool popupOpen: false

    // Panel tray-icon hover state (M12.2): while the mouse is over one of
    // the per-app panel icons, the applet's own tooltip is suppressed and
    // the icon's tooltip takes over (see main.qml toolTipMainText).
    property string panelHoverSni: ""
    property string panelHoverSniTooltip: ""
    function setPanelSniHover(title, tooltip) {
        panelHoverSni = title || ""
        panelHoverSniTooltip = tooltip || ""
    }
    function clearPanelSniHover() {
        panelHoverSni = ""
        panelHoverSniTooltip = ""
    }

    // Panel keyboard-layout hover: while the mouse is over the layout
    // indicator, the applet's (shell-positioned) tooltip shows the layout's
    // full name instead of the Quick Settings summary.  Using the applet
    // tooltip keeps this to one tooltip, exactly like the tray icons above.
    property string panelHoverKeyboardLayout: ""
    function setPanelKeyboardLayoutHover(name) {
        panelHoverKeyboardLayout = name || ""
    }
    property string activePage: "main"      // "main", "wifi", "bluetooth", "power", ...
    property bool listsPaused: false        // true while the user types a password

    // ---------------------------------------------------------------- audio
    property bool audioAvailable: false
    property real volume: 0          // 0..1
    property bool muted: false
    property bool micAvailable: false
    property real micVolume: 0       // 0..1
    property bool micMuted: false
    // Device lists for the GNOME-style device-picker arrows on the
    // volume and microphone sliders; refreshed on demand (when the user
    // expands the picker), each entry is {name, active, description}.
    property var audioSinks: []
    property var audioSources: []

    // ----------------------------------------------------------- brightness
    property bool brightnessAvailable: false
    property real brightness: 0      // 0..1

    // -------------------------------------------------------------- battery
    // From Plasma's BatteryControlModel (all batteries combined, like the stock applet).
    Loader {
        id: batteryLoader
        source: "backends/BatteryBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] battery backend could not be loaded (org.kde.plasma.private.battery missing?)")
    }
    readonly property bool hasBattery: batteryLoader.item ? batteryLoader.item.present : false
    readonly property int batteryPercent: batteryLoader.item ? batteryLoader.item.percent : 0
    readonly property bool charging: batteryLoader.item ? batteryLoader.item.charging : false
    readonly property string batteryIcon: batteryLoader.item ? batteryLoader.item.iconName : "battery-missing"
    // M7 additions for the battery detail page.
    readonly property bool batteryPluggedIn: batteryLoader.item ? batteryLoader.item.pluggedIn : false
    readonly property int batteryRemainingMsec: batteryLoader.item ? batteryLoader.item.remainingMsec : 0
    readonly property int batteryChargeStopThreshold: batteryLoader.item ? batteryLoader.item.chargeStopThreshold : 0
    readonly property bool batteryInhibited: batteryLoader.item ? batteryLoader.item.inhibited : false
    readonly property var batteriesModel: batteryLoader.item ? batteryLoader.item.batteriesModel : null

    function batteryToggleInhibited() {
        if (batteryLoader.item) batteryLoader.item.toggleInhibited()
    }

    // --------------------------------------------------------------- Wi-Fi
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property string wifiSsid: ""             // active network, "" when none
    property int wifiSignal: 0               // 0..100
    property bool ethConnected: false
    property var wifiNetworks: []            // [{ssid, signal, level, secure, saved, active}]
    property string wifiBusySsid: ""         // network being connected right now
    property string wifiError: ""
    property bool wifiScanning: false

    // ------------------------------------------------------------ Bluetooth
    // From BlueDevil's own logic (bluez-qt + its private models), see BluetoothBackend.qml.
    Loader {
        id: btLoader
        source: "backends/BluetoothBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] bluetooth backend could not be loaded (bluedevil / bluez-qt missing?)")
    }
    readonly property bool bluetoothAvailable: btLoader.item ? btLoader.item.present : false
    readonly property bool bluetoothEnabled: btLoader.item ? btLoader.item.operational : false
    readonly property int btConnectedCount: btLoader.item ? btLoader.item.connectedCount : 0
    readonly property string btConnectedName: btLoader.item ? btLoader.item.connectedName : ""
    readonly property var btModel: btLoader.item ? btLoader.item.devicesModel : null

    // -------------------------------------------------- Power Profile (M4)
    // Reuses powerdevil's PowerProfilesControl via org.kde.plasma.private.batterymonitor,
    // so the slider/tile matches the stock "Power & Battery" applet's behaviour exactly
    // (profiles list, inhibition reasons, profile holds).
    Loader {
        id: powerProfileLoader
        source: "backends/PowerProfileBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] power-profile backend could not be loaded (org.kde.plasma.private.batterymonitor missing?)")
    }
    readonly property bool powerProfileAvailable: powerProfileLoader.item ? powerProfileLoader.item.available : false
    readonly property bool powerProfileTlp: powerProfileLoader.item ? powerProfileLoader.item.tlpInstalled : false
    readonly property var powerProfiles: powerProfileLoader.item ? powerProfileLoader.item.profiles : []
    readonly property string powerProfile: powerProfileLoader.item ? powerProfileLoader.item.activeProfile : ""
    readonly property string powerProfileConfigured: powerProfileLoader.item ? powerProfileLoader.item.configuredProfile : ""
    readonly property string powerProfileInhibitionReason: powerProfileLoader.item ? powerProfileLoader.item.inhibitionReason : ""
    readonly property string powerProfileDegradationReason: powerProfileLoader.item ? powerProfileLoader.item.degradationReason : ""
    readonly property var powerProfileHolds: powerProfileLoader.item ? powerProfileLoader.item.profileHolds : []
    readonly property string powerProfileLabel: powerProfileLoader.item ? powerProfileLoader.item.activeProfileLabel : i18n("Balanced")
    readonly property bool powerProfilePerformanceInhibited: powerProfileLoader.item ? powerProfileLoader.item.performanceInhibited : false

    // ------------------------------------------------------- DND / M4 (M4)
    // Reuses plasma-workspace's libnotificationmanager — same Settings object
    // the notifications applet uses, so toggling here matches the tray.
    Loader {
        id: dndLoader
        source: "backends/NotificationsBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] notifications/DnD backend could not be loaded (org.kde.notificationmanager missing?)")
    }
    readonly property bool dndAvailable: dndLoader.item ? dndLoader.item.available : false
    readonly property bool doNotDisturb: dndLoader.item ? dndLoader.item.inhibited : false
    readonly property bool dndByApplication: dndLoader.item ? dndLoader.item.inhibitedByApplication : false

    // ----------------------------- Notifications history (M7)
    // Same `org.kde.notificationmanager.Notifications` model the stock
    // notifications applet uses for its history list.
    Loader {
        id: notifHistoryLoader
        source: "backends/NotificationsHistoryBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] notifications-history backend could not be loaded (org.kde.notificationmanager missing?)")
    }
    readonly property bool notifHistoryAvailable: notifHistoryLoader.item ? notifHistoryLoader.item.available : false
    readonly property var notifHistoryModel: notifHistoryLoader.item ? notifHistoryLoader.item.model : null
    readonly property int notifHistoryCount: notifHistoryLoader.item ? notifHistoryLoader.item.count : 0
    readonly property int notifUnreadCount: notifHistoryLoader.item ? notifHistoryLoader.item.unreadCount : 0
    readonly property int notifDismissedCount: notifHistoryLoader.item ? notifHistoryLoader.item.dismissedCount : 0

    function notifMarkAllRead() { if (notifHistoryLoader.item) notifHistoryLoader.item.markAllRead() }
    function notifClearExpired() { if (notifHistoryLoader.item) notifHistoryLoader.item.clearExpired() }

    // --------------------------------------------------- Notification toasts (M12)
    // Popup model, a copy of the stock notifications applet's
    // popupNotificationsModel (see backends/NotificationPopupBackend.qml).
    // There is no stock notifications applet on this system, so this
    // applet owns the screen toasts — NotificationToast.qml renders them.
    // Each popup stops the model's timeout while it is on screen and runs
    // its own countdown (so hovering can pause it), exactly like stock.
    Loader {
        id: notifToastLoader
        source: "backends/NotificationPopupBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] notifications-toast backend could not be loaded (org.kde.notificationmanager missing?)")
    }
    readonly property var notifToastModel: notifToastLoader.item ? notifToastLoader.item.model : null
    readonly property int notifToastCount: notifToastLoader.item ? notifToastLoader.item.count : 0
    readonly property int notifPopupTimeout: notifToastLoader.item ? notifToastLoader.item.notifPopupTimeout : 5000
    readonly property bool notifShowPopupTimeout: notifToastLoader.item ? notifToastLoader.item.notifShowPopupTimeout : true

    function notifToastClose(index) { if (notifToastLoader.item) notifToastLoader.item.close(index) }
    function notifToastExpire(index) { if (notifToastLoader.item) notifToastLoader.item.expire(index) }
    function notifToastExpireAll() { if (notifToastLoader.item) notifToastLoader.item.expireAll() }
    function notifToastConfigure(index) { if (notifToastLoader.item) notifToastLoader.item.configure(index) }
    function notifToastInvokeDefault(index) { if (notifToastLoader.item) notifToastLoader.item.invokeDefaultAction(index) }
    function notifToastInvokeAction(index, actionName) { if (notifToastLoader.item) notifToastLoader.item.invokeAction(index, actionName) }
    function notifToastStopTimeout(index) { if (notifToastLoader.item) notifToastLoader.item.stopTimeout(index) }
    function notifToastStartTimeout(notificationId) { if (notifToastLoader.item) notifToastLoader.item.startTimeout(notificationId) }


    // ----------------------------------------------------- Night Color (M4)
    // KWin owns this; we talk to org.kde.KWin.NightLight through qs.sh.
    Loader {
        id: nightColorLoader
        source: "backends/NightColorBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] night-color backend could not be loaded")
    }
    readonly property bool nightColorAvailable: nightColorLoader.item ? nightColorLoader.item.available : false
    property bool nightLight: nightColorLoader.item ? nightColorLoader.item.enabled : false
    readonly property string nightColorSubtitle: nightColorLoader.item ? nightColorLoader.item.subtitle : ""

    // ------------------------------------------------- Color scheme / M4 (M4)
    // plasma-apply-colorscheme (the official CLI) through qs.sh.
    Loader {
        id: colorSchemeLoader
        source: "backends/ColorSchemeBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] color-scheme backend could not be loaded")
    }
    readonly property bool colorSchemeAvailable: colorSchemeLoader.item ? colorSchemeLoader.item.available : false
    readonly property bool darkStyle: colorSchemeLoader.item ? colorSchemeLoader.item.darkActive : false
    readonly property string colorSchemeName: colorSchemeLoader.item ? colorSchemeLoader.item.currentScheme : ""
    readonly property string colorSchemeSubtitle: colorSchemeLoader.item ? colorSchemeLoader.item.subtitle : ""
    readonly property string colorSchemePartner: colorSchemeLoader.item ? colorSchemeLoader.item.partner : ""

    // ------------------------------------------------------- Airplane (M4)
    // rfkill through qs.sh.  Toggling this also turns Wi-Fi and Bluetooth off
    // (or back on) at the kernel level; the Wi-Fi/Bluetooth backends will pick
    // the change up on their next poll and refresh their own tiles.
    Loader {
        id: airplaneLoader
        source: "backends/AirplaneModeBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] airplane-mode backend could not be loaded")
    }
    readonly property bool airplaneAvailable: airplaneLoader.item ? airplaneLoader.item.available : false
    property bool airplaneMode: airplaneLoader.item ? airplaneLoader.item.active : false
    readonly property bool airplaneHardBlocked: airplaneLoader.item ? airplaneLoader.item.hardBlocked : false
    readonly property string airplaneSubtitle: airplaneLoader.item ? airplaneLoader.item.subtitle : ""

    // ------------------------------------------------------------ Media (M5)
    // From plasma-workspace's libkmpris (org.kde.plasma.private.mpris),
    // the same Mpris2Model the stock mediacontroller applet uses.
    Loader {
        id: mediaLoader
        source: "backends/MediaPlayerBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] media-player backend could not be loaded (org.kde.plasma.private.mpris missing?)")
    }
    readonly property bool mediaAvailable: mediaLoader.item ? mediaLoader.item.hasPlayer : false
    readonly property string mediaTrack: mediaLoader.item ? mediaLoader.item.track : ""
    readonly property string mediaArtist: mediaLoader.item ? mediaLoader.item.artist : ""
    readonly property string mediaAlbum: mediaLoader.item ? mediaLoader.item.album : ""
    readonly property string mediaAlbumArt: mediaLoader.item ? mediaLoader.item.albumArt : ""
    readonly property string mediaIdentity: mediaLoader.item ? mediaLoader.item.identity : ""
    readonly property string mediaIcon: mediaLoader.item ? mediaLoader.item.iconName : "emblem-music-symbolic"
    readonly property bool mediaPlaying: mediaLoader.item ? mediaLoader.item.isPlaying : false
    readonly property bool mediaCanPlay: mediaLoader.item ? mediaLoader.item.canPlay : false
    readonly property bool mediaCanPause: mediaLoader.item ? mediaLoader.item.canPause : false
    readonly property bool mediaCanGoPrevious: mediaLoader.item ? mediaLoader.item.canGoPrevious : false
    readonly property bool mediaCanGoNext: mediaLoader.item ? mediaLoader.item.canGoNext : false
    readonly property bool mediaCanStop: mediaLoader.item ? mediaLoader.item.canStop : false
    readonly property bool mediaCanRaise: mediaLoader.item ? mediaLoader.item.canRaise : false
    readonly property bool mediaCanQuit: mediaLoader.item ? mediaLoader.item.canQuit : false
    readonly property int mediaPosition: mediaLoader.item ? mediaLoader.item.position : 0
    readonly property real mediaLength: mediaLoader.item ? mediaLoader.item.length : 0
    readonly property real mediaVolume: mediaLoader.item ? mediaLoader.item.volume : 0

    // --------------------------------------------------------- Clipboard (M5)
    // From plasma-workspace's klipper (org.kde.plasma.private.clipboard),
    // the same HistoryModel the stock clipboard applet uses.
    Loader {
        id: clipboardLoader
        source: "backends/ClipboardBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] clipboard backend could not be loaded (org.kde.plasma.private.clipboard missing?)")
    }
    readonly property bool clipboardAvailable: clipboardLoader.item ? clipboardLoader.item.available : false
    readonly property bool clipboardEmpty: clipboardLoader.item ? clipboardLoader.item.empty : true
    readonly property int clipboardCount: clipboardLoader.item ? clipboardLoader.item.count : 0
    readonly property string clipboardCurrent: clipboardLoader.item ? clipboardLoader.item.currentText : ""
    readonly property bool clipboardHasPassword: clipboardLoader.item ? clipboardLoader.item.clipboardHasPassword : false
    readonly property var clipboardModel: clipboardLoader.item ? clipboardLoader.item.model : null

    // --------------------------------------------------------- KDE Connect (M5)
    // From kdeconnect-kde's plasmoid (org.kde.kdeconnect.DevicesModel).
    Loader {
        id: kdeconnectLoader
        source: "backends/KDEConnectBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] kdeconnect backend could not be loaded (org.kde.kdeconnect missing?)")
    }
    readonly property bool kdeconnectAvailable: kdeconnectLoader.item ? kdeconnectLoader.item.available : false
    readonly property int kdeconnectConnectedCount: kdeconnectLoader.item ? kdeconnectLoader.item.connectedCount : 0
    readonly property int kdeconnectPairedCount: kdeconnectLoader.item ? kdeconnectLoader.item.pairedCount : 0
    readonly property string kdeconnectSubtitle: kdeconnectLoader.item ? kdeconnectLoader.item.subtitle : i18n("Unavailable")
    readonly property var kdeconnectConnectedModel: kdeconnectLoader.item ? kdeconnectLoader.item.connectedModel : null
    readonly property var kdeconnectPairedModel: kdeconnectLoader.item ? kdeconnectLoader.item.pairedModel : null
    readonly property var kdeconnectAllModel: kdeconnectLoader.item ? kdeconnectLoader.item.allModel : null

    // ---------------------------------------------------- Disks & Devices (M5)
    // From plasma-workspace's devicenotifier (plasma.applet.org.kde.plasma.devicenotifier).
    Loader {
        id: devicesLoader
        source: "backends/DevicesBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] devices backend could not be loaded (plasma.applet.org.kde.plasma.devicenotifier missing?)")
    }
    readonly property bool devicesAvailable: devicesLoader.item ? devicesLoader.item.available : false
    readonly property int devicesCount: devicesLoader.item ? devicesLoader.item.count : 0
    readonly property string devicesSubtitle: devicesLoader.item ? devicesLoader.item.subtitle : i18n("Unavailable")
    readonly property var devicesModel: devicesLoader.item ? devicesLoader.item.model : null
    readonly property int devicesRoleUdi: devicesLoader.item ? devicesLoader.item.roleUdi : 0
    readonly property int devicesRoleDescription: devicesLoader.item ? devicesLoader.item.roleDescription : 0
    readonly property int devicesRoleType: devicesLoader.item ? devicesLoader.item.roleType : 0
    readonly property int devicesRoleIcon: devicesLoader.item ? devicesLoader.item.roleIcon : 0
    readonly property int devicesRoleIsRemovable: devicesLoader.item ? devicesLoader.item.roleIsRemovable : 0
    readonly property int devicesRoleFreeSpaceText: devicesLoader.item ? devicesLoader.item.roleFreeSpaceText : 0
    readonly property int devicesRoleSizeText: devicesLoader.item ? devicesLoader.item.roleSizeText : 0
    readonly property int devicesRoleMounted: devicesLoader.item ? devicesLoader.item.roleMounted : 0
    readonly property int devicesRoleState: devicesLoader.item ? devicesLoader.item.roleState : 0
    readonly property int devicesRoleMessage: devicesLoader.item ? devicesLoader.item.roleMessage : 0
    readonly property int devicesRoleActions: devicesLoader.item ? devicesLoader.item.roleActions : 0
    readonly property int devicesRoleIsBusy: devicesLoader.item ? devicesLoader.item.roleIsBusy : 0

    // ------------------------------------------------------- Input Method (M5)
    // From plasma-workspace's manage-inputmethod (org.kde.plasma.workspace.keyboardlayout).
    Loader {
        id: inputMethodLoader
        source: "backends/InputMethodBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] input-method backend could not be loaded (org.kde.plasma.workspace.keyboardlayout missing?)")
    }
    readonly property bool inputMethodAvailable: inputMethodLoader.item ? inputMethodLoader.item.available : false
    readonly property bool inputMethodVisible: inputMethodLoader.item ? inputMethodLoader.item.visible_ : false
    readonly property int inputMethodMode: inputMethodLoader.item ? inputMethodLoader.item.mode : 0
    readonly property string inputMethodSubtitle: inputMethodLoader.item ? inputMethodLoader.item.subtitle : i18n("Unavailable")
    readonly property string inputMethodModeLabel: inputMethodLoader.item ? inputMethodLoader.item.modeLabel : ""
    readonly property int inputMethodModeNever: inputMethodLoader.item ? inputMethodLoader.item.modeNever : 0
    readonly property int inputMethodModeNonMouseInput: inputMethodLoader.item ? inputMethodLoader.item.modeNonMouseInput : 1
    readonly property int inputMethodModeAnyInput: inputMethodLoader.item ? inputMethodLoader.item.modeAnyInput : 2

    // ------------------------------------------- indicators (Milestone 6)
    // Camera-in-use indicator: reuses plasma-workspace cameraindicator's
    // `org.kde.pipewire.monitor.Monitor.MediaMonitor` with role=Camera.
    // Lights up the existing panel-icon slot in CompactRepresentation.qml.
    Loader {
        id: cameraLoader
        source: "backends/CameraIndicatorBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] camera-indicator backend could not be loaded (org.kde.pipewire.monitor missing?)")
    }
    readonly property bool cameraAvailable: cameraLoader.item ? cameraLoader.item.available : false
    readonly property bool cameraInUse: cameraLoader.item ? cameraLoader.item.inUse : false
    readonly property int cameraRunningCount: cameraLoader.item ? cameraLoader.item.runningCount : 0
    readonly property int cameraIdleCount: cameraLoader.item ? cameraLoader.item.idleCount : 0
    readonly property string cameraSummary: cameraLoader.item ? cameraLoader.item.summary : ""

    // Microphone-in-use indicator: same MediaMonitor with role=Communication
    // (the role VoIP apps register with PipeWire).  Lights up the existing
    // mic-icon slot in CompactRepresentation.qml.
    Loader {
        id: micIndicatorLoader
        source: "backends/MicrophoneInUseBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] mic-indicator backend could not be loaded (org.kde.pipewire.monitor missing?)")
    }
    readonly property bool micIndicatorAvailable: micIndicatorLoader.item ? micIndicatorLoader.item.available : false
    readonly property bool microphoneInUse: micIndicatorLoader.item ? micIndicatorLoader.item.inUse : false
    readonly property int micRunningCount: micIndicatorLoader.item ? micIndicatorLoader.item.runningCount : 0
    readonly property string micSummary: micIndicatorLoader.item ? micIndicatorLoader.item.summary : ""

    // --------------------------------------------------- Tray & Bg apps (M6)
    // StatusNotifier items + Background Apps, both via the public D-Bus
    // services that the stock systemtray's private models wrap.
    Loader {
        id: trayLoader
        source: "backends/TrayBackend.qml"
        onLoaded: if (item) item.backend = backend
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] tray backend could not be loaded")
    }
    readonly property bool trayAvailable: trayLoader.item ? trayLoader.item.available : false
    // True when the live StatusNotifierModel loaded (the normal Plasma case).
    // false only when the private module is missing and qs.sh polls instead.
    readonly property bool trayUsingModel: trayLoader.item ? trayLoader.item.usingModel : false
    readonly property var traySniItems: trayLoader.item ? trayLoader.item.sniItems : []
    readonly property var trayBackgroundApps: trayLoader.item ? trayLoader.item.backgroundApps : []
    readonly property int trayCount: trayLoader.item ? trayLoader.item.count : 0
    readonly property string traySubtitle: trayLoader.item ? trayLoader.item.subtitle : i18n("Unavailable")

    // --------------------------------------------------- SNI pills (M7)
    // SNIs the user has pinned to the main grid as pills.  The list comes
    // from Plasmoid.configuration.pinnedSnis (a StringList of "service|path"
    // pairs); we match each against the live traySniItems so the pill
    // always shows the current title/icon (which can change at any time).
    // Which StatusNotifierItems get pills on the main page: every live
    // tray app when the user enables the setting, otherwise only the ones
    // pinned from the Tray page's right-click action.  traySniItems comes
    // from the live StatusNotifierModel, so pills update instantly.
    readonly property var pillSniItems: Plasmoid.configuration.showSniPills
        ? traySniItems
        : pinnedSniItems

    readonly property var pinnedSniItems: {
        const pinned = Plasmoid.configuration.pinnedSnis || []
        const live = traySniItems
        const result = []
        for (const pair of pinned) {
            const sep = pair.indexOf("|")
            if (sep < 0) continue
            const svc = pair.slice(0, sep)
            const path = pair.slice(sep + 1)
            for (const sni of live) {
                if (sni.service === svc && sni.path === path) {
                    result.push(sni)
                    break
                }
            }
        }
        return result
    }

    function isSniPinned(service, path) {
        const pair = service + "|" + path
        return (Plasmoid.configuration.pinnedSnis || []).indexOf(pair) >= 0
    }
    function pinSni(service, path) {
        if (isSniPinned(service, path)) return
        const list = (Plasmoid.configuration.pinnedSnis || []).slice()
        list.push(service + "|" + path)
        Plasmoid.configuration.pinnedSnis = list
        Plasmoid.configuration.writeConfig()
    }
    function unpinSni(service, path) {
        const pair = service + "|" + path
        const list = (Plasmoid.configuration.pinnedSnis || []).filter(p => p !== pair)
        Plasmoid.configuration.pinnedSnis = list
        Plasmoid.configuration.writeConfig()
    }

    // ------------------------------------------------- derived display values
    readonly property string volumeIcon: muted || volume <= 0 ? "audio-volume-muted"
        : volume < 0.34 ? "audio-volume-low"
        : volume < 0.67 ? "audio-volume-medium"
        : "audio-volume-high"
    readonly property string micIcon: micMuted ? "microphone-sensitivity-muted"
        : micVolume < 0.34 ? "microphone-sensitivity-low"
        : micVolume < 0.67 ? "microphone-sensitivity-medium"
        : "microphone-sensitivity-high"
    // 0 (none) .. 4 (excellent)
    function signalLevel(s) { return s >= 75 ? 4 : s >= 50 ? 3 : s >= 25 ? 2 : s > 0 ? 1 : 0 }
    function signalIcon(s) {
        return ["network-wireless-signal-none", "network-wireless-signal-weak",
                "network-wireless-signal-ok", "network-wireless-signal-good",
                "network-wireless-signal-excellent"][signalLevel(s)]
    }

    // Wired wins when both are up: that is normally the primary connection.
    readonly property string networkIcon: {
        if (airplaneMode) return "network-flightmode-on"
        if (ethConnected) return "network-wired-activated"
        if (wifiAvailable && wifiEnabled && wifiSsid.length > 0) return signalIcon(wifiSignal)
        if (wifiAvailable && wifiEnabled) return "network-wireless-disconnected"
        if (wifiAvailable) return "network-wireless-off"
        return "network-offline"
    }

    readonly property string wifiSubtitle: {
        if (!wifiAvailable) return i18n("Unavailable")
        if (!wifiEnabled) return i18n("Off")
        if (wifiBusySsid.length > 0) return i18n("Connecting…")
        return wifiSsid.length > 0 ? wifiSsid : i18n("Not connected")
    }
    readonly property string bluetoothSubtitle: {
        if (!bluetoothAvailable) return i18n("Unavailable")
        if (!bluetoothEnabled) return i18n("Off")
        if (btConnectedCount > 1) return i18n("%1 devices", btConnectedCount)
        if (btConnectedCount === 1) return btConnectedName
        return i18n("On")
    }

    readonly property string summary: {
        const parts = []
        if (audioAvailable)
            parts.push(muted ? i18n("Volume muted") : i18n("Volume %1%", Math.round(volume * 100)))
        if (brightnessAvailable)
            parts.push(i18n("Brightness %1%", Math.round(brightness * 100)))
        if (hasBattery)
            parts.push(i18n("Battery %1%", batteryPercent))
        if (wifiAvailable && wifiEnabled && wifiSsid.length > 0)
            parts.push(wifiSsid)
        if (airplaneMode)
            parts.push(i18n("Airplane mode"))
        if (doNotDisturb)
            parts.push(i18n("Do Not Disturb"))
        return parts.join("  ·  ")
    }

    // ================================================================ plumbing

    readonly property string scriptPath: decodeURIComponent(
        Qt.resolvedUrl("../scripts/qs.sh").toString().replace(/^file:\/\//, ""))

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }
    function command(args) {
        return "sh " + shellQuote(scriptPath) + " " + args
    }

    // Replies are routed by the exact command string. (Never log these:
    // a Wi-Fi password travels inside one.)
    property var callbacks: ({})

    function run(args, callback) {
        const cmd = command(args)
        if (callback)
            callbacks[cmd] = callback
        exec.connectSource(cmd)
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            const cb = backend.callbacks[sourceName]
            if (cb) {
                delete backend.callbacks[sourceName]
                cb(data["stdout"] || "")
            }
        }
    }

    // While the user is changing a value, ignore polled values for a moment so
    // the slider/toggle doesn't jump back to a stale reading.
    property var holdUntil: ({})
    function touch(key, ms) { holdUntil[key] = Date.now() + (ms || 1500) }
    function held(key) { return (holdUntil[key] || 0) > Date.now() }

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }

    function parseKv(text) {
        const kv = {}
        for (const line of text.split("\n")) {
            const i = line.indexOf("=")
            if (i > 0)
                kv[line.slice(0, i)] = line.slice(i + 1).trim()
        }
        return kv
    }

    // "result=ok" or "result=error|message" -> {ok, message}
    function parseResult(out) {
        const m = /^result=(ok|error)(?:\|(.*))?$/m.exec(out)
        if (!m)
            return { ok: false, message: i18n("No answer from the system helper") }
        return { ok: m[1] === "ok", message: m[2] || "" }
    }

    // Split "a|b|c|rest" into `count` fields plus the untouched remainder
    // (the last field is free text and may itself contain "|").
    function splitFields(body, count) {
        const parts = []
        let rest = body
        for (let i = 0; i < count; i++) {
            const j = rest.indexOf("|")
            if (j < 0)
                return null
            parts.push(rest.slice(0, j))
            rest = rest.slice(j + 1)
        }
        parts.push(rest)
        return parts
    }

    // ============================================================== polling

    function applyPoll(text) {
        const kv = parseKv(text)

        audioAvailable = kv.sink_volume !== undefined
        if (audioAvailable && !held("sink")) {
            volume = clamp01(parseFloat(kv.sink_volume))
            muted = kv.sink_muted === "1"
        }

        micAvailable = kv.source_volume !== undefined
        if (micAvailable && !held("source")) {
            micVolume = clamp01(parseFloat(kv.source_volume))
            micMuted = kv.source_muted === "1"
        }

        const max = parseInt(kv.brightness_max)
        brightnessAvailable = kv.brightness !== undefined && max > 0
        if (brightnessAvailable && !held("brightness"))
            brightness = clamp01(parseInt(kv.brightness) / max)
    }

    function applyNetPoll(text) {
        const kv = parseKv(text)

        ethConnected = kv.eth_connected === "1"

        wifiAvailable = kv.wifi_present === "1"
        if (!wifiAvailable) {
            wifiEnabled = false
            wifiSsid = ""
            wifiSignal = 0
        } else {
            if (!held("wifi"))
                wifiEnabled = kv.wifi_enabled === "1"
            wifiSsid = kv.wifi_ssid || ""
            wifiSignal = parseInt(kv.wifi_signal) || 0
        }

    }

    // -------------------------------------------------- M4 polls
    // Night Color + Airplane mode.  Both go through qs.sh and write the same
    // `key=value` format as the existing polls.  We don't hold their values
    // (the user can't drag a slider for them) but we DO respect `touch()` for
    // the optimistic-UI window after a toggle.
    function applyMiscPoll(text) {
        const kv = parseKv(text)

        if (nightColorLoader.item) {
            nightColorLoader.item.available = kv.nc_available === "1"
            if (!held("nightcolor")) {
                nightColorLoader.item.enabled = kv.nc_enabled === "1"
                nightColorLoader.item.running = kv.nc_running === "1"
            }
        }

        if (airplaneLoader.item) {
            airplaneLoader.item.available = kv.air_available === "1"
            airplaneLoader.item.hardBlocked = kv.air_hard === "1"
            if (!held("airplane"))
                airplaneLoader.item.active = kv.air_active === "1"
        }
    }

    // Color scheme state (slower to change than the others — once a minute is plenty).
    function applyColorSchemePoll(text) {
        const kv = parseKv(text)
        if (colorSchemeLoader.item) {
            colorSchemeLoader.item.available = kv.cs_available === "1"
            if (kv.cs_current !== undefined && !held("colorscheme"))
                colorSchemeLoader.item.currentScheme = kv.cs_current
            if (kv.cs_list !== undefined)
                colorSchemeLoader.item.schemes = kv.cs_list.split("\t").filter(n => n.length > 0).map(name => ({ name, dark: colorSchemeLoader.item.isDarkName(name) }))
        }
    }

    function pollMain() { run("poll", applyPoll) }
    function pollNet() { run("netpoll", applyNetPoll) }
    function pollMisc() { run("miscpoll", applyMiscPoll) }
    function pollColorScheme() { run("cschemepoll", applyColorSchemePoll) }

    // ------------------------------------------------------- Tray poll (M6)
    // Parses `qs.sh traypoll` output, which is one line per StatusNotifier
    // item ("sni=...") plus one line per background app ("bg_app=..."),
    // bracketed by `tray_available=` and `bg_separator=1` / `bg_available=`
    // markers.  See the script for the exact format.
    function applyTrayPoll(text) {
        if (!trayLoader.item) return
        const usingModel = trayLoader.item.usingModel
        const snis = []
        const bgApps = []
        for (const line of text.split("\n")) {
            if (line.startsWith("tray_available=")) {
                // Never let the legacy answer override the live model: the
                // model is authoritative while it is loaded.
                if (!usingModel)
                    trayLoader.item.availableLegacy =
                        line.slice("tray_available=".length) === "1"
            } else if (line.startsWith("sni=")) {
                // sni=<title>|<icon>|<tooltip>|<isMenu>|<service>|<path>
                if (!usingModel) {
                    const f = splitFields(line.slice(4), 5)
                    if (f) {
                        snis.push({
                            title: f[0],
                            icon: f[1],
                            tooltip: f[2],
                            isMenu: f[3] === "1",
                            service: f[4],
                            path: f[5]
                        })
                    }
                }
            } else if (line.startsWith("bg_app=")) {
                // bg_app=<app_id>|<instance>|<message>
                const f = splitFields(line.slice("bg_app=".length), 2)
                if (f && f[0].length > 0) {
                    bgApps.push({
                        appId: f[0],
                        name: f[0],
                        message: f[2],
                        instance: f[1] || f[0]
                    })
                }
            }
        }
        // Only update if the signature changed, to avoid needless ListView
        // rebuilds while the popup is open (same trick as the Wi-Fi list).
        // The icon is part of the legacy signature: some SNIs (IBus proxy)
        // swap their pixmap in place while keeping the same service/path.
        const currentSnis = usingModel ? backend.traySniItems : snis
        const sig = (currentSnis.map(s => s.service + "@" + s.path + "@" + s.icon).join("\u0001"))
                  + "\u0002" + (bgApps.map(a => a.appId).join("\u0001"))
        const oldSig = (backend.traySniItems.map(s => s.service + "@" + s.path + "@" + s.icon).join("\u0001"))
                  + "\u0002" + (backend.trayBackgroundApps.map(a => a.appId).join("\u0001"))
        if (sig !== oldSig) {
            if (!usingModel)
                trayLoader.item.legacySniItems = snis
            trayLoader.item.backgroundApps = bgApps
        }
    }

    // Snapshot for the configuration page's per-icon hide list: the KCM
    // pages cannot see runtime objects, only the configuration.
    // "service|path|title" entries; write only when it changes.  Driven by
    // the live model now, so it also updates when an icon changes title.
    onTraySniItemsChanged: {
        const snapshot = traySniItems.map(s =>
            s.service + "|" + s.path + "|" + (s.title || "").split("\n")[0])
        if (JSON.stringify(snapshot)
                !== JSON.stringify(Plasmoid.configuration.panelTrayIconList || []))
            Plasmoid.configuration.panelTrayIconList = snapshot
    }
    // ------------------------------------------------ tray polling (fallback)
    // The SNI list itself is event-driven now (TrayModelBackend.qml), the
    // same model the stock systemtray renders — no timer, no forks, updates
    // at bus-signal speed.  Only two things still come from qs.sh:
    //
    //   * background apps: plasma-workspace does not export
    //     BackgroundAppsModel to QML, and the list is only shown on the
    //     Tray page, so a slow `qs.sh bgpoll` is enough;
    //   * the whole SNI snapshot, but only when the private tray model
    //     could not be loaded (non-Plasma system, renamed module).  That is
    //     the pre-M13 polling behaviour, kept as a safety net.
    function pollTray() {
        if (backend.trayUsingModel)
            run("bgpoll", applyTrayPoll)
        else
            run("traypoll", applyTrayPoll)
    }

    Timer {
        interval: backend.popupOpen ? 1000 : 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: backend.pollMain()
    }
    Timer {
        interval: backend.popupOpen ? 2500 : 6000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: backend.pollNet()
    }
    // M4 polls (Night Color + Airplane mode).  Slow when the popup is closed
    // (these states change rarely) and quick when it's open so the tiles
    // update promptly after the user toggles them.
    Timer {
        interval: backend.popupOpen ? 1500 : 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: backend.pollMisc()
    }
    // Color scheme rarely changes; a minute is enough.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: backend.pollColorScheme()
    }
    // Tray fallback poll.  The SNI list itself is pushed by the live model
    // (zero forks), so this timer only exists for:
    //   - background apps (Tray page, rarely changes), and
    //   - the legacy full snapshot when the live model is unavailable.
    // The cadence is deliberately slow when the popup is closed; opening
    // the Tray page also triggers an immediate poll (onActivePageChanged).
    Timer {
        interval: backend.popupOpen
            ? (backend.trayUsingModel ? 5000 : 500)
            : (backend.trayUsingModel ? 30000 : 2000)
        running: backend.popupOpen || Plasmoid.configuration.showPanelTrayIcons
        repeat: true
        triggeredOnStart: true
        onTriggered: backend.pollTray()
    }
    // quick re-check after we changed something
    Timer {
        id: netRefresh
        interval: 1500
        onTriggered: backend.pollNet()
    }
    Timer {
        id: miscRefresh
        interval: 800
        onTriggered: backend.pollMisc()
    }
    Timer {
        id: colorSchemeRefresh
        interval: 800
        onTriggered: backend.pollColorScheme()
    }

    // Sliders fire many times per second; send only the latest value.
    property var pending: ({})
    Timer {
        id: flush
        interval: 80
        onTriggered: {
            const p = backend.pending
            backend.pending = ({})
            if (p.volume !== undefined) backend.run("volume " + p.volume.toFixed(2))
            if (p.mic !== undefined) backend.run("micvolume " + p.mic.toFixed(2))
            if (p.brightness !== undefined) backend.run("brightness " + p.brightness.toFixed(3))
        }
    }

    // ============================================================ audio/screen

    function setVolume(v) {
        volume = clamp01(v)
        muted = false
        touch("sink")
        pending.volume = volume
        flush.restart()
    }
    function nudgeVolume(delta) { setVolume(volume + delta) }
    function toggleMute() {
        muted = !muted
        touch("sink")
        run("mute sink")
    }

    function setMicVolume(v) {
        micVolume = clamp01(v)
        micMuted = false
        touch("source")
        pending.mic = micVolume
        flush.restart()
    }
    function toggleMicMute() {
        micMuted = !micMuted
        touch("source")
        run("mute source")
    }

    // Device-picker support.  qs.sh audiosinks/audiosources answer with a
    // single "sinkjson=/sourcejson=" line (see audio_list() there).
    function parseDeviceList(out, key) {
        for (const line of (out || "").split("\n")) {
            if (line.startsWith(key + "=")) {
                try {
                    return JSON.parse(line.slice(key.length + 1)).map(d => ({
                        name: d[0],
                        active: d[1] === 1,
                        description: d[2] || d[0]
                    }))
                } catch (e) { /* malformed json -> keep previous list */ }
            }
        }
        return []
    }
    function refreshAudioSinks() { run("audiosinks", out => backend.audioSinks = parseDeviceList(out, "sinkjson")) }
    function refreshAudioSources() { run("audiosources", out => backend.audioSources = parseDeviceList(out, "sourcejson")) }
    function setDefaultSink(name) {
        if (!name) return
        touch("sink")
        run("setsink " + shellQuote(name))
    }
    function setDefaultSource(name) {
        if (!name) return
        touch("source")
        run("setsource " + shellQuote(name))
    }

    function setBrightness(v) {
        brightness = clamp01(v)
        touch("brightness")
        pending.brightness = brightness
        flush.restart()
    }

    function lockScreen() { run("lock") }
    function powerMenu() { run("power") }
    // M7: screenshot now takes a mode (fullscreen/region/window) and uses
    // the backend from Plasmoid.configuration.screenshotBackend.  Defaults
    // to the configured default mode when called with no argument.
    function screenshot(mode) {
        const m = mode || Plasmoid.configuration.screenshotDefaultMode || "fullscreen"
        const b = Plasmoid.configuration.screenshotBackend || "auto"
        run("screenshot " + m + " " + b)
    }
    function openSettings() { run("settings") }
    function openNetworkSettings() { run("settings network") }
    function openBluetoothSettings() { run("settings bluetooth") }
    function openPowerSettings() { run("settings power") }
    function openNotificationSettings() { run("settings notifications") }
    function openNightColorSettings() { run("settings nightcolor") }
    function openColorSchemeSettings() { run("settings colors") }
    function openInputMethodSettings() { run("settings virtualkeyboard") }
    function openKDEConnectSettings() {
        // Forwarded through the KDE Connect backend, which uses the same
        // `KDEConnect.OpenConfig.openConfiguration()` the stock applet uses.
        if (kdeconnectLoader.item)
            kdeconnectLoader.item.openSettings()
    }
    function openDevicesSettings() { run("settings removabledevices") }
    function openClipboardSettings() {
        // Forwarded through the clipboard backend → klipper.configure(),
        // the same call the stock clipboard applet makes.
        if (clipboardLoader.item)
            clipboardLoader.item.configure()
    }

    // ================================================================= Wi-Fi

    // Merge duplicate SSIDs (one per access point), keep the strongest signal,
    // and sort so the list only reorders when something meaningful changes:
    // active first, then signal *level* (not the jittery raw value), then name.
    function parseNetworks(text) {
        const bySsid = new Map()
        for (const line of text.split("\n")) {
            if (!line.startsWith("net="))
                continue
            const f = splitFields(line.slice(4), 4)
            if (f === null || f[4] === "")
                continue
            const signal = parseInt(f[1]) || 0
            const entry = { ssid: f[4], signal: signal, level: signalLevel(signal),
                            secure: f[2] !== "0", enterprise: f[2] === "2",
                            saved: f[3] === "1", active: f[0] === "1" }
            const old = bySsid.get(entry.ssid)
            if (old === undefined) {
                bySsid.set(entry.ssid, entry)
            } else {
                old.signal = Math.max(old.signal, entry.signal)
                old.level = signalLevel(old.signal)
                old.active = old.active || entry.active
                old.secure = old.secure || entry.secure
                old.enterprise = old.enterprise || entry.enterprise
                old.saved = old.saved || entry.saved
            }
        }
        const list = Array.from(bySsid.values())
        list.sort((a, b) => (Number(b.active) - Number(a.active))
                         || (b.level - a.level)
                         || (a.ssid < b.ssid ? -1 : a.ssid > b.ssid ? 1 : 0))
        return list
    }

    function listSignature(list, fields) {
        return list.map(e => fields.map(k => String(e[k])).join("\u0001")).join("\u0002")
    }

    property bool wifiListBusy: false
    function refreshWifiList() {
        if (!wifiAvailable || !wifiEnabled || wifiListBusy || listsPaused)
            return
        wifiListBusy = true
        run("wifilist", out => {
            wifiListBusy = false
            const list = parseNetworks(out)
            const keys = ["ssid", "active", "saved", "secure", "enterprise", "level"]
            if (listSignature(list, keys) !== listSignature(wifiNetworks, keys))
                wifiNetworks = list
        })
    }

    function scanWifi() {
        if (!wifiAvailable || !wifiEnabled)
            return
        wifiScanning = true
        run("wifiscan")
        scanDone.restart()
    }
    Timer {
        id: scanDone
        interval: 3000
        onTriggered: {
            backend.wifiScanning = false
            backend.refreshWifiList()
        }
    }

    function setWifiEnabled(on) {
        wifiEnabled = on
        touch("wifi", 3500)
        if (!on) {
            wifiNetworks = []
            wifiSsid = ""
            wifiError = ""
        }
        run("wifi " + (on ? "on" : "off"))
        netRefresh.restart()
        if (on && activePage === "wifi")
            pageKick.restart()
    }

    // Turn the helper's error text into something a person can act on.
    function friendlyWifiError(message) {
        if (/secrets|password/i.test(message))
            return i18n("Wrong password, or the network refused the connection.")
        if (/could not be found|not found/i.test(message))
            return i18n("That network is out of range.")
        if (/timeout|timed out/i.test(message))
            return i18n("Connecting took too long.")
        return message
    }

    // password === undefined  ->  saved or open network
    function connectWifi(ssid, saved, password) {
        if (wifiBusySsid.length > 0)
            return
        wifiError = ""
        wifiBusySsid = ssid
        const args = password !== undefined
            ? "wificonnectpw " + shellQuote(ssid) + " " + shellQuote(password)
            : "wificonnect " + shellQuote(ssid) + (saved ? " saved" : " new")
        run(args, out => {
            const r = parseResult(out)
            wifiBusySsid = ""
            wifiError = r.ok ? "" : friendlyWifiError(r.message)
            pollNet()
            wifiListBusy = false
            refreshWifiList()
        })
    }

    function disconnectWifi() {
        wifiError = ""
        run("wifidisconnect", out => {
            const r = parseResult(out)
            wifiError = r.ok ? "" : friendlyWifiError(r.message)
            wifiSsid = ""
            pollNet()
            refreshWifiList()
        })
    }

    // ============================================================== Bluetooth
    // (All logic lives in backends/BluetoothBackend.qml; these just forward.)

    function setBluetoothEnabled(on) {
        if (btLoader.item)
            btLoader.item.setEnabled(on)
    }
    function toggleBtDevice(device, ubi, connected, busy) {
        if (btLoader.item)
            btLoader.item.toggleDevice(device, ubi, connected, busy)
    }
    function pairBtDevice() {
        if (btLoader.item)
            btLoader.item.pairDevice()
    }

    // =========================================================== Power Profile
    // (All logic lives in backends/PowerProfileBackend.qml; these just forward.)

    function setPowerProfile(profile) {
        if (powerProfileLoader.item)
            powerProfileLoader.item.setProfile(profile)
    }
    function cyclePowerProfile() {
        if (powerProfileLoader.item)
            powerProfileLoader.item.cycleProfile()
    }

    // ============================================================== DND / M4
    // (Forwards to backends/NotificationsBackend.qml which uses libnotificationmanager.)

    function setDoNotDisturb(on) {
        if (dndLoader.item)
            dndLoader.item.setDoNotDisturb(on)
    }
    function toggleDoNotDisturb() {
        if (dndLoader.item)
            dndLoader.item.toggle()
    }

    // ============================================================ Night Color
    // State lives in NightColorBackend.qml; the actual D-Bus call goes through qs.sh.

    function setNightLight(on) {
        if (!nightColorLoader.item)
            return
        nightColorLoader.item.setEnabled(on)
        touch("nightcolor", 2500)
        run("nightcolor " + (on ? "on" : "off"))
        miscRefresh.restart()
    }
    function toggleNightLight() {
        setNightLight(!nightLight)
    }

    // =========================================================== Color scheme
    // State lives in ColorSchemeBackend.qml; switching goes through qs.sh.

    function setColorScheme(name) {
        if (!colorSchemeLoader.item || !name || name === colorSchemeName)
            return
        colorSchemeLoader.item.toggle()  // updates currentScheme optimistically
        // But we want a specific scheme, not the auto-pair: override.
        if (colorSchemeLoader.item)
            colorSchemeLoader.item.currentScheme = name
        touch("colorscheme", 3000)
        run("colorscheme set " + shellQuote(name))
        colorSchemeRefresh.restart()
    }
    function toggleDarkStyle() {
        if (!colorSchemeLoader.item || colorSchemeLoader.item.partner.length === 0)
            return
        const target = colorSchemeLoader.item.partner
        colorSchemeLoader.item.toggle()
        touch("colorscheme", 3000)
        run("colorscheme set " + shellQuote(target))
        colorSchemeRefresh.restart()
    }

    // ============================================================ Airplane mode
    // State lives in AirplaneModeBackend.qml; toggling goes through qs.sh.

    function setAirplaneMode(on) {
        if (!airplaneLoader.item || (on && airplaneHardBlocked))
            return
        airplaneLoader.item.setActive(on)
        touch("airplane", 3000)
        run("airplane " + (on ? "on" : "off"))
        miscRefresh.restart()
        netRefresh.restart()  // Wi-Fi/Bluetooth tiles should follow
    }
    function toggleAirplaneMode() {
        setAirplaneMode(!airplaneMode)
    }

    // ============================================================== Media (M5)
    // Forwards to MediaPlayerBackend.qml which wraps Mpris2Model/PlayerContainer.

    function mediaPrevious()  { if (mediaLoader.item) mediaLoader.item.previous() }
    function mediaNext()      { if (mediaLoader.item) mediaLoader.item.next() }
    function mediaPlay()      { if (mediaLoader.item) mediaLoader.item.play() }
    function mediaPause()     { if (mediaLoader.item) mediaLoader.item.pause() }
    function mediaTogglePlay() { if (mediaLoader.item) mediaLoader.item.togglePlaying() }
    function mediaStop()      { if (mediaLoader.item) mediaLoader.item.stop() }
    function mediaQuit()      { if (mediaLoader.item) mediaLoader.item.quit() }
    function mediaRaise()     { if (mediaLoader.item) mediaLoader.item.raise() }
    function mediaSeek(offset) { if (mediaLoader.item) mediaLoader.item.seek(offset) }
    function mediaSetPosition(pos) { if (mediaLoader.item) mediaLoader.item.setPosition(pos) }
    function mediaSetVolume(v) { if (mediaLoader.item) mediaLoader.item.setVolume(v) }
    function mediaRefreshPosition() { if (mediaLoader.item) mediaLoader.item.refreshPosition() }

    // =========================================================== Clipboard (M5)
    // Forwards to ClipboardBackend.qml which wraps klipper's HistoryModel.

    function clipboardSelect(uuid) { if (clipboardLoader.item) clipboardLoader.item.select(uuid) }
    function clipboardRemove(uuid) { if (clipboardLoader.item) clipboardLoader.item.remove(uuid) }
    function clipboardClear()       { if (clipboardLoader.item) clipboardLoader.item.clearHistory() }

    // =========================================================== KDE Connect (M5)
    // Forwards to KDEConnectBackend.qml which wraps org.kde.kdeconnect.DevicesModel.
    // The "pair a new device" and "open settings" actions are the same as the
    // stock KDE Connect applet.

    // =========================================================== Devices (M5)
    // Forwards to DevicesBackend.qml which wraps devicenotifier's DeviceFilterControl.
    // The actual mount/unmount/eject call is `actionsObj.actionTriggered(name)`
    // — the same path the stock applet takes (see actionsinfo.h).
    function deviceTriggerAction(actionsObj, name) {
        if (devicesLoader.item) devicesLoader.item.triggerAction(actionsObj, name)
    }
    function deviceTriggerDefault(actionsObj) {
        if (devicesLoader.item) devicesLoader.item.triggerDefault(actionsObj)
    }

    // =========================================================== Input Method (M5)
    // Forwards to InputMethodBackend.qml which wraps KWinVirtualKeyboard.
    function inputMethodToggle()  { if (inputMethodLoader.item) inputMethodLoader.item.toggle() }
    function inputMethodSetMode(m) { if (inputMethodLoader.item) inputMethodLoader.item.setMode(m) }
    function inputMethodShow()    { if (inputMethodLoader.item) inputMethodLoader.item.show() }
    function inputMethodHide()    { if (inputMethodLoader.item) inputMethodLoader.item.hide() }

    // =========================================================== Tray (M6)
    // Forwards to qs.sh, which calls the StatusNotifierItem /
    // org.freedesktop.background.Monitor D-Bus methods directly.
    // Left click.  If the item has no working Activate action (busctl call
    // fails — some items only implement a menu, and ItemIsMenu is not
    // always accurate), fall back to the right-click action: open the
    // item's menu.  `menuAnchor` is the visual anchor for that menu; pass
    // undefined to get the old fire-and-forget behaviour.
    function trayActivate(service, path, menuAnchor, withPin) {
        if (!service || !path) return
        run("trayactivate " + shellQuote(service) + " " + shellQuote(path), function(txt) {
            if (menuAnchor === undefined)
                return
            if (!parseResult(txt).ok)
                backend.trayContextMenu(service, path, !!withPin, menuAnchor)
        })
    }

    // The item's own DBusMenu, rendered in-process (see SniMenu.qml).
    // Host-side rendering is what the stock tray does: a plain
    // ContextMenu(0,0) call is a no-op for most StatusNotifierItems, the
    // actual menu lives at the object path in the item's `Menu` property
    // and has to be shown by whoever hosts the icon.
    function trayContextMenu(service, path, withPin, anchor) {
        if (!service || !path) return
        if (sniMenu) {
            // A freshly closed menu is pending deletion here; destroying
            // an object that already went away throws, which is harmless
            // but noisy, so swallow it.
            try { sniMenu.destroy() } catch (err) {}
        }
        sniMenu = menuComponent.createObject(backend, {
            backend: backend,
            withPinEntry: !!withPin,
            anchorItem: anchor ?? null
        })
        sniMenu.openFor(service, path)
    }

    function trayMenuClick(service, menuPath, nodeId) {
        if (!service || !menuPath) return
        run("traymenuclick " + shellQuote(service) + " " + shellQuote(menuPath) + " " + nodeId)
    }
    function trayMenuAboutToShow(service, menuPath, nodeId) {
        if (!service || !menuPath) return
        run("traymenuabout " + shellQuote(service) + " " + shellQuote(menuPath) + " " + nodeId)
    }
    // Fetch + flatten the item's menu; used by SniMenu inside openFor().
    function fetchTrayMenuLayout(service, sniPath, callback) {
        if (!service || !sniPath) return
        run("traymenulayout " + shellQuote(service) + " " + shellQuote(sniPath), callback)
    }
    function trayOpenApp(appId) {
        if (!appId) return
        run("trayopenapp " + shellQuote(appId))
    }
    function trayStopApp(instance) {
        if (!instance) return
        run("traystopapp " + shellQuote(instance))
    }

    // SniMenu destroys itself on close (see SniMenu.qml), so we spawn a
    // fresh instance for every request.
    property var sniMenu: null
    Component {
        id: menuComponent
        SniMenu {}
    }

    // ===================================================== detail-page refresh

    // Refresh the list that belongs to the page currently shown.
    function refreshActivePage() {
        if (!popupOpen)
            return
        if (activePage === "wifi")
            refreshWifiList()
    }

    Timer {
        interval: 4000
        running: backend.popupOpen && backend.activePage === "wifi"
        repeat: true
        onTriggered: backend.refreshActivePage()
    }

    // Opening a page: start from fresh data (and ask for a new Wi-Fi scan).
    Timer {
        id: pageKick
        interval: 400
        onTriggered: {
            if (backend.activePage === "wifi") {
                backend.scanWifi()
                backend.refreshWifiList()
            }
        }
    }
    onActivePageChanged: {
        wifiError = ""
        if (activePage === "wifi")
            pageKick.restart()
        // Refresh M4 state the moment the user opens the relevant page, so
        // the tiles feel responsive instead of waiting for the next poll.
        if (activePage === "power" || activePage === "main")
            pollMisc()
        // Tray page: refresh immediately so the list isn't empty for a
        // second while the timer fires.
        if (activePage === "tray")
            pollTray()
        // When the popup opens (activePage becomes non-empty from ""), refresh
        // the MPRIS position so the seek bar isn't stale.  Same trick the
        // stock mediacontroller applet uses in onExpandedChanged.
        if (popupOpen && mediaLoader.item)
            mediaLoader.item.refreshPosition()
    }
}
