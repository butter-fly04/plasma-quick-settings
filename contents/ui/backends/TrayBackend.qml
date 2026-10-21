/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Tray & Background Apps state.

    The stock plasma-workspace systemtray applet is a ContainmentItem — it
    can't be embedded inside another applet's popup.  Its private models
    (`StatusNotifierModel`, `BackgroundAppsModel`) live in
    `org.kde.plasma.private.systemtray`, a private QML module that's
    explicitly unstable across Plasma releases.

    Per PLAN.md M6 notes, we go with **option (a)**: connect to the public
    D-Bus interfaces directly, the same ones the private models wrap:

      - StatusNotifierItems: `org.kde.StatusNotifierWatcher` at
        `/StatusNotifierWatcher` (session bus) exposes
        `RegisteredStatusNotifierItems` — a QStringList of "service/path"
        pairs.  Each item is then an `org.kde.StatusNotifierItem` at the
        given service+path, with `Icon`, `Title`, `ToolTip`, `Menu`, and
        an `Activate(x, y)` method.
      - Background Apps: `org.freedesktop.background.Monitor` at
        `/org/freedesktop/background/monitor` exposes `BackgroundApps` —
        a list of `{app_id, message, instance}`.  Methods: `OpenApp(app_id)`,
        `StopApp(instance)`.

    All D-Bus access goes through `../scripts/qs.sh` (run via the executable
    engine in Backend.qml, the existing pattern).  The script writes one
    line per SNI / background app in a `key=value` format Backend.qml
    parses; the resulting arrays are exposed here as `sniItems` and
    `backgroundApps`.

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

    // ----------------------------------------------------- availability/state
    property bool available: false         // busctl + StatusNotifierWatcher present
    property var sniItems: []              // [{service, path, title, icon, tooltip, isMenu}]
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
        root.available = true
        backend.trayActivate(service, path)
    }

    // Open a background app's main window.  The BackgroundMonitor D-Bus
    // service exposes OpenApp(s app_id).
    function openBackgroundApp(appId) {
        root.available = true
        backend.trayOpenApp(appId)
    }

    // Stop a background app instance.  The instance ID is the flatpak PID
    // the monitor reports.
    function stopBackgroundApp(instance) {
        root.available = true
        backend.trayStopApp(instance)
    }
}
