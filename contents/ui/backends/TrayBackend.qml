/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Tray & Background Apps state.

    StatusNotifier items
    --------------------
    The panel icons and the Tray page need the live SNI list.  The stock
    systemtray applet renders `StatusNotifierModel`, a model kept up to
    date by `StatusNotifierItemHost` through session-bus signals;
    plasma-workspace exports that model to QML (for plasma-mobile), so we
    instantiate it through `TrayModelBackend.qml`.  That gives exactly the
    stock latency: a NewIcon/NewTitle/NewStatus signal updates the model,
    the model updates this array, the icons repaint — no polling and no
    subprocesses.

    If the private module cannot be loaded (non-Plasma platform, renamed
    module), a Loader error leaves `usingModel` false and the old
    `qs.sh traypoll` path in Backend.qml keeps working unchanged.

    Background apps
    ---------------
    `org.freedesktop.background.Monitor` at
    `/org/freedesktop/background/monitor` exposes `BackgroundApps` — a list
    of `{app_id, message, instance}`.  Methods: `OpenApp(app_id)`,
    `StopApp(instance)`.  There is no QML-exported model for it in
    plasma-workspace, so this list still comes from `qs.sh traypoll`
    (polled slowly; it is only shown on the Tray page).

    All D-Bus calls go through `../scripts/qs.sh` (run via the executable
    engine in Backend.qml, the existing pattern).  The script writes one
    line per SNI / background app in a `key=value` format Backend.qml
    parses.

    If `busctl` is missing, or the watcher service isn't registered (no
    system tray running), the lists stay empty and the Tray page just
    shows its placeholder messages — same graceful degradation as the
    rest of the plasmoid.
*/
import QtQuick

Item {
    id: root
    visible: false

    // Filled in by Backend.qml's trayLoader (onLoaded); used by the
    // mutators below, which are thin routing wrappers over qs.sh.
    property var backend: null

    // ------------------------------------------------ live StatusNotifier model
    // Private plasma-workspace module; isolated in its own file so a
    // missing module only fails this Loader.
    Loader {
        id: modelLoader
        source: "TrayModelBackend.qml"
        onStatusChanged: if (status === Loader.Error)
            console.warn("[QuickSettings] live tray model unavailable, using qs.sh fallback")
    }

    readonly property bool usingModel: modelLoader.item !== null
    readonly property bool modelReady: usingModel && modelLoader.item.ready

    // ----------------------------------------------------- availability/state
    // Legacy (qs.sh) fallbacks, written by Backend.applyTrayPoll only while
    // the live model is unavailable.
    property bool availableLegacy: false
    property var legacySniItems: []

    readonly property bool available: usingModel ? true : availableLegacy
    readonly property var sniItems: usingModel ? modelLoader.item.sniItems : legacySniItems
    property var backgroundApps: []        // [{appId, name, icon, message, instance}]
    property string error: ""

    readonly property int count: sniItems.length + backgroundApps.length
    readonly property string subtitle: {
        if (count === 0) return i18n("Nothing running")
        const parts = []
        if (sniItems.length > 0)
            parts.push(i18np("One tray item", "%1 tray items", sniItems.length))
        if (backgroundApps.length > 0)
            parts.push(i18np("One background app", "%1 background apps", backgroundApps.length))
        return parts.join(" · ")
    }

    // ---------------------------------------------------------- mutators
    // Activate a StatusNotifierItem by service+path.  The SNI spec says
    // Activate(int x, int y) is what to call when the user clicks the icon
    // (e.g. to toggle the app's main window).  We pass (0, 0) — the same
    // the stock systemtray's StatusNotifierItem.qml does for a left-click
    // without a known cursor position.
    function activateSni(service, path) {
        backend.trayActivate(service, path)
    }

    // Open a background app's main window.  The BackgroundMonitor D-Bus
    // service exposes OpenApp(s app_id).
    function openBackgroundApp(appId) {
        backend.trayOpenApp(appId)
    }

    // Stop a background app instance.  The instance ID is the flatpak PID
    // the monitor reports.
    function stopBackgroundApp(instance) {
        backend.trayStopApp(instance)
    }
}
