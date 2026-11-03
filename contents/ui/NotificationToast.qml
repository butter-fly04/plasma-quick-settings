/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Screen toast manager (Milestone 12).

    This system ships plasma-workspace without the stock "Notifications"
    applet, so nothing shows pop-up notifications (the daemon queues them;
    no applet owns the toast windows).  This component provides them.

    Architecture copied from the stock applet's global/Globals.qml:
    an Instantiator creates one NotificationPopup window per row of the
    popup model, and each window is positioned/stacked here.  A fresh
    window per notification means the very first notification is shown by
    the same code path as every later one (the old shared dialog was
    created invisibly at startup and its first show could be swallowed).

    Popups are anchored to the bottom-right of the applet's screen (the
    GNOME-style placement this applet already uses).  The countdown and
    hover-pause live in NotificationPopup.qml.
*/

import QtQuick
import QtQml
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property var backend

    // Stock's default toast width/edges (bottom-right, no horizontal centering).
    readonly property int edgeDistance: Kirigami.Units.gridUnit * 2
    readonly property int popupSpacing: Kirigami.Units.gridUnit
    readonly property int popupWidth: Math.max(
        Kirigami.Units.gridUnit * 10,
        Math.min(Kirigami.Units.gridUnit * 18,
                 availableRect.width - 2 * edgeDistance))

    // Plasmoid.availableScreenRect is relative to the screen; add the
    // screen origin to get global window coordinates.
    readonly property rect availableRect: {
        const screen = Plasmoid.screenGeometry
        const available = Plasmoid.availableScreenRect
        if (screen && screen.width > 0 && available && available.width > 0) {
            return Qt.rect(screen.x + available.x, screen.y + available.y,
                           available.width, available.height)
        }
        // plasmoidviewer / no containment: approximate with the primary screen.
        const w = Screen.desktopAvailableWidth || Screen.width || 1920
        const h = Screen.desktopAvailableHeight || Screen.height || 1080
        return Qt.rect(0, 0, w, h)
    }
    onAvailableRectChanged: Qt.callLater(applyPositions)

    readonly property bool popupsEnabled: Plasmoid.configuration.showNotificationPopups

    function applyPositions() {
        const rect = availableRect
        if (rect.width <= 0 || rect.height <= 0) {
            return
        }

        // Iterate in model order: the first (oldest) row sits closest to the
        // bottom-right corner and newer popups stack upwards, like stock.
        let y = rect.y + rect.height - edgeDistance
        const maxTop = rect.y + rect.height * 0.2

        for (let i = 0; i < toastInstantiator.count; ++i) {
            const popup = toastInstantiator.objectAt(i)
            if (!popup) {
                continue
            }

            // Before the first show the window is still hidden and Qt keeps
            // its size at 0; the main item already has the final size, so use
            // that for the first placement.
            const width = popup.width > 0
                ? popup.width
                : (popup.mainItem ? popup.mainItem.width : popupWidth)
            const height = popup.height > 0
                ? popup.height
                : (popup.mainItem ? popup.mainItem.height : 0)

            popup.x = Math.round(rect.x + rect.width - edgeDistance - width)
            popup.y = Math.round(y - height)
            y -= height + popupSpacing

            // Don't let a flood of notifications fill the whole screen.
            // The oldest (first) one is always visible.
            popup.visible = popupsEnabled
                && width > 0 && height > 0
                && (i === 0 || popup.y > maxTop)
        }
    }

    Instantiator {
        id: toastInstantiator
        model: root.backend ? root.backend.notifToastModel : null

        delegate: NotificationPopup {
            backend: root.backend
            popupWidth: root.popupWidth
            onHeightChanged: Qt.callLater(root.applyPositions)
            onWidthChanged: Qt.callLater(root.applyPositions)
        }

        onObjectAdded: (index, object) => {
            object.visible = false
            root.applyPositions()
            if (root.popupsEnabled) {
                // Re-run after the window has its platform size; this is the
                // stock "position, then show" order.
                Qt.callLater(function() {
                    root.applyPositions()
                })
            } else if (root.backend) {
                // Don't keep hidden rows around (and don't destroy the
                // popup from inside Instantiator's objectAdded signal).
                Qt.callLater(function() {
                    if (root.backend) {
                        root.backend.notifToastExpireAll()
                    }
                })
            }
        }

        onObjectRemoved: (index, object) => {
            Qt.callLater(root.applyPositions)
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onShowNotificationPopupsChanged() {
            if (!root.popupsEnabled && root.backend) {
                Qt.callLater(function() {
                    if (root.backend) {
                        root.backend.notifToastExpireAll()
                    }
                })
            }
            Qt.callLater(root.applyPositions)
        }
    }
}
