/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notifications history backend, taken from plasma-workspace's
    notifications applet (applets/notifications/main.qml +
    FullRepresentation.qml).

    Uses `org.kde.notificationmanager.Notifications` — the same model the
    stock applet uses for its history list — configured the same way:
      showExpired: true
      showDismissed: true
      sortMode: SortByDate
      groupMode: GroupApplicationsFlat
      groupLimit: 2
      urgencies: Normal | Critical (| Low if lowPriorityHistory)

    Each row's roles (from plasma-workspace/libnotificationmanager/notifications.h)
    include: Id, Created, Updated, Summary, Body, ApplicationName,
    ApplicationIconName, DesktopEntry, Urgency, Type, ActionList, ExpiresAt,
    Dismissed, Read.  The NotificationsPage reads them via `model.<role>`.

    We expose:
      - `model`              the Notifications model (for the ListView)
      - `count`              number of rows
      - `unreadCount`        number of unread notifications (capped at 99)
      - `markAllRead()`      mark every visible row as Read
      - `clearExpired()`     clear expired notifications (the stock applet's
                              "Clear All Notifications" contextual action)

    The model is a QML type from `org.kde.notificationmanager`, so it lives
    in the same module as the DND backend we already use.
*/
import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
    id: root
    visible: false

    NotificationManager.Settings {
        id: notificationSettings
        live: true
        Component.onCompleted: load()
    }

    NotificationManager.Notifications {
        id: historyModel
        showExpired: true
        showDismissed: true
        showJobs: notificationSettings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByDate
        // Plain chronological list.  GroupApplicationsFlat inserts a
        // header row per application whose summary/body are empty, which
        // showed up as a blank row under the page title.
        groupMode: NotificationManager.Notifications.GroupDisabled
        expandUnread: true
        ignoreBlacklistDuringInhibition: true
        blacklistedDesktopEntries: notificationSettings.historyBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.historyBlacklistedServices
        urgencies: {
            let u = NotificationManager.Notifications.CriticalUrgency
                  | NotificationManager.Notifications.NormalUrgency
            if (notificationSettings.lowPriorityHistory)
                u |= NotificationManager.Notifications.LowUrgency
            return u
        }
    }

    // ----------------------------------------------------- availability/state
    readonly property bool available: NotificationManager.Server.valid
    readonly property var model: historyModel
    readonly property int count: historyModel.count
    readonly property int unreadCount: Math.min(99, historyModel.unreadNotificationsCount)
    readonly property int dismissedCount: historyModel.dismissedResidentNotificationsCount

    // ---------------------------------------------------------- mutators
    // Mark every visible row as Read — same loop the stock applet's
    // onExpandedChanged handler runs.
    function markAllRead() {
        for (let i = 0; i < historyModel.count; i++) {
            const idx = historyModel.index(i, 0)
            historyModel.setData(idx, true, NotificationManager.Notifications.ReadRole)
        }
    }

    // Clear expired notifications — same call the stock applet's
    // "Clear All Notifications" action makes.
    function clearExpired() {
        historyModel.clear(NotificationManager.Notifications.ClearExpired)
    }

    // Open the "Configure Event Notifications and Actions…" KCM.
    // Routed through qs.sh → systemsettings kcm_notifications.
    function openSettings() {
        // Forwarded via Backend.qml.openNotificationSettings()
    }
}
