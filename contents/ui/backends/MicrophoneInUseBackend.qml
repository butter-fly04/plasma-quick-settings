/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Microphone-in-use indicator, taken from the same KPipeWire MediaMonitor
    the camera indicator uses.

    plasma-workspace doesn't ship a standalone mic-in-use applet, but the
    same `org.kde.pipewire.monitor.Monitor.MediaMonitor` from kpipewire
    works for any `PW_KEY_MEDIA_ROLE`.  We use `role: Communication`, which
    is the role VoIP/conferencing apps (Zoom, Discord, Teams, Jitsi, etc.)
    register themselves with — so the mic icon lights up exactly when one
    of those apps is actively capturing audio.

    This matches what the stock systemtray's mic-in-use indicator does
    internally: it watches PipeWire nodes for the `Communication` role and
    sets `Plasmoid.status = ActiveStatus` while any of them is `Running`.

    `MediaMonitor` is a QAbstractListModel of every matching PipeWire node.
    We only consume `runningCount` (the active-capture gate) and
    `detectionAvailable` (PipeWire is up); `idleCount` and the full model
    are exposed in case a future page wants to list per-app rows.

    If `org.kde.pipewire.monitor` isn't installed the Loader in Backend.qml
    reports the failure and the panel-icon slot stays empty.
*/
import QtQuick
import org.kde.pipewire.monitor as Monitor

Item {
    id: root
    visible: false

    // Same MediaMonitor as the camera backend, with the Communication role
    // (VoIP/audio-call apps).  This is the closest standard role to "the
    // microphone is being used"; a true "any audio capture" indicator
    // would need a node-type watcher, but `Communication` covers the apps
    // people actually care about.
    Monitor.MediaMonitor {
        id: monitor
        role: Monitor.MediaRole.Communication
    }

    // ----------------------------------------------------- availability/state
    readonly property bool available: monitor.detectionAvailable
    readonly property bool inUse: monitor.runningCount > 0
    readonly property int runningCount: monitor.runningCount
    readonly property int idleCount: monitor.idleCount
    readonly property int totalCount: monitor.count

    readonly property string summary: {
        if (!available) return i18n("Microphone indicator is unavailable")
        if (runningCount > 0)
            return i18np("An app is using the microphone",
                         "%1 apps are using the microphone", runningCount)
        return i18n("No app is using the microphone")
    }

    readonly property alias model: monitor
}
