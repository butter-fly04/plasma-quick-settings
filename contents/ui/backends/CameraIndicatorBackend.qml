/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Camera-in-use indicator, taken from Plasma itself.

    plasma-workspace's cameraindicator applet (applets/cameraindicator/qml/
    main.qml) uses `org.kde.pipewire.monitor.Monitor.MediaMonitor` from the
    `kpipewire` repo (src/monitors/mediamonitor.h).  We instantiate the same
    singleton here with `role: Camera` so the Quick Settings panel icon
    lights up exactly when the stock camera-indicator tray icon would.

    `MediaMonitor` is a QAbstractListModel of every PipeWire node with the
    given `PW_KEY_MEDIA_ROLE`.  For cameras that means every video capture
    node (webcam, screen-share, etc.).  We only care about its `runningCount`
    — the number of nodes in the `Running` state — because that's the
    "a camera is actively capturing right now" signal the stock applet uses
    to set Plasmoid.status = ActiveStatus.

    The model also exposes `idleCount` (cameras available but not capturing)
    and `detectionAvailable` (PipeWire is up and the monitor can see nodes);
    we surface them so the UI can show a dimmed icon when no camera is
    connected at all.

    If `org.kde.pipewire.monitor` isn't installed (a system without kpipewire)
    the Loader in Backend.qml reports the failure and the panel-icon slot
    stays empty — same graceful degradation as every other backend.
*/
import QtQuick
import org.kde.pipewire.monitor as Monitor

Item {
    id: root
    visible: false

    // The same MediaMonitor the stock cameraindicator applet uses.
    Monitor.MediaMonitor {
        id: monitor
        role: Monitor.MediaRole.Camera
    }

    // ----------------------------------------------------- availability/state
    // True when PipeWire can see at least one camera node AND that node is
    // actively capturing.  This is the gate the stock applet uses to decide
    // whether to show the indicator.
    readonly property bool available: monitor.detectionAvailable
    readonly property bool inUse: monitor.runningCount > 0
    readonly property int runningCount: monitor.runningCount
    readonly property int idleCount: monitor.idleCount
    readonly property int totalCount: monitor.count

    // A short human-readable summary for the popup, mirroring the stock
    // applet's toolTipSubText.
    readonly property string summary: {
        if (!available) return i18n("Camera indicator is unavailable")
        if (runningCount > 0)
            return i18np("A camera is in use", "%1 cameras are in use", runningCount)
        return i18n("No camera is in use")
    }

    // Exposed so a future Tray page could list the per-camera rows (the
    // stock applet's FullRepresentation does this).  For now we only need
    // the aggregate flags, but the model is here if we want it.
    readonly property alias model: monitor
}
