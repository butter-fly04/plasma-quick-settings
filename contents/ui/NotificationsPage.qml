/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notifications detail page.  Mirrors plasma-workspace's notifications applet
    (applets/notifications/FullRepresentation.qml):

      - a header row with a "Do Not Disturb" switch (same call as the main
        DND tile — NotificationsBackend.setDoNotDisturb) and a "Clear All"
        button (calls `Notifications.clear(ClearExpired)`)
      - a scrollable list of recent notifications, one row per notification:
          * application icon + name (top)
          * summary (bold) + body (muted)
          * relative time ("just now", "5 min ago", …)
          * action buttons if the notification exposed any (actionLabels /
            actionNames)
      - clicking a row with a default action invokes it

    The model is `org.kde.notificationmanager.Notifications` — the same one
    the stock applet uses for its history list.  Role names (from
    libnotificationmanager/utils.cpp Utils::roleNames): each `FooRole` enum
    value becomes a lower-camel role name with "Role" stripped — e.g.
    `ApplicationNameRole` → `applicationName`, `BodyRole` → `body`,
    `CreatedRole` → `created`, `ActionLabelsRole` → `actionLabels`,
    `ActionNamesRole` → `actionNames`, `IconNameRole` → `iconName`,
    `ApplicationIconNameRole` → `applicationIconName`.  `IdRole` is special-
    cased to `notificationId` (because `id` is QML-reserved).  `SummaryRole`
    is Qt::DisplayRole so it's exposed as `display`.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.notificationmanager as NotificationManager

ColumnLayout {
    id: page

    required property var backend

    // Opt-in sizing for FullRepresentation's dynamic popup height: this
    // page collapses the popup to its own implicit height, but only while
    // nothing is listed (the placeholder-only cases) — with real entries
    // the ScrollView below takes the popup's regular fill height anyway.
    property bool sizedToContent: backend.notifHistoryCount === 0

    spacing: Kirigami.Units.smallSpacing

    // Optional "Do Not Disturb" switch.  Hidden by default — the main page
    // already has a Do Not Disturb tile and the page heading carries the
    // "clear history" button, so with the switch off this page is just
    // heading + content: no filler row, no gap under the header.
    RowLayout {
        visible: Plasmoid.configuration.showDndInNotifications
        Layout.fillWidth: true

        PlasmaComponents3.Switch {
            text: i18n("Do Not Disturb")
            enabled: page.backend.dndAvailable
            checked: page.backend.doNotDisturb
            onToggled: page.backend.setDoNotDisturb(checked)
        }
    }

    // --- Placeholder when there are no notifications ---
    // No fillHeight: the popup shrinks to this page's own height when
    // empty, so a centered filler would be the "empty space below the
    // header" the placeholder used to produce.
    Kirigami.PlaceholderMessage {
        visible: page.backend.notifHistoryAvailable && page.backend.notifHistoryCount === 0
        Layout.fillWidth: true
        icon.name: "notifications"
        text: i18n("No unread notifications")
    }

    Kirigami.PlaceholderMessage {
        visible: !page.backend.notifHistoryAvailable
        Layout.fillWidth: true
        icon.name: "notifications-disabled"
        text: i18n("Notifications unavailable")
        explanation: i18n("Plasma's notification daemon is not running.")
    }

    // --- Notification list ---
    // Plain ListView (not wrapped in a ScrollView) to avoid the empty
    // gap at the top that PlasmaComponents3.ScrollView can introduce.
    PlasmaComponents3.ScrollView {
        id: notifScroll
        visible: page.backend.notifHistoryAvailable && page.backend.notifHistoryCount > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

    ListView {
        id: notifList
        clip: true
        spacing: Kirigami.Units.smallSpacing / 2
        model: page.backend.notifHistoryModel

        // Mark everything as read when the user opens this page (same
        // behaviour as the stock applet's onExpandedChanged).
        Component.onCompleted: page.backend.notifMarkAllRead()

        delegate: PlasmaComponents3.ItemDelegate {
            id: notifRow
            required property int index
                required property var model

                width: ListView.view.width

                // Clicking a row with a default action invokes it — the same
                // interaction the stock applet gives rows (Close behavior, so
                // acting on a non-resident notification clears it).
                onClicked: {
                    if (notifRow.model.hasDefaultAction) {
                        try {
                            const idx = page.backend.notifHistoryModel.index(notifRow.index, 0)
                            page.backend.notifHistoryModel.invokeDefaultAction(idx,
                                NotificationManager.Notifications.Close)
                        } catch (e) { /* ignore */ }
                    }
                }

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: (notifRow.model.applicationIconName ?? "")
                                || (notifRow.model.iconName ?? "")
                                || "preferences-desktop-notification"
                        fallback: "preferences-desktop-notification"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            PlasmaComponents3.Label {
                                text: notifRow.model.applicationName ?? ""
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                opacity: 0.85
                            }
                            PlasmaComponents3.Label {
                                visible: notifRow.model.created !== undefined
                                text: {
                                    const created = notifRow.model.created
                                    if (!created) return ""
                                    // KCoreAddons.Format.formatRelativeDateTime
                                    // gives "5 min ago" / "just now" / etc.
                                    try {
                                        return KCoreAddons.Format.formatRelativeDateTime(created, Locale.ShortFormat)
                                    } catch (e) {
                                        return ""
                                    }
                                }
                                opacity: 0.6
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                        PlasmaComponents3.Label {
                            visible: (notifRow.model.display ?? "").length > 0
                            text: notifRow.model.display ?? ""
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            visible: (notifRow.model.body ?? "").length > 0
                            text: notifRow.model.body ?? ""
                            opacity: 0.85
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        // Action buttons row — same pattern as the stock
                        // applet's NotificationItem actions Repeater.
                        RowLayout {
                            visible: (notifRow.model.actionLabels ?? []).length > 0
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: notifRow.model.actionLabels ?? []
                                delegate: PlasmaComponents3.Button {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    flat: true
                                    onClicked: {
                                        // Invoke the action by its name; the
                                        // model wraps it with a built-in proxy
                                        // chain, so a top-level QModelIndex of
                                        // row @ index works (same call the
                                        // stock applet makes; upstream
                                        // FullRepresentation.qml:551).
                                        // Close behavior: after the user acts
                                        // on a non-resident notification it
                                        // goes away from history, like stock.
                                        const names = notifRow.model.actionNames ?? []
                                        if (index < names.length) {
                                            try {
                                                const idx = page.backend.notifHistoryModel.index(notifRow.index, 0)
                                                page.backend.notifHistoryModel.invokeAction(idx, names[index],
                                                    NotificationManager.Notifications.Close)
                                            } catch (e) { /* ignore */ }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
    }
}
