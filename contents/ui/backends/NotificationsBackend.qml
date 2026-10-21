/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Do Not Disturb state, taken from Plasma itself instead of being re-implemented.

    The stock "Notifications" applet (plasma-workspace/applets/notifications)
    sets Do Not Disturb through two objects from `org.kde.notificationmanager`:

      - NotificationManager.Settings   (a KConfig-backed settings object)
            .notificationsInhibitedUntil  QDateTime   — DND is active until this
            .notificationsInhibitedByApplication  bool  — some app called
                                                            Inhibit() on the FDN
            .save() / .revokeApplicationInhibitions()
      - NotificationManager.Server     (a singleton wrapping the FDN daemon)
            .valid    bool  — is Plasma's notification daemon on the bus
            .inhibited bool  — the live "are we suppressing popups right now"
                                 flag; writing it tells the daemon to update

    Globals.qml in the notifications applet toggles DND by setting
    `notificationsInhibitedUntil` to "a year from now" (effectively "until
    turned off") and calling `save()`.  We mirror that exactly so toggling
    here matches toggling in the notification tray, including the OSD message
    the daemon may show.

    We also expose `inhibitedByApplication` so the UI can show "an application
    has inhibited notifications" — the same reason the stock applet shows a
    struck-through bell icon.
*/
import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
    id: root
    visible: false

    NotificationManager.Settings {
        id: settings
        // `live: true` makes Settings watch its config file for external
        // changes (e.g. the user toggling DND from the notification applet),
        // so our `inhibited` flag tracks the truth in real time.
        live: true
        Component.onCompleted: load()
    }

    // ----------------------------------------------------- availability/state
    readonly property bool available: NotificationManager.Server.valid
    // Server.inhibited is the source of truth and already takes
    // `notificationsInhibitedUntil` AND `notificationsInhibitedByApplication`
    // into account (the daemon computes the effective value). We still keep
    // `byApplication` separately because the UI shows the reason.
    readonly property bool inhibited: NotificationManager.Server.inhibited
    readonly property bool inhibitedByApplication: settings.notificationsInhibitedByApplication
    readonly property date inhibitedUntil: settings.notificationsInhibitedUntil

    // ---------------------------------------------------------- mutators
    // Same wording/logic as Globals.qml toggleDoNotDisturbMode() in the
    // notifications applet: a year from now == "until turned off".
    // To disable, set notificationsInhibitedUntil = undefined (NOT
    // resetNotificationsInhibitedUntil() — that method exists in C++ but
    // is not Q_INVOKABLE, so calling it from QML silently does nothing,
    // which is why DND could be enabled but not disabled in v0.7.4).
    function setDoNotDisturb(on) {
        if (!available)
            return
        if (on) {
            const d = new Date()
            d.setFullYear(d.getFullYear() + 1)
            settings.notificationsInhibitedUntil = d
        } else {
            // Mirrors Globals.qml revokeInhibitions(): clear the until-date,
            // revoke app inhibitions, and clear the fullscreen/mirror flags.
            settings.notificationsInhibitedUntil = undefined
            settings.revokeApplicationInhibitions()
        }
        settings.save()
        // Live-update the daemon: Server.inhibited is writable and bound to
        // the FDN `Inhibited` property.
        NotificationManager.Server.inhibited = on
    }

    function toggle() {
        setDoNotDisturb(!inhibited)
    }
}
