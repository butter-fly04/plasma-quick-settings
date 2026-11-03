/*
    SPDX-License-Identifier: GPL-2.0-or-later

    One screen toast, rendered as its own window.

    This is a QML port of plasma-workspace's notification popup
    (applets/notifications/NotificationPopup.qml + delegates/DelegatePopup.qml):
    a borderless Plasma dialog in the bottom-right corner, with the app header,
    summary/body, the notification's action buttons and the stock horizontal
    "time left" indicator that shrinks while the toast is shown.

    Each popup owns its display timeout (the model's timeout is stopped while
    the popup is alive), so hovering pauses the countdown like in stock.
*/

import QtQuick
import QtQuick.Layouts
import QtQml
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.notificationmanager as NotificationManager

PlasmaCore.Dialog {
    id: popup

    required property int index
    required property var model

    property var backend
    property int popupWidth: Kirigami.Units.gridUnit * 18

    readonly property bool critical:
        model.urgency === NotificationManager.Notifications.CriticalUrgency
    readonly property var urls: model.urls ?? []
    readonly property var actionLabels: model.actionLabels ?? []
    readonly property var actionNames: model.actionNames ?? []
    readonly property var notificationId: model.notificationId

    // Stock: a notification's own timeout wins; -1 means "use the configured
    // default", 0 means "never expire".  Notifications carrying URLs get a
    // longer default so the user can drag them out.
    readonly property int defaultTimeout:
        (backend ? backend.notifPopupTimeout : 5000)
        + (urls.length > 0 ? 5000 : 0)
    readonly property int effectiveTimeout: {
        const timeout = model.timeout
        if (timeout === undefined || timeout === null || timeout === -1) {
            return defaultTimeout
        }
        return Math.max(0, timeout)
    }
    readonly property bool showTimeoutBar:
        backend ? backend.notifShowPopupTimeout : true

    // Drives the stock shrinking timeout indicator.  The animation overwrites
    // the binding while it runs, exactly like the stock popup.
    property real remainingTime: effectiveTimeout

    readonly property bool hovered: hoverHandler.hovered

    location: PlasmaCore.Types.Floating
    // Use KWin's notification window types so the shell stacks and positions
    // these like stock notifications (X11 gets NET::Notification types).
    type: critical
        ? PlasmaCore.Dialog.CriticalNotification
        : PlasmaCore.Dialog.Notification
    // Don't steal focus from the focused window.  Do NOT add
    // WindowStaysOnTopHint here: PlasmaCore.Dialog turns a dialog with that
    // flag into a Dock (panel) surface, which would override the notification
    // role and let windows cover the toast.  Notifications are kept on top by
    // their role.
    flags: Qt.WindowDoesNotAcceptFocus

    // Stock shows the window from Instantiator.onObjectAdded after it has
    // been created and positioned; never from a startup binding.
    visible: false

    mainItem: Item {
        id: toastContent

        width: popup.popupWidth
        // Keep a non-zero height even before the layout is polished: an
        // invisible window does not always run layout polish, and a zero-sized
        // dialog refuses the show (the old "first toast missing" failure).
        height: Math.max(Kirigami.Units.gridUnit * 3,
                         contentLayout.implicitHeight
                         + 2 * Kirigami.Units.largeSpacing)

        // Hover pauses the countdown.
        HoverHandler {
            id: hoverHandler
        }

        // Stock's popup-wide click handling: left click invokes the default
        // action, middle click closes.  Child buttons still handle their own
        // clicks.
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            enabled: popup.model.hasDefaultAction || popup.model.closable
            onTapped: (eventPoint, button) => {
                if (button === Qt.MiddleButton) {
                    if (popup.model.closable) {
                        popup.backend.notifToastClose(popup.index)
                    }
                } else if (popup.model.hasDefaultAction) {
                    popup.backend.notifToastInvokeDefault(popup.index)
                }
            }
        }

        // Critical notifications get the stock left-hand accent bar.
        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: 4
            visible: popup.critical
            color: Kirigami.Theme.neutralTextColor
        }

        // Stock horizontal "time left" indicator: a 2 px bar hugging the top
        // edge of the popup that shrinks as the toast's timeout runs out.
        // Critical notifications never expire, so they use the accent bar
        // instead (stock does the same).
        Item {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 2
            visible: !popup.critical && popup.showTimeoutBar
                     && popup.effectiveTimeout > 0

            Rectangle {
                anchors.left: parent.left
                height: parent.height
                width: Math.round(parent.width * Math.max(0, Math.min(1,
                    popup.remainingTime / popup.effectiveTimeout)))
                color: Kirigami.Theme.highlightColor
            }
        }

        ColumnLayout {
            id: contentLayout

            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            // ----------------------------------------------------- header
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: popup.model.applicationIconName ?? ""
                    visible: valid
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 5
                    opacity: 0.9
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: {
                        const app = popup.model.applicationName ?? ""
                        const origin = popup.model.originName ?? ""
                        return origin ? app + " · " + origin : app
                    }
                }

                PlasmaComponents3.Label {
                    visible: text.length > 0
                    text: popup.ageText
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                PlasmaComponents3.ToolButton {
                    visible: popup.model.configurable ?? false
                    icon.name: "configure"
                    text: popup.model.configureActionLabel || i18n("Configure")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    onClicked: popup.backend.notifToastConfigure(popup.index)
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                }

                PlasmaComponents3.ToolButton {
                    visible: popup.model.dismissable ?? false
                    icon.name: "window-minimize"
                    text: i18n("Minimize")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    onClicked: popup.model.dismissed = true
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                }

                PlasmaComponents3.ToolButton {
                    visible: popup.model.closable ?? false
                    icon.name: "window-close"
                    text: i18n("Close")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    onClicked: popup.backend.notifToastClose(popup.index)
                    PlasmaComponents3.ToolTip.text: text
                    PlasmaComponents3.ToolTip.visible: hovered
                }
            }

            // ------------------------------- stock timeout indicator
            // (full-bleed bar at the top edge of the popup, added below)

            // ------------------------------------------- summary + body
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing / 2

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                        level: 4
                        type: Kirigami.Heading.Type.Primary
                        // Apps often repeat their own name as summary.
                        text: {
                            const summary = popup.model.summary ?? ""
                            const app = popup.model.applicationName ?? ""
                            if (summary
                                    && summary.toLocaleLowerCase().trim()
                                       !== app.toLocaleLowerCase().trim()) {
                                return summary
                            }
                            return ""
                        }
                        visible: text.length > 0
                    }

                    Kirigami.SelectableLabel {
                        id: bodyLabel
                        Layout.fillWidth: true
                        Layout.maximumHeight: Kirigami.Units.gridUnit * 8
                        visible: (popup.model.body ?? "").length > 0
                        // Stock injects the theme link colour into the HTML
                        // body (QTBUG-81463).
                        text: "<style>a { color: " + Kirigami.Theme.linkColor
                              + "; }</style>" + (popup.model.body ?? "")
                        textFormat: Text.RichText
                        wrapMode: TextEdit.Wrap
                        selectByMouse: !Kirigami.Settings.tabletMode
                        onLinkActivated: link => Qt.openUrlExternally(link)
                        onClicked: {
                            if (popup.model.hasDefaultAction && !hoveredLink) {
                                popup.backend.notifToastInvokeDefault(popup.index)
                            }
                        }
                    }

                    // ------------------------------------ action buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing / 2
                        spacing: Kirigami.Units.smallSpacing
                        visible: popup.actionLabels.length > 0

                        Item {
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: popup.actionLabels

                            delegate: PlasmaComponents3.Button {
                                required property string modelData
                                required property int index

                                text: modelData
                                onClicked: {
                                    if (index < popup.actionNames.length) {
                                        popup.backend.notifToastInvokeAction(
                                            popup.index, popup.actionNames[index])
                                    }
                                }
                            }
                        }
                    }
                }

                // Notification-specific artwork, like stock (the app icon
                // already appears in the header, so don't repeat it).
                Kirigami.Icon {
                    readonly property var ownSource:
                        popup.model.image || popup.model.iconName || ""
                    source: ownSource !== ""
                        && ownSource !== popup.model.applicationIconName
                        ? ownSource : ""
                    visible: valid
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                }
            }
        }

        // Non-visual objects live inside mainItem: PlasmaCore.Dialog's default
        // property is `mainItem`, so a direct Timer child would be rejected.
        Timer {
            id: expiryTimer
            interval: popup.effectiveTimeout
            repeat: false
            running: popup.visible && !popup.hovered && popup.effectiveTimeout > 0
            onTriggered: {
                if (popup.backend) {
                    popup.backend.notifToastExpire(popup.index)
                }
            }
        }

        NumberAnimation {
            target: popup
            property: "remainingTime"
            from: popup.effectiveTimeout
            to: 0
            duration: popup.effectiveTimeout
            running: expiryTimer.running && popup.showTimeoutBar
                        && popup.effectiveTimeout > 0
        }

        // "5 min ago" is redrawn periodically while the toast is up.
        Timer {
            interval: 30000
            repeat: true
            running: popup.visible
            onTriggered: popup.ageTick++
        }
    }

    // The popup takes over the model's timeout for as long as it is alive,
    // so hovering can pause it and the indicator can animate.
    property var savedNotificationId
    Component.onCompleted: {
        savedNotificationId = model.notificationId
        if (backend) {
            backend.notifToastStopTimeout(index)
        }
    }

    Component.onDestruction: {
        if (backend && savedNotificationId !== undefined) {
            backend.notifToastStartTimeout(savedNotificationId)
        }
    }

    property int ageTick: 1
    readonly property string ageText: {
        popup.ageTick // dependency
        const time = popup.model.updated ?? popup.model.created
        if (!time || isNaN(time.getTime())) {
            return ""
        }
        if (Date.now() - time.getTime() < 60000) {
            return ""
        }
        try {
            return KCoreAddons.Format.formatRelativeDateTime(time, Locale.ShortFormat)
        } catch (e) {
            return ""
        }
    }
}
