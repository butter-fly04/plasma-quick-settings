/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notification toast (popup) model — Milestone 12.

    This system ships plasma-workspace without the stock "Notifications"
    applet (plugin org.kde.plasma.notifications is not present, so nothing
    shows screen toasts: the FDN daemon runs, the popups have no owner).
    NotificationPopup.qml in the applet instead provides the toast window;
    its model configuration is copied 1:1 from the stock applet's
    global/Globals.qml `popupNotificationsModel`:

      - showExpired / showDismissed: false        (expired rows leave the
        model, which closes the toast — the model runs the timeout itself,
        we just don't hover-pause it like the stock applet does)
      - showAddedDuringInhibition: false
      - popup blacklists (popupBlacklistedApplications / Services from
        NotificationManager.Settings)
      - DND handling: while Server.inhibited, only critical toasts remain,
        unless criticalPopupsInDoNotDisturbMode allows them; plus the DND
        pop-up whitelists when inhibited
      - sortMode SortByTypeAndUrgency / Ascending, groupMode Off
      - jobs are OFF in toasts (stock shows job progress bars; skipped here)

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
