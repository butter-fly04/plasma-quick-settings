/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notification toast (popup) model — Milestone 12.

    This system ships plasma-workspace without the stock "Notifications"
    applet (plugin org.kde.plasma.notifications is not present, so nothing
    shows screen toasts: the FDN daemon runs, the popups have no owner).
    NotificationPopup.qml provides the per-notification toast window; its
    model configuration is copied 1:1 from the stock applet's
    global/Globals.qml `popupNotificationsModel`:

      - showExpired / showDismissed: false        (expired rows leave the
        model, which closes their popup)
      - showAddedDuringInhibition: false
      - popup blacklists (popupBlacklistedApplications / Services from
        NotificationManager.Settings)
      - DND handling: while Server.inhibited, only critical toasts remain,
        unless criticalPopupsInDoNotDisturbMode allows them; plus the DND
        pop-up whitelists when inhibited
      - sortMode SortByTypeAndUrgency / Ascending, groupMode Off
      - jobs are OFF in toasts (stock shows job progress bars; skipped here)

    Like stock, each popup calls stopTimeout() on creation and owns the
    timeout itself (so hovering pauses its countdown bar), then calls
    startTimeout() again when it is destroyed.

    Exposed mutators mirror the stock delegates' lifecycle calls:
      close(), expire(), configure(), invokeDefaultAction(), invokeAction()
    all with InvokeBehavior.Close so acting on a toast removes it (the
    stock popup is never "resident").
*/
import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
    id: root
    visible: false

    readonly property bool available: NotificationManager.Server.valid
    readonly property bool inhibited: NotificationManager.Server.inhibited

    NotificationManager.Settings {
        id: notificationSettings
        live: true
        Component.onCompleted: load()
    }

    NotificationManager.Notifications {
        id: popupModel

        limit: 12
        showExpired: false
        showDismissed: false
        showAddedDuringInhibition: false
        blacklistedDesktopEntries: notificationSettings.popupBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.popupBlacklistedServices
        whitelistedDesktopEntries: root.inhibited
            ? notificationSettings.doNotDisturbPopupWhitelistedApplications : []
        whitelistedNotifyRcNames: root.inhibited
            ? notificationSettings.doNotDisturbPopupWhitelistedServices : []
        // Job progress bars (download/copy dialogs) are handled by the
        // stock applet; without it there is no job widget, so leave them in
        // the history only.
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByTypeAndUrgency
        sortOrder: Qt.AscendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: {
            let urgencies = 0
            // Critical always, except in DND when disabled there.
            if (!root.inhibited || notificationSettings.criticalPopupsInDoNotDisturbMode)
                urgencies |= NotificationManager.Notifications.CriticalUrgency
            // Normal only when not in do not disturb mode.
            if (!root.inhibited)
                urgencies |= NotificationManager.Notifications.NormalUrgency
            // Low only when enabled and not inhibited.
            if (!root.inhibited && notificationSettings.lowPriorityPopups)
                urgencies |= NotificationManager.Notifications.LowUrgency
            return urgencies
        }
    }

    readonly property var model: popupModel
    readonly property int count: popupModel.count

    // Timing settings shared with the stock applet (Notifications page in
    // System Settings).  NotificationPopup uses these for its countdown bar.
    readonly property int notifPopupTimeout: notificationSettings.popupTimeout
    readonly property bool notifShowPopupTimeout: notificationSettings.showPopupTimeout

    // Stock popups stop the model timeout while they are on screen and let
    // their own timer handle expiry (so hovering can pause it).
    function stopTimeout(index) {
        const idx = popupModel.index(index, 0)
        if (idx.valid) {
            popupModel.stopTimeout(idx)
        }
    }
    function startTimeout(notificationId) {
        if (notificationId !== undefined && notificationId !== null) {
            popupModel.startTimeout(notificationId)
        }
    }

    // Used when pop-up notifications are switched off: don't leave stale
    // rows accumulating in the popup model.
    function expireAll() {
        for (let i = popupModel.count - 1; i >= 0; --i) {
            popupModel.expire(popupModel.index(i, 0))
        }
    }

    function close(index) {
        popupModel.close(popupModel.index(index, 0))
    }
    function expire(index) {
        popupModel.expire(popupModel.index(index, 0))
    }
    function configure(index) {
        popupModel.configure(popupModel.index(index, 0))
    }
    function invokeDefaultAction(index) {
        popupModel.invokeDefaultAction(popupModel.index(index, 0),
            NotificationManager.Notifications.Close)
    }
    function invokeAction(index, actionName) {
        popupModel.invokeAction(popupModel.index(index, 0), actionName,
            NotificationManager.Notifications.Close)
    }
}
